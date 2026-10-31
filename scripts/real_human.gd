class_name RealHuman
extends Node3D

signal attack_hit                # the swing reaches its impact frame (combat)
signal struck                    # the hammer hits the anvil (hammer mode)
signal move_hit(move: String)    # impact frame of a punch / kick / throw
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
var attack_t := -1.0             # >= 0 while a combat swing plays (seconds since start)
var _attack_hit_sent := false
const WORK_MODES := ["hammer", "scrub", "sweep", "stir", "knead", "chop", "hawk", "haggle", "sit", "sit_talk"]
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
var _frame: Array = []             # per skeleton: Basis mapping skeleton space to model space (with scale)
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
	elif p.get("tool", "") != "":
		_add_prop(String(p["tool"]))
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
	var fb := Basis.IDENTITY
	var nd: Node = sk
	while nd != null and nd != _inner:
		if nd is Node3D:
			fb = (nd as Node3D).transform.basis * fb
		nd = nd.get_parent()
	_frame.append(fb)
	var rot := {}
	for side in ["L", "R"]:
		var sh: int = idx["sh_" + side]
		var el: int = idx["el_" + side]
		var a := 1.3 * (1.0 if side == "L" else -1.0)
		if sh >= 0 and el >= 0:
			var d: Vector3 = fb * (sk.get_bone_global_rest(el).origin - sk.get_bone_global_rest(sh).origin)
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


const DRESS := [
	Color(0.86, 0.16, 0.18), Color(0.12, 0.42, 0.80), Color(0.96, 0.72, 0.10), Color(0.12, 0.62, 0.36),
	Color(0.94, 0.42, 0.08), Color(0.62, 0.16, 0.64), Color(0.06, 0.58, 0.64), Color(0.94, 0.30, 0.52),
	Color(0.98, 0.84, 0.30), Color(0.40, 0.26, 0.72),
]
const KEEP := ["skin", "eye", "eyes", "eyebrows", "hair", "teeth", "mouth", "tongue", "beard", "black", "brown"]


## Dress the body in colour: skin, hair and eyes keep their own materials, every garment gets a
## vivid colour (the preset's tint, plus a contrasting second colour for trims and sashes).
func _tint() -> void:
	var has_tint := preset.has("tint")
	var c: Color = preset.get("tint", Color(1, 1, 1))
	var h := absi(hash(str(c) + str(preset.get("body", "")) + str(get_instance_id()))) 
	var main_c: Color = DRESS[h % DRESS.size()]
	var trim_c: Color = DRESS[(h / 7 + 3) % DRESS.size()]
	if has_tint and c != Color(1, 1, 1):
		# keep the role's hue (guards stay blue-ish, Reavers red-ish) but make it rich, not washed out
		main_c = Color.from_hsv(c.h, clampf(c.s * 1.5 + 0.35, 0.45, 0.95), clampf(c.v * 0.9, 0.35, 0.95))
		trim_c = DRESS[(h / 7 + 3) % DRESS.size()].lerp(main_c, 0.3)
	var n := 0
	for m in _inner.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for sidx in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(sidx)
			if not (mat is StandardMaterial3D):
				continue
			var nm := mat.resource_name.to_lower()
			if nm in KEEP:
				continue
			var d := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			d.albedo_color = main_c if n % 2 == 0 else trim_c
			d.roughness = 0.85
			mi.set_surface_override_material(sidx, d)
			n += 1


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
			var fn: Basis = (_frame[si] as Basis).orthonormalized()
			own[bi] = fn.inverse() * d * fn
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
			sk.set_bone_pose_rotation(i, local.orthonormalized().get_rotation_quaternion())
		if idx["hips"] >= 0:
			var off: Vector3 = (_frame[si] as Basis).inverse() * Vector3(0, _hips_dy / maxf(_inner.scale.y, 0.01), 0)
			var hp: int = idx["hips"]
			var pp := sk.get_bone_parent(hp)
			var pb: Basis = (rg[pp] as Basis) if pp >= 0 else Basis.IDENTITY
			sk.set_bone_pose_position(hp, sk.get_bone_rest(hp).origin + pb.inverse() * off)


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
		"scrub", "sweep", "stir", "knead", "chop", "hawk", "haggle", "sit", "sit_talk":
			_work(mode)
		_:
			if _speed_smooth < 0.15 and _air < 0.05:
				_idle(delta)
			else:
				_locomotion(delta)
	if move != "":
		move_t += delta
		_move_pose()
		if move_t >= _move_hit_at and not _move_sent:
			_move_sent = true
			move_hit.emit(move)
		if move_t >= _move_dur:
			move = ""
	elif react != "":
		react_t += delta
		_react_pose()
	if attack_t >= 0.0:
		attack_t += delta
		_attack_pose()
		if attack_t >= 0.34 and not _attack_hit_sent:
			_attack_hit_sent = true
			attack_hit.emit()
		if attack_t > 0.75:
			attack_t = -1.0
	_body_overlays(delta)
	_overlay(delta)
	_apply()


