class_name StoryBuilder
extends RefCounted
## Builds the playable story layer: Arin's field office, rivets, the rail crate, the dig site,
## the Sun Gate, "Talk" interactions on every NPC and the intro / gate cinematics.

var main: Node3D
var story: Story
var hud: QuestHUD
var dlg: DialogueUI
var cin: Cinematic
var player: Player
var terrain: TerrainBuilder
var office: Node3D
var _rivet_nodes: Array = []
var _seals_seen := 0
var _act2_ready := false


func _init(m: Node3D, s: Story, h: QuestHUD, d: DialogueUI, c: Cinematic) -> void:
	main = m
	story = s
	hud = h
	dlg = d
	cin = c
	player = m.player
	terrain = m.terrain


func _it(parent: Node3D, pos: Vector3, prompt: String, reach: float, fn: Callable) -> Interactable:
	var it := Interactable.new()
	it.position = pos
	it.prompt = prompt
	it.reach = reach
	it.on_interact = fn
	parent.add_child(it)
	return it


func _gp(x: float, z: float, up: float = 0.0) -> Vector3:
	return Vector3(x, terrain.sample_height(x, z) + up, z)


func build() -> void:
	var hs: Dictionary = main.houses.houses[5]
	office = hs["node"]
	_furnish_office(office)
	_talk_to_everyone()
	_rivets()
	_crate()
	_dig_site()
	_gate()
	story.refs["player"] = player
	story.changed.connect(_on_story_changed)
	story.refresh()


# --- Arin's office ----------------------------------------------------------------------

func _parchment() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for y in 256:
		for x in 256:
			var n := rng.randf() * 0.05
			var edge := minf(minf(x, 255 - x), minf(y, 255 - y)) / 255.0
			var c := Color(0.82 - n - (0.2 - minf(edge, 0.2)), 0.7 - n - (0.2 - minf(edge, 0.2)) * 0.8, 0.46 - n - (0.2 - minf(edge, 0.2)) * 0.6)
			img.set_pixel(x, y, c)
	var ink := Color(0.25, 0.15, 0.08)
	for k in 12:       # contour lines
		var r := 22.0 + k * 9.0
		for a in 360:
			var ang := deg_to_rad(a)
			var px := int(128 + cos(ang) * r * 1.2 + sin(ang * 3.0 + k) * 5.0)
			var py := int(150 + sin(ang) * r * 0.7)
			if px > 6 and px < 249 and py > 6 and py < 249 and k % 2 == 0:
				img.set_pixel(px, py, ink)
	for t in 60:       # dotted path to the gate
		var px := 40 + t * 3
		var py := int(210 - t * 2.4 + sin(t * 0.5) * 6.0)
		img.set_pixel(px, py, Color(0.5, 0.1, 0.08))
		img.set_pixel(px + 1, py, Color(0.5, 0.1, 0.08))
	for d in 11:       # red X at the gate
		img.set_pixel(190 + d, 55 + d, Color(0.7, 0.05, 0.05))
		img.set_pixel(200 - d, 55 + d, Color(0.7, 0.05, 0.05))
		img.set_pixel(191 + d, 55 + d, Color(0.7, 0.05, 0.05))
		img.set_pixel(201 - d, 55 + d, Color(0.7, 0.05, 0.05))
	return ImageTexture.create_from_image(img)


