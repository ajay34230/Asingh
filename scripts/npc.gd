class_name Npc
extends Node3D
## An ambient villager (no story role yet): a RealHuman that idles, works and REACTS to the player:
## turns to face and look at them, greets (namaste / wave), chats when they linger, startles when
## they run past, laughs when they jump, says farewell as they leave, and does small random idle
## actions when nobody is near. Speech is a floating line of text with voice babble (placeholder
## lines, no plot). Animation and behaviour only run while the player is within ANIM_RANGE.

const ANIM_RANGE := 70.0
const NOTICE := 9.0
const GREET := 6.0

const GREETINGS := [
	"Namaste, traveller!", "Welcome, friend. Safe journey!", "Ah, a new face. Namaste!",
	"Salaam! The road is long, eh?", "Good day to you, musafir!", "Hello there! Mind the sun.",
]
const FAREWELLS := ["Safe travels!", "Come back soon, friend.", "May the road be kind.", "Khuda hafiz!", "Go well, traveller."]
const STARTLES := ["Hey! Slow down!", "Careful, careful!", "Arre! Watch your step!", "Whoa, where is the fire?"]
const LAUGHS := ["Ha ha! What a leap!", "Wah! Like a goat!", "Ha! Nicely jumped!", "Haha, show-off!"]
const WORK_SOUND := {"hammer": "anvil", "scrub": "scrub", "sweep": "sweep", "stir": "pot_clink", "knead": "knead", "chop": "chop"}
const HAWK_LINES := {
	"fruit": ["Fresh mangoes! Sweet as honey!", "Pomegranates, come and taste!", "Bananas, bananas, two for a coin!"],
	"spice": ["Turmeric, cumin, pepper, buy buy!", "Fresh spices, the best in the land!"],
	"cloth": ["Silk and cotton, come and feel!", "Colours that never fade!"],
	"pot": ["Clay pots, strong and cool!", "Water stays sweet in my pots!"],
	"tea": ["Hot chai, hot chai!", "Ginger tea, warm your bones!"],
	"sweet": ["Fresh jalebi, hot and crisp!", "Laddoos! Sweets for the little ones!"],
	"general": ["Come, come, look at my wares!", "Best price in the bazaar!", "For you, special price!"],
}
const HAGGLE_LINES := ["Too much! Half the price!", "Arre, you ruin me! Fine, take it.", "Last price, final!", "Add one more and we have a deal.", "Twenty? You joke!"]
const IDLE_ACTIONS := ["stretch", "look_around", "wipe_brow", "look_around", "stretch"]
const ROLE_LINES := {
	"blacksmith": ["Mind the sparks, friend!", "Good iron needs patience.", "A hammer never lies about the work.", "Need a tool mended?"],
	"elder": ["The sand remembers what men forget.", "Sit, rest. The day is long.", "Water is worth more than gold here.", "I have seen many seasons pass."],
	"villager": ["Quiet day, thank the heavens.", "The wind brings dust again.", "My goats know the weather better than I do.", "Have you eaten yet?"],
	"farmer": ["No rain again. We wait.", "The soil is thirsty, so are we.", "A little barley, a little hope.", "Do you know the clouds, traveller?"],
	"trader": ["Spices, cloth, rope: fair prices!", "Best salt on this side of the dunes!", "Take a look, no cost to look!", "The caravan leaves at dusk."],
	"worker": ["The goods train is never on time.", "Heavy crates, light pay.", "Mind the rails, friend.", "Another load for the dock."],
	"weaver": ["Thread by thread, day by day.", "This pattern is my grandmother's.", "Feel the cloth. Finest wool.", "The loom hums as I think."],
	"chief": ["This village has stood a long time.", "Strangers are guests here. Be welcome.", "We keep our wells and our word.", "Walk wisely, traveller."],
	"guide": ["The old ruins lie ahead, past the statues.", "Keep your water close.", "I know these dunes well.", "Stay on the path when the wind rises."],
	"traveller": ["I have walked far to reach this place.", "Beautiful and strange, this land.", "Do you hear the wind sing?", "Rest your feet a while."],
	"girl": ["Hello! Did you see the big cart?", "I like the animals best.", "Race you to the well!", "Do you have any sweets?"],
}