# --- unarmed fighting and reactions ------------------------------------------------------------
## Moves: jab, cross, hook, uppercut, kick_front, kick_round, kick_side, grab, lift, throw.
## Reactions (looping until cleared): flinch, stagger, plead, held, clutch, sob, crawl.
const MOVES := {
	"jab": [0.38, 0.12], "cross": [0.42, 0.15], "hook": [0.46, 0.17], "uppercut": [0.5, 0.2],
	"kick_front": [0.55, 0.22], "kick_round": [0.72, 0.3], "kick_side": [0.62, 0.26],
	"grab": [0.4, 0.3], "lift": [0.5, 0.5], "throw": [0.45, 0.12],
}
var move := ""
var move_t := 0.0
var _move_dur := 0.0
var _move_hit_at := 0.0
var _move_sent := false
var react := ""
var react_t := 0.0


func play_move(n: String) -> void:
	if not MOVES.has(n):
		return
	move = n
	move_t = 0.0
	_move_dur = MOVES[n][0]
	_move_hit_at = MOVES[n][1]
	_move_sent = false


func move_busy() -> bool:
	return move != ""


func set_react(n: String) -> void:
	if react != n:
		react = n
		react_t = 0.0


func _pz(key: String, v: Vector3, w: float = 1.0) -> void:
	_pose[key] = (_pose[key] as Vector3).lerp(v, w)


