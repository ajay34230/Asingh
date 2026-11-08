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
var _fingers: Array = []          # per skeleton: Array of [bone index, is_thumb]
## Hand closure: 0 = open hand, 1 = tight fist. Follows fist_target smoothly (see _hands).
var fist := 0.25
var fist_target := 0.25
static var fist_axis := Vector3.RIGHT   # local finger curl axis (lab-tested)
static var fist_sign := 1.0
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
	if body == "knight":
		_load("res://assets/outfits/KnightCharacter.glb")      # Quaternius Knight (CC0)
	elif body.begins_with("m_") or body.begins_with("w_"):
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
	if not p.get("natural", false):
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
		if idx[k] < 0 and String(map[k]).begins_with("Hand."):
			idx[k] = sk.find_bone(String(map[k]).replace("Hand.", "Palm."))     # the Knight rig
	if idx["hips"] < 0:
		return
	_skins.append(sk)
	_bone_idx.append(idx)
	var fl: Array = []
	for i in sk.get_bone_count():
		var bn := sk.get_bone_name(i).to_lower()
		if bn.ends_with("_end") or bn.contains("leaf") or bn.contains("metacarpal"):
			continue
		var thumb := bn.begins_with("thumb")
		if thumb or bn.begins_with("index") or bn.begins_with("middle") or bn.begins_with("ring") or bn.begins_with("pinky"):
			fl.append([i, thumb])
	_fingers.append(fl)
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
	if int(GameSettings.v.get("quality", 0)) == 0 and name != "Explorer":
		# High graphics: villagers get the same real fabric / leather / metal look, and some wear bangles
		ClothLook.dress(self, [main_c, trim_c])
		if h % 3 == 0:
			add_gear_node(ClothLook.kada(), "wrist_R")
		if h % 5 == 0:
			add_gear_node(ClothLook.kada(Color(0.85, 0.85, 0.88)), "wrist_L")
	else:
		_dye(main_c, trim_c)


## X27: re-dress the body in chosen colours (garments only).
func recolor(main_c: Color, trim_c: Color) -> int:
	return _dye(main_c, trim_c)


func _dye(main_c: Color, trim_c: Color) -> int:
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
	return n


var _tool_att: BoneAttachment3D
var weapon := "hammer"


func _add_hammer() -> void:
	if _skins.is_empty() or _bone_idx[0]["wr_R"] < 0:
		return
	var sk0 := _skins[0]
	_tool_att = BoneAttachment3D.new()
	_tool_att.bone_name = sk0.get_bone_name(_bone_idx[0]["wr_R"])
	_skins[0].add_child(_tool_att)
	set_weapon("hammer")


## What the hands hold: "fists" (nothing), "hammer", "axe", "spear", "sword", "dagger" or "bow" (left hand).
## Models: Quaternius Medieval Weapons (CC0), scaled to a real length and gripped near the handle end.
const WEAPON_GLB := {"hammer": "Hammer_Small", "axe": "Axe", "spear": "Spear", "sword": "Sword", "dagger": "Dagger", "bow": "Bow_Wooden", "shovel": "../graveyard/shovel"}
const WEAPON_LEN := {"hammer": 0.62, "axe": 0.8, "spear": 1.9, "sword": 1.0, "dagger": 0.4, "bow": 1.25, "shovel": 1.15}
const WEAPON_GRIP := {"hammer": 0.12, "axe": 0.12, "spear": 0.38, "sword": 0.1, "dagger": 0.12, "bow": 0.5, "shovel": 0.75}
var _bow_att: BoneAttachment3D


static func weapon_model(id: String) -> Node3D:
	var path := "res://assets/weapons/%s.glb" % String(WEAPON_GLB.get(id, ""))
	if not WEAPON_GLB.has(id) or not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	var box := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var n: Node = m
		while n != null and n != inst:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var bb := xf * m.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	var holder := Node3D.new()
	holder.add_child(inst)
	# stand the model up along +Y if it was modelled lying along X or Z (the long axis is the handle)
	var rot := Basis.IDENTITY
	if box.size.z > box.size.y * 1.5 and box.size.z >= box.size.x:
		rot = Basis(Vector3.RIGHT, -PI * 0.5)
	elif box.size.x > box.size.y * 1.5:
		rot = Basis(Vector3.BACK, PI * 0.5)
	box = Transform3D(rot, Vector3.ZERO) * box
	var h := maxf(box.size.y, 0.0001)
	var sc := float(WEAPON_LEN[id]) / h
	inst.transform = Transform3D(rot.scaled(Vector3.ONE * sc), Vector3.ZERO)
	var grip_y := box.position.y + h * float(WEAPON_GRIP[id])
	inst.position = -Vector3(box.get_center().x, grip_y, box.get_center().z) * sc
	return holder


## An arrow (Quaternius Medieval Weapons, CC0), 0.8 m long, pointing along -Z so look_at aims it.
static func arrow_model() -> Node3D:
	var path := "res://assets/weapons/Arrow.glb"
	if not ResourceLoader.exists(path):
		return null
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	var box := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var n: Node = m
		while n != null and n != inst:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var bb := xf * m.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	# lay the longest side along -Z (look_at's forward) and make it 0.8 m long; the head is the heavier end
	var rot := Basis.IDENTITY
	if box.size.y >= box.size.x and box.size.y >= box.size.z:
		rot = Basis(Vector3.RIGHT, -PI * 0.5)     # +Y -> -Z
	elif box.size.x >= box.size.z:
		rot = Basis(Vector3.UP, PI * 0.5)         # +X -> -Z
	var rb := Transform3D(rot, Vector3.ZERO) * box
	var long := maxf(rb.size.z, 0.0001)
	var sc := 0.8 / long
	var holder := Node3D.new()
	holder.add_child(inst)
	inst.transform = Transform3D(rot.scaled(Vector3.ONE * sc), -rb.get_center() * sc)
	return holder


func set_weapon(id: String) -> void:
	weapon = id
	if id != "bow":
		clear_archery()
	if _skins.is_empty():
		return
	for att in [_tool_att, _bow_att]:
		if att != null:
			for c in (att as Node).get_children():
				c.queue_free()
	if id == "fists":
		return
	var left := id == "bow"
	var bone: int = _bone_idx[0]["wr_L" if left else "wr_R"]
	if bone < 0:
		return
	var att: BoneAttachment3D = _bow_att if left else _tool_att
	if att == null:
		att = BoneAttachment3D.new()
		att.bone_name = _skins[0].get_bone_name(bone)
		_skins[0].add_child(att)
		if left:
			_bow_att = att
		else:
			_tool_att = att
	var model := weapon_model(id)
	if model == null:
		return
	if left:
		model.position = Vector3(0, 0.08, 0.0)        # bow held upright in the left fist
	else:
		model.position = Vector3(0, 0.08, 0.04)
		model.rotation.x = deg_to_rad(90.0)            # blade or head points forward out of the fist
	att.add_child(model)
	_fit_scale(model)


# --- armour pieces (helmets, shoulder pads) ------------------------------------------------------------
var _gear: Array[Node3D] = []


