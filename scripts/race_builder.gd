class_name RaceBuilder
extends Node3D
## The Sand Circuit: track dressing (arch, bunting, fences, hay, grandstand with a cheering crowd,
## torches), the Race Master who gives the mission, and the whole bull-cart race: countdown,
## four carts (you + three rivals), laps, positions, weapons, damage, wrecks and the reward.

const LAPS := 3
const RIVALS := [["Red Dust", Color(0.95, 0.35, 0.3)], ["Blue Jackal", Color(0.35, 0.55, 0.95)], ["Green Mamba", Color(0.4, 0.85, 0.4)]]
const DRIVERS := ["villager_man", "blacksmith", "merchant"]

var main: Node3D
var story: Story
var hud: QuestHUD
var dlg: DialogueUI
var terrain: TerrainBuilder
var player: Player
var master: Npc

var state := "idle"            # idle, countdown, racing, ending
var laps_override := 0
var manual_step := false
var racers: Array[CartRacer] = []
var mine: CartRacer
var order: Array[CartRacer] = []
var result := ""               # "win", "lose" once the race is over
var _t := 0.0
var _end_t := 0.0
var _pair_cd := {}
var _cam_yaw := 0.0
var _layer: CanvasLayer
var _lbl_big: Label
var _lbl_top: Label
var _lbl_rivals: Label
var _bar_hp: ColorRect
var _bar_boost: ColorRect
var _ai_atk_t := {}
var _saved_dist := 6.0
var player_steer_test := 0.0


func _init(m: Node3D, s: Story, h: QuestHUD, d: DialogueUI, ter: TerrainBuilder, p: Player) -> void:
	main = m
	story = s
	hud = h
	dlg = d
	terrain = ter
	player = p
	name = "RaceBuilder"


func laps() -> int:
	return laps_override if laps_override > 0 else LAPS


func build() -> void:
	main.add_child(self)
	_decor()
	_master()
	_quest()
	_build_hud()
	player.attack_override = Callable(self, "_player_attack")


# --- track dressing -------------------------------------------------------------------------

func _gp(p: Vector2, up: float = 0.0) -> Vector3:
	return Vector3(p.x, terrain.sample_height(p.x, p.y) + up, p.y)


