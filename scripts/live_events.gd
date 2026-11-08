class_name LiveEvents
extends Node3D
## Real-calendar festivals, read from the phone's date. While one is on, the village celebrates, there is a
## short festival task with a reward, and a festival outfit is sold in the bazaar (and given free for the task):
##   Diwali     (5 days around Lakshmi Puja): light 12 diyas round the bazaar square; fireworks every night.
##   Holi       (around Dhulandi):             throw colour at 8 villagers; colour bursts by the fountain.
##   Sankranti  (around 14 January):           shoot 6 kites out of the sky with your bow.
##   Dussehra   (Navratri to Vijayadashami):   burn the Ravana effigy with 3 fire arrows; fireworks after.
## Hindu festivals follow the lunar calendar, so their dates are listed per year (checked against
## publicholidays.in and holidaydb.com); Sankranti is fixed. Progress is saved per festival per year.

const C := Festival.C                 # the bazaar square
const EVENTS := {
	"diwali": {"name": "Diwali", "title": "Festival of Lights", "dates": ["2026-11-08", "2027-10-29", "2028-10-17"],
		"before": 4, "after": 3, "goal": 12, "outfit": "diwali_sherwani", "coins": 150,
		"task": "Light the diyas round the bazaar square", "intro": "Diwali is here! Light the diyas round the bazaar square."},
	"holi": {"name": "Holi", "title": "Festival of Colours", "dates": ["2027-03-22", "2028-03-11"],
		"before": 1, "after": 2, "goal": 8, "outfit": "holi_kurta", "coins": 120,
		"task": "Throw colour at villagers", "intro": "Holi hai! Throw colour at the villagers in the bazaar."},
	"sankranti": {"name": "Makar Sankranti", "title": "Kite Festival", "yearly": "01-14",
		"before": 1, "after": 2, "goal": 6, "outfit": "kite_jacket", "coins": 140,
		"task": "Shoot kites out of the sky with your bow", "intro": "Makar Sankranti! Kites fill the sky. Shoot them down with your bow."},
	"dussehra": {"name": "Dussehra", "title": "Victory of Good", "dates": ["2026-10-20", "2027-10-09", "2028-09-27"],
		"before": 9, "after": 1, "goal": 3, "outfit": "vijaya_warrior", "coins": 200,
		"task": "Burn the Ravana effigy with fire arrows", "intro": "Dussehra! Burn the Ravana effigy with fire arrows."},
}

var main: Node3D
var story: Story
var player: Player
var terrain: TerrainBuilder
var hud: Node
var festival: Festival
var active := ""
var year := 0
var _root: Node3D
var _targets: Array = []            # diyas, villagers, kites, the effigy
var _fw_t := 3.0
var _t := 0.0
var _effigy_burning := false


func build() -> void:
	add_to_group("live_events")
	var forced := OS.get_environment("EVENT")
	if forced == "" and "--selftest" in OS.get_cmdline_user_args():
		return                                 # the selftest starts festivals itself
	if forced == "" and story != null:
		forced = String(story.get_flag("event_override", ""))
	var today := _today()
	year = int(today.substr(0, 4))
	active = forced if EVENTS.has(forced) else event_for_date(today)
	if active == "":
		return
	start(active)


## "YYYY-MM-DD" from the phone's clock.
func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]


static func _day_number(date: String) -> int:
	return int(floor(Time.get_unix_time_from_datetime_string(date + "T12:00:00") / 86400.0))


## Which festival (if any) is on for a date.
static func event_for_date(date: String) -> String:
	var dn := _day_number(date)
	var y := int(date.substr(0, 4))
	for id in EVENTS:
		var e: Dictionary = EVENTS[id]
		var days: Array = []
		if e.has("yearly"):
			for yy in [y - 1, y, y + 1]:
				days.append(_day_number("%04d-%s" % [yy, String(e["yearly"])]))
		else:
			for ds in e["dates"]:
				days.append(_day_number(String(ds)))
		for fd in days:
			if dn >= int(fd) - int(e["before"]) and dn <= int(fd) + int(e["after"]):
				return id
	return ""


