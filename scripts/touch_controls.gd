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
var _attack_id := -1
var _lfire_id := -1            # the second FIRE button on the left (move, aim and shoot at once, PUBG style)
var _use_id := -1
var _pinch_id := -1
var _pos := {}                 # touch index -> last position (right-side fingers)
var _focus: Interactable = null
var _toast := ""
var _toast_time := 0.0
var _run_on := false
var _crouch_id := -1
var _block_id := -1
var _roll_id := -1
var on_exit := Callable()      # GET OFF while riding
var on_whistle := Callable()   # HORSE: whistle for your ride (returns the line to show)
var has_ride := Callable()     # true once you have ridden an animal
var left_handed := false       # mirror the layout: stick on the right, look and buttons on the left
var btn_scale := 1.0           # button size and spacing, 0.8 .. 1.4
var show_fps := true
var hints_on := true
var btn_alpha := 1.0            # button opacity multiplier
var _hint_time := 12.0
var _fps_text := ""
var _fps_timer := 0.0

const STICK_RADIUS := 95.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_layout()
	get_viewport().size_changed.connect(_refresh_layout)
	visibility_changed.connect(_reset_touches)
	if player:
		player.focus_changed.connect(func(t: Interactable) -> void: _focus = t)
		player.message.connect(func(text: String) -> void:
			_toast = text
			_toast_time = 4.0)


## Forget every finger when the controls are hidden (dialogue, cinematics) so nothing stays 'held'.
func _reset_touches() -> void:
	_stick_id = -1
	_look_id = -1
	_pinch_id = -1
	_use_id = -1
	_run_id = -1
	_jump_id = -1
	_attack_id = -1
	_lfire_id = -1
	_crouch_id = -1
	_pos.clear()
	if player != null:
		player.move_input = Vector2.ZERO
		player.release_aim()


func _refresh_layout() -> void:
	_vp = get_viewport().get_visible_rect().size
	queue_redraw()


func _corner(ox: float, oy: float) -> Vector2:
	var x := ox * btn_scale
	return Vector2(x if left_handed else _vp.x - x, _vp.y - oy * btn_scale)


func _run_button_centre() -> Vector2:
	return _lay("run", _corner(110.0, 95.0))


func _use_button_centre() -> Vector2:
	return _lay("use", _corner(110.0, 225.0))


func _attack_button_centre() -> Vector2:
	return _lay("attack", _corner(245.0, 285.0))


func _scope_button_centre() -> Vector2:
	return _lay("scope", _corner(515.0, 360.0))            # left of the main buttons, clear of the minimap


## The left FIRE button sits above the joystick area, on the other side from the main buttons.
func _lfire_button_centre() -> Vector2:
	var x := 545.0 * btn_scale              # just right of the quest panel, where PUBG puts its left fire button
	return _lay("lfire", Vector2(_vp.x - x if left_handed else x, _vp.y - 250.0 * btn_scale))


func _bow_mode() -> bool:
	return player != null and player.gear_ranged


func _jump_button_centre() -> Vector2:
	return _lay("jump", _corner(245.0, 150.0))


func _block_button_centre() -> Vector2:
	return _lay("block", _corner(380.0, 230.0))


func _roll_button_centre() -> Vector2:
	return _lay("roll", _corner(380.0, 365.0))


func _weapon_button_centre() -> Vector2:
	return _lay("weapon", _corner(515.0, 110.0))


func _horse_button_centre() -> Vector2:
	return _lay("horse", _corner(515.0, 235.0))


func _horse_visible() -> bool:
	return player != null and not player.mounted and has_ride.is_valid() and bool(has_ride.call())


func _moves_button_centre() -> Vector2:
	return _lay("moves", _corner(650.0, 110.0))


func _moves_menu() -> MovesMenu:
	return get_tree().get_first_node_in_group("moves_menu") as MovesMenu


func _crouch_button_centre() -> Vector2:
	return _lay("crouch", _corner(380.0, 95.0))


func _on_move_side(pos: Vector2) -> bool:
	return (pos.x > _vp.x * 0.58) if left_handed else (pos.x < _vp.x * 0.42)


func _on_look_side(pos: Vector2) -> bool:
	return (pos.x <= _vp.x * 0.58) if left_handed else (pos.x >= _vp.x * 0.42)