## Pose for the current move at time move_t. Arms/legs are written directly (no easing) so the
## blows snap; an ease-in/out envelope keeps the transitions smooth.
func _move_pose() -> void:
	var t := move_t
	var d := _move_dur
	var hit := _move_hit_at
	var wind := smoothstep(0.0, hit, t)                       # 0 -> 1 up to the impact
	var out := 1.0 - smoothstep(hit + 0.04, d, t)             # 1 -> 0 afterwards
	var e := wind * out                                       # overall strength
	var snap := smoothstep(hit - 0.06, hit, t) * out          # the strike itself
	var guard_l := Vector3(-0.95, 0.0, 0.12)
	var guard_r := Vector3(-0.95, 0.0, 0.0)
	match move:
		"jab":
			_pz("sh_L", guard_l.lerp(Vector3(-1.5, 0.0, 0.0), snap))
			_pz("el_L", Vector3(1.7, 0, 0).lerp(Vector3(0.05, 0, 0), snap))
			_pz("sh_R", guard_r); _pz("el_R", Vector3(1.7, 0, 0))
			_pose["spine"] = Vector3(-0.1 * e, 0.28 * snap, 0)
			_pose["hips"] = Vector3(0, 0.1 * snap, 0)
			_pz("hip_L", Vector3(-0.25 * e, 0, 0)); _pz("kn_L", Vector3(-0.2 * e, 0, 0))
			_pz("hip_R", Vector3(0.2 * e, 0, 0)); _pz("kn_R", Vector3(-0.15 * e, 0, 0))
			_hips_dy = -0.04 * e
		"cross":
			_pz("sh_R", guard_r.lerp(Vector3(-1.55, 0.0, 0.0), snap))
			_pz("el_R", Vector3(1.7, 0, 0).lerp(Vector3(0.05, 0, 0), snap))
			_pz("sh_L", guard_l); _pz("el_L", Vector3(1.7, 0, 0))
			_pose["spine"] = Vector3(-0.15 * e, -0.55 * snap + 0.2 * wind * (1.0 - snap), 0)
			_pose["hips"] = Vector3(0, -0.3 * snap, 0)
			_pz("hip_L", Vector3(-0.3 * e, 0, 0)); _pz("kn_L", Vector3(-0.3 * e, 0, 0))
			_pz("hip_R", Vector3(0.35 * e, 0, 0)); _pz("kn_R", Vector3(-0.2 * e, 0, 0))
			_hips_dy = -0.06 * e
		"hook":
			_pz("sh_L", Vector3(-1.35, 0.0, 1.35 * (1.0 - snap) + 0.25 * snap))
			_pz("el_L", Vector3(1.55, 0, 0))
			_pz("sh_R", guard_r); _pz("el_R", Vector3(1.7, 0, 0))
			_pose["spine"] = Vector3(-0.1 * e, 0.6 * wind * (1.0 - snap) - 0.45 * snap, 0.12 * e)
			_pose["hips"] = Vector3(0, 0.25 * wind * (1.0 - snap) - 0.3 * snap, 0)
			_pz("hip_R", Vector3(0.25 * e, 0, 0)); _pz("kn_R", Vector3(-0.25 * e, 0, 0))
			_hips_dy = -0.08 * e
		"uppercut":
			var crouch := smoothstep(0.0, hit * 0.7, t) * (1.0 - smoothstep(hit * 0.7, hit + 0.05, t))
			_pz("sh_R", Vector3(-0.6 - 1.55 * snap, 0.0, 0.0))
			_pz("el_R", Vector3(1.9 - 1.3 * snap, 0, 0))
			_pz("sh_L", guard_l); _pz("el_L", Vector3(1.7, 0, 0))
			_pose["spine"] = Vector3(0.2 * crouch - 0.25 * snap, -0.25 * snap, 0)
			_hips_dy = -0.22 * crouch + 0.04 * snap
			for tg in ["L", "R"]:
				_pz("hip_" + tg, Vector3(-0.55 * crouch, 0, 0)); _pz("kn_" + tg, Vector3(-1.0 * crouch, 0, 0))
		"kick_front":
			var lift := smoothstep(0.0, hit, t) * out
			_pz("hip_R", Vector3(1.5 * lift, 0, 0)); _pz("kn_R", Vector3(-1.1 * (1.0 - snap) * wind - 0.05, 0, 0))
			_pz("hip_L", Vector3(-0.1 * lift, 0, 0)); _pz("kn_L", Vector3(-0.2 * lift, 0, 0))
			_pose["spine"] = Vector3(0.28 * lift, 0, 0)
			_pose["hips"] = Vector3(0.0, 0.0, 0.0)
			_pz("sh_L", Vector3(-0.6, 0, 0.7 * lift)); _pz("sh_R", Vector3(0.2, 0, 0.6 * lift))
			_pz("el_L", Vector3(0.9, 0, 0)); _pz("el_R", Vector3(0.9, 0, 0))
			_hips_dy = -0.05 * lift
		"kick_round":
			var spin := smoothstep(0.0, hit + 0.08, t) * out
			_pose["hips"] = Vector3(0, -1.2 * spin, 0)
			_pose["spine"] = Vector3(0.1 * spin, -0.8 * spin, -0.15 * spin)
			_pz("hip_R", Vector3(-1.45 * spin, 0, 0)); _pz("kn_R", Vector3(-0.2 * spin - 0.15 * (1.0 - snap) * wind, 0, 0))
			_pz("hip_L", Vector3(0.05, 0, 0)); _pz("kn_L", Vector3(-0.3 * spin, 0, 0))
			_pz("sh_L", Vector3(-0.5, 0, 1.2 * spin)); _pz("sh_R", Vector3(-0.3, 0, 1.0 * spin))
			_pz("el_L", Vector3(0.5, 0, 0)); _pz("el_R", Vector3(0.5, 0, 0))
			_hips_dy = -0.04 * spin
		"kick_side":
			var l2 := smoothstep(0.0, hit, t) * out
			_pose["hips"] = Vector3(0, 0.8 * l2, 0.0)
			_pose["spine"] = Vector3(0.0, 0.3 * l2, 0.5 * l2)
			_pz("hip_R", Vector3(-1.2 * l2, 0, 1.1 * l2)); _pz("kn_R", Vector3(-0.15 * snap - 0.8 * (1.0 - snap) * wind, 0, 0))
			_pz("hip_L", Vector3(0, 0, 0)); _pz("kn_L", Vector3(-0.25 * l2, 0, 0))
			_pz("sh_L", Vector3(-0.8, 0, 0.9 * l2)); _pz("sh_R", Vector3(-0.8, 0, 0.9 * l2))
			_pz("el_L", Vector3(1.0, 0, 0)); _pz("el_R", Vector3(1.0, 0, 0))
		"grab":
			var g := smoothstep(0.0, hit, t) * (1.0 - smoothstep(hit, d, t) * 0.3)
			for tg in ["L", "R"]:
				_pz("sh_" + tg, Vector3(-1.45 * g, 0, 0.25 * g)); _pz("el_" + tg, Vector3(0.6 * g, 0, 0))
			_pose["spine"] = Vector3(-0.25 * g, 0, 0)
			_hips_dy = -0.1 * g
			for tg in ["L", "R"]:
				_pz("hip_" + tg, Vector3(-0.3 * g, 0, 0)); _pz("kn_" + tg, Vector3(-0.5 * g, 0, 0))
		"lift":
			var l3 := smoothstep(0.0, d * 0.8, t)
			for tg in ["L", "R"]:
				_pz("sh_" + tg, Vector3(-1.45 - 1.4 * l3, 0, 0.3 * l3)); _pz("el_" + tg, Vector3(0.6 - 0.2 * l3, 0, 0))
			_pose["spine"] = Vector3(-0.25 + 0.55 * l3, 0, 0)
			_hips_dy = -0.1 + 0.1 * l3
		"throw":
			var th := smoothstep(0.0, hit, t) * (1.0 - smoothstep(hit, d, t))
			for tg in ["L", "R"]:
				_pz("sh_" + tg, Vector3(-2.85 + 1.7 * smoothstep(0.0, hit, t), 0, 0.3)); _pz("el_" + tg, Vector3(0.4, 0, 0))
			_pose["spine"] = Vector3(0.3 - 0.75 * smoothstep(0.0, hit + 0.05, t) * (1.0 - smoothstep(hit + 0.1, d, t) * 0.6), 0, 0)
			_hips_dy = -0.14 * smoothstep(0.0, hit, t) * out
			_pz("hip_L", Vector3(-0.5 * th, 0, 0)); _pz("kn_L", Vector3(-0.6 * th, 0, 0))
	# glance toward the blow
	_pose["head"] = Vector3(0.05, 0, 0)