func _furnish_office(h: Node3D) -> void:
	var fy := HouseBuilder.FLOOR_Y
	var wood := PropFactory.wood()
	var dark := PropFactory.wood(Color(0.24, 0.16, 0.10))
	var paper := PropFactory.material(Color(0.85, 0.8, 0.62), 0.9)
	# desk with chair, back wall
	PropFactory.box(h, Vector3(2.2, 0.1, 0.9), Vector3(-2.3, fy + 0.8, -2.5), dark)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			PropFactory.box(h, Vector3(0.1, 0.8, 0.1), Vector3(-2.3 + sx * 1.0, fy + 0.4, -2.5 + sz * 0.38), dark)
	PropFactory.box(h, Vector3(0.5, 0.06, 0.5), Vector3(-2.3, fy + 0.5, -1.7), wood)
	PropFactory.box(h, Vector3(0.5, 0.6, 0.06), Vector3(-2.3, fy + 0.8, -1.45), wood)
	PropFactory.box(h, Vector3(0.45, 0.07, 0.32), Vector3(-2.7, fy + 0.89, -2.5), PropFactory.cloth(Color(0.45, 0.12, 0.1)), Vector3(0, 12, 0), false)   # journal
	PropFactory.box(h, Vector3(0.4, 0.01, 0.3), Vector3(-1.9, fy + 0.86, -2.4), paper, Vector3(0, -8, 0), false)
	PropsExtra.oil_lamp(h, Vector3(-1.6, fy + 0.85, -2.7), true)
	# map table
	PropFactory.box(h, Vector3(2.4, 0.12, 1.5), Vector3(0.8, fy + 0.85, -0.6), wood)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			PropFactory.box(h, Vector3(0.12, 0.85, 0.12), Vector3(0.8 + sx * 1.05, fy + 0.42, -0.6 + sz * 0.6), dark)
	var mp := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.1, 1.25)
	mp.mesh = pm
	var mm := StandardMaterial3D.new()
	mm.albedo_texture = _parchment()
	mm.roughness = 0.95
	mp.material_override = mm
	mp.position = Vector3(0.8, fy + 0.915, -0.6)
	h.add_child(mp)
	PropsExtra.oil_lamp(h, Vector3(1.6, fy + 0.91, -0.9), true)
	# shelves, crates, cot, rope and a big sun-disc rubbing on the wall
	for k in 3:
		PropFactory.box(h, Vector3(0.35, 0.05, 2.2), Vector3(-3.7, fy + 0.7 + k * 0.7, 0.2), wood)
		PropFactory.box(h, Vector3(0.25, 0.3, 0.3), Vector3(-3.7, fy + 0.88 + k * 0.7, 0.9 - k * 0.5), paper, Vector3.ZERO, false)
	PropFactory.box(h, Vector3(0.9, 0.35, 2.0), Vector3(3.3, fy + 0.3, -2.2), dark)
	PropFactory.box(h, Vector3(0.85, 0.12, 1.9), Vector3(3.3, fy + 0.55, -2.2), PropFactory.cloth(Color(0.55, 0.4, 0.25)), Vector3.ZERO, false)
	PropsExtra.crate_stack(h, Vector3(3.0, fy, 1.4), 20.0, RandomNumberGenerator.new())
	PropsExtra.rope_coil(h, Vector3(-3.2, fy, 2.2), 1.0)
	PropFactory.cylinder(h, 0.9, 0.9, 0.05, Vector3(0.0, fy + 2.1, -3.2), PropFactory.cloth(Color(0.78, 0.55, 0.2)), Vector3(90, 0, 0), false, 24)
	story.refs["desk"] = h.to_global(Vector3(-2.3, fy + 1.0, -2.5))
	story.refs["map"] = h.to_global(Vector3(0.8, fy + 1.0, -0.6))
	_it(h, Vector3(-2.3, fy + 1.0, -2.1), "Search Arin's desk", 2.6, func(_by: Node3D, _me: Interactable) -> void:
		Sfx.ui("page_turn", -4.0)
		dlg.open(story.dialogue_for("desk"), null, "man"))
	_it(h, Vector3(0.8, fy + 1.0, 0.0), "Study the map", 2.6, func(_by: Node3D, _me: Interactable) -> void:
		Sfx.ui("page_turn", -4.0)
		dlg.open(story.dialogue_for("map"), null, "man"))


# --- NPC talk ------------------------------------------------------------------------------

