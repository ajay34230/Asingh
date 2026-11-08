class_name Monster
extends Enemy
## Ghosts and monsters (Quaternius Ultimate Monsters, CC0), animated with the models' own clips
## (Idle / Walk / Run / Punch / HitReact / Death, or Flying_Idle / Fast_Flying / Headbutt for fliers).
## Shares the Enemy interface (group "enemies", take_hit, died signal, hp bar) so the player's aiming,
## combos, arrows, lock-on, bounties and achievements all work on them. Ghosts are spectral: arrows and
## blades hurt them most, bare fists only a little.

const KINDS := {
	"ghost": {"file": "Ghost", "height": 1.9, "hp": 42.0, "dmg": 7.0, "speed": 3.4, "fly": 1.3, "reach": 1.9, "spectral": true, "tint": Color(0.75, 0.9, 1.0)},
	"ghost_skull": {"file": "Ghost_Skull", "height": 1.7, "hp": 34.0, "dmg": 9.0, "speed": 4.4, "fly": 1.6, "reach": 1.8, "spectral": true, "tint": Color(0.85, 1.0, 0.8)},
	"skeleton": {"file": "Orc_Skull", "height": 2.1, "hp": 75.0, "dmg": 11.0, "speed": 3.0, "fly": 0.0, "reach": 2.1, "spectral": false},
	"yeti": {"file": "Yeti", "height": 2.7, "hp": 230.0, "dmg": 17.0, "speed": 3.3, "fly": 0.0, "reach": 2.6, "spectral": false, "boss": true},
	"mushroom_king": {"file": "MushroomKing", "height": 2.5, "hp": 260.0, "dmg": 15.0, "speed": 2.4, "fly": 0.0, "reach": 2.5, "spectral": false, "boss": true},
	"demon": {"file": "Demon", "height": 2.9, "hp": 320.0, "dmg": 20.0, "speed": 3.6, "fly": 0.0, "reach": 2.8, "spectral": false, "boss": true},
	"dragon": {"file": "Dragon_Evolved", "height": 3.0, "hp": 380.0, "dmg": 18.0, "speed": 5.0, "fly": 3.2, "reach": 3.0, "spectral": false, "boss": true},
}

var mkind := "ghost"
var flier := false
var hover := 0.0
var head_h := 1.62                # arrows: head and chest heights above the feet (before hover)
var chest_h := 1.1
var boss: BossBrain                 # phases, stomp, charge, orbs and the weak spot (boss monsters only)
var last_hit_at: Variant = null     # where the last arrow struck (set by Arrow), for the weak spot
var spectral := false
var reach := 2.0
var _model: Node3D
var _anim: AnimationPlayer
var _cur := ""
var _atk_t := -1.0
var _hit_t := 0.0
var _bob := 0.0
var _mats: Array[StandardMaterial3D] = []
static var _cache := {}


func setup_monster(k: String, at: Vector3, label: String) -> Monster:
	var d: Dictionary = KINDS.get(k, KINDS["ghost"])
	mkind = k
	name = label
	kind = k
	role = k
	add_to_group("enemies")
	add_to_group("monsters")
	_rng.seed = hash(label) + int(at.x * 7.0)
	home = at
	hp = float(d["hp"])
	max_hp = hp
	damage = float(d["dmg"])
	speed = float(d["speed"])
	hover = float(d["fly"])
	flier = hover > 0.0
	spectral = bool(d["spectral"])
	reach = float(d["reach"])
	head_h = float(d["height"]) * 0.86
	chest_h = float(d["height"]) * 0.56
	is_boss = bool(d.get("boss", false))
	aggro = 40.0
	leash = 120.0
	drop_chance = 0.35
	attack_cd = 1.4 if not is_boss else 1.8
	_model = _load_model(String(d["file"]), float(d["height"]), d.get("tint", Color.WHITE))
	add_child(_model)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = clampf(float(d["height"]) * 0.2, 0.35, 0.9)
	cap.height = maxf(float(d["height"]) * 0.8, cap.radius * 2.2)
	cs.shape = cap
	cs.position.y = cap.height * 0.5 + (0.2 if flier else 0.0)
	add_child(cs)
	_hp_bar = Label3D.new()
	_hp_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar.no_depth_test = true
	_hp_bar.fixed_size = true
	_hp_bar.pixel_size = 0.0009
	_hp_bar.font_size = 40
	_hp_bar.outline_size = 10
	_hp_bar.modulate = Color(0.6, 0.9, 1.0) if spectral else Color(1.0, 0.35, 0.3)
	_hp_bar.position.y = float(d["height"]) + 0.4
	add_child(_hp_bar)
	if is_boss:
		boss = BossBrain.new(self)
		add_child(boss)
	_bubble = Label3D.new()
	_bubble.visible = false
	add_child(_bubble)
	_refresh_bar()
	position = at
	_play("Flying_Idle" if flier else "Idle")
	return self


