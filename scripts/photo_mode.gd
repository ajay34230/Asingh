class_name PhotoMode
extends CanvasLayer
## X20 + photo studio: hides the HUD and controls so you can frame a shot.
##   - drag anywhere to swing the camera round the hero, pinch (or mouse wheel) to zoom
##   - SELFIE turns the camera to face the hero
##   - POSE cycles hero poses: stand, fighter, archer (bow drawn), kick, punch, pray, victory
##   - FILTER cycles colour looks: none, warm, cool, sepia, black and white, vivid
##   - TIME cycles the light: as it was, sunrise, noon, sunset, night
##   - PHOTO saves a PNG: the phone's Pictures folder if the game may write there, else Downloads, else
##     the game's own folder. Everything is put back as it was on exit.

const POSES := ["Stand", "Fighter", "Archer", "Kick", "Punch", "Pray", "Victory"]
const FILTERS := ["None", "Warm", "Cool", "Sepia", "Black & white", "Vivid"]
const TIMES := [["As it was", -1.0], ["Sunrise", 0.27], ["Noon", 0.5], ["Sunset", 0.71], ["Night", 0.9]]
const VICTORY := {"sh_R": Vector3(-2.9, 0.0, 0.25), "el_R": Vector3(0.25, 0, 0), "sh_L": Vector3(-0.3, 0.0, 0.15),
	"el_L": Vector3(0.45, 0, 0), "head": Vector3(-0.22, 0, 0), "spine": Vector3(0.06, 0, 0)}

var hide_nodes: Array = []
var player: Player
var atmo: Atmosphere
var panel: HBoxContainer
var active := false
var saved := 0
var last_path := ""
var pose := 0
var filter := 0
var time_i := 0
var _filter_rect: ColorRect
var _filter_mat: ShaderMaterial
var _hint: Label
var _btns := {}
var _touch := {}                 # finger index -> position
var _saved_tod := 0.0
var _saved_dist := 6.0
var _saved_weapon := ""
var _was_locked := false
var _hidden: Array = []


