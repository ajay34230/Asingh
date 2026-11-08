class_name Arrow
extends Node3D
## A flying arrow: leaves the string at ~40 m/s on a real ballistic arc aimed to land on the target,
## turns to follow its flight, leaves a faint streak, and on impact sticks into the enemy (or the ground or a
## wall) and quivers before it fades away.

const SPEED := 40.0
const G := 6.0                 # a little less than real gravity so arcs read well on a phone screen
static var headshots := 0      # counted for the selftest and stats
var vel := Vector3.ZERO
var foe: Enemy
var dmg := 0.0
var shooter: Node3D
var fire := false              # fire arrow: burns the target for a few seconds
var _burn_t := 0.0
var _burn_tick := 0.0
var _burning: Enemy
var _flame: MeshInstance3D
var _life := 0.0
var _stuck := -1.0
var _wobble := 0.0
var _trail: MeshInstance3D
var _model: Node3D


func launch(from: Transform3D, target: Vector3, f: Enemy, damage: float, by: Node3D) -> void:
	foe = f
	dmg = damage
	shooter = by
	global_transform = from
	var d := target - from.origin
	var flat := Vector2(d.x, d.z).length()
	var t := maxf(flat / SPEED, 0.05)
	var dir := Vector3(d.x, 0.0, d.z).normalized() if flat > 0.01 else -from.basis.z
	vel = dir * (flat / t) + Vector3.UP * ((d.y + 0.5 * G * t * t) / t)
	_model = RealHuman.arrow_model()
	if _model == null:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.01
		cm.bottom_radius = 0.01
		cm.height = 0.8
		mi.mesh = cm
		mi.rotation.x = PI * 0.5
		_model = Node3D.new()
		_model.add_child(mi)
	add_child(_model)
	_trail = MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.006
	tm.bottom_radius = 0.0
	tm.height = 1.0
	tm.radial_segments = 4
	_trail.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 0.92, 0.45)
	_trail.material_override = mat
	_trail.rotation.x = PI * 0.5
	_trail.position = Vector3(0, 0, 0.9)
	_trail.scale = Vector3(1, 1.1, 1)
	add_child(_trail)
	if fire:
		mat.albedo_color = Color(1.0, 0.55, 0.15, 0.8)
		_trail.scale = Vector3(2.5, 1.6, 2.5)
		_flame = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.18
		sm.radial_segments = 8
		sm.rings = 4
		_flame.mesh = sm
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.albedo_color = Color(1.0, 0.62, 0.18, 0.85)
		fm.emission_enabled = true
		fm.emission = Color(1.0, 0.45, 0.1)
		fm.emission_energy_multiplier = 3.0
		_flame.material_override = fm
		_flame.position = Vector3(0, 0, -0.38)
		add_child(_flame)
	_face(vel)


## Height of the head above an enemy's feet (monsters set their own `head_h`).
static func head_height(en: Node3D) -> float:
	var h = en.get("head_h")
	return float(h) if h != null else 1.62


static func chest_height(en: Node3D) -> float:
	var h = en.get("chest_h")
	return float(h) if h != null else 1.1


func _face(v: Vector3) -> void:
	if v.length() > 0.01:
		look_at(global_position + v, Vector3.UP if absf(v.normalized().y) < 0.98 else Vector3.FORWARD)