static func _norm_model(path: String, width: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	var box := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var n: Node = m
		while n != null and n != inst:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var bb := xf * m.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	var holder := Node3D.new()
	holder.add_child(inst)
	var sc := width / maxf(box.size.x, 0.0001)
	inst.scale = Vector3.ONE * sc
	inst.position = -box.get_center() * sc
	inst.rotation.y = PI                 # the models face +Z, people face -Z
	inst.position = Basis(Vector3.UP, PI) * inst.position
	return holder


## Put on a helmet ("helmet") or shoulder pads ("pads") from a model file. The piece is placed upright over
## the head (or across the shoulders) using the skeleton's rest pose, then follows the bone as it moves.
func add_gear(file: String, kind: String) -> void:
	var width := 0.27 if kind == "helmet" else 0.5
	var piece := _norm_model("res://assets/outfits/%s.glb" % file, width)
	if piece != null:
		add_gear_node(piece, kind)


## Attach any built piece: "helmet" / "turban" (head), "pads" / "cape" (shoulders), "sash" (waist).
var _cape_mats: Array[ShaderMaterial] = []


func add_gear_node(piece: Node3D, kind: String) -> void:
	if _skins.is_empty():
		return
	var key := "head" if kind in ["helmet", "turban"] else ("spine" if kind == "sash" else "chest")
	if kind == "wrist_L" or kind == "wrist_R":
		key = "el_" + kind.right(1)
	elif kind.begins_with("hip_"):
		key = "hips"
	var bi: int = _bone_idx[0][key]
	if bi < 0:
		return
	var sk: Skeleton3D = _skins[0]
	var att := BoneAttachment3D.new()
	att.bone_name = sk.get_bone_name(bi)
	sk.add_child(att)
	att.add_child(piece)
	_gear.append(att)
	if kind == "cape":
		for mi in piece.find_children("*", "MeshInstance3D", true, false):
			var cm := (mi as MeshInstance3D).material_override as ShaderMaterial
			if cm != null:
				_cape_mats.append(cm)
	_place_gear(att, piece, kind)


func _place_gear(att: BoneAttachment3D, piece: Node3D, kind: String) -> void:
	if not is_inside_tree():
		await ready
	if not is_instance_valid(att):
		return
	var sk := att.get_parent() as Skeleton3D
	var bi := sk.find_bone(att.bone_name)
	var bone_rest := sk.global_transform * sk.get_bone_global_rest(bi)
	var up := global_transform.basis.y.normalized()
	var back := global_transform.basis.z.normalized()          # people face -Z: +Z is behind them
	var k := global_transform.basis.get_scale().y            # NPC size variants
	var where := bone_rest.origin
	var grow := 1.0
	var l: int = _bone_idx[0]["sh_L"]
	var r: int = _bone_idx[0]["sh_R"]
	var pl := Vector3.ZERO
	var pr := Vector3.ZERO
	if l >= 0 and r >= 0:
		pl = (sk.global_transform * sk.get_bone_global_rest(l)).origin
		pr = (sk.global_transform * sk.get_bone_global_rest(r)).origin
	match kind:
		"helmet":
			where += up * 0.12 * k
		"turban":
			where += up * 0.15 * k
		"sash":
			where += up * 0.0 * k
			if l >= 0:
				grow = clampf(pl.distance_to(pr) / (0.36 * k), 0.8, 1.5)
		"pads":
			if l >= 0:
				where = (pl + pr) * 0.5 + up * 0.03 * k
				grow = clampf(pl.distance_to(pr) * 1.45 / (0.5 * k), 0.7, 1.6)
		"cape":
			if l >= 0:
				where = (pl + pr) * 0.5 + up * 0.04 * k + back * 0.13 * k
				grow = clampf(pl.distance_to(pr) / (0.36 * k), 0.8, 1.5)
		"wrist_L", "wrist_R":
			# a bangle (kada) just above the wrist, lined up with the forearm bone
			var wi: int = _bone_idx[0]["wr_" + kind.right(1)]
			if wi >= 0:
				var wp := (sk.global_transform * sk.get_bone_global_rest(wi)).origin
				where = wp + (bone_rest.origin - wp).normalized() * 0.05 * k
			var b := bone_rest.basis.orthonormalized()
			piece.transform = bone_rest.affine_inverse() * Transform3D(b.scaled(Vector3.ONE * k), where)
			return
		"neck":
			var ni: int = _bone_idx[0]["neck"]
			var np := (sk.global_transform * sk.get_bone_global_rest(ni)).origin if ni >= 0 else (pl + pr) * 0.5
			where = np - up * 0.06 * k - back * 0.12 * k
			if l >= 0:
				grow = clampf(pl.distance_to(pr) / (0.36 * k), 0.8, 1.5)
		"hip_L", "hip_R":
			var side := global_transform.basis.x.normalized() * (-1.0 if kind == "hip_L" else 1.0)
			where = bone_rest.origin + side * 0.17 * k - up * 0.02 * k
		"back":
			if l >= 0:
				where = (pl + pr) * 0.5 - up * 0.16 * k + back * 0.14 * k
	var want := Transform3D(global_transform.basis.orthonormalized().scaled(Vector3.ONE * k * grow), where)
	piece.transform = bone_rest.affine_inverse() * want


func clear_gear() -> void:
	for g in _gear:
		if is_instance_valid(g):
			g.queue_free()
	_gear.clear()
	_cape_mats.clear()


## Hand props hang off a bone. Some rigs carry a 100x scale in their bones, which used to blow brooms and
## tools up into the giant yellow slabs and brown beams seen on the phone. Undo the bone's scale so a
## prop is always its real size in metres.
func _fit_scale(n: Node3D) -> void:
	if not is_inside_tree():
		await ready
	await get_tree().process_frame
	if not is_instance_valid(n) or not n.is_inside_tree():
		return
	var par := n.get_parent() as Node3D
	var s := par.global_transform.basis.get_scale() / global_transform.basis.get_scale()
	if absf(s.x - 1.0) > 0.05 or absf(s.y - 1.0) > 0.05:
		n.scale = Vector3(1.0 / maxf(s.x, 0.0001), 1.0 / maxf(s.y, 0.0001), 1.0 / maxf(s.z, 0.0001))
		n.position = n.position * n.scale


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
				d = Basis(Vector3.UP, r.y) * Basis(Vector3.RIGHT, r.x) * Basis(Vector3.BACK, a0 - signf(a0) * r.z)
			var fn: Basis = (_frame[si] as Basis).orthonormalized()
			own[bi] = fn.inverse() * d * fn
		# D_total(b) = D_total(parent) * own(b); global basis = D_total * restGlobal
		var dtot: Array = []
		dtot.resize(n)
		for i in n:
			var p := sk.get_bone_parent(i)
			var par: Basis = (dtot[p] if p >= 0 else Basis.IDENTITY)
			var o: Basis = own[i]
			if i == int(idx["el_L"]) or i == int(idx["el_R"]):
				# the arms rest in a T-pose and are lowered by the shoulder, which turns the forearm's own axes:
				# express the elbow hinge in the lowered arm's frame, or the bend becomes a twist along the forearm
				o = par.inverse() * o * par
			dtot[i] = par * o
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
		# curl the fingers into a fist: each joint bends about its own local axis
		if si < _fingers.size():
			for f in _fingers[si]:
				var fi: int = f[0]
				var ang := fist * fist_sign * (0.45 if bool(f[1]) else 1.1)
				var q := sk.get_bone_pose_rotation(fi) * Quaternion(fist_axis, ang)
				sk.set_bone_pose_rotation(fi, q)
		if idx["hips"] >= 0:
			var off: Vector3 = (_frame[si] as Basis).inverse() * Vector3(0, _hips_dy / maxf(_inner.scale.y, 0.01), 0)
			var hp: int = idx["hips"]
			var pp := sk.get_bone_parent(hp)
			var pb: Basis = (rg[pp] as Basis) if pp >= 0 else Basis.IDENTITY
			sk.set_bone_pose_position(hp, sk.get_bone_rest(hp).origin + pb.inverse() * off)


# --- animation -----------------------------------------------------------------------------

func animate(delta: float, speed: float, grounded: bool) -> void:
	_t += delta
	# hands: a tight fist in the boxing guard, while striking or blocking; loosely curled otherwise
	var striking := move != "" and move != "roll" and move != "lift"
	fist_target = 1.0 if (guard or striking or react == "block") else 0.3
	fist = move_toward(fist, fist_target, delta * 7.0)
	for cm in _cape_mats:
		cm.set_shader_parameter("swing", clampf(_speed_smooth / 7.0, 0.0, 1.0) + 0.6 * clampf(-air_vy / 8.0, 0.0, 1.0))
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
		if not (hold_draw and move == "bow_shot" and move_t >= 0.6) and not (move_hold >= 0.0 and move_t >= move_hold):
			move_t += delta * move_rate
		if react == "ride":
			react_t += delta
			_react_pose()                 # in the saddle: the legs keep riding, the move only drives the upper body
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
	if guard and move == "" and react == "" and _speed_smooth < 2.5 and _air < 0.1 and climb_kind == "":
		_guard_pose()
	if climb_kind != "":
		_climb_pose()
	elif jump_prep > 0.0:
		_jump_prep_pose()
	_body_overlays(delta)
	_hit_overlay(delta)
	_overlay(delta)
	if not photo_pose.is_empty():
		for k in photo_pose:
			if k == "dy":
				_hips_dy = float(photo_pose[k])
			elif k == "spine" or k == "hips" or k == "chest" or k == "head":
				_pose[k] = photo_pose[k]
			else:
				_pz(k, photo_pose[k])
	_apply()
	if weapon == "bow":
		_archery()


# --- archery: a live bowstring and the arrow on the string --------------------------------------
var aim_twist := 0.0              # extra torso turn toward the target (archery from the saddle)
var move_hold := -1.0             # photo mode: freeze the current move at this time (a kick at full extension)
var photo_pose := {}              # photo mode: a held pose (keys as in the move keyframes)
var hold_draw := false            # manual aim: the bow stays at full draw until the player lets go
var move_rate := 1.0              # playback speed of the current move (Quick Draw speeds up the bow)
var _string: Array[MeshInstance3D] = []
var _nocked: Node3D
const BOW_HALF := 0.6             # grip to tip along the bow, metres


func _bone_pos(key: String) -> Vector3:
	var i: int = _bone_idx[0][key]
	if i < 0:
		return global_position
	return _skins[0].global_transform * _skins[0].get_bone_global_pose(i).origin


static func _place_between(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.0001:
		mi.visible = false
		return
	var y := d / l
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	mi.global_transform = Transform3D(Basis(x, y * l, z), (a + b) * 0.5)
	mi.visible = true


var _bow_local := Transform3D()
var _bow_local_set: Node3D = null


## While shooting, hold the bow upright (a slight cant) with its face along the bow arm, the way an archer
## does, instead of flat in the fist. Blends in as the arrow is nocked and out after the follow-through.
func _upright_bow(bow: Node3D) -> void:
	if _bow_local_set != bow:
		_bow_local_set = bow
		_bow_local = bow.transform
	bow.transform = _bow_local
	if move != "bow_shot":
		return
	var w := smoothstep(0.18, 0.32, move_t) * (1.0 - smoothstep(0.86, 0.98, move_t))
	if w <= 0.001:
		return
	var g := bow.global_transform
	var sc := g.basis.get_scale()
	var fwd := _bone_pos("wr_L") - _bone_pos("sh_L")
	if fwd.length() < 0.05:
		return
	fwd = fwd.normalized()
	var side := Vector3.UP.cross(fwd)
	if side.length() < 0.1:
		return
	side = side.normalized()
	var up := (Vector3.UP + side * 0.18).normalized()       # a small cant, top limb leaning out
	up = (up - fwd * up.dot(fwd)).normalized()
	var want := Basis(up.cross(fwd).normalized(), up, fwd)
	var q := g.basis.orthonormalized().get_rotation_quaternion().slerp(want.get_rotation_quaternion(), w)
	bow.global_transform = Transform3D(Basis(q).scaled(sc), g.origin)


func _archery() -> void:
	if _bow_att == null or _bow_att.get_child_count() == 0 or _skins.is_empty():
		return
	var bow := _bow_att.get_child(0) as Node3D
	if bow == null or not bow.is_inside_tree():
		return
	if _string.is_empty():
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.92, 0.9, 0.82)
		sm.roughness = 0.6
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0035
		cm.bottom_radius = 0.0035
		cm.height = 1.0
		cm.radial_segments = 4
		cm.rings = 1
		for i in 2:
			var mi := MeshInstance3D.new()
			mi.mesh = cm
			mi.material_override = sm
			mi.top_level = true
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_string.append(mi)
		_nocked = Node3D.new()
		_nocked.top_level = true
		var am := arrow_model()
		if am != null:
			_nocked.add_child(am)
		add_child(_nocked)
	_upright_bow(bow)
	var bx := bow.global_transform
	var up := bx.basis.y.normalized()
	var top := bx.origin + up * BOW_HALF
	var bot := bx.origin - up * BOW_HALF
	var grip := bx.origin
	# the string sits a hand's width behind the grip; while drawing it follows the string hand
	var rest := grip - (bx.basis.z.normalized()) * 0.12
	var drawing := move == "bow_shot" and move_t > 0.3 and move_t < _move_hit_at
	var nock := rest
	if drawing:
		nock = _bone_pos("wr_R")
		# the limbs bend as the string comes back
		var pull := clampf((nock - rest).length() / 0.6, 0.0, 1.0)
		top -= up * 0.05 * pull
		bot += up * 0.05 * pull
	_place_between(_string[0], top, nock)
	_place_between(_string[1], nock, bot)
	# the arrow: in the hand from the quiver, then on the string, pointing past the bow hand at the target
	var show := move == "bow_shot" and move_t > 0.14 and move_t < _move_hit_at
	_nocked.visible = show
	if show:
		var hand := _bone_pos("wr_R")
		var dir := (grip - hand).normalized() if move_t > 0.3 else (global_transform.basis.y.normalized() + global_transform.basis.z.normalized() * 0.4).normalized()
		if dir.length() < 0.5:
			dir = -global_transform.basis.z
		var b := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)
		_nocked.global_transform = Transform3D(b, hand + dir * 0.38)


