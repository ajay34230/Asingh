class_name VaidyaClinic
extends Node3D
## The Vaidya's dispensary in the village: a canopy over a charpai, a sign, and the Vaidya. People brought in
## unconscious are laid on the charpai (others wait on mats beside it); the Vaidya kneels and treats each one,
## they get up, and they go home healed.

const TREAT_SECS := 10.0
const AT := Vector2(-45.0, 7.0)        # open ground just south of the temple

var vaidya: Npc
var _queue: Array = []            # patients waiting or being treated
var _t := 0.0
var _ter: TerrainBuilder


static func build(parent: Node3D, ter: TerrainBuilder, player: Node3D) -> VaidyaClinic:
	var c := VaidyaClinic.new()
	c.name = "VaidyaClinic"
	c._ter = ter
	parent.add_child(c)
	c.global_position = Vector3(AT.x, ter.sample_height(AT.x, AT.y), AT.y)
	c.rotation.y = deg_to_rad(30.0)
	c.add_to_group("clinic")
	c._build_place()
	c.vaidya = Npc.new().setup({"role": "vaidya", "voice": "old", "body": "elder", "robe": true, "scale": 0.98, "tint": Color(1.0, 0.97, 0.9)}, "idle", "Vaidya")
	c.vaidya.player = player as Player
	parent.add_child(c.vaidya)
	c.vaidya.global_position = c.global_transform * Vector3(1.6, 0.0, 0.9)
	c.vaidya.home_yaw = c.rotation.y - PI * 0.5
	c.vaidya.rotation.y = c.vaidya.home_yaw
	return c


func _build_place() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.28, 0.16)
	wood.roughness = 0.85
	var weave := StandardMaterial3D.new()
	weave.albedo_color = Color(0.82, 0.72, 0.5)
	weave.roughness = 1.0
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.95, 0.9, 0.78)
	cloth.roughness = 0.95
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	# charpai: wooden frame, four legs, a woven top
	_box(Vector3(0.95, 0.06, 2.0), Vector3(0, 0.45, 0), wood)
	_box(Vector3(0.85, 0.03, 1.9), Vector3(0, 0.49, 0), weave)
	for x in [-0.42, 0.42]:
		for z in [-0.92, 0.92]:
			_box(Vector3(0.08, 0.45, 0.08), Vector3(x, 0.22, z), wood)
	# canopy on four poles
	for x in [-1.6, 1.6]:
		for z in [-1.6, 1.6]:
			_box(Vector3(0.09, 2.5, 0.09), Vector3(x, 1.25, z), wood)
	_box(Vector3(3.6, 0.04, 3.6), Vector3(0, 2.5, 0), cloth)
	# waiting mats
	for i in 2:
		_box(Vector3(0.9, 0.02, 1.9), Vector3(-1.2 - i * 1.1, 0.01, 2.6), weave)
	# a low shelf of herb pots
	_box(Vector3(1.2, 0.5, 0.35), Vector3(1.0, 0.25, -1.4), wood)
	for i in 4:
		var pot := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.1
		sm.height = 0.18
		pot.mesh = sm
		var pm := StandardMaterial3D.new()
		pm.albedo_color = [Color(0.6, 0.32, 0.18), Color(0.3, 0.5, 0.25), Color(0.7, 0.55, 0.2), Color(0.5, 0.3, 0.35)][i]
		pot.material_override = pm
		pot.position = Vector3(0.55 + i * 0.3, 0.6, -1.4)
		add_child(pot)
	var sign := Label3D.new()
	sign.text = "वैद्य  Vaidya"
	sign.font_size = 64
	sign.outline_size = 12
	sign.pixel_size = 0.006
	sign.modulate = Color(1.0, 0.85, 0.4)
	sign.position = Vector3(0, 2.8, 1.62)
	add_child(sign)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(0.95, 0.5, 2.0)
	cs.shape = bx
	cs.position = Vector3(0, 0.25, 0)
	body.add_child(cs)
	add_child(body)


func _box(size: Vector3, at: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = at
	add_child(m)


## Where the stretcher team sets down (in front of the charpai).
func drop_point() -> Vector3:
	return global_transform * Vector3(0, 0, 2.2)


func _bed(i: int) -> Vector3:
	if i == 0:
		return global_transform * Vector3(0, 0.51, 0)
	return global_transform * Vector3(-1.2 - (i - 1) * 1.1, 0.03, 2.6)


## A patient arrives: on the charpai if it is free, otherwise on a mat to wait.
func admit(p: Npc) -> void:
	p.in_care = true
	p.rescue = null
	_queue.append(p)
	if _queue.size() == 1:
		_t = 0.0
	_lay_all()
	LogCollector.event("Vaidya admits %s" % p.name)


func _lay_all() -> void:
	var along := global_transform.basis.z.normalized()
	for i in _queue.size():
		var p: Npc = _queue[i]
		if not is_instance_valid(p):
			continue
		if not p.rig.clip_playing("ual_laytoidle"):
			p.rig.play_clip("ual_laytoidle", 1.0, 0.0, true, 0.0, 0.1)
		RescueTeam._lay_on(p, _bed(mini(i, 2)), along)


func _process(delta: float) -> void:
	_queue = _queue.filter(func(p) -> bool: return is_instance_valid(p))
	if _queue.is_empty():
		return
	_t += delta
	var p: Npc = _queue[0]
	if _t < TREAT_SECS:
		# the Vaidya kneels at the charpai and treats them
		if vaidya != null and not vaidya.rig.clip_playing("ual_fixing_kneeling"):
			vaidya.rig.play_clip("ual_fixing_kneeling", 1.0, 1.0, false, 0.0, 0.2)
		if p.rig.clip_playing("ual_laytoidle"):
			RescueTeam._lay_on(p, _bed(0), global_transform.basis.z.normalized())
	elif p.rig.clip_playing("ual_laytoidle") and p.rig._clip_rate == 0.0:
		if not p.rig.play_clip("ual_laytoidle", 1.0, 1.0, false, 0.0, 0.1):    # gets up
			# far from the camera the rig plays no clips, so the frozen lying pose would never end and this
			# branch would repeat for ever (the time cap below is never reached): just let them stand up
			p.rig.stop_clip(0.1)
		if vaidya != null:
			vaidya.rig.stop_clip(0.3)
			vaidya.say("Rest well. You will be fine.", 2.5)
	elif not p.rig.clip_playing() or _t > TREAT_SECS + 6.0:      # up (or never stuck lying, whatever the rig did)
		_queue.pop_front()
		p.healed()
		_t = 0.0
		_lay_all()
	p.rig.animate(delta, 0.0, true)
