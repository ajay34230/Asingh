## Instant replay of the last fight. While a fight runs, every frame records both
## fighters' transforms (root, body and every limb pivot) and the cues (impacts, blocks)
## with their times. Playback restores those poses at half speed while the camera
## circles the fighters, re-fires impact flashes, then puts everything back.
class_name FightReplay
extends Node

signal cue(name: String, data: Dictionary)
signal finished

var recording := false
var playing := false
var camera: Camera3D
var _frames: Array = []          ## [{t, a: pose, v: pose}]
var _cues: Array = []            ## [{t, name, data}]
var _a: TransformerToken
var _v: TransformerToken
var _t0 := 0


func start(attacker: TransformerToken, victim: TransformerToken) -> void:
	_a = attacker
	_v = victim
	_frames.clear()
	_cues.clear()
	_t0 = Time.get_ticks_msec()
	recording = true


func stop() -> void:
	recording = false


func has_replay() -> bool:
	return _frames.size() > 10 and is_instance_valid(_a) and is_instance_valid(_v)


func note_cue(name: String, data: Dictionary) -> void:
	if recording:
		_cues.append({"t": _game_time(), "name": name, "data": data.duplicate()})


## Recording uses game time (scaled), so slow motion and hit-stops replay as they played.
var _game_clock := 0.0


func _game_time() -> float:
	return _game_clock


func _process(delta: float) -> void:
	if recording:
		_game_clock += delta
		_frames.append({"t": _game_clock, "a": _pose(_a), "v": _pose(_v)})


static func _pose(t: TransformerToken) -> Dictionary:
	var p := {"root": t.global_transform, "body": t.body_node.transform, "pivots": []}
	for group in [t.arm_pivots, t.leg_pivots]:
		for side in ["L", "R"]:
			for joint in group[side]:
				(p["pivots"] as Array).append((group[side][joint] as Node3D).transform)
	return p


static func _apply(t: TransformerToken, p: Dictionary) -> void:
	t.global_transform = p["root"]
	t.body_node.transform = p["body"]
	var i := 0
	for group in [t.arm_pivots, t.leg_pivots]:
		for side in ["L", "R"]:
			for joint in group[side]:
				(group[side][joint] as Node3D).transform = p["pivots"][i]
				i += 1


## Plays the recording at `speed` (0.5 = half speed) with an orbiting camera.
func play(speed := 0.5) -> void:
	if not has_replay() or playing:
		return
	playing = true
	var saved_a := _pose(_a)
	var saved_v := _pose(_v)
	var saved_cam := camera.global_transform
	var saved_fov := camera.fov
	var director: Node = camera.get_parent().get_node_or_null("CameraDirector")
	if director:
		director.set_process(false)
	var duration: float = _frames[-1]["t"]
	var clock := 0.0
	var fi := 0
	var ci := 0
	var mid0: Vector3 = (_frames[0]["a"]["root"] as Transform3D).origin.lerp((_frames[0]["v"]["root"] as Transform3D).origin, 0.5)
	cue.emit("replay_start", {})
	while clock < duration:
		var dt := get_process_delta_time() / maxf(Engine.time_scale, 0.01)
		clock += dt * speed
		while fi < _frames.size() - 1 and float(_frames[fi + 1]["t"]) <= clock:
			fi += 1
		_apply(_a, _frames[fi]["a"])
		_apply(_v, _frames[fi]["v"])
		while ci < _cues.size() and float(_cues[ci]["t"]) <= clock:
			cue.emit(_cues[ci]["name"], _cues[ci]["data"])
			ci += 1
		## Camera: a slow orbit around the fighters, low and close.
		var a_pos := _a.global_position
		var v_pos := _v.global_position
		var mid := a_pos.lerp(v_pos, 0.5)
		if mid.distance_to(mid0) > 3.0:
			mid = mid0.lerp(mid, 0.3)   # keep framing on the fight, not the far throw
		var ang := clock / duration * PI * 1.2
		var cam_pos := mid + Vector3(cos(ang) * 3.0, 1.1, sin(ang) * 3.0)
		camera.look_at_from_position(cam_pos, mid + Vector3(0, 0.45, 0), Vector3.UP)
		camera.fov = 40.0
		await get_tree().process_frame
	_apply(_a, saved_a)
	_apply(_v, saved_v)
	camera.global_transform = saved_cam
	camera.fov = saved_fov
	if director:
		director.set_process(true)
	playing = false
	cue.emit("replay_end", {})
	finished.emit()
