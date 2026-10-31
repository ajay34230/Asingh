class_name Shrines
extends Node3D
## X15: four stone shrines. Touch one to light it; lit shrines become fast-travel stops in the pause menu.
## Travel is refused while enemies are close or shortly after combat.

const SPOTS := [
	["bazaar", "Bazaar Shrine", Vector2(22.0, -22.0)],
	["pond", "Pond Shrine", Vector2(-60.0, 52.0 + 22.0)],
	["forest", "Forest Shrine", Vector2(-150.0 + 46.0, -110.0)],
	["ruins", "Ruins Shrine", Vector2(0.0, -112.0)],
]

var main: Node3D
var terrain: TerrainBuilder
var story: Story
var player: Player
var hud: Node
var flames := {}
var items: Array[Interactable] = []


func build() -> void:
	var stone := PropFactory.stone(Color(0.62, 0.56, 0.48))
	var glow := PropFactory.glow_lamp()
	for s in SPOTS:
		var id: String = s[0]
		var p2: Vector2 = s[2]
		var n := Node3D.new()
		n.name = "Shrine_" + id
		add_child(n)
		n.global_position = Vector3(p2.x, terrain.sample_height(p2.x, p2.y), p2.y)
		PropFactory.cylinder(n, 0.9, 1.1, 0.35, Vector3(0, 0.17, 0), stone, Vector3.ZERO, false, 10)
		PropFactory.cylinder(n, 0.28, 0.4, 1.6, Vector3(0, 1.15, 0), stone, Vector3.ZERO, false, 8)
		PropFactory.cylinder(n, 0.5, 0.35, 0.2, Vector3(0, 2.05, 0), stone, Vector3.ZERO, false, 8)
		var flame := PropFactory.sphere(n, 0.18, Vector3(0, 2.35, 0), glow, Vector3(1, 1.5, 1))
		flame.visible = false
		flames[id] = flame
		var it := Interactable.new()
		it.position = Vector3(0, 1.2, 0)
		it.reach = 3.2
		n.add_child(it)
		items.append(it)
		it.on_interact = func(_by: Node3D, me: Interactable) -> void:
			light(id)
			me.prompt = "Shrine (lit)"
		it.prompt = "Light shrine" if not is_lit(id) else "Shrine (lit)"
		flame.visible = is_lit(id)


func is_lit(id: String) -> bool:
	return story != null and bool(story.get_flag("shrine_" + id, false))


func light(id: String) -> bool:
	if is_lit(id):
		return false
	story.set_flag("shrine_" + id, true)
	if flames.has(id):
		(flames[id] as Node3D).visible = true
	if hud != null:
		hud.banner(Loc.t("Shrine lit - fast travel unlocked"), "")
	return true


func lit_list() -> Array:
	var out: Array = []
	for s in SPOTS:
		if is_lit(String(s[0])):
			out.append(s)
	return out


func can_travel() -> bool:
	if player == null or player.dead or player.mounted:
		return false
	if player._combat_t < 6.0:
		return false
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Node3D).global_position.distance_to(player.global_position) < 20.0:
			return false
	return true


func travel(id: String) -> bool:
	if not is_lit(id) or not can_travel():
		return false
	for s in SPOTS:
		if String(s[0]) == id:
			var p2: Vector2 = s[2]
			main.call("_teleport", p2.x + 2.5, p2.y + 2.5)
			return true
	return false
