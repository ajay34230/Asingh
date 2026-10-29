class_name GameMenu
extends CanvasLayer
## Pause button + menu (resume, volume, graphics quality, new game, quit) and save/load.
## Save file: user://save.json holds story flags and the player position. Autosaves on every
## story change and every 20 s. Works offline, on-device only.

const SAVE_PATH := "user://save.json"

var story: Story
var player: Player
var main: Node3D
var _btn: Button
var _panel: PanelContainer
var _timer := 0.0
var _vol: HSlider
var _quality: OptionButton
var _sens: HSlider
var _fov: HSlider
var _invert: CheckButton
var _fp: CheckButton


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_btn = Button.new()
	_btn.text = "II"
	_btn.add_theme_font_size_override("font_size", 28)
	_btn.anchor_left = 1.0
	_btn.anchor_right = 1.0
	_btn.offset_left = -250
	_btn.offset_right = -184
	_btn.offset_top = 14
	_btn.offset_bottom = 76
	_btn.pressed.connect(toggle)
	root.add_child(_btn)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, 0.96)
	sb.border_color = Color(0.85, 0.65, 0.28)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.anchor_left = 0.25
	_panel.anchor_right = 0.75
	_panel.anchor_top = 0.08
	_panel.anchor_bottom = 0.92
	_panel.visible = false
	root.add_child(_panel)
	var sc := ScrollContainer.new()
	_panel.add_child(sc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	var h := Label.new()
	h.text = "PAUSED"
	h.add_theme_font_size_override("font_size", 40)
	h.add_theme_color_override("font_color", Color(0.95, 0.74, 0.32))
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(h)
	vb.add_child(_button("Resume", toggle))
	var vl := Label.new()
	vl.text = "Volume"
	vl.add_theme_font_size_override("font_size", 26)
	vb.add_child(vl)
	_vol = HSlider.new()
	_vol.min_value = 0.0
	_vol.max_value = 1.0
	_vol.step = 0.05
	_vol.value = 1.0
	_vol.custom_minimum_size = Vector2(0, 44)
	_vol.value_changed.connect(_set_volume)
	vb.add_child(_vol)
	var ql := Label.new()
	ql.text = "Graphics (lower = faster)"
	ql.add_theme_font_size_override("font_size", 26)
	vb.add_child(ql)
	_quality = OptionButton.new()
	_quality.add_theme_font_size_override("font_size", 26)
	_quality.custom_minimum_size = Vector2(0, 56)
	_quality.add_item("High", 0)
	_quality.add_item("Medium", 1)
	_quality.add_item("Low", 2)
	_quality.item_selected.connect(_set_quality)
	vb.add_child(_quality)
	vb.add_child(_label("Look speed"))
	_sens = _slider(0.4, 2.5, 1.0, func(v: float) -> void:
		player.look_sens = v
		_save_settings())
	vb.add_child(_sens)
	vb.add_child(_label("Field of view"))
	_fov = _slider(60.0, 95.0, 70.0, func(v: float) -> void:
		player.base_fov = v
		_save_settings())
	vb.add_child(_fov)
	_invert = CheckButton.new()
	_invert.text = "Invert look up/down"
	_invert.add_theme_font_size_override("font_size", 26)
	_invert.toggled.connect(func(on: bool) -> void:
		player.invert_y = on
		_save_settings())
	vb.add_child(_invert)
	_fp = CheckButton.new()
	_fp.text = "First-person view"
	_fp.add_theme_font_size_override("font_size", 26)
	_fp.toggled.connect(func(on: bool) -> void:
		player.set_first_person(on)
		_save_settings())
	vb.add_child(_fp)
	vb.add_child(_button("New game (erase save)", _new_game))
	vb.add_child(_button("Quit", func() -> void:
		save()
		get_tree().quit()))
	_load_settings()
	story.changed.connect(save)


func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 26)
	return l


func _slider(lo: float, hi: float, v: float, fn: Callable) -> HSlider:
	var h := HSlider.new()
	h.min_value = lo
	h.max_value = hi
	h.step = (hi - lo) / 40.0
	h.value = v
	h.custom_minimum_size = Vector2(0, 44)
	h.value_changed.connect(fn)
	return h


func _button(t: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 62)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(fn)
	return b


func toggle() -> void:
	var on := not _panel.visible
	_panel.visible = on
	get_tree().paused = on
	if on:
		save()


func _set_volume(v: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
	_save_settings()


func _set_quality(i: int) -> void:
	var scale: float = [1.0, 0.8, 0.62][i]
	get_viewport().scaling_3d_scale = scale
	_save_settings()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("s", "volume", _vol.value)
	cfg.set_value("s", "quality", _quality.selected)
	cfg.set_value("s", "sens", _sens.value)
	cfg.set_value("s", "fov", _fov.value)
	cfg.set_value("s", "invert", _invert.button_pressed)
	cfg.set_value("s", "fp", _fp.button_pressed)
	cfg.save("user://settings.cfg")


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return
	_vol.set_value_no_signal(cfg.get_value("s", "volume", 1.0))
	_set_volume(_vol.value)
	var q: int = cfg.get_value("s", "quality", 0)
	_quality.select(q)
	_set_quality(q)
	_sens.set_value_no_signal(cfg.get_value("s", "sens", 1.0))
	player.look_sens = _sens.value
	_fov.set_value_no_signal(cfg.get_value("s", "fov", 70.0))
	player.base_fov = _fov.value
	_invert.set_pressed_no_signal(cfg.get_value("s", "invert", false))
	player.invert_y = _invert.button_pressed
	_fp.set_pressed_no_signal(cfg.get_value("s", "fp", false))
	player.set_first_person(_fp.button_pressed)


func _process(delta: float) -> void:
	_timer += delta
	if _timer > 20.0:
		_timer = 0.0
		save()


func save() -> void:
	if player == null or story == null or not story.get_flag("intro_done"):
		return
	var p := player.global_position
	var d := {"flags": story.flags, "pos": [p.x, p.y, p.z], "yaw": player.look_yaw(), "tod": main.atmosphere.time_of_day}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Returns true if a save was applied.
func load_save() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary) or not d.has("flags") or not d.has("pos"):
		return false
	for k in d["flags"]:
		story.flags[k] = d["flags"][k]
	var p: Array = d["pos"]
	player.global_position = Vector3(p[0], p[1] + 0.3, p[2])
	player.velocity = Vector3.ZERO
	player.set_look(float(d.get("yaw", 0.0)), -0.05)
	main.atmosphere.time_of_day = float(d.get("tod", 0.33))
	main.atmosphere.apply_time()
	story.changed.emit()
	return true


func _new_game() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().paused = false
	get_tree().reload_current_scene()
