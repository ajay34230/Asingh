class_name KesarKot
extends Node3D
## Kesar Kot, the great walled town of the Shadow Quarter (about 130 x 240 m). Every downloaded model has a place
## chosen by what it is (planning sheet of Sketchfab previews, 2026-11-17):
##  - core: "low poly desert village" (adobe, stairs, flat roofs)   - north and south towns: the 12 desert/concrete kit houses
##  - east gate quarter: the western tavern (Ravi's lamp tower), the four rusty-roof stilt shanties, the statue plaza
##  - north-west: the haunted mansion (the Kaali Pagdi den), the broken wooden watch post, the courtyard ruin
##  - south-west: the gothic chapel ruin with the stone bridge; the necromorph and the nebula window inside
##  - outside: the wooden farmstead kit, oak grove and pines (north); the cantonment village (south); the two city
##    scans as far scenery below the west cliff
## A rooftop road with an obstacle for every captured parkour move, sentries for stealth, and eight missions.

const C := Vector2(-105.0, 440.0)
const HX := 65.0                       # half width (x) and half length (z) of the town wall
const HZ := 120.0
const CORE := Vector2(0, 0)
const GATE_Q := Vector2(52, 0)
const DEN := Vector2(-45, -95)
const CHAPEL := Vector2(-45, 95)
const COURSE_Z := -55.0                # the rooftop road lane between the two rows of the north town
const KIT := ["Concrete House_001", "Desert House_002", "Concrete House_003", "Desert House_004", "Concrete House_005", "Desert House_006",
	"Desert House_001", "Concrete House_002", "Desert House_003", "Concrete House_004", "Desert House_005", "Concrete House_006"]
const SHANTIES := ["jungle_house", "wood_house_a", "wood_house_b", "wood_house_c"]

var terrain: TerrainBuilder
var player: Player
var story: Story
var main: Node3D
var combat: CombatBuilder
var hud: Node
var dlg: DialogueUI
var course: Array = []
var race: Array = []
var thief_path: Array = []
var sentry_spots: Array = []
var placed := 0
var _stone: StandardMaterial3D
var _wood: StandardMaterial3D
var _hay: StandardMaterial3D
var _rope: StandardMaterial3D
var _t := 0.0
var _race_t := -1.0
var _race_i := 0
var _thief: Npc
var _thief_i := 0
var _den: Array = []
var _chapel: Array = []
var _sentries: Array = []
var _chasers: Array = []
var _escape_t := -1.0


func _g(x: float, z: float) -> float:
	return terrain.sample_height(x, z)


## world position of a town offset
func _at(o: Vector2) -> Vector3:
	return Vector3(C.x + o.x, _g(C.x + o.x, C.y + o.y), C.y + o.y)


func build() -> void:
	name = "KesarKot"
	_stone = _mat(Color(0.78, 0.62, 0.42))
	_wood = _mat(Color(0.36, 0.24, 0.14))
	_hay = _mat(Color(0.86, 0.74, 0.36))
	_rope = _mat(Color(0.5, 0.38, 0.24))
	_layout()
	_walls()
	_course()
	_nature()
	_statues()
	_people()
	_sentry_posts()
	_quests()


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _layout() -> void:
	# the core: the adobe desert village (its own ground plane removed: the terrain is the ground)
	_place("desert_village", _at(CORE), 75.0, 0.0, "", "Plane")
	# north and south towns: the twelve kit houses, two rows each, with the rooftop road between the north rows
	for row in 2:
		for k in 6:
			var x := -35.0 + k * 14.0
			_place("mud_house", _at(Vector2(x, -67.0 + row * 24.0)), 9.0, PI if row == 1 else 0.0, KIT[row * 6 + k])
			_place("mud_house", _at(Vector2(x, 50.0 + row * 24.0)), 9.0, PI * 0.5 * (row * 2 + 1), KIT[(row * 6 + k + 5) % 12])
	# east gate quarter
	_place("tavern", _at(GATE_Q + Vector2(4, -16)), 11.0, -PI * 0.5)
	var spots := [Vector2(-2, 14), Vector2(8, 26), Vector2(-4, 34), Vector2(6, -34)]
	for k2 in 4:
		_place(SHANTIES[k2], _at(GATE_Q + spots[k2]), 9.0, PI * 0.5 * k2)
	# the den and its yard
	_place("haunted_house", _at(DEN), 18.0, PI * 0.5)
	_place("church", _at(DEN + Vector2(22, -4)), 12.0, 0.4)
	_place("courtyard_ruin", _at(DEN + Vector2(2, 22)), 13.0, 0.0)
	# the chapel and the bridge before it
	_place("chapel_ruin", _at(CHAPEL), 18.0, 0.0)
	_place("stone_bridge", _at(CHAPEL + Vector2(0, -20)), 12.0, PI * 0.5)
	# outside the walls
	_place("belarus_village", _at(Vector2(0, -HZ - 34)), 45.0, 0.0)
	_place("volgar_village", _at(Vector2(0, HZ + 40)), 45.0, 0.0)
	# far scenery: the two city scans below the west cliff (no collision)
	for k3 in 2:
		var o := Vector2(-HX - 40.0, -55.0 + k3 * 110.0)
		var p := Vector3(C.x + o.x, _g(C.x - HX, C.y + o.y) - 10.0, C.y + o.y)
		_place(["ancient_houses", "country_house"][k3], p, 90.0, k3 * 1.3, "", "", false)


