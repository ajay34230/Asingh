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
	"festival": ["Festival", Color("#ff5ab0")],
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
	## Royal history
	"design_maratha": ["Maratha Sardar", "rare", 650],
	"design_hampi": ["Hampi Stone", "rare", 700],
	"design_mughal": ["Mughal Emperor", "epic", 950],
	"design_rani": ["Rani of Jhansi", "epic", 1050],
	"design_chola": ["Chola Bronze", "epic", 1200],
	## Nature
	"design_snowleopard": ["Snow Leopard", "rare", 550],
	"design_banyan": ["Banyan Spirit", "rare", 600],
	"design_lion": ["Asiatic Lion", "epic", 900],
	"design_monsoon": ["Monsoon Cloud", "epic", 1000],
	## Fun
	"design_chai": ["Chai Wala", "rare", 450],
	"design_bollywood": ["Bollywood Hero", "rare", 650],
	"design_cricket": ["Cricket Star", "epic", 1100],
	## Legends
	"design_naga": ["Naga Raja", "epic", 1200],
	"design_airavata": ["Airavata", "epic", 1100],
	"design_hanuman": ["Hanuman's Mace", "legendary", 2200],
	"design_garuda": ["Garuda", "legendary", 2400],
	"design_nataraja": ["Nataraja's Fire", "legendary", 2600],
	"design_robo": ["Robo Raja", "legendary", 2200],
	"design_ghost": ["Ghost of the Palace", "legendary", 2000],
	## Festival designs: on sale only while their festival is on
	"design_diya": ["Diwali Diya", "festival", 900],
	"design_holi": ["Holi Rang", "festival", 900],
	"design_kite": ["Sankranti Kite", "festival", 900],
	"design_tiranga": ["Tiranga Pride", "festival", 900],
	"design_star": ["Christmas Star", "festival", 900],
}

## Festival designs -> the festival (Festivals.FESTIVALS id) when they can be unlocked.
const FESTIVAL_OF := {
	"design_diya": "diwali", "design_holi": "holi", "design_kite": "pongal",
	"design_tiranga": "independence", "design_star": "christmas",
}

## Collections: own every design in a set to earn its title and coins.
## id -> [name, achievement id, designs]
const SETS := {
	"legends": ["Legends of India", "set_legends", ["design_naga", "design_airavata", "design_hanuman", "design_garuda", "design_nataraja"]],
	"court": ["The Royal Court", "set_court", ["design_raja", "design_maharaja", "design_mughal", "design_rani", "design_maratha"]],
	"wild": ["Wild India", "set_wild", ["design_tiger", "design_snowleopard", "design_lion", "design_peacock"]],
	"heritage": ["Living Heritage", "set_heritage", ["design_lotus", "design_chola", "design_hampi", "design_banyan", "design_monsoon"]],
	"bazaar": ["Palace Bazaar", "set_bazaar", ["design_chai", "design_bollywood", "design_cricket", "design_robo", "design_ghost"]],
	"festivals": ["Festival Spirit", "set_festivals", ["design_diya", "design_holi", "design_kite", "design_tiranga", "design_star"]],
}

## Victory poses: weapons are raised, legends whirl into the air, royals bow; others
## do the usual dance.
const POSES := {
	"design_warrior": "raise", "design_rani": "raise", "design_hanuman": "raise", "design_cricket": "raise",
	"design_maratha": "raise", "design_tiranga": "raise",
	"design_garuda": "whirl", "design_nataraja": "whirl", "design_surya": "whirl", "design_naga": "whirl",
	"design_ghost": "whirl", "design_bollywood": "whirl", "design_holi": "whirl",
	"design_maharaja": "bow", "design_mughal": "bow", "design_raja": "bow", "design_chai": "bow", "design_diya": "bow",
}

## Mastery: games played wearing a design; each level adds a star circling the head.
const MASTERY := [10, 25, 50]
const MASTERY_NAMES := ["", "Bronze mastery", "Silver mastery", "Gold mastery"]

