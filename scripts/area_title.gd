class_name AreaTitle
extends CanvasLayer
## X5: a short cinematic place-name card ("The Musafir Bazaar") when the player enters a new zone.

const NAMES := {
	"town": "The Bazaar of Surya",
	"forest": "The Whispering Forest",
	"pond": "The Mirror Pond",
	"river": "The River Road",
	"ruins": "The Sunken Ruins",
	"desert": "The Golden Dunes",
}

var sfx: Sfx
var label: Label
var shown := ""
var shown_count := 0
var _check := 0.0
var _cool := 0.0


func _ready() -> void:
	layer = 20
	label = Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.offset_top = 90.0
	label.offset_bottom = 150.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02, 0.9))
	label.add_theme_constant_override("outline_size", 8)
	label.modulate.a = 0.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _process(delta: float) -> void:
	_cool -= delta
	_check -= delta
	if _check > 0.0 or sfx == null:
		return
	_check = 1.0
	var z: String = sfx.zone
	if z != shown and _cool <= 0.0:
		show_zone(z)


func show_zone(z: String) -> void:
	shown = z
	shown_count += 1
	_cool = 12.0
	label.text = Loc.t(String(NAMES.get(z, "The Lost Kingdom")))
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.8)
	tw.tween_interval(2.4)
	tw.tween_property(label, "modulate:a", 0.0, 1.4)
