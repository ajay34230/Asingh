class_name HumanRig
extends Node3D
## A procedurally built, jointed human figure (no imported assets): shaped head with eyes, brows,
## nose, lips and ears, hair/headwear, torso with clothing, arms with elbows and hands, legs with
## knees and boots. Joints are Node3Ds so the figure can be animated in code:
##   - locomotion: walk / run cycle driven by real ground speed (hip swing, knee flex, arm swing
##     opposite to the legs, torso counter-rotation, pelvis bob, forward lean)
##   - idle: breathing, weight shift, small head movements
##   - hammer: a repeating hammering motion for workers
##   - airborne: legs tucked, arms out
## The figure faces -Z (Godot forward) and is about 1.75 m tall at scale 1.
##
## Preset keys (all optional): scale, build, female, skin, hair_color, hair_style
## (0 short, 1 long, 2 bald, 3 turban, 4 headscarf, 5 cap), beard, top, bottom, accent, long_robe,
## boots, satchel, apron, sleeves_rolled, brow.

const UP_ARM := 0.29
const FORE_ARM := 0.27
const THIGH := 0.45
const SHIN := 0.44

var preset: Dictionary = {}
var mode := "locomotion"        # "locomotion", "idle", "hammer"
var _j: Dictionary = {}          # joint name -> Node3D
var _phase := 0.0
var _t := 0.0
var _speed_smooth := 0.0
var _air := 0.0
var _chest: Node3D
var _base_pelvis_y := 0.95
var _seed := 0.0


func setup(p: Dictionary, name_: String = "Human") -> HumanRig:
	preset = p
	name = name_
	_seed = float(hash(name_) % 1000) * 0.01
	_t = _seed * 10.0
	_build()
	return self


# --- construction helpers ----------------------------------------------------------------

func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO,
		scl: Vector3 = Vector3.ONE, rot_deg: Vector3 = Vector3.ZERO, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot_deg
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _sphere(r: float, seg: int = 14, rings: int = 8) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = rings
	return m


func _capsule(r: float, h: float, seg: int = 12) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = seg
	m.rings = 4
	return m