## Pose for a reaction (looping). Written after the base pose so it wins.
func _react_pose() -> void:
	var t := react_t
	match react:
		"flinch":
			var k := exp(-t * 6.0)
			_pose["head"] = Vector3(-0.5 * k, 0.25 * k, 0)
			_pose["spine"] = Vector3(0.3 * k, 0.15 * k, 0)
			_pz("sh_L", Vector3(0.3 * k, 0, 0.5 * k)); _pz("sh_R", Vector3(0.3 * k, 0, 0.5 * k))
		"stagger":
			var k2 := 0.6 + 0.4 * sin(t * 9.0)
			_pose["spine"] = Vector3(0.35, 0.12 * sin(t * 6.0), 0.08 * sin(t * 7.0))
			_pose["head"] = Vector3(-0.3, 0.2 * sin(t * 5.0), 0)
			_pz("sh_L", Vector3(-0.2, 0, 1.0 * k2)); _pz("sh_R", Vector3(-0.2, 0, 1.0 * (1.2 - k2)))
			_pz("el_L", Vector3(0.6, 0, 0)); _pz("el_R", Vector3(0.6, 0, 0))
			_pz("hip_L", Vector3(-0.35 * sin(t * 8.0), 0, 0)); _pz("hip_R", Vector3(0.35 * sin(t * 8.0), 0, 0))
			_pz("kn_L", Vector3(-0.3, 0, 0)); _pz("kn_R", Vector3(-0.3, 0, 0))
		"plead":
			var sh := sin(t * 14.0) * 0.04
			_hips_dy = -0.5
			for tg in ["L", "R"]:
				_pz("hip_" + tg, Vector3(-0.1, 0, 0)); _pz("kn_" + tg, Vector3(-2.3, 0, 0))
				_pz("sh_" + tg, Vector3(-1.0 + sh, 0, 0.12)); _pz("el_" + tg, Vector3(1.9 + sh, 0, 0))
			_pose["spine"] = Vector3(-0.2 + 0.03 * sin(t * 3.0), 0, 0)
			_pose["head"] = Vector3(0.3 + 0.1 * sin(t * 3.4), 0.1 * sin(t * 1.6), 0)
		"sob":
			var b := sin(t * 5.2)
			_hips_dy = -0.5
			for tg in ["L", "R"]:
				_pz("hip_" + tg, Vector3(-0.1, 0, 0)); _pz("kn_" + tg, Vector3(-2.3, 0, 0))
				_pz("sh_" + tg, Vector3(-0.9, 0, 0.0)); _pz("el_" + tg, Vector3(2.3, 0, 0))
			_pose["spine"] = Vector3(-0.45 + 0.06 * b, 0, 0)
			_pose["head"] = Vector3(0.65 + 0.05 * b, 0, 0)
		"held":
			var w := t * 11.0
			_hips_dy = 0.0
			_pz("sh_L", Vector3(-0.2 + 0.6 * sin(w), 0, 0.9 + 0.5 * sin(w * 1.3))); _pz("sh_R", Vector3(-0.2 + 0.6 * sin(w + 2.0), 0, 0.9 + 0.5 * sin(w * 1.1)))
			_pz("el_L", Vector3(0.5 + 0.4 * sin(w), 0, 0)); _pz("el_R", Vector3(0.5 + 0.4 * sin(w + 1.0), 0, 0))
			_pz("hip_L", Vector3(-0.6 + 0.7 * sin(w * 1.2), 0, 0.2)); _pz("hip_R", Vector3(-0.2 + 0.7 * sin(w * 1.2 + 2.5), 0, -0.2))
			_pz("kn_L", Vector3(-0.5 - 0.4 * sin(w), 0, 0)); _pz("kn_R", Vector3(-0.5 + 0.4 * sin(w), 0, 0))
			_pose["spine"] = Vector3(0.1 * sin(w), 0, 0.15 * sin(w * 0.8))
			_pose["head"] = Vector3(-0.4, 0.3 * sin(w * 0.7), 0)
		"clutch":
			_pz("sh_L", Vector3(-0.45, 0, 0.1)); _pz("sh_R", Vector3(-0.45, 0, 0.1))
			_pz("el_L", Vector3(2.3, 0, 0)); _pz("el_R", Vector3(2.3, 0, 0))
			_pose["spine"] = Vector3(-0.6, 0, 0.1 * sin(t * 12.0))
			_pose["head"] = Vector3(0.5, 0, 0)
			_hips_dy = -0.12
			_pz("hip_L", Vector3(-0.4, 0, 0)); _pz("hip_R", Vector3(-0.4, 0, 0))
			_pz("kn_L", Vector3(-0.8, 0, 0)); _pz("kn_R", Vector3(-0.8, 0, 0))
		"ride":
			# Seated astride: thighs open to the sides, knees bent with the heels drawn up, upright back that
			# leans forward at speed, hands low and forward on the reins, hips bouncing with the gait; the rider
			# leans into turns and rises out of the saddle when the animal leaps.
			var k := ride_k
			var gait := sin(t * (7.0 + 6.0 * k))
			var lean := 0.06 + 0.32 * k
			_hips_dy = -0.5 + gait * (0.012 + 0.03 * k) + 0.16 * ride_air + 0.05 * k
			for tg in ["L", "R"]:
				var sg := 1.0 if tg == "L" else -1.0
				_pz("hip_" + tg, Vector3(0.62 + 0.25 * k + 0.2 * ride_air, 0, 0.6 * sg))
				_pz("kn_" + tg, Vector3(-1.0 - 0.3 * k - 0.3 * ride_air, 0, 0))
				_pz("sh_" + tg, Vector3(-0.8 - 0.35 * k - 0.15 * gait * k, 0, 0.14 * sg))
				_pz("el_" + tg, Vector3(1.15 + 0.2 * k, 0, 0))
			_pose["spine"] = Vector3(-lean + 0.025 * gait, -0.1 * ride_turn, 0.16 * ride_turn)
			_pose["hips"] = Vector3(0.0, 0.0, -0.05 * ride_turn)
			_pose["head"] = Vector3(lean * 0.75 - 0.02, 0.1 * ride_turn, -0.08 * ride_turn)
		"block":
			# guard up: forearms in front of the face, knees soft, weight sunk
			_hips_dy = -0.16
			_pz("sh_L", Vector3(-1.15, 0, 0.22)); _pz("sh_R", Vector3(-1.15, 0, -0.22))
			_pz("el_L", Vector3(2.15, 0, 0)); _pz("el_R", Vector3(2.15, 0, 0))
			_pz("hip_L", Vector3(0.3, 0, 0.12)); _pz("hip_R", Vector3(-0.15, 0, -0.12))
			_pz("kn_L", Vector3(-0.55, 0, 0)); _pz("kn_R", Vector3(-0.5, 0, 0))
			_pose["spine"] = Vector3(-0.22, 0.2, 0)
			_pose["head"] = Vector3(0.22, 0, 0)
		"dead":
			_pz("sh_L", Vector3(-0.1, 0, 1.15)); _pz("sh_R", Vector3(-0.3, 0, 0.9))
			_pz("el_L", Vector3(0.3, 0, 0)); _pz("el_R", Vector3(0.7, 0, 0))
			_pz("hip_L", Vector3(0.0, 0, 0.3)); _pz("hip_R", Vector3(-0.1, 0, -0.2))
			_pz("kn_L", Vector3(-0.1, 0, 0)); _pz("kn_R", Vector3(-0.3, 0, 0))
			_pose["head"] = Vector3(-0.2, 0.5, 0.2)
			_pose["spine"] = Vector3(0.0, 0.2, 0.1)
		"crawl":
			var c := sin(t * 7.0)
			_pz("sh_L", Vector3(-2.3 + 0.5 * c, 0, 0.3)); _pz("sh_R", Vector3(-2.3 - 0.5 * c, 0, 0.3))
			_pz("el_L", Vector3(0.5, 0, 0)); _pz("el_R", Vector3(0.5, 0, 0))
			_pz("hip_L", Vector3(0.2 * c, 0, 0)); _pz("hip_R", Vector3(-0.2 * c, 0, 0))
			_pose["head"] = Vector3(-0.8, 0, 0)