func _load_model(file: String, height: float, tint: Color) -> Node3D:
	var path := "res://assets/monsters/%s.gltf" % file
	var holder := Node3D.new()
	holder.name = "Model"
	var ps: PackedScene = _cache.get(path) as PackedScene
	if ps == null and ResourceLoader.exists(path):
		ps = load(path) as PackedScene
		_cache[path] = ps
	if ps == null:
		# headless tests without imported assets: a simple stand-in shape
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.height = height
		cm.radius = height * 0.22
		mi.mesh = cm
		mi.position.y = height * 0.5
		holder.add_child(mi)
		return holder
	var inst := ps.instantiate() as Node3D
	holder.add_child(inst)
	inst.rotation.y = PI                  # the models face +Z; we face -Z
	var box := AABB()
	var first := true
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mi2 := m as MeshInstance3D
		var bb := mi2.get_aabb()
		var xf := Transform3D.IDENTITY
		var n: Node = mi2
		while n != null and n != inst:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		bb = xf * bb
		box = bb if first else box.merge(bb)
		first = false
		# own material copies so a ghost can glow and fade on its own
		for si in mi2.get_surface_override_material_count():
			var src := mi2.get_active_material(si) as StandardMaterial3D
			if src == null:
				continue
			var mat := src.duplicate() as StandardMaterial3D
			mat.albedo_color = mat.albedo_color * tint
			if spectral:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = 0.78
				mat.emission_enabled = true
				mat.emission = Color(0.35, 0.55, 0.75)
				mat.emission_energy_multiplier = 0.6
			mi2.set_surface_override_material(si, mat)
			_mats.append(mat)
	var sc := height / maxf(box.size.y, 0.01)
	inst.scale = Vector3.ONE * sc
	inst.position.y = -box.position.y * sc
	_anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		for an in ["Idle", "Walk", "Run", "Flying_Idle", "Fast_Flying"]:
			if _anim.has_animation(an):
				_anim.get_animation(an).loop_mode = Animation.LOOP_LINEAR
	return holder


func _play(n: String, blend: float = 0.15, spd: float = 1.0) -> void:
	if _anim == null or _cur == n or not _anim.has_animation(n):
		return
	_cur = n
	_anim.play(n, blend, spd)


func _refresh_bar() -> void:
	if _hp_bar == null:
		return
	var n := clampi(int(ceil(10.0 * hp / max_hp)), 0, 10)
	_hp_bar.text = ("BOSS " if is_boss else "") + "▮".repeat(n) + "▯".repeat(10 - n)


func say(_text: String) -> void:
	pass


func begin_held() -> void:
	pass


func throw_from(_thrower: Node3D, _dir: Vector3) -> void:
	pass


func take_hit_ground(amount: float) -> void:
	take_hit("slam", amount, Vector3.ZERO)


## Damage with the monster's own rules: spectral bodies shrug off fists and feel arrows and blades.
func take_hit(hk: String, amount: float, from_dir: Vector3) -> void:
	if dead:
		return
	var m := 1.0
	if spectral:
		match hk:
			"arrow":
				m = 2.0
			"spirit":
				m = 6.0                         # spirit arrows: triple an ordinary arrow
			"punch", "kick", "round":
				m = 0.55
			_:
				m = 1.3 if (player != null and player.weapon in ["sword", "dagger", "spear", "axe"]) else 0.9
		if player != null:
			m *= player.ghost_mult              # Hunter: Spirit Bane
	elif hk == "arrow" or hk == "spirit":
		m = 1.2
	amount *= m
	if boss != null:
		amount *= boss.damage_mult(hk, last_hit_at)
	last_hit_at = null
	hp -= amount
	FloatText.spawn(get_parent(), global_position + Vector3(0, _hp_bar.position.y - 0.2, 0), str(int(round(amount))), Color(0.6, 0.95, 1.0) if spectral else Color(1.0, 0.8, 0.3), 1.0 if amount < 20.0 else 1.4)
	HitFx.burst(get_parent(), global_position + Vector3(0, chest_h, 0), true, Color(0.6, 0.85, 1.0) if spectral else Color(0.7, 0.2, 0.2))
	_refresh_bar()
	if hp <= 0.0:
		_die(hk, from_dir)
		return
	if boss != null:
		boss.on_hit()
		if boss.state != "":
			return                          # a boss mid-move is not knocked out of it
	var dir := Vector3(from_dir.x, 0.0, from_dir.z)
	if dir.length() > 0.01:
		velocity += dir.normalized() * (2.0 if is_boss else 5.0)
	_hit_t = 0.35
	_atk_t = -1.0
	_cur = ""
	_play("HitReact", 0.05)
	Sfx.at("hit_thud", global_position + Vector3(0, 1.2, 0), -4.0, 0.7 if is_boss else 1.2)
	if is_boss and boss == null and not enraged and hp < max_hp * 0.5:
		enraged = true
		speed *= 1.25
		attack_cd *= 0.75
		Sfx.at("scream", global_position + Vector3(0, 2.0, 0), 0.0, 0.6)


