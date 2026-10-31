class_name Act5
extends Node3D
## ACT 5: The Last Sun. The Solar Vault (a golden hall off the map): Arin's revelation, three sun pedestals to
## light in order (east, centre, west), the three-stage Eclipse Guardian, then the final choice and the endings.

const ORIGIN := Vector3(-700.0, 0.0, 700.0)
const HALL_W := 36.0
const HALL_L := 90.0
const ORDER := [2, 1, 0]            # follow the sun: east, centre, west

var camp: Campaign
var story: Story
var hud: Node
var player: Player
var terrain: TerrainBuilder
var combat: CombatBuilder
var dlg: DialogueUI
var cin: Cinematic
var arin: Npc
var arin_it: Interactable
var ped_its: Array[Interactable] = []
var ped_lamps: Array[Node3D] = []
var seq: Array[int] = []
var heart_it: Interactable
var guardian: Enemy
var stage := 0
var credits: CanvasLayer
var _started := false


func _o(x: float, y: float, z: float) -> Vector3:
	return ORIGIN + Vector3(x, y, z)


func build() -> void:
	story = camp.story
	hud = camp.hud
	player = camp.player
	terrain = camp.terrain
	combat = camp.combat
	dlg = camp.dlg
	cin = camp.cin
	add_to_group("act5")
	_build_hall()
	_build_pedestals()
	_build_arin()
	_build_heart()
	_entrances()
	_add_quest()
	story.changed.connect(_on_changed)
	_on_changed()


func _build_hall() -> void:
	var stone := PropFactory.stone(Color(0.8, 0.7, 0.45))
	var dark := PropFactory.stone(Color(0.5, 0.42, 0.28))
	var gold := PropFactory.material(Color(1.0, 0.8, 0.3), 0.4, 0.6, Color(1.0, 0.7, 0.2), 0.6)
	var root := Node3D.new()
	root.name = "SolarVault"
	add_child(root)
	PropFactory.box(root, Vector3(HALL_W, 1.0, HALL_L), _o(0, -0.5, 0), stone, Vector3.ZERO, true, false)
	PropFactory.box(root, Vector3(1.2, 14.0, HALL_L), _o(-HALL_W * 0.5, 7.0, 0), dark, Vector3.ZERO, true, false)
	PropFactory.box(root, Vector3(1.2, 14.0, HALL_L), _o(HALL_W * 0.5, 7.0, 0), dark, Vector3.ZERO, true, false)
	PropFactory.box(root, Vector3(HALL_W, 14.0, 1.2), _o(0, 7.0, -HALL_L * 0.5), dark, Vector3.ZERO, true, false)
	PropFactory.box(root, Vector3(HALL_W, 14.0, 1.2), _o(0, 7.0, HALL_L * 0.5), dark, Vector3.ZERO, true, false)
	PropFactory.box(root, Vector3(HALL_W, 1.0, HALL_L), _o(0, 14.5, 0), dark, Vector3.ZERO, false, false)
	# golden inlay down the middle and a big sun disc over the Heart's altar
	PropFactory.box(root, Vector3(3.0, 0.05, HALL_L - 6.0), _o(0, 0.03, 0), gold, Vector3.ZERO, false, false)
	PropFactory.cylinder(root, 6.0, 6.0, 0.08, _o(0, 0.05, -38.0), gold, Vector3.ZERO, false, 24, 0, false)
	for i in 6:
		for sx in [-1.0, 1.0]:
			PropFactory.cylinder(root, 0.8, 0.9, 14.0, _o(sx * 13.0, 7.0, -36.0 + i * 15.0), stone, Vector3.ZERO, true, 10, 0, false)
	var glow := PropFactory.glow_lamp()
	for i in 5:
		var lp := _o(0.0, 11.0, -36.0 + i * 18.0)
		PropFactory.sphere(root, 0.5, lp, glow)
		if i % 2 == 0:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.82, 0.5)
			l.omni_range = 30.0
			l.light_energy = 2.6
			root.add_child(l)
			l.global_position = lp


