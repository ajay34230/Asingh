class_name BossBrain
extends Node
## Gives a boss monster (Yeti, Mushroom King, Demon, Dragon) a real fight in three phases:
##   Phase 1 (full to 2/3 health): heavy swings, and a STOMP: a red ring spreads on the ground, then a
##     shockwave hits everyone inside it who is on the ground. Jump, roll or get out of the ring.
##   Phase 2 (below 2/3): a roar, minions rise, and a glowing WEAK SPOT appears on its chest. It adds a CHARGE:
##     a red lane is marked, then it rushes down it. Dodge sideways and it crashes and is dazed.
##   Phase 3 (below 1/3): enraged and faster, more minions, and it hurls FIRE ORBS (the dragon breathes them).
## While dazed (after a stomp or a missed charge) it takes double damage. Arrows into the weak spot do triple.
## A boss bar at the top of the screen shows its name, health and phase.

const NAMES := {
	"yeti": "Himraaj, Beast of Sal Forest",
	"mushroom_king": "Kukurmatta, the Mushroom King",
	"demon": "Raktasur, Demon of Dhoopgarh",
	"dragon": "Agnivyal, Dragon of the Dunes",
}
const MINIONS := {"yeti": "skeleton", "mushroom_king": "ghost_skull", "demon": "ghost", "dragon": "ghost_skull"}
const STOMP_R := 6.5

var mon: Monster
var phase := 1
var state := ""                  # "", "roar", "stomp", "charge_aim", "charge", "dazed", "orbs"
var _t := 0.0
var _stomp_cd := 6.0
var _charge_cd := 3.0
var _orb_cd := 4.0
var _charge_dir := Vector3.ZERO
var _charge_hit := false
var _ring: MeshInstance3D
var _lane: MeshInstance3D
var _gem: MeshInstance3D
var _gem_mat: StandardMaterial3D
var _bar: CanvasLayer
var _bar_fill: ColorRect
var _bar_back: ColorRect
var _bar_phase: Label
var weak_hits := 0
static var bosses_beaten := 0


func _init(m: Monster) -> void:
	mon = m


func _ready() -> void:
	_build_gem()
	_ring = _flat_mesh(Color(1.0, 0.15, 0.1, 0.45))
	_ring_mesh()
	_lane = _flat_mesh(Color(1.0, 0.2, 0.1, 0.4))


func display_name() -> String:
	return Loc.t(String(NAMES.get(mon.mkind, mon.mkind.capitalize())))


# --- visuals -------------------------------------------------------------------------------------

func _flat_mesh(c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = c
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mi.material_override = mat
	mi.top_level = true
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mon.add_child(mi)
	return mi


## A round red ring texture is not needed: a disc that grows and fades reads well from above.
func _ring_mesh() -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.04
	cm.radial_segments = 32
	cm.rings = 1
	_ring.mesh = cm


func _build_gem() -> void:
	_gem = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	sm.radial_segments = 12
	sm.rings = 6
	_gem.mesh = sm
	_gem_mat = StandardMaterial3D.new()
	_gem_mat.albedo_color = Color(1.0, 0.85, 0.3)
	_gem_mat.emission_enabled = true
	_gem_mat.emission = Color(1.0, 0.6, 0.1)
	_gem_mat.emission_energy_multiplier = 2.5
	_gem_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gem.material_override = _gem_mat
	_gem.position = Vector3(0, mon.chest_h + 0.15, -0.55 * clampf(mon.chest_h / 1.5, 0.8, 1.4))
	_gem.visible = false
	mon.add_child(_gem)


func gem_world() -> Vector3:
	return _gem.global_position


func gem_open() -> bool:
	return _gem.visible


func _show_bar() -> void:
	if _bar != null:
		return
	_bar = CanvasLayer.new()
	_bar.layer = 12
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	root.position = Vector2(-300, 150)          # below the health bar and the area title
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(root)
	var name_l := Label.new()
	name_l.text = display_name()
	name_l.add_theme_font_size_override("font_size", 24)
	name_l.add_theme_color_override("font_outline_color", Color.BLACK)
	name_l.add_theme_constant_override("outline_size", 6)
	name_l.size = Vector2(600, 30)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(name_l)
	_bar_back = ColorRect.new()
	_bar_back.color = Color(0, 0, 0, 0.6)
	_bar_back.position = Vector2(0, 34)
	_bar_back.size = Vector2(600, 18)
	root.add_child(_bar_back)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.85, 0.15, 0.12)
	_bar_fill.position = Vector2(2, 36)
	_bar_fill.size = Vector2(596, 14)
	root.add_child(_bar_fill)
	for f in [1.0 / 3.0, 2.0 / 3.0]:
		var tick := ColorRect.new()
		tick.color = Color(1, 1, 1, 0.8)
		tick.position = Vector2(2 + 596 * f - 1, 33)
		tick.size = Vector2(2, 20)
		root.add_child(tick)
	_bar_phase = Label.new()
	_bar_phase.add_theme_font_size_override("font_size", 18)
	_bar_phase.add_theme_color_override("font_outline_color", Color.BLACK)
	_bar_phase.add_theme_constant_override("outline_size", 5)
	_bar_phase.position = Vector2(0, 54)
	_bar_phase.size = Vector2(600, 24)
	_bar_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_bar_phase)
	mon.get_parent().add_child(_bar)
	refresh_bar()


