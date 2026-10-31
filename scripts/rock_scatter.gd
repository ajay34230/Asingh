class_name RockScatter
extends RefCounted
## Stones everywhere: boulders with collision, a field of low-poly eroded rocks, and pebbles/gravel
## scattered as MultiMeshes (culled by cell). Rocks are faceted meshes textured with the grainy
## sandstone material, in several tones so they do not all look alike.


static func build(parent: Node3D, terrain: TerrainBuilder) -> void:
	var root := Node3D.new()
	root.name = "Rocks"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var tones := [Color(0.62, 0.47, 0.31), Color(0.55, 0.50, 0.44), Color(0.70, 0.56, 0.40), Color(0.45, 0.36, 0.28), Color(0.66, 0.62, 0.56)]
	var mats: Array = []
	for t in tones:
		mats.append(PropFactory.stone(t, 0.5))
	var buckets: Array = []
	for i in 6:
		buckets.append([] as Array[Transform3D])
	var big := 0
	var tries := 0
	while tries < 6000 and (big < 46 or true):
		tries += 1
		if tries > 2600:
			break
		var x := rng.randf_range(-190.0, 190.0)
		var z := rng.randf_range(-190.0, 190.0)
		var y := terrain.sample_height(x, z)
		if y < 0.25:
			continue
		var near_town := Vector2(x - TerrainBuilder.TOWN_C.x, z - TerrainBuilder.TOWN_C.y).length() < 38.0
		var near_track := Vector2(x - TerrainBuilder.TRACK_C.x, z - TerrainBuilder.TRACK_C.y).length() < 70.0
		var on_road := terrain._path_distance(x, z) < 6.0
		var pond := Vector2(x - TerrainBuilder.POND_C.x, z - TerrainBuilder.POND_C.y).length() < TerrainBuilder.POND_R * 1.1
		if near_town or near_track or pond:
			continue
		var kind := rng.randf()
		if kind < 0.05 and big < 40 and not on_road:
			var s := rng.randf_range(0.9, 2.4)
			PropFactory.rock(root, Vector3(s, s * rng.randf_range(0.55, 0.9), s * rng.randf_range(0.8, 1.2)), Vector3(x, y + s * 0.1, z), mats[rng.randi() % mats.size()], rng.randf() * 360.0, s > 1.2)
			big += 1
			# a few rocks leaning against the boulder
			for k in rng.randi_range(2, 4):
				var a := rng.randf() * TAU
				var s2 := s * rng.randf_range(0.18, 0.4)
				var px := x + cos(a) * s * 1.2
				var pz := z + sin(a) * s * 1.2
				PropFactory.rock(root, Vector3(s2, s2 * 0.65, s2), Vector3(px, terrain.sample_height(px, pz) + s2 * 0.1, pz), mats[rng.randi() % mats.size()], rng.randf() * 360.0, false)
		else:
			var s := rng.randf_range(0.12, 0.5) if kind < 0.35 else rng.randf_range(0.04, 0.14)
			var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
			b = b.scaled(Vector3(s * rng.randf_range(0.8, 1.4), s * rng.randf_range(0.5, 0.9), s * rng.randf_range(0.8, 1.3)))
			(buckets[rng.randi() % 6] as Array[Transform3D]).append(Transform3D(b, Vector3(x, y + s * 0.15, z)))
			# gravel clusters
			if kind > 0.8:
				for k in 5:
					var a2 := rng.randf() * TAU
					var d2 := rng.randf_range(0.2, 0.9)
					var s3 := rng.randf_range(0.03, 0.09)
					var qx := x + cos(a2) * d2
					var qz := z + sin(a2) * d2
					var b3 := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s3, s3 * 0.6, s3))
					(buckets[rng.randi() % 6] as Array[Transform3D]).append(Transform3D(b3, Vector3(qx, terrain.sample_height(qx, qz) + s3 * 0.1, qz)))
	for i in 6:
		var xf: Array[Transform3D] = buckets[i]
		if xf.is_empty():
			continue
		Flora.scatter_cells(root, WeatheredMesh.rock(i, 5, 8, 0.32), mats[i % mats.size()], xf, "Stones%d" % i, "foliage_stone", 50.0)
	root.set_meta("boulders", big)