var rig: RealHuman
var player: Player
var role := "villager"
var voice := "man"
var home_yaw := 0.0
static var atmo: Atmosphere            # set by Main: lets villagers go home at night
var routine := {}                # {"type": "walk"|"play", points / centre / radius, home}
var _move_speed := 0.0
var _rt_i := 0
var _rt_wait := 0.0
var _rt_target := Vector3.ZERO
var pot: Node3D                  # water pot carried on the head (water carriers)
var _carry_dir := -1
var _home_state := 0             # 0 out, 1 heading home, 2 inside (hidden)
var _start_pos := Vector3.ZERO
var companion := false           # follows the player and fights beside them
var _atk_cd := 0.0
var _base_mode := "idle"
var _cd := {"greet": 0.0, "chat": 0.0, "run": 0.0, "jump": 0.0, "idle": 6.0, "say": 0.0}
var _in_zone := false
var _met := false
var _linger := 0.0
var _rng := RandomNumberGenerator.new()
var _bubble: Label3D
var _bubble_t := 0.0
var _restore_t := 0.0
var _busy := 0.0
var stall_kind := "general"      # what a hawker sells (HAWK_LINES key)
var _chat_t := 0.0


func setup(preset: Dictionary, mode: String, label: String) -> Npc:
	name = label
	role = preset.get("role", "villager")
	voice = preset.get("voice", "man")
	_base_mode = mode
	_rng.seed = hash(label)
	_cd["idle"] = _rng.randf_range(3.0, 12.0)
	rig = RealHuman.new().setup(preset, label)
	rig.mode = mode
	add_child(rig)
	rig.struck.connect(func() -> void:
		var snd: String = WORK_SOUND.get(_base_mode, "anvil")
		Sfx.at(snd, global_position + global_transform.basis * Vector3(0.0, 0.9, -0.9), -2.0 if snd == "anvil" else -7.0, _rng.randf_range(0.92, 1.08)))
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	body.add_child(cs)
	add_child(body)
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.fixed_size = false
	_bubble.pixel_size = 0.0042
	_bubble.font_size = 44
	_bubble.outline_size = 14
	_bubble.outline_modulate = Color(0.05, 0.04, 0.03, 0.95)
	_bubble.modulate = Color(1.0, 0.96, 0.82, 1.0)
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD
	_bubble.width = 620.0
	_bubble.position = Vector3(0, 2.25, 0)
	_bubble.visible = false
	add_child(_bubble)
	return self


func _flat_dist() -> float:
	var d := player.global_position - global_position
	d.y = 0.0
	return d.length()


func say(text_en: String, dur: float = 0.0) -> void:
	var text := Loc.t(text_en)
	_bubble.text = text
	_bubble.visible = true
	_bubble.modulate.a = 1.0
	_bubble_t = dur if dur > 0.0 else clampf(1.6 + text.length() * 0.055, 2.2, 5.0)
	Sfx.bark(voice, text, self)


func _gesture(action: String, dur: float) -> void:
	rig.play_action(action, dur)
	if RealHuman.WORK_MODES.has(_base_mode):
		rig.mode = "idle"
		_restore_t = dur + 0.4


func _pick(lines: Array) -> String:
	return lines[_rng.randi() % lines.size()]


func _ground_follow(delta: float) -> void:
	# Ray down for the ground, skipping people, animals and the player (their capsules would lift us).
	var space := get_world_3d().direct_space_state
	var ex: Array[RID] = []
	var hit := {}
	for i in 5:
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 2.2, 0), global_position + Vector3(0, -6.0, 0))
		q.exclude = ex
		hit = space.intersect_ray(q)
		if hit.is_empty():
			break
		var col := hit["collider"] as Node
		var owner_node: Node = col.get_parent() if col != null else null
		if owner_node is Npc or owner_node is Animal or col is CharacterBody3D:
			ex.append(hit["rid"])
			hit = {}
			continue
		break
	if not hit.is_empty():
		global_position.y = lerpf(global_position.y, hit["position"].y, 1.0 - exp(-12.0 * delta))


func _walk_toward(target: Vector3, spd: float, delta: float) -> bool:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.6:
		return true
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-7.0 * delta))
	global_position += Vector3(-sin(rotation.y), 0.0, -cos(rotation.y)) * spd * delta
	_ground_follow(delta)
	_move_speed = spd
	return false


