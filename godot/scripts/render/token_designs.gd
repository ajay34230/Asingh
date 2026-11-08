## Collectible token designs: 3D gear added to a player's tokens so they can show off.
## Head gear rides on the body (it squashes and spins with it), shields and swords sit
## in the hands (they swing in fights). Epic and Legendary designs glow; Legendary ones
## leave a trail of sparks as they walk.
class_name TokenDesigns
extends RefCounted

const RARITY := {
	"common": ["Common", Color("#c8c0b0")],
	"rare": ["Rare", Color("#4fa8ff")],
	"epic": ["Epic", Color("#c070ff")],
	"legendary": ["Legendary", Color("#ffb020")],
}

## id -> [name, rarity, price]
const DESIGNS := {
	"design_classic": ["Classic", "common", 0],
	"design_raja": ["Raja's Turban", "rare", 400],
	"design_tiger": ["Bengal Tiger", "rare", 500],
	"design_peacock": ["Peacock Crest", "rare", 600],
	"design_lotus": ["Lotus Queen", "epic", 800],
	"design_maharaja": ["Maharaja's Crown", "epic", 900],
	"design_warrior": ["Rajput Warrior", "epic", 1000],
	"design_shadow": ["Shadow Assassin", "legendary", 2000],
	"design_surya": ["Surya, the Sun King", "legendary", 2500],
}

## Customising: the metal of crowns and trims, and the colour of the aura.
const METALS := {
	"gold": ["Gold", Color("#e8b54f"), 0.25],
	"silver": ["Silver", Color("#d4dae0"), 0.22],
	"rose": ["Rose gold", Color("#e8a088"), 0.25],
	"onyx": ["Black onyx", Color("#2c2834"), 0.15],
}
const AURAS := {
	"rarity": ["Rarity colour", Color.TRANSPARENT],
	"ruby": ["Ruby", Color("#ff3050")],
	"emerald": ["Emerald", Color("#30e080")],
	"sapphire": ["Sapphire", Color("#3d8bff")],
	"pearl": ["Pearl", Color("#fff2dc")],
}

const HEAD_Y := 0.86   ## top of the token's head in its own units


static func rarity_of(id: String) -> String:
	return String(DESIGNS.get(id, DESIGNS["design_classic"])[1])


## "design_raja|silver|ruby" -> ["design_raja", "silver", "ruby"]; anything unknown
## falls back to the defaults, so a spec from another phone is always safe.
static func parse(spec: String) -> Array:
	var p := spec.split("|")
	var id := p[0] if DESIGNS.has(p[0]) else "design_classic"
	var metal := p[1] if p.size() > 1 and METALS.has(p[1]) else "gold"
	var aura := p[2] if p.size() > 2 and AURAS.has(p[2]) else "rarity"
	return [id, metal, aura]


static func aura_color(id: String, aura: String) -> Color:
	if aura != "rarity" and AURAS.has(aura):
		return AURAS[aura][1]
	return RARITY[rarity_of(id)][1]


## Dresses one token from a spec ("design_raja" or "design_raja|silver|ruby").
## Safe to call again: old gear is removed first.
static func apply(token: TransformerToken, spec: String, team: Color) -> void:
	for n in token.find_children("DesignGear*", "", true, false):
		n.get_parent().remove_child(n)
		n.queue_free()
	var parsed := parse(spec)
	var id: String = parsed[0]
	if id == "design_classic":
		return
	var head := Node3D.new()
	head.name = "DesignGearHead"
	head.position = Vector3(0, HEAD_Y, 0)
	token.body_node.add_child(head)
	var m: Array = METALS[parsed[1]]
	var gold := RoyalBoard.metal(m[1], m[2])
	match id:
		"design_raja":
			_turban(head, Color("#ff9a1f"), gold)
		"design_tiger":
			_tiger(head, token)
		"design_peacock":
			_peacock(head, gold)
		"design_lotus":
			_lotus(head, gold)
		"design_maharaja":
			_crown(head, gold, team)
		"design_warrior":
			_warrior(head, token, gold)
		"design_shadow":
			_shadow(head, token)
		"design_surya":
			_surya(head, gold)
	var r := rarity_of(id)
	if r == "epic" or r == "legendary":
		var ring := _aura(token, aura_color(id, parsed[2]))
		ring.set_meta("trail", r == "legendary")


# --- gear ------------------------------------------------------------------------------