func _build_pedestals() -> void:
	var stone := PropFactory.stone(Color(0.7, 0.62, 0.5))
	var glow := PropFactory.glow_lamp()
	for i in 3:
		var p := Node3D.new()
		add_child(p)
		p.global_position = _o(-9.0 + i * 9.0, 0, 12.0)
		PropFactory.cylinder(p, 0.5, 0.7, 1.3, Vector3(0, 0.65, 0), stone, Vector3.ZERO, false, 8, 0, false)
		var lamp := PropFactory.sphere(p, 0.4, Vector3(0, 1.7, 0), glow)
		lamp.visible = false
		ped_lamps.append(lamp)
		var it := Interactable.new()
		it.position = Vector3(0, 1.3, 0)
		it.prompt = "Touch the sun pedestal"
		it.reach = 3.0
		p.add_child(it)
		ped_its.append(it)
		var idx := i
		it.on_interact = func(_by: Node3D, _me: Interactable) -> void: touch_pedestal(idx)


func touch_pedestal(i: int) -> bool:
	if story.get_flag("pedestals_done", false):
		return false
	if i != ORDER[seq.size()]:
		seq.clear()
		for l in ped_lamps:
			l.visible = false
		hud.banner(Loc.t("The light fades. Follow the sun: east to west."), "")
		return false
	seq.append(i)
	ped_lamps[i].visible = true
	Sfx.ui_at("reveal", -4.0)
	if seq.size() == 3:
		story.set_flag("pedestals_done", true)
		hud.banner(Loc.t("The sun doors open!"), "reveal")
		_on_changed()
	return true


func _build_arin() -> void:
	var pr: Dictionary = (NpcBuilder.PRESETS["scholar"] as Dictionary).duplicate()
	arin = Npc.new().setup(pr, "idle", "Dr. Arin Rao")
	arin.player = player
	camp.main.add_child(arin)
	arin.global_position = _o(6.0, 0.05, 30.0)
	arin.rotation.y = deg_to_rad(20.0)
	arin_it = Interactable.new()
	arin_it.position = Vector3(0, 1.1, 0)
	arin_it.prompt = "Speak to Arin"
	arin_it.reach = 3.2
	arin.add_child(arin_it)
	arin_it.on_interact = func(_by: Node3D, _me: Interactable) -> void: arin_talk()


func arin_talk() -> void:
	var n := {
		"a": {"who": "Dr. Arin Rao", "text": "You came all this way. The Sun Heart sleeps beyond these doors. Ila hid it so no one could own the sun, but the valley is dying without it.", "go": "b"},
		"b": {"who": "Dr. Arin Rao", "text": "Light the three sun pedestals: follow the sun's road, east to west. A guardian of the eclipse waits behind. When it falls, the choice will be yours alone.",
			"choices": [{"t": "I understand. I will finish this.", "go": "", "set": {"arin5_met": true}}]},
	}
	dlg.open({"start": "a", "nodes": n}, arin, "man")


func _build_heart() -> void:
	var h := Node3D.new()
	add_child(h)
	h.global_position = _o(0, 0, -38.0)
	PropFactory.cylinder(h, 1.0, 1.4, 1.6, Vector3(0, 0.8, 0), PropFactory.stone(Color(0.85, 0.75, 0.5)), Vector3.ZERO, false, 12, 0, false)
	PropFactory.sphere(h, 0.7, Vector3(0, 2.4, 0), PropFactory.material(Color(1.0, 0.85, 0.4), 0.2, 0.0, Color(1.0, 0.8, 0.3), 5.0))
	heart_it = Interactable.new()
	heart_it.position = Vector3(0, 1.5, 0)
	heart_it.prompt = "Touch the Sun Heart"
	heart_it.reach = 3.5
	heart_it.enabled = false
	h.add_child(heart_it)
	heart_it.on_interact = func(_by: Node3D, _me: Interactable) -> void: choose()


func _entrances() -> void:
	var down := Interactable.new()
	down.prompt = "Enter the Solar Vault"
	down.reach = 4.0
	down.position = camp.gate_pos + Vector3(-5.0, 0.0, 6.0)
	camp.main.add_child(down)
	down.on_interact = func(_by: Node3D, _me: Interactable) -> void: enter()
	var up := Interactable.new()
	up.prompt = "Leave the Solar Vault"
	up.reach = 4.0
	up.position = _o(0, 1.0, HALL_L * 0.5 - 3.0)
	add_child(up)
	up.on_interact = func(_by: Node3D, _me: Interactable) -> void: leave()


func enter() -> bool:
	if not story.get_flag("act4_done", false):
		hud.banner(Loc.t("The Solar Vault is sealed. Deal with Vessa first."), "")
		return false
	player.global_position = _o(0, 1.0, HALL_L * 0.5 - 8.0)
	player.velocity = Vector3.ZERO
	story.set_flag("v5_entered", true)
	Sfx.ui_at("stone_boom", -4.0)
	return true