func _talk_to_everyone() -> void:
	for n in main.npcs:
		var npc: Npc = n
		story.refs[npc.name] = npc
		var it := _it(npc, Vector3(0, 1.1, 0), "Talk", 3.3, Callable())
		it.on_interact = func(_by: Node3D, _me: Interactable) -> void:
			var d := story.dialogue_for(npc.name)
			if d.is_empty():
				player.say("They nod politely.")
				return
			dlg.open(d, npc, npc.voice)
		it.prompt = "Talk to " + npc.name


# --- rivets (Hammer-Seal) ------------------------------------------------------------------

func _rivets() -> void:
	var smith: Node3D = story.refs.get("Blacksmith")
	var c := smith.global_position if smith != null else _gp(-80, 10)
	var offs := [Vector2(7.0, 5.0), Vector2(-6.0, 8.5), Vector2(3.0, -9.0)]
	var rivets: Array = []
	for o in offs:
		var pos := _gp(c.x + o.x, c.z + o.y, 0.12)
		var n := Node3D.new()
		n.position = pos
		main.add_child(n)
		var m := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.05
		cy.bottom_radius = 0.12
		cy.height = 0.16
		m.mesh = cy
		m.material_override = PropFactory.glow_bronze()
		n.add_child(m)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.3)
		l.omni_range = 3.0
		l.light_energy = 0.6
		l.position.y = 0.3
		n.add_child(l)
		var it := _it(n, Vector3(0, 0.3, 0), "Pick up rivet", 2.2, Callable())
		it.on_interact = func(_by: Node3D, me: Interactable) -> void:
			Sfx.ui("pickup", -3.0)
			story.add("rivets", 1)
			rivets.erase(n)
			story.refs["rivets"] = rivets
			me.enabled = false
			n.queue_free()
			player.say("A bronze rivet. (%d/3)" % int(story.get_flag("rivets", 0)))
			story.changed.emit()
		rivets.append(n)
	story.refs["rivets"] = rivets


# --- seals ---------------------------------------------------------------------------------

func _found_seal(flag: String, title: String) -> void:
	story.set_flag(flag, true)


func _crate() -> void:
	var base: Vector3 = main.railway.boxcar_door_world + Vector3(0, 0.6, 1.2)
	story.refs["crate"] = base
	var m := PropFactory.box(main, Vector3(0.9, 0.7, 0.7), base + Vector3(0, 0.0, 0), PropFactory.wood(Color(0.5, 0.36, 0.2)), Vector3.ZERO, false)
	_it(main, base + Vector3(0, 0.5, 0), "Open crate LOT 7", 2.8, func(_by: Node3D, me: Interactable) -> void:
		if story.get_flag("seal_rail"):
			player.say("Only straw and a hollow where the seal lay.")
			return
		if not story.get_flag("rail_talk"):
			player.say("Dozens of crates. Perhaps the yard worker knows which one matters.")
			return
		Sfx.ui("dig_0", -4.0)
		_found_seal("seal_rail", "The Rail-Seal"))
	if m == null:
		pass


func _dig_site() -> void:
	var p := _gp(-95.0, 25.0, 0.0)
	story.refs["dig"] = p + Vector3(0, 1.0, 0)
	PropFactory.cylinder(main, 0.05, 0.05, 1.4, p + Vector3(0, 0.7, 0), PropFactory.wood(), Vector3.ZERO, false, 8)
	PropFactory.box(main, Vector3(0.5, 0.35, 0.02), p + Vector3(0.28, 1.2, 0), PropFactory.cloth(Color(0.75, 0.1, 0.08)), Vector3(0, 0, 8), false)
	PropFactory.box(main, Vector3(1.4, 0.05, 1.4), p + Vector3(0, 0.03, 0), PropFactory.material(Color(0.55, 0.42, 0.28), 1.0), Vector3.ZERO, false)
	_it(main, p + Vector3(0, 0.8, 0), "Dig here", 2.8, func(_by: Node3D, me: Interactable) -> void:
		if story.get_flag("seal_well"):
			player.say("The hole is empty now.")
			return
		if not story.get_flag("well_riddle"):
			player.say("A stake with red cloth. Why would anyone dig here?")
			return
		me.enabled = false
		for i in 4:
			main.get_tree().create_timer(0.2 + i * 1.0).timeout.connect(func() -> void: Sfx.ui("dig_%d" % (i % 3), -3.0))
		hud.progress("Digging...", 4.2, func() -> void:
			me.enabled = true
			_found_seal("seal_well", "The Water-Seal")))


