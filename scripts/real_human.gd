class_name RealHuman
extends Node3D

signal struck                    # the hammer hits the anvil (hammer mode)
## A downloaded, skinned human model (Quaternius "Universal Base Characters", CC0, see ASSETS.md)
## driven by code: walk/run cycle from real ground speed, idle breathing and head looks, a hammer
## work loop and an airborne pose. Same interface as the old procedural HumanRig:
## setup(preset, name), `mode`, animate(delta, speed, grounded). Faces -Z, about 1.75 m tall.
##
## Preset keys: body (glb name), robe (bool, tunic overlay), scale, tint (Color), tool ("hammer").
##
## The models are in a T-pose, so all poses are model-space rotations about each bone's pivot,
## composed down the hierarchy and converted to Godot local bone poses (see _apply).

const DIR := "res://assets/characters/"
const TARGET_HEIGHT := 1.75
const BONES_UBC := {
	"hips": "hips", "spine": "spine", "chest": "chest", "neck": "neck", "head": "head",
	"clav_L": "clavicle_l", "sh_L": "upper_arm_l", "el_L": "forearm_l", "wr_L": "hand_l",
	"clav_R": "clavicle_r", "sh_R": "upper_arm_r", "el_R": "forearm_r", "wr_R": "hand_r",
	"hip_L": "thigh_l", "kn_L": "shin_l", "an_L": "foot_l",
	"hip_R": "thigh_r", "kn_R": "shin_r", "an_R": "foot_r",
}
const BONES_MOD := {
	"hips": "Hips", "spine": "Abdomen", "chest": "Torso", "neck": "Neck", "head": "Head",
	"clav_L": "Shoulder.L", "sh_L": "UpperArm.L", "el_L": "LowerArm.L", "wr_L": "Hand.L",
	"clav_R": "Shoulder.R", "sh_R": "UpperArm.R", "el_R": "LowerArm.R", "wr_R": "Hand.R",
	"hip_L": "UpperLeg.L", "kn_L": "LowerLeg.L", "an_L": "Foot.L",
	"hip_R": "UpperLeg.R", "kn_R": "LowerLeg.R", "an_R": "Foot.R",
}
const BONES := BONES_UBC

var preset: Dictionary = {}
var mode := "locomotion"        # "locomotion", "idle", "hammer"
var _t := 0.0
var _phase := 0.0
var _speed_smooth := 0.0
var _air := 0.0
var _seed := 0.0
var _skins: Array[Skeleton3D] = []
var _bone_idx: Array = []         # per skeleton: Dictionary key -> bone index
var _rest_g: Array = []           # per skeleton: Array[Basis] global rest bases
var _order: Array = []            # per skeleton: bone indices parent-first
var _arm_rot: Array = []          # per skeleton: {"L": rad, "R": rad} rotation about Z that lowers the arm
var _pose: Dictionary = {}        # key -> Vector3 (rx, ry, rz) rig-style angles
var _hips_dy := 0.0
var _hips_rest_pos: Array = []
var _inner: Node3D
var look_yaw := 0.0                # radians relative to the body, set by the NPC brain
var action := ""
var _action_t := 0.0
var _action_dur := 0.0
var _was_strike := false


func setup(p: Dictionary, name_: String = "Human") -> RealHuman:
	preset = p
	name = name_
	_seed = float(hash(name_) % 1000) * 0.01
	_t = _seed * 10.0
	_inner = Node3D.new()
	_inner.name = "Model"
	_inner.rotation.y = PI          # the models face +Z; we face -Z
	add_child(_inner)
	var body: String = p.get("body", "veteran")
	if body.begins_with("m_") or body.begins_with("w_"):
		_load("res://assets/people/" + body + ".glb")
	else:
		_load(DIR + body + ".glb")
		if p.get("robe", true):
			var rb := body
			if rb == "striker_mail":
				rb = "striker"
			_load(DIR + "robe_" + rb + ".glb")
	for k in BONES:
		_pose[k] = Vector3.ZERO
	_fit()
	_tint()
	if p.get("tool", "") == "hammer":
		_add_hammer()
	_apply()
	return self