func _key(s: String) -> String:
	return "ev_%s_%d_%s" % [active, year, s]


func progress() -> int:
	return int(story.get_flag(_key("n"), 0))


func done() -> bool:
	return bool(story.get_flag(_key("done"), false))


func goal() -> int:
	return int(EVENTS[active]["goal"]) if active != "" else 0


func start(id: String) -> void:
	active = id
	var e: Dictionary = EVENTS[id]
	_root = Node3D.new()
	_root.name = "LiveEvent_" + id
	add_child(_root)
	if festival != null:
		festival.force_kind = "colours" if id == "holi" else "lights"
	match id:
		"diwali":
			_build_diyas()
		"holi":
			(func() -> void: _tag_villagers()).call_deferred()
		"sankranti":
			_build_kites()
		"dussehra":
			_build_effigy()
	story.quests.insert(mini(1, story.quests.size()), {
		"id": "event_" + id, "title": String(e["title"]), "blurb": String(e["intro"]),
		"show": func() -> bool: return active == id and not done(),
		"objs": [
			{"text": func() -> String: return "%s (%d/%d)" % [Loc.t(String(e["task"])), progress(), goal()],
			 "done": func() -> bool: return done(),
			 "target": func() -> Vector3: return _next_target_pos()},
		],
	})
	var seen := _key("seen")
	if not bool(story.get_flag(seen, false)):
		story.set_flag(seen, true)
		if id == "dussehra" and player != null:
			var it := get_tree().get_first_node_in_group("items") if is_inside_tree() else null
			if it != null:
				it.call("give", "fire_arrow", 5)
		(func() -> void:
			if hud != null:
				hud.banner(Loc.t(String(e["intro"])) + "\n" + Loc.t("Festival outfit in the bazaar: %s") % Loc.t(_outfit_name(String(e["outfit"]))), "cheer_crowd")).call_deferred()


func _outfit_name(oid: String) -> String:
	for o in Wardrobe.OUTFITS:
		if String(o["id"]) == oid:
			return String(o["name"])
	return oid


## True while an event outfit may be bought (its festival is on).
func outfit_on_sale(oid: String) -> bool:
	return active != "" and String(EVENTS[active]["outfit"]) == oid


func _next_target_pos() -> Vector3:
	for t in _targets:
		if is_instance_valid(t) and not bool((t as Node).get_meta("done", false)):
			return (t as Node3D).global_position
	return Vector3.ZERO


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, terrain.sample_height(x, z), z)


