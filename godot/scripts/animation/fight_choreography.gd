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
## Legendary token designs always finish with their own signature move.
## design id -> [finisher, banner]
const SIGNATURES := {
	"design_garuda": ["garuda_dive", "GARUDA DIVE!"],
	"design_nataraja": ["tandava", "TANDAVA!"],
	"design_hanuman": ["mace_smash", "GADA PRAHAAR!"],
	"design_surya": ["sun_blast", "SURYA BLAST!"],
	"design_shadow": ["shadow_strike", "SHADOW STRIKE!"],
	"design_robo": ["laser", "LASER BEAM!"],
	"design_ghost": ["possess", "POSSESSED!"],
}
## Signature moves that end with the victim already on the floor (no knock-back).
const GROUNDED := ["slam", "mace_smash"]

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
	var design := String(attacker.get_meta("design", ""))
	var banner := ""
	if SIGNATURES.has(design):
		finisher = SIGNATURES[design][0]
		banner = SIGNATURES[design][1]
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
	if banner != "":
		cue.emit("signature", {"name": banner, "position": attacker.global_position})
	match finisher:
		"garuda_dive":
			await _garuda_dive(attacker, victim)
		"tandava":
			await _tandava(attacker, victim)
		"mace_smash":
			await _mace_smash(attacker, victim, ground_v)
		"sun_blast":
			await _sun_blast(attacker, victim)
		"shadow_strike":
			await _shadow_strike(attacker, victim)
		"laser":
			await _laser(attacker, victim)
		"possess":
			await _possess(attacker, victim)
		"uppercut":
			await _uppercut(attacker, victim)
		"spin_kick":
			await _spin_kick(attacker, victim)
		"flying_kick":
			await _flying_kick(attacker, victim)
		"slam":
			await _slam(attacker, victim, ground_v)
	_shot("side", attacker, victim, false)
	if not finisher in GROUNDED:
		await _launch(victim, attacker, ground_v)
	attacker.global_position.y = ground_a
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



# --- signature finishers (legendary designs) ----------------------------------------

func _burst(at: Vector3, color: Color, amount := 30, speed := 2.4, life := 0.8, gravity := 2.0) -> void:
	cue.emit("burst", {"position": at, "color": color, "amount": amount, "speed": speed, "life": life, "gravity": gravity})


func _glow_mat(c: Color, energy := 4.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c, alpha)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _impact(attacker: TransformerToken, victim: TransformerToken, at: Vector3, kind := "punch", shake := 0.2) -> void:
	cue.emit("impact", {"position": at, "victim": victim, "kind": kind, "big": true})
	if director:
		director.punch_in(8.0, 0.9)
		director.shake(shake, 0.45)
	await _hit_stop(0.14)


## Garuda soars high, hangs in the air, then dives talons-first into the victim.
func _garuda_dive(attacker: TransformerToken, victim: TransformerToken) -> void:
	var start := attacker.global_position
	cue.emit("charge", {"position": start, "attacker": attacker})
	var wings := {"arm_L": [Vector3(-1.4, 0, 1.4), Vector3(-0.1, 0, 0)], "arm_R": [Vector3(-1.4, 0, -1.4), Vector3(-0.1, 0, 0)]}
	_pose(attacker, wings, 0.15)
	_shot("sky", attacker, victim)
	var high := start + Vector3.UP * 1.9 - _forward(attacker) * 0.3
	var rise := attacker.create_tween()
	rise.tween_property(attacker, "global_position", high, 0.4 * anim_scale).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await rise.finished
	_burst(high, Color("#ffd24a"), 30, 1.6, 0.8, 0.5)
	await _wait(0.12)
	_slow_motion(0.3, 0.6)
	cue.emit("swing", {"position": high, "heavy": true})
	var target := victim.global_position + Vector3.UP * 0.4
	var dive := attacker.create_tween().set_parallel(true)
	dive.tween_property(attacker, "global_position", target - _forward(attacker) * 0.2, 0.18 * anim_scale).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	dive.tween_property(attacker.body_node, "rotation:x", 0.9, 0.18 * anim_scale)
	await dive.finished
	_burst(target, Color("#ffb020"), 50, 3.0, 0.9)
	await _impact(attacker, victim, target, "kick", 0.25)
	var land := attacker.create_tween().set_parallel(true)
	land.tween_property(attacker.body_node, "rotation:x", 0.0, 0.2 * anim_scale)
	land.tween_property(attacker, "global_position", Vector3(target.x, start.y, target.z) - _forward(attacker) * 0.5, 0.25 * anim_scale).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await land.finished