# --- Sun Gate ------------------------------------------------------------------------------

func _gate() -> void:
	var gp := Vector3(0, EntranceBuilder.PLATFORM_Y + 1.2, -172.5)
	story.refs["gate"] = gp
	_it(main, gp, "Examine the Sun Gate", 5.0, func(_by: Node3D, me: Interactable) -> void:
		if story.get_flag("gate_open"):
			player.say("The gate stands open. Act 2 awaits.")
			return
		var n := story.seals_held()
		if n < 3:
			player.say("Three sun-shaped hollows in the stone. %d of 3 filled by your seals." % n if n > 0 else "Three sun-shaped hollows. All empty. Find the Sun-Seals.")
			return
		me.enabled = false
		open_gate())


func open_gate() -> void:
	var door := main.find_child("SealedDoor", true, false) as Node3D
	var gp: Vector3 = story.refs["gate"]
	var shots := [
		{"from": gp + Vector3(0, 1.5, 11), "to": gp + Vector3(0, 1.0, 7), "look": gp + Vector3(0, 0.5, 0), "dur": 5.0,
		 "text": "One by one, the seals sink into the stone. The Sun Gate shudders...", "sfx": "gate_rumble"},
		{"from": gp + Vector3(-9, 0.5, 6), "to": gp + Vector3(-3, 2.0, 5), "look": gp + Vector3(0, 6, 0), "look_to": gp + Vector3(0, 9, 0), "dur": 5.0,
		 "text": "Dust pours from a doorway sealed for a thousand years.", "sfx": "stone_boom"},
		{"from": gp + Vector3(0, 3.0, 4), "to": gp + Vector3(0, 3.0, -2), "look": gp + Vector3(0, 3.0, -14), "dur": 5.0,
		 "text": "Beyond it: a golden corridor, and somewhere in the dark... a lantern. Arin's lantern.", "sfx": "reveal"},
		{"from": gp + Vector3(0, 12, 26), "to": gp + Vector3(0, 18, 40), "look": gp + Vector3(0, 6, 0), "dur": 5.0, "title": true,
		 "text": "Act 2: The Lantern Trail."},
	]
	if door != null:
		var tw := main.create_tween()
		tw.tween_interval(3.0)
		tw.tween_property(door, "position:y", door.position.y - 9.0, 6.0).set_trans(Tween.TRANS_SINE)
	cin.play(shots, "ACT 2: THE LANTERN TRAIL", func() -> void:
		story.set_flag("gate_open", true)
		start_act2()
		hud.banner("ACT 1 COMPLETE", "mission_new"))


# --- intro ---------------------------------------------------------------------------------

func intro() -> void:
	var desk: Vector3 = story.refs["desk"]
	var o := office.global_position
	var shots := [
		{"from": Vector3(40, 34, -105), "to": Vector3(8, 24, -140), "look": Vector3(0, 14, -168), "dur": 6.5, "title": true,
		 "text": "The Valley of Sands. Beyond the dunes, the ruins of Suryavan: a kingdom that vanished in a single night."},
		{"from": Vector3(-60, 14, 70), "to": Vector3(-95, 9, 40), "look": Vector3(-90, 4, 12), "dur": 5.5,
		 "text": "Only a village remains, and the people who still keep its secrets."},
		{"from": o + Vector3(7, 3.0, 12), "to": o + Vector3(4, 2.6, 8), "look": o + Vector3(0, 1.5, 0), "dur": 5.0,
		 "text": "Three days ago, your mentor Dr. Arin Rao walked into those ruins, and did not walk out."},
		{"from": desk + Vector3(1.6, 0.9, 1.6), "to": desk + Vector3(0.8, 0.7, 0.9), "look": desk, "dur": 5.0,
		 "text": "All he left behind is his field office, and a journal that wants to be read."},
	]
	cin.play(shots, "THE LOST KINGDOM", func() -> void: start_in_office())