func _ready() -> void:
	layer = 30
	_filter_rect = ColorRect.new()
	_filter_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_filter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filter_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform int mode = 0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	if (mode == 1) { c = c * vec3(1.08, 1.0, 0.84) + vec3(0.03, 0.012, 0.0); }
	else if (mode == 2) { c = c * vec3(0.88, 0.98, 1.12); }
	else if (mode == 3) { c = vec3(l) * vec3(1.08, 0.92, 0.7); }
	else if (mode == 4) { c = vec3(l); c = (c - 0.5) * 1.15 + 0.5; }
	else if (mode == 5) { c = mix(vec3(l), c, 1.5); }
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - dot(d, d) * 0.8;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
"""
	_filter_mat.shader = sh
	_filter_rect.material = _filter_mat
	_filter_rect.visible = false
	add_child(_filter_rect)
	panel = HBoxContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -100.0
	panel.offset_bottom = -20.0
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 14)
	panel.visible = false
	add_child(panel)
	for spec in [["photo", "PHOTO", func() -> void: capture()], ["pose", "", next_pose], ["filter", "", next_filter],
			["time", "", next_time], ["selfie", "SELFIE", selfie], ["exit", "EXIT", exit]]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(150 if spec[0] != "photo" else 180, 72)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(spec[2])
		b.focus_mode = Control.FOCUS_NONE
		panel.add_child(b)
		_btns[spec[0]] = [b, spec[1]]
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.position = Vector2(-400, 20)
	_hint.size = Vector2(800, 40)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.visible = false
	add_child(_hint)
	_relabel()


func _relabel() -> void:
	(_btns["photo"][0] as Button).text = Loc.t("PHOTO")
	(_btns["pose"][0] as Button).text = Loc.t("Pose") + ": " + Loc.t(POSES[pose])
	(_btns["filter"][0] as Button).text = Loc.t("Filter") + ": " + Loc.t(FILTERS[filter])
	(_btns["time"][0] as Button).text = Loc.t("Light") + ": " + Loc.t(String(TIMES[time_i][0]))
	(_btns["selfie"][0] as Button).text = Loc.t("SELFIE")
	(_btns["exit"][0] as Button).text = Loc.t("EXIT")
	_hint.text = Loc.t("Drag to move the camera, pinch to zoom")


func enter() -> void:
	active = true
	# every on-screen layer goes: controls, HUD, coins, minimap, area titles (only the photo bar stays)
	var all: Array = hide_nodes.duplicate()
	for cl in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if cl != self and not all.has(cl):
			all.append(cl)
	_hidden = []
	for n in all:
		if n == null or not is_instance_valid(n):
			continue
		n.set_meta("pm_was", n.get("visible"))
		n.set("visible", false)
		_hidden.append(n)
	if player != null:
		_was_locked = player.locked
		player.locked = true
		player.move_input = Vector2.ZERO
		_saved_dist = player._target_distance
		_saved_weapon = player.weapon
	if atmo != null:
		_saved_tod = atmo.time_of_day
	pose = 0
	filter = 0
	time_i = 0
	_apply_filter()
	_relabel()
	panel.visible = true
	_hint.visible = true


func exit() -> void:
	active = false
	for n in _hidden:
		if n != null and is_instance_valid(n):
			n.set("visible", bool(n.get_meta("pm_was", true)))
	_hidden = []
	panel.visible = false
	_hint.visible = false
	_filter_rect.visible = false
	_touch.clear()
	if player != null:
		_clear_pose()
		player.locked = _was_locked
		player.set_distance(_saved_dist)
	if atmo != null and time_i != 0:
		atmo.time_of_day = _saved_tod
		atmo.apply_time()


# --- poses ---------------------------------------------------------------------------------------

func _clear_pose() -> void:
	var rig := player._rig
	rig.photo_pose = {}
	rig.hold_draw = false
	rig.move_hold = -1.0
	rig.move = ""
	rig.action = ""
	if rig.weapon != _saved_weapon:
		rig.set_weapon(_saved_weapon)


func next_pose() -> void:
	set_pose((pose + 1) % POSES.size())


func set_pose(i: int) -> void:
	pose = i
	if player == null:
		return
	_clear_pose()
	var rig := player._rig
	match POSES[i]:
		"Fighter":
			rig.photo_pose = RealHuman.GUARD.duplicate()
		"Archer":
			rig.set_weapon("bow")
			rig.play_move("bow_shot")
			rig.hold_draw = true
		"Kick":
			rig.play_move("kick_front")
			rig.move_hold = 0.3
		"Punch":
			rig.play_move("cross")
			rig.move_hold = 0.16
		"Pray":
			rig.play_action("pray", 100000.0)
		"Victory":
			rig.photo_pose = VICTORY.duplicate()
	_relabel()


# --- filters and light ---------------------------------------------------------------------------

func next_filter() -> void:
	filter = (filter + 1) % FILTERS.size()
	_apply_filter()
	_relabel()


func _apply_filter() -> void:
	_filter_rect.visible = filter != 0
	_filter_mat.set_shader_parameter("mode", filter)


func next_time() -> void:
	time_i = (time_i + 1) % TIMES.size()
	if atmo != null:
		var t := float(TIMES[time_i][1])
		atmo.time_of_day = _saved_tod if t < 0.0 else t
		atmo.apply_time()
	_relabel()


func selfie() -> void:
	if player == null:
		return
	player.set_look(player._model.rotation.y + PI, -0.08)
	player.set_distance(2.4)


# --- camera by touch -------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not active or player == null:
		return
	var on_panel := func(p: Vector2) -> bool: return panel.get_global_rect().has_point(p)
	if event is InputEventScreenTouch:
		if event.pressed and not on_panel.call(event.position):
			_touch[event.index] = event.position
		else:
			_touch.erase(event.index)
	elif event is InputEventScreenDrag and _touch.has(event.index):
		if _touch.size() >= 2:
			var keys := _touch.keys()
			var a: Vector2 = _touch[keys[0]]
			var b: Vector2 = _touch[keys[1]]
			var before := a.distance_to(b)
			_touch[event.index] = event.position
			a = _touch[keys[0]]
			b = _touch[keys[1]]
			player.zoom((before - a.distance_to(b)) * 0.02)
		else:
			_touch[event.index] = event.position
			player.add_look(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			player.zoom(-0.4)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			player.zoom(0.4)


# --- saving --------------------------------------------------------------------------------------

func capture() -> String:
	panel.visible = false
	_hint.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var name_ := "lostkingdom_%s.png" % Time.get_datetime_string_from_system(false, false).replace(":", "-")
	var path := ""
	for d in [OS.get_system_dir(OS.SYSTEM_DIR_PICTURES), OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS), ProjectSettings.globalize_path("user://photos")]:
		if String(d) == "":
			continue
		DirAccess.make_dir_recursive_absolute(String(d))
		var p := String(d).path_join(name_)
		if img.save_png(p) == OK and FileAccess.file_exists(p):
			path = p
			break
	panel.visible = active
	_hint.visible = active
	if path != "":
		saved += 1
		last_path = path
		Sfx.ui("tink", -4.0)
		_hint.text = Loc.t("Photo saved: ") + path.get_base_dir().get_file() + "/" + path.get_file()
	return path