func _mat(c: Color, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _mark(n: Node) -> void:
	if bool(n.get_meta("done", false)):
		return
	n.set_meta("done", true)
	var k := progress() + 1
	story.set_flag(_key("n"), k)
	story.changed.emit()
	if k >= goal() and not done():
		_complete()


func _complete() -> void:
	if not EVENTS.has(active):
		return
	var e: Dictionary = EVENTS[active]
	story.set_flag(_key("done"), true)
	var coins = main.get("coin_sys")
	if coins != null:
		coins.call("add", int(e["coins"]), "festival")
	var oid := String(e["outfit"])
	story.set_flag("own_" + oid, true)
	var wr := get_tree().get_first_node_in_group("wardrobe")
	if wr != null:
		wr.call("wear", oid)
	if hud != null:
		hud.banner(Loc.t("Happy %s!") % Loc.t(String(e["name"])) + "\n" + "+%d %s, %s" % [int(e["coins"]), Loc.t("coins"), Loc.t(_outfit_name(oid))], "seal_found")
	Sfx.ui("cheer_crowd", -2.0)
	for i in 5:
		get_tree().create_timer(0.35 * i).timeout.connect(_firework)
	var ach := get_tree().get_first_node_in_group("achievements")
	if ach != null:
		ach.call("unlock", "festive")
	story.changed.emit()


# --- Diwali: diyas ---------------------------------------------------------------------------

func _build_diyas() -> void:
	var clay := _mat(Color(0.62, 0.32, 0.16))
	var flame_m := _mat(Color(1.0, 0.7, 0.25), 4.0)
	flame_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 12:
		var a := TAU * float(i) / 12.0
		var p := _ground(C.x + cos(a) * 8.5, C.z + sin(a) * 8.5)
		var d := Node3D.new()
		_root.add_child(d)
		d.global_position = p
		var bowl := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.12
		sm.is_hemisphere = false
		bowl.mesh = sm
		bowl.material_override = clay
		bowl.position.y = 0.05
		d.add_child(bowl)
		var fl := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.045
		fm.height = 0.14
		fl.mesh = fm
		fl.material_override = flame_m
		fl.position = Vector3(0.08, 0.17, 0)
		fl.visible = false
		fl.name = "Flame"
		d.add_child(fl)
		var it := Interactable.new()
		it.position = Vector3(0, 0.4, 0)
		it.prompt = "Light the diya"
		it.reach = 2.2
		it.on_interact = func(_by: Node3D, me: Interactable) -> void: light_diya(d, me)
		d.add_child(it)
		_targets.append(d)
		if i < progress():
			fl.visible = true
			it.enabled = false
			d.set_meta("done", true)


func light_diya(d: Node3D, it: Interactable) -> void:
	if bool(d.get_meta("done", false)):
		return
	(d.get_node("Flame") as Node3D).visible = true
	if it != null:
		it.enabled = false
	Sfx.at("tink", d.global_position, -8.0, 1.5)
	_mark(d)


# --- Holi: colour the villagers ---------------------------------------------------------------

func _tag_villagers() -> void:
	var npcs: Array = []
	for n in get_tree().get_nodes_in_group("npcs"):
		if n is Node3D and is_instance_valid(n):
			npcs.append(n)
	npcs.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(Vector3(C.x, 0, C.z)) < b.global_position.distance_squared_to(Vector3(C.x, 0, C.z)))
	var left := goal() - progress()
	for i in mini(left, npcs.size()):
		var npc: Node3D = npcs[i]
		var it := Interactable.new()
		it.position = Vector3(0, 1.2, 0)
		it.prompt = "Throw colour (Holi hai!)"
		it.reach = 2.6
		it.on_interact = func(_by: Node3D, me: Interactable) -> void: colour(npc, me)
		npc.add_child(it)
		_targets.append(npc)


func colour(npc: Node3D, it: Interactable) -> void:
	if bool(npc.get_meta("done", false)):
		return
	if it != null:
		it.enabled = false
	var cols := [Color(0.95, 0.2, 0.55), Color(0.2, 0.8, 0.35), Color(1.0, 0.8, 0.1), Color(0.25, 0.55, 1.0)]
	HitFx.burst(main, npc.global_position + Vector3(0, 1.3, 0), true, cols[randi() % cols.size()])
	HitFx.burst(main, npc.global_position + Vector3(0, 1.0, 0), true, cols[randi() % cols.size()])
	Sfx.at("child_laugh", npc.global_position + Vector3(0, 1.4, 0), -4.0, randf_range(0.9, 1.15))
	if npc.has_method("say"):
		npc.call("say", "Holi hai!")
	_mark(npc)


# --- Sankranti: kites --------------------------------------------------------------------------

func _build_kites() -> void:
	var cols := [Color(0.95, 0.2, 0.3), Color(1.0, 0.75, 0.1), Color(0.2, 0.55, 1.0), Color(0.3, 0.85, 0.4), Color(0.85, 0.3, 0.9), Color(1.0, 0.5, 0.1)]
	for i in goal():
		var k := Node3D.new()
		k.name = "Kite%d" % i
		_root.add_child(k)
		var a := TAU * float(i) / float(goal()) + 0.4
		var base := _ground(C.x + cos(a) * 22.0, C.z + sin(a) * 22.0) + Vector3(0, 16.0 + 3.0 * float(i % 3), 0)
		k.global_position = base
		k.set_meta("base", base)
		k.set_meta("phase", float(i) * 1.3)
		var mi := MeshInstance3D.new()
		var pm := PrismMesh.new()                 # a diamond: two flat triangles
		pm.size = Vector3(1.1, 0.8, 0.02)
		mi.mesh = pm
		var m := _mat(cols[i % cols.size()])
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		k.add_child(mi)
		var mi2 := MeshInstance3D.new()
		mi2.mesh = pm
		mi2.material_override = m
		mi2.rotation.z = PI
		mi2.position.y = -0.8
		k.add_child(mi2)
		var tail := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.05, 1.2, 0.02)
		tail.mesh = tm
		tail.material_override = _mat(Color(1, 1, 1))
		tail.position.y = -1.7
		k.add_child(tail)
		k.add_to_group("arrow_targets")
		k.set_meta("events", self)
		k.set_meta("radius", 1.4)
		k.set_meta("kind", "kite")
		_targets.append(k)
		if i < progress():
			k.set_meta("done", true)
			k.visible = false
			k.remove_from_group("arrow_targets")