## After loading a save: remove collected rivets, open the gate if it was opened.
func apply_loaded_state() -> void:
	_seals_seen = story.seals_held()
	var got := int(story.get_flag("rivets", 0))
	var left: Array = story.refs.get("rivets", [])
	for i in mini(got, left.size()):
		var n: Node = left[0]
		left.remove_at(0)
		n.queue_free()
	if story.get_flag("gate_open"):
		var door := main.find_child("SealedDoor", true, false) as Node3D
		if door != null:
			door.position.y -= 9.0
		for it in main.get_tree().get_nodes_in_group("interactables"):
			if (it as Interactable).prompt.begins_with("Examine the Sun Gate"):
				(it as Interactable).enabled = false
		start_act2()
	story.silence()
	story.refresh()


func start_in_office() -> void:
	var hs: Dictionary = main.houses.houses[5]
	var p: Vector3 = hs["inside"]
	player.global_position = p + Vector3(0, 0.4, 0)
	player.velocity = Vector3.ZERO
	var d: Vector3 = (story.refs["desk"] as Vector3) - p
	player.set_look(atan2(-d.x, -d.z), -0.05)
	hud.banner("CHAPTER ONE\nWhere is Arin?", "mission_new")
	story.set_flag("intro_done", true)


# --- seal effect ---------------------------------------------------------------------------

func _on_story_changed() -> void:
	var held := story.seals_held()
	if held > _seals_seen:
		_seals_seen = held
		hud.banner("SUN-SEAL FOUND (%d/3)" % held, "seal_found")
		seal_fx(player.global_position + Vector3(0, 1.0, 0))