func _load(path: String) -> void:
	var ps := load(path) as PackedScene
	if ps == null:
		push_warning("RealHuman: cannot load " + path)
		return
	var inst := ps.instantiate() as Node3D
	_inner.add_child(inst)
	for sk in inst.find_children("*", "Skeleton3D", true, false):
		_register(sk as Skeleton3D)


func _register(sk: Skeleton3D) -> void:
	var map: Dictionary = BONES_MOD if sk.find_bone("Hips") >= 0 else BONES_UBC
	var idx := {}
	for k in BONES:
		idx[k] = sk.find_bone(map[k])
	if idx["hips"] < 0:
		return
	_skins.append(sk)
	_bone_idx.append(idx)
	var rg: Array = []
	var order: Array = []
	for i in sk.get_bone_count():
		rg.append(sk.get_bone_global_rest(i).basis)
		order.append(i)
	_rest_g.append(rg)
	_order.append(order)
	_hips_rest_pos.append(sk.get_bone_rest(idx["hips"]).origin)
	var rot := {}
	for side in ["L", "R"]:
		var sh: int = idx["sh_" + side]
		var el: int = idx["el_" + side]
		var a := 1.3 * (1.0 if side == "L" else -1.0)
		if sh >= 0 and el >= 0:
			var d := sk.get_bone_global_rest(el).origin - sk.get_bone_global_rest(sh).origin
			# rotate the arm direction (in the XY plane) to hang straight down, keeping a small gap
			a = Vector2(d.x, d.y).angle_to(Vector2(0.0, -1.0))
			a *= 0.93
		rot[side] = a
	_arm_rot.append(rot)


## Scale to the preset height and stand on y = 0.
func _fit() -> void:
	var lo := INF
	var hi := -INF
	for m in _inner.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != _inner:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var bb := mi.mesh.get_aabb()
		for c in 8:
			var corner := bb.position + bb.size * Vector3(c & 1, (c >> 1) & 1, (c >> 2) & 1)
			var wp := xf * corner
			lo = minf(lo, wp.y)
			hi = maxf(hi, wp.y)
	var h := hi - lo
	if h < 0.3 or h > 6.0:
		h = 1.8
		lo = 0.0
	var s := TARGET_HEIGHT * float(preset.get("scale", 1.0)) / h
	_inner.scale = Vector3.ONE * s
	_inner.position.y = -lo * s


func _tint() -> void:
	var c: Color = preset.get("tint", Color(1, 1, 1))
	if c == Color(1, 1, 1):
		return
	for m in _inner.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat is StandardMaterial3D:
				var d := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.albedo_color = c
				mi.set_surface_override_material(s, d)


func _add_hammer() -> void:
	if _skins.is_empty() or _bone_idx[0]["wr_R"] < 0:
		return
	var sk0 := _skins[0]
	var att := BoneAttachment3D.new()
	att.bone_name = sk0.get_bone_name(_bone_idx[0]["wr_R"])
	_skins[0].add_child(att)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.2, 0.1)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.2, 0.2, 0.22)
	iron.metallic = 0.8
	iron.roughness = 0.45
	var handle := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.018
	hm.bottom_radius = 0.02
	hm.height = 0.4
	handle.mesh = hm
	handle.material_override = wood
	var head := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.14, 0.07, 0.07)
	head.mesh = bm
	head.material_override = iron
	head.position = Vector3(0, 0.2, 0)
	handle.add_child(head)
	handle.position = Vector3(0, 0.08, 0.04)
	handle.rotation.x = deg_to_rad(90.0)
	att.add_child(handle)


# --- pose application ----------------------------------------------------------------------

## Model-space rotation delta for a rig-style angle triple (rx = forward swing, as in the old rig).
static func _delta(r: Vector3) -> Basis:
	return Basis(Vector3.UP, r.y) * Basis(Vector3.BACK, r.z) * Basis(Vector3.RIGHT, -r.x)


