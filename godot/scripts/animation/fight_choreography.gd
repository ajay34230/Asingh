## Capture fight, staged like a fighting game:
##   1. face-off    both tokens turn to face each other and raise their guard
##   2. combo       two quick jabs that land (hit sparks, short hit-stop, recoil)
##   3. finisher    uppercut (punch) or spinning kick, in slow motion; the victim is
##                  launched, flips and crashes down
##   4. dazed       the victim wobbles with stars circling its head
##   5. throw       the attacker grabs it, lifts it overhead, spins and hurls it home
##   6. victory     the attacker raises its arms
## Poses drive the shoulder/elbow/hip/knee pivots of TransformerToken. The model's
## front is +Z and an arm hanging down points along -Y: rotating a shoulder about X by
## a negative angle swings the arm forward (-1.57 = straight ahead, -2.6 = overhead).
class_name FightChoreography
extends Node

signal cue(name: String, data: Dictionary)   ## sounds and effects: swing, jab, impact, ...

var director: CameraDirector
var anim_scale := 1.0

var _stars: Node3D


const FINISHERS := ["uppercut", "spin_kick", "flying_kick", "slam"]
const EXCHANGES := ["counter", "dodge", "none"]

var _skip := false
var forced_finisher := ""   ## tests and recordings only
var forced_exchange := ""


## Tap during a fight: the rest plays at high speed.
func skip() -> void:
	if _active:
		_skip = true


func perform(attacker: TransformerToken, victim: TransformerToken, home: Vector3, use_punch: bool) -> void:
	_active = true
	_skip = false
	var ground_a := attacker.ground_y
	var ground_v := victim.ground_y
	var finisher: String = FINISHERS.pick_random()
	if not use_punch and finisher == "uppercut":
		finisher = "spin_kick"
	var exchange: String = EXCHANGES.pick_random()
	if forced_finisher != "":
		finisher = forced_finisher
	if forced_exchange != "":
		exchange = forced_exchange

	# 1. Face-off: both raise their guard; the camera is low and wide.
	_face(attacker, victim.global_position)
	_face(victim, attacker.global_position)
	attacker.transform_out(0.15)
	victim.transform_out(0.15)
	_shot("low", attacker, victim)
	await _pose(attacker, _guard(), 0.18)
	_pose(victim, _guard(), 0.18)
	cue.emit("faceoff", {"attacker": attacker, "victim": victim})
	await _bounce(attacker, 0.32)

	# 2. Exchange: the defender strikes first and the attacker blocks or dodges.
	_shot("side", attacker, victim)
	if exchange == "counter":
		await _counter_block(victim, attacker)
	elif exchange == "dodge":
		await _counter_dodge(victim, attacker)

	# 3. Combo: two jabs that land.
	_shot("over", attacker, victim)
	for side in ["L", "R"]:
		await _jab(attacker, victim, side)
		await _wait(0.05)

	# 4. Finisher, from the hero angle, in slow motion.
	_shot("low", attacker, victim)
	cue.emit("finisher", {"name": finisher, "attacker": attacker})
	match finisher:
		"uppercut":
			await _uppercut(attacker, victim)
		"spin_kick":
			await _spin_kick(attacker, victim)
		"flying_kick":
			await _flying_kick(attacker, victim)
		"slam":
			await _slam(attacker, victim, ground_v)
	_shot("side", attacker, victim, false)
	if finisher != "slam":
		await _launch(victim, attacker, ground_v)
	_pose(attacker, _guard(), 0.15)

	# 5. Dazed, 6. throw home (crane shot), 7. victory.
	await _dazed(victim, 0.6)
	_shot("high", attacker, victim, false)
	await _grab_spin_throw(attacker, victim, home)
	await _victory(attacker, ground_a)
	attacker.ground_y = ground_a
	_active = false
	_skip = false
	_freeze_until = 0
	_slow_until = 0
	Engine.time_scale = 1.0


func _shot(kind: String, a: Node3D, b: Node3D, cut := true) -> void:
	if director and not _skip:
		director.shot(kind, a, b, cut)


# --- poses ----------------------------------------------------------------------