## Where the arrow on the string is right now (the shot leaves from here).
func nock_transform() -> Transform3D:
	if _nocked != null and _nocked.is_inside_tree():
		return _nocked.global_transform
	return global_transform.translated_local(Vector3(0, 1.4, -0.4))


func clear_archery() -> void:
	for m in _string:
		m.queue_free()
	_string.clear()
	if _nocked != null:
		_nocked.queue_free()
		_nocked = null


# --- unarmed fighting and reactions ------------------------------------------------------------
## Moves: jab, cross, hook, uppercut, kick_front, kick_round, kick_side, grab, lift, throw.
## Reactions (looping until cleared): flinch, stagger, plead, held, clutch, sob, crawl.
const MOVES := {
	"jab": [0.38, 0.12], "cross": [0.42, 0.15], "hook": [0.46, 0.17], "uppercut": [0.5, 0.2],
	"kick_front": [0.72, 0.3], "kick_round": [0.75, 0.32], "kick_side": [0.72, 0.3], "bow_shot": [1.0, 0.64],
	"roll": [0.45, 0.44], "grab": [0.4, 0.3], "lift": [0.5, 0.5], "throw": [0.45, 0.12],
}
var move := ""
var move_t := 0.0
var _move_dur := 0.0
var _move_hit_at := 0.0
var _move_sent := false
var react := ""
var react_t := 0.0


## Starts a move. Returns the lead time in seconds: a punch thrown from relaxed hands first spends
## FIST_LEAD in the guard while the hand closes into a fist, then strikes.
const FIST_LEAD := 0.14
const PUNCHES := ["jab", "cross", "hook", "uppercut"]


func play_move(n: String) -> float:
	if not MOVES.has(n):
		return 0.0
	move = n
	move_t = 0.0
	var lead := 0.0
	if n in PUNCHES and fist < 0.8:
		lead = FIST_LEAD
		move_t = -lead
	_move_dur = MOVES[n][0]
	_move_hit_at = MOVES[n][1]
	_move_sent = false
	move_rate = 1.0
	move_hold = -1.0
	return lead


## Boxing stance: fists up by the chin, lead hand forward, knees soft, a little bounce on the toes.
var guard := false


func _guard_pose() -> void:
	var b := sin(_t * 7.0)
	for k in GUARD:
		var v: Variant = GUARD[k]
		if k == "dy":
			_hips_dy = float(v) + 0.02 * b
		elif k == "spine" or k == "hips" or k == "chest" or k == "head":
			_pose[k] = v
		else:
			_pz(k, v as Vector3, 0.85)
	_pz("sh_L", Vector3(-1.1 + 0.04 * b, 0.12, 0.1), 0.85)
	_pz("sh_R", Vector3(-1.0 - 0.04 * b, -0.15, 0.1), 0.85)


func move_busy() -> bool:
	return move != ""


func set_react(n: String) -> void:
	if react != n:
		react = n
		react_t = 0.0


func _pz(key: String, v: Vector3, w: float = 1.0) -> void:
	_pose[key] = (_pose[key] as Vector3).lerp(v, w)


