## Palace garden on the side wings: photo-scanned plants (Poly Haven, CC0) in marble
## planters, with wind. Foliage gets a custom shader that keeps the scanned colour,
## normal and roughness maps, lets light glow through leaves, and sways in the wind:
## nothing at the base, most at the tips, with a quick flutter on top.
class_name Garden
extends Node3D

const PLANTS := "res://assets/models/07_Plants/"

const FOLIAGE_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform float normal_strength = 1.0;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap;
uniform int rough_channel = 1;
uniform float roughness = 1.0;
uniform float alpha_cut = 0.5;
uniform float wind_strength = 0.05;
uniform float wind_speed = 1.4;
uniform float base_y = 0.0;
uniform float height = 1.0;
uniform float phase = 0.0;

void vertex() {
	float h = clamp((VERTEX.y - base_y) / height, 0.0, 1.0);
	float t = TIME * wind_speed + phase;
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float gust = 0.6 + 0.4 * sin(t * 0.35 + root.x * 0.2);
	float sway = sin(t + root.x * 0.7 + root.z * 0.5) * 0.7 + sin(t * 2.3 + root.z * 1.3) * 0.2;
	float flutter = sin(t * 8.0 + VERTEX.x * 14.0 + VERTEX.z * 11.0) * 0.18;
	float k = wind_strength * h * h * gust;
	VERTEX.x += (sway + flutter) * k;
	VERTEX.z += (cos(t * 0.8 + root.z) * 0.45 + flutter) * k;
	VERTEX.y -= abs(sway) * k * 0.15;
}