func _die(_hk: String, _dir: Vector3) -> void:
	dead = true
	if boss != null:
		boss.on_death()
	remove_from_group("enemies")
	var ach := get_tree().get_first_node_in_group("achievements")
	if ach != null:
		ach.note_kill(role, false)
	var itm := get_tree().get_first_node_in_group("items")
	if itm != null:
		itm.loot(role, _rng)
	_hp_bar.visible = false
	collision_layer = 0
	_cur = ""
	_play("Death", 0.05)
	Sfx.at("scream", global_position + Vector3(0, 1.5, 0), -4.0, 1.4 if spectral else 0.7)
	HitFx.burst(get_parent(), global_position + Vector3(0, chest_h, 0), true, Color(0.7, 0.9, 1.0) if spectral else Color(0.4, 0.3, 0.3))
	if player != null and global_position.distance_to(player.global_position) < 6.0 and get_tree().get_nodes_in_group("enemies").is_empty():
		StoryFX.hitstop(0.45)
	var tw := create_tween()
	tw.tween_interval(1.2)
	if spectral:
		for mt in _mats:
			tw.parallel().tween_property(mt, "albedo_color:a", 0.0, 1.0)
		tw.parallel().tween_property(_model, "position:y", 1.2, 1.0)
	else:
		tw.tween_property(_model, "position:y", -1.5, 1.6)
	tw.tween_callback(queue_free)
	if _spawn_pickup.is_valid() and (is_boss or _rng.randf() < drop_chance):
		var kinds := ["health", "health", "speed", "power", "shield"]
		_spawn_pickup.call(global_position + Vector3(0, 0.6, 0), kinds[_rng.randi() % kinds.size()])
	died.emit(self)


func _physics_process(delta: float) -> void:
	if dead:
		if not flier and not is_on_floor():
			velocity.y -= GRAVITY * delta
			move_and_slide()
		return
	_cd -= delta
	_hit_t -= delta
	_bob += delta
	if player == null or player.dead:
		_idle_move(delta)
		return
	var to := player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	# "protect" missions: while the player is not close, haunt the village centre instead
	if has_meta("goal") and dist > 14.0 and _atk_t < 0.0:
		var g: Vector3 = get_meta("goal")
		var tg := g - global_position
		tg.y = 0.0
		if tg.length() > 2.5:
			var gf := tg.normalized()
			rotation.y = lerp_angle(rotation.y, atan2(-gf.x, -gf.z), 1.0 - exp(-6.0 * delta))
			velocity.x = move_toward(velocity.x, gf.x * speed * 0.8, 10.0 * delta)
			velocity.z = move_toward(velocity.z, gf.z * speed * 0.8, 10.0 * delta)
			_play("Fast_Flying" if flier else "Walk")
		else:
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
			_play("Flying_Idle" if flier else "Idle")
		if flier:
			velocity.y = clampf((g.y + hover + 0.25 * sin(_bob * 2.2) - global_position.y) * 3.0, -5.0, 5.0)
		elif not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	var fwd := to.normalized() if dist > 0.01 else Vector3.FORWARD
	if boss != null and boss.tick(delta, dist, fwd):
		if flier:
			velocity.y = clampf((player.global_position.y + hover - global_position.y) * 3.0, -5.0, 5.0)
		elif not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	if boss != null and boss.state == "charge":
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	rotation.y = lerp_angle(rotation.y, atan2(-fwd.x, -fwd.z), 1.0 - exp(-8.0 * delta))
	# attack: wind up, strike at the middle of the clip if the player is still within reach
	if _atk_t >= 0.0:
		_atk_t += delta
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		if _atk_t >= 0.45 and _atk_t - delta < 0.45 and dist < reach + 0.8:
			player._hurt_by_spirit = spectral
			player.take_damage(damage * (1.25 if enraged else 1.0), fwd)
			player._hurt_by_spirit = false
		if _atk_t > 0.9:
			_atk_t = -1.0
			_cur = ""
	elif _hit_t > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	elif dist < reach and _cd <= 0.0:
		_cd = attack_cd + _rng.randf_range(-0.2, 0.3)
		_atk_t = 0.0
		_cur = ""
		_play(("Headbutt" if _rng.randf() < 0.5 else "Punch") if flier else ("Weapon" if is_boss and _rng.randf() < 0.4 else "Punch"), 0.08)
		Sfx.at("whoosh_kick", global_position + Vector3(0, 1.4, 0), -6.0, 0.8)
	elif dist < aggro:
		var sp := speed * (1.0 if dist > reach * 0.8 else 0.0)
		velocity.x = move_toward(velocity.x, fwd.x * sp, 14.0 * delta)
		velocity.z = move_toward(velocity.z, fwd.z * sp, 14.0 * delta)
		if sp > 0.1:
			_play("Fast_Flying" if flier else ("Run" if speed > 2.8 else "Walk"))
		else:
			_play("Flying_Idle" if flier else "Idle")
	else:
		_idle_move(delta)
	if flier:
		var ground := player.global_position.y if dist < 20.0 else global_position.y - hover
		var want := ground + hover + 0.25 * sin(_bob * 2.2)
		velocity.y = clampf((want - global_position.y) * 3.0, -5.0, 5.0)
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()


func _idle_move(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	_play("Flying_Idle" if flier else "Idle")
	if flier:
		velocity.y = 0.3 * cos(_bob * 2.0)
	move_and_slide()