func start_attack() -> void:
	if attack_t < 0.0:
		attack_t = 0.0
		_attack_hit_sent = false


## Overhead smash: wind up (0..0.3 s), fast strike (0.3..0.42), recover.
func _attack_pose() -> void:
	var t := attack_t
	var wind := smoothstep(0.0, 0.3, t)
	var strike := smoothstep(0.3, 0.4, t)
	var rec := smoothstep(0.45, 0.75, t)
	var up := wind * (1.0 - strike) + strike * 0.0
	var down := strike * (1.0 - rec)
	_pose["spine"] = Vector3(0.25 * wind * (1.0 - strike) - 0.38 * down, -0.2 * wind * (1.0 - rec), 0.0)
	_pose["chest"] = Vector3(0.1 * wind - 0.12 * down, 0.0, 0.0)
	_pose["head"] = Vector3(-0.1 * wind + 0.2 * down, 0.0, 0.0)
	_pose["sh_R"] = Vector3(-0.5 - 2.4 * up - 0.4 * down, 0.0, 0.2)
	_pose["el_R"] = Vector3(0.5 + 0.9 * up - 0.5 * down, 0.0, 0.0)
	_pose["sh_L"] = Vector3(-0.7 - 0.6 * up, 0.0, 0.0)
	_pose["el_L"] = Vector3(0.9, 0.0, 0.0)
	_hips_dy = -0.05 * down


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