func refresh_bar() -> void:
	if _bar == null:
		return
	var k := clampf(mon.hp / mon.max_hp, 0.0, 1.0)
	_bar_fill.size.x = 596.0 * k
	var tip := ""
	match state:
		"dazed":
			tip = Loc.t("DAZED! Hit it now!")
		"stomp":
			tip = Loc.t("Get out of the red ring, or jump!")
		"charge_aim":
			tip = Loc.t("It's going to charge. Dodge sideways!")
		_:
			tip = Loc.t("Shoot the glowing weak spot!") if gem_open() else ""
	_bar_phase.text = "%s %d/3   %s" % [Loc.t("Phase"), phase, tip]


func free_bar() -> void:
	if _bar != null:
		_bar.queue_free()
		_bar = null


# --- damage rules ------------------------------------------------------------------------------

## Extra damage multiplier for a hit (called from Monster.take_hit). `at` is where an arrow struck, if known.
func damage_mult(hk: String, at: Variant) -> float:
	if state == "roar":
		return 0.15                           # roaring: thick hide, almost nothing gets through
	var m := 1.0
	if state == "dazed":
		m *= 2.0
	if gem_open() and hk == "arrow" and at is Vector3 and (at as Vector3).distance_to(gem_world()) < 0.6:
		m *= 3.0
		weak_hits += 1
		FloatText.spawn(mon.get_parent(), gem_world() + Vector3(0, 0.6, 0), Loc.t("WEAK SPOT!"), Color(1.0, 0.85, 0.2), 1.3, 1.4, 1.0)
		_gem_mat.emission_energy_multiplier = 8.0
	return m


func on_hit() -> void:
	if state == "roar":
		return
	var k := mon.hp / mon.max_hp
	if phase == 1 and k < 2.0 / 3.0:
		_enter_phase(2)
	elif phase == 2 and k < 1.0 / 3.0:
		_enter_phase(3)
	refresh_bar()


func on_death() -> void:
	bosses_beaten += 1
	_ring.visible = false
	_lane.visible = false
	_gem.visible = false
	free_bar()
	var ach := mon.get_tree().get_first_node_in_group("achievements")
	if ach != null and ach.has_method("unlock"):
		ach.call("unlock", "slayer")
		if weak_hits >= 3:
			ach.call("unlock", "weakspot")


func _enter_phase(p: int) -> void:
	phase = p
	state = "roar"
	_t = 0.0
	mon._atk_t = -1.0
	mon._cur = ""
	mon._play("Idle", 0.1)
	Sfx.at("scream", mon.global_position + Vector3(0, 2.0, 0), 2.0, 0.5)
	if mon.player != null:
		StoryFX.shake(mon.player, 0.35, 0.8)
		mon.player.message.emit("%s %d!" % [Loc.t("Phase"), p])
	_gem.visible = true
	if p == 3:
		mon.enraged = true
		mon.speed *= 1.25
		mon.attack_cd *= 0.75
		_gem_mat.emission = Color(1.0, 0.25, 0.1)
	_summon(2 if p == 2 else 3)


func _summon(n: int) -> void:
	var mm := mon.get_tree().get_first_node_in_group("monster_missions")
	var kind: String = MINIONS.get(mon.mkind, "ghost")
	for i in n:
		var a := TAU * float(i) / float(n) + mon.rotation.y
		var p := mon.global_position + Vector3(cos(a), 0, sin(a)) * 5.0
		if mm != null and mm.has_method("summon"):
			mm.call("summon", kind, p)


# --- the fight -----------------------------------------------------------------------------------

