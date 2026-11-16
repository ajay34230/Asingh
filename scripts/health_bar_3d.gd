class_name HealthBar3D
extends Label3D
## One small bar over an enemy, monster or ghost: green when full, yellow at half, red when low. No text.
## It is a Label3D so existing code (visible, position, modulate, visibility range) keeps working; the bar
## itself is two camera-facing quads drawn on top of everything, shown only within 20 m.

const W := 0.6
const H := 0.06
var _fq: QuadMesh
var _fmat: StandardMaterial3D


func _quad(col: Color, prio: int, size: Vector2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.render_priority = prio
	m.albedo_color = col
	mi.material_override = m
	mi.visibility_range_end = 20.0
	mi.visibility_range_end_margin = 2.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## r = health fraction 0..1
func set_health(r: float) -> void:
	text = ""
	if _fq == null:
		_quad(Color(0, 0, 0, 0.6), 10, Vector2(W + 0.03, H + 0.03))
		var f := _quad(Color.GREEN, 11, Vector2(W, H))
		_fq = f.mesh as QuadMesh
		_fmat = f.material_override as StandardMaterial3D
	r = clampf(r, 0.0, 1.0)
	_fq.size = Vector2(maxf(W * r, 0.001), H)
	_fq.center_offset = Vector3(-W * (1.0 - r) * 0.5, 0, 0)       # shrinks from the right
	var c := Color(1.0, 0.85, 0.1).lerp(Color(0.2, 0.9, 0.25), (r - 0.5) * 2.0) if r >= 0.5 \
			else Color(0.95, 0.15, 0.1).lerp(Color(1.0, 0.85, 0.1), r * 2.0)
	_fmat.albedo_color = Color(c, 0.95)