func _physics_process(delta: float) -> void:
	_life += delta
	if _stuck >= 0.0:
		_stuck += delta
		if _wobble > 0.0:                       # the shaft quivers after it bites in
			_wobble = maxf(0.0, _wobble - delta * 3.0)
			_model.rotation.x = sin(_stuck * 60.0) * 0.06 * _wobble
		if _flame != null:
			_flame.scale = Vector3.ONE * (0.8 + 0.35 * sin(_stuck * 31.0)) * clampf(1.0 - (_stuck - 4.0) / 2.0, 0.0, 1.0)
		if _burn_t > 0.0 and is_instance_valid(_burning) and not _burning.dead:
			_burn_t -= delta
			_burn_tick -= delta
			if _burn_tick <= 0.0:
				_burn_tick = 0.5
				_burning.take_hit_ground(3.0)
				FloatText.spawn(_burning.get_parent(), _burning.global_position + Vector3(0, 2.0, 0), "3", Color(1.0, 0.5, 0.1), 0.8)
		if _stuck > 6.0:
			queue_free()
		return
	if _flame != null:
		_flame.scale = Vector3.ONE * (0.85 + 0.3 * sin(_life * 40.0))
	if _life > 3.5:
		queue_free()
		return
	var prev := global_position
	vel.y -= G * delta
	var next := prev + vel * delta
	# enemies along this step (the chosen target first, then anyone else in the way)
	var victims: Array = []
	if is_instance_valid(foe) and not foe.dead:
		victims.append(foe)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != foe:
			victims.append(e)
	for e in victims:
		var en := e as Enemy
		if en == null or en.dead:
			continue
		var hover := 0.0           # flying bodies already float at their hover height
		var seg := next - prev
		# a boss's open weak spot sits in front of its chest: check it before the body
		var bb = en.get("boss")
		if bb != null and bb.gem_open():
			var gp: Vector3 = bb.gem_world()
			var tg := clampf((gp - prev).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
			if (prev + seg * tg).distance_to(gp) < 0.45:
				global_position = prev + seg * tg
				en.set("last_hit_at", gp)
				en.take_hit("arrow", dmg * (1.25 if fire else 1.0), vel.normalized())
				Sfx.at("tink", global_position, -2.0, 1.6)
				_stick(en)
				return
		var head := en.global_position + Vector3(0, head_height(en) + hover, 0)
		# where this step passes closest to the enemy's upright centre line, and how high the arrow is there
		var base := en.global_position + Vector3(0, hover, 0)
		var s2 := Vector2(seg.x, seg.z)
		var rel := Vector2(base.x - prev.x, base.z - prev.z)
		var raw := rel.dot(s2) / maxf(s2.length_squared(), 0.0001)
		if raw > 1.0 and Vector2(next.x - base.x, next.z - base.z).length() > 0.25:
			continue                    # still closing in: the next step reaches the closest point
		var tt := clampf(raw, 0.0, 1.0)
		var p := prev + seg * tt
		var horiz := Vector2(p.x - base.x, p.z - base.z).length()
		var body_r := clampf(chest_height(en) * 0.45, 0.5, 1.0)
		if horiz > body_r or p.y < base.y - 0.1 or p.y > head.y + 0.3:
			continue
		var is_head := absf(p.y - head.y) < 0.3 and horiz < 0.4
		if true:
			global_position = p - vel.normalized() * minf(horiz, 0.3)
			var amount := dmg * (2.5 if is_head and en.get("boss") == null else (1.5 if is_head else 1.0)) * (1.25 if fire else 1.0)
			if "last_hit_at" in en:
				en.set("last_hit_at", global_position)
			en.take_hit("arrow", amount, vel.normalized())
			if is_head:
				headshots += 1
				FloatText.spawn(en.get_parent(), head + Vector3(0, 0.7, 0), Loc.t("HEADSHOT"), Color(1.0, 0.3, 0.2), 1.3, 1.4, 1.1)
				StoryFX.hitstop(0.06)
				var ach := get_tree().get_first_node_in_group("achievements")
				if ach != null and ach.has_method("unlock") and en.dead:
					ach.call("unlock", "headshot")
			if Engine.time_scale < 0.5:
				var ach2 := get_tree().get_first_node_in_group("achievements")
				if ach2 != null and ach2.has_method("unlock"):
					ach2.call("unlock", "focus")
			Sfx.at("hit_thud", global_position, -4.0, 1.4)
			if fire and not en.dead:
				_burning = en
				_burn_t = 4.0
				_burn_tick = 0.5
			_stick(en)
			return
	var q := PhysicsRayQueryParameters3D.create(prev, next)
	if shooter is CollisionObject3D:
		q.exclude = [(shooter as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and not (hit.collider is CharacterBody3D):
		global_position = (hit.position as Vector3) - vel.normalized() * 0.25
		Sfx.at("tink", global_position, -6.0, 1.2)
		_stick(null)
		return
	global_position = next
	_face(vel)
	_trail.scale.y = clampf(vel.length() / SPEED, 0.2, 1.2)


func _stick(into: Node3D) -> void:
	_stuck = 0.0
	_wobble = 1.0
	_trail.visible = false
	if into != null and is_instance_valid(into):
		var g := global_transform
		get_parent().remove_child(self)
		into.add_child(self)
		global_transform = g