## Simple hand-held props for market work: broom, ladle, knife, cloth, basket.
func _add_prop(kind: String) -> void:
	if _skins.is_empty() or _bone_idx[0]["wr_R"] < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = _skins[0].get_bone_name(_bone_idx[0]["wr_R"])
	_skins[0].add_child(att)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.28, 0.14)
	var root := Node3D.new()
	root.position = Vector3(0, 0.08, 0.04)
	att.add_child(root)
	var add := func(size: Vector3, pos: Vector3, col: Color) -> void:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		m.mesh = b
		var mt := StandardMaterial3D.new()
		mt.albedo_color = col
		m.material_override = mt
		m.position = pos
		root.add_child(m)
	match kind:
		"broom":
			add.call(Vector3(0.025, 1.2, 0.025), Vector3(0, -0.2, 0), Color(0.4, 0.28, 0.14))
			add.call(Vector3(0.28, 0.2, 0.08), Vector3(0, -0.85, 0), Color(0.75, 0.62, 0.3))
		"ladle":
			add.call(Vector3(0.02, 0.5, 0.02), Vector3(0, -0.1, 0), Color(0.4, 0.28, 0.14))
			add.call(Vector3(0.09, 0.05, 0.09), Vector3(0, -0.36, 0), Color(0.3, 0.2, 0.1))
		"knife":
			add.call(Vector3(0.03, 0.3, 0.01), Vector3(0, -0.15, 0), Color(0.75, 0.78, 0.82))
			add.call(Vector3(0.03, 0.1, 0.03), Vector3(0, 0.05, 0), Color(0.3, 0.2, 0.1))
		"cloth":
			add.call(Vector3(0.3, 0.02, 0.22), Vector3(0, -0.1, 0), Color(0.9, 0.9, 0.85))
		"basket":
			add.call(Vector3(0.3, 0.16, 0.3), Vector3(0, -0.12, 0), Color(0.7, 0.55, 0.25))


var _beat_prev := false
var crouch := 0.0                # 0 standing .. 1 crouched (smoothed toward crouch_target)
var crouch_target := 0.0
var ride_k := 0.0                # 0 walking .. 1 galloping (set by the mount system)
var ride_turn := 0.0             # -1..1 how hard the animal is turning
var air_vy := 0.0                # player's vertical speed, shapes the jump pose
var ride_air := 0.0              # 1 while the animal is in the air
var turn_lean := 0.0             # -1..1, set by the player: lean into turns while moving
var _lean_s := 0.0
var _land_t := 0.0
var _land_k := 0.0


## Landing recovery: knees absorb the impact, then the body rises again.
func land(impact: float) -> void:
	_land_k = clampf(impact / 14.0, 0.25, 1.0)
	_land_t = 0.42


## Crouch, lean into turns and landing recovery are layered over whatever the base animation wrote.
func _body_overlays(delta: float) -> void:
	crouch = lerpf(crouch, crouch_target, 1.0 - exp(-10.0 * delta))
	_lean_s = lerpf(_lean_s, turn_lean, 1.0 - exp(-6.0 * delta))
	if crouch > 0.01:
		var c := crouch
		_hips_dy -= 0.42 * c
		for tg in ["L", "R"]:
			_pose["hip_" + tg] = (_pose["hip_" + tg] as Vector3) + Vector3(0.75 * c, 0.0, 0.0)
			_pose["kn_" + tg] = (_pose["kn_" + tg] as Vector3) + Vector3(-1.35 * c, 0.0, 0.0)
		_pose["spine"] = (_pose["spine"] as Vector3) + Vector3(-0.3 * c, 0.0, 0.0)
		_pose["head"] = (_pose["head"] as Vector3) + Vector3(0.28 * c, 0.0, 0.0)
	if absf(_lean_s) > 0.01 and _speed_smooth > 1.0:
		var l := _lean_s * clampf(_speed_smooth / 5.0, 0.2, 1.0)
		_pose["spine"] = (_pose["spine"] as Vector3) + Vector3(0.0, 0.0, 0.2 * l)
		_pose["hips"] = (_pose["hips"] as Vector3) + Vector3(0.0, 0.0, 0.08 * l)
		_pose["head"] = (_pose["head"] as Vector3) + Vector3(0.0, 0.0, -0.12 * l)
	if _land_t > 0.0:
		_land_t = maxf(0.0, _land_t - delta)
		var ph := 1.0 - _land_t / 0.42                      # 0 -> 1
		var env := sin(clampf(ph, 0.0, 1.0) * PI) * (1.0 if ph < 0.5 else 0.85)
		var k := _land_k * env
		_hips_dy -= 0.34 * k
		for tg2 in ["L", "R"]:
			_pose["hip_" + tg2] = (_pose["hip_" + tg2] as Vector3) + Vector3(0.65 * k, 0.0, 0.0)
			_pose["kn_" + tg2] = (_pose["kn_" + tg2] as Vector3) + Vector3(-1.2 * k, 0.0, 0.0)
			_pose["sh_" + tg2] = (_pose["sh_" + tg2] as Vector3) + Vector3(-0.5 * k, 0.0, 0.25 * k * (1.0 if tg2 == "L" else -1.0))
		_pose["spine"] = (_pose["spine"] as Vector3) + Vector3(-0.35 * k, 0.0, 0.0)