## A pose maps "arm_L"/"arm_R"/"leg_L"/"leg_R" to [shoulder|hip, elbow|knee] rotations.
func _guard() -> Dictionary:
	return {
		"arm_L": [Vector3(-0.55, 0, 0.18), Vector3(-1.9, 0, 0)],
		"arm_R": [Vector3(-0.45, 0, -0.18), Vector3(-1.95, 0, 0)],
		"leg_L": [Vector3(-0.25, 0, -0.25), Vector3(0.35, 0, 0)],
		"leg_R": [Vector3(0.2, 0, 0.25), Vector3(0.3, 0, 0)],
	}


func _pose(token: TransformerToken, pose: Dictionary, seconds: float, trans := Tween.TRANS_BACK) -> void:
	var t := token.create_tween().set_parallel(true)
	for key in pose:
		var side: String = key.substr(4)
		var parts: Dictionary = token.arm_pivots[side] if key.begins_with("arm") else token.leg_pivots[side]
		var first: Node3D = parts["shoulder"] if key.begins_with("arm") else parts["hip"]
		var second: Node3D = parts["elbow"] if key.begins_with("arm") else parts["knee"]
		t.tween_property(first, "rotation", pose[key][0], seconds * anim_scale).set_trans(trans).set_ease(Tween.EASE_OUT)
		t.tween_property(second, "rotation", pose[key][1], seconds * anim_scale).set_trans(trans).set_ease(Tween.EASE_OUT)
	await t.finished


func _face(token: Node3D, point: Vector3) -> void:
	var flat := Vector3(point.x - token.global_position.x, 0, point.z - token.global_position.z)
	if flat.length_squared() > 0.0001:
		token.rotation.y = atan2(flat.x, flat.z)


func _forward(token: Node3D) -> Vector3:
	return Vector3(sin(token.rotation.y), 0, cos(token.rotation.y))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds * anim_scale).timeout


## Time control. Hit-stops and slow motion are deadlines in real time; the time scale
## is recomputed every frame from them, so overlapping effects can never leave the
## game stuck slow or frozen.
var _freeze_until := 0
var _slow_until := 0
var _slow_scale := 1.0
var _active := false


func _process(_delta: float) -> void:
	if not _active:
		return
	var now := Time.get_ticks_msec()
	if _skip:
		Engine.time_scale = 5.0
	elif now < _freeze_until:
		Engine.time_scale = 0.03
	elif now < _slow_until:
		Engine.time_scale = _slow_scale
	else:
		Engine.time_scale = 1.0


## Freezes the whole game for a moment on contact (the classic "hit-stop").
func _hit_stop(real_seconds: float) -> void:
	if _skip:
		return
	_freeze_until = Time.get_ticks_msec() + int(real_seconds * 1000.0)
	Engine.time_scale = 0.03
	await get_tree().create_timer(real_seconds, true, false, true).timeout


func _slow_motion(scale: float, real_seconds: float) -> void:
	_slow_scale = scale
	_slow_until = Time.get_ticks_msec() + int(real_seconds * 1000.0)


func _bounce(token: TransformerToken, seconds: float) -> void:
	var t := token.create_tween()
	for i in range(2):
		t.tween_property(token.body_node, "position:y", 0.035, seconds * 0.25 * anim_scale).set_trans(Tween.TRANS_SINE)
		t.tween_property(token.body_node, "position:y", 0.0, seconds * 0.25 * anim_scale).set_trans(Tween.TRANS_SINE)
	await t.finished


func _fist(token: TransformerToken, side: String) -> Vector3:
	return (token.arm_pivots[side]["wrist"] as Node3D).global_position


# --- moves ------------------------------------------------------------------------

## Lunge distance so the fist meets the opponent's body instead of punching air.
func _reach(attacker: Node3D, victim: Node3D, contact := 0.5) -> float:
	var d := Vector2(victim.global_position.x - attacker.global_position.x, victim.global_position.z - attacker.global_position.z).length()
	return maxf(0.0, d - contact)