func _process(delta: float) -> void:
	_hint_time = maxf(0.0, _hint_time - delta)
	_toast_time = maxf(0.0, _toast_time - delta)
	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.5
		_fps_text = "%d FPS   v%s %s" % [int(Engine.get_frames_per_second()), BuildInfo.VERSION, BuildInfo.BUILD]
	queue_redraw()


func _input(event: InputEvent) -> void:
	if edit_mode:
		_edit_input(event)
		return
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
	var mm := _moves_menu()
	if mm != null and mm.visible:
		return                                      # the MOVES menu has the screen
	if pos.y < 90.0 and pos.x > _vp.x - 350.0:      # Map / Pause / Journal buttons live here
		return
	if mm != null and player != null and not player.mounted and pos.distance_to(_moves_button_centre()) < 46.0 * btn_scale:
		mm.toggle()
		return
	if pos.y < 330.0 and pos.x > _vp.x - 250.0:     # minimap
		return
	if player != null and player.mounted:
		if pos.distance_to(_use_button_centre()) < 62.0 * btn_scale and on_exit.is_valid():
			_use_id = idx
			on_exit.call()
			return
	else:
		if pos.distance_to(_block_button_centre()) < 56.0 * btn_scale:
			_block_id = idx
			player.set_block(true)
			return
		if pos.distance_to(_roll_button_centre()) < 56.0 * btn_scale:
			_roll_id = idx
			player.roll()
			return
	if player != null and not player.mounted and pos.distance_to(_weapon_button_centre()) < 50.0 * btn_scale:
		var w := player.cycle_weapon()
		_toast = Loc.t("Weapon: ") + Loc.t(w.capitalize())
		_toast_time = 1.6
		return
	if _horse_visible() and on_whistle.is_valid() and pos.distance_to(_horse_button_centre()) < 46.0 * btn_scale:
		var line := String(on_whistle.call())
		if line != "":
			_toast = Loc.t(line)
			_toast_time = 2.4
		return
	if player != null and not player.mounted and pos.distance_to(_crouch_button_centre()) < 56.0 * btn_scale:
		_crouch_id = idx
		player.toggle_crouch()
		return
	if pos.distance_to(_run_button_centre()) < 60.0 * btn_scale:
		_run_id = idx
		_run_on = not _run_on
		player.sprint = _run_on
		return
	if _focus != null and is_instance_valid(_focus) and pos.distance_to(_use_button_centre()) < 62.0 * btn_scale:
		_use_id = idx
		player.interact()
		return
	if pos.distance_to(_attack_button_centre()) < 60.0 * btn_scale:
		_attack_id = idx
		player.begin_aim() if player.gear_ranged else player.attack()
		return
	if pos.distance_to(_jump_button_centre()) < 55.0 * btn_scale:
		_jump_id = idx
		player.jump_requested = true
		return
	if _bow_mode() and pos.distance_to(_scope_button_centre()) < 46.0 * btn_scale:
		player.toggle_scope()
		return
	if _bow_mode() and _lfire_id == -1 and _attack_id == -1 and pos.distance_to(_lfire_button_centre()) < 52.0 * btn_scale:
		_lfire_id = idx
		player.begin_aim()
		return
	if _on_move_side(pos) and _stick_id == -1:
		_stick_id = idx
		_stick_origin = pos
		_stick_pos = pos
		return
	if _on_look_side(pos):
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
	elif idx == _attack_id:
		_attack_id = -1
		player.release_aim()
	elif idx == _lfire_id:
		_lfire_id = -1
		player.release_aim()
	elif idx == _crouch_id:
		_crouch_id = -1
	elif idx == _block_id:
		_block_id = -1
		player.set_block(false)
	elif idx == _roll_id:
		_roll_id = -1


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
	elif (idx == _attack_id or idx == _lfire_id) and _bow_mode():
		player.add_look(rel)                    # hold FIRE and slide the same finger to aim, like PUBG
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
	if edit_mode:
		_draw_edit()
		return
	var font := ThemeDB.fallback_font
	if show_fps:
		draw_string(font, Vector2(0, 104), _fps_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(1, 1, 1, 0.8))   # centred under the health bar, no background
	_draw_haze_markers()
	if hints_on and _hint_time > 0.0:
		var a := clampf(_hint_time / 3.0, 0.0, 1.0)
		draw_string(font, Vector2(16, 58), Loc.t("Left: move   Right: look (two fingers: zoom)   USE appears near things"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.9 * a))
	# Interaction prompt, USE button and message toast.
	if player != null and player.mounted:
		_draw_button(font, _use_button_centre(), 50.0 * btn_scale, "GET OFF", _use_id != -1)
	elif _focus != null and is_instance_valid(_focus):
		var ptxt := Loc.t(_focus.prompt)
		var psz := font.get_string_size(ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
		var pc := Vector2(_vp.x * 0.5, _vp.y - 120.0)
		draw_rect(Rect2(pc - Vector2(psz.x * 0.5 + 16.0, 30.0), Vector2(psz.x + 32.0, 42.0)), Color(0, 0, 0, 0.45))
		draw_string(font, pc + Vector2(-psz.x * 0.5, 0.0), ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.97))
		_draw_button(font, _use_button_centre(), 50.0 * btn_scale, "USE", _use_id != -1)
	if _toast_time > 0.0:
		var ta := clampf(_toast_time / 1.0, 0.0, 1.0)
		var toast := Loc.t(_toast)
		var tsz := font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		var tc := Vector2(_vp.x * 0.5, 80.0)
		draw_rect(Rect2(tc - Vector2(tsz.x * 0.5 + 16.0, 28.0), Vector2(tsz.x + 32.0, 40.0)), Color(0, 0, 0, 0.5 * ta))
		draw_string(font, tc + Vector2(-tsz.x * 0.5, 0.0), toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, ta))
	# Joystick (only visible while touching).
	if _stick_id != -1:
		draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.12))
		draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.45), 3.0)
		var knob := _stick_origin + (_stick_pos - _stick_origin).limit_length(STICK_RADIUS)
		draw_circle(knob, 38.0, Color(1, 1, 1, 0.4))
	else:
		# Faint idle hint where the stick will appear.
		draw_arc(Vector2(_vp.x - 150.0 if left_handed else 150.0, _vp.y - 150.0), STICK_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.18), 2.0)
	_draw_button(font, _run_button_centre(), 50.0 * btn_scale, "RUN", _run_on)
	_draw_button(font, _jump_button_centre(), 45.0 * btn_scale, "JUMP", _jump_id != -1)
	var bow := player != null and player.gear_ranged
	_draw_button(font, _attack_button_centre(), 48.0 * btn_scale, Loc.t("FIRE") if bow else "HIT", _attack_id != -1)
	if bow:
		_draw_button(font, _scope_button_centre(), 38.0 * btn_scale, "SCOPE", player.ads)
		_draw_button(font, _lfire_button_centre(), 44.0 * btn_scale, "FIRE", _lfire_id != -1)
		_draw_bow_hud(font)
	if player == null or not player.mounted:
		_draw_button(font, _crouch_button_centre(), 44.0 * btn_scale, "DUCK", player != null and player.crouching)
		_draw_button(font, _block_button_centre(), 44.0 * btn_scale, "BLOCK", _block_id != -1)
		_draw_button(font, _roll_button_centre(), 44.0 * btn_scale, "ROLL", _roll_id != -1)
		_draw_button(font, _weapon_button_centre(), 40.0 * btn_scale, player.weapon.to_upper() if player != null else "FISTS", false)
		if _moves_menu() != null:
			_draw_button(font, _moves_button_centre(), 40.0 * btn_scale, Loc.t("MOVES"), _moves_menu().visible)
		if _horse_visible():
			_draw_button(font, _horse_button_centre(), 38.0 * btn_scale, Loc.t("HORSE"), mounts_called())