# --- Dussehra: the Ravana effigy -------------------------------------------------------------------

func _build_effigy() -> void:
	var e := Node3D.new()
	e.name = "Ravana"
	_root.add_child(e)
	e.global_position = _ground(C.x, C.z + 30.0)
	var red := _mat(Color(0.7, 0.1, 0.08))
	var gold := _mat(Color(0.95, 0.75, 0.2))
	var dark := _mat(Color(0.2, 0.08, 0.06))
	var face := _mat(Color(0.95, 0.75, 0.55))
	var parts := [
		[Vector3(0.6, 3.2, 0.6), Vector3(-0.7, 1.6, 0), dark], [Vector3(0.6, 3.2, 0.6), Vector3(0.7, 1.6, 0), dark],
		[Vector3(2.6, 3.4, 1.2), Vector3(0, 4.9, 0), red], [Vector3(2.8, 0.3, 1.3), Vector3(0, 3.3, 0), gold],
		[Vector3(0.5, 2.8, 0.5), Vector3(-1.7, 5.0, 0), red], [Vector3(0.5, 2.8, 0.5), Vector3(1.7, 5.0, 0), red],
		[Vector3(0.12, 3.8, 0.12), Vector3(2.0, 4.6, 0.3), gold],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mi.mesh = bm
		mi.material_override = p[2]
		mi.position = p[1]
		e.add_child(mi)
	for h in 10:                                   # ten heads in a row, the middle one largest
		var x := (float(h) - 4.5) * 0.62
		var big := absf(x) < 0.4
		var hm := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.42 if big else 0.32
		sm.height = sm.radius * 2.2
		hm.mesh = sm
		hm.material_override = face
		hm.position = Vector3(x, 7.0 + (0.15 if big else 0.0), 0)
		e.add_child(hm)
		var cr := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = sm.radius * 0.8
		cm.height = 0.5
		cr.mesh = cm
		cr.material_override = gold
		cr.position = hm.position + Vector3(0, sm.radius + 0.2, 0)
		e.add_child(cr)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 7.6, 1.4)
	cs.shape = box
	cs.position.y = 3.8
	body.add_child(cs)
	e.add_child(body)
	e.add_to_group("arrow_targets")
	e.set_meta("events", self)
	e.set_meta("radius", 1.8)
	e.set_meta("kind", "effigy")
	e.set_meta("aim_h", 4.8)
	_targets.append(e)
	if done():
		e.visible = false
		e.remove_from_group("arrow_targets")


## Called by an Arrow that passes close to a festival target.
func arrow_hit(t: Node3D, fire: bool) -> bool:
	if active == "":
		return false
	var kind := String(t.get_meta("kind", ""))
	if bool(t.get_meta("done", false)):
		return false
	if kind == "kite":
		t.set_meta("done", true)
		t.remove_from_group("arrow_targets")
		Sfx.at("tink", t.global_position, 0.0, 1.8)
		var tw := t.create_tween()
		tw.tween_property(t, "global_position", t.global_position - Vector3(0, 14.0, 0), 2.2).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(t, "rotation:z", 9.0, 2.2)
		tw.tween_callback(func() -> void: t.visible = false)
		t.set_meta("done", false)
		_mark(t)
		return true
	if kind == "effigy":
		if not fire:
			player.message.emit(Loc.t("It needs fire! Hold DRAW to full draw with fire arrows."))
			return true
		var n := progress() + 1
		Sfx.at("stone_boom", t.global_position + Vector3(0, 4, 0), -4.0, 1.4)
		HitFx.burst(main, t.global_position + Vector3(0, 4.5, 0), true, Color(1.0, 0.45, 0.1))
		if n >= goal():
			_burn_effigy(t)
		story.set_flag(_key("n"), n)
		story.changed.emit()
		if n >= goal() and not done():
			t.set_meta("done", true)
			_complete()
		return true
	return false