## Daily routine: walkers follow waypoints and pause to chat or work; kids dash about playing;
## at night everyone heads home and disappears indoors until morning.
func _routine_step(delta: float) -> void:
	_move_speed = 0.0
	if _start_pos == Vector3.ZERO:
		_start_pos = global_position
	var night := atmo.night if atmo != null else 0.0
	var home: Vector3 = routine.get("home", _start_pos)
	if _home_state == 2:
		if night < 0.35:
			_home_state = 0
			visible = true
			global_position = _start_pos
		return
	if night > 0.75 and _home_state == 0:
		_home_state = 1
	if _home_state == 1:
		if _walk_toward(home, 2.2, delta):
			_home_state = 2
			visible = false
		return
	if _rt_wait > 0.0:
		_rt_wait -= delta
		return
	match routine.get("type", ""):
		"walk":
			var pts: Array = routine["points"]
			if _walk_toward(pts[_rt_i], 1.35, delta):
				_rt_i = (_rt_i + 1) % pts.size()
				_rt_wait = _rng.randf_range(3.0, 8.0)
				var acts := ["talk", "stretch", "wipe_brow", "look_around"]
				rig.play_action(acts[_rng.randi() % acts.size()], minf(_rt_wait, 3.0))
		"carry":
			var cp: Array = routine["points"]
			if _walk_toward(cp[_rt_i], 1.25, delta):
				if _rt_i == cp.size() - 1 and _carry_dir == 1:
					if pot != null:
						pot.visible = false
					_carry_dir = -1
					_rt_wait = 4.0
					rig.play_action("wipe_brow", 3.0)
				elif _rt_i == 0 and _carry_dir == -1:
					if pot != null:
						pot.visible = true
					_carry_dir = 1
					_rt_wait = 3.5
					rig.play_action("stretch", 3.0)
				_rt_i = clampi(_rt_i + _carry_dir, 0, cp.size() - 1)
		"play":
			if _rt_target == Vector3.ZERO or _walk_toward(_rt_target, 3.6, delta):
				var c: Vector3 = routine["centre"]
				var a := _rng.randf() * TAU
				_rt_target = c + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(1.0, float(routine.get("radius", 6.0)))
				if _rt_target != Vector3.ZERO and _rng.randf() < 0.35:
					_rt_wait = _rng.randf_range(0.6, 1.6)
					rig.play_action("laugh", 1.4)


func _companion_step(delta: float) -> void:
	var to := player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var spd := 0.0
	if dist > 3.2:
		spd = 5.8 if dist > 9.0 else 3.0
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-8.0 * delta))
		var fwd := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
		global_position += fwd * spd * delta
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 3.0, 0), global_position + Vector3(0, -6.0, 0))
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			global_position.y = lerpf(global_position.y, hit["position"].y, 1.0 - exp(-12.0 * delta))
	if dist > 40.0:                      # lost: catch up
		global_position = player.global_position + Vector3(2.0, 0.0, 2.0)
	_atk_cd -= delta
	var foe: Node3D = null
	var best := 3.4
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to((e as Node3D).global_position)
		if d < best:
			best = d
			foe = e
	if foe != null:
		var tf := foe.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(-tf.x, -tf.z), 1.0 - exp(-10.0 * delta))
		if _atk_cd <= 0.0:
			_atk_cd = 1.5
			rig.start_attack()
			get_tree().create_timer(0.36).timeout.connect(func() -> void:
				if is_instance_valid(foe) and not (foe as Enemy).dead:
					(foe as Enemy).take_damage(16.0, foe.global_position - global_position)
					Sfx.at("hit_thud", foe.global_position + Vector3(0, 1.0, 0), -5.0))
	rig.mode = "locomotion"
	rig.animate(delta, spd, true)