# --- keyframed fight moves ---------------------------------------------------------------------
# Poses follow the boxing and taekwondo reference sheets: guard stance with lead foot forward and fists at the
# chin; jab and cross straight with hip and shoulder turn; hook with a bent elbow swinging flat; uppercut from a
# knee-bend; kicks as chamber (knee up), pivot, extend, retract. Each frame is [seconds, {key: value}]; a key a
# frame leaves out falls back to GUARD, and the moves return to GUARD at their end.
const GUARD := {
	"sh_L": Vector3(-1.1, 0.12, 0.1), "el_L": Vector3(1.9, 0, 0),
	"sh_R": Vector3(-1.0, -0.15, 0.1), "el_R": Vector3(2.0, 0, 0),
	"hip_L": Vector3(0.3, 0, 0), "kn_L": Vector3(-0.3, 0, 0),
	"hip_R": Vector3(-0.3, 0, 0), "kn_R": Vector3(-0.25, 0, 0),
	"spine": Vector3(-0.12, 0.3, 0), "hips": Vector3.ZERO, "chest": Vector3.ZERO, "head": Vector3(0.14, 0, 0),
	"dy": -0.08,
}


func _kf_moves() -> Dictionary:
	return {
		"jab": [[0.0, {}],
			[0.05, {"sh_L": Vector3(-1.2, 0.1, 0.1), "el_L": Vector3(2.1, 0, 0), "spine": Vector3(-0.12, 0.2, 0), "dy": -0.1}],
			[0.12, {"sh_L": Vector3(-1.55, 0.0, 0.0), "el_L": Vector3(0.04, 0, 0), "spine": Vector3(-0.17, 0.55, 0), "chest": Vector3(0, 0.15, 0), "hips": Vector3(0, 0.2, 0), "head": Vector3(0.2, -0.3, 0), "hip_L": Vector3(0.5, 0, 0), "dy": -0.12}],
			[0.2, {"sh_L": Vector3(-1.55, 0.0, 0.0), "el_L": Vector3(0.04, 0, 0), "spine": Vector3(-0.17, 0.5, 0), "chest": Vector3(0, 0.15, 0), "hips": Vector3(0, 0.2, 0), "head": Vector3(0.2, -0.3, 0), "hip_L": Vector3(0.5, 0, 0), "dy": -0.12}],
			[0.38, {}]],
		"cross": [[0.0, {}],
			[0.08, {"spine": Vector3(-0.12, 0.05, 0), "hips": Vector3(0, 0.2, 0), "sh_R": Vector3(-1.1, -0.2, 0.1), "el_R": Vector3(2.2, 0, 0), "kn_R": Vector3(-0.45, 0, 0), "dy": -0.12}],
			[0.15, {"sh_R": Vector3(-1.55, 0.0, 0.0), "el_R": Vector3(0.04, 0, 0), "spine": Vector3(-0.2, -0.75, 0), "hips": Vector3(0, -0.55, 0), "chest": Vector3(0, -0.2, 0), "head": Vector3(0.2, 0.3, 0), "hip_R": Vector3(-0.2, -0.5, 0), "kn_R": Vector3(-0.2, 0, 0), "dy": -0.1}],
			[0.24, {"sh_R": Vector3(-1.55, 0.0, 0.0), "el_R": Vector3(0.04, 0, 0), "spine": Vector3(-0.2, -0.7, 0), "hips": Vector3(0, -0.5, 0), "chest": Vector3(0, -0.2, 0), "head": Vector3(0.2, 0.3, 0), "hip_R": Vector3(-0.2, -0.5, 0), "dy": -0.1}],
			[0.42, {}]],
		"hook": [[0.0, {}],
			[0.09, {"sh_L": Vector3(-0.6, -0.2, 1.35), "el_L": Vector3(1.3, 0, 0), "spine": Vector3(-0.1, 1.0, 0.1), "hips": Vector3(0, 0.45, 0), "kn_L": Vector3(-0.5, 0, 0), "dy": -0.13}],
			[0.17, {"sh_L": Vector3(-1.35, 0.55, 0.15), "el_L": Vector3(1.0, 0, 0), "spine": Vector3(-0.1, -0.3, 0.1), "hips": Vector3(0, -0.35, 0), "chest": Vector3(0, -0.2, 0), "head": Vector3(0.2, 0.1, 0), "dy": -0.1}],
			[0.26, {"sh_L": Vector3(-1.35, 0.55, 0.15), "el_L": Vector3(1.0, 0, 0), "spine": Vector3(-0.1, -0.3, 0.1), "hips": Vector3(0, -0.35, 0), "dy": -0.1}],
			[0.46, {}]],
		"uppercut": [[0.0, {}],
			[0.14, {"sh_R": Vector3(-0.45, 0.0, 0.05), "el_R": Vector3(1.35, 0, 0), "spine": Vector3(0.05, 0.1, 0), "hips": Vector3(0, 0.25, 0), "hip_L": Vector3(0.75, 0, 0), "kn_L": Vector3(-1.0, 0, 0), "hip_R": Vector3(0.1, 0, 0), "kn_R": Vector3(-1.0, 0, 0), "dy": -0.3}],
			[0.2, {"sh_R": Vector3(-1.75, 0.0, 0.0), "el_R": Vector3(1.2, 0, 0), "spine": Vector3(-0.28, -0.55, 0), "hips": Vector3(0, -0.45, 0), "hip_L": Vector3(0.35, 0, 0), "kn_L": Vector3(-0.35, 0, 0), "hip_R": Vector3(-0.25, 0, 0), "kn_R": Vector3(-0.2, 0, 0), "head": Vector3(-0.1, 0.1, 0), "dy": 0.0}],
			[0.28, {"sh_R": Vector3(-1.75, 0.0, 0.0), "el_R": Vector3(1.2, 0, 0), "spine": Vector3(-0.28, -0.5, 0), "hips": Vector3(0, -0.4, 0), "dy": 0.0}],
			[0.5, {}]],
		"kick_front": [[0.0, {}],
			[0.16, {"hip_R": Vector3(1.55, 0, 0), "kn_R": Vector3(-2.0, 0, 0), "hip_L": Vector3(0.15, 0, 0), "kn_L": Vector3(-0.4, 0, 0), "spine": Vector3(0.1, 0.1, 0), "hips": Vector3(0, 0.3, 0), "sh_L": Vector3(-0.9, 0, 0.5), "sh_R": Vector3(-0.8, 0, 0.5), "el_L": Vector3(1.5, 0, 0), "el_R": Vector3(1.5, 0, 0), "dy": -0.1}],
			[0.3, {"hip_R": Vector3(1.45, 0, 0), "kn_R": Vector3(-0.05, 0, 0), "hip_L": Vector3(0.1, 0, 0), "kn_L": Vector3(-0.3, 0, 0), "spine": Vector3(0.3, 0.1, 0), "hips": Vector3(0, 0.3, 0), "sh_L": Vector3(-0.9, 0, 0.6), "sh_R": Vector3(-0.5, 0, 0.6), "el_L": Vector3(1.5, 0, 0), "el_R": Vector3(1.2, 0, 0), "dy": -0.06}],
			[0.4, {"hip_R": Vector3(1.45, 0, 0), "kn_R": Vector3(-0.05, 0, 0), "hip_L": Vector3(0.1, 0, 0), "kn_L": Vector3(-0.3, 0, 0), "spine": Vector3(0.3, 0.1, 0), "hips": Vector3(0, 0.3, 0), "sh_L": Vector3(-0.9, 0, 0.6), "sh_R": Vector3(-0.5, 0, 0.6), "el_L": Vector3(1.5, 0, 0), "el_R": Vector3(1.2, 0, 0), "dy": -0.06}],
			[0.52, {"hip_R": Vector3(1.2, 0, 0), "kn_R": Vector3(-1.6, 0, 0), "spine": Vector3(0.1, 0.1, 0), "dy": -0.1}],
			[0.72, {}]],
		"kick_round": [[0.0, {}],
			[0.16, {"hip_R": Vector3(1.35, 0, 0.5), "kn_R": Vector3(-1.9, 0, 0), "hip_L": Vector3(0.1, 0.4, 0), "kn_L": Vector3(-0.45, 0, 0), "hips": Vector3(0, -0.4, 0), "spine": Vector3(0.0, -0.3, 0.1), "sh_L": Vector3(-1.0, 0, 0.3), "sh_R": Vector3(-0.8, 0, 0.5), "dy": -0.12}],
			[0.32, {"hip_R": Vector3(1.3, 0, 0.95), "kn_R": Vector3(-0.1, 0, 0), "hip_L": Vector3(0.1, 0.9, 0), "kn_L": Vector3(-0.4, 0, 0), "hips": Vector3(0, -1.1, 0), "spine": Vector3(0.15, -0.5, -0.45), "chest": Vector3(0, -0.2, 0), "sh_L": Vector3(-1.0, 0, 0.6), "sh_R": Vector3(-0.4, 0, 1.2), "el_R": Vector3(0.5, 0, 0), "head": Vector3(0.1, 0.5, 0), "dy": -0.08}],
			[0.4, {"hip_R": Vector3(1.3, 0, 0.95), "kn_R": Vector3(-0.1, 0, 0), "hip_L": Vector3(0.1, 0.9, 0), "kn_L": Vector3(-0.4, 0, 0), "hips": Vector3(0, -1.1, 0), "spine": Vector3(0.15, -0.5, -0.45), "sh_L": Vector3(-1.0, 0, 0.6), "sh_R": Vector3(-0.4, 0, 1.2), "dy": -0.08}],
			[0.52, {"hip_R": Vector3(1.1, 0, 0.5), "kn_R": Vector3(-1.7, 0, 0), "hips": Vector3(0, -0.6, 0), "dy": -0.1}],
			[0.75, {}]],
		"kick_side": [[0.0, {}],
			[0.16, {"hip_R": Vector3(1.4, 0, 0.2), "kn_R": Vector3(-2.0, 0, 0), "hip_L": Vector3(0.1, 0.5, 0), "kn_L": Vector3(-0.5, 0, 0), "hips": Vector3(0, 0.7, 0), "spine": Vector3(0.0, 0.6, 0.15), "dy": -0.12}],
			[0.3, {"hip_R": Vector3(1.25, 0, 0.35), "kn_R": Vector3(-0.05, 0, 0), "hip_L": Vector3(0.1, 1.2, 0), "kn_L": Vector3(-0.4, 0, 0), "hips": Vector3(0, 1.35, 0), "spine": Vector3(0.05, 0.55, 0.55), "sh_L": Vector3(-0.7, 0, 0.9), "sh_R": Vector3(-0.7, 0, 0.9), "el_L": Vector3(0.8, 0, 0), "el_R": Vector3(0.8, 0, 0), "head": Vector3(0.1, -0.6, 0), "dy": -0.1}],
			[0.4, {"hip_R": Vector3(1.25, 0, 0.35), "kn_R": Vector3(-0.05, 0, 0), "hip_L": Vector3(0.1, 1.2, 0), "kn_L": Vector3(-0.4, 0, 0), "hips": Vector3(0, 1.35, 0), "spine": Vector3(0.05, 0.55, 0.55), "sh_L": Vector3(-0.7, 0, 0.9), "sh_R": Vector3(-0.7, 0, 0.9), "dy": -0.1}],
			[0.52, {"hip_R": Vector3(1.2, 0, 0.2), "kn_R": Vector3(-1.7, 0, 0), "hips": Vector3(0, 0.7, 0), "dy": -0.1}],
			[0.72, {}]],
		# archery, after real archers: reach over the shoulder to the quiver, draw an arrow and nock it,
		# raise the bow arm straight at the target while turning side-on, pull the string back to the
		# cheek (anchor), a breath of aim, release (the string hand springs back past the ear), follow through.
		"bow_shot": [[0.0, {}],
			[0.16, {"sh_R": Vector3(-2.5, 0.45, 0.35), "el_R": Vector3(2.0, 0, 0), "sh_L": Vector3(-0.55, 0.0, 0.12), "el_L": Vector3(0.35, 0, 0), "spine": Vector3(-0.02, 0.25, 0), "hips": Vector3(0, -0.2, 0), "head": Vector3(0.0, -0.2, 0)}],
			[0.3, {"sh_R": Vector3(-1.25, 0.2, 0.05), "el_R": Vector3(1.55, 0, 0), "sh_L": Vector3(-1.05, 0.0, 0.05), "el_L": Vector3(0.45, 0, 0), "spine": Vector3(-0.02, 0.42, 0), "hips": Vector3(0, -0.4, 0), "head": Vector3(0.05, 0.0, 0)}],
			[0.42, {"sh_L": Vector3(-1.55, 0.0, 0.05), "el_L": Vector3(0.08, 0, 0), "sh_R": Vector3(-1.45, 0.4, 0), "el_R": Vector3(1.35, 0, 0), "spine": Vector3(-0.03, 0.72, 0), "hips": Vector3(0, -0.7, 0), "head": Vector3(0.05, 0.02, 0), "dy": -0.04}],
			[0.58, {"sh_L": Vector3(-1.57, 0.0, 0.05), "el_L": Vector3(0.04, 0, 0), "sh_R": Vector3(-1.38, 0.85, 0), "el_R": Vector3(2.55, 0, 0), "spine": Vector3(-0.04, 0.6, 0), "hips": Vector3(0, -0.8, 0), "head": Vector3(0.05, 0.05, 0), "dy": -0.05}],
			[0.64, {"sh_L": Vector3(-1.57, 0.0, 0.05), "el_L": Vector3(0.04, 0, 0), "sh_R": Vector3(-1.38, 0.88, 0), "el_R": Vector3(2.6, 0, 0), "spine": Vector3(-0.04, 0.6, 0), "hips": Vector3(0, -0.8, 0), "head": Vector3(0.05, 0.05, 0), "dy": -0.05}],
			[0.7, {"sh_L": Vector3(-1.5, 0.0, 0.08), "el_L": Vector3(0.06, 0, 0), "sh_R": Vector3(-1.05, 1.05, 0.5), "el_R": Vector3(1.05, 0, 0), "spine": Vector3(-0.02, 0.6, 0), "hips": Vector3(0, -0.8, 0), "head": Vector3(0.05, 0.05, 0), "dy": -0.05}],
			[0.84, {"sh_L": Vector3(-1.4, 0.0, 0.1), "el_L": Vector3(0.1, 0, 0), "sh_R": Vector3(-1.0, 1.05, 0.55), "el_R": Vector3(1.0, 0, 0), "spine": Vector3(-0.02, 0.76, 0), "hips": Vector3(0, -0.75, 0), "head": Vector3(0.05, 0.05, 0), "dy": -0.04}],
			[1.0, {}]],
	}


