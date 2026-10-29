class_name LifeBuilder
extends RefCounted
## Ambient animals and carts: livestock around the village, dogs, a camel-style train at the
## caravan station, wild deer and foxes at the edges, a bailgaadi (bullock cart) and an uthgaadi
## (camel-style cart) on slow loops.

static func build(parent: Node3D, terrain: TerrainBuilder, houses: HouseBuilder, railway: RailwayBuilder, player: Node3D) -> Array:
	var out: Array = []
	var spots := [
		# kind, x, z, wander radius
		["cow", -84.0, 30.0, 9.0], ["cow", -90.0, 34.0, 9.0], ["bull", -70.0, 30.0, 8.0],
		["cow", -110.0, -4.0, 8.0], ["donkey", -60.0, -24.0, 7.0], ["donkey", -112.0, 22.0, 7.0],
		["horse", -94.0, -34.0, 8.0], ["horse_white", -58.0, 24.0, 9.0],
		["dog", -80.0, 4.0, 14.0], ["dog", -100.0, 14.0, 12.0], ["shiba", -72.0, -8.0, 10.0],
		["camel", 52.0, 52.0, 5.0], ["camel", 56.0, 44.0, 5.0], ["donkey", 36.0, 56.0, 6.0],
		["deer", -150.0, 70.0, 20.0], ["stag", -156.0, 62.0, 20.0], ["fox", -140.0, -60.0, 20.0],
		["fox", 90.0, 120.0, 25.0], ["deer", 110.0, 110.0, 20.0],
	]
	for s in spots:
		var a := Animal.new().setup(s[0], terrain, player, Vector3.ZERO, s[3])
		parent.add_child(a)
		var x: float = s[1]
		var z: float = s[2]
		a.home = Vector3(x, 0.0, z)
		a.global_position = Vector3(x, terrain.sample_height(x, z), z)
		a.rotation.y = randf() * TAU
		out.append(a)
	# Bailgaadi: two bulls, loop through the village outskirts.
	var bail: Array[Vector2] = [Vector2(-40, 20), Vector2(-40, 50), Vector2(-20, 66), Vector2(10, 66), Vector2(10, 40), Vector2(-14, 24)]
	var w1 := Wagon.new().setup(terrain, player, "bull", bail, 1.3)
	parent.add_child(w1)
	out.append(w1)
	# Uthgaadi: two camel-style animals, a longer loop near the caravan station.
	var uth: Array[Vector2] = [Vector2(30, 20), Vector2(70, 20), Vector2(82, 40), Vector2(70, 70), Vector2(30, 70), Vector2(20, 44)]
	var w2 := Wagon.new().setup(terrain, player, "camel", uth, 1.5)
	parent.add_child(w2)
	out.append(w2)
	return out