## Customising: the metal of crowns and trims, and the colour of the aura.
const METALS := {
	"gold": ["Gold", Color("#f2c662"), 0.26],
	"silver": ["Silver", Color("#e4e8ee"), 0.24],
	"rose": ["Rose gold", Color("#f0aa90"), 0.26],
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
	var mastery := clampi(int(p[3]), 0, 3) if p.size() > 3 and p[3].is_valid_int() else 0
	return [id, metal, aura, mastery]


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
	for mesh in _body_meshes(token):   # undo a whole-body material (bronze, chrome...)
		if mesh.has_meta("design_orig"):
			mesh.material_override = mesh.get_meta("design_orig")
			mesh.remove_meta("design_orig")
	var parsed := parse(spec)
	var id: String = parsed[0]
	token.set_meta("design", id)   # the fight picks a legendary's signature finisher
	for crest_path in ["HeadFinial", "RoboHead/HeadCrest", "KnightHead/CatEarL", "KnightHead/CatEarR"]:   # head gear replaces the crest
		var crest := token.body_node.get_node_or_null(crest_path) if token.body_node else null
		if crest:
			crest.visible = id == "design_classic"
	if id == "design_classic":
		return
	var head := Node3D.new()
	head.name = "DesignGearHead"
	head.position = Vector3(0, HEAD_Y, 0)
	token.body_node.add_child(head)
	var m: Array = METALS[parsed[1]]
	var gold := RoyalBoard.metal(m[1], m[2])
	gold.metallic = 0.85 if parsed[1] != "onyx" else 1.0   # a touch of base colour so gold never mirrors black
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
		"design_maratha":
			_maratha(head, token)
		"design_hampi":
			_hampi(head, token)
		"design_mughal":
			_mughal(head, gold)
		"design_rani":
			_rani(head, token, gold)
		"design_chola":
			_chola(head, token)
		"design_snowleopard":
			_tiger(head, token, Color("#ecebe6"), Color("#3a3a40"))
		"design_banyan":
			_banyan(head)
		"design_lion":
			_lion(head, token)
		"design_monsoon":
			_monsoon(head)
		"design_chai":
			_chai(head, token)
		"design_bollywood":
			_bollywood(head, token)
		"design_cricket":
			_cricket(head, token)
		"design_naga":
			_naga(head, gold)
		"design_airavata":
			_airavata(head, gold)
		"design_hanuman":
			_hanuman(head, token, gold)
		"design_garuda":
			_garuda(head, token, gold)
		"design_nataraja":
			_nataraja(head, token, gold)
		"design_robo":
			_robo(head, token)
		"design_ghost":
			_ghost(head, token)
		"design_diya":
			_diya(head, token)
		"design_holi":
			_holi(head)
		"design_kite":
			_kite(head, token)
		"design_tiranga":
			_tiranga(head, gold)
		"design_star":
			_star(head)
	var r := rarity_of(id)
	if r == "epic" or r == "legendary" or r == "festival":
		var ring := _aura(token, aura_color(id, parsed[2]))
		## Legendary and festival designs leave sparks; Holi's are every colour.
		ring.set_meta("trail", "holi" if id == "design_holi" else (r == "legendary" or r == "festival"))
	if int(parsed[3]) > 0:
		_mastery_stars(head, int(parsed[3]))


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


static func _tiger(head: Node3D, token: TransformerToken, fur_color := Color("#e8892a"), dark_color := Color("#2a1a10")) -> void:
	var fur := _solid(fur_color, 0.8)
	var dark := _solid(dark_color, 0.8)
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


# --- helpers for the bigger collection -------------------------------------------------

static func _cyl(top: float, bottom: float, h: float, segs := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	return c


static func _boxm(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 40
	t.ring_segments = 10
	return t


## A gear node held in a hand ("L" or "R"), turned so it points along the forearm.
static func _in_hand(token: TransformerToken, side: String, gear_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = gear_name
	(token.arm_pivots[side]["wrist"] as Node3D).add_child(root)
	return root


## A gear node on the body (back, shoulders), squashing and spinning with it.
static func _on_body(token: TransformerToken, gear_name: String, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = gear_name
	root.position = at
	token.body_node.add_child(root)
	return root


## The token's own meshes (body and limbs), not any design gear.
static func _body_meshes(token: TransformerToken) -> Array:
	var out: Array = []
	for root in [token.body_node, token.limb_root]:
		if root == null:
			continue
		for m in root.find_children("*", "MeshInstance3D", true, false):
			if not String(token.get_path_to(m)).contains("DesignGear") and not m.has_meta("no_skin"):
				out.append(m)
	return out


## Whole-body designs (bronze, granite, chrome, ghost) swap the token's material.
static func _skin(token: TransformerToken, mat: Material) -> void:
	for m in _body_meshes(token):
		var mesh := m as MeshInstance3D
		if not mesh.has_meta("design_orig"):
			mesh.set_meta("design_orig", mesh.material_override)
		mesh.material_override = mat


## Small looping motions: wings flap, fire flickers, flags wave, lights blink.
class GearAnimator extends Node3D:
	var mode := ""
	var parts: Array = []
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		for i in range(parts.size()):
			var n: Node3D = parts[i]
			if not is_instance_valid(n):
				continue
			match mode:
				"flap":   # wings: a slow beat, mirrored left and right
					n.rotation.z = (0.25 + sin(t * 3.2) * 0.18) * (1.0 if i == 0 else -1.0)
				"flicker":
					var k := 1.0 + sin(t * 13.0 + i * 1.7) * 0.18 + sin(t * 7.0 + i) * 0.1
					n.scale = Vector3(1.0, k, 1.0)
				"wave":
					n.rotation.y = sin(t * 4.0 + i * 0.8) * 0.35
				"blink":
					n.visible = fmod(t + i * 0.3, 1.2) < 0.6
				"orbit":   # mastery stars circling the head
					var a := t * 1.6 + TAU * i / parts.size()
					n.position = Vector3(cos(a) * 0.26, 0.32 + sin(t * 2.0 + i) * 0.03, sin(a) * 0.26)
					n.rotation.y = -a
				"bolt":   # a lightning flash every few seconds
					n.visible = fmod(t, 3.1) < 0.12 or (fmod(t, 3.1) > 0.2 and fmod(t, 3.1) < 0.26)


static func _animate(parent: Node3D, mode: String, parts: Array) -> void:
	var a := GearAnimator.new()
	a.name = "DesignGearAnimator"
	a.mode = mode
	a.parts = parts
	parent.add_child(a)


# --- royal history ---------------------------------------------------------------------

static func _maratha(head: Node3D, token: TransformerToken) -> void:
	var saffron := _solid(Color("#ff8a1a"), 0.55)
	var white := _solid(Color("#fff4e0"), 0.6)
	for i in range(3):   # the pagadi, wound and leaning back
		var m := _mi(head, _torus(0.1, 0.165 - i * 0.012), saffron if i != 1 else white, Vector3(0, 0.03 + i * 0.045, -0.01 * i))
		m.rotation.x = -0.12
	_mi(head, _sphere(0.1), saffron, Vector3(0, 0.12, -0.02))
	var tura := _mi(head, _sphere(0.06), _solid(Color("#ffd04a"), 0.5), Vector3(0.15, 0.12, 0))   # side crest
	tura.scale = Vector3(0.4, 1.4, 1)
	## The saffron flag on the back.
	var pole := _on_body(token, "DesignGearFlag", Vector3(0.12, 0.55, -0.2))
	_mi(pole, _cyl(0.008, 0.008, 0.7, 8), RoyalBoard.metal(Color("#c8a050"), 0.3), Vector3(0, 0.35, 0))
	var cloth := Node3D.new()
	cloth.position = Vector3(0, 0.62, 0)
	pole.add_child(cloth)
	var flag := _mi(cloth, _boxm(Vector3(0.005, 0.12, 0.2)), saffron, Vector3(0, 0, -0.1))
	flag.rotation.x = 0.1
	_animate(pole, "wave", [cloth])


static func _hampi(head: Node3D, token: TransformerToken) -> void:
	var stone := StandardMaterial3D.new()
	var noise := NoiseTexture2D.new()
	noise.noise = FastNoiseLite.new()
	noise.noise.frequency = 0.08
	noise.color_ramp = Gradient.new()
	noise.color_ramp.set_color(0, Color("#5a5650"))
	noise.color_ramp.set_color(1, Color("#a8a096"))
	stone.albedo_texture = noise
	stone.roughness = 0.95
	stone.uv1_triplanar = true
	stone.uv1_scale = Vector3(3, 3, 3)
	_skin(token, stone)
	var moss := _solid(Color("#4a7a2a"), 1.0)
	for i in range(6):
		var a := TAU * i / 6.0 + 0.3
		var m := _mi(head, _sphere(0.045 + (i % 3) * 0.01), moss, Vector3(cos(a) * 0.12, 0.0 + (i % 2) * 0.04, sin(a) * 0.12))
		m.scale = Vector3(1.3, 0.6, 1.3)


static func _mughal(head: Node3D, gold: Material) -> void:
	var silk := _solid(Color("#fbf6ea"), 0.45)
	for i in range(3):
		var m := _mi(head, _torus(0.1, 0.17 - i * 0.01), silk, Vector3(0, 0.03 + i * 0.05, 0))
		m.rotation.z = (i - 1) * 0.1
	_mi(head, _sphere(0.115), silk, Vector3(0, 0.12, 0))
	var pearl := _solid(Color("#fffaf0"), 0.15)
	for i in range(16):   # a string of pearls around the turban
		var a := TAU * i / 16.0
		_mi(head, _sphere(0.016), pearl, Vector3(cos(a) * 0.172, 0.075, sin(a) * 0.172))
	## The kalgi: a jewelled brooch with a tall white plume.
	_mi(head, _sphere(0.045), RoyalBoard.gem_material(Color("#c0102a")), Vector3(0, 0.1, 0.17))
	_mi(head, _torus(0.04, 0.055), gold, Vector3(0, 0.1, 0.165)).rotation.x = PI * 0.5
	var plume := _mi(head, _sphere(0.5), _solid(Color("#ffffff"), 0.7), Vector3(0, 0.27, 0.12))
	plume.scale = Vector3(0.05, 0.28, 0.04)
	plume.rotation.x = -0.3


## Shield in the left hand, sword in the right (warrior and Rani).
static func _shield_and_sword(token: TransformerToken, gold: Material, shield_color: Color) -> void:
	var steel := RoyalBoard.metal(Color("#b8c0c8"), 0.3)
	var shield_root := _in_hand(token, "L", "DesignGearShield")
	var s := _mi(shield_root, _cyl(0.16, 0.16, 0.03, 32), RoyalBoard.metal(shield_color, 0.5), Vector3(-0.06, 0, 0.02))
	s.rotation.z = PI * 0.5
	var boss := _mi(shield_root, _sphere(0.045), gold, Vector3(-0.08, 0, 0.02))
	boss.scale = Vector3(0.6, 1, 1)
	var sword_root := _in_hand(token, "R", "DesignGearSword")
	var b := _mi(sword_root, _boxm(Vector3(0.02, 0.36, 0.05)), steel, Vector3(0, -0.2, 0.03))
	b.rotation.x = 0.2
	_mi(sword_root, _boxm(Vector3(0.1, 0.02, 0.03)), gold, Vector3(0, -0.02, 0.0))


static func _rani(head: Node3D, token: TransformerToken, gold: Material) -> void:
	var cloth := _solid(Color("#c4102e"), 0.6)
	var scarf := _mi(head, _sphere(0.175), cloth, Vector3(0, 0.01, -0.01))
	scarf.scale = Vector3(1, 0.85, 1.05)
	_mi(head, _torus(0.16, 0.185), gold, Vector3(0, -0.03, 0))
	_mi(head, _sphere(0.035), RoyalBoard.gem_material(Color("#ffd040")), Vector3(0, 0.02, 0.18))
	var tail := _mi(token.body_node, _boxm(Vector3(0.12, 0.38, 0.015)), cloth, Vector3(0.05, 0.6, -0.2))
	tail.name = "DesignGearScarfTail"
	tail.rotation.x = 0.2
	_shield_and_sword(token, gold, Color("#5a2a14"))


static func _chola(head: Node3D, token: TransformerToken) -> void:
	var bronze := RoyalBoard.metal(Color("#d08a48"), 0.42)
	bronze.metallic = 0.8
	_skin(token, bronze)
	_crown(head, RoyalBoard.metal(Color("#c88a48"), 0.3), Color("#3fbf9f"))


# --- nature ------------------------------------------------------------------------------

static func _banyan(head: Node3D) -> void:
	var leaf := _solid(Color("#3f8a2a"), 0.7)
	var leaf2 := _solid(Color("#6aaa3a"), 0.7)
	var bark := _solid(Color("#5a3a20"), 0.95)
	for i in range(14):
		var a := TAU * i / 14.0
		var holder := Node3D.new()
		holder.rotation.y = -a
		head.add_child(holder)
		var l := _mi(holder, _sphere(0.5), leaf if i % 2 == 0 else leaf2, Vector3(0.15, 0.06 + (i % 2) * 0.03, 0))
		l.scale = Vector3(0.12, 0.03, 0.07)
		l.rotation.z = 0.5
	for i in range(5):   # aerial roots hanging from the crown
		var a := TAU * i / 5.0 + 0.4
		_mi(head, _cyl(0.006, 0.01, 0.2, 6), bark, Vector3(cos(a) * 0.17, -0.06, sin(a) * 0.17))


static func _lion(head: Node3D, token: TransformerToken) -> void:
	var mane := _solid(Color("#a8641e"), 0.9)
	var mane2 := _solid(Color("#d89a3a"), 0.9)
	for ring in range(2):
		for i in range(12):
			var a := TAU * (i + ring * 0.5) / 12.0
			var r := 0.17 + ring * 0.05
			var m := _mi(head, _sphere(0.07 - ring * 0.01), mane if (i + ring) % 2 == 0 else mane2, Vector3(cos(a) * r, -0.05 + sin(a) * 0.02, sin(a) * r - 0.02))
			m.scale = Vector3(1, 1.3, 1)
	for x in [-0.1, 0.1]:
		var ear := _mi(head, _sphere(0.05), mane2, Vector3(x, 0.1, 0))
		ear.scale = Vector3(1, 1, 0.5)
	var tail := _on_body(token, "DesignGearTail", Vector3(0, 0.25, -0.22))
	_mi(tail, _cyl(0.012, 0.015, 0.3, 8), mane2, Vector3(0, 0.05, -0.12)).rotation.x = 1.0
	_mi(tail, _sphere(0.045), mane, Vector3(0, 0.15, -0.25))


static func _monsoon(head: Node3D) -> void:
	var cloud := _solid(Color("#8a90a0"), 1.0)
	var cloud_root := Node3D.new()
	cloud_root.position = Vector3(0, 0.38, 0)
	head.add_child(cloud_root)
	for p in [Vector3(0, 0, 0), Vector3(0.1, -0.02, 0.02), Vector3(-0.1, -0.02, -0.01), Vector3(0.04, 0.05, -0.03), Vector3(-0.05, 0.04, 0.04), Vector3(0, -0.03, 0.08)]:
		_mi(cloud_root, _sphere(0.08), cloud, p)
	var rain := CPUParticles3D.new()
	rain.amount = 24
	rain.lifetime = 0.5
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(0.12, 0.01, 0.08)
	rain.direction = Vector3.DOWN
	rain.spread = 2.0
	rain.gravity = Vector3(0, -6, 0)
	rain.initial_velocity_min = 0.6
	rain.initial_velocity_max = 0.9
	rain.position = Vector3(0, -0.06, 0)
	var drop := _cyl(0.004, 0.004, 0.05, 4)
	var dm := _glow(Color("#9fd0ff"), 1.0)
	drop.material = dm
	rain.mesh = drop
	cloud_root.add_child(rain)
	var bolt := _mi(cloud_root, _boxm(Vector3(0.015, 0.18, 0.015)), _glow(Color("#fff8b0"), 6.0), Vector3(0.03, -0.12, 0.06))
	bolt.rotation.z = 0.4
	_animate(cloud_root, "bolt", [bolt])


# --- fun ---------------------------------------------------------------------------------

static func _chai(head: Node3D, token: TransformerToken) -> void:
	var cap := _mi(head, _boxm(Vector3(0.2, 0.07, 0.3)), _solid(Color("#f6f3ea"), 0.8), Vector3(0, 0.03, 0))
	cap.rotation.y = PI * 0.5
	var brass := RoyalBoard.metal(Color("#d8a848"), 0.3)
	var kettle := _in_hand(token, "R", "DesignGearKettle")
	_mi(kettle, _sphere(0.08), brass, Vector3(0, -0.1, 0.06))
	var spout := _mi(kettle, _cyl(0.008, 0.016, 0.11, 8), brass, Vector3(0, -0.07, 0.15))
	spout.rotation.x = 1.0
	_mi(kettle, _torus(0.05, 0.062), brass, Vector3(0, -0.04, 0.0)).rotation.x = PI * 0.5
	var cup := _in_hand(token, "L", "DesignGearCup")
	_mi(cup, _cyl(0.035, 0.028, 0.07, 16), _solid(Color("#f8f4ee"), 0.3), Vector3(0, -0.05, 0.05))
	_mi(cup, _cyl(0.032, 0.032, 0.005, 16), _solid(Color("#8a5022"), 0.2), Vector3(0, -0.017, 0.05))


static func _bollywood(head: Node3D, token: TransformerToken) -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("#101014")
	glass.metallic = 0.6
	glass.roughness = 0.05
	for x in [-0.06, 0.06]:
		var lens := _mi(head, _sphere(0.045), glass, Vector3(x, -0.03, 0.18))
		lens.scale = Vector3(1.1, 0.8, 0.3)
	_mi(head, _boxm(Vector3(0.05, 0.01, 0.01)), RoyalBoard.metal(Color("#e0c060"), 0.2), Vector3(0, -0.02, 0.19))
	## A long scarf fluttering behind.
	var scarf := _on_body(token, "DesignGearScarf", Vector3(0, 0.72, -0.16))
	var red := _solid(Color("#e01e3c"), 0.6)
	var parts: Array = []
	for i in range(3):
		var piece := Node3D.new()
		piece.position = Vector3(0.05 * i, -0.02 * i, -0.08 * i)
		scarf.add_child(piece)
		_mi(piece, _boxm(Vector3(0.09, 0.015, 0.1)), red, Vector3(0, 0, -0.05))
		parts.append(piece)
	_animate(scarf, "wave", parts)


static func _cricket(head: Node3D, token: TransformerToken) -> void:
	var navy := _solid(Color("#1a2a6a"), 0.35)
	var helm := _mi(head, _sphere(0.18), navy, Vector3(0, 0.0, -0.01))
	helm.scale = Vector3(1, 0.85, 1.05)
	_mi(head, _boxm(Vector3(0.24, 0.015, 0.08)), navy, Vector3(0, 0.0, 0.19))
	var steel := RoyalBoard.metal(Color("#c8ccd2"), 0.25)
	for i in range(3):   # face grille
		var bar := _mi(head, _cyl(0.006, 0.006, 0.22, 6), steel, Vector3(0, -0.04 - i * 0.035, 0.2))
		bar.rotation.z = PI * 0.5
	var bat := _in_hand(token, "R", "DesignGearBat")
	_mi(bat, _cyl(0.015, 0.015, 0.12, 8), _solid(Color("#202020"), 0.8), Vector3(0, -0.04, 0.03))
	var blade := _mi(bat, _boxm(Vector3(0.075, 0.3, 0.025)), _solid(Color("#e8cc8a"), 0.6), Vector3(0, -0.24, 0.03))
	blade.rotation.x = 0.15


# --- legends -----------------------------------------------------------------------------

static func _naga(head: Node3D, gold: Material) -> void:
	var scales := _solid(Color("#1f5a3a"), 0.35)
	var belly := _solid(Color("#e8d080"), 0.5)
	var hood := Node3D.new()
	hood.position = Vector3(0, -0.02, -0.14)
	head.add_child(hood)
	for i in range(5):   # five hooded heads fanned behind
		var a := lerpf(-0.9, 0.9, i / 4.0)
		var arm := Node3D.new()
		arm.rotation.z = a
		hood.add_child(arm)
		_mi(arm, _cyl(0.025, 0.035, 0.26, 10), scales, Vector3(0, 0.13, 0))
		var h := _mi(arm, _sphere(0.065), scales, Vector3(0, 0.3, 0.02))
		h.scale = Vector3(1.3, 0.8, 0.5)
		var under := _mi(arm, _sphere(0.05), belly, Vector3(0, 0.27, 0.035))
		under.scale = Vector3(1.1, 1.0, 0.3)
		for x in [-0.025, 0.025]:
			_mi(arm, _sphere(0.01), _glow(Color("#ff2a2a"), 4.0), Vector3(x, 0.31, 0.055))
	_mi(head, _sphere(0.04), RoyalBoard.gem_material(Color("#1fbf6a")), Vector3(0, 0.06, 0.16))
	_mi(head, _torus(0.15, 0.17), gold, Vector3(0, 0.0, 0))


static func _airavata(head: Node3D, gold: Material) -> void:
	var hide := _solid(Color("#f2efe8"), 0.6)
	var cap := _mi(head, _sphere(0.17), hide, Vector3(0, 0.03, -0.01))
	cap.scale = Vector3(1, 0.75, 1)
	for x in [-1.0, 1.0]:
		var ear := _mi(head, _sphere(0.12), hide, Vector3(x * 0.19, -0.02, -0.02))
		ear.scale = Vector3(0.25, 1.0, 0.9)
		var tusk := _mi(head, _cyl(0.0, 0.016, 0.14, 8), _solid(Color("#fffaf0"), 0.2), Vector3(x * 0.06, -0.12, 0.2))
		tusk.rotation.x = 1.9
	for i in range(6):   # trunk curling down and out
		var f := i / 5.0
		_mi(head, _sphere(0.04 - f * 0.015), hide, Vector3(0, -0.05 - f * 0.18, 0.2 + sin(f * 2.2) * 0.07))
	var plate := _mi(head, _sphere(0.08), gold, Vector3(0, 0.05, 0.14))
	plate.scale = Vector3(1, 1.2, 0.3)
	_mi(head, _sphere(0.03), RoyalBoard.gem_material(Color("#d0142e")), Vector3(0, 0.06, 0.17))


static func _hanuman(head: Node3D, token: TransformerToken, gold: Material) -> void:
	## A tall golden mukut.
	_mi(head, _cyl(0.15, 0.16, 0.08, 32), gold, Vector3(0, 0.03, 0))
	_mi(head, _cyl(0.0, 0.14, 0.24, 24), gold, Vector3(0, 0.19, 0))
	_mi(head, _sphere(0.035), RoyalBoard.gem_material(Color("#d0142e")), Vector3(0, 0.08, 0.15))
	_mi(head, _sphere(0.025), RoyalBoard.gem_material(Color("#ffd040")), Vector3(0, 0.32, 0))
	## The gada (mace) resting on the right shoulder.
	var mace := _on_body(token, "DesignGearMace", Vector3(0.3, 0.42, 0.06))
	mace.rotation.z = -0.35
	_mi(mace, _cyl(0.022, 0.022, 0.42, 10), gold, Vector3(0, 0.12, 0))
	var ball := _mi(mace, _sphere(0.12), gold, Vector3(0, 0.38, 0))
	for i in range(3):
		var band := _mi(ball, _torus(0.115, 0.13), RoyalBoard.metal(Color("#b8862c"), 0.3), Vector3.ZERO)
		band.rotation = Vector3(i * 1.05, 0, PI * 0.5)
	_mi(mace, _sphere(0.035), gold, Vector3(0, 0.52, 0))
	_mi(mace, _sphere(0.03), gold, Vector3(0, -0.1, 0))


static func _garuda(head: Node3D, token: TransformerToken, gold: Material) -> void:
	var beak := _mi(head, _cyl(0.0, 0.04, 0.1, 8), _solid(Color("#e8901a"), 0.4), Vector3(0, -0.04, 0.2))
	beak.rotation.x = PI * 0.5 + 0.3
	_crown(head, gold, Color("#d0142e"))
	var back := _on_body(token, "DesignGearWings", Vector3(0, 0.72, -0.2))
	var feather_mat := RoyalBoard.metal(Color("#e8b54f"), 0.3)
	var tip_mat := _solid(Color("#c4102e"), 0.5)
	var wings: Array = []
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(side * 0.08, 0, 0)
		back.add_child(wing)
		for i in range(6):
			var f := Node3D.new()
			f.rotation.z = -side * (0.55 + i * 0.2)   # fanned out sideways and up
			wing.add_child(f)
			var len := 0.62 - i * 0.05
			_mi(f, _boxm(Vector3(0.06, len, 0.012)), feather_mat, Vector3(0, len * 0.5, -0.01 * i))
			_mi(f, _boxm(Vector3(0.062, 0.06, 0.014)), tip_mat, Vector3(0, len - 0.03, -0.01 * i))
		wings.append(wing)
	_animate(back, "flap", wings)


static func _nataraja(head: Node3D, token: TransformerToken, gold: Material) -> void:
	_crown(head, gold, Color("#ff6a1a"))
	var ring_root := _on_body(token, "DesignGearFireRing", Vector3(0, 0.5, -0.2))
	var fire := _glow(Color("#ff7a1a"), 4.0)
	var ring := _mi(ring_root, _torus(0.44, 0.48), RoyalBoard.metal(Color("#d89a3a"), 0.3))
	ring.rotation.x = PI * 0.5
	var flames: Array = []
	for i in range(16):   # flames all around the ring
		var a := TAU * i / 16.0
		var holder := Node3D.new()
		holder.position = Vector3(cos(a) * 0.48, sin(a) * 0.48, 0)
		holder.rotation.z = a - PI * 0.5
		ring_root.add_child(holder)
		_mi(holder, _cyl(0.0, 0.035, 0.11, 8), fire if i % 2 == 0 else _glow(Color("#ffc83a"), 4.0), Vector3(0, 0.05, 0))
		flames.append(holder)
	_animate(ring_root, "flicker", flames)


static func _robo(head: Node3D, token: TransformerToken) -> void:
	var chrome := RoyalBoard.metal(Color("#e8eef4"), 0.32)
	chrome.metallic = 0.75
	_skin(token, chrome)
	_mi(head, _boxm(Vector3(0.26, 0.05, 0.05)), _glow(Color("#2ae0ff"), 4.0), Vector3(0, -0.04, 0.17))
	_mi(head, _cyl(0.006, 0.006, 0.16, 6), RoyalBoard.metal(Color("#606870"), 0.3), Vector3(0.07, 0.1, 0))
	var light := _mi(head, _sphere(0.025), _glow(Color("#ff2a40"), 6.0), Vector3(0.07, 0.19, 0))
	for x in [-0.17, 0.17]:
		_mi(head, _cyl(0.04, 0.04, 0.03, 16), RoyalBoard.metal(Color("#606870"), 0.3), Vector3(x, -0.02, 0)).rotation.z = PI * 0.5
	_animate(head, "blink", [light])


static func _ghost(head: Node3D, token: TransformerToken) -> void:
	var mist := StandardMaterial3D.new()
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.albedo_color = Color(0.85, 0.92, 1.0, 0.38)
	mist.emission_enabled = true
	mist.emission = Color(0.45, 0.65, 1.0)
	mist.emission_energy_multiplier = 0.8
	mist.roughness = 0.2
	mist.cull_mode = BaseMaterial3D.CULL_DISABLED
	_skin(token, mist)
	for x in [-0.05, 0.05]:
		_mi(head, _sphere(0.025), _glow(Color("#9ff0ff"), 6.0), Vector3(x, -0.03, 0.17))



# --- festival designs --------------------------------------------------------------------

static func _diya(head: Node3D, token: TransformerToken) -> void:
	var clay := _solid(Color("#b4582a"), 0.8)
	var lamp := _mi(head, _cyl(0.1, 0.05, 0.06, 20), clay, Vector3(0, 0.04, 0))
	_mi(lamp, _torus(0.085, 0.1), RoyalBoard.metal(Color("#e8b54f"), 0.3), Vector3(0, 0.03, 0))
	var flame_root := Node3D.new()
	flame_root.position = Vector3(0, 0.08, 0.04)
	head.add_child(flame_root)
	var flame := _mi(flame_root, _sphere(0.04), _glow(Color("#ffb030"), 6.0), Vector3(0, 0.04, 0))
	flame.scale = Vector3(0.7, 1.6, 0.7)
	_mi(flame_root, _sphere(0.018), _glow(Color("#fff2b0"), 8.0), Vector3(0, 0.03, 0))
	_animate(head, "flicker", [flame_root])
	## A marigold garland around the neck.
	var garland := _on_body(token, "DesignGearGarland", Vector3(0, 0.66, 0))
	for i in range(18):
		var a := TAU * i / 18.0
		_mi(garland, _sphere(0.03), _solid(Color("#ff9a10") if i % 2 == 0 else Color("#ffd020"), 0.7), Vector3(cos(a) * 0.22, -abs(sin(a * 0.5)) * 0.06, sin(a) * 0.2))


static func _holi(head: Node3D) -> void:
	var colors := [Color("#ff2a8a"), Color("#20c0ff"), Color("#ffd020"), Color("#30e070"), Color("#a040ff")]
	var band := _mi(head, _torus(0.15, 0.18), _solid(Color("#ffffff"), 0.7), Vector3(0, -0.01, 0))
	band.rotation.x = 0.1
	for i in range(10):   # splashes of colour powder
		var a := TAU * i / 10.0 + 0.2
		var splash := _mi(head, _sphere(0.04 + (i % 3) * 0.01), _solid(colors[i % colors.size()], 0.9), Vector3(cos(a) * 0.15, 0.03 + (i % 2) * 0.05, sin(a) * 0.15))
		splash.scale = Vector3(1.2, 0.5, 1.2)
	var pichkari := _mi(head, _cyl(0.02, 0.02, 0.2, 10), _solid(Color("#30e070"), 0.4), Vector3(0.16, 0.14, 0))
	pichkari.rotation.z = 0.9


static func _kite(head: Node3D, token: TransformerToken) -> void:
	_mi(head, _torus(0.14, 0.17), _solid(Color("#ffd020"), 0.6), Vector3(0, 0.0, 0))
	var back := _on_body(token, "DesignGearKite", Vector3(0, 0.9, -0.22))
	var kite := Node3D.new()
	back.add_child(kite)
	var sail := _mi(kite, _boxm(Vector3(0.3, 0.3, 0.01)), _solid(Color("#e01e5a"), 0.6), Vector3.ZERO)
	sail.rotation.z = PI * 0.25
	var stripe := _mi(kite, _boxm(Vector3(0.42, 0.04, 0.012)), _solid(Color("#ffd020"), 0.6), Vector3(0, 0, 0.002))
	stripe.rotation.z = PI * 0.25
	for i in range(4):   # ribbon tail
		_mi(kite, _boxm(Vector3(0.04, 0.05, 0.008)), _solid(Color("#20a0ff") if i % 2 == 0 else Color("#ffd020"), 0.6), Vector3(0, -0.24 - i * 0.07, 0))
	_mi(back, _cyl(0.004, 0.004, 0.4, 6), _solid(Color("#f0f0f0"), 0.8), Vector3(0.0, -0.2, 0.02)).rotation.z = 0.2
	_animate(back, "wave", [kite])


static func _tiranga(head: Node3D, gold: Material) -> void:
	var colours := [Color("#ff9933"), Color("#ffffff"), Color("#138808")]
	for i in range(3):
		_mi(head, _torus(0.1, 0.17 - i * 0.012), _solid(colours[i], 0.55), Vector3(0, 0.03 + (2 - i) * 0.05, 0))
	_mi(head, _sphere(0.1), _solid(colours[0], 0.55), Vector3(0, 0.14, 0))
	var chakra := _mi(head, _torus(0.03, 0.045), _solid(Color("#0a2a8a"), 0.3), Vector3(0, 0.08, 0.17))
	chakra.rotation.x = PI * 0.5
	for i in range(8):   # spokes of the chakra
		var spoke := _mi(head, _boxm(Vector3(0.004, 0.06, 0.004)), _solid(Color("#0a2a8a"), 0.3), Vector3(0, 0.08, 0.175))
		spoke.rotation.z = PI * i / 8.0
	_mi(head, _sphere(0.012), gold, Vector3(0, 0.08, 0.18))


static func _star(head: Node3D) -> void:
	var red := _solid(Color("#d01e2a"), 0.6)
	var cap := _mi(head, _cyl(0.0, 0.16, 0.26, 24), red, Vector3(0, 0.12, -0.02))
	cap.rotation.x = -0.25
	_mi(head, _torus(0.14, 0.18), _solid(Color("#ffffff"), 0.9), Vector3(0, 0.0, 0))
	var star := Node3D.new()
	star.position = Vector3(0, 0.36, -0.02)
	star.scale = Vector3.ONE * 2.0
	head.add_child(star)
	var glow := _glow(Color("#ffe060"), 5.0)
	for i in range(5):   # a five-pointed glowing star
		var arm := _mi(star, _cyl(0.0, 0.03, 0.09, 6), glow, Vector3.ZERO)
		arm.rotation.z = TAU * i / 5.0
		arm.position = Vector3(-sin(TAU * i / 5.0), cos(TAU * i / 5.0), 0) * 0.045
	_mi(star, _sphere(0.03), glow)


## Mastery: one to three golden stars circling above the head.
static func _mastery_stars(head: Node3D, level: int) -> void:
	var stars: Array = []
	var colours := [Color("#cd7f45"), Color("#d8dde6"), Color("#ffd24a")]
	for i in range(level):
		var st := Node3D.new()
		head.add_child(st)
		var m := _mi(st, _sphere(0.03), _glow(colours[level - 1], 4.0))
		m.scale = Vector3(1, 1, 0.5)
		stars.append(st)
	_animate(head, "orbit", stars)
