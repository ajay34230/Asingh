class_name SoftDot
extends RefCounted
## A soft round white dot. Particle quads without a texture draw as hard squares (the "yellow boxes" at night,
## white boxes on sparkles); giving their material this texture makes them round and feathered.

static var _tex: GradientTexture2D


static func texture() -> GradientTexture2D:
	if _tex == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		_tex = GradientTexture2D.new()
		_tex.gradient = g
		_tex.fill = GradientTexture2D.FILL_RADIAL
		_tex.fill_from = Vector2(0.5, 0.5)
		_tex.fill_to = Vector2(1.0, 0.5)
		_tex.width = 64
		_tex.height = 64
	return _tex


static func apply(m: BaseMaterial3D) -> void:
	if m == null or m.albedo_texture != null:
		return
	m.albedo_texture = texture()
	if m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if m.emission_enabled:
		m.emission_texture = texture()
