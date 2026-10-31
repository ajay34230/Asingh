class_name Murals
extends RefCounted
## Hand-painted decoration for walls: a mandala / rangoli panel, a painted diamond border for the
## base and the top of a wall. The pictures are drawn pixel by pixel in code (no imported assets).

static var _tex := {}
const PALETTES := [
	[Color(0.80, 0.12, 0.14), Color(0.98, 0.78, 0.12), Color(0.10, 0.45, 0.62), Color(0.97, 0.93, 0.82)],
	[Color(0.15, 0.50, 0.36), Color(0.95, 0.45, 0.10), Color(0.62, 0.14, 0.50), Color(0.99, 0.95, 0.80)],
	[Color(0.10, 0.30, 0.66), Color(0.98, 0.70, 0.10), Color(0.84, 0.20, 0.30), Color(0.97, 0.94, 0.86)],
]


static func mandala(i: int) -> ImageTexture:
	var key := "mandala_%d" % (i % PALETTES.size())
	if _tex.has(key):
		return _tex[key]
	var pal: Array = PALETTES[i % PALETTES.size()]
	var n := 128
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var petals := 8 + 4 * (i % 3)
	for y in n:
		for x in n:
			var dx := (x + 0.5) / n * 2.0 - 1.0
			var dy := (y + 0.5) / n * 2.0 - 1.0
			var r := sqrt(dx * dx + dy * dy)
			var a := atan2(dy, dx)
			if r > 0.98:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var c: Color = pal[3]
			var petal := 0.55 + 0.2 * absf(cos(a * petals * 0.5))
			if r > 0.9:
				c = pal[0]
			elif r > 0.84:
				c = pal[3]
			elif r > 0.72:
				c = pal[2] if int((a + PI) / TAU * petals * 2.0) % 2 == 0 else pal[1]
			elif r > petal:
				c = pal[3]
			elif r > 0.28:
				c = pal[0] if int((a + PI) / TAU * petals) % 2 == 0 else pal[1]
				if r < 0.36:
					c = pal[2]
			elif r > 0.16:
				c = pal[1]
			else:
				c = pal[0]
			var dot := absf(r - 0.78) < 0.025 and int((a + PI) / TAU * petals * 4.0) % 2 == 0
			if dot:
				c = pal[3]
			img.set_pixel(x, y, c)
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


static func border(i: int) -> ImageTexture:
	var key := "border_%d" % (i % PALETTES.size())
	if _tex.has(key):
		return _tex[key]
	var pal: Array = PALETTES[i % PALETTES.size()]
	var w := 64
	var h := 32
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c: Color = pal[3]
			if y < 3 or y >= h - 3:
				c = pal[0]
			else:
				var u := float(x % 32) / 32.0
				var v := float(y - 3) / (h - 6)
				var tri := absf(u - 0.5) * 2.0          # triangle wave across the tile
				if v > tri * 0.9 + 0.05 and v < 1.0 - 0.0:
					c = pal[1] if (x / 32) % 2 == 0 else pal[2]
				if absf(v - 0.5) < 0.08 and absf(u - 0.5) < 0.08:
					c = pal[0]
			img.set_pixel(x, y, c)
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


static func _mat(t: Texture2D, repeat_x: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.roughness = 0.9
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.uv1_scale = Vector3(repeat_x, 1, 1)
	m.texture_repeat = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func _quad(parent: Node3D, size: Vector2, pos: Vector3, mat: Material, yaw_flip: bool = false) -> void:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## A painted band along a front wall at height `y`, split around the door (gap centred on door_x).
static func band(parent: Node3D, x0: float, x1: float, y: float, z: float, h: float, style: int,
		gap_x: float = 0.0, gap_w: float = 0.0) -> void:
	var segs: Array = []
	if gap_w > 0.0 and gap_x > x0 and gap_x < x1:
		segs = [[x0, gap_x - gap_w * 0.5], [gap_x + gap_w * 0.5, x1]]
	else:
		segs = [[x0, x1]]
	for s in segs:
		var len_: float = float(s[1]) - float(s[0])
		if len_ < 0.3:
			continue
		_quad(parent, Vector2(len_, h), Vector3((float(s[0]) + float(s[1])) * 0.5, y, z), _mat(border(style), len_ / (h * 2.0)))


static func panel(parent: Node3D, x: float, y: float, z: float, size: float, style: int) -> void:
	_quad(parent, Vector2(size, size), Vector3(x, y, z), _mat(mandala(style), 1.0))
