class_name TouchControls
extends Control
## On-screen controls for phones, drawn and handled entirely in code (no image assets):
##   - left side of the screen: floating virtual joystick (move)
##   - right side of the screen: drag to look around
##   - two fingers on the right side: pinch to zoom the camera
##   - RUN button (toggle), JUMP button and (when something is in reach) USE button, bottom right
## Also draws a small FPS counter and a hint that fades out after a few seconds.
## On a PC, mouse clicks are emulated as touches (see project.godot), so it can be tested there.

var player: Player
var blocked := false            # true while a dialogue / cinematic owns the screen

var _vp := Vector2(1280, 720)
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_id := -1
var _run_id := -1
var _jump_id := -1
var _use_id := -1
var _pinch_id := -1
var _pos := {}                 # touch index -> last position (right-side fingers)
var _focus: Interactable = null
var _toast := ""
var _toast_time := 0.0
var _run_on := false
var _hint_time := 12.0
var _fps_text := ""
var _fps_timer := 0.0

const STICK_RADIUS := 95.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_layout()
	get_viewport().size_changed.connect(_refresh_layout)
	if player:
		player.focus_changed.connect(func(t: Interactable) -> void: _focus = t)
		player.message.connect(func(text: String) -> void:
			_toast = text
			_toast_time = 4.0)


func _refresh_layout() -> void:
	_vp = get_viewport().get_visible_rect().size
	queue_redraw()


func _run_button_centre() -> Vector2:
	return Vector2(_vp.x - 110.0, _vp.y - 95.0)


func _use_button_centre() -> Vector2:
	return Vector2(_vp.x - 110.0, _vp.y - 225.0)


func _jump_button_centre() -> Vector2:
	return Vector2(_vp.x - 245.0, _vp.y - 150.0)


func _process(delta: float) -> void:
	_hint_time = maxf(0.0, _hint_time - delta)
	_toast_time = maxf(0.0, _toast_time - delta)
	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.5
		_fps_text = "%d FPS" % int(Engine.get_frames_per_second())
	queue_redraw()


func _input(event: InputEvent) -> void:
	if player == null or not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event.index, event.position)
		else:
			_on_release(event.index)
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position, event.relative)


func _on_press(idx: int, pos: Vector2) -> void:
	if pos.distance_to(_run_button_centre()) < 60.0:
		_run_id = idx
		_run_on = not _run_on
		player.sprint = _run_on
		return
	if _focus != null and is_instance_valid(_focus) and pos.distance_to(_use_button_centre()) < 62.0:
		_use_id = idx
		player.interact()
		return
	if pos.distance_to(_jump_button_centre()) < 55.0:
		_jump_id = idx
		player.jump_requested = true
		return
	if pos.x < _vp.x * 0.42 and _stick_id == -1:
		_stick_id = idx
		_stick_origin = pos
		_stick_pos = pos
		return
	if pos.x >= _vp.x * 0.42:
		_pos[idx] = pos
		if _look_id == -1:
			_look_id = idx
		elif _pinch_id == -1:
			_pinch_id = idx


func _on_release(idx: int) -> void:
	if idx == _stick_id:
		_stick_id = -1
		player.move_input = Vector2.ZERO
	elif idx == _look_id:
		_look_id = -1
		_pos.erase(idx)
	elif idx == _pinch_id:
		_pinch_id = -1
		_pos.erase(idx)
	elif idx == _use_id:
		_use_id = -1
	elif idx == _run_id:
		_run_id = -1
	elif idx == _jump_id:
		_jump_id = -1


func _on_drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	if idx == _stick_id:
		_stick_pos = pos
		var d := (pos - _stick_origin) / STICK_RADIUS
		if d.length() > 1.0:
			d = d.normalized()
		# Small dead zone, then a gentle curve so slow walking is easy. Screen up means forward.
		var m := d.length()
		if m < 0.12:
			d = Vector2.ZERO
		else:
			d = d.normalized() * pow((m - 0.12) / 0.88, 1.3)
		player.move_input = Vector2(d.x, -d.y)
	elif idx == _look_id or idx == _pinch_id:
		if _look_id != -1 and _pinch_id != -1 and _pos.has(_look_id) and _pos.has(_pinch_id):
			# Two fingers: pinch to zoom, no camera rotation.
			var before: float = (_pos[_look_id] as Vector2).distance_to(_pos[_pinch_id])
			_pos[idx] = pos
			var after: float = (_pos[_look_id] as Vector2).distance_to(_pos[_pinch_id])
			player.zoom((before - after) * 0.02)
		else:
			_pos[idx] = pos
			if idx == _look_id:
				player.add_look(rel)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(16, 28), _fps_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.85))
	if _hint_time > 0.0:
		var a := clampf(_hint_time / 3.0, 0.0, 1.0)
		draw_string(font, Vector2(16, 58), "Left: move   Right: look (two fingers: zoom)   USE appears near things",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.9 * a))
	# Interaction prompt, USE button and message toast.
	if _focus != null and is_instance_valid(_focus):
		var ptxt := _focus.prompt
		var psz := font.get_string_size(ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
		var pc := Vector2(_vp.x * 0.5, _vp.y - 120.0)
		draw_rect(Rect2(pc - Vector2(psz.x * 0.5 + 16.0, 30.0), Vector2(psz.x + 32.0, 42.0)), Color(0, 0, 0, 0.45))
		draw_string(font, pc + Vector2(-psz.x * 0.5, 0.0), ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.97))
		_draw_button(font, _use_button_centre(), 50.0, "USE", _use_id != -1)
	if _toast_time > 0.0:
		var ta := clampf(_toast_time / 1.0, 0.0, 1.0)
		var tsz := font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		var tc := Vector2(_vp.x * 0.5, 80.0)
		draw_rect(Rect2(tc - Vector2(tsz.x * 0.5 + 16.0, 28.0), Vector2(tsz.x + 32.0, 40.0)), Color(0, 0, 0, 0.5 * ta))
		draw_string(font, tc + Vector2(-tsz.x * 0.5, 0.0), _toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, ta))
	# Joystick (only visible while touching).
	if _stick_id != -1:
		draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.12))
		draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.45), 3.0)
		var knob := _stick_origin + (_stick_pos - _stick_origin).limit_length(STICK_RADIUS)
		draw_circle(knob, 38.0, Color(1, 1, 1, 0.4))
	else:
		# Faint idle hint where the stick will appear.
		draw_arc(Vector2(150.0, _vp.y - 150.0), STICK_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.18), 2.0)
	_draw_button(font, _run_button_centre(), 50.0, "RUN", _run_on)
	_draw_button(font, _jump_button_centre(), 45.0, "JUMP", _jump_id != -1)


func _draw_button(font: Font, c: Vector2, r: float, label: String, active: bool) -> void:
	draw_circle(c, r, Color(1, 1, 1, 0.34 if active else 0.14))
	draw_arc(c, r, 0.0, TAU, 32, Color(1, 1, 1, 0.55), 2.5)
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	draw_string(font, c + Vector2(-size.x * 0.5, 8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.95))