func _sparks(parent: Node3D, color: Color, amount: int, speed: float, life: float, grav: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, grav, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	sm.material = m
	p.mesh = sm
	parent.add_child(p)
	p.emitting = true
	return p


## A golden sun-disc rises from the player, spins, bursts into sparks and fades.
func seal_fx(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	main.add_child(root)
	var disc := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.38
	cy.bottom_radius = 0.38
	cy.height = 0.06
	disc.mesh = cy
	disc.material_override = PropFactory.glow_bronze()
	disc.rotation_degrees.x = 90
	root.add_child(disc)
	for k in 12:
		var ray := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.22, 0.03)
		ray.mesh = bm
		ray.material_override = PropFactory.glow_bronze()
		ray.rotation.z = k * TAU / 12.0
		ray.position = Vector3(cos(k * TAU / 12.0), sin(k * TAU / 12.0), 0) * 0.52
		disc.add_child(ray)
	disc.rotation_degrees = Vector3(0, 0, 0)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.4)
	l.omni_range = 9.0
	l.light_energy = 0.0
	root.add_child(l)
	_sparks(root, Color(1.0, 0.85, 0.4), 60, 3.5, 1.6, -1.5)
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(root, "position:y", at.y + 1.6, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(disc, "rotation:y", TAU * 3.0, 2.2)
	tw.tween_property(l, "light_energy", 4.0, 0.5)
	tw.chain().tween_property(root, "scale", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(l, "light_energy", 0.0, 0.5)
	tw.chain().tween_callback(root.queue_free)


# --- Act 2: Arin and the Queen's lanterns -------------------------------------------------

func start_act2() -> void:
	if _act2_ready:
		return
	_act2_ready = true
	_spawn_arin()
	var lanterns: Array = []
	for lp in [Vector2(-12.0, -158.0), Vector2(12.0, -158.0), Vector2(0.0, -150.0)]:
		var l := _lantern(lp)
		lanterns.append(l)
	story.refs["lanterns"] = lanterns
	# lanterns already lit in a loaded save
	var lit := int(story.get_flag("lanterns", 0))
	for i in mini(lit, lanterns.size()):
		_light(lanterns[i], false)
	story.changed.emit()


func _spawn_arin() -> void:
	var n := Npc.new().setup(NpcBuilder.PRESETS["merchant"], "idle", "Arin")
	n.player = player
	main.add_child(n)
	n.global_position = Vector3(3.0, EntranceBuilder.PLATFORM_Y + 0.05, -161.0)
	n.rotation.y = deg_to_rad(20.0)
	n.home_yaw = n.rotation.y
	story.refs["Arin"] = n
	main.npcs.append(n)
	var it := _it(n, Vector3(0, 1.1, 0), "Talk to Dr. Arin", 3.3, Callable())
	it.on_interact = func(_by: Node3D, _me: Interactable) -> void:
		dlg.open(story.dialogue_for("Arin"), n, "man")


func _lantern(p2: Vector2) -> Node3D:
	var from := Vector3(p2.x, EntranceBuilder.PLATFORM_Y + 4.0, p2.y)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -8, 0))
	var hit := main.get_world_3d().direct_space_state.intersect_ray(q)
	var gy: float = hit["position"].y if not hit.is_empty() else EntranceBuilder.PLATFORM_Y
	var n := Node3D.new()
	n.position = Vector3(p2.x, gy, p2.y)
	main.add_child(n)
	PropFactory.cylinder(n, 0.08, 0.14, 1.6, Vector3(0, 0.8, 0), PropFactory.bronze(), Vector3.ZERO, false, 10)
	PropFactory.cylinder(n, 0.3, 0.14, 0.18, Vector3(0, 1.65, 0), PropFactory.bronze(), Vector3.ZERO, false, 12)
	var flame := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.36
	flame.mesh = sm
	flame.material_override = PropFactory.glow_lamp()
	flame.position = Vector3(0, 1.9, 0)
	flame.scale = Vector3.ZERO
	flame.name = "Flame"
	n.add_child(flame)
	var l := OmniLight3D.new()
	l.name = "Light"
	l.light_color = Color(1.0, 0.72, 0.35)
	l.omni_range = 11.0
	l.light_energy = 0.0
	l.position = Vector3(0, 2.0, 0)
	n.add_child(l)
	var it := _it(n, Vector3(0, 1.5, 0), "Light the lantern", 3.2, Callable())
	it.on_interact = func(_by: Node3D, me: Interactable) -> void:
		me.enabled = false
		story.add("lanterns", 1)
		_light(n, true)
		player.say("The flame catches. Somewhere beneath the stone, something answers. (%d/3)" % int(story.get_flag("lanterns", 0)))
	return n


func _light(n: Node3D, animate: bool) -> void:
	var flame := n.get_node("Flame") as Node3D
	var l := n.get_node("Light") as OmniLight3D
	for c in n.get_children():
		if c is Interactable:
			(c as Interactable).enabled = false
	if animate:
		Sfx.at("reveal", n.global_position + Vector3(0, 2, 0), -6.0, 1.3)
		_sparks(n, Color(1.0, 0.8, 0.4), 40, 2.8, 1.4, -1.0).position = Vector3(0, 1.9, 0)
		var tw := n.create_tween().set_parallel(true)
		tw.tween_property(flame, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "light_energy", 2.6, 1.2)
		tw.chain().tween_callback(func() -> void: _flicker(l))
	else:
		flame.scale = Vector3.ONE
		l.light_energy = 2.6
		_flicker(l)


func _flicker(l: OmniLight3D) -> void:
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "light_energy", 2.2, 0.31)
	tw.tween_property(l, "light_energy", 2.9, 0.23)
	tw.tween_property(l, "light_energy", 2.4, 0.37)
