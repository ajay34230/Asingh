class_name DogCompanion
extends Node
## Moti, the stray husky by the village. Make friends with him and he stays at your side for good:
##   - follows you everywhere, keeping a step behind, and gallops alongside when you ride
##   - sniffs out gold coins nearby and fetches them, and digs and barks at buried caches
##   - joins fights: runs at the nearest enemy and bites (staggering men, nipping at monsters)
##   - pet him (USE when close) for a wag and a little health; five pets = "Best Friends"
## Adoption is saved as the story flag "dog_adopted".

const NAME := "Moti"
const STRAY_AT := Vector3(-80.0, 0.0, 4.0)

var main: Node3D
var player: Player
var story: Story
var terrain: TerrainBuilder
var hud: Node
var dog: Animal
var adopted := false
var mode := "follow"              # follow, fetch, alert, fight, pet
var finds := 0
var bites := 0
var _it: Interactable
var _tag: Label3D
var _goal: Node3D
var _goal_kind := ""
var _alerted := {}                # cache index -> true, so each cache is announced once
var _scan_t := 0.0
var _bite_cd := 0.0
var _mode_t := 0.0
var _bark_t := 0.0
var _pet_heal_t := 0.0
var _foe: Node3D


func build() -> void:
	add_to_group("dog_companion")
	var best: Animal = null
	var bd := INF
	for c in main.life:
		var a := c as Animal
		if a == null or a.species != "dog":
			continue
		var d := a.global_position.distance_to(STRAY_AT)
		if d < bd:
			bd = d
			best = a
	dog = best
	if dog == null:
		return
	_it = Interactable.new()
	_it.position = Vector3(0, 0.7, 0)
	_it.reach = 2.4
	_it.prompt = "Make friends with the stray dog"
	_it.on_interact = func(_by: Node3D, _me: Interactable) -> void: (pet() if adopted else adopt())
	dog.add_child(_it)
	_tag = Label3D.new()
	_tag.text = NAME
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.font_size = 40
	_tag.pixel_size = 0.006
	_tag.outline_size = 8
	_tag.modulate = Color(1.0, 0.92, 0.7)
	_tag.position = Vector3(0, 1.25, 0)
	_tag.visible = false
	dog.add_child(_tag)
	_collar()
	if bool(story.get_flag("dog_adopted", false)):
		adopt(true)
	finds = int(story.get_flag("dog_finds", 0))


## A red collar with a brass bell, so you can tell Moti from the village dogs.
func _collar() -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.09
	tm.outer_radius = 0.12
	tm.rings = 12
	tm.ring_segments = 6
	var ring := MeshInstance3D.new()
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.1, 0.08)
	m.roughness = 0.6
	ring.material_override = m
	ring.position = Vector3(0, 0.62, -0.32)
	ring.rotation = Vector3(1.2, 0, 0)
	ring.visible = false
	ring.name = "Collar"
	dog.add_child(ring)
	var bell := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	bell.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.85, 0.65, 0.25)
	bm.metallic = 0.9
	bm.roughness = 0.3
	bell.material_override = bm
	bell.position = Vector3(0, -0.1, 0.0)
	ring.add_child(bell)


func adopt(silent: bool = false) -> void:
	if dog == null:
		return
	adopted = true
	dog.driven = true
	story.set_flag("dog_adopted", true)
	_it.prompt = "Pet %s" % NAME
	_tag.visible = true
	var col := dog.get_node_or_null("Collar") as Node3D
	if col != null:
		col.visible = true
	mode = "follow"
	if silent:
		_place_near_player()
		return
	_bark()
	if hud != null and hud.has_method("banner"):
		hud.banner(Loc.t("Moti is your dog now!") + "\n" + Loc.t("He follows you, finds hidden coins and treasure, and bites your enemies."), "seal_found")


func pet() -> void:
	mode = "pet"
	_mode_t = 0.0
	_bark()
	FloatText.spawn(main, dog.global_position + Vector3(0, 1.3, 0), Loc.t("Wag wag!"), Color(1.0, 0.75, 0.8), 1.0, 1.0, 1.2)
	if _pet_heal_t <= 0.0 and player.hp < player.max_hp:
		player.heal(10.0)
		_pet_heal_t = 60.0
	var n := int(story.get_flag("dog_pets", 0)) + 1
	story.set_flag("dog_pets", n)
	var ach := get_tree().get_first_node_in_group("achievements")
	if ach != null and n >= 5:
		ach.call("unlock", "best_friend")