func _jab(attacker: TransformerToken, victim: TransformerToken, side: String) -> void:
	var fwd := _forward(attacker)
	var start := attacker.global_position
	var lunge := _reach(attacker, victim, 0.52)
	cue.emit("swing", {"position": start})
	# Cock the fist back a touch, then snap it out while stepping in.
	var pose := _guard()
	pose["arm_" + side] = [Vector3(-0.2, 0, 0.1 if side == "L" else -0.1), Vector3(-2.2, 0, 0)]
	await _pose(attacker, pose, 0.06, Tween.TRANS_QUAD)
	var strike := attacker.create_tween().set_parallel(true)
	var arm: Dictionary = attacker.arm_pivots[side]
	strike.tween_property(arm["shoulder"], "rotation", Vector3(-1.55, 0, 0.0), 0.07 * anim_scale).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	strike.tween_property(arm["elbow"], "rotation", Vector3(-0.05, 0, 0), 0.07 * anim_scale).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	strike.tween_property(attacker, "global_position", start + fwd * lunge, 0.07 * anim_scale).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	strike.tween_property(attacker.body_node, "rotation:y", 0.35 if side == "L" else -0.35, 0.07 * anim_scale)   # shoulder turn
	await strike.finished
	# Contact.
	cue.emit("jab", {"position": _fist(attacker, side), "victim": victim})
	_recoil(victim, fwd, 0.14, -0.4)
	await _hit_stop(0.05)
	var back := attacker.create_tween().set_parallel(true)
	back.tween_property(attacker, "global_position", start, 0.14 * anim_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	back.tween_property(attacker.body_node, "rotation:y", 0.0, 0.14 * anim_scale)
	await back.finished
	_pose(attacker, _guard(), 0.1)


func _recoil(victim: TransformerToken, push_dir: Vector3, distance: float, tilt: float) -> void:
	var start := victim.global_position
	var t := victim.create_tween()
	t.set_parallel(true)
	t.tween_property(victim, "global_position", start + push_dir * distance, 0.08 * anim_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(victim.body_node, "rotation:x", tilt, 0.08 * anim_scale)
	t.tween_property(victim.body_node, "scale", Vector3(1.08, 0.9, 1.08), 0.06 * anim_scale)
	t.chain().tween_property(victim.body_node, "rotation:x", 0.0, 0.2 * anim_scale).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(victim.body_node, "scale", Vector3.ONE, 0.2 * anim_scale).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _uppercut(attacker: TransformerToken, victim: TransformerToken) -> void:
	var fwd := _forward(attacker)
	var start := attacker.global_position
	cue.emit("charge", {"position": start, "attacker": attacker})
	# Crouch and draw the right fist low and back.
	var load_pose := _guard()
	load_pose["arm_R"] = [Vector3(0.55, 0, -0.25), Vector3(-1.2, 0, 0)]
	load_pose["leg_L"] = [Vector3(-0.5, 0, -0.3), Vector3(0.8, 0, 0)]
	load_pose["leg_R"] = [Vector3(0.4, 0, 0.3), Vector3(0.7, 0, 0)]
	var crouch := attacker.create_tween()
	crouch.tween_property(attacker.body_node, "position:y", -0.06, 0.16 * anim_scale)
	_pose(attacker, load_pose, 0.16, Tween.TRANS_QUAD)
	await crouch.finished
	await _wait(0.08)
	_slow_motion(0.35, 0.55)
	cue.emit("swing", {"position": start, "heavy": true})
	# Explode upward: fist rises through the target, the body leaves the ground.
	var lunge := _reach(attacker, victim, 0.42)
	var up := attacker.create_tween().set_parallel(true)
	var arm: Dictionary = attacker.arm_pivots["R"]
	up.tween_property(arm["shoulder"], "rotation", Vector3(-2.75, 0, -0.1), 0.12 * anim_scale).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	up.tween_property(arm["elbow"], "rotation", Vector3(-0.35, 0, 0), 0.12 * anim_scale)
	up.tween_property(attacker.body_node, "position:y", 0.14, 0.12 * anim_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up.tween_property(attacker, "global_position", start + fwd * lunge, 0.12 * anim_scale).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await up.finished
	cue.emit("impact", {"position": _fist(attacker, "R"), "victim": victim, "kind": "punch"})
	if director:
		director.punch_in(7.0, 0.9)
		director.shake(0.14, 0.35)
	await _hit_stop(0.11)
	var land := attacker.create_tween().set_parallel(true)
	land.tween_property(attacker.body_node, "position:y", 0.0, 0.18 * anim_scale).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	land.tween_property(attacker, "global_position", start + fwd * lunge * 0.5, 0.18 * anim_scale)
	await land.finished


func _spin_kick(attacker: TransformerToken, victim: TransformerToken) -> void:
	var fwd := _forward(attacker)
	var start := attacker.global_position
	var heading := attacker.rotation.y
	cue.emit("charge", {"position": start, "attacker": attacker})
	var chamber := _guard()
	chamber["leg_R"] = [Vector3(-0.9, 0, 0.2), Vector3(1.4, 0, 0)]   # knee up, foot tucked
	await _pose(attacker, chamber, 0.14, Tween.TRANS_QUAD)
	_slow_motion(0.35, 0.6)
	cue.emit("swing", {"position": start, "heavy": true})
	# One full turn on the standing leg; the kicking leg snaps out on the way round.
	var lunge := _reach(attacker, victim, 0.45)
	var spin := attacker.create_tween().set_parallel(true)
	spin.tween_property(attacker, "rotation:y", heading + TAU, 0.24 * anim_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	spin.tween_property(attacker, "global_position", start + fwd * lunge, 0.24 * anim_scale)
	var leg: Dictionary = attacker.leg_pivots["R"]
	spin.tween_property(leg["hip"], "rotation", Vector3(-1.55, 0, 0.55), 0.16 * anim_scale).set_delay(0.08 * anim_scale)
	spin.tween_property(leg["knee"], "rotation", Vector3(0.05, 0, 0), 0.16 * anim_scale).set_delay(0.08 * anim_scale)
	spin.tween_property(attacker.body_node, "rotation:z", -0.25, 0.2 * anim_scale)
	spin.tween_property(attacker.body_node, "position:y", 0.08, 0.2 * anim_scale)
	await spin.finished
	attacker.rotation.y = heading
	var foot := (attacker.leg_pivots["R"]["ankle"] as Node3D).global_position
	cue.emit("impact", {"position": foot, "victim": victim, "kind": "kick"})
	if director:
		director.punch_in(7.0, 0.9)
		director.shake(0.16, 0.35)
	await _hit_stop(0.12)
	var land := attacker.create_tween().set_parallel(true)
	land.tween_property(attacker.body_node, "rotation:z", 0.0, 0.18 * anim_scale)
	land.tween_property(attacker.body_node, "position:y", 0.0, 0.18 * anim_scale).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	land.tween_property(attacker, "global_position", start + fwd * lunge * 0.5, 0.18 * anim_scale)
	await land.finished


## The finisher's knock-back: up, a backflip, and a crash landing with dust.
func _launch(victim: TransformerToken, attacker: Node3D, ground: float) -> void:
	var away := _forward(attacker)
	var start := victim.global_position
	var end := start + away * 0.55
	end.y = ground
	var fly := func(p: float) -> void:
		victim.global_position = start.lerp(end, p) + Vector3.UP * sin(p * PI) * 0.75
		victim.body_node.rotation.x = -p * TAU * 0.85
		victim.body_node.rotation.z = sin(p * PI) * 0.4
	var t := victim.create_tween()
	t.tween_method(fly, 0.0, 1.0, 0.5 * anim_scale).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	victim.body_node.rotation = Vector3(-0.35, 0, 0.2)
	victim.global_position = end
	cue.emit("crash", {"position": end})
	var squash := victim.create_tween().set_parallel(true)
	squash.tween_property(victim.body_node, "scale", Vector3(1.18, 0.74, 1.18), 0.06 * anim_scale)
	squash.chain().tween_property(victim.body_node, "scale", Vector3.ONE, 0.22 * anim_scale).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	squash.parallel().tween_property(victim.body_node, "rotation", Vector3.ZERO, 0.3 * anim_scale).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await squash.finished


func _dazed(victim: TransformerToken, seconds: float) -> void:
	_stars = _make_stars()
	victim.add_child(_stars)
	_stars.position = Vector3(0, 0.95, 0)
	cue.emit("dazed", {"position": victim.global_position})
	# Limp arms, wobbling on the spot.
	_pose(victim, {"arm_L": [Vector3(0.1, 0, 0.55), Vector3(-0.2, 0, 0)], "arm_R": [Vector3(0.1, 0, -0.55), Vector3(-0.2, 0, 0)]}, 0.15)
	var wobble := func(p: float) -> void:
		victim.body_node.rotation.z = sin(p * TAU * 2.0) * 0.22 * (1.0 - p * 0.3)
		victim.body_node.rotation.x = cos(p * TAU * 2.0) * 0.12
		if is_instance_valid(_stars):
			_stars.rotation.y = p * TAU * 2.5
	var t := victim.create_tween()
	t.tween_method(wobble, 0.0, 1.0, seconds * anim_scale)
	await t.finished
	victim.body_node.rotation = Vector3.ZERO


func _make_stars() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#ffe066")
	mat.emission_enabled = true
	mat.emission = Color("#ffcc33")
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var star := PackedVector2Array()
	for i in range(10):
		var r := 0.14 if i % 2 == 0 else 0.06
		var a := TAU * i / 10.0 - PI * 0.5
		star.append(Vector2(cos(a), sin(a)) * r)
	var mesh := RoyalBoard.extrude_mesh(star, -0.015, 0.015)
	for i in range(3):
		var m := MeshInstance3D.new()
		m.mesh = mesh
		m.material_override = mat
		var a := TAU * i / 3.0
		m.position = Vector3(cos(a) * 0.36, 0.05 * sin(a * 3.0), sin(a) * 0.36)
		m.rotation.x = PI * 0.5
		root.add_child(m)
	return root


func _grab_spin_throw(attacker: TransformerToken, victim: TransformerToken, home: Vector3) -> void:
	if is_instance_valid(_stars):
		_stars.queue_free()
	_face(attacker, victim.global_position)
	var fwd := _forward(attacker)
	# Step in and reach with both arms.
	var reach := {"arm_L": [Vector3(-1.45, 0, -0.15), Vector3(-0.3, 0, 0)], "arm_R": [Vector3(-1.45, 0, 0.15), Vector3(-0.3, 0, 0)]}
	_pose(attacker, reach, 0.12, Tween.TRANS_QUAD)
	var step := attacker.create_tween()
	step.tween_property(attacker, "global_position", victim.global_position - fwd * 0.42, 0.12 * anim_scale)
	await step.finished
	cue.emit("grab", {"position": victim.global_position})
	# Lift overhead.
	var lift_pose := {"arm_L": [Vector3(-2.85, 0, -0.2), Vector3(-0.2, 0, 0)], "arm_R": [Vector3(-2.85, 0, 0.2), Vector3(-0.2, 0, 0)],
		"leg_L": [Vector3(-0.2, 0, -0.35), Vector3(0.45, 0, 0)], "leg_R": [Vector3(0.2, 0, 0.35), Vector3(0.45, 0, 0)]}
	_pose(attacker, lift_pose, 0.22)
	var overhead := func() -> Vector3: return attacker.global_position + Vector3.UP * 0.92 + _forward(attacker) * 0.05
	var v_start := victim.global_position
	var raise := func(p: float) -> void:
		victim.global_position = v_start.lerp(overhead.call(), p)
		victim.body_node.rotation.z = p * PI * 0.5   # carried on its side
	var lift := victim.create_tween()
	lift.tween_method(raise, 0.0, 1.0, 0.22 * anim_scale).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await lift.finished
	# Spin one and a half turns, speeding up, then release towards home.
	cue.emit("spin", {"position": attacker.global_position})
	var heading := attacker.rotation.y
	var to_home := Vector3(home.x - attacker.global_position.x, 0, home.z - attacker.global_position.z)
	var release_heading := atan2(to_home.x, to_home.z)
	var turns := heading + TAU * 1.5
	var end_heading := release_heading + TAU * roundf((turns - release_heading) / TAU)
	var whirl := func(h: float) -> void:
		attacker.rotation.y = h
		victim.global_position = overhead.call()
		victim.rotation.y = h
	var spin := attacker.create_tween()
	spin.tween_method(whirl, heading, end_heading, 0.6 * anim_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await spin.finished
	cue.emit("throw", {"position": victim.global_position})
	var follow := {"arm_L": [Vector3(-1.6, 0, -0.1), Vector3(0, 0, 0)], "arm_R": [Vector3(-1.6, 0, 0.1), Vector3(0, 0, 0)]}
	_pose(attacker, follow, 0.12, Tween.TRANS_EXPO)
	if director:
		director.stop_tracking()
		director.release(0.9)
	victim.body_node.rotation = Vector3.ZERO
	await victim.play_thrown_to_home(home)
	cue.emit("thrown_home", {"position": home, "victim": victim})


## The defender throws a punch; the attacker crosses its arms and blocks it.
func _counter_block(defender: TransformerToken, attacker: TransformerToken) -> void:
	var fwd := _forward(defender)
	var start := defender.global_position
	cue.emit("swing", {"position": start})
	var block := {"arm_L": [Vector3(-1.9, 0, 0.6), Vector3(-1.4, 0, 0)], "arm_R": [Vector3(-1.9, 0, -0.6), Vector3(-1.4, 0, 0)]}
	_pose(attacker, block, 0.08, Tween.TRANS_QUAD)
	var t := defender.create_tween().set_parallel(true)
	t.tween_property(defender.arm_pivots["R"]["shoulder"], "rotation", Vector3(-1.55, 0, 0), 0.09 * anim_scale).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(defender.arm_pivots["R"]["elbow"], "rotation", Vector3.ZERO, 0.09 * anim_scale)
	t.tween_property(defender, "global_position", start + fwd * _reach(defender, attacker, 0.55), 0.09 * anim_scale)
	await t.finished
	cue.emit("block", {"position": _fist(defender, "R")})
	_recoil(attacker, fwd, 0.08, -0.15)
	await _hit_stop(0.05)
	var back := defender.create_tween().set_parallel(true)
	back.tween_property(defender, "global_position", start, 0.16 * anim_scale)
	await back.finished
	_pose(defender, _guard(), 0.1)
	await _pose(attacker, _guard(), 0.1)


## The defender lunges; the attacker sways aside and the punch whiffs.
func _counter_dodge(defender: TransformerToken, attacker: TransformerToken) -> void:
	var fwd := _forward(defender)
	var side := Vector3(-fwd.z, 0, fwd.x)
	var start := defender.global_position
	var a_start := attacker.global_position
	cue.emit("swing", {"position": start})
	var t := defender.create_tween().set_parallel(true)
	t.tween_property(defender.arm_pivots["L"]["shoulder"], "rotation", Vector3(-1.55, 0, 0), 0.12 * anim_scale).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(defender, "global_position", start + fwd * _reach(defender, attacker, 0.4), 0.12 * anim_scale)
	t.tween_property(attacker, "global_position", a_start + side * 0.28, 0.1 * anim_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(attacker.body_node, "rotation:z", 0.35, 0.1 * anim_scale)
	await t.finished
	cue.emit("whiff", {"position": attacker.global_position})
	_slow_motion(0.4, 0.25)
	await _wait(0.12)
	var back := defender.create_tween().set_parallel(true)
	back.tween_property(defender, "global_position", start, 0.18 * anim_scale)
	back.tween_property(attacker, "global_position", a_start, 0.18 * anim_scale)
	back.tween_property(attacker.body_node, "rotation:z", 0.0, 0.18 * anim_scale)
	await back.finished
	_pose(defender, _guard(), 0.1)


## Running jump, knee tucked, foot driven down into the target at the top of the arc.
func _flying_kick(attacker: TransformerToken, victim: TransformerToken) -> void:
	var fwd := _forward(attacker)
	var start := attacker.global_position
	cue.emit("charge", {"position": start, "attacker": attacker})
	var crouch := attacker.create_tween()
	crouch.tween_property(attacker.body_node, "scale", Vector3(1.1, 0.82, 1.1), 0.12 * anim_scale)
	await crouch.finished
	_slow_motion(0.35, 0.7)
	cue.emit("swing", {"position": start, "heavy": true})
	var target := start + fwd * _reach(attacker, victim, 0.45)
	var tuck := {"leg_R": [Vector3(-1.5, 0, 0), Vector3(0.05, 0, 0)], "leg_L": [Vector3(-0.9, 0, 0), Vector3(1.6, 0, 0)],
		"arm_L": [Vector3(-0.6, 0, 0.9), Vector3(-0.4, 0, 0)], "arm_R": [Vector3(0.4, 0, -0.9), Vector3(-0.4, 0, 0)]}
	_pose(attacker, tuck, 0.1, Tween.TRANS_EXPO)
	var arc := func(p: float) -> void:
		attacker.global_position = start.lerp(target, p) + Vector3.UP * sin(p * PI * 0.8) * 0.75
		attacker.body_node.scale = Vector3.ONE
		attacker.body_node.rotation.x = -0.35 * sin(p * PI)
	var t := attacker.create_tween()
	t.tween_method(arc, 0.0, 1.0, 0.3 * anim_scale).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished
	var foot := (attacker.leg_pivots["R"]["ankle"] as Node3D).global_position
	cue.emit("impact", {"position": foot, "victim": victim, "kind": "kick", "big": true})
	if director:
		director.punch_in(8.0, 0.9)
		director.shake(0.18, 0.4)
	await _hit_stop(0.13)
	var land := attacker.create_tween().set_parallel(true)
	land.tween_property(attacker, "global_position", Vector3(target.x, start.y, target.z), 0.2 * anim_scale).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	land.tween_property(attacker.body_node, "rotation:x", 0.0, 0.2 * anim_scale)
	await land.finished


## Grab, hoist overhead and slam the opponent into the floor; the board shakes.
func _slam(attacker: TransformerToken, victim: TransformerToken, ground: float) -> void:
	var fwd := _forward(attacker)
	cue.emit("charge", {"position": attacker.global_position, "attacker": attacker})
	var step := attacker.create_tween()
	step.tween_property(attacker, "global_position", victim.global_position - fwd * 0.42, 0.12 * anim_scale)
	_pose(attacker, {"arm_L": [Vector3(-1.45, 0, -0.15), Vector3(-0.3, 0, 0)], "arm_R": [Vector3(-1.45, 0, 0.15), Vector3(-0.3, 0, 0)]}, 0.12)
	await step.finished
	cue.emit("grab", {"position": victim.global_position})
	_pose(attacker, {"arm_L": [Vector3(-2.9, 0, -0.2), Vector3(-0.2, 0, 0)], "arm_R": [Vector3(-2.9, 0, 0.2), Vector3(-0.2, 0, 0)]}, 0.22)
	var v_start := victim.global_position
	var top := attacker.global_position + Vector3.UP * 1.0
	var lift := func(p: float) -> void:
		victim.global_position = v_start.lerp(top, p)
		victim.body_node.rotation.x = -p * PI
	var t := victim.create_tween()
	t.tween_method(lift, 0.0, 1.0, 0.28 * anim_scale).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished
	_slow_motion(0.35, 0.5)
	cue.emit("swing", {"position": top, "heavy": true})
	var down := v_start + fwd * 0.15
	down.y = ground
	_pose(attacker, {"arm_L": [Vector3(-1.2, 0, -0.2), Vector3(0, 0, 0)], "arm_R": [Vector3(-1.2, 0, 0.2), Vector3(0, 0, 0)]}, 0.12, Tween.TRANS_EXPO)
	var drop := victim.create_tween()
	drop.tween_property(victim, "global_position", down, 0.14 * anim_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await drop.finished
	cue.emit("impact", {"position": down + Vector3(0, 0.2, 0), "victim": victim, "kind": "punch", "big": true})
	cue.emit("crash", {"position": down})
	if director:
		director.punch_in(8.0, 0.9)
		director.shake(0.25, 0.5)
	await _hit_stop(0.14)
	var squash := victim.create_tween()
	squash.tween_property(victim.body_node, "scale", Vector3(1.25, 0.6, 1.25), 0.06 * anim_scale)
	squash.tween_property(victim.body_node, "scale", Vector3.ONE, 0.25 * anim_scale).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	squash.parallel().tween_property(victim.body_node, "rotation:x", 0.0, 0.25 * anim_scale)
	await squash.finished


func _victory(attacker: TransformerToken, ground: float) -> void:
	var cheer := {"arm_L": [Vector3(-2.9, 0, 0.55), Vector3(-0.1, 0, 0)], "arm_R": [Vector3(-2.9, 0, -0.55), Vector3(-0.1, 0, 0)]}
	_pose(attacker, cheer, 0.16)
	var hop := attacker.create_tween()
	hop.tween_property(attacker.body_node, "position:y", 0.12, 0.14 * anim_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(attacker.body_node, "position:y", 0.0, 0.16 * anim_scale).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await hop.finished
	await _wait(0.15)
	attacker.ground_y = ground
	await _pose(attacker, _guard(), 0.12)
