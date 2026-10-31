class_name Footprints
extends Node3D
## Footprints and hoof prints pressed into the sand. A ring buffer of 150 flat quads (one MultiMesh);
## each print fades over about 90 s, and much faster while it rains.

const MAX := 150
const LIFE := 90.0

var terrain: TerrainBuilder
var player: Player
var atmo: Atmosphere
var _mm: MultiMesh
var _age := PackedFloat32Array()
var _next := 0
var _left := true
var _t := 0.0
var count_made := 0


func _init(t: TerrainBuilder, p: Player, a: Atmosphere) -> void:
	terrain = t
	player = p
	atmo = a
	name = "Footprints"


func build(parent: Node3D) -> void:
	parent.add_child(self)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.34)
	q.orientation = PlaneMesh.FACE_Y
	_mm.mesh = q
	_mm.instance_count = MAX
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.22, 0.16, 0.10, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4000.0
	add_child(mi)
	_age.resize(MAX)
	for i in MAX:
		_age[i] = LIFE
		_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0, -500, 0)))
		_mm.set_instance_color(i, Color(1, 1, 1, 0))
	player.stepped.connect(_on_step)


func _on_step(run: bool) -> void:
	if player == null or not player.is_on_floor() or player.mounted:
		return
	var gy := terrain.sample_height(player.global_position.x, player.global_position.z)
	if player.global_position.y - gy > 0.5:        # on a roof, stairs or indoors: no prints
		return
	var yaw := player._model.rotation.y
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	_left = not _left
	var side := -1.0 if _left else 1.0
	var pos := player.global_position + right * side * 0.13
	put(pos, yaw, 1.25 if run else 1.0)


## Press a print at `pos` (ground height is sampled here). `size` scales the quad (hooves use ~1.2).
func put(pos: Vector3, yaw: float, size: float = 1.0) -> void:
	var y := terrain.sample_height(pos.x, pos.z) + 0.035
	var b := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(size, 1.0, size))
	_mm.set_instance_transform(_next, Transform3D(b, Vector3(pos.x, y, pos.z)))
	_mm.set_instance_color(_next, Color(1, 1, 1, 0.55))
	_age[_next] = 0.0
	_next = (_next + 1) % MAX
	count_made += 1


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.4:
		return
	var dt := _t
	_t = 0.0
	var wet := 1.0 + (atmo.rain * 6.0 if atmo != null else 0.0)       # rain smooths the sand quickly
	for i in MAX:
		if _age[i] >= LIFE:
			continue
		_age[i] += dt * wet
		var a := 0.55 * clampf(1.0 - _age[i] / LIFE, 0.0, 1.0)
		_mm.set_instance_color(i, Color(1, 1, 1, a))
