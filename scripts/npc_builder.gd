class_name NpcBuilder
extends RefCounted
## Places a handful of ambient villagers and workers around the hamlet, goods yard and caravan
## station. They only stand, breathe, look around or work (hammering); there is no dialogue,
## movement AI or story role. That belongs to later phases.

const PRESETS := {
	"blacksmith": {"role": "blacksmith", "voice": "deep", "body": "brute", "robe": true, "scale": 1.03, "tool": "hammer"},
	"elder_woman": {"role": "elder", "voice": "old", "body": "elder", "robe": true, "scale": 0.93},
	"villager_man": {"role": "villager", "voice": "man", "body": "veteran", "robe": true, "scale": 0.98},
	"rail_worker": {"role": "worker", "voice": "man", "body": "whelp", "robe": true, "scale": 1.0, "tint": Color(0.72, 0.78, 0.9)},
	"trader": {"role": "trader", "voice": "man", "body": "striker_mail", "robe": true, "scale": 0.97, "tint": Color(0.85, 0.95, 0.95)},
	"weaver": {"role": "weaver", "voice": "woman", "body": "thief", "robe": true, "scale": 0.95},
	"farmer": {"role": "farmer", "voice": "man", "body": "m_Farmer", "scale": 1.0},
	"chief": {"role": "chief", "voice": "deep", "body": "m_King", "scale": 1.02},
	"worker2": {"role": "worker", "voice": "deep", "body": "m_Worker", "scale": 1.0},
	"guide": {"role": "guide", "voice": "man", "body": "m_Adventurer", "scale": 1.0},
	"merchant": {"role": "trader", "voice": "man", "body": "m_Suit", "scale": 1.0},
	"villager2": {"role": "villager", "voice": "man", "body": "m_Casual", "scale": 0.98},
	"lady_green": {"role": "weaver", "voice": "woman", "body": "w_Formal", "scale": 0.96},
	"lady_medieval": {"role": "villager", "voice": "old", "body": "w_Medieval", "scale": 0.96},
	"worker_woman": {"role": "worker", "voice": "woman", "body": "w_Worker", "scale": 0.97},
	"girl_casual": {"role": "girl", "voice": "girl", "body": "w_Casual", "scale": 0.94},
	"huntress": {"role": "traveller", "voice": "woman", "body": "huntress", "robe": true, "scale": 0.97},
	"potter": {"role": "worker", "voice": "man", "body": "m_Worker", "scale": 0.99, "tint": Color(1.0, 0.85, 0.7)},
	"shepherd": {"role": "villager", "voice": "old", "body": "m_Casual", "scale": 0.97, "tint": Color(0.8, 1.0, 0.8)},
	"child_a": {"role": "girl", "voice": "girl", "body": "w_Casual", "scale": 0.68, "tint": Color(1.0, 0.8, 0.9)},
	"child_b": {"role": "boy", "voice": "girl", "body": "m_Casual", "scale": 0.7, "tint": Color(0.8, 0.9, 1.0)},
	"guard": {"role": "guard", "voice": "deep", "body": "veteran", "robe": true, "scale": 1.03, "tint": Color(0.75, 0.82, 0.95)},
	"priest": {"role": "priest", "voice": "old", "body": "elder", "robe": true, "scale": 0.99, "tint": Color(1.0, 0.95, 0.85)},
	"cook": {"role": "worker", "voice": "woman", "body": "w_Worker", "scale": 1.0, "tint": Color(1.0, 0.9, 0.75)},
	"scholar": {"role": "scholar", "voice": "man", "body": "m_Suit", "scale": 0.97, "tint": Color(0.8, 0.85, 1.0)},
	"dancer": {"role": "villager", "voice": "woman", "body": "w_Formal", "scale": 0.98, "tint": Color(1.0, 0.7, 0.7)},
	"sorceress": {"role": "traveller", "voice": "woman", "body": "sorceress", "robe": true, "scale": 0.97},
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
	# More people: farmers and villagers about the houses, workers at the goods yard, a guide at the
	# start, merchants at the caravan station.
	var h1: Node3D = houses.houses[1].node
	spots.append(["farmer", "idle", "Farmer", h1.global_transform * Vector3(4.5, 0.0, houses.houses[1].half.y + 5.0), h1.rotation.y + PI * 0.8])
	spots.append(["chief", "idle", "Chief", _ground(terrain, -86.0, 18.5), deg_to_rad(-100.0)])
	spots.append(["worker2", "idle", "YardWorker", _ground(terrain, railway.dock_ramp_foot.x - 6.0, railway.dock_ramp_foot.z - 5.0), deg_to_rad(120.0)])
	spots.append(["lady_green", "idle", "VillagerGreen", h3.global_transform * Vector3(3.2, 0.0, houses.houses[3].half.y + 3.4), h3.rotation.y + 0.6])
	var h4: Node3D = houses.houses[4].node
	spots.append(["villager2", "idle", "Villager2", h4.global_transform * Vector3(-3.5, 0.0, houses.houses[4].half.y + 4.0), h4.rotation.y - 0.5])
	spots.append(["lady_medieval", "idle", "Villager3", _ground(terrain, -94.0, 9.0), deg_to_rad(40.0)])
	spots.append(["girl_casual", "idle", "Villager4", _ground(terrain, -80.0, -28.0), deg_to_rad(170.0)])
	spots.append(["merchant", "idle", "Merchant", _ground(terrain, 47.5, 41.5), deg_to_rad(20.0)])
	spots.append(["huntress", "idle", "Traveller", _ground(terrain, 40.0, 48.0), deg_to_rad(-40.0)])
	var sp := TerrainBuilder.START_MOUND
	spots.append(["guide", "idle", "Guide", _ground(terrain, sp.x + 3.0, sp.y - 3.5), deg_to_rad(200.0)])
	# Phase 5: more people. Village life around the well, the caravan stop and the gate forecourt.
	spots.append(["potter", "idle", "Potter", _ground(terrain, -99.0, 4.0), deg_to_rad(60.0)])
	spots.append(["shepherd", "idle", "Shepherd", _ground(terrain, -74.0, 6.0), deg_to_rad(-120.0)])
	spots.append(["child_a", "idle", "ChildA", _ground(terrain, -88.0, 22.0), deg_to_rad(10.0)])
	spots.append(["child_b", "idle", "ChildB", _ground(terrain, -86.0, 24.5), deg_to_rad(190.0)])
	spots.append(["priest", "idle", "Priest", _ground(terrain, -104.0, 24.0), deg_to_rad(90.0)])
	spots.append(["cook", "idle", "Cook", _ground(terrain, 51.0, 51.5), deg_to_rad(250.0)])
	spots.append(["dancer", "idle", "Dancer", _ground(terrain, 37.0, 41.0), deg_to_rad(120.0)])
	spots.append(["scholar", "idle", "Scholar", _ground(terrain, 104.0, 152.0), deg_to_rad(200.0)])
	spots.append(["guard", "idle", "GuardA", _ground(terrain, -6.0, -126.0), deg_to_rad(180.0)])
	spots.append(["guard", "idle", "GuardB", _ground(terrain, 6.0, -126.0), deg_to_rad(180.0)])
	for s in spots:
		var n := Npc.new().setup(PRESETS[s[0]], s[1], s[2])
		n.player = player
		n.home_yaw = s[4]
		parent.add_child(n)
		n.global_position = s[3]
		n.rotation.y = s[4]
		out.append(n)
	return out


static func _ground(terrain: TerrainBuilder, x: float, z: float) -> Vector3:
	return Vector3(x, terrain.sample_height(x, z), z)