## Bow: crosshair while aiming (tightens as the draw fills), the focus meter round the bow button and the
## number of fire arrows left.
func _draw_bow_hud(font: Font) -> void:
	var c := _attack_button_centre()
	var r := 56.0 * btn_scale
	draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * player.aim_focus, 40, Color(0.45, 0.85, 1.0, 0.8 * btn_alpha), 4.0)
	var it := player.get_tree().get_first_node_in_group("items")
	var fa := int(it.call("count", "fire_arrow")) if it != null else 0
	var sa := int(it.call("count", "spirit_arrow")) if it != null else 0
	if fa > 0:
		draw_string(font, c + Vector2(-34.0, r + 26.0), "%s %d" % [Loc.t("FIRE"), fa], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.6, 0.2, 0.95))
	if sa > 0:
		draw_string(font, c + Vector2(-34.0, r + (46.0 if fa > 0 else 26.0)), "%s %d" % [Loc.t("SPIRIT"), sa], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.6, 0.88, 1.0, 0.95))
	if player.aim_blend < 0.3 and not player.crosshair_aim:
		return
	var a := maxf(player.aim_blend, 0.75)
	var ctr := _vp * 0.5
	var drawing: bool = player.aiming or player._rig.move == "bow_shot"
	var draw_k := clampf(player._rig.move_t / 0.58, 0.0, 1.0) if drawing else 0.0
	var gap := lerpf(22.0 if player.ads else 30.0, 6.0, draw_k)
	var col := Color(1.0, 0.95, 0.85, 0.9 * a) if draw_k < 1.0 else Color(1.0, 0.55, 0.2, 0.95 * a)
	if player._assist != null:
		col = Color(1.0, 0.25, 0.2, 0.95)         # on target
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(ctr + d * gap, ctr + d * (gap + 16.0), Color(0, 0, 0, 0.55 * a), 6.0)
		draw_line(ctr + d * gap, ctr + d * (gap + 16.0), col, 3.0)
	draw_circle(ctr, 3.0, col)
	if player.hit_marker > 0.0:
		# hit marker: a white X, red for a headshot or a kill
		var hm := Color(1.0, 0.2, 0.15, 1.0) if (player.hit_marker_head or player.hit_marker_kill) else Color(1, 1, 1, 0.95)
		hm.a *= clampf(player.hit_marker / 0.2, 0.0, 1.0)
		var s := 9.0 + (4.0 if player.hit_marker_kill else 0.0)
		for dv in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(ctr + dv * 6.0, ctr + dv * (6.0 + s), Color(0, 0, 0, hm.a * 0.6), 5.0)
			draw_line(ctr + dv * 6.0, ctr + dv * (6.0 + s), hm, 2.5)
	if player._focusing:
		var t := Loc.t("FOCUS")
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(font, ctr + Vector2(-w * 0.5, 64.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.55, 0.9, 1.0, 0.9))