func leave() -> void:
	player.global_position = camp.gate_pos + Vector3(-3.0, 1.0, 10.0)
	player.velocity = Vector3.ZERO


# --- Eclipse Guardian (three stages) ---------------------------------------------------------

func _on_changed() -> void:
	if story.get_flag("pedestals_done", false) and guardian == null and not story.get_flag("eclipse_down", false) and not _started:
		_started = true
		spawn_guardian.call_deferred()
	if story.get_flag("eclipse_down", false) and heart_it != null:
		heart_it.enabled = not story.get_flag("ending_done", false)


func spawn_guardian() -> Enemy:
	guardian = combat.spawn_enemy(_o(0, 0.3, -22.0), true, 60.0, "eclipse")
	guardian.name = "EclipseGuardian"
	guardian.hp = 900.0
	guardian.max_hp = 900.0
	guardian.damage = 24.0
	guardian.scale = Vector3.ONE * 1.5
	guardian._refresh_bar()
	stage = 1
	hud.banner(Loc.t("The Eclipse Guardian rises!"), "war_roar")
	return guardian


func _adds(n: int) -> void:
	var roles := ["shield", "archer", "ambusher"]
	for k in n:
		var p := _o(-8.0 + k * 8.0, 0.4, -8.0)
		var e := combat.spawn_enemy(p, false, 60.0, "eclipse_add")
		e.apply_role(roles[k % roles.size()])


func _process(_delta: float) -> void:
	if guardian == null or not is_instance_valid(guardian) or guardian.dead:
		return
	var f: float = guardian.hp / guardian.max_hp
	if stage == 1 and f < 0.66:
		stage = 2
		_adds(3)
		hud.banner(Loc.t("The eclipse deepens!"), "raid_panic")
	elif stage == 2 and f < 0.33:
		stage = 3
		guardian.enrage()
		_adds(3)
		hud.banner(Loc.t("Total eclipse! Strike now!"), "war_roar")


# --- the choice and the endings --------------------------------------------------------------

func secret_unlocked() -> bool:
	var ach: Achievements = camp.main.get("achievements") as Achievements
	var rb: VillageRebuild = camp.main.get("rebuild") as VillageRebuild
	return rb != null and rb.stage() >= 3 and story.get_flag("karan_fate", "") == "spared" and story.get_flag("vikram_fate", "") == "forgiven" and ach != null and ach.count() >= 5


func choose() -> void:
	var choices := [
		{"t": "Wake the Heart and restore the sun. (Heroic)", "go": "", "set": {"ending": "heroic"}},
		{"t": "Give yourself to the light. (Sacrifice)", "go": "", "set": {"ending": "sacrifice"}},
	]
	if secret_unlocked():
		choices.append({"t": "Share the light with every soul in the valley. (Secret)", "go": "", "set": {"ending": "secret"}})
	var n := {"a": {"who": "Narrator", "text": "The Sun Heart waits. Ila left the choice to whoever opened the door. What is the light for?", "choices": choices}}
	dlg.open({"start": "a", "nodes": n}, null, "old", func() -> void:
		var e := String(story.get_flag("ending", ""))
		if e != "":
			play_ending(e))


func ending_lines(e: String) -> Array:
	var kar := String(story.get_flag("karan_fate", ""))
	var vik := String(story.get_flag("vikram_fate", ""))
	var tail := ""
	if kar == "spared":
		tail += " Karan keeps the new watch on the Sun Gate."
	if vik == "forgiven":
		tail += " Vikram rebuilds the library, one honest book at a time."
	match e:
		"heroic":
			return ["The Heart wakes, and the sun climbs over the valley for the first time in a thousand years.", "Rain follows the light. The barley stands green, and the village sings." + tail, "You walk home with the hammer on your shoulder, and the Lost Kingdom is lost no more."]
		"sacrifice":
			return ["You place both hands on the Heart. The light takes you gently, and gives itself to the sky.", "Every spring, the valley blooms where your footsteps once fell." + tail, "They say that on the longest day, a hammer rings from the ruins. The sun remembers."]
		_:
			return ["You hold the Heart and do not keep it. The light flows out through every door and every window.", "No crown, no throne: every village, every road, every child gets a share of the sun." + tail, "Suryavan is born again, and it belongs to everyone."]