func _beat(on: bool) -> void:
	if on and not _beat_prev:
		struck.emit()
	_beat_prev = on


## Market and household work. Angle conventions: shoulder forward = negative rx, elbow flex =
## positive rx, spine forward lean = negative rx, thigh forward = positive rx, knee flex = negative.
func _work(kind: String) -> void:
	var t := _t * 1.0 + _seed
	var legs_stand := true
	match kind:
		"scrub":
			var s := sin(t * 5.5)
			_hips_dy = -0.5
			_pose["spine"] = Vector3(-0.55, 0.0, 0.0)
			_pose["chest"] = Vector3(-0.1, 0.0, 0.0)
			_pose["head"] = Vector3(0.4, 0.0, 0.0)
			_pose["sh_R"] = Vector3(-1.15 - 0.35 * s, 0.0, 0.0)
			_pose["sh_L"] = Vector3(-1.15 + 0.35 * s, 0.0, 0.0)
			_pose["el_R"] = Vector3(0.5 + 0.3 * s, 0.0, 0.0)
			_pose["el_L"] = Vector3(0.5 - 0.3 * s, 0.0, 0.0)
			_kneel()
			legs_stand = false
			_beat(s > 0.9)
		"sweep":
			var s2 := sin(t * 2.6)
			_hips_dy = 0.0
			_pose["spine"] = Vector3(-0.28, 0.35 * s2, 0.0)
			_pose["chest"] = Vector3(-0.05, 0.2 * s2, 0.0)
			_pose["head"] = Vector3(0.35, -0.2 * s2, 0.0)
			_pose["sh_R"] = Vector3(-0.95, 0.0, 0.0)
			_pose["sh_L"] = Vector3(-0.8, 0.0, 0.0)
			_pose["el_R"] = Vector3(0.7, 0.0, 0.0)
			_pose["el_L"] = Vector3(0.9, 0.0, 0.0)
			_beat(s2 > 0.95 or s2 < -0.95)
		"stir":
			var c := t * 3.2
			_hips_dy = 0.0
			_pose["spine"] = Vector3(-0.25, 0.0, 0.0)
			_pose["chest"] = Vector3.ZERO
			_pose["head"] = Vector3(0.45, 0.0, 0.0)
			_pose["sh_R"] = Vector3(-1.0 + 0.15 * cos(c), 0.2 * sin(c), 0.0)
			_pose["el_R"] = Vector3(1.0 + 0.2 * sin(c), 0.0, 0.0)
			_pose["sh_L"] = Vector3(-0.55, 0.0, 0.0)
			_pose["el_L"] = Vector3(1.2, 0.0, 0.0)
			_beat(sin(c) > 0.97)
		"knead":
			var s3 := sin(t * 4.0)
			_hips_dy = -0.04
			_pose["spine"] = Vector3(-0.42 - 0.08 * s3, 0.0, 0.0)
			_pose["chest"] = Vector3.ZERO
			_pose["head"] = Vector3(0.4, 0.0, 0.0)
			for tg in ["L", "R"]:
				_pose["sh_" + tg] = Vector3(-1.05 + 0.4 * s3, 0.0, 0.0)
				_pose["el_" + tg] = Vector3(0.6 - 0.3 * s3, 0.0, 0.0)
			_beat(s3 > 0.95)
		"chop":
			var c2 := fmod(t * 3.0, TAU)
			var up := 0.5 + 0.5 * sin(c2)
			var strike := pow(maxf(0.0, -sin(c2 + 0.4)), 3.0)
			_hips_dy = 0.0
			_pose["spine"] = Vector3(-0.3 - 0.1 * strike, 0.1, 0.0)
			_pose["chest"] = Vector3.ZERO
			_pose["head"] = Vector3(0.5, 0.0, 0.0)
			_pose["sh_R"] = Vector3(-0.8 - 0.8 * up, 0.0, 0.0)
			_pose["el_R"] = Vector3(0.7 + 0.8 * up - 0.7 * strike, 0.0, 0.0)
			_pose["sh_L"] = Vector3(-0.75, 0.0, 0.0)
			_pose["el_L"] = Vector3(1.0, 0.0, 0.0)
			_beat(strike > 0.85)
		"hawk":
			var w := sin(t * 3.0)
			_hips_dy = 0.0
			_pose["spine"] = Vector3(0.06, 0.0, 0.0)
			_pose["chest"] = Vector3(0.04, 0.0, 0.0)
			_pose["head"] = Vector3(-0.12, 0.25 * sin(t * 0.7), 0.0)
			_pose["sh_R"] = Vector3(-2.5 + 0.15 * w, 0.0, 0.25 + 0.1 * w)
			_pose["el_R"] = Vector3(0.35, 0.0, 0.0)
			_pose["sh_L"] = Vector3(-0.3, 0.0, 0.25)
			_pose["el_L"] = Vector3(1.6, 0.0, 0.0)
		"haggle":
			var h1 := sin(t * 2.2)
			var h2 := sin(t * 2.2 + 2.0)
			_hips_dy = 0.0
			_pose["spine"] = Vector3(-0.05, 0.12 * h1, 0.0)
			_pose["chest"] = Vector3.ZERO
			_pose["head"] = Vector3(0.1 * h2, 0.3 * h1, 0.0)
			_pose["sh_R"] = Vector3(-0.9 - 0.35 * h1, 0.0, 0.15)
			_pose["el_R"] = Vector3(1.2 + 0.3 * h1, 0.0, 0.0)
			_pose["sh_L"] = Vector3(-0.8 - 0.35 * h2, 0.0, 0.15)
			_pose["el_L"] = Vector3(1.2 + 0.3 * h2, 0.0, 0.0)
		"sit", "sit_talk":
			var talk := kind == "sit_talk"
			var br := sin(t * 1.7)
			_hips_dy = -0.52
			_pose["spine"] = Vector3(-0.05 + 0.01 * br, 0.0, 0.0)
			_pose["chest"] = Vector3.ZERO
			_pose["head"] = Vector3(0.05, 0.3 * sin(t * 0.5), 0.0)
			if talk:
				var g := sin(t * 2.4)
				_pose["sh_R"] = Vector3(-0.8 - 0.3 * g, 0.0, 0.15)
				_pose["el_R"] = Vector3(1.3 + 0.3 * g, 0.0, 0.0)
			else:
				_pose["sh_R"] = Vector3(-0.35, 0.0, 0.0)
				_pose["el_R"] = Vector3(1.0, 0.0, 0.0)
			_pose["sh_L"] = Vector3(-0.35, 0.0, 0.0)
			_pose["el_L"] = Vector3(1.0, 0.0, 0.0)
			_kneel()
			legs_stand = false
	if legs_stand:
		for tg2 in ["L", "R"]:
			_pose["hip_" + tg2] = Vector3(0.1 if tg2 == "L" else -0.08, 0.0, 0.0)
			_pose["kn_" + tg2] = Vector3(-0.12, 0.0, 0.0)
			_pose["an_" + tg2] = Vector3.ZERO