func _bark() -> void:
	if dog == null:
		return
	Sfx.at("dog_bark_%d" % randi_range(0, 2), dog.global_position + Vector3(0, 0.6, 0), -2.0, randf_range(0.95, 1.1))
	_bark_t = 0.0


func _place_near_player() -> void:
	var back := Vector3(sin(player._yaw), 0.0, cos(player._yaw))
	var p := player.global_position + back * 3.0 + Vector3(cos(player._yaw), 0, -sin(player._yaw)) * 1.0
	p.y = terrain.sample_height(p.x, p.z)
	dog.global_position = p
	dog.home = p


# --- moving the dog ----------------------------------------------------------------------------

## Runs toward `p` at `speed` m/s with the right gait. Returns true once within `near` metres.
func _run_to(p: Vector3, speed: float, delta: float, near: float = 0.9) -> bool:
	var to := p - dog.global_position
	to.y = 0.0
	if to.length() < near:
		_anim(dog._idle, 1.0)
		return true
	dog.rotation.y = lerp_angle(dog.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-8.0 * delta))
	var fwd := Vector3(-sin(dog.rotation.y), 0.0, -cos(dog.rotation.y))
	var step := minf(speed * delta, to.length())
	var np := dog.global_position + fwd * step
	np.y = terrain.sample_height(np.x, np.z)
	dog.global_position = np
	if speed > 3.5 and dog._has_gallop:
		_anim(dog._gallop, clampf(speed / 7.0, 0.8, 1.8))
	else:
		_anim(dog._walk, clampf(speed / 1.8, 0.7, 2.0))
	return false


func _anim(clip: String, spd: float) -> void:
	if dog._anim == null or clip == "" or not dog._anim.has_animation(clip):
		return
	if dog._anim.current_animation != clip:
		dog._anim.play(clip, 0.2)
	dog._anim.speed_scale = spd


func _face(p: Vector3, delta: float) -> void:
	var to := p - dog.global_position
	to.y = 0.0
	if to.length() > 0.1:
		dog.rotation.y = lerp_angle(dog.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-6.0 * delta))


# --- behaviour -------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not adopted or dog == null or not is_instance_valid(dog) or player == null:
		return
	_scan_t -= delta
	_bite_cd -= delta
	_mode_t += delta
	_bark_t += delta
	_pet_heal_t -= delta
	_tag.visible = dog.global_position.distance_to(player.global_position) < 14.0
	var d := dog.global_position.distance_to(player.global_position)
	if d > 45.0 and mode != "alert":
		_place_near_player()                      # fast travel, a cut-scene, a long gallop: he catches up
		mode = "follow"
	if _scan_t <= 0.0:
		_scan_t = 0.4
		_look_around()
	match mode:
		"pet":
			_face(player.global_position, delta)
			_anim(dog._idle2 if dog._idle2 != "" else dog._idle, 1.2)
			if _mode_t > 1.6:
				mode = "follow"
		"fight":
			_fight(delta)
		"fetch":
			if not is_instance_valid(_goal):
				mode = "follow"
			elif _run_to(_goal.global_position, 6.5, delta, 0.8):
				_fetched()
			elif _mode_t > 12.0:
				mode = "follow"
		"alert":
			# at a buried cache: dig and bark until you come over (or you walk away)
			if not is_instance_valid(_goal) or not _goal.visible:
				mode = "follow"
			elif _run_to(_goal.global_position + (dog.global_position - _goal.global_position).normalized() * 0.9, 6.0, delta, 0.5):
				_face(_goal.global_position, delta)
				_anim(dog._headlow if dog._headlow != "" else dog._idle, 1.4)
				if _bark_t > 1.8:
					_bark()
				if d < 3.0 or d > 30.0 or _mode_t > 25.0:
					mode = "follow"
		_:
			_follow(delta, d)