## Candidate poses for the pose-lab capture (edit while tuning).
static func lab_variants() -> Array:
	var g := {"hip_L": Vector3(0.3, 0, 0), "hip_R": Vector3(-0.3, 0, 0), "kn_L": Vector3(-0.3, 0, 0), "kn_R": Vector3(-0.25, 0, 0), "dy": -0.08}
	var out: Array = []
	var combos := [[Vector3(0.0, 0.0, 0.0), 0.0], [Vector3(-1.1, 0.0, 0.0), 0.0], [Vector3(0.0, 0.0, 0.0), 1.9], [Vector3(-1.1, 0.0, 0.0), 1.9], [Vector3(1.1, 0.0, 0.0), 0.0]]
	for c in combos:
		var d := g.duplicate()
		d["sh_L"] = c[0]
		d["sh_R"] = c[0]
		d["el_L"] = Vector3(c[1], 0, 0)
		d["el_R"] = Vector3(c[1], 0, 0)
		out.append(d)
	return out


var _kf_cache: Dictionary = {}


func _kf_pose(name_: String, t: float) -> bool:
	if _kf_cache.is_empty():
		_kf_cache = _kf_moves()
	if not _kf_cache.has(name_):
		return false
	var frames: Array = _kf_cache[name_]
	var i := 0
	while i < frames.size() - 2 and t >= float((frames[i + 1] as Array)[0]):
		i += 1
	var fa: Array = frames[i]
	var fb: Array = frames[i + 1]
	var span := maxf(float(fb[0]) - float(fa[0]), 0.0001)
	var u := clampf((t - float(fa[0])) / span, 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	var seated := react == "ride"
	for k in GUARD:
		if seated and (k == "dy" or k == "hips" or k.begins_with("hip_") or k.begins_with("kn_")):
			continue
		var va: Variant = (fa[1] as Dictionary).get(k, GUARD[k])
		var vb: Variant = (fb[1] as Dictionary).get(k, GUARD[k])
		if k == "dy":
			_hips_dy = lerpf(float(va), float(vb), u)
		elif k == "spine" or k == "hips" or k == "chest" or k == "head":
			_pose[k] = (va as Vector3).lerp(vb as Vector3, u)
			if k == "spine" and name_ == "bow_shot":
				_pose[k] = (_pose[k] as Vector3) + Vector3(0, aim_twist * smoothstep(0.2, 0.42, t) * (1.0 - smoothstep(0.84, 1.0, t)), 0)
		else:
			_pz(k, (va as Vector3).lerp(vb as Vector3, u))
	return true



# --- one-shot hit reactions -----------------------------------------------------------------------
# Added on top of whatever the body is doing: the head snaps, the torso recoils away from the blow, the arms
# fling out and the knees dip, then it settles in about half a second. kinds: head, body, gut (doubled over).
var hit_t := -1.0
var _hit_kind := "body"
var _hit_side := 1.0


func play_hit(kind: String = "body", side: float = 1.0) -> void:
	hit_t = 0.0
	_hit_kind = kind
	_hit_side = 1.0 if side >= 0.0 else -1.0


func _hit_overlay(delta: float) -> void:
	if hit_t < 0.0:
		return
	hit_t += delta
	var dur := 0.55
	if hit_t >= dur:
		hit_t = -1.0
		return
	var u := hit_t / dur
	var e := smoothstep(0.0, 0.14, u) * (1.0 - smoothstep(0.35, 1.0, u))     # fast in, slow out
	var s := _hit_side
	var sp: Vector3 = _pose["spine"]
	var hd: Vector3 = _pose["head"]
	match _hit_kind:
		"head":
			sp += Vector3(0.3 * e, 0.25 * s * e, 0.14 * s * e)
			hd += Vector3(-0.75 * e, 0.6 * s * e, 0.25 * s * e)
			_add_arms(0.55 * e, 0.6 * e, 0.4 * e)
		"gut":
			sp += Vector3(-0.65 * e, 0.0, 0.1 * s * e)
			hd += Vector3(0.35 * e, 0.0, 0.0)
			for tg in ["L", "R"]:
				_pose["sh_" + tg] = (_pose["sh_" + tg] as Vector3).lerp(Vector3(-0.7, 0.0, 0.15), 0.85 * e)
				_pose["el_" + tg] = (_pose["el_" + tg] as Vector3).lerp(Vector3(1.5, 0.0, 0.0), 0.85 * e)
		_:
			sp += Vector3(0.38 * e, 0.3 * s * e, 0.1 * s * e)
			hd += Vector3(-0.45 * e, 0.3 * s * e, 0.0)
			_add_arms(0.7 * e, 0.8 * e, 0.5 * e)
	_pose["spine"] = sp
	_pose["head"] = hd
	_hips_dy -= 0.07 * e
	for tg2 in ["L", "R"]:
		_pose["kn_" + tg2] = (_pose["kn_" + tg2] as Vector3) + Vector3(-0.35 * e, 0.0, 0.0)
		_pose["hip_" + tg2] = (_pose["hip_" + tg2] as Vector3) + Vector3(0.18 * e, 0.0, 0.0)


func _add_arms(back: float, out: float, bend: float) -> void:
	for tg in ["L", "R"]:
		_pose["sh_" + tg] = (_pose["sh_" + tg] as Vector3) + Vector3(back, 0.0, out * 0.6)
		_pose["el_" + tg] = (_pose["el_" + tg] as Vector3) + Vector3(bend, 0.0, 0.0)

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
	if _kf_pose(move, t):
		_pose["head"] = (_pose["head"] as Vector3)
		return
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
		"roll":
			# tucked ball: knees to chest, chin down, arms hugging the shins; the Player rotates the model
			# around the body centre while this holds the tuck, so nothing swings through the ground
			var tuck := smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(d - 0.1, d, t))
			_pose["spine"] = Vector3(0.9 * tuck, 0, 0)
			_pose["chest"] = Vector3(0.4 * tuck, 0, 0)
			_pose["head"] = Vector3(0.5 * tuck, 0, 0)
			for tg in ["L", "R"]:
				_pz("hip_" + tg, Vector3(-1.7 * tuck, 0, 0)); _pz("kn_" + tg, Vector3(-2.0 * tuck, 0, 0))
				_pz("sh_" + tg, Vector3(-1.1 * tuck, 0, 0.1)); _pz("el_" + tg, Vector3(1.9 * tuck, 0, 0))
			_hips_dy = -0.35 * tuck
			return
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
				# thighs forward and only slightly apart (a rider's legs hug the animal), shins hanging back
				_pz("hip_" + tg, Vector3(0.5 + 0.2 * k + 0.2 * ride_air, 0, 0.22 * sg))
				_pz("kn_" + tg, Vector3(-1.25 - 0.3 * k - 0.3 * ride_air, 0, 0))
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
		# --- mission tasks (conventions: shoulder forward = negative x, elbow flex = positive, thigh forward =
		# positive, knee flex = negative, spine forward lean = negative). "dy" lowers the hips.
		"dig":
			# both hands on the shovel: drive it down with a knee push, lever back, throw the earth aside
			var c := fmod(t, 1.3) / 1.3
			var drive := sin(clampf(c / 0.45, 0.0, 1.0) * PI * 0.5)
			var lift := smoothstep(0.45, 0.8, c) * (1.0 - smoothstep(0.85, 1.0, c))
			tgt["sh_R"] = Vector3(-0.55 - 0.5 * lift + 0.25 * drive, 0.2, 0.1)
			tgt["el_R"] = Vector3(0.6 + 0.5 * lift, 0, 0)
			tgt["sh_L"] = Vector3(-0.9 - 0.4 * lift, -0.3, 0.1)
			tgt["el_L"] = Vector3(0.5 + 0.4 * drive, 0, 0)
			tgt["spine"] = Vector3(-0.55 + 0.25 * lift, 0.25 * lift, 0)
			tgt["head"] = Vector3(0.35, 0, 0)
			tgt["hip_L"] = Vector3(0.55, 0, 0)
			tgt["kn_L"] = Vector3(-0.7 - 0.2 * drive, 0, 0)
			tgt["hip_R"] = Vector3(0.15 + 0.35 * drive, 0, 0)
			tgt["kn_R"] = Vector3(-0.5 - 0.4 * drive, 0, 0)
			tgt["dy"] = Vector3(-0.18 - 0.06 * drive, 0, 0)
		"search":
			# bent over, both hands rummaging in turn
			tgt["spine"] = Vector3(-0.85, 0.15 * sin(t * 2.0), 0)
			tgt["head"] = Vector3(0.45, 0, 0)
			tgt["sh_L"] = Vector3(-1.1 + 0.25 * sin(t * 7.0), 0, 0.15)
			tgt["sh_R"] = Vector3(-1.1 + 0.25 * sin(t * 7.0 + 2.0), 0, 0.15)
			tgt["el_L"] = Vector3(0.5 + 0.3 * sin(t * 6.0), 0, 0)
			tgt["el_R"] = Vector3(0.5 + 0.3 * sin(t * 6.0 + 1.5), 0, 0)
			tgt["hip_L"] = Vector3(0.45, 0, 0)
			tgt["hip_R"] = Vector3(0.45, 0, 0)
			tgt["kn_L"] = Vector3(-0.7, 0, 0)
			tgt["kn_R"] = Vector3(-0.7, 0, 0)
			tgt["dy"] = Vector3(-0.2, 0, 0)
		"pickup":
			# squat down, take it with the right hand, stand up holding it close
			var dn := sin(clampf(t / _action_dur, 0.0, 1.0) * PI)
			tgt["hip_L"] = Vector3(1.2 * dn, 0, 0)
			tgt["hip_R"] = Vector3(0.9 * dn, 0, 0)
			tgt["kn_L"] = Vector3(-2.0 * dn, 0, 0)
			tgt["kn_R"] = Vector3(-1.6 * dn, 0, 0)
			tgt["an_L"] = Vector3(-0.5 * dn, 0, 0)
			tgt["spine"] = Vector3(-0.5 * dn, 0, 0)
			tgt["head"] = Vector3(0.4 * dn, 0, 0)
			tgt["sh_R"] = Vector3(-0.9 * dn - 0.2, 0, 0.1)
			tgt["el_R"] = Vector3(0.3 + 1.2 * (1.0 - dn), 0, 0)
			tgt["dy"] = Vector3(-0.55 * dn, 0, 0)
		"reach":
			# light a lamp, touch a stone, set something down: right arm out and up, a step in
			tgt["sh_R"] = Vector3(-1.75, 0.1, 0.05)
			tgt["el_R"] = Vector3(0.15, 0, 0)
			tgt["sh_L"] = Vector3(-0.3, 0, 0.2)
			tgt["spine"] = Vector3(-0.12, -0.2, 0)
			tgt["head"] = Vector3(-0.15, 0, 0)
			tgt["hip_R"] = Vector3(0.35, 0, 0)
			tgt["kn_R"] = Vector3(-0.3, 0, 0)
		"pray":
			# kneel on both knees, palms together, head bowed
			tgt["hip_L"] = Vector3(0.1, 0, 0)
			tgt["hip_R"] = Vector3(0.1, 0, 0)
			tgt["kn_L"] = Vector3(-2.3, 0, 0)
			tgt["kn_R"] = Vector3(-2.3, 0, 0)
			tgt["an_L"] = Vector3(0.6, 0, 0)
			tgt["an_R"] = Vector3(0.6, 0, 0)
			tgt["sh_L"] = Vector3(-0.75, -0.55, 0.0)
			tgt["sh_R"] = Vector3(-0.75, 0.55, 0.0)
			tgt["el_L"] = Vector3(1.85, 0, 0)
			tgt["el_R"] = Vector3(1.85, 0, 0)
			tgt["head"] = Vector3(0.45, 0, 0)
			tgt["spine"] = Vector3(-0.15, 0, 0)
			tgt["dy"] = Vector3(-0.5, 0, 0)
		"chop":
			# two-handed overhead swing into the wood
			var c2 := fmod(t, 0.9) / 0.9
			var up := 1.0 - smoothstep(0.35, 0.55, c2) if c2 > 0.3 else smoothstep(0.0, 0.3, c2)
			tgt["sh_R"] = Vector3(lerpf(-0.6, -2.7, up), 0.25, 0.1)
			tgt["sh_L"] = Vector3(lerpf(-0.6, -2.6, up), -0.25, 0.1)
			tgt["el_R"] = Vector3(lerpf(0.3, 1.0, up), 0, 0)
			tgt["el_L"] = Vector3(lerpf(0.3, 1.0, up), 0, 0)
			tgt["spine"] = Vector3(lerpf(-0.45, 0.1, up), 0, 0)
			tgt["hip_L"] = Vector3(0.3, 0, 0)
			tgt["kn_L"] = Vector3(-0.35, 0, 0)
			tgt["dy"] = Vector3(-0.08, 0, 0)
		"cut":
			# kneel on one knee and saw at a rope
			tgt["hip_L"] = Vector3(0.9, 0, 0)
			tgt["kn_L"] = Vector3(-1.6, 0, 0)
			tgt["hip_R"] = Vector3(-0.1, 0, 0)
			tgt["kn_R"] = Vector3(-2.0, 0, 0)
			tgt["sh_R"] = Vector3(-0.9 + 0.35 * sin(t * 12.0), 0.2, 0.1)
			tgt["el_R"] = Vector3(0.8 + 0.4 * sin(t * 12.0), 0, 0)
			tgt["sh_L"] = Vector3(-0.9, -0.1, 0.1)
			tgt["el_L"] = Vector3(0.6, 0, 0)
			tgt["spine"] = Vector3(-0.35, 0, 0)
			tgt["head"] = Vector3(0.3, 0, 0)
			tgt["dy"] = Vector3(-0.45, 0, 0)
		"drink":
			# bend to the water, cup the hands, bring them to the mouth
			var dd := sin(clampf(t / _action_dur, 0.0, 1.0) * PI)
			tgt["spine"] = Vector3(-0.75 * dd, 0, 0)
			tgt["sh_L"] = Vector3(-0.9 - 0.5 * dd, -0.3, 0)
			tgt["sh_R"] = Vector3(-0.9 - 0.5 * dd, 0.3, 0)
			tgt["el_L"] = Vector3(1.4, 0, 0)
			tgt["el_R"] = Vector3(1.4, 0, 0)
			tgt["hip_L"] = Vector3(0.5 * dd, 0, 0)
			tgt["hip_R"] = Vector3(0.5 * dd, 0, 0)
			tgt["kn_L"] = Vector3(-0.8 * dd, 0, 0)
			tgt["kn_R"] = Vector3(-0.8 * dd, 0, 0)
			tgt["dy"] = Vector3(-0.25 * dd, 0, 0)
		"read":
			tgt["sh_L"] = Vector3(-0.8, -0.3, 0.05)
			tgt["sh_R"] = Vector3(-0.8, 0.3, 0.05)
			tgt["el_L"] = Vector3(1.3, 0, 0)
			tgt["el_R"] = Vector3(1.3, 0, 0)
			tgt["head"] = Vector3(0.4, 0.1 * sin(t * 1.2), 0)
		"push":
			tgt["sh_L"] = Vector3(-1.45, -0.1, 0.1)
			tgt["sh_R"] = Vector3(-1.45, 0.1, 0.1)
			tgt["el_L"] = Vector3(0.35, 0, 0)
			tgt["el_R"] = Vector3(0.35, 0, 0)
			tgt["spine"] = Vector3(-0.25, 0, 0)
			tgt["hip_R"] = Vector3(-0.35, 0, 0)
			tgt["hip_L"] = Vector3(0.35, 0, 0)
			tgt["kn_L"] = Vector3(-0.35, 0, 0)
	for k in tgt:
		var goal: Vector3 = tgt[k]
		if k == "dy":
			_hips_dy = lerpf(_hips_dy, goal.x, w)
			continue
		var base: Vector3 = _pose[k]
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
	_fit_scale(root)
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
	if jump_kind == "run" and impact < 11.0:
		_land_k *= 0.45            # a running landing rolls straight on into the next stride
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


