## In-game HUD: whose turn it is, the roll and game messages, a new-game button and the result panel.
class_name Hud
extends CanvasLayer

signal new_game_pressed

const COLOR_HEX := {"red": "#e0444c", "green": "#43b861", "yellow": "#f7cd55", "blue": "#4f8ce6"}

var _turn: Label
var _message: Label
var _result: PanelContainer
var _result_list: Label


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_turn = _label(root, 18, Vector2(16, 12))
	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 22)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_message.offset_top = -56
	_message.offset_bottom = -12
	root.add_child(_message)

	var button := Button.new()
	button.text = "New game"
	button.custom_minimum_size = Vector2(150, 48)
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.position = Vector2(-166, 12)
	button.pressed.connect(func() -> void: new_game_pressed.emit())
	root.add_child(button)

	_result = PanelContainer.new()
	_result.set_anchors_preset(Control.PRESET_CENTER)
	_result.visible = false
	root.add_child(_result)
	var box := VBoxContainer.new()
	_result.add_child(box)
	var title := Label.new()
	title.text = "Game over"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	_result_list = Label.new()
	_result_list.add_theme_font_size_override("font_size", 20)
	box.add_child(_result_list)
	var again := Button.new()
	again.text = "Play again"
	again.custom_minimum_size = Vector2(200, 48)
	again.pressed.connect(func() -> void:
		_result.visible = false
		new_game_pressed.emit())
	box.add_child(again)


func _label(parent: Control, size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.position = pos
	parent.add_child(l)
	return l


func set_turn(color: String, human: bool) -> void:
	var who: String = "You" if human else color.capitalize()
	_turn.text = "Turn: %s (%s)" % [who, color.capitalize()]
	_turn.add_theme_color_override("font_color", Color(COLOR_HEX.get(color, "#ffffff")))


func set_message(text: String) -> void:
	_message.text = text


func show_result(ranking: Array) -> void:
	var lines: Array[String] = []
	for entry in ranking:
		var who: String = "You" if entry["human"] else String(entry["color"]).capitalize()
		lines.append("%d. %s" % [entry["place"], who])
	_result_list.text = "\n".join(lines)
	_result.visible = true