func _follow(delta: float, d: float) -> void:
	var yaw := player._model.rotation.y
	var back := Vector3(sin(yaw), 0.0, cos(yaw))
	var side := Vector3(cos(yaw), 0.0, -sin(yaw))
	var spot := player.global_position + back * 2.2 + side * 1.1
	var ride := player.mounted
	if ride:
		spot = player.global_position + side * 2.4 + back * 0.6     # running at the horse's flank
	var gap := dog.global_position.distance_to(spot)
	var speed := 0.0
	if ride:
		speed = clampf(gap * 3.0, 0.0, 14.0)
	elif gap > 6.0:
		speed = 7.5
	elif gap > 1.2:
		speed = lerpf(2.0, 5.0, clampf((gap - 1.2) / 4.8, 0.0, 1.0))
	if speed > 0.2:
		_run_to(spot, speed, delta, 0.3)
	else:
		_face(player.global_position, delta)
		_anim(dog._idle, 1.0)


## Every few tenths of a second: enemies first, then treasure.
func _look_around() -> void:
	if mode == "pet":
		return
	# a fight near the player: go for the nearest foe
	var foe: Node3D = null
	var fd := 12.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead or en.get("surrendered") == true:
			continue
		var dd := en.global_position.distance_to(player.global_position)
		if dd < fd:
			fd = dd
			foe = en
	if foe != null:
		if mode != "fight" or _foe != foe:
			_foe = foe
			if mode != "fight":
				_bark()
			mode = "fight"
			_mode_t = 0.0
		return
	if mode == "fight":
		mode = "follow"
	if mode != "follow" or player.mounted:
		return
	# gold coins lying within sniffing range
	var cs = main.get("coin_sys")
	if cs != null:
		var best: Node3D = null
		var bd := 20.0
		for c in cs.coins:
			var n := c["node"] as Node3D
			if n == null or not is_instance_valid(n):
				continue
			var dd := n.global_position.distance_to(player.global_position)
			if dd < bd:
				bd = dd
				best = n
		if best != null:
			_goal = best
			_goal_kind = "coin"
			mode = "fetch"
			_mode_t = 0.0
			_bark()
			return
	# buried caches
	var sec = main.get("secrets")
	if sec != null:
		for i in sec.nodes.size():
			var n: Node3D = sec.nodes[i]
			if _alerted.has(i) or not n.visible or bool(story.get_flag("cache_%d" % i, false)):
				continue
			if n.global_position.distance_to(player.global_position) < 26.0:
				_alerted[i] = true
				_goal = n
				_goal_kind = "cache"
				mode = "alert"
				_mode_t = 0.0
				_bark()
				player.message.emit(Loc.t("Moti smells something buried! Follow him."))
				return


func _fetched() -> void:
	if _goal_kind == "coin":
		var cs = main.get("coin_sys")
		if cs != null:
			for i in cs.coins.size():
				if cs.coins[i]["node"] == _goal:
					cs.collect(i)
					finds += 1
					story.set_flag("dog_finds", finds)
					FloatText.spawn(main, dog.global_position + Vector3(0, 1.2, 0), Loc.t("Moti found a coin!"), Color(1.0, 0.85, 0.3), 0.9, 1.0, 1.2)
					break
	mode = "follow"


func _fight(delta: float) -> void:
	if not is_instance_valid(_foe) or (_foe as Enemy).dead:
		mode = "follow"
		return
	var fp := _foe.global_position
	var to := fp - dog.global_position
	to.y = 0.0
	var reach := 1.3 + (float(_foe.get("reach")) * 0.4 if _foe.get("reach") != null else 0.0)
	if to.length() > reach:
		_run_to(fp, 8.0, delta, reach)
		return
	_face(fp, delta)
	if _bite_cd <= 0.0:
		_bite_cd = 1.1
		bites += 1
		var en := _foe as Enemy
		en.take_hit("bite", 6.0, to.normalized())
		if not (en is Monster) and not en.dead:
			en.stagger(0.35)
		Sfx.at("dog_bark_%d" % randi_range(0, 2), dog.global_position + Vector3(0, 0.6, 0), -4.0, 1.25)
		_anim(dog._kick if dog._kick != "" else dog._idle, 1.6)
	elif _bite_cd < 0.7:
		_anim(dog._idle2 if dog._idle2 != "" else dog._idle, 1.4)
