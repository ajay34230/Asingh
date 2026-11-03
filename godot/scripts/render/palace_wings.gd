## Palace terraces either side of the board. They are real 3D: marble platforms with
## columns, arches, a fountain basin and planters. The board stays square and true to
## proportion; these wings give the scene the width of a landscape screen.
class_name PalaceWings
extends Node3D

const INNER_X := 6.9     ## just outside the board edge
const OUTER_X := 12.0
const DEPTH := 8.4       ## terrace depth along Z, centred on the board

var _marble: Material
var _gold: Material
var _stone: Material


func _ready() -> void:
	_marble = _solid(Color("#efe7d6"), 0.25)
	_gold = _metal(Color("#d9a441"))
	_stone = _solid(Color("#8a6a4c"), 0.4)
	for side in [-1.0, 1.0]:
		_build_terrace(side)


func _build_terrace(side: float) -> void:
	var centre_x := side * (INNER_X + OUTER_X) * 0.5
	var width := OUTER_X - INNER_X
	var root := Node3D.new()
	root.name = "Terrace_%s" % ("left" if side < 0 else "right")
	root.position = Vector3(centre_x, 0, 0)
	add_child(root)

	# Raised marble platform with a gold rim.
	_box(root, Vector3(0, -0.12, 0), Vector3(width, 0.24, DEPTH), _marble)
	_box(root, Vector3(0, 0.005, 0), Vector3(width - 0.2, 0.02, DEPTH - 0.2), _terrace_top())
	_box(root, Vector3(0, 0.02, 0), Vector3(width + 0.08, 0.06, DEPTH + 0.08), _gold)

	# Two rows of columns along the outer and inner edges, with arches between them.
	for z in [-DEPTH * 0.36, DEPTH * 0.36]:
		for x in [-width * 0.32, width * 0.32]:
			_column(root, Vector3(x, 0, z))
		_arch(root, Vector3(0, 0, z), width * 0.64)

	# Fountain basin in the middle of the terrace, with a water surface.
	_cylinder(root, Vector3(0, 0.04, 0), 1.15, 0.22, _marble)
	_cylinder(root, Vector3(0, 0.15, 0), 0.95, 0.04, _water_material())
	_cylinder(root, Vector3(0, 0.45, 0), 0.12, 0.7, _marble)

	# Planters at the outer corners.
	for z in [-DEPTH * 0.42, DEPTH * 0.42]:
		_cylinder(root, Vector3(-width * 0.42 * side, 0.05, z), 0.42, 0.22, _gold)
		_sphere(root, Vector3(-width * 0.42 * side, 0.38, z), 0.36, _green_material())


func _column(parent: Node3D, at: Vector3) -> void:
	_cylinder(parent, at + Vector3(0, 1.1, 0), 0.14, 2.2, _marble)
	_box(parent, at + Vector3(0, 2.25, 0), Vector3(0.42, 0.14, 0.42), _gold)
	_box(parent, at + Vector3(0, 0.12, 0), Vector3(0.38, 0.12, 0.38), _gold)


## An arcade piece: a gold lintel across the columns, with a carved arch soffit below it.
func _arch(parent: Node3D, at: Vector3, span: float) -> void:
	_box(parent, at + Vector3(0, 2.3, 0), Vector3(span, 0.18, 0.3), _marble)
	_box(parent, at + Vector3(0, 2.14, 0), Vector3(span * 0.9, 0.06, 0.34), _gold)


func _box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = mat
	m.position = at
	parent.add_child(m)


func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 24
	m.mesh = cyl
	m.material_override = mat
	m.position = at
	parent.add_child(m)


func _sphere(parent: Node3D, at: Vector3, radius: float, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	m.mesh = s
	m.material_override = mat
	m.position = at
	parent.add_child(m)


func _solid(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


func _metal(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 1.0
	mat.roughness = 0.3
	return mat


func _water_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.6, 0.7, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.05
	mat.metallic = 0.2
	return mat


func _terrace_top() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#e6d7b8")
	mat.roughness = 0.3
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.25
	return mat


func _green_material() -> StandardMaterial3D:
	return _solid(Color("#2f7d3a"), 0.8)
