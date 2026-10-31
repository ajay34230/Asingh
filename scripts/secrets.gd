class_name Secrets
extends Node3D
## X16: five buried caches around the valley (they glimmer when you are near) and a relic chest at the ruins
## that only appears at night. Caches pay coins and crafting items; five found = "Treasure Hunter".

const CACHES := [Vector2(-90.0, -20.0), Vector2(60.0, 110.0), Vector2(120.0, -80.0), Vector2(-20.0, 150.0), Vector2(-160.0, 60.0)]
const NIGHT_CHEST := Vector2(14.0, -125.0)

var story: Story
var player: Player
var terrain: TerrainBuilder
var hud: Node
var atmo: Atmosphere
var nodes: Array[Node3D] = []
var its: Array[Interactable] = []
var sparks: Array[CPUParticles3D] = []
var chest: Node3D
var chest_it: Interactable
var _t := 0.0


func build() -> void:
	add_to_group("secrets")
	for i in CACHES.size():
		var p := Vector3(CACHES[i].x, terrain.sample_height(CACHES[i].x, CACHES[i].y), CACHES[i].y)
		var n := Node3D.new()
		n.name = "Cache%d" % i
		add_child(n)
		n.global_position = p
		PropFactory.box(n, Vector3(0.8, 0.5, 0.55), Vector3(0, 0.15, 0), PropFactory.wood(Color(0.3, 0.2, 0.12)), Vector3.ZERO, false, false)
		var sp := _sparkle()
		n.add_child(sp)
		sp.position = Vector3(0, 0.6, 0)
		sparks.append(sp)
		var it := Interactable.new()
		it.position = Vector3(0, 0.6, 0)
		it.prompt = "Open the buried cache"
		it.reach = 2.6
		n.add_child(it)
		var idx := i
		it.on_interact = func(_by: Node3D, _me: Interactable) -> void: open_cache(idx)
		nodes.append(n)
		its.append(it)
		if story.get_flag("cache_%d" % i, false):
			n.visible = false
			it.enabled = false
	chest = Node3D.new()
	chest.name = "NightRelic"
	add_child(chest)
	chest.global_position = Vector3(NIGHT_CHEST.x, terrain.sample_height(NIGHT_CHEST.x, NIGHT_CHEST.y), NIGHT_CHEST.y)
	PropFactory.box(chest, Vector3(1.0, 0.7, 0.7), Vector3(0, 0.35, 0), PropFactory.material(Color(0.8, 0.65, 0.2), 0.3, 0.7, Color(1, 0.8, 0.3), 1.5), Vector3.ZERO, false, false)
	chest_it = Interactable.new()
	chest_it.position = Vector3(0, 0.8, 0)
	chest_it.prompt = "Open the moonlit relic chest"
	chest_it.reach = 2.8
	chest.add_child(chest_it)
	chest_it.on_interact = func(_by: Node3D, _me: Interactable) -> void: open_night_chest()
	chest.visible = false
	chest_it.enabled = false


func _sparkle() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 8
	p.lifetime = 1.6
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.direction = Vector3(0, 1, 0)
	p.spread = 30.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.5
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.08
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(1.0, 0.9, 0.4)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.85, 0.3)
	m.emission_energy_multiplier = 3.0
	q.material = m
	p.mesh = q
	p.emitting = false
	return p


func found() -> int:
	var n := 0
	for i in CACHES.size():
		if story.get_flag("cache_%d" % i, false):
			n += 1
	return n


func open_cache(i: int) -> bool:
	if story.get_flag("cache_%d" % i, false):
		return false
	story.set_flag("cache_%d" % i, true)
	its[i].enabled = false
	nodes[i].visible = false
	var coins := 40 + 15 * i
	story.set_flag("coins", int(story.get_flag("coins", 0)) + coins)
	var itm := player.get_tree().get_first_node_in_group("items") as Items
	if itm != null:
		itm.give(["iron", "hide", "herb", "iron", "potion"][i % 5], 2 if i % 5 != 4 else 1)
	hud.banner(Loc.t("Cache found! +%d coins (%d/5)") % [coins, found()], "seal_found")
	var ach := player.get_tree().get_first_node_in_group("achievements")
	if ach != null and found() >= 5:
		ach.unlock("hunter")
	return true


func open_night_chest() -> bool:
	if story.get_flag("night_chest", false):
		return false
	story.set_flag("night_chest", true)
	chest_it.enabled = false
	chest.visible = false
	story.set_flag("coins", int(story.get_flag("coins", 0)) + 200)
	var itm := player.get_tree().get_first_node_in_group("items") as Items
	if itm != null:
		itm.give("chain")
	hud.banner(Loc.t("The relic chest holds 200 coins and chain mail!"), "reveal")
	return true


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	for i in nodes.size():
		var open: bool = story.get_flag("cache_%d" % i, false)
		sparks[i].emitting = not open and nodes[i].global_position.distance_to(player.global_position) < 28.0
	var night := atmo != null and atmo.night > 0.7
	var taken: bool = story.get_flag("night_chest", false)
	chest.visible = night and not taken
	chest_it.enabled = night and not taken