# --- jump anticipation and climbing ------------------------------------------------------------
var jump_kind := "walk"           # "stand", "walk" or "run": set by the player at take-off
var jump_prep := 0.0              # 0..1 anticipation crouch before take-off
var climb_kind := ""              # "", "climb" (hang and pull up), "mantle" (low wall) or "vault" (hop over)
var climb_u := 0.0                # 0..1 progress of the climb


## Anticipation: hips drop and sit back, knees bend, chest folds forward, arms swing back.
func _jump_prep_pose() -> void:
	var k := jump_prep
	_hips_dy -= 0.24 * k
	for tg in ["L", "R"]:
		_pz("hip_" + tg, Vector3(0.7 * k, 0, 0))
		_pz("kn_" + tg, Vector3(-1.15 * k, 0, 0))
		_pz("an_" + tg, Vector3(-0.35 * k, 0, 0))
		_pz("sh_" + tg, Vector3(0.65 * k, 0, 0.1 * k))
		_pz("el_" + tg, Vector3(0.25, 0, 0))
	_pose["spine"] = Vector3(-0.42 * k, 0, 0)
	_pose["head"] = Vector3(0.3 * k, 0, 0)


func _seg(u: float, a: float, b: float) -> float:
	return smoothstep(0.0, 1.0, clampf((u - a) / maxf(b - a, 0.001), 0.0, 1.0))


