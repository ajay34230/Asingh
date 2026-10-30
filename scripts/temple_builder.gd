class_name TempleBuilder
extends RefCounted
## The village temple: a three-tier stone plinth with steps, a porch of pillars, a sanctum with an
## altar and oil lamps, a stepped tower with a gold finial, painted bands, marigold garlands, flags,
## a hanging bell and lamps along the stairs. The altar and the bell are functional: praying
## restores health (with a cooldown) and the bell rings.

var terrain: TerrainBuilder
var player: Player
var _last_prayer := -1000.0


func _init(t: TerrainBuilder, p: Player) -> void:
	terrain = t
	player = p


func build(parent: Node3D) -> void:
	var c := TerrainBuilder.TEMPLE_C
	var y := terrain.sample_height(c.x, c.y)
	var root := Node3D.new()
	root.name = "Temple"
	root.position = Vector3(c.x, y, c.y)
	parent.add_child(root)
	var stone := PropFactory.sandstone()
	var pale := PropFactory.sandstone_pale()
	var saffron := PropFactory.material(Color(0.92, 0.45, 0.10), 0.85)
	var crimson := PropFactory.material(Color(0.62, 0.12, 0.10), 0.85)
	var cream := PropFactory.material(Color(0.88, 0.80, 0.62), 0.9)
	var gold := PropFactory.glow_bronze()
	var lamp := PropFactory.glow_lamp()
	# Plinth: three low tiers, each a 0.3 m step, so the player simply walks up.
	var tiers := [[22.0, 22.0], [18.0, 18.0], [14.0, 14.0]]
	for i in 3:
		var sz: Array = tiers[i]
		PropFactory.box(root, Vector3(sz[0], 0.3, sz[1]), Vector3(0, 0.15 + 0.3 * i, 0), pale if i % 2 == 0 else stone, Vector3.ZERO, true, false)
	var fy := 0.9                              # floor height of the top tier
	# Sanctum: back and side walls, a front wall with a doorway, flat roof.
	var w := 7.0
	var d := 7.0
	var wh := 4.6
	var th := 0.6
	PropFactory.box(root, Vector3(w, wh, th), Vector3(0, fy + wh / 2.0, -d / 2.0), stone, Vector3.ZERO, true, false)
	PropFactory.box(root, Vector3(th, wh, d), Vector3(-w / 2.0, fy + wh / 2.0, 0), stone, Vector3.ZERO, true, false)
	PropFactory.box(root, Vector3(th, wh, d), Vector3(w / 2.0, fy + wh / 2.0, 0), stone, Vector3.ZERO, true, false)
	var gap := 2.6
	var seg := (w - gap) / 2.0
	for sgn in [-1.0, 1.0]:
		PropFactory.box(root, Vector3(seg, wh, th), Vector3(sgn * (gap / 2.0 + seg / 2.0), fy + wh / 2.0, d / 2.0), stone, Vector3.ZERO, true, false)
	PropFactory.box(root, Vector3(gap + 0.6, wh - 3.2, th), Vector3(0, fy + 3.2 + (wh - 3.2) / 2.0, d / 2.0), crimson, Vector3.ZERO, true, false)
	PropFactory.box(root, Vector3(w + 0.8, 0.4, d + 0.8), Vector3(0, fy + wh + 0.2, 0), saffron, Vector3.ZERO, true, false)
	# Painted bands round the outside.
	for k in 2:
		var by := fy + 1.2 + k * 1.5
		PropFactory.box(root, Vector3(w + 0.12, 0.28, 0.1), Vector3(0, by, -d / 2.0 - 0.34), crimson, Vector3.ZERO, false, false)
		PropFactory.box(root, Vector3(0.1, 0.28, d + 0.12), Vector3(-w / 2.0 - 0.34, by, 0), crimson, Vector3.ZERO, false, false)
		PropFactory.box(root, Vector3(0.1, 0.28, d + 0.12), Vector3(w / 2.0 + 0.34, by, 0), crimson, Vector3.ZERO, false, false)
	# Stepped tower (shikhara) with a gold finial.
	var ty := fy + wh + 0.4
	for i in 6:
		var s := 6.0 - i * 0.95
		PropFactory.box(root, Vector3(s, 0.9, s), Vector3(0, ty + 0.45 + i * 0.9, 0), cream if i % 2 == 0 else saffron, Vector3.ZERO, false, false)
	var top := ty + 0.9 * 6.0
	PropFactory.cylinder(root, 0.12, 0.3, 1.0, Vector3(0, top + 0.5, 0), gold, Vector3.ZERO, false, 10, 0, false)
	PropFactory.sphere(root, 0.34, Vector3(0, top + 1.2, 0), gold)
	# Porch: four pillars carrying a roof slab, and a hanging bell.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var porch_z := d / 2.0 + 3.0
	for px in [-3.0, -1.0, 1.0, 3.0]:
		var col := PropFactory.cylinder(root, 0.3, 0.34, 3.8, Vector3(px, fy + 1.9, porch_z), stone, Vector3.ZERO, true, 12, 0, false)
		col.name = "PorchPillar"
		PropFactory.box(root, Vector3(0.9, 0.3, 0.9), Vector3(px, fy + 3.95, porch_z), saffron, Vector3.ZERO, false, false)
	PropFactory.box(root, Vector3(8.6, 0.4, 4.0), Vector3(0, fy + 4.3, d / 2.0 + 1.8), crimson, Vector3.ZERO, false, false)
	var bell := Node3D.new()
	bell.name = "TempleBell"
	bell.position = Vector3(0, fy + 3.5, porch_z)
	root.add_child(bell)
	PropFactory.cylinder(bell, 0.04, 0.04, 0.5, Vector3(0, 0.45, 0), gold, Vector3.ZERO, false, 8, 0, false)
	PropFactory.sphere(bell, 0.32, Vector3(0, -0.05, 0), gold, Vector3(1.0, 1.15, 1.0))
	# Marigold garland strung between the porch pillars.
	var marigold := [Color(1.0, 0.62, 0.05), Color(1.0, 0.78, 0.12), Color(0.95, 0.40, 0.05)]
	for gi in 3:
		var x0 := -3.0 + gi * 2.0
		for k in 9:
			var t := float(k) / 8.0
			var gx := lerpf(x0, x0 + 2.0, t)
			var gy := fy + 3.7 - sin(t * PI) * 0.55
			PropFactory.sphere(root, 0.15, Vector3(gx, gy, porch_z + 0.2), PropFactory.material(marigold[(k + gi) % 3], 0.8, 0.0, marigold[(k + gi) % 3], 0.25))
	# Flag poles at the front corners of the plinth.
	for sgn in [-1.0, 1.0]:
		PropFactory.cylinder(root, 0.06, 0.08, 7.0, Vector3(sgn * 10.0, 3.5, 9.5), PropFactory.wood(), Vector3.ZERO, false, 8, 0, false)
		PropFactory.box(root, Vector3(1.6, 0.9, 0.05), Vector3(sgn * 10.0 + 0.8, 6.4, 9.5), saffron, Vector3.ZERO, false, false)
	# Oil lamps along both sides of the steps, and inside.
	for k in 5:
		for sgn in [-1.0, 1.0]:
			PropFactory.sphere(root, 0.13, Vector3(sgn * 4.6, fy + 0.15, d / 2.0 + 0.8 + k * 1.1), lamp)
	# Altar inside the sanctum.
	PropFactory.box(root, Vector3(2.2, 1.0, 1.2), Vector3(0, fy + 0.5, -d / 2.0 + 1.3), pale, Vector3.ZERO, true, false)
	PropFactory.box(root, Vector3(1.4, 0.2, 0.8), Vector3(0, fy + 1.1, -d / 2.0 + 1.3), crimson, Vector3.ZERO, false, false)
	PropFactory.sphere(root, 0.38, Vector3(0, fy + 1.65, -d / 2.0 + 1.3), gold, Vector3(1.0, 1.3, 1.0))
	for sgn in [-1.0, 1.0]:
		PropFactory.sphere(root, 0.16, Vector3(sgn * 1.4, fy + 1.15, -d / 2.0 + 1.3), lamp)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, fy + 2.4, -d / 2.0 + 2.0)
	glow.light_color = Color(1.0, 0.68, 0.32)
	glow.light_energy = 1.4
	glow.omni_range = 9.0
	glow.shadow_enabled = false
	root.add_child(glow)
	# Interactions: pray at the altar (restores health), ring the bell.
	var altar := Interactable.new()
	altar.position = root.position + Vector3(0, fy + 1.0, -d / 2.0 + 2.4)
	altar.prompt = "Pray at the altar"
	altar.reach = 3.2
	altar.on_interact = func(by: Node3D, _me: Interactable) -> void:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_prayer < 60.0:
			(by as Player).say("The lamps burn quietly. Peace remains with you.")
			return
		_last_prayer = now
		(by as Player).heal(60.0)
		Sfx.at("temple_bell", altar.position, -8.0)
		(by as Player).say("You pray at the altar. Warmth fills you; your wounds ease.")
	parent.add_child(altar)
	var bell_it := Interactable.new()
	bell_it.position = root.position + Vector3(0, fy + 2.4, porch_z)
	bell_it.prompt = "Ring the temple bell"
	bell_it.reach = 3.2
	bell_it.on_interact = func(by: Node3D, _me: Interactable) -> void:
		Sfx.at("temple_bell", bell_it.position, -2.0)
		var tw := bell.create_tween()
		tw.tween_property(bell, "rotation:z", 0.25, 0.15)
		tw.tween_property(bell, "rotation:z", -0.18, 0.3)
		tw.tween_property(bell, "rotation:z", 0.0, 0.4)
	parent.add_child(bell_it)