## Nataraja's cosmic dance: a whirling spin that throws off rings of fire.
func _tandava(attacker: TransformerToken, victim: TransformerToken) -> void:
	var start := attacker.global_position
	var heading := attacker.rotation.y
	cue.emit("charge", {"position": start, "attacker": attacker})
	var dance := {"arm_L": [Vector3(-1.5, 0, 1.2), Vector3(-0.8, 0, 0)], "arm_R": [Vector3(-1.2, 0, -1.4), Vector3(-0.2, 0, 0)],
		"leg_L": [Vector3(-1.2, 0, -0.5), Vector3(1.2, 0, 0)]}
	await _pose(attacker, dance, 0.15)
	_slow_motion(0.4, 0.9)
	var lunge := _reach(attacker, victim, 0.5)
	var spin := attacker.create_tween().set_parallel(true)
	spin.tween_property(attacker, "rotation:y", heading + TAU * 3.0, 0.6 * anim_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	spin.tween_property(attacker, "global_position", start + _forward(attacker) * lunge, 0.6 * anim_scale)
	spin.tween_property(attacker.body_node, "position:y", 0.15, 0.3 * anim_scale)
	for i in range(3):
		var at := start + _forward(attacker) * lunge * (i + 1) / 3.0 + Vector3.UP * 0.4
		get_tree().create_timer(0.18 * (i + 1) * anim_scale).timeout.connect(func() -> void:
			cue.emit("swing", {"position": at, "heavy": true})
			_burst(at, Color("#ff6a1a"), 26, 2.6, 0.6, -0.5))
	await spin.finished
	attacker.rotation.y = heading
	var hit := victim.global_position + Vector3.UP * 0.4
	_burst(hit, Color("#ffc83a"), 60, 3.2, 0.8, -0.5)
	await _impact(attacker, victim, hit, "kick")
	var land := attacker.create_tween()
	land.tween_property(attacker.body_node, "position:y", 0.0, 0.2 * anim_scale).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await land.finished


## Hanuman leaps and brings the mace down: the victim is flattened, the ground quakes.
func _mace_smash(attacker: TransformerToken, victim: TransformerToken, ground: float) -> void:
	var start := attacker.global_position
	cue.emit("charge", {"position": start, "attacker": attacker})
	var overhead := {"arm_L": [Vector3(-2.9, 0, 0.3), Vector3(-0.3, 0, 0)], "arm_R": [Vector3(-2.9, 0, -0.3), Vector3(-0.3, 0, 0)]}
	_pose(attacker, overhead, 0.15)
	_shot("sky", attacker, victim)
	var apex := start.lerp(victim.global_position, 0.6) + Vector3.UP * 1.3
	var jump := attacker.create_tween()
	jump.tween_property(attacker, "global_position", apex, 0.3 * anim_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await jump.finished
	_slow_motion(0.3, 0.5)
	cue.emit("swing", {"position": apex, "heavy": true})
	_pose(attacker, {"arm_L": [Vector3(-1.0, 0, 0.2), Vector3(0, 0, 0)], "arm_R": [Vector3(-1.0, 0, -0.2), Vector3(0, 0, 0)]}, 0.1, Tween.TRANS_EXPO)
	var down := victim.global_position - _forward(attacker) * 0.45
	down.y = ground
	var drop := attacker.create_tween()
	drop.tween_property(attacker, "global_position", down, 0.14 * anim_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await drop.finished
	var at := victim.global_position + Vector3.UP * 0.2
	cue.emit("crash", {"position": victim.global_position})
	_burst(at, Color("#ffd24a"), 70, 3.4, 0.9, 3.0)
	cue.emit("quake", {"position": victim.global_position})
	var squash := victim.create_tween()
	squash.tween_property(victim.body_node, "scale", Vector3(1.4, 0.45, 1.4), 0.06 * anim_scale)
	await _impact(attacker, victim, at, "punch", 0.32)
	squash = victim.create_tween()
	squash.tween_property(victim.body_node, "scale", Vector3.ONE, 0.3 * anim_scale).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await squash.finished


## Surya gathers the sun above its head and hurls it.
func _sun_blast(attacker: TransformerToken, victim: TransformerToken) -> void:
	cue.emit("charge", {"position": attacker.global_position, "attacker": attacker})
	_shot("sky", attacker, victim)
	_pose(attacker, {"arm_L": [Vector3(-2.9, 0, 0.35), Vector3(-0.4, 0, 0)], "arm_R": [Vector3(-2.9, 0, -0.35), Vector3(-0.4, 0, 0)]}, 0.18)
	var sun := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	sun.mesh = sphere
	sun.material_override = _glow_mat(Color("#ffc040"), 6.0)
	sun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(sun)
	sun.global_position = attacker.global_position + Vector3.UP * 1.45
	sun.scale = Vector3.ONE * 0.1
	var grow := sun.create_tween()
	grow.tween_property(sun, "scale", Vector3.ONE, 0.45 * anim_scale).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_burst(sun.global_position, Color("#ffe080"), 30, 1.2, 0.6, -0.5)
	await grow.finished
	_slow_motion(0.35, 0.6)
	cue.emit("swing", {"position": sun.global_position, "heavy": true})
	_pose(attacker, {"arm_L": [Vector3(-1.6, 0, 0.1), Vector3(0, 0, 0)], "arm_R": [Vector3(-1.6, 0, -0.1), Vector3(0, 0, 0)]}, 0.1, Tween.TRANS_EXPO)
	var target := victim.global_position + Vector3.UP * 0.45
	var fly := sun.create_tween()
	fly.tween_property(sun, "global_position", target, 0.2 * anim_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fly.finished
	sun.queue_free()
	_burst(target, Color("#ffb020"), 80, 3.6, 1.0, 0.5)
	_burst(target, Color("#ffffff"), 30, 2.0, 0.5, 0.0)
	await _impact(attacker, victim, target, "punch", 0.28)


## The shadow vanishes in smoke and strikes from behind.
func _shadow_strike(attacker: TransformerToken, victim: TransformerToken) -> void:
	var smoke := Color("#2a1a3a")
	cue.emit("charge", {"position": attacker.global_position, "attacker": attacker})
	_burst(attacker.global_position + Vector3.UP * 0.4, smoke, 50, 1.4, 0.8, -1.0)
	cue.emit("whiff", {"position": attacker.global_position})
	attacker.visible = false
	await _wait(0.25)
	var behind := victim.global_position + _forward(attacker) * 0.5
	attacker.global_position = behind
	_face(attacker, victim.global_position)
	attacker.visible = true
	_burst(behind + Vector3.UP * 0.4, smoke, 40, 1.4, 0.7, -1.0)
	_slow_motion(0.3, 0.5)
	cue.emit("swing", {"position": behind, "heavy": true})
	var arm: Dictionary = attacker.arm_pivots["R"]
	var strike := attacker.create_tween().set_parallel(true)
	strike.tween_property(arm["shoulder"], "rotation", Vector3(-1.6, 0, 0.6), 0.08 * anim_scale).set_trans(Tween.TRANS_EXPO)
	strike.tween_property(arm["elbow"], "rotation", Vector3(-0.05, 0, 0), 0.08 * anim_scale)
	strike.tween_property(attacker.body_node, "rotation:y", -0.6, 0.08 * anim_scale)
	await strike.finished
	var at := victim.global_position + Vector3.UP * 0.45
	_burst(at, Color("#ff2a40"), 40, 2.8, 0.6)
	await _impact(attacker, victim, at, "punch")
	var back := attacker.create_tween()
	back.tween_property(attacker.body_node, "rotation:y", 0.0, 0.15 * anim_scale)
	await back.finished


## Robo Raja fires a laser from its visor.
func _laser(attacker: TransformerToken, victim: TransformerToken) -> void:
	cue.emit("charge", {"position": attacker.global_position, "attacker": attacker})
	await _pose(attacker, _guard(), 0.1)
	var eye := attacker.global_position + Vector3.UP * 0.82 + _forward(attacker) * 0.18
	var target := victim.global_position + Vector3.UP * 0.45
	_burst(eye, Color("#2ae0ff"), 20, 0.8, 0.4, 0.0)
	await _wait(0.2)
	_slow_motion(0.35, 0.7)
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.035
	var length := eye.distance_to(target)
	cyl.height = length
	beam.mesh = cyl
	beam.material_override = _glow_mat(Color("#40f0ff"), 8.0, 0.9)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(beam)
	beam.global_position = (eye + target) * 0.5
	beam.look_at(target, Vector3.UP if absf((target - eye).normalized().y) < 0.99 else Vector3.RIGHT)
	beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)   # cylinders stand along Y
	cue.emit("swing", {"position": eye, "heavy": true})
	for i in range(4):
		_burst(target, Color("#9ff8ff"), 14, 2.0, 0.4)
		await _wait(0.06)
	await _impact(attacker, victim, target, "punch", 0.22)
	beam.queue_free()


## The ghost glides into its victim, shakes it from inside and bursts out.
func _possess(attacker: TransformerToken, victim: TransformerToken) -> void:
	var start := attacker.global_position
	cue.emit("charge", {"position": start, "attacker": attacker})
	_pose(attacker, {"arm_L": [Vector3(-1.6, 0, 0.2), Vector3(0, 0, 0)], "arm_R": [Vector3(-1.6, 0, -0.2), Vector3(0, 0, 0)]}, 0.15)
	var glide := attacker.create_tween().set_parallel(true)
	glide.tween_property(attacker, "global_position", victim.global_position + Vector3.UP * 0.1, 0.4 * anim_scale).set_trans(Tween.TRANS_SINE)
	glide.tween_property(attacker, "scale", attacker.scale * 0.6, 0.4 * anim_scale)
	await glide.finished
	attacker.visible = false
	_burst(victim.global_position + Vector3.UP * 0.5, Color("#9ff0ff"), 30, 1.0, 0.7, -1.0)
	var shake := func(p: float) -> void:
		victim.body_node.rotation.z = sin(p * TAU * 6.0) * 0.35
		victim.body_node.position.x = sin(p * TAU * 9.0) * 0.05
	var t := victim.create_tween()
	t.tween_method(shake, 0.0, 1.0, 0.6 * anim_scale)
	await t.finished
	victim.body_node.rotation.z = 0.0
	victim.body_node.position.x = 0.0
	_slow_motion(0.3, 0.5)
	attacker.global_position = victim.global_position - _forward(attacker) * 0.5
	attacker.global_position.y = start.y
	attacker.scale = attacker.scale / 0.6
	attacker.visible = true
	var at := victim.global_position + Vector3.UP * 0.5
	_burst(at, Color("#c8f8ff"), 60, 3.0, 0.8, -0.5)
	cue.emit("swing", {"position": at, "heavy": true})
	await _impact(attacker, victim, at, "punch")
