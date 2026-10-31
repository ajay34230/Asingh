class_name BountyBoard
extends Node3D
## Repeatable jobs posted on a notice board in the bazaar. Each job counts a world counter (kills, harvests,
## sales, coins found) from the moment it is accepted, and pays coins when claimed.

const JOBS := [
	{"id": "slay", "name": "Clear the Roads", "desc": "Defeat 5 bandits.", "counter": "kills", "goal": 5, "reward": 90},
	{"id": "harvest", "name": "Fill the Granary", "desc": "Harvest 6 ripe fields.", "counter": "harvests", "goal": 6, "reward": 70},
	{"id": "trade", "name": "Fair Trade", "desc": "Earn 150 coins at the market.", "counter": "sales", "goal": 150, "reward": 60},
	{"id": "scavenge", "name": "Lost Purses", "desc": "Find 10 gold coins in the world.", "counter": "coins_found", "goal": 10, "reward": 50},
]

var terrain: TerrainBuilder
var story: Story
var player: Player
var hud: Node
var coins: CoinSystem
var shop: ShopUI
var items: Items


func build() -> void:
	add_to_group("bounty_board")
	var p := Vector2(26.0, -22.0)
	global_position = Vector3(p.x, terrain.sample_height(p.x, p.y), p.y)
	var wood := PropFactory.material(Color(0.4, 0.27, 0.15), 0.9)
	PropFactory.box(self, Vector3(0.18, 2.2, 0.18), Vector3(-0.9, 1.1, 0), wood, Vector3.ZERO, true)
	PropFactory.box(self, Vector3(0.18, 2.2, 0.18), Vector3(0.9, 1.1, 0), wood, Vector3.ZERO, true)
	PropFactory.box(self, Vector3(2.1, 1.3, 0.12), Vector3(0, 1.55, 0), PropFactory.material(Color(0.55, 0.4, 0.22), 0.9), Vector3.ZERO, false)
	for i in 3:
		PropFactory.box(self, Vector3(0.45, 0.6, 0.03), Vector3(-0.6 + 0.6 * i, 1.55, 0.08), PropFactory.material(Color(0.9, 0.85, 0.7), 1.0), Vector3(0, 0, -6 + 6 * i), false)
	var sign_l := Label3D.new()
	sign_l.text = "BOUNTIES"
	sign_l.font_size = 40
	sign_l.pixel_size = 0.006
	sign_l.position = Vector3(0, 2.4, 0.1)
	sign_l.outline_size = 6
	add_child(sign_l)
	var it := Interactable.new()
	it.position = Vector3(0, 1.3, 0.4)
	it.reach = 3.2
	it.prompt = "Read the bounty board"
	add_child(it)
	it.on_interact = func(_by: Node3D, _me: Interactable) -> void: open()


func state_of(id: String) -> String:
	return String(story.get_flag("bty_" + id, "off"))


func progress(job: Dictionary) -> int:
	var base := int(story.get_flag("bty_%s_base" % String(job["id"]), 0))
	return maxi(0, int(story.get_flag(String(job["counter"]), 0)) - base)


func accept(id: String) -> bool:
	for j in JOBS:
		if String(j["id"]) == id and state_of(id) == "off":
			story.set_flag("bty_" + id, "active")
			story.set_flag("bty_%s_base" % id, int(story.get_flag(String(j["counter"]), 0)))
			return true
	return false


func claim(id: String) -> int:
	for j in JOBS:
		if String(j["id"]) == id and state_of(id) == "active" and progress(j) >= int(j["goal"]):
			story.set_flag("bty_" + id, "off")        # the job is posted again
			story.add("bounties_done")
			coins.add(int(j["reward"]), "Bounty complete")
			return int(j["reward"])
	return 0


func open() -> void:
	if shop == null or shop.is_open() or player.locked:
		return
	shop.open_shop("Bounty Board", _rows)


func _rows() -> Array:
	var rows: Array = []
	for j in JOBS:
		var id := String(j["id"])
		var st := state_of(id)
		var goal := int(j["goal"])
		var prog := mini(progress(j), goal)
		var d := "%s  Reward: %d coins." % [Loc.t(String(j["desc"])), int(j["reward"])]
		if st == "active":
			d += "  %d / %d" % [prog, goal]
		var row := {"name": String(j["name"]), "desc": d, "price": 0}
		if st == "off":
			row["label"] = "Accept"
			row["enabled"] = true
			row["on_press"] = accept.bind(id)
		elif prog >= goal:
			row["label"] = "Claim"
			row["enabled"] = true
			row["on_press"] = claim.bind(id)
		else:
			row["label"] = "In progress"
			row["enabled"] = false
			row["on_press"] = func() -> void: pass
		rows.append(row)
	return rows
