class_name ActivityManager
extends Node
## Vice City-style activity culling: characters only cost CPU and GPU when the player could see them.
## Five times a second every villager, animal and enemy is sorted:
##  - mission characters (all enemies and monsters, and villagers standing at an active objective): active and
##    visible within MISSION_RANGE (100 m), whether on screen or not
##  - everyone else: visible within RANGE (50 m), and active only while on screen within RANGE, or within NEAR (6 m) in
##    any direction (so someone right behind the player still reacts)
##  - always active and visible: companions, police while the player is wanted, the knocked out and their rescue,
##    villagers fighting the player, animals pulling a cart, ridden or whistled, enemies close enough to chase
## Paused characters keep their place and pose and carry on when they come back into view.
## Only what this manager paused or hid is resumed or shown again, so other systems' own switches are respected.

const NEAR := 6.0               # was 12: the bazaar kept 55 characters active (perf run 2026-11-16)
const RANGE := 50.0
const MISSION_RANGE := 100.0
const TICK := 0.2

var main: Node3D
var player: Node3D
var enabled := true
var active_count := 0
var paused_count := 0
var hidden_count := 0

var _t := 0.0
var _obj_t := 0.0
var _objs: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--selftest" or a == "--audit" or a.begins_with("--capture"):
			enabled = false           # tests place characters behind the camera on purpose; the selftest checks this class itself


func _process(delta: float) -> void:
	if not enabled or player == null or not is_instance_valid(player):
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	tick()


## One sorting pass (also called directly by the selftest).
func tick() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var planes := cam.get_frustum()
	_obj_t -= TICK
	if _obj_t <= 0.0:
		_obj_t = 1.0
		_refresh_objectives()
	var pp := player.global_position
	active_count = 0
	paused_count = 0
	hidden_count = 0
	for g in ["npcs", "animals", "enemies"]:
		for n in get_tree().get_nodes_in_group(g):
			var b := n as Node3D
			if b == null or not b.is_inside_tree() or _gone(b):
				continue
			var d := b.global_position.distance_to(pp)
			var keep := _busy(b, d)
			var mission := _is_mission(b)
			var active: bool
			var vis: bool
			if keep:
				active = true
				vis = true
			elif mission:
				active = d < MISSION_RANGE
				vis = d < MISSION_RANGE
			else:
				vis = d < RANGE
				active = d < NEAR or (vis and on_screen(planes, b.global_position + Vector3(0, 1.0, 0), 2.0))
			_apply(b, active, vis)
			if active:
				active_count += 1
			else:
				paused_count += 1
			if not vis:
				hidden_count += 1


## Resume and show everything this manager paused or hid (when switching it off).
func release_all() -> void:
	for g in ["npcs", "animals", "enemies"]:
		for n in get_tree().get_nodes_in_group(g):
			var b := n as Node3D
			if b != null:
				_apply(b, true, true)


## True if a sphere at `p` with radius `r` is at least partly inside the camera frustum.
## Godot's frustum planes face outward, so a point more than `r` in front of any plane is outside.
static func on_screen(planes: Array, p: Vector3, r: float) -> bool:
	for pl in planes:
		if (pl as Plane).distance_to(p) > r:
			return false
	return true


func _refresh_objectives() -> void:
	_objs.clear()
	var st = main.get("story") if main != null else null
	if st == null or not st.has_method("active_objectives"):
		return
	for o in st.active_objectives(4):
		var tg = (o as Dictionary).get("target", Vector3.ZERO)
		if tg is Vector3 and tg != Vector3.ZERO:
			_objs.append(tg)


func _gone(b: Node3D) -> bool:
	# the dead manage their own processing (fall, then switch off or free); leave them alone
	if b is Npc:
		return (b as Npc).dead_forever
	return bool(b.get("dead")) if b.get("dead") != null else false


func _busy(b: Node3D, d: float) -> bool:
	if b is Npc:
		var n := b as Npc
		if n.companion or n.ko or n.in_care or n.rescue != null or n.angry_t > 0.0:
			return true
		if n.role == "police" and float(player.get("wanted_t")) > 0.0:
			return true
		return false
	if b is Animal:
		return (b as Animal).driven or player.get("ride") == b
	if b is Enemy:
		var e := b as Enemy
		return e.held or d < e.aggro + 5.0
	return false


func _is_mission(b: Node3D) -> bool:
	if b is Enemy:
		return true                 # enemies and monsters only appear for missions, bounties, raids and camps
	if b is Npc:
		for tg in _objs:
			if b.global_position.distance_to(tg) < 4.0:
				return true
	return false


func _apply(b: Node3D, active: bool, vis: bool) -> void:
	var paused := b.has_meta("_ac_paused")
	if not active and not paused:
		b.set_meta("_ac_paused", [b.is_processing(), b.is_physics_processing()])
		b.set_process(false)
		b.set_physics_process(false)
	elif active and paused:
		var st: Array = b.get_meta("_ac_paused")
		b.remove_meta("_ac_paused")
		b.set_process(bool(st[0]))
		b.set_physics_process(bool(st[1]))
	if not vis and b.visible:
		b.visible = false
		b.set_meta("_ac_hidden", true)
	elif vis and b.has_meta("_ac_hidden"):
		b.remove_meta("_ac_hidden")
		b.visible = true