func mounts_called() -> bool:
	return on_whistle.is_valid() and on_whistle.get_object() != null and on_whistle.get_object().get("called") != null


func _draw_button(font: Font, c: Vector2, r: float, label: String, active: bool) -> void:
	var ba := btn_alpha
	draw_circle(c, r, Color(1, 1, 1, (0.34 if active else 0.14) * ba))
	draw_arc(c, r, 0.0, TAU, 32, Color(1, 1, 1, minf(1.0, 0.55 * ba)), 2.5)
	label = Loc.t(label)
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	draw_string(font, c + Vector2(-size.x * 0.5, 8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.95))


# --- button layout (BGMI-style): move or hide any button, saved in user://hud_layout.cfg -------------------

const LAYOUT_PATH := "user://hud_layout.cfg"
## id -> label shown in the editor and the button's radius there
const LAYOUT_IDS := {"run": ["RUN", 50.0], "use": ["USE", 50.0], "attack": ["HIT", 60.0], "jump": ["JUMP", 55.0],
	"block": ["BLOCK", 50.0], "roll": ["ROLL", 50.0], "crouch": ["DUCK", 50.0], "weapon": ["WEAPON", 45.0],
	"moves": ["MOVES", 45.0], "horse": ["HORSE", 45.0], "scope": ["SCOPE", 45.0], "lfire": ["FIRE (left)", 50.0]}
var layout := {}                 # id -> {"p": Vector2 (fraction of the screen), "h": hidden}
var edit_mode := false
var _edit_sel := ""
var _edit_id := -1
var _layout_loaded := false


func _lay(id: String, def: Vector2) -> Vector2:
	if not _layout_loaded:
		load_layout()
	var l: Dictionary = layout.get(id, {})
	if bool(l.get("h", false)) and not edit_mode:
		return Vector2(-10000, -10000)          # hidden: off screen, so it is neither drawn nor pressed
	if l.has("p"):
		return (l["p"] as Vector2) * _vp
	return def


