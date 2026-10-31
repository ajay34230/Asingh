class_name FloatText
extends RefCounted
## Floating combat text: a billboard label that rises and fades (damage numbers, warnings).

static func spawn(parent: Node, pos: Vector3, text: String, color: Color = Color.WHITE, size: float = 0.9, rise: float = 1.2, life: float = 0.8) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.pixel_size = 0.006 * size
	l.font_size = 64
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	parent.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position:y", pos.y + rise, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, life * 0.5).set_delay(life * 0.5)
	tw.chain().tween_callback(l.queue_free)