## Sitting / kneeling legs: thighs forward, knees folded.
func _kneel() -> void:
	for tg in ["L", "R"]:
		var sg := 1.0 if tg == "L" else -1.0
		_pose["hip_" + tg] = Vector3(1.4, 0.0, 0.5 * sg)
		_pose["kn_" + tg] = Vector3(-2.0, 0.0, 0.0)
		_pose["an_" + tg] = Vector3.ZERO


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
		var up := clampf(air_vy / 6.0, 0.0, 1.0)
		var down := clampf(-air_vy / 8.0, 0.0, 1.0)
		var lead: bool = side == 0
		# take-off: lead knee driven up, trailing leg tucked behind; descent: legs reach for the ground
		var air_hip := (lerpf(0.2, 1.0, up) if lead else lerpf(-0.2, -0.55, up)) + down * (0.1 if lead else 0.5)
		var air_kn := (lerpf(0.35, 1.3, up) if lead else lerpf(0.5, 1.4, up)) * (1.0 - 0.5 * down)
		_pose["hip_" + tag] = Vector3(lerpf(amp * swing, air_hip, air), 0.0, 0.0)
		_pose["kn_" + tag] = Vector3(-lerpf(flex, air_kn, air), 0.0, 0.0)
		_pose["an_" + tag] = Vector3(lerpf(-0.25 * cos(ph + 0.35) * stride + 0.4 * maxf(0.0, -swing) * 0.4, 0.4 - 0.5 * down, air), 0.0, 0.0)
		var arm_swing := -sin(ph) * lerpf(0.38, 0.8, run_k) * minf(1.0, stride + 0.2)
		# arms swing up through the jump and spread wide for balance on the way down
		_pose["sh_" + tag] = Vector3(lerpf(arm_swing, -0.4 - 1.1 * up - 0.3 * down, air), 0.0, 0.0)
		_pose["el_" + tag] = Vector3(lerpf(0.22 + lerpf(0.1, 1.0, run_k) * (0.5 + 0.5 * maxf(0.0, -sin(ph))), 0.5, air), 0.0, 0.0)
	var bob := (0.018 + 0.03 * run_k) * stride
	_hips_dy = -bob * (1.0 - cos(2.0 * _phase)) * 0.5
	_pose["hips"] = Vector3(0.0, 0.14 * sin(_phase) * stride, -0.03 * sin(_phase) * stride)
	var lean := 0.03 + 0.07 * stride + 0.14 * run_k
	_pose["spine"] = Vector3(-lean, -0.2 * sin(_phase) * stride, 0.025 * sin(_phase) * stride)
	_pose["chest"] = Vector3.ZERO
	_pose["head"] = Vector3(lean * 0.8 - 0.02, 0.1 * sin(_phase) * stride, 0.0)