func _apply() -> void:
	for si in _skins.size():
		var sk := _skins[si]
		var idx: Dictionary = _bone_idx[si]
		var rg: Array = _rest_g[si]
		var n := sk.get_bone_count()
		# model-space delta per bone, own part only
		var own: Array = []
		own.resize(n)
		for i in n:
			own[i] = Basis.IDENTITY
		for k in BONES:
			var bi: int = idx[k]
			if bi < 0:
				continue
			var d := _delta(_pose[k])
			if k.begins_with("sh_"):
				var side: String = k.substr(3)
				var a0: float = (_arm_rot[si] as Dictionary)[side]
				var r: Vector3 = _pose[k]
				# r.z = abduction in radians: raises the arm away from the hanging pose
				d = Basis(Vector3.UP, r.y) * Basis(Vector3.RIGHT, -r.x) * Basis(Vector3.BACK, a0 - signf(a0) * r.z)
			own[bi] = d
		# D_total(b) = D_total(parent) * own(b); global basis = D_total * restGlobal
		var dtot: Array = []
		dtot.resize(n)
		for i in n:
			var p := sk.get_bone_parent(i)
			dtot[i] = (dtot[p] if p >= 0 else Basis.IDENTITY) * own[i]
		for i in n:
			var p := sk.get_bone_parent(i)
			var b_i: Basis = (dtot[i] as Basis) * (rg[i] as Basis)
			var local: Basis
			if p >= 0:
				var b_p: Basis = (dtot[p] as Basis) * (rg[p] as Basis)
				local = b_p.inverse() * b_i
			else:
				local = b_i
			var rest_local := sk.get_bone_rest(i).basis
			sk.set_bone_pose_rotation(i, (rest_local.inverse() * local).get_rotation_quaternion())
		if idx["hips"] >= 0:
			sk.set_bone_pose_position(idx["hips"], (_hips_rest_pos[si] as Vector3) + Vector3(0, _hips_dy / maxf(_inner.scale.y, 0.01), 0))


# --- animation -----------------------------------------------------------------------------

func animate(delta: float, speed: float, grounded: bool) -> void:
	_t += delta
	_speed_smooth = lerpf(_speed_smooth, speed, 1.0 - exp(-10.0 * delta))
	_air = lerpf(_air, 0.0 if grounded else 1.0, 1.0 - exp(-14.0 * delta))
	match mode:
		"idle":
			_idle(delta)
		"hammer":
			_hammer()
		_:
			if _speed_smooth < 0.15 and _air < 0.05:
				_idle(delta)
			else:
				_locomotion(delta)
	_overlay(delta)
	_apply()


## Start a one-shot gesture ("wave", "namaste", "talk", "startle", "laugh", "point", "stretch",
## "look_around", "wipe_brow"). Layered over the idle pose.
func play_action(n: String, dur: float) -> void:
	action = n
	_action_t = 0.0
	_action_dur = dur