static func _mi(parent: Node3D, mesh: Mesh, mat: Material, at := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	return s


static func _solid(c: Color, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _glow(c: Color, e := 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m


static func _turban(head: Node3D, cloth: Color, gold: Material) -> void:
	var silk := _solid(cloth, 0.5)
	for i in range(3):   # wound layers
		var t := TorusMesh.new()
		t.inner_radius = 0.08 - i * 0.012
		t.outer_radius = 0.2 - i * 0.03
		t.rings = 32
		t.ring_segments = 12
		var m := _mi(head, t, silk, Vector3(0, 0.04 + i * 0.05, 0))
		m.rotation.z = (i - 1) * 0.12
	_mi(head, _sphere(0.11), silk, Vector3(0, 0.12, 0))
	_mi(head, _sphere(0.04), RoyalBoard.gem_material(Color("#1fa060")), Vector3(0, 0.08, 0.19))
	var plume := CylinderMesh.new()
	plume.top_radius = 0.0
	plume.bottom_radius = 0.025
	plume.height = 0.22
	var p := _mi(head, plume, gold, Vector3(0, 0.22, 0.14))
	p.rotation.x = -0.35


static func _crown(head: Node3D, gold: Material, team: Color) -> void:
	var band := CylinderMesh.new()
	band.top_radius = 0.17
	band.bottom_radius = 0.15
	band.height = 0.08
	band.radial_segments = 32
	_mi(head, band, gold, Vector3(0, 0.04, 0))
	for i in range(8):   # points with gems on the tips
		var a := TAU * i / 8.0
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = 0.035
		spike.height = 0.13
		spike.radial_segments = 8
		_mi(head, spike, gold, Vector3(cos(a) * 0.15, 0.14, sin(a) * 0.15))
		_mi(head, _sphere(0.022), RoyalBoard.gem_material(Color("#d0142e") if i % 2 == 0 else team), Vector3(cos(a) * 0.15, 0.22, sin(a) * 0.15))
	_mi(head, _sphere(0.05), RoyalBoard.gem_material(team), Vector3(0, 0.05, 0.17))


static func _warrior(head: Node3D, token: TransformerToken, gold: Material) -> void:
	var steel := RoyalBoard.metal(Color("#b8c0c8"), 0.3)
	var helm := _mi(head, _sphere(0.17), steel, Vector3(0, 0.02, 0))
	helm.scale = Vector3(1, 0.8, 1)
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.03
	spike.height = 0.18
	_mi(head, spike, gold, Vector3(0, 0.2, 0))
	var nose := BoxMesh.new()
	nose.size = Vector3(0.025, 0.12, 0.02)
	_mi(head, nose, steel, Vector3(0, -0.03, 0.17))
	## Round shield in the left hand, curved sword in the right.
	var lw: Node3D = token.arm_pivots["L"]["wrist"]
	var shield_root := Node3D.new()
	shield_root.name = "DesignGearShield"
	lw.add_child(shield_root)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.16
	disc.bottom_radius = 0.16
	disc.height = 0.03
	disc.radial_segments = 32
	var s := _mi(shield_root, disc, RoyalBoard.metal(Color("#7a4a20"), 0.5), Vector3(-0.06, 0, 0.02))
	s.rotation.z = PI * 0.5
	var boss := _mi(shield_root, _sphere(0.045), gold, Vector3(-0.08, 0, 0.02))
	boss.scale = Vector3(0.6, 1, 1)
	var rw: Node3D = token.arm_pivots["R"]["wrist"]
	var sword_root := Node3D.new()
	sword_root.name = "DesignGearSword"
	rw.add_child(sword_root)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.02, 0.36, 0.05)
	var b := _mi(sword_root, blade, steel, Vector3(0, -0.2, 0.03))
	b.rotation.x = 0.2
	var hilt := BoxMesh.new()
	hilt.size = Vector3(0.1, 0.02, 0.03)
	_mi(sword_root, hilt, gold, Vector3(0, -0.02, 0.0))


static func _peacock(head: Node3D, gold: Material) -> void:
	var fan := Node3D.new()
	fan.position = Vector3(0, 0.05, -0.08)
	head.add_child(fan)
	for i in range(9):
		var a := lerpf(-1.1, 1.1, i / 8.0)
		var feather := Node3D.new()
		feather.rotation = Vector3(-0.25, 0, a)
		fan.add_child(feather)
		var stem := CylinderMesh.new()
		stem.top_radius = 0.006
		stem.bottom_radius = 0.008
		stem.height = 0.32
		_mi(feather, stem, _solid(Color("#3a6a3a")), Vector3(0, 0.16, 0))
		var eye := _mi(feather, _sphere(0.05), _solid(Color("#1f8fa8"), 0.3), Vector3(0, 0.33, 0))
		eye.scale = Vector3(1, 1.3, 0.3)
		var dot := _mi(feather, _sphere(0.022), RoyalBoard.gem_material(Color("#1a3aa8")), Vector3(0, 0.33, 0.012))
		dot.scale = Vector3(1, 1.2, 0.4)
	_mi(head, _sphere(0.035), gold, Vector3(0, 0.04, 0.15))


static func _tiger(head: Node3D, token: TransformerToken) -> void:
	var fur := _solid(Color("#e8892a"), 0.8)
	var dark := _solid(Color("#2a1a10"), 0.8)
	for x in [-0.13, 0.13]:
		var ear := _mi(head, _sphere(0.085), fur, Vector3(x, 0.07, 0))
		ear.scale = Vector3(1, 1.15, 0.5)
		var inner := _mi(head, _sphere(0.045), _solid(Color("#f2c8a8")), Vector3(x, 0.07, 0.03))
		inner.scale = Vector3(1, 1.1, 0.4)
	## Striped headband across the brow.
	for i in range(5):
		var a := lerpf(-0.9, 0.9, i / 4.0)
		var stripe := BoxMesh.new()
		stripe.size = Vector3(0.03, 0.08, 0.02)
		var st := _mi(head, stripe, dark if i % 2 == 0 else fur, Vector3(sin(a) * 0.15, -0.02, cos(a) * 0.15))
		st.rotation.y = a
	## A striped tail curling behind the body.
	var tail := Node3D.new()
	tail.name = "DesignGearTail"
	tail.position = Vector3(0, 0.25, -0.22)
	token.body_node.add_child(tail)
	for i in range(8):
		var f := float(i) / 7.0
		_mi(tail, _sphere(0.04 - f * 0.012), dark if i % 2 == 1 else fur, Vector3(0, f * 0.25 + sin(f * 3.0) * 0.06, -f * 0.18 - sin(f * 2.0) * 0.05))


static func _lotus(head: Node3D, gold: Material) -> void:
	var pink := _solid(Color("#ff8fb8"), 0.4)
	var light := _solid(Color("#ffd8e6"), 0.4)
	for ring in range(2):
		for i in range(8):
			var a := TAU * i / 8.0 + ring * 0.39
			var holder := Node3D.new()
			holder.rotation.y = -a
			head.add_child(holder)
			var petal := _mi(holder, _sphere(0.5), pink if ring == 0 else light, Vector3(0.1 - ring * 0.04, 0.05 + ring * 0.03, 0))
			petal.scale = Vector3(0.11, 0.18, 0.06)
			petal.rotation.z = -0.6 + ring * 0.3
	_mi(head, _sphere(0.04), gold, Vector3(0, 0.08, 0))


static func _shadow(head: Node3D, token: TransformerToken) -> void:
	var cloth := _solid(Color("#16121c"), 0.9)
	var hood := _mi(head, _sphere(0.2), cloth, Vector3(0, -0.02, -0.02))
	hood.scale = Vector3(1, 1.05, 1.1)
	var peak := CylinderMesh.new()
	peak.top_radius = 0.0
	peak.bottom_radius = 0.1
	peak.height = 0.16
	var p := _mi(head, peak, cloth, Vector3(0, 0.17, -0.06))
	p.rotation.x = -0.4
	for x in [-0.05, 0.05]:
		_mi(head, _sphere(0.02), _glow(Color("#ff2a40"), 5.0), Vector3(x, -0.02, 0.19))
	## A cloak down the back.
	var cape := BoxMesh.new()
	cape.size = Vector3(0.34, 0.5, 0.02)
	var c := _mi(token.body_node, cape, cloth, Vector3(0, 0.45, -0.2))
	c.name = "DesignGearCape"
	c.rotation.x = 0.15


static func _surya(head: Node3D, gold: Material) -> void:
	var glow := _glow(Color("#ffc040"), 3.5)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.2
	ring.outer_radius = 0.24
	ring.rings = 48
	ring.ring_segments = 12
	var halo := _mi(head, ring, glow, Vector3(0, 0.05, -0.12))
	halo.rotation.x = PI * 0.5
	for i in range(12):   # sun rays around the halo
		var a := TAU * i / 12.0
		var ray := CylinderMesh.new()
		ray.top_radius = 0.0
		ray.bottom_radius = 0.025
		ray.height = 0.12
		var r := _mi(head, ray, glow, Vector3(cos(a) * 0.3, 0.05 + sin(a) * 0.3, -0.12))
		r.rotation.z = a - PI * 0.5
	_crown(head, gold, Color("#ffd040"))


## A soft glowing ring on the ground under the token, in the rarity colour.
static func _aura(token: TransformerToken, color: Color) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = 0.3
	t.outer_radius = 0.38
	t.rings = 48
	t.ring_segments = 8
	var m := MeshInstance3D.new()
	m.name = "DesignGearAura"
	m.mesh = t
	var mat := _glow(color, 2.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.7
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(0, 0.02, 0)
	m.scale = Vector3(1, 0.3, 1)
	token.add_child(m)
	return m
