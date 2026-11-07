## UI motion and ornament: gold filigree corners on panels, a light sweep across
## buttons, press/hover bounce, and panels that rise and fade in.
class_name UiFx
extends RefCounted

const SHINE_SHADER := """
shader_type canvas_item;
uniform float period = 7.0;
uniform float offset = 0.0;
void fragment() {
	// A soft diagonal band of light crossing the button every `period` seconds.
	float t = fract((TIME + offset) / period) * 5.0 - 0.7;   // on the button ~1/4 of the time
	float x = UV.x + (UV.y - 0.5) * 0.35;
	float band = smoothstep(0.06, 0.0, abs(x - t));
	COLOR = vec4(1.0, 0.93, 0.7, band * 0.2);
}
"""

static var _shine: Shader
static var _count := 0


## Shine sweep plus hover and press bounce on a button.
static func button(b: Button) -> void:
	if _shine == null:
		_shine = Shader.new()
		_shine.code = SHINE_SHADER
	var shine := ColorRect.new()
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = _shine
	_count += 1
	mat.set_shader_parameter("offset", _count * 0.25)   # buttons glint one after another
	shine.material = mat
	shine.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
	b.add_child(shine)
	b.clip_contents = true
	var centre := func() -> void: b.pivot_offset = b.size * 0.5
	b.resized.connect(centre)
	b.mouse_entered.connect(func() -> void:
		centre.call()
		_tween_scale(b, 1.04, 0.12))
	b.mouse_exited.connect(func() -> void: _tween_scale(b, 1.0, 0.15))
	b.button_down.connect(func() -> void:
		centre.call()
		_tween_scale(b, 0.94, 0.06))
	b.button_up.connect(func() -> void: _tween_scale(b, 1.0, 0.25, Tween.TRANS_ELASTIC))


static func _tween_scale(c: Control, to: float, seconds: float, trans := Tween.TRANS_BACK) -> void:
	if not c.is_inside_tree():
		return
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2.ONE * to, seconds).set_trans(trans).set_ease(Tween.EASE_OUT)


## Panel arrives: rises a little, scales up from 92% and fades in.
static func pop_in(c: Control, delay := 0.0) -> void:
	if not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	c.modulate.a = 0.0
	c.scale = Vector2.ONE * 0.92
	var t := c.create_tween().set_parallel(true)
	t.tween_property(c, "modulate:a", 1.0, 0.22).set_delay(delay)
	t.tween_property(c, "scale", Vector2.ONE, 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Buttons in a list arrive one after another.
static func cascade(buttons: Array, start := 0.08, step := 0.045) -> void:
	for i in range(buttons.size()):
		var b: Control = buttons[i]
		if not b.is_inside_tree():
			continue
		b.modulate.a = 0.0
		var t := b.create_tween()
		t.tween_property(b, "modulate:a", 1.0, 0.2).set_delay(start + i * step)


## Gold filigree corners drawn over a panel.
## `inset` is measured from the panel edge; the corners draw outside the content area.
static func ornaments(panel: Control, inset := 8.0) -> void:
	var o := OrnateCorners.new()
	var margin := 0.0
	var sb := panel.get_theme_stylebox("panel")
	if sb:
		margin = sb.get_margin(SIDE_LEFT)
	o.inset = inset - margin
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(o)


class OrnateCorners extends Control:
	var inset := 8.0
	var gold := Color("#e2b04f")
	var light := Color("#ffe3a0")

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var s := 46.0
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var fx := 1.0 if corner.x == 0 else -1.0
			var fy := 1.0 if corner.y == 0 else -1.0
			var o := Vector2(inset + corner.x * (size.x - 2.0 * inset), inset + corner.y * (size.y - 2.0 * inset))
			var p := func(x: float, y: float) -> Vector2: return o + Vector2(x * fx, y * fy)
			# Two nested L-shaped rules.
			draw_polyline(PackedVector2Array([p.call(0, s), p.call(0, 0), p.call(s, 0)]), gold, 3.0, true)
			draw_polyline(PackedVector2Array([p.call(7, s * 0.7), p.call(7, 7), p.call(s * 0.7, 7)]), light, 1.5, true)
			# Scroll curls at the ends.
			for end in [Vector2(s, 0), Vector2(0, s)]:
				var c: Vector2 = p.call(end.x + (4.0 if end.y == 0 else 0.0), end.y + (4.0 if end.x == 0 else 0.0))
				draw_arc(c, 5.0, 0, TAU, 16, gold, 2.0, true)
			# A gem-like dot and a small lotus bud in the corner.
			draw_circle(p.call(14, 14), 4.5, gold)
			draw_circle(p.call(14, 14), 2.2, Color("#c0182c"))
			draw_arc(p.call(14, 14), 9.0, 0, TAU, 20, light, 1.2, true)
