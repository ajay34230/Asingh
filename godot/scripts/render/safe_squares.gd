## Safe squares (start squares and stars) as special places on the board.
##  - An empty safe square shows a floating, spinning gold shield emblem over a beam
##    of light and a pulsing ring.
##  - A token resting on one is wrapped in a glowing protective shield with orbiting
##    sparks. The shield switches on with a pulse and switches off when the token leaves.
## Visual only: the rules engine decides what is safe.
class_name SafeSquares
extends Node3D

signal shield_raised(position: Vector3)

const EMBLEM_Y := 0.85

const FRESNEL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float strength = 1.0;
void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.2);
	float bands = 0.5 + 0.5 * sin(UV.y * 48.0 - TIME * 4.0);
	float runes = step(0.82, fract(UV.x * 18.0 + floor(UV.y * 9.0) * 0.37 + TIME * 0.15));
	float glow = rim * (1.6 + 0.45 * bands) + runes * rim * 0.8 + 0.1;
	ALBEDO = tint.rgb * glow * strength;
}
"""

const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float strength = 1.0;
void fragment() {
	float fade = pow(clamp(UV.y, 0.0, 1.0), 1.6);   // bright at the floor, gone at the top
	float shimmer = 0.75 + 0.25 * sin(UV.x * 30.0 + TIME * 3.0);
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.2);
	ALBEDO = tint.rgb * fade * shimmer * (0.25 + rim * 0.5) * strength;
}
"""

var game: GameController
var _squares: Array[Dictionary] = []     ## {index, root, emblem, beam_mat, ring}
var _shields: Dictionary = {}            ## token node -> {root, mat, sparks, born}
var _time := 0.0
var _gold: StandardMaterial3D
var _fresnel: Shader
var _beam: Shader


func _ready() -> void:
	_fresnel = Shader.new()
	_fresnel.code = FRESNEL_SHADER
	_beam = Shader.new()
	_beam.code = BEAM_SHADER
	_gold = RoyalBoard.metal(BoardThemes.current()["gold"], 0.22)
	_gold.emission_enabled = true
	_gold.emission = Color("#ffb84a")
	_gold.emission_energy_multiplier = 0.35
	for index in BoardPath.safe_ring_indices():
		_build_square(index)


func _owner_of_start(index: int) -> String:
	for color in BoardPath.COLORS:
		if BoardPath.start_of(color) == index:
			return color
	return ""


func _build_square(index: int) -> void:
	var cell: Vector2i = BoardPath.ring()[index]
	var at := BoardPath.to_world(cell.x + 0.5, cell.y + 0.5)
	var owner := _owner_of_start(index)
	var tint: Color = RoyalBoard.PALETTE[owner].lightened(0.25) if owner != "" else Color("#ffd27a")
	var root := Node3D.new()
	root.position = Vector3(at.x, RoyalBoard.TILE_TOP, at.z)
	add_child(root)

	## Beam of light rising from the tile.
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.3
	beam_mesh.bottom_radius = 0.4
	beam_mesh.height = 1.4
	beam_mesh.radial_segments = 24
	beam_mesh.cap_top = false
	beam_mesh.cap_bottom = false
	var beam_mat := ShaderMaterial.new()
	beam_mat.shader = _beam
	beam_mat.set_shader_parameter("tint", tint)
	var beam := _mesh(beam_mesh, Vector3(0, 0.7, 0), beam_mat, root)
	beam.rotation.x = PI  ## UV.y runs top to bottom on a cylinder; flip so it fades upwards

	## Pulsing ring on the tile.
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.36
	ring_mesh.outer_radius = 0.42
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 6
	var ring_mat := ShaderMaterial.new()
	ring_mat.shader = _fresnel
	ring_mat.set_shader_parameter("tint", tint)
	var ring := _mesh(ring_mesh, Vector3(0, 0.02, 0), ring_mat, root)
	ring.scale = Vector3(1, 0.25, 1)

	## The emblem: a gold heater shield with a jewel (start square) or a star.
	var emblem := Node3D.new()
	emblem.position = Vector3(0, EMBLEM_Y, 0)
	root.add_child(emblem)
	var outline := _shield_outline(0.26)
	var shield := _mesh(RoyalBoard.extrude_mesh(outline, -0.035, 0.035), Vector3.ZERO, _gold, emblem)
	shield.rotation.x = PI * 0.5   ## stand the outline up
	var inner_mat: Material
	if owner != "":
		inner_mat = RoyalBoard.gem_material(RoyalBoard.PALETTE[owner])
	else:
		inner_mat = RoyalBoard.gem_material(Color("#b5121b"))
	var inner := _mesh(RoyalBoard.extrude_mesh(_shield_outline(0.19), -0.05, 0.05), Vector3(0, 0.01, 0), inner_mat, emblem)
	inner.rotation.x = PI * 0.5
	var star := PackedVector2Array()
	for i in range(10):
		var r := 0.11 if i % 2 == 0 else 0.045
		var a := TAU * i / 10.0 - PI * 0.5
		star.append(Vector2(cos(a), sin(a)) * r)
	var star_mesh := _mesh(RoyalBoard.extrude_mesh(star, -0.065, 0.065), Vector3(0, 0.03, 0), _gold, emblem)
	star_mesh.rotation.x = PI * 0.5
	emblem.scale = Vector3.ONE * 1.9
	_squares.append({"index": index, "root": root, "emblem": emblem, "beam": beam, "beam_mat": beam_mat, "ring": ring, "show": 1.0})


