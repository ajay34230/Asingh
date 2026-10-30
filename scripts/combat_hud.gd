class_name CombatHUD
extends CanvasLayer
## Health bar (top centre), active power-up chips, red hit flash and the knocked-out overlay.

var player: Player
var _bar: ProgressBar
var _label: Label
var _chips: HBoxContainer
var _flash: ColorRect
var _ko: Label
var _flash_a := 0.0


func _ready() -> void:
	layer = 6
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_flash = ColorRect.new()
	_flash.color = Color(0.8, 0.05, 0.05, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.offset_left = -230
	box.offset_right = 230
	box.offset_top = 10
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(460, 30)
	_bar.show_percentage = false
	_bar.max_value = player.max_hp
	_bar.value = player.hp
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.2, 0.22)
	fill.set_corner_radius_all(6)
	_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.05, 0.05, 0.7)
	bg.set_corner_radius_all(6)
	bg.border_color = Color(0.9, 0.7, 0.3)
	bg.set_border_width_all(2)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_bar)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_label)
	_chips = HBoxContainer.new()
	_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_chips.add_theme_constant_override("separation", 10)
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_chips)
	_ko = Label.new()
	_ko.text = "YOU WERE KNOCKED OUT"
	_ko.add_theme_font_size_override("font_size", 56)
	_ko.add_theme_color_override("font_color", Color(1, 0.8, 0.7))
	_ko.add_theme_color_override("font_outline_color", Color(0.2, 0, 0))
	_ko.add_theme_constant_override("outline_size", 12)
	_ko.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ko.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ko.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ko.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ko.visible = false
	root.add_child(_ko)
	player.hp_changed.connect(_on_hp)
	player.damaged.connect(func(_a: float) -> void: _flash_a = 0.5)
	player.powerup_changed.connect(_refresh_chips)
	player.died_signal.connect(func() -> void:
		_ko.visible = true
		get_tree().create_timer(2.5).timeout.connect(func() -> void: _ko.visible = false))
	_on_hp(player.hp, player.max_hp)


func _on_hp(hp: float, mx: float) -> void:
	_bar.max_value = mx
	_bar.value = hp
	_label.text = "HEALTH  %d / %d" % [int(ceil(hp)), int(mx)]


func _refresh_chips() -> void:
	for c in _chips.get_children():
		c.queue_free()
	var names := {"speed": ["SPEED", Color(0.3, 0.7, 1.0)], "power": ["POWER x2", Color(1.0, 0.6, 0.15)], "shield": ["SHIELD", Color(1.0, 0.9, 0.35)]}
	for k in player.power:
		var l := Label.new()
		l.name = k
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", names[k][1])
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		l.add_theme_constant_override("outline_size", 6)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chips.add_child(l)


func _process(delta: float) -> void:
	_flash_a = maxf(0.0, _flash_a - delta * 1.6)
	_flash.color.a = _flash_a * 0.55 + (0.35 if player.hp < player.max_hp * 0.25 and not player.dead else 0.0) * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008))
	for c in _chips.get_children():
		if player.power.has(c.name):
			var names := {"speed": "SPEED", "power": "POWER x2", "shield": "SHIELD"}
			(c as Label).text = "%s %ds" % [names[c.name], int(ceil(player.power[c.name]))]
