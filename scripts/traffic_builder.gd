class_name TrafficBuilder
extends Node
## Local traffic on the valley's roads, like a living region: bull, camel and donkey carts with seated
## drivers going to and fro between the village, the temple, the Bazaar, the race track and the caravan
## station; riders on horseback and camelback; and travellers on foot with loads. Carts slow down and
## ring a bell when the player stands in the road ahead. Everyone goes quiet at night.

const C := TerrainBuilder.TOWN_C

## kind, speed (m/s), the road as a polyline (carts run out and back along it)
const CARTS: Array = [
	["bull", 1.9, [Vector2(-90, 12), Vector2(-60, 0), Vector2(-40, -20), Vector2(-28, -40), Vector2(-4, -42)]],
	["camel", 2.2, [Vector2(40, -42), Vector2(70, -42), Vector2(100, -46), Vector2(112, -48)]],
	["donkey", 1.8, [Vector2(22, -20), Vector2(22, 4), Vector2(38, 30), Vector2(50, 46)]],
	["bull", 1.6, [Vector2(22, -64), Vector2(22, -86), Vector2(8, -110)]],
]
## kind of animal, speed, road, and the rider's look
const RIDERS: Array = [
	["horse", 4.2, [Vector2(-86, 8), Vector2(-60, -2), Vector2(-38, -22), Vector2(-26, -40), Vector2(0, -42)], "guard"],
	["camel", 3.0, [Vector2(48, 44), Vector2(36, 28), Vector2(22, 2), Vector2(22, -20)], "trader"],
	["horse_white", 4.6, [Vector2(44, -42), Vector2(78, -44), Vector2(108, -48)], "huntress"],
]
## travellers on foot: preset, road
const WALKERS: Array = [
	["farmer", [Vector2(-80, 14), Vector2(-60, 2), Vector2(-40, -18), Vector2(-28, -38)]],
	["weaver", [Vector2(-28, -38), Vector2(-40, -18), Vector2(-62, 0), Vector2(-82, 14)]],
	["shepherd", [Vector2(-20, -40), Vector2(-4, -43), Vector2(-24, -42), Vector2(-36, -24)]],
	["worker2", [Vector2(48, -42), Vector2(80, -44), Vector2(104, -48), Vector2(80, -44)]],
	["lady_green", [Vector2(24, -18), Vector2(24, 4), Vector2(34, 22), Vector2(24, 4)]],
	["villager_man", [Vector2(22, -66), Vector2(22, -84), Vector2(12, -104), Vector2(22, -84)]],
	["merchant", [Vector2(40, 30), Vector2(26, 8), Vector2(24, -16), Vector2(26, 8)]],
	["worker_woman", [Vector2(-56, 2), Vector2(-38, -20), Vector2(-58, 2), Vector2(-84, 12)]],
]

var main: Node3D
var terrain: TerrainBuilder
var player: Player
var wagons: Array[Wagon] = []
var riders: Array[Traveller] = []
var walkers: Array[Npc] = []
var done := false                # everyone is spawned (one per frame, so the world loads quickly)


func _init(m: Node3D, t: TerrainBuilder, p: Player) -> void:
	main = m
	terrain = t
	player = p
	name = "Traffic"


func _out_and_back(pts: Array) -> Array[Vector2]:
	var r: Array[Vector2] = []
	for p in pts:
		r.append(p)
	for i in range(pts.size() - 2, 0, -1):
		r.append(pts[i])
	return r


func build() -> void:
	main.add_child(self)
	_spawn.call_deferred()


func _spawn() -> void:
	for c in CARTS:
		var w := Wagon.new().setup(terrain, player, c[0], _out_and_back(c[2]), float(c[1]))
		w.yields_to_player = true
		main.add_child(w)
		var driver := _driver(w, "driver_%s" % c[0])
		w.driver = driver
		wagons.append(w)
		await get_tree().process_frame
	for r in RIDERS:
		var t := Traveller.new(terrain, player, r[0], _out_and_back(r[2]), float(r[1]), _preset(r[3]))
		main.add_child(t)
		riders.append(t)
		await get_tree().process_frame
	var i := 0
	for wk in WALKERS:
		var n := Npc.new().setup(_preset(wk[0]), "idle", "Traveller%d" % i)
		n.player = player
		var pts: Array = []
		for p in wk[1]:
			pts.append(Vector3(p.x, terrain.sample_height(p.x, p.y), p.y))
		n.routine = {"type": "walk", "points": pts, "home": pts[0]}
		main.add_child(n)
		n.global_position = pts[0]
		walkers.append(n)
		i += 1
		await get_tree().process_frame
	done = true


func _preset(key: String) -> Dictionary:
	return (NpcBuilder.PRESETS[key] as Dictionary).duplicate()


func _driver(w: Wagon, label: String) -> Npc:
	var n := Npc.new().setup(_preset("villager2"), "sit", label)
	n.player = player
	w.seat.add_child(n)
	n.position = Vector3(0, -0.55, 0)
	return n