func load_layout() -> void:
	_layout_loaded = true
	var c := ConfigFile.new()
	if c.load(LAYOUT_PATH) == OK:
		layout = c.get_value("hud", "layout", {})


func save_layout() -> void:
	var c := ConfigFile.new()
	c.set_value("hud", "layout", layout)
	c.save(LAYOUT_PATH)


func start_edit() -> void:
	_reset_touches()
	edit_mode = true
	_edit_sel = ""
	queue_redraw()


func _centre_of(id: String) -> Vector2:
	return call("_%s_button_centre" % id)


func _edit_bar() -> Array:
	var w := 200.0
	var x0 := _vp.x * 0.5 - w * 1.5 - 20.0
	return [["hide", Rect2(x0, 12, w, 56)], ["reset", Rect2(x0 + w + 20.0, 12, w, 56)], ["done", Rect2(x0 + (w + 20.0) * 2.0, 12, w, 56)]]


func _edit_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		if event.pressed:
			for b in _edit_bar():
				if (b[1] as Rect2).has_point(pos):
					match b[0]:
						"hide":
							if _edit_sel != "":
								var l: Dictionary = layout.get(_edit_sel, {})
								l["h"] = not bool(l.get("h", false))
								layout[_edit_sel] = l
						"reset":
							layout = {}
						"done":
							save_layout()
							edit_mode = false
							_edit_sel = ""
					queue_redraw()
					return
			var best := ""
			var bd := 90.0 * btn_scale
			for id in LAYOUT_IDS:
				var d := pos.distance_to(_centre_of(id))
				if d < bd:
					bd = d
					best = id
			_edit_sel = best
			_edit_id = event.index if best != "" else -1
		elif event.index == _edit_id:
			_edit_id = -1
		queue_redraw()
	elif event is InputEventScreenDrag and event.index == _edit_id and _edit_sel != "":
		var l2: Dictionary = layout.get(_edit_sel, {})
		var p: Vector2 = (event.position as Vector2).clamp(Vector2(40, 90), _vp - Vector2(40, 40))
		l2["p"] = p / _vp
		layout[_edit_sel] = l2
		queue_redraw()


func _draw_edit() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, _vp), Color(0, 0, 0, 0.45))
	draw_string(font, Vector2(0, 100), Loc.t("Drag a button to move it. Tap one, then HIDE/SHOW."), HORIZONTAL_ALIGNMENT_CENTER, _vp.x, 22, Color(1, 1, 1, 0.9))
	for id in LAYOUT_IDS:
		var hid := bool((layout.get(id, {}) as Dictionary).get("h", false))
		var lbl: String = LAYOUT_IDS[id][0] + (" (hidden)" if hid else "")
		var c := _centre_of(id)
		_draw_button(font, c, float(LAYOUT_IDS[id][1]) * btn_scale, lbl, id == _edit_sel)
		if hid:
			draw_line(c - Vector2(30, 30), c + Vector2(30, 30), Color(1, 0.3, 0.3, 0.9), 4.0)
	for b in _edit_bar():
		var r: Rect2 = b[1]
		draw_rect(r, Color(0.15, 0.12, 0.08, 0.92))
		draw_rect(r, Color(1, 0.85, 0.4), false, 2.0)
		var t := {"hide": "HIDE / SHOW", "reset": "RESET", "done": "DONE"}[b[0]] as String
		draw_string(font, Vector2(r.position.x, r.position.y + 38), Loc.t(t), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, Color.WHITE)


## While the low-FPS dust haze hides the far view, mission enemies (all enemies) within 100 m that are past it
## get a red marker, so missions stay fair.
func _draw_haze_markers() -> void:
	var m := get_tree().current_scene
	var dg = m.get("diag") if m != null else null
	if dg == null or not bool(dg.get("haze_on")) or player == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead:
			continue
		var d := en.global_position.distance_to(player.global_position)
		if d < Diag.HAZE_VIEW - 10.0 or d > 100.0:
			continue
		var wp := en.global_position + Vector3(0, 2.2, 0)
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		draw_colored_polygon(PackedVector2Array([sp + Vector2(-10, -16), sp + Vector2(10, -16), sp]), Color(1, 0.15, 0.1, 0.9))
