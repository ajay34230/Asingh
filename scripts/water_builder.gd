class_name WaterBuilder
extends RefCounted
## The village pond (animated water, reeds, lilies, shore stones, palms and grass), a stone water
## channel that runs from the pond to a trough beside the well, and water-carrying villagers.

const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, specular_schlick_ggx;
// Dark green-grey water with strong sky reflection at glancing angles, big slow swells with fine
// ripples on top, sun glints, depth-based colour and white foam where the water meets the shore.
uniform sampler2D nrm_a : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D nrm_b : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
global uniform vec3 water_sky;
global uniform float wind_strength;
uniform vec4 shallow_col : source_color = vec4(0.20, 0.34, 0.28, 1.0);
uniform vec4 deep_col : source_color = vec4(0.02, 0.09, 0.10, 1.0);
uniform vec2 flow = vec2(0.012, 0.006);
uniform float wave_amp = 0.06;
uniform float gl_depth = 0.0;
varying vec3 wpos;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = 0.6 + wind_strength;
	VERTEX.y += (sin(w.x * 0.35 + TIME * 0.9) * 0.6 + sin(w.z * 0.5 - TIME * 1.1) * 0.5 + sin((w.x + w.z) * 1.1 + TIME * 1.9) * 0.25) * wave_amp * k;
	wpos = w;
}
void fragment() {
	vec2 uv = wpos.xz * 0.06;
	vec3 a = texture(nrm_a, uv * 0.6 + flow * TIME).rgb;
	vec3 b = texture(nrm_b, uv * 1.9 - flow.yx * TIME * 1.4 + 0.31).rgb;
	vec3 c = texture(nrm_b, uv * 5.3 + vec2(0.27, -0.11) * TIME * 0.2).rgb;
	vec3 n = normalize((a * 2.0 - 1.0) * 1.0 + (b * 2.0 - 1.0) * 0.7 + (c * 2.0 - 1.0) * 0.35);
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.1 + wind_strength * 0.6;
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, mix(depth, depth * 2.0 - 1.0, gl_depth));
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float thick = max(-view.z + VERTEX.z, 0.0);
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fres = 0.03 + 0.97 * pow(1.0 - ndv, 4.0);
	float tint = 1.0 - exp(-thick * 0.55);
	vec3 body = mix(shallow_col.rgb, deep_col.rgb, tint);
	float foam_line = (1.0 - smoothstep(0.0, 0.45, thick)) * smoothstep(0.30, 0.60, a.g * 0.6 + b.r * 0.5 + 0.1 * sin(TIME * 1.3 + wpos.x * 3.0));
	float foam_edge = (1.0 - smoothstep(0.0, 0.12, thick));
	float foam = clamp(foam_line + foam_edge, 0.0, 1.0);
	ALBEDO = mix(body, vec3(0.92, 0.94, 0.92), foam);
	EMISSION = water_sky * fres * 0.85 * (1.0 - foam);
	ALPHA = clamp(mix(0.35 + tint * 0.6, 1.0, max(fres, foam)), 0.0, 0.98);
	ROUGHNESS = mix(0.06, 0.8, foam);
	SPECULAR = 1.0;
	METALLIC = 0.0;
}
"""

var terrain: TerrainBuilder
var water_level := 0.0
var pond_mat: ShaderMaterial
var chan_mat: ShaderMaterial
var well_pos := Vector2(-90.0, 12.0)
var channel_start := Vector3.ZERO
var channel_end := Vector3.ZERO


func _init(t: TerrainBuilder) -> void:
	terrain = t
	water_level = t.pond_level - 0.55


func _make_mat(flow: Vector2, amp: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = WATER_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("nrm_a", PropFactory._noise_texture("water_a", 0.02, 3, 91, true, 5.0, 0.6, false, 256))
	m.set_shader_parameter("nrm_b", PropFactory._noise_texture("water_b", 0.035, 2, 93, true, 3.5, 0.6, false, 256))
	m.set_shader_parameter("flow", flow)
	m.set_shader_parameter("wave_amp", amp)
	m.set_shader_parameter("gl_depth", 1.0 if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 0.0)
	return m


func build(parent: Node3D, houses: HouseBuilder) -> void:
	var root := Node3D.new()
	root.name = "Water"
	parent.add_child(root)
	_pond(root)
	_channel(root)
	_flora(root, houses)


func _pond(root: Node3D) -> void:
	var c := TerrainBuilder.POND_C
	pond_mat = _make_mat(Vector2(0.012, 0.006), 0.06)
	var mi := MeshInstance3D.new()
	mi.name = "PondWater"
	var pm := PlaneMesh.new()
	pm.size = Vector2(54.0, 54.0)
	pm.subdivide_width = 64
	pm.subdivide_depth = 64
	mi.mesh = pm
	mi.material_override = pond_mat
	mi.position = Vector3(c.x, water_level, c.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# Shore stones.
	var stone := PropFactory.sandstone()
	for i in 16:
		var a := TAU * i / 16.0 + rng.randf_range(-0.12, 0.12)
		var r := TerrainBuilder.POND_R * rng.randf_range(1.12, 1.3)
		var x := c.x + cos(a) * r
		var z := c.y + sin(a) * r
		var s := rng.randf_range(0.3, 0.8)
		PropFactory.rock(root, Vector3(s, s * 0.6, s * 0.9), Vector3(x, terrain.sample_height(x, z) + s * 0.1, z), stone, rng.randf() * 360.0)
	# Lily pads and lotus flowers floating on the water.
	var pads: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	for i in 22:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * TerrainBuilder.POND_R * 0.78
		var p := Vector3(c.x + cos(a) * r, water_level + 0.03, c.y + sin(a) * r)
		var sc := rng.randf_range(0.7, 1.4)
		pads.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(sc, 1, sc)), p))
		if i % 4 == 0:
			flowers.append(Transform3D(Basis(), p + Vector3(0.12, 0.08, 0.0)))
	var pad := CylinderMesh.new()
	pad.top_radius = 0.45
	pad.bottom_radius = 0.45
	pad.height = 0.02
	pad.radial_segments = 14
	pad.rings = 1
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.12, 0.42, 0.14)
	pad_mat.roughness = 0.6
	pad.material = pad_mat
	Flora.scatter(root, pad, pad_mat, pads, "LilyPads")
	var lotus := SphereMesh.new()
	lotus.radius = 0.15
	lotus.height = 0.26
	lotus.radial_segments = 10
	lotus.rings = 5
	var lot_mat := StandardMaterial3D.new()
	lot_mat.albedo_color = Color(0.96, 0.52, 0.72)
	lot_mat.roughness = 0.5
	lot_mat.emission_enabled = true
	lot_mat.emission = Color(0.5, 0.15, 0.3)
	lot_mat.emission_energy_multiplier = 0.4
	Flora.scatter(root, lotus, lot_mat, flowers, "Lotus")


func _channel(root: Node3D) -> void:
	var c3 := Vector3(TerrainBuilder.POND_C.x, 0.0, TerrainBuilder.POND_C.y)
	var wp3 := Vector3(well_pos.x, 0.0, well_pos.y)
	var dir := (wp3 - c3).normalized()
	var a := c3 + dir * TerrainBuilder.POND_R * 1.18
	var b := wp3 - dir * 4.5
	channel_start = a
	channel_end = b
	var total := a.distance_to(b)
	var count := int(total / 1.6)
	chan_mat = _make_mat(Vector2(0.0, 0.35), 0.0)
	var stone := PropFactory.sandstone()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(0.22, 0.42, 1.66)
	var water_mesh := BoxMesh.new()
	water_mesh.size = Vector3(0.78, 0.05, 1.66)
	var segs := Node3D.new()
	segs.name = "Channel"
	root.add_child(segs)
	var side := Vector3(-dir.z, 0.0, dir.x)
	var prev_p := Vector3.ZERO
	for i in count:
		var t0 := float(i) / count
		var t1 := float(i + 1) / count
		var p0 := a.lerp(b, t0)
		var p1 := a.lerp(b, t1)
		p0.y = terrain.sample_height(p0.x, p0.z) + 0.1
		p1.y = terrain.sample_height(p1.x, p1.z) + 0.1
		var mid := (p0 + p1) * 0.5
		var bs := Basis.looking_at(p1 - p0, Vector3.UP)
		for sgn: float in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			w.mesh = wall_mesh
			w.material_override = stone
			w.transform = Transform3D(bs, mid + side * 0.5 * sgn + Vector3(0, 0.12, 0))
			segs.add_child(w)
		var wm := MeshInstance3D.new()
		wm.mesh = water_mesh
		wm.material_override = chan_mat
		wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wm.transform = Transform3D(bs, mid + Vector3(0, 0.26, 0))
		segs.add_child(wm)
		prev_p = mid
	# Sluice posts at the pond end and a stone trough where the channel ends.
	for sgn: float in [-1.0, 1.0]:
		var sp: Vector3 = a + side * 0.75 * float(sgn)
		PropFactory.box(root, Vector3(0.4, 1.0, 0.4), Vector3(sp.x, terrain.sample_height(sp.x, sp.z) + 0.5, sp.z), stone, Vector3.ZERO, false)
	var tp := b + dir * 1.6
	tp.y = terrain.sample_height(tp.x, tp.z)
	var trough := Node3D.new()
	trough.name = "Trough"
	trough.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), tp)
	root.add_child(trough)
	PropFactory.box(trough, Vector3(2.6, 0.7, 1.5), Vector3(0, 0.35, 0), stone, Vector3.ZERO, true)
	var tw := MeshInstance3D.new()
	var twm := BoxMesh.new()
	twm.size = Vector3(2.2, 0.04, 1.1)
	tw.mesh = twm
	tw.material_override = chan_mat
	tw.position = Vector3(0, 0.72, 0)
	tw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trough.add_child(tw)


func _flora(root: Node3D, houses: HouseBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	var c := TerrainBuilder.POND_C
	var palms: Array[Transform3D] = []
	var blocked := func(x: float, z: float) -> bool:
		for s in TerrainBuilder.HOUSE_SITES:
			if Vector2(x - s.x, z - s.y).length() < 15.0:
				return true
		if absf(z - 96.0) < 22.0 and absf(x) < 155.0:
			return true
		if Vector2(x - TerrainBuilder.FOREST_C.x, z - TerrainBuilder.FOREST_C.y).length() < TerrainBuilder.FOREST_R + 6.0:
			return true
		if absf(x - TerrainBuilder.TRACK_C.x) < TerrainBuilder.TRACK_R + TerrainBuilder.TRACK_W + 14.0 and absf(z - TerrainBuilder.TRACK_C.y) < TerrainBuilder.TRACK_L + TerrainBuilder.TRACK_R + TerrainBuilder.TRACK_W + 14.0:
			return true
		if Vector2(x - TerrainBuilder.TOWN_C.x, z - TerrainBuilder.TOWN_C.y).length() < TerrainBuilder.TOWN_R + 8.0:
			return true
		if Vector2(x - TerrainBuilder.START_MOUND.x, z - TerrainBuilder.START_MOUND.y).length() < 20.0:
			return true
		if Vector2(x - TerrainBuilder.TEMPLE_C.x, z - TerrainBuilder.TEMPLE_C.y).length() < 22.0:
			return true
		if Vector2(x - well_pos.x, z - well_pos.y).length() < 6.0:
			return true
		return false
	# Palms: a ring around the pond, a few along the channel, and groves round the village.
	var spots: Array[Vector2] = []
	for i in 11:
		var a := TAU * i / 11.0 + rng.randf_range(-0.2, 0.2)
		var r := TerrainBuilder.POND_R * rng.randf_range(1.5, 2.1)
		spots.append(c + Vector2(cos(a), sin(a)) * r)
	for i in 26:
		spots.append(Vector2(rng.randf_range(-145.0, -45.0), rng.randf_range(-60.0, 70.0)))
	for i in 8:
		spots.append(Vector2(44.0, 44.0) + Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0)))
	var palm_body := StaticBody3D.new()
	palm_body.name = "PalmTrunks"
	root.add_child(palm_body)
	for sp in spots:
		if blocked.call(sp.x, sp.y):
			continue
		if Vector2(sp.x - c.x, sp.y - c.y).length() < TerrainBuilder.POND_R * 1.35:
			continue
		var y := terrain.sample_height(sp.x, sp.y)
		var sc := rng.randf_range(0.8, 1.25)
		palms.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * sc), Vector3(sp.x, y - 0.1, sp.y)))
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3 * sc
		cyl.height = 4.0
		cs.shape = cyl
		cs.position = Vector3(sp.x, y + 2.0, sp.y)
		palm_body.add_child(cs)
	Flora.scatter_cells(root, Flora.palm_mesh(), Flora.sway_material("palm", 0.012, 1.1), palms, "Palms", "foliage_palm", 60.0)
	# Acacias, dead trees, bushes and wildflowers add variety to the palms.
	var acacias: Array[Transform3D] = []
	var deads: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	var flowers: Array[Array] = [[], [], []]
	for i in 16:
		var x := rng.randf_range(-150.0, -45.0)
		var z := rng.randf_range(-62.0, 75.0)
		if blocked.call(x, z) or Vector2(x - c.x, z - c.y).length() < TerrainBuilder.POND_R * 1.4:
			continue
		var y := terrain.sample_height(x, z)
		var sc := rng.randf_range(0.8, 1.3)
		acacias.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * sc), Vector3(x, y - 0.1, z)))
		var cs2 := CollisionShape3D.new()
		var cy2 := CylinderShape3D.new()
		cy2.radius = 0.3 * sc
		cy2.height = 3.0
		cs2.shape = cy2
		cs2.position = Vector3(x, y + 1.5, z)
		palm_body.add_child(cs2)
	for i in 14:
		var x := rng.randf_range(20.0, 150.0)
		var z := rng.randf_range(-110.0, 60.0)
		if blocked.call(x, z):
			continue
		deads.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), Vector3(x, terrain.sample_height(x, z) - 0.1, z)))
	for i in 150:
		var x := rng.randf_range(-150.0, -40.0)
		var z := rng.randf_range(-62.0, 78.0)
		if blocked.call(x, z) or Vector2(x - c.x, z - c.y).length() < TerrainBuilder.POND_R * 1.25:
			continue
		bushes.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4)), Vector3(x, terrain.sample_height(x, z) - 0.05, z)))
	for i in 420:
		var a := rng.randf() * TAU
		var r := TerrainBuilder.POND_R * 1.2 + sqrt(rng.randf()) * 24.0
		var x := c.x + cos(a) * r
		var z := c.y + sin(a) * r
		if blocked.call(x, z):
			continue
		flowers[i % 3].append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), Vector3(x, terrain.sample_height(x, z) - 0.02, z)))
	Flora.scatter_cells(root, Flora.acacia_mesh(), Flora.sway_material("acacia", 0.006, 0.9), acacias, "Acacia", "foliage_palm", 60.0)
	Flora.scatter_cells(root, Flora.dead_tree_mesh(), Flora.sway_material("dead", 0.0, 1.0), deads, "DeadTree", "foliage_palm", 60.0)
	Flora.scatter_cells(root, Flora.bush_mesh(), Flora.sway_material("bush", 0.05, 1.3), bushes, "Bush", "foliage_grass", 30.0)
	var head_cols := [Color(0.95, 0.85, 0.2), Color(0.9, 0.25, 0.45), Color(0.95, 0.95, 0.9)]
	for k in 3:
		var ft: Array[Transform3D] = []
		ft.assign(flowers[k])
		Flora.scatter_cells(root, Flora.flower_mesh(head_cols[k], 30 + k), Flora.sway_material("flower", 0.12, 1.6), ft, "Flowers%d" % k, "foliage_grass", 30.0)
	# Grass tufts across the green ground, and tall reeds at the water's edge.
	var grass: Array[Transform3D] = []
	var reeds: Array[Transform3D] = []
	for i in 2600:
		var a := rng.randf() * TAU
		var r := TerrainBuilder.POND_R * 1.15 + sqrt(rng.randf()) * 30.0
		var x := c.x + cos(a) * r
		var z := c.y + sin(a) * r
		if blocked.call(x, z):
			continue
		grass.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.6)), Vector3(x, terrain.sample_height(x, z) - 0.02, z)))
	for i in 700:
		var x := rng.randf_range(-140.0, -48.0)
		var z := rng.randf_range(-55.0, 65.0)
		if blocked.call(x, z):
			continue
		grass.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3)), Vector3(x, terrain.sample_height(x, z) - 0.02, z)))
	for i in 160:
		var a := rng.randf() * TAU
		var r := TerrainBuilder.POND_R * rng.randf_range(0.95, 1.18)
		var x := c.x + cos(a) * r
		var z := c.y + sin(a) * r
		reeds.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(1, rng.randf_range(0.9, 1.5), 1)), Vector3(x, terrain.sample_height(x, z) - 0.1, z)))
	Flora.scatter_cells(root, Flora.clump_mesh(7, 0.3, 0.6, 5, Color(0.30, 0.44, 0.16)), Flora.sway_material("grass", 0.18, 1.8), grass, "Grass", "foliage_grass", 30.0)
	Flora.scatter_cells(root, Flora.clump_mesh(5, 1.2, 2.1, 9, Color(0.28, 0.42, 0.15)), Flora.sway_material("reeds", 0.06, 1.2), reeds, "Reeds", "foliage_reeds", 30.0)


## Villagers fetch water from the pond and carry clay pots on their heads to the houses and the trough.
func spawn_carriers(parent: Node3D, houses: HouseBuilder, player: Node3D) -> Array[Npc]:
	var out: Array[Npc] = []
	var c := TerrainBuilder.POND_C
	var plans := [
		["lady_medieval", "WaterCarrier1", 3], ["worker_woman", "WaterCarrier2", 0],
		["lady_green", "WaterCarrier3", -1], ["girl_casual", "WaterCarrier4", 1],
	]
	for pl in plans:
		var path: Array[Vector3] = []
		var target: Vector3
		var hi: int = pl[2]
		var end_pts: Array[Vector3] = []
		if hi >= 0:
			var hn: Node3D = houses.houses[hi].node
			var hy: float = houses.houses[hi].half.y
			end_pts.append(hn.global_transform * Vector3(0, 0, hy + 8.0))
			end_pts.append(hn.global_transform * Vector3(0, 0, hy + 1.6))
			target = end_pts[end_pts.size() - 1]
		else:
			target = channel_end + (channel_end - Vector3(c.x, 0, c.y)).normalized() * 3.0
			end_pts.append(target)
		var toward := (Vector3(target.x, 0, target.z) - Vector3(c.x, 0, c.y)).normalized()
		var shore := Vector3(c.x, 0, c.y) + toward * TerrainBuilder.POND_R * 1.25
		path.append(shore)
		path.append(Vector3(c.x, 0, c.y) + toward * TerrainBuilder.POND_R * 2.2)
		for e in end_pts:
			path.append(e)
		for i in path.size():
			path[i].y = terrain.sample_height(path[i].x, path[i].z)
		var n := Npc.new().setup(NpcBuilder.PRESETS[pl[0]], "idle", pl[1])
		n.player = player
		parent.add_child(n)
		n.global_position = path[0]
		n.routine = {"type": "carry", "points": path, "home": path[path.size() - 1]}
		n.pot = _make_pot()
		n.add_child(n.pot)
		n.pot.position = Vector3(0, 1.78, 0)
		n.pot.visible = false
		out.append(n)
	return out


func _make_pot() -> Node3D:
	var root := Node3D.new()
	var clay := PropFactory.clay()
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.36
	sm.radial_segments = 14
	sm.rings = 7
	body.mesh = sm
	body.material_override = clay
	body.position = Vector3(0, 0.16, 0)
	root.add_child(body)
	var neck := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.08
	cm.height = 0.14
	cm.radial_segments = 12
	neck.mesh = cm
	neck.material_override = clay
	neck.position = Vector3(0, 0.37, 0)
	root.add_child(neck)
	return root