func _decor() -> void:
	var P := TerrainBuilder.track_length()
	var wood := PropFactory.wood()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.14, 1.1, 0.14)
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(1.0, 0.08, 0.06)
	var posts: Array[Transform3D] = []
	var rails: Array[Transform3D] = []
	var flags: Array[Transform3D] = []
	var flag_cols: Array[Color] = []
	var cols := [Color(0.9, 0.25, 0.2), Color(0.95, 0.75, 0.2), Color(0.25, 0.55, 0.9), Color(0.95, 0.95, 0.9), Color(0.3, 0.75, 0.35)]
	var step := 4.0
	var n := int(P / step)
	for side: float in [-1.0, 1.0]:
		var off: float = (TerrainBuilder.TRACK_W + 0.9) * side
		for i in n:
			var a: Vector2 = TerrainBuilder.track_point(i * step) + TerrainBuilder.track_right(i * step) * off
			var b: Vector2 = TerrainBuilder.track_point((i + 1) * step) + TerrainBuilder.track_right((i + 1) * step) * off
			if side > 0.0 and absf(a.x - TerrainBuilder.TRACK_C.x - 0.0) < 0.0:
				continue
			var ya := terrain.sample_height(a.x, a.y)
			var yb := terrain.sample_height(b.x, b.y)
			posts.append(Transform3D(Basis(), Vector3(a.x, ya + 0.5, a.y)))
			var mid := Vector3((a.x + b.x) * 0.5, (ya + yb) * 0.5, (a.y + b.y) * 0.5)
			var dir := Vector3(b.x - a.x, yb - ya, b.y - a.y)
			var len := dir.length()
			var bs := Basis.looking_at(dir.normalized(), Vector3.UP) * Basis(Vector3.UP, PI * 0.5)
			bs = bs * Basis.from_scale(Vector3(len, 1, 1))
			rails.append(Transform3D(bs, mid + Vector3(0, 0.9, 0)))
			rails.append(Transform3D(bs, mid + Vector3(0, 0.55, 0)))
			# bunting flag hanging from the top rail every second bay
			if i % 2 == 0:
				var fb := Basis.looking_at(dir.normalized(), Vector3.UP) * Basis(Vector3.UP, PI * 0.5)
				flags.append(Transform3D(fb, mid + Vector3(0, 0.78, 0)))
				flag_cols.append(cols[(i / 2 + (0 if side < 0.0 else 2)) % cols.size()])
	_multi("Posts", post_mesh, wood, posts)
	_multi("Rails", rail_mesh, wood, rails)
	var fm := PrismMesh.new()
	fm.size = Vector3(0.45, 0.4, 0.02)
	var fmat := StandardMaterial3D.new()
	fmat.vertex_color_use_as_albedo = true
	fmat.roughness = 0.9
	fmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = fm
	mm.instance_count = flags.size()
	for i in flags.size():
		var t := flags[i]
		t.basis = t.basis * Basis(Vector3.RIGHT, PI)
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, flag_cols[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Bunting"
	mi.multimesh = mm
	mi.material_override = fmat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# finish arch across the start line
	var sp := TerrainBuilder.track_point(0.0)
	var tn := TerrainBuilder.track_tangent(0.0)
	var arch := Node3D.new()
	arch.name = "FinishArch"
	add_child(arch)
	arch.position = _gp(sp)
	arch.rotation.y = atan2(-tn.x, -tn.y)
	var w := TerrainBuilder.TRACK_W + 1.6
	for sx in [-w, w]:
		PropFactory.cylinder(arch, 0.3, 0.34, 6.2, Vector3(sx, 3.1, 0), PropFactory.sandstone(), Vector3.ZERO, false, 12)
		PropFactory.box(arch, Vector3(0.9, 0.35, 0.9), Vector3(sx, 0.18, 0), PropFactory.sandstone_dark(), Vector3.ZERO, false)
	PropFactory.box(arch, Vector3(w * 2.0 + 1.0, 0.9, 0.7), Vector3(0, 6.3, 0), PropFactory.sandstone(), Vector3.ZERO, false)
	var sign := Label3D.new()
	sign.text = "SAND CIRCUIT"
	sign.font_size = 120
	sign.pixel_size = 0.012
	sign.outline_size = 18
	sign.modulate = Color(1.0, 0.9, 0.55)
	sign.outline_modulate = Color(0.2, 0.08, 0.04)
	sign.position = Vector3(0, 6.35, 0.4)
	sign.double_sided = true
	arch.add_child(sign)
	var sign2 := sign.duplicate() as Label3D
	sign2.position = Vector3(0, 6.35, -0.4)
	sign2.rotation.y = PI
	arch.add_child(sign2)
	# chequered line painted on the track
	var line := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(TerrainBuilder.TRACK_W * 2.0, 0.9)
	qm.orientation = PlaneMesh.FACE_Y
	line.mesh = qm
	line.material_override = _chequer()
	line.position = Vector3(0, 0.06, 0)
	arch.add_child(line)
	arch.global_position = _gp(sp)
	line.global_position.y = terrain.sample_height(sp.x, sp.y) + 0.07
	_stands()
	_hay_and_torches()


func _chequer() -> StandardMaterial3D:
	var img := Image.create(16, 2, false, Image.FORMAT_RGB8)
	for x in 16:
		for y in 2:
			img.set_pixel(x, y, Color.WHITE if (x + y) % 2 == 0 else Color(0.05, 0.05, 0.05))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	return m


func _multi(nm: String, mesh: Mesh, mat: Material, xf: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	mi.material_override = mat
	add_child(mi)


## Grandstand along the start straight (outside edge) with a crowd of colourful spectators.
func _stands() -> void:
	var tn := TerrainBuilder.track_tangent(30.0)
	var base := TerrainBuilder.track_point(30.0) + TerrainBuilder.track_right(30.0) * (TerrainBuilder.TRACK_W + 5.5)
	var g := Node3D.new()
	g.name = "Grandstand"
	add_child(g)
	g.position = _gp(base)
	g.rotation.y = atan2(-tn.x, -tn.y)
	# local +X = travel's right = away from the track
	var wood := PropFactory.wood(Color(0.42, 0.3, 0.2))
	var cloth := PropFactory.material(Color(0.85, 0.3, 0.2), 0.9)
	var crowd_xf: Array[Transform3D] = []
	var crowd_col: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var skin := [Color(0.55, 0.38, 0.27), Color(0.45, 0.3, 0.2), Color(0.65, 0.47, 0.34)]
	for r in 4:
		PropFactory.box(g, Vector3(2.2, 0.35 + r * 0.55, 26.0), Vector3(r * 2.2 + 1.1, (0.35 + r * 0.55) * 0.5, 0), wood, Vector3.ZERO, false)
		for k in 14:
			var z := -12.0 + k * 1.85 + rng.randf_range(-0.2, 0.2)
			var h := 0.35 + r * 0.55
			crowd_xf.append(Transform3D(Basis(), Vector3(r * 2.2 + 1.2, h + 0.55, z)))
			crowd_col.append([Color(0.9, 0.3, 0.25), Color(0.95, 0.8, 0.3), Color(0.3, 0.6, 0.9), Color(0.95, 0.95, 0.9), Color(0.4, 0.75, 0.4), Color(0.7, 0.35, 0.8)][rng.randi() % 6])
	var cm := CapsuleMesh.new()
	cm.radius = 0.28
	cm.height = 1.0
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cm
	mm.instance_count = crowd_xf.size()
	for i in crowd_xf.size():
		mm.set_instance_transform(i, crowd_xf[i])
		mm.set_instance_color(i, crowd_col[i])
	var cmi := MultiMeshInstance3D.new()
	cmi.name = "Crowd"
	cmi.multimesh = mm
	cmi.material_override = mat
	g.add_child(cmi)
	var hm := SphereMesh.new()
	hm.radius = 0.2
	hm.height = 0.4
	var hmm := MultiMesh.new()
	hmm.transform_format = MultiMesh.TRANSFORM_3D
	hmm.mesh = hm
	hmm.instance_count = crowd_xf.size()
	for i in crowd_xf.size():
		hmm.set_instance_transform(i, Transform3D(Basis(), crowd_xf[i].origin + Vector3(0, 0.72, 0)))
	var hmi := MultiMeshInstance3D.new()
	hmi.name = "CrowdHeads"
	hmi.multimesh = hmm
	hmi.material_override = PropFactory.skin(skin[0])
	g.add_child(hmi)
	# roof
	for z in [-12.5, 12.5]:
		PropFactory.cylinder(g, 0.1, 0.1, 5.6, Vector3(9.0, 2.8, z), wood, Vector3.ZERO, false, 8, 0, false)
	PropFactory.box(g, Vector3(5.0, 0.12, 27.0), Vector3(6.6, 5.6, 0), cloth, Vector3(0, 0, -8), false, false)


func _hay_and_torches() -> void:
	var P := TerrainBuilder.track_length()
	var hay := PropFactory.material(Color(0.78, 0.65, 0.3), 1.0)
	for k in 10:
		var s := P * (k + 0.5) / 10.0
		var p := TerrainBuilder.track_point(s) + TerrainBuilder.track_right(s) * (TerrainBuilder.TRACK_W + 2.2)
		if k % 3 == 0:
			PropFactory.cylinder(self, 0.55, 0.55, 0.9, _gp(p, 0.45), hay, Vector3(90, 0, k * 20.0), false, 10)
			PropFactory.cylinder(self, 0.55, 0.55, 0.9, _gp(p + Vector2(1.2, 0.3), 0.45), hay, Vector3(90, 0, k * 35.0), false, 10)
	var lit := 0
	for k in 6:
		var s := P * (k + 0.2) / 6.0
		var p := TerrainBuilder.track_point(s) - TerrainBuilder.track_right(s) * (TerrainBuilder.TRACK_W + 1.8)
		var tp := Node3D.new()
		add_child(tp)
		tp.position = _gp(p)
		PropFactory.cylinder(tp, 0.06, 0.09, 2.2, Vector3(0, 1.1, 0), PropFactory.wood(), Vector3.ZERO, false, 8)
		PropFactory.cylinder(tp, 0.2, 0.1, 0.25, Vector3(0, 2.3, 0), PropFactory.bronze(), Vector3.ZERO, false, 10)
		var fl := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.17
		sm.height = 0.4
		fl.mesh = sm
		fl.material_override = PropFactory.glow_lamp()
		fl.position = Vector3(0, 2.55, 0)
		tp.add_child(fl)
		if lit < 3 and k % 2 == 0:
			lit += 1
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.7, 0.35)
			l.omni_range = 10.0
			l.light_energy = 1.2
			l.position = Vector3(0, 2.7, 0)
			tp.add_child(l)


# --- race master, quest ---------------------------------------------------------------------

func _master() -> void:
	var sp := TerrainBuilder.track_point(0.0) - TerrainBuilder.track_right(0.0) * (TerrainBuilder.TRACK_W + 3.0) + TerrainBuilder.track_tangent(0.0) * -3.0
	master = Npc.new().setup(NpcBuilder.PRESETS["blacksmith"], "idle", "Race Master")
	master.player = player
	main.add_child(master)
	master.global_position = _gp(sp, 0.05)
	master.rotation.y = atan2(TerrainBuilder.track_right(0.0).x, TerrainBuilder.track_right(0.0).y)
	master.home_yaw = master.rotation.y
	story.refs["racemaster"] = master
	main.npcs.append(master)
	var it := Interactable.new()
	it.position = Vector3(0, 1.1, 0)
	it.prompt = "Talk to the Race Master"
	it.reach = 3.4
	master.add_child(it)
	it.on_interact = func(_by: Node3D, _me: Interactable) -> void:
		dlg.open(_dialogue(), master, "deep", Callable(self, "_after_dialogue"))


func _dialogue() -> Dictionary:
	var w := "Race Master Bhim"
	if state != "idle":
		return {}
	if story.get_flag("race_won"):
		return {"start": "a", "nodes": {"a": {"who": w, "text": "Champion! The crowd still sings your name. Want to race again just for the thrill? The bulls are rested.",
			"choices": [{"t": "One more race!", "go": "", "set": {"race_go": true}}, {"t": "Not now.", "go": ""}]}}}
	return {"start": "a", "nodes": {
		"a": {"who": w, "text": "Welcome to the Sand Circuit! Three laps, four carts, no rules except this: the cart that crosses the line first wins.",
			"choices": [{"t": "Sounds easy enough.", "go": "b"}, {"t": "Not now.", "go": ""}]},
		"b": {"who": w, "text": "Easy? The dunes have made humps in the track, and the other drivers carry iron blades on their carts. Steer with the stick, pull back to brake, tap JUMP for a burst of speed, and HIT to swing your blades at anyone beside you.",
			"choices": [{"t": "Let me at them.", "go": "c", "set": {"race_ask": true}}]},
		"c": {"who": w, "text": "That is the spirit! Your cart is waiting at the line. Win, and the prize purse is yours.",
			"choices": [{"t": "Start the race!", "go": "", "set": {"race_go": true}}, {"t": "Give me a moment.", "go": ""}]}}}


func _after_dialogue() -> void:
	if story.get_flag("race_go"):
		story.flags.erase("race_go")
		start_race()


func _quest() -> void:
	story.quests.append({
		"id": "race", "title": "Side: The Sand Circuit",
		"blurb": "Race Master Bhim runs a bull-cart race on the Sand Circuit in the east. Win three laps against three armed rivals.",
		"show": func() -> bool: return story.get_flag("met_chief"),
		"objs": [
			{"text": func() -> String: return "Speak to the Race Master at the Sand Circuit",
			 "done": func() -> bool: return story.get_flag("race_ask"), "target": func() -> Vector3: return master.global_position if master != null else Vector3.ZERO},
			{"text": func() -> String: return "Win the bull cart race (%d laps)" % LAPS,
			 "done": func() -> bool: return story.get_flag("race_won"), "target": func() -> Vector3: return master.global_position if master != null else Vector3.ZERO},
		],
	})
	story.changed.emit()


# --- HUD ------------------------------------------------------------------------------------

func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 12
	_layer.visible = false
	add_child(_layer)
	_lbl_big = _label(96, Color(1, 0.9, 0.5))
	_lbl_big.anchor_left = 0.0
	_lbl_big.anchor_right = 1.0
	_lbl_big.position = Vector2(0, 170)
	_lbl_big.size = Vector2(1280, 130)
	_lbl_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_top = _label(34, Color.WHITE)
	_lbl_top.anchor_left = 0.0
	_lbl_top.anchor_right = 1.0
	_lbl_top.position = Vector2(0, 74)
	_lbl_top.size = Vector2(1280, 50)
	_lbl_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_rivals = _label(24, Color.WHITE)
	_lbl_rivals.anchor_left = 1.0
	_lbl_rivals.anchor_right = 1.0
	_lbl_rivals.position = Vector2(-300, 340)
	_lbl_rivals.size = Vector2(280, 140)
	_lbl_rivals.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.55)
	back.position = Vector2(24, 560)
	back.size = Vector2(380, 62)
	_layer.add_child(back)
	var t1 := _label(20, Color.WHITE)
	t1.text = "CART"
	t1.position = Vector2(34, 560)
	_layer.add_child(t1)
	_bar_hp = ColorRect.new()
	_bar_hp.color = Color(0.3, 0.9, 0.3)
	_bar_hp.position = Vector2(100, 568)
	_bar_hp.size = Vector2(290, 18)
	_layer.add_child(_bar_hp)
	var t2 := _label(20, Color(1, 0.85, 0.4))
	t2.text = "BOOST"
	t2.position = Vector2(34, 590)
	_layer.add_child(t2)
	_bar_boost = ColorRect.new()
	_bar_boost.color = Color(1.0, 0.75, 0.2)
	_bar_boost.position = Vector2(100, 598)
	_bar_boost.size = Vector2(290, 14)
	_layer.add_child(_bar_boost)


