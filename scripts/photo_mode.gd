class_name PhotoMode
extends CanvasLayer
## X20: hides the HUD and controls so you can frame the scenery, then saves a PNG to user://photos.

var hide_nodes: Array = []
var panel: HBoxContainer
var active := false
var saved := 0


func _ready() -> void:
	layer = 30
	panel = HBoxContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -110.0
	panel.offset_bottom = -30.0
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 40)
	panel.visible = false
	add_child(panel)
	for spec in [["Take photo", capture], ["Exit photo mode", exit]]:
		var b := Button.new()
		b.text = Loc.t(String(spec[0]))
		b.custom_minimum_size = Vector2(280, 80)
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(spec[1])
		panel.add_child(b)


func enter() -> void:
	active = true
	for n in hide_nodes:
		if n == null:
			continue
		n.set_meta("pm_was", n.get("visible"))
		n.set("visible", false)
	panel.visible = true


func exit() -> void:
	active = false
	for n in hide_nodes:
		if n != null:
			n.set("visible", bool(n.get_meta("pm_was", true)))
	panel.visible = false


func capture() -> String:
	panel.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://photos")
	var path := "user://photos/photo_%d.png" % Time.get_unix_time_from_system()
	var ok := img.save_png(path) == OK
	panel.visible = active
	if ok:
		saved += 1
	return path if ok else ""