## Climbing poses (GTA-style): reach, hang and pull with bent elbows while a knee walks up the wall, push down
## on the ledge with straight arms as the knee comes over, then stand. Mantle = the push-up half on a low wall.
## Vault = hands planted on top, legs tucked to one side and swung over, then reach for the ground.
func _climb_pose() -> void:
	var u := climb_u
	var pp := {}
	match climb_kind:
		"climb":
			var a := _seg(u, 0.0, 0.18)
			var b := _seg(u, 0.18, 0.6)
			var c := _seg(u, 0.6, 0.86)
			var d := _seg(u, 0.86, 1.0)
			var sh := lerpf(lerpf(lerpf(-0.6, -2.75, a), -1.5, b), -0.15, c)
			var el := lerpf(lerpf(0.2, 2.2, b), 0.1, c)
			pp = {"sh_L": Vector3(lerpf(sh, 0.0, d), 0, 0.12), "sh_R": Vector3(lerpf(sh, 0.0, d), 0, 0.12),
				"el_L": Vector3(lerpf(el, 0.25, d), 0, 0), "el_R": Vector3(lerpf(el, 0.25, d), 0, 0),
				"hip_R": Vector3(lerpf(lerpf(lerpf(0.4, 0.15, a), 1.05, b), 1.65, c) * (1.0 - d), 0, 0),
				"kn_R": Vector3(-lerpf(lerpf(lerpf(0.9, 0.3, a), 1.5, b), 2.1, c) * (1.0 - d) - 0.15 * d, 0, 0),
				"hip_L": Vector3(lerpf(lerpf(0.4, 0.05, a), 0.45, c) * (1.0 - d), 0, 0),
				"kn_L": Vector3(-lerpf(lerpf(0.9, 0.35, a), 0.9, c) * (1.0 - d) - 0.15 * d, 0, 0),
				"spine": Vector3(lerpf(lerpf(-0.1, -0.2, b), -0.65, c) * (1.0 - d) - 0.06 * d, 0, 0),
				"head": Vector3(lerpf(lerpf(-0.25, 0.1, b), 0.45, c) * (1.0 - d), 0, 0)}
		"mantle":
			var c2 := _seg(u, 0.0, 0.55)
			var d2 := _seg(u, 0.55, 1.0)
			pp = {"sh_L": Vector3(lerpf(lerpf(-1.1, -0.2, c2), 0.0, d2), 0, 0.15), "sh_R": Vector3(lerpf(lerpf(-1.1, -0.2, c2), 0.0, d2), 0, 0.15),
				"el_L": Vector3(lerpf(lerpf(1.0, 0.1, c2), 0.25, d2), 0, 0), "el_R": Vector3(lerpf(lerpf(1.0, 0.1, c2), 0.25, d2), 0, 0),
				"hip_R": Vector3(lerpf(1.6, 0.0, d2), 0, 0), "kn_R": Vector3(-lerpf(2.05, 0.15, d2), 0, 0),
				"hip_L": Vector3(lerpf(0.35, 0.0, d2), 0, 0), "kn_L": Vector3(-lerpf(0.7, 0.15, d2), 0, 0),
				"spine": Vector3(lerpf(-0.55, -0.06, d2), 0, 0), "head": Vector3(lerpf(0.4, 0.0, d2), 0, 0)}
		"vault":
			var tuck := sin(clampf(u / 0.75, 0.0, 1.0) * PI)
			var reach := _seg(u, 0.6, 1.0)
			pp = {"sh_L": Vector3(lerpf(-1.05, -0.3, reach), 0, 0.1), "sh_R": Vector3(lerpf(-1.05, -0.3, reach), 0, 0.25 * reach),
				"el_L": Vector3(0.1, 0, 0), "el_R": Vector3(0.1, 0, 0),
				"hip_L": Vector3(lerpf(0.2, 1.25, tuck), 0, 0), "kn_L": Vector3(-lerpf(0.3, 1.7, tuck), 0, 0),
				"hip_R": Vector3(lerpf(0.2, 1.05, tuck), 0, 0), "kn_R": Vector3(-lerpf(0.3, 1.5, tuck), 0, 0),
				"hips": Vector3(0, 0, 0.45 * tuck), "spine": Vector3(-0.35 * tuck, 0, -0.3 * tuck), "head": Vector3(0.25 * tuck, 0, 0.2 * tuck)}
	for k in pp:
		var v: Vector3 = pp[k]
		if k == "spine" or k == "hips" or k == "head" or k == "chest":
			_pose[k] = v
		else:
			_pose[k] = v
	_pose["chest"] = Vector3.ZERO
	_hips_dy = 0.0


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
		var apex := 1.0 - clampf(absf(air_vy) / 5.0, 0.0, 1.0)
		var air_hip: float
		var air_kn: float
		match jump_kind:
			"stand":
				# two-footed vertical jump: legs push straight, tuck both knees at the top, reach down to land
				air_hip = lerpf(0.15, 1.05, apex) * (1.0 - down) + 0.45 * down
				air_kn = lerpf(0.2, 1.7, apex) * (1.0 - down) + 0.55 * down
			"run":
				# running leap: lead leg reaches forward almost straight, trailing leg folds behind
				air_hip = (lerpf(0.75, 1.1, up) if lead else -0.75) * (1.0 - 0.4 * down) + (0.25 * down if lead else 0.3 * down)
				air_kn = (0.35 if lead else 1.55) * (1.0 - 0.5 * down) + (0.15 * down if lead else 0.0)
			_:
				# walking jump off one foot: lead knee driven up, trailing leg tucked behind; descent: legs reach down
				air_hip = (lerpf(0.2, 1.0, up) if lead else lerpf(-0.2, -0.55, up)) + down * (0.1 if lead else 0.5)
				air_kn = (lerpf(0.35, 1.3, up) if lead else lerpf(0.5, 1.4, up)) * (1.0 - 0.5 * down)
		_pose["hip_" + tag] = Vector3(lerpf(amp * swing, air_hip, air), 0.0, 0.0)
		_pose["kn_" + tag] = Vector3(-lerpf(flex, air_kn, air), 0.0, 0.0)
		_pose["an_" + tag] = Vector3(lerpf(-0.25 * cos(ph + 0.35) * stride + 0.4 * maxf(0.0, -swing) * 0.4, 0.4 - 0.5 * down, air), 0.0, 0.0)
		var arm_swing := -sin(ph) * lerpf(0.38, 0.8, run_k) * minf(1.0, stride + 0.2)
		# arms: stand = both swing up overhead and come forward at the top; run = opposite arm to the lead leg
		# drives forward; walk = swing up and spread for balance on the way down
		var air_sh := -0.4 - 1.1 * up - 0.3 * down
		var air_ab := 0.0
		if jump_kind == "stand":
			air_sh = -lerpf(2.5, 1.2, apex) * (1.0 - down) - 0.8 * down
			air_ab = 0.35 * down
		elif jump_kind == "run":
			air_sh = (0.55 if lead else -1.15)
			air_ab = 0.25 * down
		_pose["sh_" + tag] = Vector3(lerpf(arm_swing, air_sh, air), 0.0, air_ab * air)
		_pose["el_" + tag] = Vector3(lerpf(0.22 + lerpf(0.1, 1.0, run_k) * (0.5 + 0.5 * maxf(0.0, -sin(ph))), 0.5, air), 0.0, 0.0)
	var bob := (0.018 + 0.03 * run_k) * stride
	_hips_dy = -bob * (1.0 - cos(2.0 * _phase)) * 0.5
	_pose["hips"] = Vector3(0.0, 0.14 * sin(_phase) * stride, -0.03 * sin(_phase) * stride)
	var lean := 0.03 + 0.07 * stride + 0.14 * run_k
	if jump_kind == "run":
		lean = lerpf(lean, 0.28, air)
	elif jump_kind == "stand":
		lean = lerpf(lean, 0.12 * (1.0 - clampf(absf(air_vy) / 5.0, 0.0, 1.0)), air)
	_pose["spine"] = Vector3(-lean, -0.2 * sin(_phase) * stride, 0.025 * sin(_phase) * stride)
	_pose["chest"] = Vector3.ZERO
	_pose["head"] = Vector3(lean * 0.8 - 0.02, 0.1 * sin(_phase) * stride, 0.0)
