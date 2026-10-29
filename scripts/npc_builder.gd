class_name NpcBuilder
extends RefCounted
## Places a handful of ambient villagers and workers around the hamlet, goods yard and caravan
## station. They only stand, breathe, look around or work (hammering); there is no dialogue,
## movement AI or story role. That belongs to later phases.

const PRESETS := {
	"blacksmith": {"scale": 1.0, "build": 1.18, "skin": Color(0.62, 0.43, 0.32), "hair_color": Color(0.05, 0.04, 0.04),
		"hair_style": 2, "beard": true, "top": Color(0.40, 0.33, 0.27), "bottom": Color(0.20, 0.17, 0.14),
		"accent": Color(0.25, 0.17, 0.12), "apron": true, "sleeves_rolled": true},
	"elder_woman": {"scale": 0.93, "build": 0.95, "female": true, "skin": Color(0.66, 0.48, 0.36), "hair_color": Color(0.62, 0.60, 0.58),
		"hair_style": 4, "top": Color(0.52, 0.20, 0.17), "bottom": Color(0.30, 0.22, 0.18), "accent": Color(0.70, 0.55, 0.30),
		"long_robe": true, "boots": false},
	"villager_man": {"scale": 0.99, "build": 1.0, "skin": Color(0.70, 0.50, 0.36), "hair_color": Color(0.06, 0.05, 0.05),
		"hair_style": 3, "beard": true, "top": Color(0.78, 0.74, 0.64), "bottom": Color(0.52, 0.46, 0.36),
		"accent": Color(0.50, 0.30, 0.18), "tunic": true},
	"rail_worker": {"scale": 1.0, "build": 1.06, "skin": Color(0.58, 0.40, 0.29), "hair_color": Color(0.05, 0.04, 0.03),
		"hair_style": 5, "top": Color(0.30, 0.36, 0.44), "bottom": Color(0.27, 0.27, 0.30),
		"accent": Color(0.55, 0.40, 0.20), "sleeves_rolled": true},
	"trader": {"scale": 0.97, "build": 0.98, "skin": Color(0.74, 0.55, 0.40), "hair_color": Color(0.10, 0.07, 0.05),
		"hair_style": 3, "top": Color(0.20, 0.40, 0.45), "bottom": Color(0.42, 0.33, 0.22),
		"accent": Color(0.72, 0.58, 0.25), "long_robe": true, "satchel": true},
	"weaver": {"scale": 0.95, "build": 0.97, "female": true, "skin": Color(0.72, 0.52, 0.38), "hair_color": Color(0.05, 0.04, 0.04),
		"hair_style": 1, "top": Color(0.78, 0.60, 0.22), "bottom": Color(0.34, 0.22, 0.30), "accent": Color(0.55, 0.20, 0.18),
		"tunic": true, "boots": false},
}


static func build(parent: Node3D, terrain: TerrainBuilder, houses: HouseBuilder, railway: RailwayBuilder, player: Node3D) -> Array[Npc]:
	var out: Array[Npc] = []
	var spots := []
	# Blacksmith at the anvil of house 2 (see HouseBuilder._exterior).
	var h2: Node3D = houses.houses[2].node
	var w2: float = houses.houses[2].half.x * 2.0
	var d2: float = houses.houses[2].half.y * 2.0
	spots.append(["blacksmith", "hammer", "Blacksmith", h2.global_transform * Vector3(-w2 * 0.5 - 2.4, 0.0, d2 * 0.5 - 1.6), h2.rotation.y + PI])
	# Elder by the well, villager in front of house 0, weaver in front of house 3.
	spots.append(["elder_woman", "idle", "Elder", _ground(terrain, -92.5, 14.0), deg_to_rad(80.0)])
	var h0: Node3D = houses.houses[0].node
	spots.append(["villager_man", "idle", "Villager", h0.global_transform * Vector3(3.8, 0.0, houses.houses[0].half.y + 4.5), h0.rotation.y + PI * 0.25])
	var h3: Node3D = houses.houses[3].node
	spots.append(["weaver", "idle", "Weaver", h3.global_transform * Vector3(-2.2, 0.0, houses.houses[3].half.y + 2.2), h3.rotation.y])
	# Goods yard: a worker by the dock ramp and the trader near the caravan station well.
	spots.append(["rail_worker", "idle", "RailWorker", _ground(terrain, railway.dock_ramp_foot.x - 2.5, railway.dock_ramp_foot.z - 3.0), deg_to_rad(-70.0)])
	spots.append(["trader", "idle", "Trader", _ground(terrain, 44.0, 44.0), deg_to_rad(200.0)])
	for s in spots:
		var n := Npc.new().setup(PRESETS[s[0]], s[1], s[2])
		n.player = player
		parent.add_child(n)
		n.global_position = s[3]
		n.rotation.y = s[4]
		out.append(n)
	return out


static func _ground(terrain: TerrainBuilder, x: float, z: float) -> Vector3:
	return Vector3(x, terrain.sample_height(x, z), z)
