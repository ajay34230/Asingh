class_name TouchControls
extends Control
## On-screen controls for phones, drawn and handled entirely in code (no image assets):
##   - left side of the screen: floating virtual joystick (move)
##   - right side of the screen: drag to look around
##   - RUN button (toggle) and JUMP button, bottom right
## Also draws a small FPS counter and a hint that fades out after a few seconds.
## On a PC, mouse clicks are emulated as touches (see project.godot), so it can be tested there.

var player: Player

var _vp := Vector2(1280, 720)
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_id := -1
var _run_id := -1
var _jump_id := -1
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


func _refresh_layout() -> void:
	_vp = get_viewport().get_visible_rect().size
	queue_redraw()


func _run_button_centre() -> Vector2:
	return Vector2(_vp.x - 110.0, _vp.y - 95.0)


func _jump_button_centre() -> Vector2:
	return Vector2(_vp.x - 245.0, _vp.y - 150.0)


func _process(delta: float) -> void:
	_hint_time = maxf(0.0, _hint_time - delta)
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
	if pos.distance_to(_jump_button_centre()) < 55.0:
		_jump_id = idx
		player.jump_requested = true
		return
	if pos.x < _vp.x * 0.42 and _stick_id == -1:
		_stick_id = idx
		_stick_origin = pos
		_stick_pos = pos
		return
	if pos.x >= _vp.x * 0.42 and _look_id == -1:
		_look_id = idx


func _on_release(idx: int) -> void:
	if idx == _stick_id:
		_stick_id = -1
		player.move_input = Vector2.ZERO
	elif idx == _look_id:
		_look_id = -1
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
		# Screen up means forward.
		player.move_input = Vector2(d.x, -d.y)
	elif idx == _look_id:
		player.add_look(rel)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(16, 28), _fps_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.85))
	if _hint_time > 0.0:
		var a := clampf(_hint_time / 3.0, 0.0, 1.0)
		draw_string(font, Vector2(16, 58), "Left side: move   Right side: look   RUN toggles speed",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.9 * a))
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
