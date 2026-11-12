## Visual effects: sparkle bursts, capture shockwaves, gold dust, victory fireworks and
## confetti. Effects are one-shot GPU particles that free themselves when finished.
class_name EffectsManager
extends Node3D

const GOLD := Color("#ffd76a")
const TEAM := {
	"red": Color("#e0444c"), "green": Color("#43b861"),
	"yellow": Color("#f7cd55"), "blue": Color("#4f8ce6"),
}

var _spark_mesh: SphereMesh
var _confetti_mesh: BoxMesh


func _ready() -> void:
	_spark_mesh = SphereMesh.new()
	_spark_mesh.radius = 0.05   ## a spark is a few centimetres across on the board
	_spark_mesh.height = 0.1
	_confetti_mesh = BoxMesh.new()
	_confetti_mesh.size = Vector3(0.12, 0.02, 0.06)


## A quick burst of sparks. `amount` and `speed` scale with how big the event is.
func burst(at: Vector3, color: Color, amount := 36, speed := 2.4, lifetime := 0.9, gravity := 4.0) -> void:
	var p := _make_particles(amount, lifetime)
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 180.0
	mat.initial_velocity_min = speed * 0.4
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, -gravity, 0)
	mat.scale_min = 0.6
	mat.scale_max = 1.4
	mat.color = color
	p.process_material = mat
	p.draw_pass_1 = _glow_mesh(color)
	_emit_at(p, at, lifetime)


## Contact flash for a hit: a bright core that pops and fades, sharp streaks flying
## outward and a few sparks. `big` for finishers.
func hit_spark(at: Vector3, big := false) -> void:
	var size := 0.55 if big else 0.28
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(1.0, 0.97, 0.85)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.85, 0.5)
	core_mat.emission_energy_multiplier = 6.0
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	core.mesh = sphere
	core.material_override = core_mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.position = at
	core.scale = Vector3.ONE * 0.05
	add_child(core)
	var t := create_tween().set_parallel(true)
	t.tween_property(core, "scale", Vector3.ONE * size, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(core_mat, "albedo_color:a", 0.0, 0.18).set_delay(0.04)
	t.tween_property(core, "scale", Vector3.ONE * size * 1.4, 0.18).set_delay(0.05)
	t.chain().tween_callback(core.queue_free)
	## Streaks: thin bright shards shooting out from the contact point.
	var streak_mat := core_mat.duplicate() as StandardMaterial3D
	var count := 10 if big else 6
	for i in range(count):
		var shard := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.025, 0.025, 0.32 if big else 0.2)
		shard.mesh = box
		shard.material_override = streak_mat
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.4, 1.0), randf_range(-1, 1)).normalized()
		add_child(shard)
		shard.global_position = at
		shard.look_at(at + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
		var st := create_tween().set_parallel(true)
		st.tween_property(shard, "global_position", at + dir * (0.7 if big else 0.4), 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		st.tween_property(shard, "scale", Vector3(1, 1, 0.1), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		st.chain().tween_callback(shard.queue_free)
	burst(at, Color(1.0, 0.85, 0.45), 26 if big else 10, 3.4 if big else 2.0, 0.45, 6.0)


## Low puff of dust where something crashes onto the board.
## A heavy metal hit: a puff of dark smoke and flying metal fragments (fewer on Low).
func metal_hit(at: Vector3, big := false) -> void:
	var lite := String(GameSettings.get_option("graphics")) == "low"
	burst(at, Color("#4a4a50"), 6 if lite else (16 if big else 10), 0.7, 1.3, -0.5)             # smoke
	burst(at, Color("#cfd6de"), 6 if lite else (18 if big else 10), 3.4 if big else 2.6, 0.8, 9.0)   # debris
	if big and not lite:
		burst(at, Color("#ff9a3a"), 14, 4.0, 0.5, 6.0)                                               # hot sparks


func dust(at: Vector3) -> void:
	burst(at + Vector3(0, 0.08, 0), Color(0.85, 0.75, 0.6, 0.8), 22, 1.2, 0.6, 1.5)


## Gold dust drifting up from a position (used for dice sparkles and home entry).
func sparkle_trail(at: Vector3, amount := 24) -> void:
	var p := _make_particles(amount, 1.2)
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 40.0
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.0
	mat.gravity = Vector3(0, 0.6, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.0
	mat.color = GOLD
	p.process_material = mat
	p.draw_pass_1 = _glow_mesh(GOLD)
	_emit_at(p, at, 1.2)


## Shockwave ring on the board where a capture happens.
func shockwave(at: Vector3, color := GOLD) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.26
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	ring.material_override = mat
	ring.global_position = at + Vector3(0, 0.05, 0)
	ring.rotation_degrees.x = 90
	add_child(ring)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 9.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tween.chain().tween_callback(ring.queue_free)


## Fireworks: staggered coloured bursts over the board.
func fireworks(duration := 3.0) -> void:
	var colors := [GOLD, TEAM["red"], TEAM["green"], TEAM["yellow"], TEAM["blue"]]
	var bursts := int(duration * 2.0)
	for i in range(bursts):
		var at := Vector3(randf_range(-5.0, 5.0), randf_range(3.0, 6.0), randf_range(-5.0, 5.0))
		var delay := i * 0.5 + randf_range(0.0, 0.2)
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			burst(at, colors[randi() % colors.size()], 90, 4.0, 1.3, 2.5))


## Confetti falling over the board for `duration` seconds.
func confetti(duration := 4.0) -> void:
	var colors := [TEAM["red"], TEAM["green"], TEAM["yellow"], TEAM["blue"], GOLD]
	for color in colors:
		var p := _make_particles(60, duration)
		p.one_shot = false
		p.lifetime = 3.0
		var mat := ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = Vector3(6.0, 0.1, 6.0)
		mat.direction = Vector3.DOWN
		mat.spread = 20.0
		mat.initial_velocity_min = 0.5
		mat.initial_velocity_max = 1.5
		mat.gravity = Vector3(0, -1.2, 0)
		mat.angular_velocity_min = -220.0
		mat.angular_velocity_max = 220.0
		mat.scale_min = 0.8
		mat.scale_max = 1.3
		mat.color = color
		p.process_material = mat
		var piece := _confetti_mesh.duplicate() as BoxMesh
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		piece.material = m
		p.draw_pass_1 = piece
		p.position = Vector3(0, 6.0, 0)
		add_child(p)
		p.emitting = true
		get_tree().create_timer(duration + 3.5).timeout.connect(p.queue_free)


func _make_particles(amount: int, lifetime: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = false
	return p


func _emit_at(p: GPUParticles3D, at: Vector3, lifetime: float) -> void:
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(lifetime + 0.6).timeout.connect(p.queue_free)


func _glow_mesh(color: Color) -> SphereMesh:
	var mesh := _spark_mesh.duplicate() as SphereMesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	return mesh
