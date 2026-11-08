## Board pieces for the extra modes: coiled cobras on snake squares and gold ladders on
## ladder squares (Snakes & Ludo), and floating power-up orbs (shield or star).
class_name SpecialSquares
extends Node3D

var _orbs: Dictionary = {}   ## ring index -> Node3D
var _time := 0.0
var _gold: StandardMaterial3D


func _ready() -> void:
	_gold = RoyalBoard.metal(BoardThemes.current()["gold"], 0.25)


func build_jumps() -> void:
	for ring in RulesEngine.JUMPS:
		var delta: int = RulesEngine.JUMPS[ring]
		var cell: Vector2i = BoardPath.ring()[ring]
		var at := BoardPath.to_world(cell.x + 0.5, cell.y + 0.5)
		var root := Node3D.new()
		root.position = Vector3(at.x, RoyalBoard.TILE_TOP, at.z)
		root.scale = Vector3.ONE * 1.5
		add_child(root)
		if delta < 0:
			_cobra(root)
		else:
			_ladder(root)
		## A small number shows how far it moves the token.
		var l := Label3D.new()
		l.text = ("+%d" % delta) if delta > 0 else str(delta)
		l.font_size = 90
		l.pixel_size = 0.004
		l.outline_size = 14
		l.modulate = Color("#7cff7a") if delta > 0 else Color("#ff6a6a")
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = Vector3(0, 0.75, 0)
		root.add_child(l)


func _cobra(root: Node3D) -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("#2f8a3a")
	skin.roughness = 0.35
	skin.metallic_specular = 0.8
	var belly := StandardMaterial3D.new()
	belly.albedo_color = Color("#e8d27a")
	for i in range(3):
		var coil := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.18 - i * 0.04
		torus.outer_radius = 0.28 - i * 0.04
		torus.rings = 32
		torus.ring_segments = 10
		coil.mesh = torus
		coil.material_override = skin
		coil.position = Vector3(0, 0.05 + i * 0.08, 0)
		root.add_child(coil)
	var neck := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.07
	cyl.height = 0.35
	neck.mesh = cyl
	neck.material_override = skin
	neck.position = Vector3(0, 0.38, 0)
	root.add_child(neck)
	var hood := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.13
	s.height = 0.26
	hood.mesh = s
	hood.material_override = skin
	hood.position = Vector3(0, 0.58, 0.02)
	hood.scale = Vector3(1.3, 1.0, 0.45)
	root.add_child(hood)
	for x in [-0.045, 0.045]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.02
		es.height = 0.04
		eye.mesh = es
		eye.material_override = RoyalBoard.gem_material(Color("#ff2020"))
		eye.position = Vector3(x, 0.6, 0.08)
		root.add_child(eye)
	root.set_meta("sway", true)


func _ladder(root: Node3D) -> void:
	var rail := BoxMesh.new()
	rail.size = Vector3(0.04, 0.8, 0.04)
	var rung := BoxMesh.new()
	rung.size = Vector3(0.3, 0.03, 0.03)
	var lad := Node3D.new()
	lad.rotation.x = -0.35
	lad.position = Vector3(0, 0.36, 0.08)
	root.add_child(lad)
	for x in [-0.15, 0.15]:
		var r := MeshInstance3D.new()
		r.mesh = rail
		r.material_override = _gold
		r.position = Vector3(x, 0, 0)
		lad.add_child(r)
	for i in range(5):
		var g := MeshInstance3D.new()
		g.mesh = rung
		g.material_override = _gold
		g.position = Vector3(0, -0.32 + i * 0.16, 0)
		lad.add_child(g)


## Shows exactly the orbs the rules engine has (ring index -> type).
func sync_powerups(powerups: Dictionary) -> void:
	for ring in _orbs.keys():
		if not powerups.has(ring) or (_orbs[ring] as Node3D).get_meta("type") != powerups[ring]:
			(_orbs[ring] as Node3D).queue_free()
			_orbs.erase(ring)
	for ring in powerups:
		if _orbs.has(ring):
			continue
		var type: String = powerups[ring]
		var cell: Vector2i = BoardPath.ring()[ring]
		var at := BoardPath.to_world(cell.x + 0.5, cell.y + 0.5)
		var orb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.26
		sphere.height = 0.52
		orb.mesh = sphere
		var color := Color("#4fc3ff") if type == "shield" else Color("#ffd24a")
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 3.5
		m.roughness = 0.1
		orb.material_override = m
		orb.position = Vector3(at.x, 0.55, at.z)
		orb.set_meta("type", type)
		var icon := Label3D.new()
		icon.text = "S" if type == "shield" else "+1"
		icon.font_size = 96
		icon.pixel_size = 0.004
		icon.outline_size = 12
		icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon.no_depth_test = true
		icon.position = Vector3(0, 0.45, 0)
		orb.add_child(icon)
		add_child(orb)
		_orbs[ring] = orb


func _process(delta: float) -> void:
	_time += delta
	for ring in _orbs:
		var o: Node3D = _orbs[ring]
		o.position.y = 0.55 + 0.08 * sin(_time * 2.5 + ring)
		o.rotation.y = _time * 1.5
	for c in get_children():
		if c.has_meta("sway"):
			(c as Node3D).rotation.y = sin(_time * 1.2 + c.position.x) * 0.5