func _label(sz: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 8)
	_layer.add_child(l)
	return l


# --- race flow ------------------------------------------------------------------------------

func start_race() -> void:
	if state != "idle":
		return
	result = ""
	order.clear()
	racers.clear()
	_pair_cd.clear()
	_ai_atk_t.clear()
	player.locked = true
	player.move_input = Vector2.ZERO
	player.jump_requested = false
	player._model.visible = false
	_saved_dist = player._target_distance
	player.set_distance(12.5)
	mine = _spawn("You", Color(1.0, 0.82, 0.25), NpcBuilder.PRESETS["villager_man"], true)
	mine.max_hp = 150.0
	mine.hp = 150.0
	var grid := [[0.0, 0.0], [6.0, 1.9], [3.0, -1.9], [8.0, 0.2]]
	var slots := [[0.0, -2.8], [7.0, 2.8], [14.0, -2.8], [21.0, 2.8]]
	mine.place(slots[0][0] + 4.0, slots[0][1])
	for i in 3:
		var r := _spawn(RIVALS[i][0], RIVALS[i][1], NpcBuilder.PRESETS[DRIVERS[i]], false)
		r.max_speed = [14.3, 13.9, 14.6][i]
		r.blade_damage = 9.0
		r.place(slots[i + 1][0] + 4.0, slots[i + 1][1])
	var _g := grid
	_cam_yaw = _yaw_of(mine)
	player.set_look(_cam_yaw, -0.3)
	_layer.visible = true
	hud._tracker.visible = false
	state = "countdown"
	_t = 3.99
	hud.banner("Sand Circuit race", "reveal")
	Sfx.ui("raid_horn", -4.0)


