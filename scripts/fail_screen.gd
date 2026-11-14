class_name FailScreen
extends CanvasLayer
## Shown when someone dies because the rescue was stopped: the game goes back to the start of the last mission.

static var _shown: FailScreen


static func show_for(who: Node, name_text: String) -> void:
	if _shown != null and is_instance_valid(_shown):
		return
	var f := FailScreen.new()
	_shown = f
	who.get_tree().current_scene.add_child(f)
	f._build(name_text)
	who.get_tree().paused = true


func _build(name_text: String) -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.0, 0.0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.anchor_left = 0.15
	v.anchor_right = 0.85
	v.anchor_top = 0.25
	v.anchor_bottom = 0.75
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 24)
	add_child(v)
	var title := Label.new()
	title.text = Loc.t("A life was lost")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	v.add_child(title)
	var body := Label.new()
	body.text = Loc.t("%s died because the rescue was stopped.") % name_text + "\n" + Loc.t("You must start again from your last mission.")
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 30)
	v.add_child(body)
	var b := Button.new()
	b.text = Loc.t("Start from last mission")
	b.add_theme_font_size_override("font_size", 34)
	b.custom_minimum_size = Vector2(0, 90)
	b.pressed.connect(_restart)
	v.add_child(b)


func _restart() -> void:
	var m = get_tree().current_scene.get("menu")
	get_tree().paused = false
	if m != null:
		m.call("restart_mission")
	queue_free()
