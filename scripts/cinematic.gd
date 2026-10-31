class_name Cinematic
extends CanvasLayer
## Letterboxed camera sequences with subtitles and a Skip button.
## shots: [{from, to, look, look_to (optional), dur, text, fov}] ; on_done is called at the end.

var cam: Camera3D
var player: Player
var touch: Control
var terrain: TerrainBuilder  # optional; keeps story shots above the ground
const MIN_CLEARANCE := 1.4
var clamp_ground := true      # off for scenes inside the off-map halls
var playing := false
var _shots: Array = []
var _i := -1
var _t := 0.0
var _on_done := Callable()
var _top: ColorRect
var _bot: ColorRect
var _sub: Label
var _title: Label
var _skip: Button
var _fade: ColorRect


func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_top = ColorRect.new()
	_top.color = Color.BLACK
	_top.anchor_right = 1.0
	_top.offset_bottom = 90
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_top)
	_bot = ColorRect.new()
	_bot.color = Color.BLACK
	_bot.anchor_right = 1.0
	_bot.anchor_top = 1.0
	_bot.anchor_bottom = 1.0
	_bot.offset_top = -150
	_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bot)
	_sub = Label.new()
	_sub.add_theme_font_size_override("font_size", 32)
	_sub.add_theme_color_override("font_color", Color(1, 0.95, 0.82))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	_sub.anchor_right = 1.0
	_sub.anchor_top = 1.0
	_sub.anchor_bottom = 1.0
	_sub.offset_top = -148
	_sub.offset_bottom = -4
	_sub.offset_left = 60
	_sub.offset_right = -60
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_sub)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 78)
	_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	_title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	_title.add_theme_constant_override("outline_size", 14)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.modulate.a = 0.0
	root.add_child(_title)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	root.add_child(_fade)
	_skip = Button.new()
	_skip.text = "Skip"
	_skip.add_theme_font_size_override("font_size", 26)
	_skip.anchor_left = 1.0
	_skip.anchor_right = 1.0
	_skip.offset_left = -170
	_skip.offset_right = -20
	_skip.offset_top = 100
	_skip.offset_bottom = 164
	_skip.pressed.connect(finish)
	root.add_child(_skip)
	cam = Camera3D.new()
	cam.name = "CineCamera"
	add_child(cam)
	visible = false


func play(shots: Array, title: String, on_done: Callable) -> void:
	_shots = shots
	_on_done = on_done
	_i = -1
	playing = true
	visible = true
	player.locked = true
	if touch != null:
		touch.visible = false
	_title.text = title
	_next()


func _next() -> void:
	_i += 1
	_t = 0.0
	if _i >= _shots.size():
		finish()
		return
	var s: Dictionary = _shots[_i]
	var who: String = s.get("who", "")
	var shown: String = Loc.t(str(s.get("text", "")))
	_sub.text = (Loc.name_of(who) + ":  " if who != "" else "") + shown
	if who != "" and s.has("text"):
		s["dur"] = maxf(float(s.get("dur", 3.0)), 1.2 + shown.length() * (0.075 if Loc.hindi() else 0.062))
		Sfx.speak(s.get("voice", "man"), shown, null, 0.0, true, who)
	cam.fov = s.get("fov", 62.0)
	cam.make_current()
	_place(0.0)
	if s.has("sfx"):
		Sfx.ui(s["sfx"], -2.0)


func _above_ground(p: Vector3, clearance: float = MIN_CLEARANCE) -> Vector3:
	if terrain != null and clamp_ground:
		var gy: float = terrain.sample_height(p.x, p.z)
		p.y = maxf(p.y, gy + clearance)
	return p


func _place(k: float) -> void:
	var s: Dictionary = _shots[_i]
	var e := k * k * (3.0 - 2.0 * k)
	var from: Vector3 = s["from"]
	var to: Vector3 = s.get("to", from)
	var look: Vector3 = s["look"]
	var look_to: Vector3 = s.get("look_to", look)
	cam.global_position = _above_ground(from.lerp(to, e))
	var tgt := _above_ground(look.lerp(look_to, e), 0.2)
	if (tgt - cam.global_position).length() > 0.01:
		cam.look_at(tgt, Vector3.UP)


func _process(delta: float) -> void:
	if not playing:
		return
	var s: Dictionary = _shots[_i]
	var dur: float = s["dur"]
	_t += delta
	_place(clampf(_t / dur, 0.0, 1.0))
	if s.get("title", false):
		_title.modulate.a = clampf(minf(_t, dur - _t) * 1.2, 0.0, 1.0)
	else:
		_title.modulate.a = 0.0
	var f := 0.0
	if _i == 0:
		f = clampf(1.0 - _t * 0.8, 0.0, 1.0)
	if _i == _shots.size() - 1:
		f = maxf(f, clampf((_t - (dur - 1.2)) / 1.2, 0.0, 1.0))
	_fade.modulate.a = f
	if _t >= dur:
		_next()


func finish() -> void:
	if not playing:
		return
	Sfx.stop_speech()
	playing = false
	visible = false
	_fade.modulate.a = 0.0
	player.camera.make_current()
	player.locked = false
	if touch != null:
		touch.visible = true
	if _on_done.is_valid():
		_on_done.call()