func _burn_effigy(t: Node3D) -> void:
	_effigy_burning = true
	t.remove_from_group("arrow_targets")
	var fire := CPUParticles3D.new()
	fire.amount = 90
	fire.lifetime = 1.4
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fire.emission_box_extents = Vector3(1.4, 3.6, 0.6)
	fire.direction = Vector3.UP
	fire.spread = 20.0
	fire.initial_velocity_min = 1.5
	fire.initial_velocity_max = 4.0
	fire.gravity = Vector3(0, 1.5, 0)
	fire.scale_amount_min = 0.4
	fire.scale_amount_max = 1.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1.0, 0.85, 0.3, 0.9), Color(1.0, 0.35, 0.05, 0.7), Color(0.2, 0.2, 0.2, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	fire.color_ramp = g
	var q := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	SoftDot.apply(m)
	q.material = m
	fire.mesh = q
	fire.position.y = 4.0
	t.add_child(fire)
	var tw := t.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(t, "scale:y", 0.15, 3.0).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: fire.emitting = false)


# --- fireworks -----------------------------------------------------------------------------------

func _firework() -> void:
	if not is_inside_tree():
		return
	var p := _ground(C.x + randf_range(-18.0, 18.0), C.z + randf_range(-18.0, 18.0)) + Vector3(0, randf_range(22.0, 32.0), 0)
	var fw := CPUParticles3D.new()
	fw.one_shot = true
	fw.amount = 70
	fw.lifetime = 1.8
	fw.explosiveness = 1.0
	fw.direction = Vector3.UP
	fw.spread = 180.0
	fw.initial_velocity_min = 7.0
	fw.initial_velocity_max = 10.0
	fw.gravity = Vector3(0, -3.0, 0)
	fw.damping_min = 2.0
	fw.damping_max = 3.0
	fw.scale_amount_min = 0.25
	fw.scale_amount_max = 0.45
	var c := Color.from_hsv(randf(), 0.75, 1.0)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), c, Color(c.r, c.g, c.b, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	fw.color_ramp = g
	var q := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_fog = true
	SoftDot.apply(m)
	q.material = m
	fw.mesh = q
	add_child(fw)
	fw.global_position = p
	fw.emitting = true
	Sfx.at("firework", p, 2.0, randf_range(0.9, 1.1))
	get_tree().create_timer(2.5).timeout.connect(fw.queue_free)


func _process(delta: float) -> void:
	if active == "":
		return
	_t += delta
	# kites drift and bob on the wind
	if active == "sankranti":
		for k in _targets:
			var n := k as Node3D
			if n == null or bool(n.get_meta("done", false)) or not n.is_in_group("arrow_targets"):
				continue
			var b: Vector3 = n.get_meta("base")
			var ph := float(n.get_meta("phase"))
			n.global_position = b + Vector3(sin(_t * 0.5 + ph) * 3.0, sin(_t * 1.3 + ph) * 1.2, cos(_t * 0.4 + ph) * 2.0)
			n.rotation.z = sin(_t * 1.7 + ph) * 0.35
	# fireworks over the square on Diwali and Dussehra nights (and after the effigy burns)
	if active == "diwali" or active == "dussehra":
		var night := festival != null and festival.atmo != null and (festival.atmo.time_of_day > 0.74 or festival.atmo.time_of_day < 0.2)
		if night or _effigy_burning:
			_fw_t -= delta
			if _fw_t <= 0.0 and player != null and player.global_position.distance_to(Vector3(C.x, player.global_position.y, C.z)) < 120.0:
				_fw_t = randf_range(2.0, 5.0)
				_firework()
