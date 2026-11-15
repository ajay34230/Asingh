class_name PoliceForce
extends Node
## The town police (constables in khaki with lathis). Once the player is wanted (hitting villagers), a pair
## comes running from out of sight a few seconds later; more come if the player fights them. They chase and
## strike with the lathi; a player beaten low is arrested (fined, taken to the chowki, wanted cleared) rather
## than killed. When the wanted time runs out they give up and walk away.

const PRESET := {"role": "police", "voice": "deep", "body": "veteran", "robe": true, "scale": 1.03, "tint": Color(0.78, 0.66, 0.42)}
const CHOWKI := Vector2(-30.0, -32.0)        # where an arrested player is let go, at the bazaar's west side
const FIRST_DELAY := 6.0

static var _inst: PoliceForce

var main: Node3D
var player: Player
var officers: Array[Npc] = []
var heat := 0                    # officers hit by the player: more come
var _wanted_for := 0.0
var _leave_t := 0.0
var _seq := 0


func setup(m: Node3D, p: Player) -> PoliceForce:
	main = m
	player = p
	name = "PoliceForce"
	_inst = self
	return self


func want() -> int:
	if player.wanted_t <= 0.0:
		return 0
	return mini(2 + 2 * int(player.assaults >= 7) + heat, 5)


func _process(delta: float) -> void:
	if player == null or get_tree().paused:
		return
	officers = officers.filter(func(o: Variant) -> bool: return is_instance_valid(o))
	var w := want()
	if w > 0 and not player.dead:
		_wanted_for += delta
		_leave_t = 0.0
		if _wanted_for >= FIRST_DELAY:
			var up := officers.filter(func(o: Npc) -> bool: return not o.ko).size()
			if up < w and (Engine.get_process_frames() % 30) == 0:
				_spawn()
	else:
		_wanted_for = 0.0
		if not officers.is_empty():
			_leave_t += delta
			if _leave_t > 10.0:
				for o in officers:
					if not o.ko and not o.in_care:
						o.queue_free()
				officers = officers.filter(func(o: Variant) -> bool: return is_instance_valid(o) and not (o as Npc).is_queued_for_deletion())
		heat = 0
	# lost them far behind: they go back; new ones come if still wanted
	for o in officers:
		if not o.ko and not o.in_care and o.global_position.distance_to(player.global_position) > 140.0:
			o.queue_free()


func _spawn() -> void:
	var terrain: Variant = main.get("terrain")
	if terrain == null:
		return
	# from behind the camera, out of sight, about 30 m away
	var cam := get_viewport().get_camera_3d()
	var back := Vector3.BACK
	if cam != null:
		back = cam.global_transform.basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.1 else Vector3.BACK
	var side := back.cross(Vector3.UP) * randf_range(-12.0, 12.0)
	var at := player.global_position + back * randf_range(26.0, 34.0) + side
	_seq += 1
	var n := Npc.new().setup(PRESET.duplicate(), "idle", "Constable%d" % _seq)
	n.player = player
	main.add_child(n)
	n.global_position = Vector3(at.x, float(terrain.call("sample_height", at.x, at.z)), at.z)
	n.rig.set_weapon("lathi")
	n.add_to_group("police")
	officers.append(n)
	var npcs: Variant = main.get("npcs")
	if npcs is Array:
		(npcs as Array).append(n)
	if officers.size() == 1 or _seq % 2 == 1:
		Sfx.ui("whistle", -4.0)
		var hud: Object = main.get("hud")
		if hud != null and officers.size() <= 2:
			hud.call("banner", Loc.t("POLICE! The constables are coming. Run, or stop fighting."), "")
	LogCollector.event("police: constable %d sent (wanted %.0fs, assaults %d)" % [_seq, player.wanted_t, player.assaults])


## The player hit an officer: more come.
static func officer_hit() -> void:
	if _inst != null:
		_inst.heat = mini(_inst.heat + 1, 3)


## Beaten down by the police: fined, taken to the chowki, and let go with a warning.
static func arrest(p: Player) -> void:
	if _inst == null or p.dead:
		return
	_inst._do_arrest()


func _do_arrest() -> void:
	var cs: Object = main.get("coin_sys")
	var fine := 0
	if cs != null:
		fine = mini(int(cs.call("balance")), maxi(25, int(cs.call("balance")) / 5))
		if fine > 0:
			cs.call("spend", fine)
	player.wanted_t = 0.0
	player.assaults = 0
	player.hp = maxf(player.hp, player.max_hp * 0.5)
	for o in officers:
		if is_instance_valid(o) and not o.ko and not o.in_care:
			o.queue_free()
	officers.clear()
	heat = 0
	var terrain: Variant = main.get("terrain")
	if terrain != null and main.has_method("_teleport"):
		main.call("_teleport", CHOWKI.x, CHOWKI.y)
	player.velocity = Vector3.ZERO
	var hud: Object = main.get("hud")
	if hud != null:
		hud.call("banner", Loc.tf("ARRESTED! Fined %d coins at the police chowki.", [fine]) + "\n" + Loc.t("Hitting people brings the police. Behave in town."), "")
	Sfx.ui("whistle", -6.0)
	LogCollector.event("police: arrested, fined %d" % fine)