func _process(delta: float) -> void:
	if player == null or rig == null:
		return
	if companion:
		_companion_step(delta)
		return
	if not routine.is_empty():
		_routine_step(delta)
		if _home_state == 2:
			return
	var dist := _flat_dist()
	var near := dist < ANIM_RANGE
	for k in _cd:
		_cd[k] = maxf(0.0, _cd[k] - delta)
	if _bubble_t > 0.0:
		_bubble_t -= delta
		_bubble.modulate.a = clampf(_bubble_t / 0.5, 0.0, 1.0)
		if _bubble_t <= 0.0:
			_bubble.visible = false
	if _restore_t > 0.0:
		_restore_t -= delta
		if _restore_t <= 0.0:
			rig.mode = _base_mode
	if not near:
		return
	rig.mode = "locomotion" if (_move_speed > 0.1 and not RealHuman.WORK_MODES.has(_base_mode)) else _base_mode
	rig.animate(delta, _move_speed, true)
	var spd := Vector2(player.velocity.x, player.velocity.z).length()

	# Face and look at the player when they are close; otherwise drift back to the home facing.
	var want_look := 0.0
	if _move_speed > 0.1:
		pass
	elif dist < NOTICE:
		var to := player.global_position - global_position
		var yaw_to := atan2(-to.x, -to.z)
		var diff := wrapf(yaw_to - rotation.y, -PI, PI)
		if not RealHuman.WORK_MODES.has(_base_mode) or dist < GREET:
			rotation.y = lerp_angle(rotation.y, yaw_to, 1.0 - exp(-2.5 * delta))
		want_look = clampf(wrapf(yaw_to - rotation.y, -PI, PI), -1.2, 1.2)
		var _unused := diff
	else:
		rotation.y = lerp_angle(rotation.y, home_yaw, 1.0 - exp(-0.8 * delta))
	rig.look_yaw = lerpf(rig.look_yaw, want_look, 1.0 - exp(-6.0 * delta))

	# Situations
	if dist < GREET and not _in_zone:
		_in_zone = true
		_linger = 0.0
		if _cd["greet"] <= 0.0:
			_met = true
			_cd["greet"] = 40.0
			_cd["say"] = 3.0
			var act := "namaste" if _rng.randf() < 0.5 else "wave"
			_gesture(act, 2.4)
			say(_pick(GREETINGS))
	elif dist > 12.0 and _in_zone:
		_in_zone = false
		if _met and _cd["say"] <= 0.0 and dist < 22.0:
			_gesture("wave", 2.0)
			say(_pick(FAREWELLS))
			_cd["say"] = 6.0
		_met = false
	if dist < 3.4:
		_linger += delta
		if _linger > 6.5 and _cd["chat"] <= 0.0 and _bubble_t <= 0.0:
			_cd["chat"] = 14.0
			_linger = 3.5
			_gesture("talk", 4.0)
			say(_pick(ROLE_LINES.get(role, ROLE_LINES["villager"])))
	else:
		_linger = 0.0
	if dist < GREET and spd > 5.0 and _cd["run"] <= 0.0:
		_cd["run"] = 12.0
		_gesture("startle", 1.5)
		say(_pick(STARTLES), 2.4)
	if dist < 7.0 and player.velocity.y > 3.0 and _cd["jump"] <= 0.0:
		_cd["jump"] = 10.0
		_gesture("laugh", 2.2)
		say(_pick(LAUGHS), 2.4)
	# market chatter: hawkers cry their wares, haggling pairs argue; heard as babble, bubble when near
	if (_base_mode == "hawk" or _base_mode == "haggle" or _base_mode == "sit_talk") and dist < 40.0:
		_chat_t -= delta
		if _chat_t <= 0.0:
			_chat_t = _rng.randf_range(4.0, 9.0)
			var ls: Array = HAWK_LINES.get(stall_kind, HAWK_LINES["general"]) if _base_mode == "hawk" else HAGGLE_LINES
			var ln: String = Loc.t(_pick(ls))
			if dist < 14.0:
				_bubble.text = ln
				_bubble.visible = true
				_bubble.modulate.a = 1.0
				_bubble_t = 3.0
			Sfx.bark(voice, ln, self)
	# small random idle actions when nobody is close
	if dist >= NOTICE and _cd["idle"] <= 0.0 and rig.action == "" and not RealHuman.WORK_MODES.has(_base_mode):
		_cd["idle"] = _rng.randf_range(7.0, 16.0)
		rig.play_action(IDLE_ACTIONS[_rng.randi() % IDLE_ACTIONS.size()], _rng.randf_range(2.0, 3.2))
