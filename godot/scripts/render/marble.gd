## Builds polished marble materials from the shared marble shader.
class_name Marble
extends RefCounted

const SHADER := preload("res://shaders/marble.gdshader")
static var _warp: NoiseTexture2D
static var _grain: NoiseTexture2D


static func material(base: Color, vein: Color, vein_scale: float = 2.4) -> ShaderMaterial:
	_ensure_noise()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("base_color", Vector3(base.r, base.g, base.b))
	mat.set_shader_parameter("vein_color", Vector3(vein.r, vein.g, vein.b))
	mat.set_shader_parameter("vein_scale", vein_scale)
	mat.set_shader_parameter("warp_noise", _warp)
	mat.set_shader_parameter("grain_noise", _grain)
	return mat


static func _ensure_noise() -> void:
	if _warp != null:
		return
	var warp_field := FastNoiseLite.new()
	warp_field.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warp_field.frequency = 0.02
	warp_field.fractal_octaves = 4
	_warp = NoiseTexture2D.new()
	_warp.noise = warp_field
	_warp.seamless = true
	_warp.width = 512
	_warp.height = 512
	var grain_field := FastNoiseLite.new()
	grain_field.noise_type = FastNoiseLite.TYPE_PERLIN
	grain_field.frequency = 0.05
	_grain = NoiseTexture2D.new()
	_grain.noise = grain_field
	_grain.seamless = true
	_grain.width = 512
	_grain.height = 512