func _overlay(delta: float) -> void:
	# head turn toward a target (clamped), always available
	var hp: Vector3 = _pose["head"]
	hp.y = clampf(hp.y + look_yaw * 0.7, -1.1, 1.1)
	_pose["head"] = hp
	var np: Vector3 = _pose["neck"]
	np.y = clampf(look_yaw * 0.3, -0.5, 0.5)
	_pose["neck"] = np
	if action == "":
		return
	_action_t += delta
	if _action_t >= _action_dur:
		action = ""
		return
	var w := clampf(minf(_action_t / 0.3, (_action_dur - _action_t) / 0.35), 0.0, 1.0)
	w = w * w * (3.0 - 2.0 * w)
	var t := _action_t
	var tgt := {}
	match action:
		"wave":
			tgt["sh_R"] = Vector3(0.0, 0.0, 2.0 + 0.0)
			tgt["el_R"] = Vector3(-0.4 + 0.55 * sin(t * 9.0), 0.0, 0.0)
			tgt["head"] = Vector3(0.0, 0.0, 0.0)
		"namaste":
			tgt["sh_L"] = Vector3(0.55, 0.0, 0.25)
			tgt["sh_R"] = Vector3(0.55, 0.0, 0.25)
			tgt["el_L"] = Vector3(1.95, 0.0, 0.0)
			tgt["el_R"] = Vector3(1.95, 0.0, 0.0)
			tgt["head"] = Vector3(0.28, 0.0, 0.0)
			tgt["spine"] = Vector3(-0.12, 0.0, 0.0)
		"talk":
			tgt["sh_R"] = Vector3(0.35 + 0.2 * sin(t * 3.1), 0.0, 0.25)
			tgt["el_R"] = Vector3(0.9 + 0.35 * sin(t * 4.1), 0.0, 0.0)
			tgt["sh_L"] = Vector3(0.25 + 0.15 * sin(t * 2.7 + 1.0), 0.0, 0.18)
			tgt["el_L"] = Vector3(0.7 + 0.3 * sin(t * 3.3 + 1.0), 0.0, 0.0)
			tgt["head"] = Vector3(0.05 * sin(t * 5.0), 0.12 * sin(t * 1.3), 0.0)
		"startle":
			tgt["spine"] = Vector3(0.22, 0.0, 0.0)
			tgt["head"] = Vector3(-0.15, 0.0, 0.0)
			tgt["sh_L"] = Vector3(0.0, 0.0, 0.9)
			tgt["sh_R"] = Vector3(0.0, 0.0, 0.9)
			tgt["el_L"] = Vector3(0.5, 0.0, 0.0)
			tgt["el_R"] = Vector3(0.5, 0.0, 0.0)
			tgt["hip_L"] = Vector3(0.1, 0.0, 0.0)
			tgt["hip_R"] = Vector3(-0.2, 0.0, 0.0)
			tgt["kn_R"] = Vector3(-0.3, 0.0, 0.0)
		"laugh":
			tgt["chest"] = Vector3(0.06 * sin(t * 18.0), 0.0, 0.0)
			tgt["spine"] = Vector3(0.1 + 0.04 * sin(t * 18.0), 0.0, 0.0)
			tgt["head"] = Vector3(-0.22 + 0.05 * sin(t * 18.0), 0.0, 0.0)
			tgt["sh_L"] = Vector3(0.4, 0.0, 0.1)
			tgt["sh_R"] = Vector3(0.4, 0.0, 0.1)
			tgt["el_L"] = Vector3(1.0, 0.0, 0.0)
			tgt["el_R"] = Vector3(1.0, 0.0, 0.0)
		"point":
			tgt["sh_R"] = Vector3(1.45, 0.0, 0.15)
			tgt["el_R"] = Vector3(0.1, 0.0, 0.0)
			tgt["spine"] = Vector3(-0.05, 0.15, 0.0)
		"stretch":
			tgt["sh_L"] = Vector3(0.0, 0.0, 2.6)
			tgt["sh_R"] = Vector3(0.0, 0.0, 2.6)
			tgt["el_L"] = Vector3(0.2, 0.0, 0.0)
			tgt["el_R"] = Vector3(0.2, 0.0, 0.0)
			tgt["spine"] = Vector3(0.14, 0.0, 0.0)
			tgt["head"] = Vector3(-0.25, 0.0, 0.0)
		"look_around":
			tgt["head"] = Vector3(0.0, 0.8 * sin(t * 1.5), 0.0)
		"wipe_brow":
			tgt["sh_R"] = Vector3(1.9, 0.0, 0.4)
			tgt["el_R"] = Vector3(1.6 + 0.12 * sin(t * 7.0), 0.0, 0.0)
			tgt["head"] = Vector3(0.12, 0.0, 0.0)
	for k in tgt:
		var base: Vector3 = _pose[k]
		var goal: Vector3 = tgt[k]
		_pose[k] = base.lerp(goal, w)

func _ease(key: String, target: Vector3, rate: float, delta: float) -> void:
	_pose[key] = (_pose[key] as Vector3).lerp(target, 1.0 - exp(-rate * delta))


func _idle(delta: float) -> void:
	var breathe := sin(_t * 1.7 + _seed)
	var sway := sin(_t * 0.6 + _seed * 3.0)
	_hips_dy = lerpf(_hips_dy, 0.0, 1.0 - exp(-8.0 * delta))
	_ease("hips", Vector3(0, 0, 0.012 * sway), 8.0, delta)
	_ease("spine", Vector3(-0.02 + 0.01 * breathe, 0.0, -0.012 * sway), 8.0, delta)
	_ease("chest", Vector3(0.012 * breathe, 0.0, 0.0), 8.0, delta)
	var look := sin(_t * 0.37 + _seed * 7.0)
	_ease("head", Vector3(0.03 * sin(_t * 0.5), 0.35 * look, 0.0), 3.0, delta)
	for tag in ["L", "R"]:
		_ease("sh_" + tag, Vector3(0.03 * breathe, 0.0, 0.0), 8.0, delta)
		_ease("el_" + tag, Vector3(0.18 + 0.02 * breathe, 0.0, 0.0), 8.0, delta)
		_ease("hip_" + tag, Vector3.ZERO, 10.0, delta)
		_ease("kn_" + tag, Vector3(-0.02, 0.0, 0.0), 10.0, delta)
		_ease("an_" + tag, Vector3.ZERO, 10.0, delta)