## Runs before the monster's normal behaviour. Returns true while a boss move owns the body this frame.
func tick(delta: float, dist: float, fwd: Vector3) -> bool:
	var pl := mon.player
	if dist < 30.0:
		_show_bar()
	_gem_mat.emission_energy_multiplier = move_toward(_gem_mat.emission_energy_multiplier, 2.5 + (3.0 if state == "dazed" else 0.0), delta * 10.0)
	_stomp_cd -= delta
	_charge_cd -= delta
	_orb_cd -= delta
	_t += delta
	match state:
		"roar":
			_halt(delta)
			if _t > 1.6:
				_end()
			return true
		"stomp":
			_halt(delta)
			var k := clampf(_t / 1.1, 0.0, 1.0)
			_ring.visible = true
			_ring.global_transform = Transform3D(Basis().scaled(Vector3(STOMP_R * k, 1.0, STOMP_R * k)), mon.global_position + Vector3(0, 0.06, 0))
			(_ring.material_override as StandardMaterial3D).albedo_color.a = 0.25 + 0.35 * k
			if _t >= 1.1:
				_ring.visible = false
				_shockwave()
				_daze(1.6)
			return true
		"charge_aim":
			_halt(delta)
			mon.rotation.y = lerp_angle(mon.rotation.y, atan2(-_charge_dir.x, -_charge_dir.z), 1.0 - exp(-10.0 * delta))
			_lane.visible = true
			var c := mon.global_position + _charge_dir * 9.0 + Vector3(0, 0.06, 0)
			_lane.global_transform = Transform3D(Basis.looking_at(_charge_dir, Vector3.UP).scaled(Vector3(1.8, 1.0, 18.0)), c)
			if _t >= 0.9:
				_lane.visible = false
				state = "charge"
				_t = 0.0
				_charge_hit = false
				mon._cur = ""
				mon._play("Run", 0.05, 1.6)
				Sfx.at("scream", mon.global_position + Vector3(0, 2.0, 0), -2.0, 0.8)
			return true
		"charge":
			var sp := mon.speed * 3.4
			mon.velocity.x = _charge_dir.x * sp
			mon.velocity.z = _charge_dir.z * sp
			if pl != null and not _charge_hit and pl.global_position.distance_to(mon.global_position) < mon.reach * 0.75 + 0.6:
				_charge_hit = true
				pl.take_damage(mon.damage * 1.6, _charge_dir)
				pl.velocity += _charge_dir * 10.0 + Vector3.UP * 5.0
			if _t > 1.3 or mon.get_slide_collision_count() > 0 and _t > 0.3:
				if _charge_hit:
					_end()
				else:
					StoryFX.shake(pl, 0.2, 0.4)
					_daze(2.6)              # missed and crashed: dazed
			return false
		"dazed":
			_halt(delta)
			mon._play("HitReact" if _t < 0.4 else "Idle", 0.1, 0.5)
			if _t > float(mon.get_meta("daze", 2.0)):
				_end()
			return true
		"orbs":
			_halt(delta)
			mon.rotation.y = lerp_angle(mon.rotation.y, atan2(-fwd.x, -fwd.z), 1.0 - exp(-8.0 * delta))
			for i in 3:
				var at := 0.35 + 0.3 * float(i)
				if _t >= at and _t - delta < at:
					_throw_orb(i)
			if _t > 1.4:
				_end()
			return true
	# choose a boss move when nothing else is going on
	if pl == null or pl.dead or mon._atk_t >= 0.0 or mon._hit_t > 0.0 or dist > 24.0:
		return false
	if not mon.flier and _stomp_cd <= 0.0 and dist < STOMP_R - 0.5:
		state = "stomp"
		_t = 0.0
		_stomp_cd = 8.0 if phase == 1 else 6.5
		mon._cur = ""
		mon._play("Weapon" if mon._anim != null and mon._anim.has_animation("Weapon") else "Punch", 0.1, 0.7)
		refresh_bar()
		return true
	if phase >= 2 and not mon.flier and _charge_cd <= 0.0 and dist > 6.0 and dist < 20.0:
		state = "charge_aim"
		_t = 0.0
		_charge_cd = 7.0
		_charge_dir = fwd
		refresh_bar()
		return true
	if (phase >= 3 or mon.flier) and _orb_cd <= (0.0 if phase >= 2 or not mon.flier else -2.5) and dist > 5.0:
		state = "orbs"
		_t = 0.0
		_orb_cd = 5.5
		mon._cur = ""
		mon._play("Punch", 0.1, 0.8)
		return true
	return false


func _halt(delta: float) -> void:
	mon.velocity.x = move_toward(mon.velocity.x, 0.0, 30.0 * delta)
	mon.velocity.z = move_toward(mon.velocity.z, 0.0, 30.0 * delta)


func _end() -> void:
	state = ""
	_t = 0.0
	mon._cur = ""
	refresh_bar()


func _daze(dur: float) -> void:
	state = "dazed"
	_t = 0.0
	mon.set_meta("daze", dur)
	mon._cur = ""
	refresh_bar()


func _shockwave() -> void:
	Sfx.at("hit_thud", mon.global_position, 4.0, 0.5)
	HitFx.burst(mon.get_parent(), mon.global_position + Vector3(0, 0.3, 0), true, Color(0.75, 0.6, 0.4))
	var pl := mon.player
	if pl == null:
		return
	StoryFX.shake(pl, 0.3, 0.5)
	var d := pl.global_position - mon.global_position
	d.y = 0.0
	if d.length() < STOMP_R and pl.is_on_floor():
		pl.take_damage(mon.damage * 1.2, d.normalized())
		pl.velocity += d.normalized() * 6.0 + Vector3.UP * 4.0


func _throw_orb(i: int) -> void:
	var pl := mon.player
	if pl == null:
		return
	var orb := BossOrb.new()
	mon.get_parent().add_child(orb)
	var from := mon.global_position + Vector3(0, mon.chest_h + 0.4, 0) - mon.global_transform.basis.z * 1.0
	var spread := (float(i) - 1.0) * 1.6
	var side := Vector3(cos(mon.rotation.y), 0, -sin(mon.rotation.y))
	orb.launch(from, pl.global_position + Vector3(0, 1.0, 0) + side * spread, mon.damage * 0.8, pl)
	Sfx.at("whoosh_kick", from, -2.0, 0.6)
