class_name RescueTeam
extends Node3D
## Two stretcher bearers sent for someone lying unconscious: they walk in, lift the person onto the stretcher
## and carry them to the Vaidya (VaidyaClinic). Far from the player, or after a long carry, the walk is cut
## short and they arrive straight away. Strike a bearer, or the person on the stretcher, and they die for good.

const SPEED := 2.1
const HALF := 1.3                 # stretcher centre to each bearer
const CARRY_H := 0.8              # stretcher height when carried

var patient: Npc
var clinic: Node3D
var front: RealHuman
var rear: RealHuman
var stretcher: Node3D
var state := 0                    # 0 coming, 1 lifting, 2 carrying, 3 handed over, 4 aborted
var t := 0.0
var centre := Vector3.ZERO        # stretcher centre on the ground below it
var fwd := Vector3.FORWARD
var height := CARRY_H
var _ter: TerrainBuilder


static func send(p: Npc) -> RescueTeam:
	var r := RescueTeam.new()
	r.name = "RescueTeam_" + String(p.name)
	r.patient = p
	p.get_parent().add_child(r)
	r._begin()
	return r


func _begin() -> void:
	add_to_group("rescuers")
	clinic = get_tree().get_first_node_in_group("clinic") as Node3D
	_ter = get_tree().current_scene.get("terrain") as TerrainBuilder
	var to := (clinic.global_position - patient.global_position) if clinic != null else Vector3.FORWARD
	to.y = 0.0
	var dir := to.normalized() if to.length() > 0.5 else Vector3.FORWARD
	centre = _ground(patient.global_position + dir * minf(18.0, maxf(to.length(), 6.0)))
	fwd = (patient.global_position - centre)
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.1 else -dir
	front = _bearer({"body": "m_Worker", "scale": 1.0, "natural": true, "tint": Color(0.95, 0.93, 0.85)}, "BearerFront")
	rear = _bearer({"body": "m_Casual", "scale": 0.98, "natural": true, "tint": Color(0.92, 0.9, 0.82)}, "BearerRear")
	stretcher = _make_stretcher()
	add_child(stretcher)
	LogCollector.event("rescue team sent for %s" % patient.name)


func _bearer(preset: Dictionary, label: String) -> RealHuman:
	var r := RealHuman.new().setup(preset, label)
	add_child(r)
	r.set_process(false)
	return r


func _make_stretcher() -> Node3D:
	var s := Node3D.new()
	s.name = "Stretcher"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.3, 0.17)
	wood.roughness = 0.8
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.88, 0.58, 0.22)            # saffron canvas
	cloth.roughness = 0.95
	for x in [-0.3, 0.3]:
		var pole := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.05, 0.05, HALF * 2.0 + 0.2)
		pole.mesh = pm
		pole.material_override = wood
		pole.position = Vector3(x, 0, 0)
		s.add_child(pole)
	var c := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.58, 0.02, 1.9)
	c.mesh = cm
	c.material_override = cloth
	s.add_child(c)
	return s


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, _ter.sample_height(p.x, p.z) if _ter != null else p.y, p.z)


## The bearers' positions now (for blows).
func bearer_positions() -> Array:
	return [front.global_position, rear.global_position] if front != null else []


## A blow landed on a bearer: they drop everything and run; the person on the stretcher dies.
func struck() -> void:
	if state >= 3:
		return
	if patient != null and is_instance_valid(patient) and not patient.in_care:
		patient.die_forever("the stretcher team was attacked")
	abort()


func abort() -> void:
	if state == 4:
		return
	state = 4
	if patient != null and is_instance_valid(patient):
		patient.rescue = null
		patient.global_position = _ground(patient.global_position)
		if patient.death_clip != "":
			patient.rig.play_clip(patient.death_clip, 1.0, 1.0, true, 99.0, 0.1, true)     # lies where dropped
	create_tween().tween_interval(0.4)
	queue_free.call_deferred()


func _process(delta: float) -> void:
	if state == 4 or patient == null or not is_instance_valid(patient):
		return
	t += delta
	var speed := 0.0
	match state:
		0:   # walk in with the empty stretcher
			var target := _ground(patient.global_position)
			var to := target - centre
			to.y = 0.0
			if to.length() > 0.15:
				fwd = to.normalized()
				centre = _ground(centre + fwd * minf(SPEED * delta, to.length()))
				speed = SPEED
			else:
				state = 1
				t = 0.0
				for b in [front, rear]:
					b.play_clip("ual_pickup_table", 1.0, 0.9, false, 0.0, 0.1)
		1:   # set it down, roll the person onto it, lift
			height = lerpf(CARRY_H, 0.15, clampf(t / 0.5, 0.0, 1.0)) if t < 1.0 else lerpf(0.15, CARRY_H, clampf((t - 1.0) / 0.6, 0.0, 1.0))
			if t >= 0.6 and not patient.has_meta("on_stretcher"):
				patient.set_meta("on_stretcher", true)
				patient.rig.play_clip("ual_laytoidle", 1.0, 0.0, true, 0.0, 0.15)   # lying on the back, still
			if t >= 1.7:
				state = 2
				t = 0.0
				var dest := _dest()
				var to2 := dest - centre
				to2.y = 0.0
				if to2.length() > 0.1:
					fwd = to2.normalized()
		2:   # carry to the Vaidya
			var dest2 := _dest()
			var to3 := dest2 - centre
			to3.y = 0.0
			var player := get_tree().current_scene.get("player") as Node3D
			var far := player == null or player.global_position.distance_to(centre) > 45.0
			if to3.length() < 0.5 or t > 25.0 or (far and t > 3.0):
				_hand_over()
				return
			fwd = fwd.slerp(to3.normalized(), minf(1.0, 3.0 * delta)).normalized()
			centre = _ground(centre + fwd * SPEED * delta)
			speed = SPEED
	_place(delta, speed)


func _dest() -> Vector3:
	if clinic != null:
		return _ground(clinic.call("drop_point"))
	return centre


func _place(delta: float, speed: float) -> void:
	var yaw := atan2(-fwd.x, -fwd.z)
	var top := centre + Vector3.UP * height
	stretcher.global_transform = Transform3D(Basis(Vector3.UP, yaw), top)
	front.global_position = _ground(centre + fwd * HALF)
	rear.global_position = _ground(centre - fwd * HALF)
	front.rotation.y = yaw
	rear.rotation.y = yaw
	front.animate(delta, speed, true)
	rear.animate(delta, speed, true)
	if patient.has_meta("on_stretcher"):
		_lay_on(patient, top + Vector3.UP * 0.03, fwd)


## Puts someone lying on their back along dir, their middle at the point (works for any lying pose).
static func _lay_on(p: Npc, at: Vector3, dir: Vector3) -> void:
	p.global_position = at
	var head := p.rig._bone_pos("head")
	var hips := p.rig._bone_pos("hips")
	var body := head - hips
	body.y = 0.0
	if body.length() > 0.2:
		var want := atan2(dir.x, dir.z)
		var have := atan2(body.x, body.z)
		p.rotation.y += wrapf(want - have, -PI, PI)
		head = p.rig._bone_pos("head")
		hips = p.rig._bone_pos("hips")
	var mid := (head + hips) * 0.5
	var low := minf(hips.y, head.y)
	p.global_position += Vector3(at.x - mid.x, at.y - low, at.z - mid.z)


func _hand_over() -> void:
	state = 3
	patient.remove_meta("on_stretcher")
	if clinic != null:
		clinic.call("admit", patient)
	else:
		patient.in_care = true
		patient.healed()
	queue_free()