func _hammer() -> void:
	var c := fmod(_t * 1.5, TAU)
	var up := 0.5 + 0.5 * sin(c)
	var strike := pow(maxf(0.0, -sin(c + 0.4)), 3.0)
	var hit := strike > 0.85
	if hit and not _was_strike:
		struck.emit()
	_was_strike = hit
	_hips_dy = -0.02 * strike
	_pose["hips"] = Vector3.ZERO
	_pose["spine"] = Vector3(-0.12 - 0.12 * strike, 0.18, 0.0)
	_pose["chest"] = Vector3.ZERO
	_pose["head"] = Vector3(0.18 + 0.05 * strike, -0.15, 0.0)
	_pose["sh_R"] = Vector3(-0.9 - 1.0 * up, 0.0, 0.0)
	_pose["el_R"] = Vector3(0.6 + 1.0 * up - 0.5 * strike, 0.0, 0.0)
	_pose["sh_L"] = Vector3(-0.7, 0.0, 0.0)
	_pose["el_L"] = Vector3(0.9, 0.0, 0.0)
	for tag in ["L", "R"]:
		_pose["hip_" + tag] = Vector3(0.12 if tag == "L" else -0.1, 0.0, 0.0)
		_pose["kn_" + tag] = Vector3(-0.14, 0.0, 0.0)
		_pose["an_" + tag] = Vector3.ZERO


func _locomotion(delta: float) -> void:
	var sp := _speed_smooth
	var run_k := smoothstep(2.8, 5.0, sp)
	var freq := sp / (1.2 + 0.5 * sp)
	_phase = fmod(_phase + TAU * freq * delta, TAU)
	var stride := clampf(sp / 2.6, 0.0, 1.0)
	var amp := lerpf(0.42, 0.85, run_k) * minf(1.0, stride + 0.3)
	var air := _air
	for side in [0, 1]:
		var tag := "L" if side == 0 else "R"
		var ph := _phase + (PI if side == 1 else 0.0)
		var swing := sin(ph)
		var flex := (0.15 + lerpf(0.55, 1.15, run_k) * maxf(0.0, cos(ph + 0.35))) * minf(1.0, stride + 0.2)
		_pose["hip_" + tag] = Vector3(lerpf(amp * swing, -0.65 if side == 0 else -0.15, air), 0.0, 0.0)
		_pose["kn_" + tag] = Vector3(-lerpf(flex, 1.1 if side == 0 else 0.6, air), 0.0, 0.0)
		_pose["an_" + tag] = Vector3(lerpf(-0.25 * cos(ph + 0.35) * stride + 0.4 * maxf(0.0, -swing) * 0.4, 0.3, air), 0.0, 0.0)
		var arm_swing := -sin(ph) * lerpf(0.38, 0.8, run_k) * minf(1.0, stride + 0.2)
		_pose["sh_" + tag] = Vector3(lerpf(arm_swing, -0.4, air), 0.0, 0.0)
		_pose["el_" + tag] = Vector3(lerpf(0.22 + lerpf(0.1, 1.0, run_k) * (0.5 + 0.5 * maxf(0.0, -sin(ph))), 0.5, air), 0.0, 0.0)
	var bob := (0.018 + 0.03 * run_k) * stride
	_hips_dy = -bob * (1.0 - cos(2.0 * _phase)) * 0.5
	_pose["hips"] = Vector3(0.0, 0.14 * sin(_phase) * stride, -0.03 * sin(_phase) * stride)
	var lean := 0.03 + 0.07 * stride + 0.14 * run_k
	_pose["spine"] = Vector3(-lean, -0.2 * sin(_phase) * stride, 0.025 * sin(_phase) * stride)
	_pose["chest"] = Vector3.ZERO
	_pose["head"] = Vector3(lean * 0.8 - 0.02, 0.1 * sin(_phase) * stride, 0.0)
