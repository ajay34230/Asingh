class_name CoinSystem
extends Node3D
## Coins: gold coins to collect around the valley, the coin counter on screen, mission rewards and a small
## API (`add`, `spend`, `balance`) every earning or spending system uses. The balance is the story flag
## "coins", so it saves with the game. Collected coins are remembered as flags "coin_<i>".

const COUNT := 64
const MISSION_REWARD := 50

var main: Node3D
var terrain: TerrainBuilder
var story: Story
var player: Player
var hud: Node
var coins: Array = []            # {node, value, id}
var _label: Label
var _icon: Panel
var _shown := 0
var _pop: Label
var _pop_t := 0.0
var _scan := 0.0
var _spin := 0.0
var _last_balance := 0


func balance() -> int:
	return int(story.get_flag("coins", 0))


func add(n: int, why: String = "") -> void:
	if n <= 0:
		return
	story.set_flag("coins", balance() + n)
	if why != "" and hud != null:
		hud.banner("+%d coins  %s" % [n, Loc.t(why)], "")


func spend(n: int) -> bool:
	if n <= 0 or balance() < n:
		return false
	story.set_flag("coins", balance() - n)
	return true


func build() -> void:
	name = "CoinSystem"
	_build_hud()
	_place_coins()
	story.mission_event.connect(_on_mission)
	_last_balance = balance()


## After a save replaced the flags: drop the coins already collected.
func reload() -> void:
	for i in range(coins.size() - 1, -1, -1):
		var cd: Dictionary = coins[i]
		if story.get_flag("coin_%d" % int(cd["id"]), false):
			(cd["node"] as Node3D).queue_free()
			coins.remove_at(i)
	_last_balance = balance()
	_refresh_label()


func _on_mission(kind: String, _text: String) -> void:
	if kind == "done":
		add(MISSION_REWARD, "Mission reward")


# --- HUD ------------------------------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var box := HBoxContainer.new()
	box.position = Vector2(22, 14)
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)
	_icon = Panel.new()
	_icon.custom_minimum_size = Vector2(30, 30)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.8, 0.2)
	sb.set_corner_radius_all(15)
	sb.border_color = Color(0.7, 0.45, 0.05)
	sb.set_border_width_all(3)
	_icon.add_theme_stylebox_override("panel", sb)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_icon)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
	_label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0))
	_label.add_theme_constant_override("outline_size", 8)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_label)
	_pop = Label.new()
	_pop.position = Vector2(70, 48)
	_pop.add_theme_font_size_override("font_size", 24)
	_pop.add_theme_constant_override("outline_size", 6)
	_pop.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_pop)
	_refresh_label()


func _refresh_label() -> void:
	_label.text = str(balance())


# --- world coins ----------------------------------------------------------------------------------

func _place_coins() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var spots: Array[Vector2] = []
	# a trail from the farm door towards the bazaar, then clusters at the places worth visiting
	var farm := TerrainBuilder.FARM_C
	var town := TerrainBuilder.TOWN_C
	for i in 12:
		var f := float(i + 1) / 13.0
		spots.append(farm.lerp(town, f) + Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 5.0)))
	for c in [TerrainBuilder.POND_C, TerrainBuilder.TEMPLE_C, TerrainBuilder.FOREST_C, town, farm]:
		for i in 5:
			var a := rng.randf() * TAU
			var r := rng.randf_range(8.0, 22.0)
			spots.append((c as Vector2) + Vector2(cos(a), sin(a)) * r)
	while spots.size() < COUNT:
		spots.append(Vector2(rng.randf_range(-170.0, 170.0), rng.randf_range(-150.0, 175.0)))
	var gold := PropFactory.material(Color(1.0, 0.78, 0.15), 0.35, 0.8)
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.7, 0.1)
	gold.emission_energy_multiplier = 0.5
	for i in spots.size():
		var p := spots[i]
		if story.get_flag("coin_%d" % i, false):
			continue
		var y := terrain.sample_height(p.x, p.y)
		if y < 0.2:
			continue
		var value := 5
		var big := i % 11 == 4
		if big:
			value = 25
		elif i % 3 == 0:
			value = 2
		var n := Node3D.new()
		n.position = Vector3(p.x, y + 0.9, p.y)
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.28 * (1.6 if big else 1.0)
		cm.bottom_radius = cm.top_radius
		cm.height = 0.06
		cm.radial_segments = 14
		disc.mesh = cm
		disc.material_override = gold
		disc.rotation.x = PI * 0.5
		n.add_child(disc)
		add_child(n)
		coins.append({"node": n, "value": value, "id": i})


func _process(delta: float) -> void:
	if player == null:
		return
	_spin += delta * 2.4
	_pop_t = maxf(0.0, _pop_t - delta)
	_pop.modulate.a = clampf(_pop_t / 0.4, 0.0, 1.0)
	var bal := balance()
	if bal != _last_balance:
		var diff := bal - _last_balance
		_pop.text = ("+%d" % diff) if diff > 0 else str(diff)
		_pop.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5) if diff > 0 else Color(1.0, 0.55, 0.5))
		_pop_t = 1.6
		_last_balance = bal
		_refresh_label()
	var pp := player.global_position
	for c in coins:
		var n := c["node"] as Node3D
		n.rotation.y = _spin + float(c["id"])
	_scan -= delta
	if _scan > 0.0:
		return
	_scan = 0.1
	for i in range(coins.size() - 1, -1, -1):
		var c: Dictionary = coins[i]
		var n2 := c["node"] as Node3D
		if n2.global_position.distance_to(pp + Vector3(0, 0.9, 0)) < 1.5:
			collect(i)


func collect(i: int) -> void:
	var c: Dictionary = coins[i]
	var n := c["node"] as Node3D
	story.set_flag("coin_%d" % int(c["id"]), true)
	add(int(c["value"]))
	Sfx.ui("powerup", -10.0)
	HitFx.burst(self, n.global_position, false, Color(1.0, 0.85, 0.3))
	n.queue_free()
	coins.remove_at(i)
	story.add("coins_found")
