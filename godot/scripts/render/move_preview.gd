## Shows where each legal token would go: small glowing dots on the squares it crosses
## and a pulsing ring on the landing square (red with a pointer over the victim when it captures,
## gold when it reaches home). Visual only.
class_name MovePreview
extends Node3D

const DOT_Y := 0.135

var _items: Array[Node3D] = []
var _rings: Array[MeshInstance3D] = []
var _pointers: Array[MeshInstance3D] = []
var _time := 0.0
var _dot_mesh: CylinderMesh
var _ring_mesh: TorusMesh


func _ready() -> void:
	_dot_mesh = CylinderMesh.new()
	_dot_mesh.top_radius = 0.13
	_dot_mesh.bottom_radius = 0.13
	_dot_mesh.height = 0.01
	_dot_mesh.radial_segments = 16
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.32
	_ring_mesh.outer_radius = 0.46
	_ring_mesh.rings = 32
	_ring_mesh.ring_segments = 8


func _process(delta: float) -> void:
	_time += delta
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)
	for ring in _rings:
		ring.scale = Vector3(1.0 + 0.1 * pulse, 0.3, 1.0 + 0.1 * pulse)
		var mat := ring.material_override as StandardMaterial3D
		mat.emission_energy_multiplier = 1.4 + 1.6 * pulse
	for p in _pointers:
		p.position.y = 1.35 + 0.12 * sin(_time * 5.0)
		p.rotation.y = _time * 2.0


func clear() -> void:
	for item in _items:
		item.queue_free()
	_items.clear()
	_rings.clear()
	_pointers.clear()


## `moves` are RulesEngine.preview_move() results for the current player's legal tokens.
func show_moves(color: String, moves: Array, world_of: Callable) -> void:
	clear()
	var team: Color = RoyalBoard.PALETTE[color]
	var dot_mat := _glow(team, 1.6)
	for move in moves:
		var token: int = move["token"]
		var from: int = move["from"]
		var to: int = move["to"]
		for progress in range(maxi(from + 1, 1), to):
			var p: Vector3 = world_of.call(color, progress, token)
			_add_mesh(_dot_mesh, Vector3(p.x, DOT_Y, p.z), dot_mat)
		var land: Vector3 = world_of.call(color, to, token)
		var ring_color := Color("#fff0a0")  ## pale gold reads on every tile colour
		if not (move["captures"] as Array).is_empty():
			ring_color = Color("#ff3b3b")
		elif move["finishes"]:
			ring_color = Color("#ffd24a")
		var ring := _add_mesh(_ring_mesh, Vector3(land.x, land.y + 0.03, land.z), _glow(ring_color, 2.0))
		_rings.append(ring)
		if not (move["captures"] as Array).is_empty():
			## A red pointer bobbing over the victim.
			var cone := CylinderMesh.new()
			cone.top_radius = 0.2
			cone.bottom_radius = 0.0
			cone.height = 0.36
			cone.radial_segments = 4
			var mark := _add_mesh(cone, Vector3(land.x, 1.35, land.z), _glow(Color("#ff3b3b"), 2.2))
			_pointers.append(mark)


func _add_mesh(mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	_items.append(m)
	return m


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