func _spawn(label: String, col: Color, preset: Dictionary, is_p: bool) -> CartRacer:
	var r := CartRacer.new().setup(terrain, label, col, preset, is_p)
	main.add_child(r)
	racers.append(r)
	r.destroyed.connect(_on_destroyed)
	return r


func _yaw_of(r: CartRacer) -> float:
	var t := TerrainBuilder.track_tangent(r.s)
	return atan2(-t.x, -t.y)


func _on_destroyed(r: CartRacer) -> void:
	if r == mine:
		hud.banner("Your cart is wrecked!", "enemy_down")


func _player_attack() -> void:
	if state == "racing" and mine != null:
		mine.attack(racers)


func _physics_process(delta: float) -> void:
	if manual_step or state == "idle":
		return
	step_race(minf(delta, 0.05))


func step_race(delta: float) -> void:
	match state:
		"countdown":
			_t -= delta
			for r in racers:
				r.step(delta, 0.0, false, false, false)
			_follow(delta)
			var n := int(ceil(_t))
			_lbl_big.text = "GO!" if _t <= 0.0 else str(clampi(n, 1, 3))
			_lbl_top.text = "Get ready!"
			if _t <= 0.0:
				state = "racing"
				_t = 0.0
				Sfx.ui("powerup", -3.0)
		"racing":
			_t += delta
			_race_tick(delta)
		"ending":
			_end_t -= delta
			for r in racers:
				r.step(delta, 0.0, true, true, false)
			_follow(delta)
			if _end_t <= 0.0:
				_finish()