void fragment() {
	vec4 a = texture(albedo_tex, UV) * albedo_color;
	ALBEDO = a.rgb;
	ALPHA = a.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	vec4 orm = texture(orm_tex, UV);
	ROUGHNESS = clamp((rough_channel == 0 ? orm.r : orm.g) * roughness, 0.0, 1.0);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	SPECULAR = 0.3;
	BACKLIGHT = a.rgb * 0.45;   // light shining through thin leaves and petals
}
"""

var _shader: Shader
var _planter_mats: Array[Material] = []
var _phase := 0.0


func _ready() -> void:
	_shader = Shader.new()
	_shader.code = FOLIAGE_SHADER
	var marble := RoyalBoard.pbr("marble_white", Color("#efe7da"), 0.6, 0.7, 0.3)
	var gold := RoyalBoard.metal(BoardThemes.current()["gold"], 0.26)
	var soil := RoyalBoard.pbr("granite_dark", Color("#a07050"), 1.4, 1.0, 0.0)
	_planter_mats = [marble, gold, soil]
	var top := RoyalBoard.WING_TOP
	for s in [-1.0, 1.0]:
		# Trees in tall urns at the far corners of each wing (two different pachira trees).
		_urn(Vector3(s * 10.1, top, -6.6), 0.55)
		_plant("pachira_aquatica_01", "_d", Vector3(s * 10.1, top + 0.6, -6.6), 1.8, s * 40.0)
		_urn(Vector3(s * 17.6, top, -5.9), 0.55)
		_plant("pachira_aquatica_01", "_c", Vector3(s * 17.6, top + 0.6, -5.9), 2.5, s * 120.0)
		# Potted palm beside the board, flowering anthurium on a plinth by the decoration.
		_plant("potted_plant_02", "", Vector3(s * 10.0, top, 0.0), 1.55, s * 15.0)
		_plinth(Vector3(s * 15.6, top, 0.0))
		_plant("anthurium_botany_01", "_a", Vector3(s * 15.6, top + 0.24, 0.0), 1.7, s * -30.0)
		# Long marble flower boxes along the near and far edges, densely planted.
		_flower_box(Vector3(s * 12.9, top, 7.45), 11, false)
		_flower_box(Vector3(s * 14.0, top, -7.4), 7, true, 3.2)


# --- planters ---------------------------------------------------------------------

## Tall marble urn (lathe) with a gold rim band and soil, for the trees.
func _urn(at: Vector3, r: float) -> void:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var body := Monuments.lathe(Monuments.smooth_profile(PackedVector2Array([
		Vector2(0, 0), Vector2(r * 0.7, 0), Vector2(r * 0.75, 0.05), Vector2(r * 0.55, 0.12), Vector2(r * 0.6, 0.22),
		Vector2(r * 0.95, 0.4), Vector2(r * 1.0, 0.52), Vector2(r * 0.9, 0.58), Vector2(r * 0.92, 0.62), Vector2(r * 0.84, 0.62)]), 8), 96)
	_mi(body, _planter_mats[0], root)
	_mi(Monuments.lathe(PackedVector2Array([Vector2(r * 0.97, 0.47), Vector2(r * 1.02, 0.47), Vector2(r * 1.02, 0.52), Vector2(r * 0.97, 0.52)]), 48), _planter_mats[1], root)
	_mi(Monuments.lathe(PackedVector2Array([Vector2(0, 0.6), Vector2(r * 0.84, 0.6)]), 32), _planter_mats[2], root)


func _plinth(at: Vector3) -> void:
	var p := Monuments.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.5, 0), Vector2(0.5, 0.06), Vector2(0.44, 0.08),
		Vector2(0.44, 0.2), Vector2(0.5, 0.22), Vector2(0.5, 0.24), Vector2(0, 0.24)]), 8, true, PI / 8.0)
	var root := Node3D.new()
	root.position = at
	add_child(root)
	_mi(p, _planter_mats[0], root)


## Long marble box with a gold lip and soil, densely planted with periwinkles
## (variants at random, so no two flowers match); `shrub` puts a bush in the middle.
func _flower_box(at: Vector3, count: int, shrub: bool, w := 4.8) -> void:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var d := 0.8
	_mi(RoyalBoard.bevel_box_mesh(Vector3(w, 0.32, d), 0.04), _planter_mats[0], root)
	_mi(RoyalBoard.bevel_box_mesh(Vector3(w + 0.08, 0.05, d + 0.08), 0.02), _planter_mats[1], root, Vector3(0, 0.3, 0))
	_mi(RoyalBoard.bevel_box_mesh(Vector3(w - 0.16, 0.02, d - 0.16), 0.0), _planter_mats[2], root, Vector3(0, 0.33, 0))
	var variants := [["_02_LOD0", 1.8], ["_03_LOD0", 2.3], ["_04_LOD0", 2.6]]
	for i in range(count):
		var x := lerpf(-w * 0.44, w * 0.44, float(i) / maxi(1, count - 1))
		if shrub and i == count / 2:
			_plant("shrub_02", "_b", at + Vector3(x, 0.32, 0), 0.5, randf_range(0, 360))
			continue
		var v: Array = variants[randi() % variants.size()]
		for row in [-0.18, 0.18]:
			_plant("periwinkle_plant", v[0], at + Vector3(x + randf_range(-0.12, 0.12), 0.34, row), float(v[1]) * randf_range(0.85, 1.1), randf_range(0, 360))


# --- plants -----------------------------------------------------------------------

## Places one plant. The scanned files hold several variants side by side; `variant`
## picks one by its node-name suffix ("" keeps everything) and centres it.
func _plant(model: String, variant: String, at: Vector3, scale: float, yaw: float) -> void:
	var scene := load("%s%s/%s_1k.gltf" % [PLANTS, model, model]) as PackedScene
	if scene == null:
		return
	var root := Node3D.new()
	root.position = at
	root.rotation_degrees.y = yaw
	root.scale = Vector3.ONE * scale
	add_child(root)
	var inst := scene.instantiate() as Node3D
	root.add_child(inst)
	if variant != "":
		var offset := Vector3.ZERO
		for child in inst.get_children():
			if String(child.name).ends_with(variant):
				offset = (child as Node3D).position
		for child in inst.get_children():
			if String(child.name).ends_with(variant):
				(child as Node3D).position -= Vector3(offset.x, 0, offset.z)
			else:
				child.queue_free()
	_phase += 1.7
	_apply_wind(inst, model)


## Replaces leaf and petal materials with the wind shader. Pots and bark stay still.
func _apply_wind(node: Node, model: String) -> void:
	for child in node.get_children():
		_apply_wind(child, model)
	if not (node is MeshInstance3D):
		return
	var mi := node as MeshInstance3D
	var aabb := mi.mesh.get_aabb()
	for surface in range(mi.mesh.get_surface_count()):
		var mat := mi.get_active_material(surface) as BaseMaterial3D
		if mat == null:
			continue
		var name := mat.resource_name.to_lower()
		if name.contains("pot") or name.contains("bark"):
			continue
		var sm := ShaderMaterial.new()
		sm.shader = _shader
		sm.set_shader_parameter("albedo_tex", mat.albedo_texture)
		sm.set_shader_parameter("albedo_color", mat.albedo_color)
		if mat.normal_enabled and mat.normal_texture:
			sm.set_shader_parameter("normal_tex", mat.normal_texture)
		if mat.roughness_texture:
			sm.set_shader_parameter("orm_tex", mat.roughness_texture)
			sm.set_shader_parameter("rough_channel", 0 if mat.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED else 1)
		sm.set_shader_parameter("roughness", mat.roughness)
		sm.set_shader_parameter("alpha_cut", mat.alpha_scissor_threshold if mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.35)
		sm.set_shader_parameter("base_y", aabb.position.y)
		sm.set_shader_parameter("height", maxf(aabb.size.y, 0.01))
		sm.set_shader_parameter("phase", _phase)
		## Trees sway more than low flowers; values are in the model's own units.
		var strength := 0.06 if model.begins_with("pachira") else (0.05 if model == "shrub_02" else 0.035)
		sm.set_shader_parameter("wind_strength", strength * maxf(aabb.size.y, 0.2) * 3.0)
		mi.set_surface_override_material(surface, sm)


func _mi(mesh: Mesh, mat: Material, parent: Node3D, at := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m