## One downloaded model (or one part of a kit) scaled to a footprint, on a plinth that follows the dunes.
func _place(model: String, base: Vector3, foot: float, yaw: float, keep: String = "", drop: String = "", collide := true) -> Node3D:
	var path := "res://assets/sketchfab/%s.scn" % model
	if not ResourceLoader.exists(path):
		return null
	if collide:
		var gq := PhysicsRayQueryParameters3D.create(base + Vector3(0, 200, 0), base + Vector3(0, -200, 0))
		if get_world_3d() != null and get_world_3d().direct_space_state.intersect_ray(gq).is_empty():
			return null                                  # off the playable ground
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	for mi0 in inst.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi0.name)
		if (keep != "" and not nm.begins_with(keep)) or (drop != "" and nm.begins_with(drop)):
			mi0.free()
	add_child(inst)
	var bb := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (mi as MeshInstance3D).get_aabb()
		var xf := (mi as Node3D).transform
		var p: Node = (mi as Node).get_parent()
		while p != inst and p is Node3D:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		a = xf * a
		if a.size.length() < 0.001:
			continue
		bb = a if first else bb.merge(a)
		first = false
	if first:
		inst.queue_free()
		return null
	var s := foot / maxf(maxf(bb.size.x, bb.size.z), 0.01)
	inst.scale = Vector3.ONE * s
	inst.rotation.y = yaw
	var lo := base.y
	var hi := base.y
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var h := _g(base.x + c.x * foot * 0.5, base.z + c.y * foot * 0.5)
		lo = minf(lo, h)
		hi = maxf(hi, h)
	inst.position = Vector3(base.x, hi + 0.05 - bb.position.y * s, base.z)
	inst.position -= inst.basis * (Vector3(bb.get_center().x, 0, bb.get_center().z) * s)
	# every model stands on a stone base reaching below the lowest ground under it: no floating corners
	_block(Vector3(base.x, (hi + lo) * 0.5 - 0.35, base.z), Vector3(foot * 0.95, hi - lo + 0.8, foot * 0.95), _stone)
	for mi2 in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi2 as MeshInstance3D
		m.visibility_range_end = 420.0 if not collide else 170.0
		if not collide:
			continue
		var tris := 0
		for si in m.mesh.get_surface_count():
			tris += (m.mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		if tris < 60000:
			m.create_trimesh_collision()            # real shape: ledges, sills, stairs and roofs climb as they look
	if collide and inst.find_children("*", "StaticBody3D", true, false).is_empty():
		_block(Vector3(base.x, hi + bb.size.y * s * 0.5, base.z), Vector3(bb.size.x * s * 0.9, bb.size.y * s, bb.size.z * s * 0.9), null)
	inst.set_meta("model", model + (":" + keep if keep != "" else ""))
	inst.set_meta("roof", hi + bb.size.y * s)
	placed += 1
	return inst


func _block(pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	if mat != null:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = mat
		b.add_child(mi)
	add_child(b)
	b.global_position = pos
	return b


func _prop(kind: String, pos: Vector3, meta: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.set_meta("kind", kind)
	for k in meta:
		n.set_meta(k, meta[k])
	n.add_to_group("pk_props")
	add_child(n)
	n.global_position = pos
	return n


## The town wall: gates on the east (caravan road) and north.
func _walls() -> void:
	for side in 4:
		var horiz := side >= 2
		var span := HX if horiz else HZ
		var n := int(span * 2.0 / 5.0)
		for seg in n + 1:
			var t := -span + seg * 5.0
			var o := Vector2(t, -HZ if side == 2 else HZ) if horiz else Vector2(HX if side == 0 else -HX, t)
			if (side == 0 and absf(t) < 7.0) or (side == 2 and absf(t) < 7.0):
				continue                                   # gates
			var p := _at(o)
			_block(p + Vector3(0, 2.2, 0), Vector3(5.2, 4.4, 1.2) if horiz else Vector3(1.2, 4.4, 5.2), _stone)
	story.refs["kk_gate"] = _at(Vector2(HX + 4.0, 0))


## The rooftop road: one obstacle for every captured parkour move, in order, with a checkpoint after each.
func _course() -> void:
	var z := C.y + COURSE_Z
	var x0 := C.x + 55.0
	var g := func(x: float) -> float: return _g(x, z)
	for k in 3:
		_block(Vector3(x0 - k * 3.0, g.call(x0 - k * 3.0) + 0.5, z), Vector3(1.0, 1.0, 1.0), _wood)          # crates: vault
	_block(Vector3(x0 - 11.0, g.call(x0 - 11.0) + 0.55, z), Vector3(0.2, 1.1, 3.6), _wood)                 # fence: jump over
	course.append(Vector3(x0 - 13.0, g.call(x0 - 13.0), z))
	_block(Vector3(x0 - 16.0, g.call(x0 - 16.0) + 0.6, z), Vector3(0.6, 1.2, 3.6), _stone)                 # waist wall: mantle
	_block(Vector3(x0 - 21.0, g.call(x0 - 21.0) + 1.25, z), Vector3(1.6, 2.5, 3.6), _stone)                # garden wall: climb
	course.append(Vector3(x0 - 21.0, g.call(x0 - 21.0) + 2.55, z))
	_block(Vector3(x0 - 26.0, g.call(x0 - 26.0) + 2.3, z), Vector3(1.6, 4.6, 3.6), _stone)                 # tall wall: wall run
	course.append(Vector3(x0 - 26.0, g.call(x0 - 26.0) + 4.65, z))
	var dw := _block(Vector3(x0 - 34.0, g.call(x0 - 34.0) + 1.8, z - 1.8), Vector3(8.0, 3.6, 0.4), _stone) # diagonal wall run
	dw.rotation.y = 0.35
	course.append(Vector3(x0 - 39.0, g.call(x0 - 39.0), z))
	var lx := x0 - 44.0
	var ly: float = g.call(lx)
	_block(Vector3(lx, ly + 3.0, z - 2.5), Vector3(4.0, 6.0, 3.0), _stone)
	_ladder(Vector3(lx, ly, z - 0.95), Vector3(0, 0, 1), ly + 6.0, Vector3(lx, ly + 6.0, z - 2.5))      # ladder
	course.append(Vector3(lx, ly + 6.05, z - 2.5))
	_block(Vector3(lx - 6.0, ly + 5.95, z - 2.5), Vector3(8.0, 0.12, 0.6), _wood)                          # plank across a gap
	_block(Vector3(lx - 12.0, ly + 3.0, z - 2.5), Vector3(4.0, 6.0, 3.0), _stone)
	_bar(Vector3(lx - 16.5, ly + 7.6, z - 2.5), Vector3(-1, 0, 0))                                          # swing bar over a gap
	_block(Vector3(lx - 21.0, ly + 3.0, z - 2.5), Vector3(4.0, 6.0, 3.0), _stone)
	course.append(Vector3(lx - 21.0, ly + 6.05, z - 2.5))
	var rx := lx - 27.0
	var ry: float = g.call(rx)
	_block(Vector3(rx - 3.0, ry + 4.5, z - 2.5), Vector3(4.0, 9.0, 3.0), _stone)
	_block(Vector3(rx, ry + 9.2, z - 2.5), Vector3(2.4, 0.25, 0.25), _wood)
	_rope_at(Vector3(rx, ry, z - 2.5), ry + 9.0, Vector3(rx - 3.0, ry + 9.05, z - 2.5))                 # rope
	course.append(Vector3(rx - 3.0, ry + 9.05, z - 2.5))
	_tower(Vector3(rx - 9.0, _g(rx - 9.0, z - 6.0), z - 6.0))                                               # window
	_hay_at(Vector3(rx - 9.0, _g(rx - 9.0, z + 4.2), z + 4.2))                                              # leap of faith: where a window leap lands
	course.append(Vector3(rx - 9.0, _g(rx - 9.0, z + 4.2), z + 4.2))
	# more haystacks under high roofs all over town, for drops and escapes
	for o in [Vector2(30, -20), Vector2(-30, 25), Vector2(40, 60), Vector2(-20, -80), Vector2(20, 100)]:
		_hay_at(_at(o))
	# extra ladders onto kit-house roofs in the south town
	for k in 3:
		var lp := _at(Vector2(-28.0 + k * 28.0, 44.0))
		# measure the real roof just behind the ladder, so it ends at the roof edge (kit houses differ in height)
		var rq := PhysicsRayQueryParameters3D.create(lp + Vector3(0, 40, 1.0), lp + Vector3(0, -2, 1.0))
		var rh := get_world_3d().direct_space_state.intersect_ray(rq)
		if not rh.is_empty():
			var ry0: float = (rh["position"] as Vector3).y
			if ry0 - lp.y > 2.0 and ry0 - lp.y < 12.0:
				_ladder(lp, Vector3(0, 0, -1), ry0, Vector3(lp.x, ry0 + 0.05, lp.z + 1.0))
	story.refs["kk_course0"] = course[0]
	# courier race: a ring of marks across the whole town
	for k2 in 12:
		var a := TAU * k2 / 12.0
		var p := Vector2(C.x + cos(a) * 48.0, C.y + sin(a) * 95.0)
		race.append(Vector3(p.x, _g(p.x, p.y) + 1.0, p.y))
	thief_path = race.duplicate()
	thief_path.reverse()


func _ladder(pos: Vector3, out: Vector3, top: float, exit: Vector3) -> void:
	var side_v := out.cross(Vector3.UP).normalized()
	for side in [-0.25, 0.25]:
		var rail := MeshInstance3D.new()
		var bm0 := BoxMesh.new()
		bm0.size = Vector3(0.06, top - pos.y, 0.06)
		rail.mesh = bm0
		rail.material_override = _wood
		add_child(rail)
		rail.global_position = pos + side_v * side + Vector3(0, (top - pos.y) * 0.5, 0)
	for k in int((top - pos.y) / 0.35):
		var rung := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.04, 0.05)
		rung.mesh = bm
		rung.material_override = _wood
		add_child(rung)
		rung.global_position = pos + Vector3(0, 0.3 + k * 0.35, 0)
		rung.look_at(rung.global_position + out, Vector3.UP)
	_prop("ladder", pos, {"top": top, "dir": out, "exit": exit})


func _rope_at(pos: Vector3, top: float, exit: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.035
	cm.height = top - pos.y
	mi.mesh = cm
	mi.material_override = _rope
	add_child(mi)
	mi.global_position = pos + Vector3(0, (top - pos.y) * 0.5, 0)
	_prop("rope", pos, {"top": top, "exit": exit})


func _bar(pos: Vector3, dir: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.05
	cm.height = 3.0
	mi.mesh = cm
	mi.material_override = _wood
	add_child(mi)
	mi.global_position = pos
	mi.rotation.x = PI * 0.5
	_prop("bar", pos, {"dir": dir})


func _hay_at(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.6
	sm.height = 1.8
	mi.mesh = sm
	mi.material_override = _hay
	add_child(mi)
	mi.global_position = pos + Vector3(0, 0.5, 0)
	_prop("hay", pos, {"radius": 1.8})


## A watchtower with an upper room and an open window over the haystack (jump out with JUMP).
func _tower(pos: Vector3) -> void:
	var h := 10.0
	for side in [Vector3(1.6, 0, 0), Vector3(-1.6, 0, 0), Vector3(0, 0, -1.6)]:
		var sz := Vector3(0.3, h, 3.5) if side.x != 0.0 else Vector3(3.5, h, 0.3)
		_block(pos + side + Vector3(0, h * 0.5, 0), sz, _stone)
	_block(pos + Vector3(0, 3.5, 1.6), Vector3(3.5, 7.0, 0.3), _stone)
	_block(pos + Vector3(-1.2, 8.5, 1.6), Vector3(1.1, 3.0, 0.3), _stone)
	_block(pos + Vector3(1.2, 8.5, 1.6), Vector3(1.1, 3.0, 0.3), _stone)
	_block(pos + Vector3(0, 7.05, 0), Vector3(3.2, 0.2, 3.2), _wood)
	_block(pos + Vector3(0, h + 0.1, 0), Vector3(3.8, 0.2, 3.8), _wood)
	_ladder(pos + Vector3(0, 0, -1.2), Vector3(0, 0, 1), pos.y + 7.0, pos + Vector3(0, 7.1, -0.4))
	_prop("window", pos + Vector3(0, 7.2, 1.5), {"dir": Vector3(0, 0, 1)})
	story.refs["kk_tower"] = pos + Vector3(0, 7.2, 0.8)


## Trees and plants: the oak grove and pines by the north farmstead, small trees and ferns along the walls,
## vines on the core village walls.
func _nature() -> void:
	_place("oak_pack", _at(Vector2(-40, -HZ - 30)), 40.0, PI * 0.5)
	_place("pine_stand", _at(Vector2(42, -HZ - 30)), 32.0, 0.0)
	for k in 20:
		var a := TAU * k / 20.0
		var o := Vector2(cos(a) * (HX - 5.0), sin(a) * (HZ - 6.0))
		_place(["tree_low", "beech_fern", "mossy_branch", "grass_pack"][k % 4], _at(o), [6.0, 1.6, 2.4, 3.0][k % 4], a)
	for k2 in 6:
		var o2 := Vector2(-30.0 + k2 * 12.0, 38.0 if k2 % 2 == 0 else -38.0)
		_place(["vines", "vine_branch"][k2 % 2], _at(o2), 3.0, k2 * 1.1)


## The four Atahan3D figures as statues in the gate plaza; the necromorph and the nebula window in the chapel;
## the fantasy sky as the painted dome over the tavern's tower.
func _statues() -> void:
	var c := _at(GATE_Q + Vector2(2, 2))
	var names := ["morwenna", "vesper", "fenwillow", "thalvoris"]
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var p := c + Vector3(cos(a) * 4.5, 0, sin(a) * 4.5)
		_block(p + Vector3(0, 0.4, 0), Vector3(1.4, 0.8, 1.4), _stone)
		_place(names[k], p + Vector3(0, 0.8, 0), 1.0, a + PI, "", "", false)
	_place("necromorph", _at(CHAPEL) + Vector3(0, 0.2, 2.0), 2.6, 0.7, "", "", false)
	_place("nebula_sky", _at(CHAPEL) + Vector3(0, 4.0, -3.0), 3.0, 0.0, "", "", false)
	_place("fantasy_sky", _at(GATE_Q + Vector2(4, -16)) + Vector3(0, 13.0, 0), 4.0, 0.0, "", "", false)
	# training bag by the tavern (the captured punching-bag drill) and a crate to push (the captured push)
	var bp := _at(GATE_Q + Vector2(-6, -8))
	_block(bp + Vector3(0, 2.6, 0), Vector3(0.2, 0.2, 1.6), _wood)
	var bag := MeshInstance3D.new()
	var bcm := CylinderMesh.new()
	bcm.top_radius = 0.28
	bcm.bottom_radius = 0.28
	bcm.height = 1.1
	bag.mesh = bcm
	bag.material_override = _mat(Color(0.45, 0.25, 0.15))
	add_child(bag)
	bag.global_position = bp + Vector3(0, 1.6, 0)
	var train := Interactable.new()
	train.prompt = "Train on the bag"
	train.reach = 2.2
	add_child(train)
	train.global_position = bp + Vector3(0, 1.4, 0.8)
	train.on_interact = func(by: Node3D, _me: Interactable) -> void:
		if by is Player:
			(by as Player)._rig.play_clip("mx_punching_bag", 1.0, 1.0, false, 0.0, 0.1)
			(by as Player)._pk_count("train")
	var crate := _block(_at(GATE_Q + Vector2(-8, 6)) + Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 1.0), _wood)
	var push := Interactable.new()
	push.prompt = "Push the crate"
	push.reach = 2.0
	crate.add_child(push)
	push.on_interact = func(by: Node3D, _me: Interactable) -> void:
		if by is Player:
			var dirp := (crate.global_position - by.global_position) * Vector3(1, 0, 1)
			(by as Player)._rig.play_clip("ual_push", 1.0, 1.0, false, 0.0, 0.1)
			create_tween().tween_property(crate, "global_position", crate.global_position + dirp.normalized() * 2.0, 1.2)
			(by as Player)._pk_count("push")


func _people() -> void:
	var ravi := Npc.new().setup(NpcBuilder.PRESETS["trader"], "idle", "Ravi")
	ravi.player = player
	main.add_child(ravi)
	var gp: Vector3 = story.refs["kk_gate"]
	ravi.global_position = gp + Vector3(-6.0, 0.0, 3.0)
	story.refs["Ravi"] = ravi
	main.npcs.append(ravi)
	var it := Interactable.new()
	it.prompt = "Talk"
	it.reach = 3.0
	it.position = Vector3(0, 1.4, 0)
	it.on_interact = func(_by: Node3D, _me: Interactable) -> void:
		dlg.open(_ravi_talk(), ravi, "man")
	ravi.add_child(it)


## Where the gang's lookouts stand: wall corners and gates, north-town roofs, the den, the watch post, the chapel.
func _sentry_posts() -> void:
	for o in [Vector2(HX - 3, -HZ + 3), Vector2(-HX + 3, -HZ + 3), Vector2(HX - 3, HZ - 3), Vector2(-HX + 3, HZ - 3),
			Vector2(HX - 4, 10), Vector2(8, -HZ + 4), Vector2(-21, -67), Vector2(21, -67), Vector2(-7, -43),
			DEN + Vector2(10, 10), DEN + Vector2(22, -4), CHAPEL + Vector2(0, -24)]:
		sentry_spots.append(_at(o))


func _ravi_talk() -> Dictionary:
	var n := {}
	if not story.get_flag("kk_talk"):
		n["a"] = {"who": "Ravi the lamp-keeper", "text": "A traveller in Kesar Kot? You walked into a cage, friend. The Kaali Pagdi, the Black Turbans, took our town at the new moon. They sealed the Archive of the Sun Queen, the same archive your Dr. Arin wrote to me about, and their lookouts watch every street.",
			"choices": [{"t": "Then how does anyone move?", "go": "b"}]}
		n["b"] = {"who": "Ravi the lamp-keeper", "text": "Over the roofs, as my grandfather did when he lit the lamps. Learn the rooftop road: from the crates in the north lane to the old watchtower. Jump from its window into the hay. Then come back to me.",
			"set": {"kk_talk": true}, "choices": [{"t": "Show me the rooftops.", "go": ""}]}
		return {"start": "a", "nodes": n}
	if story.get_flag("kk_leap") and not story.get_flag("kk_q1_done"):
		n["a"] = {"who": "Ravi the lamp-keeper", "text": "You fly like a kite! Our courier Meena carries lamp oil over the roofs each night, and the lookouts are learning her path. Run her route faster than she can, so they chase a ghost.",
			"set": {"kk_q1_done": true}, "choices": [{"t": "I'll run the courier route.", "go": ""}]}
		return {"start": "a", "nodes": n}
	if story.get_flag("kk_escaped") and not story.get_flag("kk_done"):
		n["a"] = {"who": "Ravi the lamp-keeper", "text": "You came through the gate with half the gang behind you and the Sun Queen's key in your fist! Inside the archive are the star-maps Dr. Arin was hunting. Tonight every lamp in Kesar Kot burns for you.",
			"set": {"kk_done": true}, "choices": [{"t": "Keep the lamps burning, Ravi.", "go": ""}]}
		return {"start": "a", "nodes": n}
	n["a"] = {"who": "Ravi the lamp-keeper", "text": "The roofs remember those who walk them. Keep going; the archive is close.", "choices": [{"t": "Farewell.", "go": ""}]}
	return {"start": "a", "nodes": n}


## The Shadow Quarter: eight missions in a row.
func _quests() -> void:
	var s := story
	var ravi_pos := func() -> Vector3: return (s.refs["Ravi"] as Node3D).global_position
	s.quests.append({"id": "kk1", "title": "Kesar Kot: The Rooftop Road",
		"blurb": "A great walled town held by the Kaali Pagdi gang. Ravi the lamp-keeper knows a way over the roofs.",
		"show": func() -> bool: return s.get_flag("met_chief"),
		"objs": [
			{"text": func() -> String: return "Reach the gate of Kesar Kot", "done": func() -> bool: return s.get_flag("kk_arrived"), "target": func() -> Vector3: return s.refs["kk_gate"]},
			{"text": func() -> String: return "Talk to Ravi the lamp-keeper", "done": func() -> bool: return s.get_flag("kk_talk"), "target": ravi_pos},
			{"text": func() -> String: return "Run the rooftop road (%d/%d)" % [int(s.get_flag("kk_cp", 0)), course.size() - 1], "done": func() -> bool: return int(s.get_flag("kk_cp", 0)) >= course.size() - 1, "target": func() -> Vector3: return course[mini(int(s.get_flag("kk_cp", 0)), course.size() - 1)]},
			{"text": func() -> String: return "Jump from the watchtower window into the hay", "done": func() -> bool: return s.get_flag("kk_leap"), "target": func() -> Vector3: return s.refs["kk_tower"]},
			{"text": func() -> String: return "Return to Ravi", "done": func() -> bool: return s.get_flag("kk_q1_done"), "target": ravi_pos},
		]})
	s.quests.append({"id": "kk2", "title": "Kesar Kot: The Courier's Run",
		"blurb": "Run the lamp-oil route over the whole town before the lookouts can follow. 12 marks in 180 seconds.",
		"show": func() -> bool: return s.get_flag("kk_q1_done"),
		"objs": [{"text": func() -> String: return ("Courier run: mark %d/12, %d s left" % [_race_i, int(maxf(0.0, 180.0 - _race_t))]) if _race_t >= 0.0 else "Start the courier run at the first mark",
			"done": func() -> bool: return s.get_flag("kk_race_done"), "target": func() -> Vector3: return race[mini(_race_i, race.size() - 1)]}]})
	s.quests.append({"id": "kk3", "title": "Kesar Kot: Thief of the Archive",
		"blurb": "A Black Turban runner grabbed the archive ledger and is fleeing over the roofs. Catch him!",
		"show": func() -> bool: return s.get_flag("kk_race_done"),
		"objs": [{"text": func() -> String: return "Catch the ledger thief", "done": func() -> bool: return s.get_flag("kk_thief"), "target": func() -> Vector3: return _thief.global_position if is_instance_valid(_thief) else race[0]}]})
	s.quests.append({"id": "kk4", "title": "Kesar Kot: Silent Night",
		"blurb": "The ledger lists the gang's lookouts. Take them down one by one before the den can be stormed. Strike from behind or from above while they have not seen you.",
		"show": func() -> bool: return s.get_flag("kk_thief"),
		"objs": [{"text": func() -> String: return "Silence the lookouts (%d/%d)" % [int(s.get_flag("kk_sentry", 0)), sentry_spots.size()], "done": func() -> bool: return int(s.get_flag("kk_sentry", 0)) >= sentry_spots.size(), "target": func() -> Vector3: return _next_sentry()}]})
	s.quests.append({"id": "kk5", "title": "Kesar Kot: The Black Turban Den",
		"blurb": "Without its lookouts the den in the old haunted mansion is blind. Storm it and break the Kaali Pagdi.",
		"show": func() -> bool: return int(s.get_flag("kk_sentry", 0)) >= sentry_spots.size(),
		"objs": [{"text": func() -> String: return "Defeat the Kaali Pagdi at the den (%d/7)" % int(s.get_flag("kk_den", 0)), "done": func() -> bool: return int(s.get_flag("kk_den", 0)) >= 7, "target": func() -> Vector3: return _at(DEN)}]})
	s.quests.append({"id": "kk6", "title": "Kesar Kot: The Chapel of Bells",
		"blurb": "The gang's leader fled to the ruined chapel, where the dead do not stay down. The Sun Queen's key is on its altar.",
		"show": func() -> bool: return int(s.get_flag("kk_den", 0)) >= 7,
		"objs": [
			{"text": func() -> String: return "Clear the chapel (%d/6)" % int(s.get_flag("kk_chapel", 0)), "done": func() -> bool: return int(s.get_flag("kk_chapel", 0)) >= 6, "target": func() -> Vector3: return _at(CHAPEL)},
			{"text": func() -> String: return "Take the archive key from the altar", "done": func() -> bool: return s.get_flag("kk_archive"), "target": func() -> Vector3: return _at(CHAPEL) + Vector3(0, 1, 0)}]})
	s.quests.append({"id": "kk7", "title": "Kesar Kot: Escape!",
		"blurb": "The bells woke the whole gang. Run for the east gate with the key before they cut you off.",
		"show": func() -> bool: return s.get_flag("kk_archive"),
		"objs": [{"text": func() -> String: return ("Escape to the east gate (%d s)" % int(maxf(0.0, 120.0 - _escape_t))) if _escape_t >= 0.0 else "Escape to the east gate", "done": func() -> bool: return s.get_flag("kk_escaped"), "target": func() -> Vector3: return s.refs["kk_gate"]}]})
	s.quests.append({"id": "kk8", "title": "Kesar Kot: The Sun Queen's Archive",
		"blurb": "Bring the key to Ravi and open the archive Dr. Arin was searching for.",
		"show": func() -> bool: return s.get_flag("kk_escaped"),
		"objs": [{"text": func() -> String: return "Give the key to Ravi", "done": func() -> bool: return s.get_flag("kk_done"), "target": ravi_pos}]})
	var key := Interactable.new()
	key.prompt = "Take the archive key"
	key.reach = 3.0
	add_child(key)
	key.global_position = _at(CHAPEL) + Vector3(0, 1.0, 0)
	key.on_interact = func(_by: Node3D, me: Interactable) -> void:
		if int(story.get_flag("kk_chapel", 0)) >= 6:
			story.set_flag("kk_archive", true)
			hud.banner(Loc.t("The bells! The whole gang is coming. RUN!"), "mission_new")
			me.enabled = false


func _next_sentry() -> Vector3:
	for e in _sentries:
		if is_instance_valid(e) and not (e as Enemy).dead:
			return (e as Enemy).global_position
	return sentry_spots[0]


func _process(delta: float) -> void:
	_t -= delta
	if _race_t >= 0.0:
		_race_t += delta
	if _escape_t >= 0.0:
		_escape_t += delta
	if _t > 0.0 or player == null:
		return
	_t = 0.25
	var pp := player.global_position
	if not story.get_flag("kk_arrived") and pp.distance_to(story.refs["kk_gate"]) < 15.0:
		story.set_flag("kk_arrived", true)
		hud.banner(Loc.t("Kesar Kot"), "mission_new")
	var cp := int(story.get_flag("kk_cp", 0))
	if story.get_flag("kk_talk") and cp < course.size() - 1 and pp.distance_to(course[cp]) < 2.5:
		story.set_flag("kk_cp", cp + 1)
		Sfx.ui("ui_blip", -4.0)
	if story.get_flag("kk_talk") and not story.get_flag("kk_leap") and int(player.pk_moves.get("hay", 0)) > 0:
		story.set_flag("kk_leap", true)
	_tick_race(pp)
	_tick_thief(pp)
	_tick_sentries()
	_tick_fights()
	_tick_escape(pp)


func _tick_race(pp: Vector3) -> void:
	if not story.get_flag("kk_q1_done") or story.get_flag("kk_race_done"):
		return
	if _race_t < 0.0:
		if pp.distance_to(race[0]) < 3.0:
			_race_t = 0.0
			_race_i = 1
			hud.banner(Loc.t("Courier run: GO!"), "mission_new")
		return
	if _race_i < race.size() and pp.distance_to(race[_race_i]) < 3.0:
		_race_i += 1
		Sfx.ui("ui_blip", -4.0)
	if _race_i >= race.size():
		story.set_flag("kk_race_done", true)
		_race_t = -1.0
	elif _race_t > 180.0:
		_race_t = -1.0
		_race_i = 0
		hud.banner(Loc.t("Too slow! Start again at the first mark."), "")


func _tick_thief(pp: Vector3) -> void:
	if not story.get_flag("kk_race_done") or story.get_flag("kk_thief"):
		return
	if _thief == null:
		_thief = Npc.new().setup(NpcBuilder.PRESETS["villager_man"], "idle", "Thief")
		_thief.player = player
		main.add_child(_thief)
		_thief.global_position = thief_path[0]
	var tgt: Vector3 = thief_path[_thief_i]
	var to := tgt - _thief.global_position
	var spd := 5.2 if pp.distance_to(_thief.global_position) < 30.0 else 0.0
	if to.length() < 1.0:
		_thief_i = (_thief_i + 1) % thief_path.size()
	else:
		_thief.global_position += to.normalized() * minf(spd * 0.25, to.length())
		_thief.global_position.y = _g(_thief.global_position.x, _thief.global_position.z)
	if pp.distance_to(_thief.global_position) < 2.5:
		story.set_flag("kk_thief", true)
		hud.banner(Loc.t("Caught! The ledger lists every lookout of the gang."), "mission_new")
		_thief.queue_free()


## Lookouts: unaware until you come close in front of them (short sight); a strike from behind or above while
## they have not seen you is a silent takedown (Player._try_takedown).
func _tick_sentries() -> void:
	if not story.get_flag("kk_thief") or int(story.get_flag("kk_sentry", 0)) >= sentry_spots.size() or not _sentries.is_empty():
		return
	for p in sentry_spots:
		var e := combat.spawn_enemy((p as Vector3) + Vector3(0, 12.0, 0), false, 7.0, "kk_sentry")
		e.add_to_group("sentries")
		e.died.connect(func(_e = null) -> void: story.add("kk_sentry", 1))
		_sentries.append(e)


func _tick_fights() -> void:
	if int(story.get_flag("kk_sentry", 0)) >= sentry_spots.size() and int(story.get_flag("kk_den", 0)) < 7 and _den.is_empty():
		for k in 7:
			var a := TAU * k / 7.0
			var e := combat.spawn_enemy(_at(DEN) + Vector3(cos(a) * 11.0, 0.5, sin(a) * 11.0), k == 6, 30.0, "kk_den")
			e.died.connect(func(_e = null) -> void: story.add("kk_den", 1))
			_den.append(e)
	if int(story.get_flag("kk_den", 0)) >= 7 and int(story.get_flag("kk_chapel", 0)) < 6 and _chapel.is_empty():
		for k2 in 6:
			var a2 := TAU * k2 / 6.0
			var z := combat.spawn_enemy(_at(CHAPEL) + Vector3(cos(a2) * 8.0, 0.5, sin(a2) * 8.0), false, 30.0, "kk_chapel")
			z.apply_role("zombie" if k2 % 2 == 0 else "zombie_runner")
			z.died.connect(func(_e = null) -> void: story.add("kk_chapel", 1))
			_chapel.append(z)


## The escape: once the key is taken, gang fighters pour out of the den and the chapel; reach the east gate in 120 s.
func _tick_escape(pp: Vector3) -> void:
	if not story.get_flag("kk_archive") or story.get_flag("kk_escaped"):
		return
	if _escape_t < 0.0:
		_escape_t = 0.0
		for k in 8:
			var a := TAU * k / 8.0
			var at := _at(CHAPEL if k % 2 == 0 else DEN) + Vector3(cos(a) * 14.0, 0.5, sin(a) * 14.0)
			_chasers.append(combat.spawn_enemy(at, false, 90.0, "kk_escape"))
	if pp.distance_to(story.refs["kk_gate"]) < 8.0:
		story.set_flag("kk_escaped", true)
		_escape_t = -1.0
		hud.banner(Loc.t("You escaped Kesar Kot!"), "mission_new")
		for e in _chasers:
			if is_instance_valid(e):
				(e as Node).queue_free()
		_chasers.clear()
	elif _escape_t > 120.0:
		_escape_t = 0.0
		hud.banner(Loc.t("They cut you off! Back to the chapel; run again."), "")
		player.global_position = _at(CHAPEL) + Vector3(0, 1.0, -6.0)
		player.velocity = Vector3.ZERO