func _race_tick(delta: float) -> void:
	if _t > 1.2:
		_lbl_big.text = ""
	var steer := clampf(player.move_input.x + _key_axis(), -1.0, 1.0)
	var brake := player.move_input.y > 0.6
	var boost := player.jump_requested or Input.is_physical_key_pressed(KEY_SPACE)
	player.jump_requested = false
	var lead := _leader_progress()
	for r in racers:
		if r == mine:
			r.step(delta, steer, brake, true, boost)
		else:
			var gap := r.progress() - mine.progress()
			var base := r.max_speed
			var rb := 1.0
			if gap < -25.0:
				rb = 1.09
			elif gap > 30.0:
				rb = 0.9
			var saved := r.max_speed
			r.max_speed = base * rb
			r.step(delta, r.ai_steer(delta, mine), false, true, r.boost_cd <= 0.0 and randf() < 0.004)
			r.max_speed = saved
			_ai_attack(r, delta)
	_collisions(delta)
	_check_finish()
	_follow(delta)
	_update_hud()
	var _l := lead
	# end conditions
	if mine.dead and _end_t <= 0.0 and state == "racing":
		result = "lose"
		state = "ending"
		_end_t = 2.5
	elif mine.finished and state == "racing":
		result = "win" if order.size() > 0 and order[0] == mine else "lose"
		state = "ending"
		_end_t = 3.0
	else:
		var alive_rivals := 0
		for r in racers:
			if r != mine and not r.dead and not r.finished:
				alive_rivals += 1
		if alive_rivals == 0 and not mine.finished and state == "racing" and order.is_empty():
			# every rival wrecked: you win by default, just finish the lap in peace
			result = "win"
			state = "ending"
			_end_t = 2.5


