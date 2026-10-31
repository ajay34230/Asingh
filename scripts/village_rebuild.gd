class_name VillageRebuild
extends Node3D
## S5: pay coins at the rebuilding board in the bazaar to restore the village in three stages.
##   1. Street lamps  (100 coins): four new lamp posts that really light the night, +15 max health.
##   2. Festival flags (250 coins): a ring of banner poles, +15 max health.
##   3. Sun Gate      (500 coins): a stone gateway, +15 max health.
## Stages are story flags (rebuild_1..3) so they persist; structures reappear when a save is loaded.

const COSTS := [100, 250, 500]

var main: Node3D
var terrain: TerrainBuilder
var story: Story
var player: Player
var hud: Node
var night_life: NightLife
var board: Interactable
var built := [false, false, false]
const C := Vector2(22.0, -42.0)


func build() -> void:
	var board_node := Node3D.new()
	board_node.name = "RebuildBoard"
	add_child(board_node)
	var bp := Vector3(C.x + 11.0, 0.0, C.y + 11.0)
	bp.y = terrain.sample_height(bp.x, bp.z)
	board_node.global_position = bp
	var wood := PropFactory.wood()
	PropFactory.box(board_node, Vector3(0.14, 2.2, 0.14), Vector3(-0.8, 1.1, 0), wood, Vector3.ZERO, false)
	PropFactory.box(board_node, Vector3(0.14, 2.2, 0.14), Vector3(0.8, 1.1, 0), wood, Vector3.ZERO, false)
	PropFactory.box(board_node, Vector3(1.9, 1.0, 0.1), Vector3(0, 1.7, 0), PropFactory.wood(Color(0.5, 0.36, 0.2)), Vector3.ZERO, false)
	board = Interactable.new()
	board.position = Vector3(0, 1.3, 0)
	board.reach = 3.2
	board_node.add_child(board)
	board.on_interact = func(_by: Node3D, _me: Interactable) -> void: pay_next()
	for i in 3:
		if story.get_flag("rebuild_%d" % (i + 1), false):
			_make(i)
	_refresh()


func stage() -> int:
	var n := 0
	for b in built:
		if b:
			n += 1
	return n


func _refresh() -> void:
	var s := stage()
	if s >= 3:
		board.prompt = "Village restored"
	else:
		board.prompt = "Rebuild the village (%d coins)" % COSTS[s]


func pay_next() -> bool:
	var s := stage()
	if s >= 3:
		return false
	var coins := int(story.get_flag("coins", 0))
	if coins < COSTS[s]:
		hud.banner(Loc.t("Not enough coins to rebuild yet."), "")
		return false
	story.set_flag("coins", coins - COSTS[s])
	story.set_flag("rebuild_%d" % (s + 1), true)
	_make(s)
	_refresh()
	hud.banner(Loc.t(["The new lamps are lit!", "Festival flags fly again!", "The Sun Gate stands once more!"][s]), "")
	return true


func _make(i: int) -> void:
	if built[i]:
		return
	built[i] = true
	player.max_hp += 15.0
	player.hp = minf(player.max_hp, player.hp + 15.0)
	player.hp_changed.emit(player.hp, player.max_hp)
	match i:
		0:
			_lamps()
		1:
			_flags()
		2:
			_gate()


func _gp(x: float, z: float) -> Vector3:
	return Vector3(x, terrain.sample_height(x, z), z)


func _lamps() -> void:
	var iron := PropFactory.iron()
	var glow := PropFactory.glow_lamp()
	for k in 4:
		var a := (k + 0.5) * TAU / 4.0 + 0.4
		var p := _gp(C.x + cos(a) * 20.0, C.y + sin(a) * 20.0)
		var post := Node3D.new()
		add_child(post)
		post.global_position = p
		PropFactory.cylinder(post, 0.07, 0.1, 3.6, Vector3(0, 1.8, 0), iron, Vector3.ZERO, false, 8, 0, false)
		PropFactory.sphere(post, 0.2, Vector3(0, 3.7, 0), glow)
		if night_life != null:
			night_life.points.append(p + Vector3(0, 3.7, 0))


func _flags() -> void:
	var cols := [Color(0.9, 0.25, 0.2), Color(0.95, 0.7, 0.15), Color(0.2, 0.55, 0.85), Color(0.3, 0.7, 0.35)]
	for k in 8:
		var a := k * TAU / 8.0
		var p := _gp(C.x + cos(a) * 24.0, C.y + sin(a) * 24.0)
		var pole := Node3D.new()
		add_child(pole)
		pole.global_position = p
		PropFactory.cylinder(pole, 0.05, 0.07, 4.0, Vector3(0, 2.0, 0), PropFactory.wood(), Vector3.ZERO, false, 6, 0, false)
		PropFactory.box(pole, Vector3(0.9, 0.55, 0.03), Vector3(0.45, 3.6, 0), PropFactory.material(cols[k % cols.size()], 0.9), Vector3.ZERO, false, false)


func _gate() -> void:
	var stone := PropFactory.stone(Color(0.66, 0.58, 0.46))
	var p := _gp(C.x, C.y + 30.0)
	var g := Node3D.new()
	g.name = "SunGate"
	add_child(g)
	g.global_position = p
	PropFactory.box(g, Vector3(1.2, 6.0, 1.2), Vector3(-4.0, 3.0, 0), stone, Vector3.ZERO, false)
	PropFactory.box(g, Vector3(1.2, 6.0, 1.2), Vector3(4.0, 3.0, 0), stone, Vector3.ZERO, false)
	PropFactory.box(g, Vector3(10.0, 1.1, 1.4), Vector3(0, 6.4, 0), stone, Vector3.ZERO, false)
	PropFactory.sphere(g, 0.8, Vector3(0, 7.5, 0), PropFactory.glow_lamp())