func _joint(parent: Node3D, key: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = key
	n.position = pos
	parent.add_child(n)
	_j[key] = n
	return n


## A limb segment hanging down from its joint (centre half way along its length): a tapered
## cylinder wrapped by a rounded capsule so both ends are soft.
func _segment(joint: Node3D, mat: Material, r_top: float, length: float, taper: float = 0.85) -> void:
	_mesh(joint, _capsule(r_top * taper * 1.02, length + r_top * taper * 1.2, 10), mat, Vector3(0, -length * 0.5, 0))
	var cone := CylinderMesh.new()
	cone.top_radius = r_top
	cone.bottom_radius = r_top * taper
	cone.height = length * 0.92
	cone.radial_segments = 10
	cone.rings = 1
	_mesh(joint, cone, mat, Vector3(0, -length * 0.5, 0))


# --- build -------------------------------------------------------------------------------

func _build() -> void:
	var s: float = preset.get("scale", 0.97)
	var build: float = preset.get("build", 1.0)
	var female: bool = preset.get("female", false)
	var skin_c: Color = preset.get("skin", Color(0.78, 0.58, 0.44))
	var hair_c: Color = preset.get("hair_color", Color(0.08, 0.06, 0.05))
	var top_c: Color = preset.get("top", Color(0.62, 0.55, 0.38))
	var bottom_c: Color = preset.get("bottom", Color(0.33, 0.30, 0.22))
	var accent_c: Color = preset.get("accent", Color(0.45, 0.20, 0.14))
	var long_robe: bool = preset.get("long_robe", false)
	var boots: bool = preset.get("boots", true)
	var style: int = preset.get("hair_style", 0)

	var skin_m := PropFactory.skin(skin_c)
	var hair_m := PropFactory.hair(hair_c)
	var top_m := PropFactory.fabric(top_c)
	var bottom_m := PropFactory.fabric(bottom_c)
	var accent_m := PropFactory.fabric(accent_c, 8.0)
	var boot_m := PropFactory.material(Color(0.20, 0.13, 0.09), 0.55)
	var dark_m := PropFactory.material(Color(0.04, 0.03, 0.03), 0.4)
	var white_m := PropFactory.material(Color(0.93, 0.92, 0.88), 0.25)
	var lip_m := PropFactory.skin(skin_c.darkened(0.18).lerp(Color(0.55, 0.28, 0.26), 0.3))

	var body := Node3D.new()
	body.name = "Body"
	body.scale = Vector3(build, 1.0, build) * s
	body.scale.y = s
	add_child(body)

	var pelvis := _joint(body, "pelvis", Vector3(0, _base_pelvis_y, 0))
	_mesh(pelvis, _sphere(0.5, 12, 6), bottom_m, Vector3(0, -0.02, 0), Vector3(0.30 if not female else 0.34, 0.20, 0.22))

	# Legs.
	for side in [-1, 1]:
		var tag := "L" if side < 0 else "R"
		var hip := _joint(pelvis, "hip_" + tag, Vector3(side * 0.095, -0.02, 0))
		var thigh_r := 0.085 if not female else 0.082
		_segment(hip, bottom_m if not long_robe else top_m, thigh_r, THIGH, 0.8)
		var knee := _joint(hip, "knee_" + tag, Vector3(0, -THIGH, 0))
		var shin_mat: Material = boot_m if boots and not long_robe else bottom_m
		_segment(knee, bottom_m, 0.062, SHIN * 0.55, 0.9)
		var shin_low := _joint(knee, "shin_" + tag, Vector3.ZERO)
		if boots:
			var bsh := CylinderMesh.new()
			bsh.top_radius = 0.07
			bsh.bottom_radius = 0.058
			bsh.height = SHIN * 0.62
			bsh.radial_segments = 10
			_mesh(shin_low, bsh, boot_m, Vector3(0, -SHIN * 0.69, 0))
		else:
			_segment(shin_low, skin_m, 0.045, SHIN * 0.85, 0.85)
		var ankle := _joint(knee, "ankle_" + tag, Vector3(0, -SHIN, 0))
		var foot := BoxMesh.new()
		foot.size = Vector3(0.095, 0.075, 0.26)
		_mesh(ankle, foot, boot_m if boots else skin_m, Vector3(0, -0.02, -0.055))
		_mesh(ankle, _sphere(0.5, 8, 4), boot_m if boots else skin_m, Vector3(0, -0.015, -0.15), Vector3(0.1, 0.07, 0.1))
		_mesh(ankle, _sphere(0.5, 8, 4), boot_m if boots else skin_m, Vector3(0, 0.0, 0.05), Vector3(0.1, 0.12, 0.1))
		if long_robe:
			pass

	# Spine, torso, neck.
	var spine := _joint(pelvis, "spine", Vector3.ZERO)
	var waist_w := 0.30 if not female else 0.26
	_mesh(spine, _sphere(0.5, 12, 6), top_m, Vector3(0, 0.14, 0), Vector3(waist_w, 0.34, 0.21))
	_chest = _joint(spine, "chest", Vector3(0, 0.30, 0))
	var chest_w := 0.37 if not female else 0.32
	_mesh(_chest, _sphere(0.5, 14, 7), top_m, Vector3(0, 0.12, 0), Vector3(chest_w, 0.38, 0.23))
	if female:
		for sx in [-1.0, 1.0]:
			_mesh(_chest, _sphere(0.5, 8, 4), top_m, Vector3(sx * 0.07, 0.10, -0.1), Vector3(0.13, 0.12, 0.11))
	# Tunic skirt / robe.
	if long_robe or preset.get("tunic", false):
		var skirt := CylinderMesh.new()
		skirt.top_radius = 0.17
		skirt.bottom_radius = 0.26 if long_robe else 0.21
		skirt.height = 0.88 if long_robe else 0.38
		skirt.radial_segments = 14
		skirt.rings = 1
		_mesh(pelvis, skirt, top_m, Vector3(0, -0.04 - (0.88 if long_robe else 0.38) * 0.5 + 0.12, 0))
	# Belt / apron / satchel strap.
	_mesh(pelvis, _sphere(0.5, 12, 4), accent_m, Vector3(0, 0.10, 0), Vector3(0.325 if not female else 0.30, 0.06, 0.235))
	if preset.get("apron", false):
		var ap := BoxMesh.new()
		ap.size = Vector3(0.28, 0.62, 0.025)
		_mesh(spine, ap, PropFactory.fabric(Color(0.28, 0.20, 0.14), 6.0, 0.7), Vector3(0, 0.12, -0.115), Vector3.ONE, Vector3(-4, 0, 0))
	if preset.get("satchel", false):
		var strap := BoxMesh.new()
		strap.size = Vector3(0.05, 0.62, 0.02)
		_mesh(spine, strap, accent_m, Vector3(0, 0.32, -0.002), Vector3.ONE, Vector3(0, 0, 38), false)
		var bag := BoxMesh.new()
		bag.size = Vector3(0.26, 0.20, 0.09)
		_mesh(pelvis, bag, PropFactory.fabric(Color(0.45, 0.31, 0.18), 4.0, 0.7), Vector3(0.24, -0.06, 0.04), Vector3.ONE, Vector3(0, 0, 8))

	# Shoulder girdle: a flattened wide ellipsoid that joins the arms to the chest.
	_mesh(_chest, _sphere(0.5, 14, 6), top_m, Vector3(0, 0.215, 0.0), Vector3(chest_w + 0.06, 0.11, 0.2))
	# Shoulders, arms.
	for side in [-1, 1]:
		var tag := "L" if side < 0 else "R"
		var shoulder_x: float = side * (chest_w * 0.5 * 0.80)
		var sh := _joint(_chest, "shoulder_" + tag, Vector3(shoulder_x, 0.225, 0))
		_mesh(sh, _sphere(0.058, 10, 6), top_m)
		_segment(sh, top_m, 0.055, UP_ARM, 0.85)
		var elbow := _joint(sh, "elbow_" + tag, Vector3(0, -UP_ARM, 0))
		var rolled: bool = preset.get("sleeves_rolled", false)
		_segment(elbow, skin_m if rolled else top_m, 0.047, FORE_ARM, 0.8)
		var wrist := _joint(elbow, "wrist_" + tag, Vector3(0, -FORE_ARM, 0))
		_mesh(wrist, _sphere(0.5, 10, 6), skin_m, Vector3(0, -0.055, 0), Vector3(0.075, 0.115, 0.045))
		_mesh(wrist, _sphere(0.5, 8, 4), skin_m, Vector3(side * 0.03 * -1.0, -0.04, -0.03), Vector3(0.03, 0.07, 0.03), Vector3(0, 0, side * 15.0))

	# Neck and head.
	var neck := _joint(_chest, "neck", Vector3(0, 0.30, 0))
	_mesh(neck, _capsule(0.052, 0.16, 8), skin_m, Vector3(0, 0.03, 0))
	var head := _joint(neck, "head", Vector3(0, 0.075, 0))
	_build_head(head, skin_m, hair_m, lip_m, dark_m, white_m, style, female, hair_c)
	_set_initial_pose()


func _build_head(head: Node3D, skin_m: Material, hair_m: Material, lip_m: Material,
		dark_m: Material, white_m: Material, style: int, female: bool, hair_c: Color) -> void:
	var cy := 0.095
	_mesh(head, _sphere(1.0, 18, 10), skin_m, Vector3(0, cy, 0.0), Vector3(0.092, 0.112, 0.103))
	# Jaw and chin give the lower face a real shape.
	_mesh(head, _sphere(1.0, 14, 8), skin_m, Vector3(0, cy - 0.065, -0.02), Vector3(0.078 if not female else 0.070, 0.068, 0.082))
	_mesh(head, _sphere(1.0, 10, 6), skin_m, Vector3(0, cy - 0.105, -0.05), Vector3(0.036, 0.03, 0.034))
	# Cheekbones, nose, brow ridge.
	for sx in [-1.0, 1.0]:
		_mesh(head, _sphere(1.0, 8, 4), skin_m, Vector3(sx * 0.055, cy - 0.03, -0.075), Vector3(0.03, 0.026, 0.026), Vector3.ZERO, false)
	_mesh(head, _sphere(1.0, 8, 5), skin_m, Vector3(0, cy - 0.02, -0.108), Vector3(0.016, 0.034, 0.02), Vector3(-12, 0, 0), false)
	_mesh(head, _sphere(1.0, 8, 4), skin_m, Vector3(0, cy - 0.047, -0.118), Vector3(0.015, 0.011, 0.014), Vector3.ZERO, false)
	_mesh(head, _sphere(1.0, 8, 4), skin_m, Vector3(0, cy + 0.045, -0.088), Vector3(0.075, 0.016, 0.02), Vector3.ZERO, false)
	# Eyes: socket shadow, white, iris, pupil highlight-free.
	for sx in [-1.0, 1.0]:
		_mesh(head, _sphere(1.0, 8, 4), lip_m, Vector3(sx * 0.037, cy + 0.016, -0.092), Vector3(0.022, 0.014, 0.012), Vector3.ZERO, false)
		_mesh(head, _sphere(1.0, 10, 6), white_m, Vector3(sx * 0.037, cy + 0.016, -0.097), Vector3(0.0165, 0.0115, 0.01), Vector3.ZERO, false)
		_mesh(head, _sphere(1.0, 8, 5), PropFactory.material(Color(0.25, 0.15, 0.08), 0.2), Vector3(sx * 0.037, cy + 0.016, -0.1035), Vector3(0.0088, 0.0088, 0.004), Vector3.ZERO, false)
		_mesh(head, _sphere(1.0, 6, 4), dark_m, Vector3(sx * 0.037, cy + 0.016, -0.1066), Vector3(0.0042, 0.0042, 0.0015), Vector3.ZERO, false)
		var brow := BoxMesh.new()
		brow.size = Vector3(0.042, 0.0075, 0.012)
		_mesh(head, brow, hair_m, Vector3(sx * 0.038, cy + 0.04, -0.098), Vector3.ONE, Vector3(0, 0, sx * -6.0), false)
		# Ears.
		_mesh(head, _sphere(1.0, 8, 5), skin_m, Vector3(sx * 0.094, cy - 0.005, 0.005), Vector3(0.012, 0.028, 0.02), Vector3.ZERO, false)
	# Mouth.
	var lip := BoxMesh.new()
	lip.size = Vector3(0.04, 0.007, 0.01)
	_mesh(head, lip, lip_m, Vector3(0, cy - 0.07, -0.094), Vector3.ONE, Vector3.ZERO, false)
	_mesh(head, _sphere(1.0, 8, 4), lip_m, Vector3(0, cy - 0.078, -0.09), Vector3(0.019, 0.007, 0.009), Vector3.ZERO, false)

	# Hair, beard, headwear.
	match style:
		0:   # short cropped hair
			_mesh(head, _sphere(1.0, 16, 9), hair_m, Vector3(0, cy + 0.025, 0.012), Vector3(0.096, 0.108, 0.108))
			for sx in [-1.0, 1.0]:
				_mesh(head, _sphere(1.0, 8, 5), hair_m, Vector3(sx * 0.082, cy - 0.01, 0.015), Vector3(0.02, 0.05, 0.06), Vector3.ZERO, false)
		1:   # long hair
			_mesh(head, _sphere(1.0, 16, 9), hair_m, Vector3(0, cy + 0.03, 0.014), Vector3(0.099, 0.108, 0.11))
			_mesh(head, _capsule(0.07, 0.34, 10), hair_m, Vector3(0, cy - 0.12, 0.07), Vector3(1.1, 1.0, 0.8))
			for sx in [-1.0, 1.0]:
				_mesh(head, _capsule(0.022, 0.2, 8), hair_m, Vector3(sx * 0.086, cy - 0.05, -0.012), Vector3.ONE, Vector3.ZERO, false)
		3:   # turban: wrapped cloth rings
			var cloth := PropFactory.fabric(Color(0.80, 0.74, 0.60), 10.0)
			for i in 4:
				var y := cy + 0.07 + i * 0.022
				var rr := 1.0 - i * 0.08
				_mesh(head, _sphere(1.0, 14, 6), cloth, Vector3(0, y - 0.04, 0.0), Vector3(0.108 * rr, 0.045, 0.118 * rr), Vector3(0, i * 20.0, i * 4.0 - 6.0))
		4:   # headscarf
			var sc := PropFactory.fabric(Color(0.55, 0.24, 0.20), 9.0)
			_mesh(head, _sphere(1.0, 16, 9), sc, Vector3(0, cy + 0.03, 0.02), Vector3(0.104, 0.112, 0.112))
			_mesh(head, _capsule(0.08, 0.30, 10), sc, Vector3(0, cy - 0.12, 0.06), Vector3(1.1, 1.0, 0.85))
		5:   # cap / hat with brim
			var hat := PropFactory.fabric(Color(0.50, 0.42, 0.28), 6.0)
			_mesh(head, _sphere(1.0, 16, 8), hat, Vector3(0, cy + 0.04, 0.0), Vector3(0.102, 0.085, 0.112))
			var brim := CylinderMesh.new()
			brim.top_radius = 0.20
			brim.bottom_radius = 0.20
			brim.height = 0.012
			brim.radial_segments = 20
			_mesh(head, brim, hat, Vector3(0, cy + 0.065, 0.0))
			_mesh(head, _sphere(1.0, 10, 5), hair_m, Vector3(0, cy - 0.005, 0.06), Vector3(0.08, 0.05, 0.05), Vector3.ZERO, false)
		_:
			pass
	if preset.get("beard", false):
		_mesh(head, _sphere(1.0, 12, 7), hair_m, Vector3(0, cy - 0.098, -0.028), Vector3(0.066, 0.052, 0.06))
		_mesh(head, _sphere(1.0, 8, 4), hair_m, Vector3(0, cy - 0.057, -0.1), Vector3(0.03, 0.007, 0.012), Vector3.ZERO, false)


func _set_initial_pose() -> void:
	for k in ["shoulder_L", "shoulder_R"]:
		(_j[k] as Node3D).rotation.z = -0.06 * (1.0 if k.ends_with("L") else -1.0)


# --- animation ---------------------------------------------------------------------------

## Drive the figure. `speed` is ground speed in m/s, `grounded` false while airborne.
func animate(delta: float, speed: float, grounded: bool) -> void:
	_t += delta
	_speed_smooth = lerpf(_speed_smooth, speed, 1.0 - exp(-10.0 * delta))
	_air = lerpf(_air, 0.0 if grounded else 1.0, 1.0 - exp(-14.0 * delta))
	match mode:
		"idle":
			_idle(delta, 0.0)
		"hammer":
			_hammer()
		_:
			if _speed_smooth < 0.15 and _air < 0.05:
				_idle(delta, 0.0)
			else:
				_locomotion(delta)


func _rx(key: String, a: float) -> void:
	(_j[key] as Node3D).rotation.x = a


func _idle(delta: float, _unused: float) -> void:
	var breathe := sin(_t * 1.7 + _seed)
	(_j["chest"] as Node3D).scale = Vector3(1.0, 1.0 + 0.012 * breathe, 1.0 + 0.016 * breathe)
	var sway := sin(_t * 0.6 + _seed * 3.0)
	var pel := _j["pelvis"] as Node3D
	pel.position.y = lerpf(pel.position.y, _base_pelvis_y, 1.0 - exp(-8.0 * delta))
	pel.rotation = pel.rotation.lerp(Vector3(0.0, 0.0, 0.012 * sway), 1.0 - exp(-8.0 * delta))
	(_j["spine"] as Node3D).rotation = (_j["spine"] as Node3D).rotation.lerp(Vector3(-0.02 + 0.01 * breathe, 0.0, -0.012 * sway), 1.0 - exp(-8.0 * delta))
	var look := sin(_t * 0.37 + _seed * 7.0)
	(_j["head"] as Node3D).rotation = (_j["head"] as Node3D).rotation.lerp(Vector3(0.03 * sin(_t * 0.5), 0.35 * look, 0.0), 1.0 - exp(-3.0 * delta))
	for tag in ["L", "R"]:
		var side := 1.0 if tag == "L" else -1.0
		var sh := _j["shoulder_" + tag] as Node3D
		sh.rotation = sh.rotation.lerp(Vector3(0.03 * breathe, 0.0, -0.07 * side), 1.0 - exp(-8.0 * delta))
		var el := _j["elbow_" + tag] as Node3D
		el.rotation = el.rotation.lerp(Vector3(0.16 + 0.02 * breathe, 0.0, 0.0), 1.0 - exp(-8.0 * delta))
		(_j["hip_" + tag] as Node3D).rotation = (_j["hip_" + tag] as Node3D).rotation.lerp(Vector3(0.0, 0.0, 0.0), 1.0 - exp(-10.0 * delta))
		(_j["knee_" + tag] as Node3D).rotation = (_j["knee_" + tag] as Node3D).rotation.lerp(Vector3(0.02, 0.0, 0.0), 1.0 - exp(-10.0 * delta))
		(_j["ankle_" + tag] as Node3D).rotation = (_j["ankle_" + tag] as Node3D).rotation.lerp(Vector3.ZERO, 1.0 - exp(-10.0 * delta))


func _hammer() -> void:
	var c := fmod(_t * 1.5, TAU)
	var up := 0.5 + 0.5 * sin(c)               # 1 = hammer raised
	var strike := pow(maxf(0.0, -sin(c + 0.4)), 3.0)
	var pel := _j["pelvis"] as Node3D
	pel.position.y = _base_pelvis_y - 0.02 * strike
	(_j["spine"] as Node3D).rotation = Vector3(-0.12 - 0.12 * strike, 0.18, 0.0)
	(_j["head"] as Node3D).rotation = Vector3(0.18 + 0.05 * strike, -0.15, 0.0)
	var sr := _j["shoulder_R"] as Node3D
	sr.rotation = Vector3(-0.9 - 1.0 * up, 0.0, 0.08)
	(_j["elbow_R"] as Node3D).rotation = Vector3(0.6 + 1.0 * up - 0.5 * strike, 0.0, 0.0)
	var sl := _j["shoulder_L"] as Node3D
	sl.rotation = Vector3(-0.7, 0.0, -0.1)
	(_j["elbow_L"] as Node3D).rotation = Vector3(0.9, 0.0, 0.0)
	for tag in ["L", "R"]:
		(_j["hip_" + tag] as Node3D).rotation = Vector3(0.12 if tag == "L" else -0.1, 0.0, 0.0)
		(_j["knee_" + tag] as Node3D).rotation = Vector3(-0.14, 0.0, 0.0)
	(_j["chest"] as Node3D).scale = Vector3.ONE


func _locomotion(delta: float) -> void:
	var sp := _speed_smooth
	var run_k := smoothstep(2.8, 5.0, sp)
	var freq := sp / (1.2 + 0.5 * sp)                 # gait cycles per second
	_phase = fmod(_phase + TAU * freq * delta, TAU)
	var stride := clampf(sp / 2.6, 0.0, 1.0)          # how pronounced the cycle is
	var amp := lerpf(0.42, 0.85, run_k) * minf(1.0, stride + 0.3)
	var air := _air
	(_j["chest"] as Node3D).scale = Vector3.ONE

	for side in [0, 1]:
		var tag := "L" if side == 0 else "R"
		var opp := "R" if side == 0 else "L"
		var ph := _phase + (PI if side == 1 else 0.0)
		var swing := sin(ph)
		var hip_a := amp * swing
		# Knee bends while the leg swings forward; slight flex on contact.
		var flex := (0.15 + lerpf(0.55, 1.15, run_k) * maxf(0.0, cos(ph + 0.35))) * minf(1.0, stride + 0.2)
		var hip := _j["hip_" + tag] as Node3D
		var knee := _j["knee_" + tag] as Node3D
		var ankle := _j["ankle_" + tag] as Node3D
		hip.rotation.x = lerpf(hip_a, -0.65 if side == 0 else -0.15, air)
		knee.rotation.x = -lerpf(flex, 1.1 if side == 0 else 0.6, air)
		ankle.rotation.x = lerpf(-0.25 * cos(ph + 0.35) * stride + 0.4 * maxf(0.0, -swing) * 0.4, 0.3, air)
		# Arms swing opposite to the same-side leg.
		var sh := _j["shoulder_" + tag] as Node3D
		var el := _j["elbow_" + tag] as Node3D
		var arm_swing := -sin(ph) * lerpf(0.38, 0.8, run_k) * minf(1.0, stride + 0.2)
		sh.rotation.x = lerpf(arm_swing, -0.4, air)
		sh.rotation.z = -(0.06 + 0.1 * air) * (1.0 if tag == "L" else -1.0)
		el.rotation.x = lerpf(0.22 + lerpf(0.1, 1.0, run_k) * (0.5 + 0.5 * maxf(0.0, -sin(ph))), 0.5, air)
		var _unused := opp

	# Pelvis: vertical bob at twice the step rate, small sway side to side, torso counter-twist.
	var pel := _j["pelvis"] as Node3D
	var bob := (0.018 + 0.03 * run_k) * stride
	pel.position.y = _base_pelvis_y - bob * (1.0 - cos(2.0 * _phase)) * 0.5 + 0.0
	pel.rotation = Vector3(0.0, 0.14 * sin(_phase) * stride, -0.03 * sin(_phase) * stride)
	var spine := _j["spine"] as Node3D
	var lean := 0.03 + 0.07 * stride + 0.14 * run_k
	spine.rotation = Vector3(-lean, -0.2 * sin(_phase) * stride, 0.025 * sin(_phase) * stride)
	var head := _j["head"] as Node3D
	head.rotation = Vector3(lean * 0.8 - 0.02, 0.1 * sin(_phase) * stride, 0.0)