func _key_axis() -> float:
	var a := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		a -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		a += 1.0
	return a


func _leader_progress() -> float:
	var m := 0.0
	for r in racers:
		m = maxf(m, r.progress())
	return m


func _ai_attack(r: CartRacer, delta: float) -> void:
	_ai_atk_t[r] = float(_ai_atk_t.get(r, 0.0)) - delta
	if _ai_atk_t[r] > 0.0 or r.dead or r.atk_cd > 0.0:
		return
	for o in racers:
		if o == r or o.dead:
			continue
		if o != mine and randf() > 0.12:
			continue                     # rivals mostly go for you, not each other
		var ds := CartRacer._delta_s(o.s, r.s)
		if absf(ds) < CartRacer.BLADE_RANGE_S - 0.6 and absf(o.lat - r.lat) < CartRacer.BLADE_RANGE_L - 0.8:
			_ai_atk_t[r] = randf_range(3.0, 5.5)
			r.attack(racers)
			return


func _collisions(delta: float) -> void:
	for k in _pair_cd.keys():
		_pair_cd[k] = float(_pair_cd[k]) - delta
	for i in racers.size():
		for j in range(i + 1, racers.size()):
			var a := racers[i]
			var b := racers[j]
			if a.dead or b.dead:
				continue
			var ds := CartRacer._delta_s(a.s, b.s)
			if absf(ds) < 3.4 and absf(a.lat - b.lat) < 2.0:
				var key := a.get_instance_id() * 1000 + b.get_instance_id() % 1000
				if float(_pair_cd.get(key, 0.0)) <= 0.0:
					_pair_cd[key] = 0.6
					a.bump(b, absf(a.speed - b.speed) + 2.0)