func play_ending(e: String) -> void:
	story.set_flag("ending_done", true)
	story.set_flag("ending", e)
	if heart_it != null:
		heart_it.enabled = false
	var lines := ending_lines(e)
	var title: String = {"heroic": "THE HEROIC DAWN", "sacrifice": "THE SUN'S OWN", "secret": "THE SHARED LIGHT"}.get(e, "THE END")
	var heart := _o(0, 2.4, -38.0)
	var shots := [
		{"from": heart + Vector3(0, 1.5, 9), "to": heart + Vector3(0, 3.0, 4), "look": heart, "dur": 5.0, "text": lines[0], "sfx": "reveal"},
		{"from": heart + Vector3(-8, 4, 6), "to": heart + Vector3(8, 6, 6), "look": heart + Vector3(0, 1, 0), "dur": 6.0, "text": lines[1]},
		{"from": heart + Vector3(0, 10, 14), "to": heart + Vector3(0, 18, 24), "look": heart, "dur": 6.0, "title": true, "text": lines[2]},
	]
	cin.clamp_ground = false
	cin.play(shots, title, func() -> void:
		cin.clamp_ground = true
		Sfx.sting("victory", -2.0)
		show_credits(e))


func show_credits(e: String) -> void:
	story.set_flag("game_complete", true)
	var seen: Array = String(story.get_flag("endings_seen", "")).split(",", false)
	if not seen.has(e):
		seen.append(e)
	story.set_flag("endings_seen", ",".join(seen))
	var ach: Achievements = camp.main.get("achievements") as Achievements
	if ach != null:
		ach.unlock("ending")
	credits = CanvasLayer.new()
	credits.layer = 40
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.01, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits.add_child(bg)
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_left = 80
	l.offset_right = -80
	l.add_theme_font_size_override("normal_font_size", 34)
	l.add_theme_font_size_override("bold_font_size", 52)
	l.text = "[center][b]THE LOST KINGDOM[/b]\n\n%s\n\nA game by Ajay\nBuilt together with Claude\n\nAll art, sound and music are original or CC0.\n\nEndings found: %d / 3\n\nThank you for playing.[/center]" % [Loc.t("The end"), seen.size()]
	credits.add_child(l)
	var b := Button.new()
	b.text = Loc.t("Continue exploring")
	b.add_theme_font_size_override("font_size", 30)
	b.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	b.offset_left = -170
	b.offset_right = 170
	b.offset_top = -120
	b.offset_bottom = -40
	b.pressed.connect(close_credits)
	credits.add_child(b)
	add_child(credits)
	get_tree().paused = false
	player.locked = true


func close_credits() -> void:
	if credits != null:
		credits.queue_free()
		credits = null
	player.locked = false
	player.global_position = camp.gate_pos + Vector3(-3.0, 1.0, 10.0)
	player.velocity = Vector3.ZERO


# --- quest ---------------------------------------------------------------------------------

func _add_quest() -> void:
	var s := story
	camp.add_quest({
		"id": "last_sun", "title": "ACT 5: The Last Sun",
		"blurb": "Vessa is gone. Dr. Arin waits in the Solar Vault, where the Sun Heart sleeps. Decide what the light is for.",
		"show": func() -> bool: return s.get_flag("act4_done"),
		"objs": [
			{"text": func() -> String: return "Enter the Solar Vault at the Sun Gate",
			 "done": func() -> bool: return s.get_flag("v5_entered"), "target": func() -> Vector3: return camp.gate_pos + Vector3(-5, 0, 6)},
			{"text": func() -> String: return "Speak to Dr. Arin in the vault",
			 "done": func() -> bool: return s.get_flag("arin5_met"), "target": func() -> Vector3: return _o(6, 0, 30)},
			{"text": func() -> String: return "Light the sun pedestals, east to west",
			 "done": func() -> bool: return s.get_flag("pedestals_done"), "target": func() -> Vector3: return _o(0, 0, 12)},
			{"text": func() -> String: return "Defeat the Eclipse Guardian",
			 "done": func() -> bool: return s.get_flag("eclipse_down"), "target": func() -> Vector3: return _o(0, 0, -22)},
			{"text": func() -> String: return "Touch the Sun Heart and choose its fate",
			 "done": func() -> bool: return s.get_flag("ending_done"), "target": func() -> Vector3: return _o(0, 0, -38)},
		],
	})