## Heater-shield outline in the XZ plane (z up the shield once stood upright).
static func _shield_outline(size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(-size, -size))
	pts.append(Vector2(0.0, -size * 1.12))
	pts.append(Vector2(size, -size))
	for i in range(1, 12):
		var t := float(i) / 12.0
		## Each side curves from the shoulder down to the point.
		pts.append(Vector2(size * cos(t * PI * 0.5), -size + t * size * 2.25))
	pts.append(Vector2(0.0, size * 1.3))
	for i in range(11, 0, -1):
		var t := float(i) / 12.0
		pts.append(Vector2(-size * cos(t * PI * 0.5), -size + t * size * 2.25))
	return pts


func _mesh(mesh: Mesh, at: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


func _process(delta: float) -> void:
	_time += delta
	var resting := _resting_safe_tokens()
	var occupied := {}
	for token in resting:
		occupied[resting[token]] = true
	var cam := get_viewport().get_camera_3d()
	for sq in _squares:
		var target := 0.0 if occupied.has(sq["index"]) else 1.0
		## Fade out emblems the camera is close to (fight close-ups), so they never block the view.
		if cam:
			var d := cam.global_position.distance_to((sq["root"] as Node3D).global_position)
			target *= clampf((d - 4.0) / 2.5, 0.0, 1.0)
		sq["show"] = move_toward(sq["show"], target, delta * 5.0)
		var k: float = sq["show"]
		var emblem: Node3D = sq["emblem"]
		emblem.visible = k > 0.01
		## Lean towards the player and sway, so the face always reads from above.
		emblem.rotation = Vector3(-0.55, sin(_time * 1.4 + float(sq["index"])) * 0.7, 0)
		emblem.position.y = EMBLEM_Y + 0.08 * sin(_time * 2.0 + sq["index"])
		emblem.scale = Vector3.ONE * 1.9 * k
		(sq["beam_mat"] as ShaderMaterial).set_shader_parameter("strength", k * (2.0 + 0.4 * sin(_time * 3.0)))
		(sq["beam"] as Node3D).visible = k > 0.01
		var ring: Node3D = sq["ring"]
		var pulse := 1.0 + 0.08 * sin(_time * 4.0 + sq["index"])
		ring.scale = Vector3(pulse, 0.25, pulse)
	_update_shields(delta, resting)


## token node -> safe ring index, for every token resting on a safe square.
func _resting_safe_tokens() -> Dictionary:
	var out := {}
	if game == null or game.engine == null or game.engine.seats.is_empty():
		return out
	for seat in game.engine.seats:
		var color: String = seat["color"]
		if not game.tokens.has(color):
			continue
		for i in range(BoardPath.TOKENS_PER_PLAYER):
			var progress: int = seat["tokens"][i]
			if progress < 1 or progress > BoardPath.COMMON_STEPS:
				continue
			var ring := BoardPath.ring_index_for_progress(color, progress)
			if not BoardPath.is_safe_ring(ring):
				continue
			var token: Node3D = game.tokens[color][i]
			## Only once the token has arrived on its square: a walking token has no shield.
			var cell: Vector2i = BoardPath.ring()[ring]
			var w := BoardPath.to_world(cell.x + 0.5, cell.y + 0.5)
			if Vector2(token.global_position.x - w.x, token.global_position.z - w.z).length() > 0.3:
				continue
			out[token] = ring
	return out


func _update_shields(delta: float, resting: Dictionary) -> void:
	for token in resting:
		if not _shields.has(token) and is_instance_valid(token):
			_shields[token] = _make_shield(token as Node3D)
			shield_raised.emit((token as Node3D).global_position)
	for token in _shields.keys():
		var s: Dictionary = _shields[token]
		var root: Node3D = s["root"]
		if not is_instance_valid(token) or not resting.has(token):
			if is_instance_valid(root):
				root.queue_free()
			_shields.erase(token)
			continue
		s["age"] = float(s["age"]) + delta
		var age: float = s["age"]
		var t := token as Node3D
		root.global_position = Vector3(t.global_position.x, RoyalBoard.TILE_TOP, t.global_position.z)
		## Pop in with an overshoot, then breathe.
		var grow := clampf(age / 0.35, 0.0, 1.0)
		var pop := 1.0 + 0.35 * sin(grow * PI) * (1.0 - grow)
		var breathe := 1.0 + 0.04 * sin(_time * 3.0)
		(s["bubble"] as Node3D).scale = Vector3(0.62, 0.78, 0.62) * grow * pop * breathe
		(s["mat"] as ShaderMaterial).set_shader_parameter("strength", 1.5 + 0.35 * sin(_time * 5.0) + (1.0 - grow) * 2.0)
		var sparks: Node3D = s["sparks"]
		sparks.rotation.y = _time * 2.4
		sparks.position.y = 0.5 + 0.12 * sin(_time * 2.0)
		var ring: Node3D = s["ring"]
		var rp := 1.0 + 0.1 * sin(_time * 4.0)
		ring.scale = Vector3(rp, 0.3, rp)


func _make_shield(token: Node3D) -> Dictionary:
	var color := "gold"
	if token.has_meta("color"):
		color = token.get_meta("color")
	var tint: Color = RoyalBoard.PALETTE.get(color, Color("#ffd27a")).lerp(Color("#ffe8a0"), 0.45)
	var root := Node3D.new()
	add_child(root)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 40
	sphere.rings = 20
	var mat := ShaderMaterial.new()
	mat.shader = _fresnel
	mat.set_shader_parameter("tint", tint)
	var bubble := _mesh(sphere, Vector3(0, 0.45, 0), mat, root)
	bubble.scale = Vector3.ZERO
	## Glowing ring on the tile under the shield.
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.5
	ring_mesh.outer_radius = 0.58
	ring_mesh.rings = 40
	ring_mesh.ring_segments = 6
	var ring := _mesh(ring_mesh, Vector3(0, 0.03, 0), mat, root)
	ring.scale = Vector3(1, 0.3, 1)
	## Three sparks orbiting the shield.
	var sparks := Node3D.new()
	root.add_child(sparks)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.albedo_color = Color("#fff2c0")
	spark_mat.emission_enabled = true
	spark_mat.emission = tint
	spark_mat.emission_energy_multiplier = 4.0
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.045
	spark_mesh.height = 0.09
	for i in range(3):
		var a := TAU * i / 3.0
		_mesh(spark_mesh, Vector3(cos(a) * 0.66, 0.12 * sin(a * 2.0), sin(a) * 0.66), spark_mat, sparks)
	return {"root": root, "bubble": bubble, "mat": mat, "sparks": sparks, "ring": ring, "age": 0.0}