func _check_finish() -> void:
	for r in racers:
		if not r.finished and not r.dead and r.lap >= laps():
			r.finished = true
			r.finish_time = _t
			order.append(r)
			if r == mine:
				hud.banner("Finished!", "chime")


func _ranked() -> Array[CartRacer]:
	var a: Array[CartRacer] = []
	a.append_array(order)
	var rest: Array[CartRacer] = []
	for r in racers:
		if not order.has(r):
			rest.append(r)
	rest.sort_custom(func(x: CartRacer, y: CartRacer) -> bool:
		if x.dead != y.dead:
			return not x.dead
		return x.progress() > y.progress())
	a.append_array(rest)
	return a


func _update_hud() -> void:
	var rk := _ranked()
	var pos := rk.find(mine) + 1
	_lbl_top.text = "Position %d/%d     Lap %d/%d" % [pos, rk.size(), mini(mine.lap + 1, laps()), laps()]
	var lines := ""
	for r in rk:
		lines += "%s  %s\n" % [r.racer_name, ("WRECKED" if r.dead else "%d%%" % int(r.hp / r.max_hp * 100.0))]
	_lbl_rivals.text = lines
	_bar_hp.size.x = 290.0 * clampf(mine.hp / mine.max_hp, 0.0, 1.0)
	_bar_hp.color = Color(0.9, 0.2, 0.15).lerp(Color(0.3, 0.9, 0.3), clampf(mine.hp / mine.max_hp, 0.0, 1.0))
	_bar_boost.size.x = 290.0 * (1.0 - clampf(mine.boost_cd / 8.0, 0.0, 1.0))


func _yaw_follow_target() -> float:
	var h := Vector2(-mine._basis.z.x, -mine._basis.z.z)
	if h.length() < 0.01:
		return _cam_yaw
	return atan2(-h.x, -h.y)


func _follow(delta: float) -> void:
	if mine == null:
		return
	_cam_yaw = lerp_angle(_cam_yaw, _yaw_follow_target(), 1.0 - exp(-3.0 * delta))
	player.global_position = mine.global_position + Vector3(0, 0.6, 0)
	player.velocity = Vector3.ZERO
	player.set_look(_cam_yaw, -0.36)


func _finish() -> void:
	var won := result == "win"
	state = "idle"
	_layer.visible = false
	hud._tracker.visible = true
	_lbl_big.text = ""
	for r in racers:
		r.cleanup()
	racers.clear()
	if won:
		story.add("coins", 150)
		story.set_flag("race_won", true)
		player.hp = player.max_hp
		player.hp_changed.emit(player.hp, player.max_hp)
		hud.banner("Race won! +150 coins", "seal_found")
	else:
		hud.banner("Race lost. Speak to the Race Master to try again.", "enemy_down")
	var tn := TerrainBuilder.track_tangent(0.0)
	var back := TerrainBuilder.track_point(0.0) - TerrainBuilder.track_right(0.0) * (TerrainBuilder.TRACK_W + 5.0)
	player.global_position = _gp(back, 0.6)
	player.velocity = Vector3.ZERO
	player._model.visible = true
	player.locked = false
	player.set_distance(_saved_dist)
	player.set_look(atan2(-tn.x, -tn.y), -0.2)
	mine = null
	story.changed.emit()
