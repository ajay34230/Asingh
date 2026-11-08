## Keeps tokens alive between moves: breathing, looking around, now and then a stretch
## or a wave; teammates cheer when their side captures and cower when an enemy strikes
## close by. Only touches tokens that are standing still, so it never fights the move,
## fight or throw animations.
class_name TokenLife
extends Node

var game: GameController
var _time := 0.0
var _next_gesture := {}       ## token -> time of its next idle gesture
var _gesturing := {}          ## token -> true while a gesture runs


func _process(delta: float) -> void:
	_time += delta
	if game == null or game.fast_mode:
		return
	for color in game.tokens:
		for i in range(game.tokens[color].size()):
			var token: TransformerToken = game.tokens[color][i]
			if not is_instance_valid(token) or token.is_moving or _gesturing.has(token):
				continue
			if game.busy and _is_current(color):
				continue
			var phase := float(i) * 1.3 + float(hash(color) % 7)
			## Breathing: a slow rise and swell of the body.
			var b := sin(_time * 1.6 + phase)
			token.body_node.scale = Vector3(1.0 + b * 0.012, 1.0 + b * 0.025, 1.0 + b * 0.012)
			## Looking around: a gentle turn of the head and body.
			token.body_node.rotation.y = sin(_time * 0.45 + phase) * 0.35
			if not _next_gesture.has(token):
				_next_gesture[token] = _time + randf_range(3.0, 12.0)
			elif _time > float(_next_gesture[token]):
				_next_gesture[token] = _time + randf_range(6.0, 16.0)
				_gesture(token)


func _is_current(color: String) -> bool:
	return not game.engine.seats.is_empty() and game.current_color() == color


func _gesture(token: TransformerToken) -> void:
	_gesturing[token] = true
	token.transform_out(0.15)
	var side := "L" if randf() < 0.5 else "R"
	var arm: Dictionary = token.arm_pivots[side]
	var t := token.create_tween()
	if randf() < 0.5:
		## Wave: arm up, wrist rocks side to side.
		t.tween_property(arm["shoulder"], "rotation", Vector3(-2.7, 0, 0.4 if side == "L" else -0.4), 0.25)
		for k in range(3):
			t.tween_property(arm["elbow"], "rotation:z", 0.5, 0.15)
			t.tween_property(arm["elbow"], "rotation:z", -0.5, 0.15)
	else:
		## Stretch: both arms up, body rises on its toes.
		var other: Dictionary = token.arm_pivots["R" if side == "L" else "L"]
		t.set_parallel(true)
		t.tween_property(arm["shoulder"], "rotation", Vector3(-2.9, 0, 0.3), 0.4)
		t.tween_property(other["shoulder"], "rotation", Vector3(-2.9, 0, -0.3), 0.4)
		t.tween_property(token.body_node, "position:y", 0.05, 0.4)
		t.chain().tween_interval(0.3)
	t.set_parallel(false)
	t.tween_callback(func() -> void: _rest(token))


func _rest(token: TransformerToken) -> void:
	if not is_instance_valid(token):
		return
	var t := token.create_tween().set_parallel(true)
	for side in ["L", "R"]:
		var arm: Dictionary = token.arm_pivots[side]
		t.tween_property(arm["shoulder"], "rotation", Vector3.ZERO, 0.3)
		t.tween_property(arm["elbow"], "rotation", Vector3.ZERO, 0.3)
	t.tween_property(token.body_node, "position:y", 0.0, 0.3)
	await t.finished
	if is_instance_valid(token):
		token.is_transformed = true
		token.transform_in(0.25)
	_gesturing.erase(token)


## A capture: the attacker's side cheers, the victim's side cowers.
func react_to_capture(attacker_color: String, victim_color: String, exclude: Array) -> void:
	if game == null or game.fast_mode:
		return
	for color in [attacker_color, victim_color]:
		if not game.tokens.has(color):
			continue
		for token in game.tokens[color]:
			if exclude.has(token) or _gesturing.has(token) or token.is_moving:
				continue
			if color == attacker_color:
				_cheer(token)
			else:
				_cower(token)


func _cheer(token: TransformerToken) -> void:
	_gesturing[token] = true
	token.transform_out(0.12)
	var t := token.create_tween()
	for n in range(2):
		t.set_parallel(true)
		for side in ["L", "R"]:
			t.tween_property(token.arm_pivots[side]["shoulder"], "rotation", Vector3(-2.8, 0, 0.5 if side == "L" else -0.5), 0.15)
		t.tween_property(token.body_node, "position:y", 0.14, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.set_parallel(false)
		t.tween_property(token.body_node, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void: _rest(token))


func _cower(token: TransformerToken) -> void:
	_gesturing[token] = true
	token.transform_out(0.12)
	var t := token.create_tween().set_parallel(true)
	for side in ["L", "R"]:
		t.tween_property(token.arm_pivots[side]["shoulder"], "rotation", Vector3(-2.2, 0, -0.7 if side == "L" else 0.7), 0.15)
		t.tween_property(token.arm_pivots[side]["elbow"], "rotation", Vector3(-1.6, 0, 0), 0.15)
	t.tween_property(token.body_node, "scale", Vector3(1.05, 0.85, 1.05), 0.15)
	t.chain().tween_interval(0.6)
	t.chain().tween_property(token.body_node, "scale", Vector3.ONE, 0.2)
	t.chain().tween_callback(func() -> void: _rest(token))


## Two tokens of one colour on the same square: they turn to each other and high-five.
func high_five(a: TransformerToken, b: TransformerToken) -> void:
	if game == null or game.fast_mode:
		return
	for pair in [[a, b], [b, a]]:
		var me: TransformerToken = pair[0]
		var other: TransformerToken = pair[1]
		_gesturing[me] = true
		me.transform_out(0.12)
		var flat := other.global_position - me.global_position
		if flat.length_squared() > 0.0001:
			me.rotation.y = atan2(flat.x, flat.z)
		var t := me.create_tween()
		t.tween_property(me.arm_pivots["R"]["shoulder"], "rotation", Vector3(-2.5, 0, -0.2), 0.18)
		t.tween_property(me.body_node, "position:y", 0.1, 0.1)
		t.tween_property(me.body_node, "position:y", 0.0, 0.12)
		t.tween_interval(0.2)
		t.tween_callback(func() -> void: _rest(me))
