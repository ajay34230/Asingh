## Procedural Mughal chhatri (domed pavilion) in the style of Rajasthan's palaces:
##   stepped red-sandstone octagonal plinth with a marble band
##   eight baluster columns (vase base, fluted shaft, lotus capital)
##   cusped (multifoil) arches with inlaid gems in the spandrels
##   carved jali lattice screens between the lower columns
##   a wide sloping chhajja (eave) with corner pinnacles (guldastas)
##   a bulbous onion dome on a drum, lotus crown and a gold kalash finial
## Everything is built from revolved profiles and extruded outlines, so it costs no
## asset space. Sizes are in board units (one board cell = 1).
class_name Monuments
extends RefCounted

const SIDES := 8

var marble: Material
var sandstone: Material
var gold: Material
var gem: Material
var jali: Material


func _init(marble_mat: Material, gold_mat: Material, gem_mat: Material) -> void:
	marble = monument_marble(marble_mat)
	gold = gold_mat
	gem = gem_mat
	sandstone = sandstone_material()
	jali = jali_material(marble_mat)


# --- materials -----------------------------------------------------------------

## Makrana-style marble for buildings: warm white, visible veins, a soft satin polish
## (less glossy than the board tiles, so domes read as stone, not plastic).
static func monument_marble(_base: Material) -> StandardMaterial3D:
	return RoyalBoard.pbr("marble_white", Color("#f3ece0"), 0.5, 0.75, 0.3)


## Rajasthani red sandstone: a scanned travertine dyed the colour of Jaipur's forts.
static func sandstone_material() -> StandardMaterial3D:
	return RoyalBoard.pbr("travertine_brown", Color("#e8906a"), 0.7, 1.0, 0.0)


## Jali: a carved marble screen, an eight-pointed star lattice cut through the stone.
static func jali_material(base: Material) -> StandardMaterial3D:
	var size := 128
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var u := float(x) / size * 2.0
			var v := float(y) / size * 2.0
			var p := Vector2(fposmod(u, 1.0) - 0.5, fposmod(v, 1.0) - 0.5)
			var r := p.length()
			var a := atan2(p.y, p.x)
			var star := 0.3 + 0.08 * cos(8.0 * a)          # eight-pointed star hole
			var diag := minf(absf(p.x + p.y), absf(p.x - p.y))  # lattice bars
			var hole := r < star and diag > 0.06
			var ring := absf(r - 0.16) < 0.025               # small carved ring inside
			var solid := not hole or ring
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 if solid else 0.0))
	img.generate_mipmaps()
	var mat := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.uv1_triplanar = false
	mat.uv1_world_triplanar = false
	mat.uv1_scale = Vector3.ONE
	mat.detail_enabled = false
	mat.albedo_texture = null
	mat.albedo_color = Color("#f6f0e4")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tex := ImageTexture.create_from_image(img)
	mat.albedo_texture = tex
	return mat


# --- mesh builders ------------------------------------------------------------------

## Surface of revolution from a profile of (radius, height) points, bottom to top.
## `flat_around` gives faceted sides (octagonal masonry); otherwise smooth (domes).
## Creases sharper than ~35 degrees along the profile stay sharp.
static func lathe(profile: PackedVector2Array, segments: int, flat_around := false, phase := 0.0) -> ArrayMesh:
	var n := profile.size()
	var seg_normals: Array[Vector2] = []
	for i in range(n - 1):
		var t := profile[i + 1] - profile[i]
		seg_normals.append(Vector2(t.y, -t.x).normalized())
	var point_normal := func(seg: int, end: int) -> Vector2:
		# Normal at the start (end=0) or end (end=1) of a profile segment.
		var k := seg + end
		var other := seg - 1 if end == 0 else seg + 1
		if other < 0 or other >= seg_normals.size():
			return seg_normals[seg]
		if seg_normals[seg].dot(seg_normals[other]) < 0.82:
			return seg_normals[seg]
		return (seg_normals[seg] + seg_normals[other]).normalized() if k >= 0 else seg_normals[seg]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(n - 1):
		var r0 := profile[i]
		var r1 := profile[i + 1]
		var n0: Vector2 = point_normal.call(i, 0)
		var n1: Vector2 = point_normal.call(i, 1)
		for j in range(segments):
			var a0 := phase + TAU * j / segments
			var a1 := phase + TAU * (j + 1) / segments
			var am := (a0 + a1) * 0.5
			var corners := [[r0, n0, a0], [r0, n0, a1], [r1, n1, a1], [r1, n1, a0]]
			var verts: Array[Vector3] = []
			var norms: Array[Vector3] = []
			for c in corners:
				var pr: Vector2 = c[0]
				var nr: Vector2 = c[1]
				var ang: float = c[2]
				var na: float = am if flat_around else ang
				verts.append(Vector3(pr.x * cos(ang), pr.y, pr.x * sin(ang)))
				norms.append(Vector3(nr.x * cos(na), nr.y, nr.x * sin(na)).normalized())
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(norms[k])
				st.set_uv(Vector2(float(j) / segments, verts[k].y))
				st.add_vertex(verts[k])
	return st.commit()


## Catmull-Rom resampling of a few control points into a smooth profile.
static func smooth_profile(ctrl: PackedVector2Array, steps_per_span := 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(ctrl.size() - 1):
		var p0 := ctrl[maxi(i - 1, 0)]
		var p1 := ctrl[i]
		var p2 := ctrl[i + 1]
		var p3 := ctrl[mini(i + 2, ctrl.size() - 1)]
		for s in range(steps_per_span):
			var t := float(s) / steps_per_span
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(ctrl[ctrl.size() - 1])
	return out


static func _mi(mesh: Mesh, mat: Material, parent: Node3D, at := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m


## Cusped (multifoil) arch outline: a pointed arch with `lobes` scallops cut into it.
static func cusped_arch(half_w: float, spring_y: float, apex_y: float, lobes := 5, depth := 0.035) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 96
	for s in range(steps + 1):
		var t := float(s) / steps
		# Pointed arch: two circular arcs meeting at the apex.
		var side := -1.0 if t < 0.5 else 1.0
		var k := t * 2.0 if t < 0.5 else (1.0 - t) * 2.0     # 0 at springing, 1 at apex
		var ang := k * PI * 0.5
		var x := side * half_w * cos(ang)
		var y := spring_y + (apex_y - spring_y) * sin(ang)
		# Scallops: push the edge inward between cusps.
		var lobe := absf(sin(t * PI * lobes))
		var inward := Vector2(-x, -(y - spring_y)).normalized() if t != 0.5 else Vector2(0, -1)
		x += inward.x * depth * lobe
		y += inward.y * depth * lobe
		pts.append(Vector2(x, y))
	return pts


# --- the chhatri ---------------------------------------------------------------------

## Builds a chhatri with its base centre at the parent origin. `radius` is the column
## circle; the whole pavilion is about 3.2 x radius tall.
func build_chhatri(parent: Node3D, radius := 0.55) -> void:
	var R := radius
	var flat := true
	var phase := PI / SIDES   # flat faces towards the four board directions

	# Plinth: two sandstone steps and a marble platform with an inlaid band.
	_mi(lathe(PackedVector2Array([Vector2(0, 0), Vector2(R * 1.45, 0), Vector2(R * 1.45, 0.08), Vector2(R * 1.32, 0.08),
		Vector2(R * 1.32, 0.16), Vector2(R * 1.2, 0.16), Vector2(R * 1.2, 0.2), Vector2(0, 0.2)]), SIDES, flat, phase), sandstone, parent)
	_mi(lathe(PackedVector2Array([Vector2(0, 0.2), Vector2(R * 1.17, 0.2), Vector2(R * 1.17, 0.21), Vector2(0, 0.21)]), SIDES, flat, phase), gold, parent)
	_mi(lathe(PackedVector2Array([Vector2(0, 0.21), Vector2(R * 1.14, 0.21), Vector2(R * 1.14, 0.235), Vector2(0, 0.235)]), SIDES, flat, phase), marble, parent)
	var floor_y := 0.235

	# Columns at the eight corners.
	var col_h := R * 1.45
	var column := lathe(smooth_profile(PackedVector2Array([
		Vector2(0, 0), Vector2(0.075, 0), Vector2(0.075, 0.03), Vector2(0.06, 0.05), Vector2(0.07, 0.1),     # base
		Vector2(0.05, 0.16), Vector2(0.04, 0.22), Vector2(0.036, col_h * 0.55), Vector2(0.04, col_h * 0.8),   # shaft
		Vector2(0.055, col_h * 0.88), Vector2(0.07, col_h * 0.95), Vector2(0.06, col_h), Vector2(0, col_h)]), 6), 32)
	var corner_angle := func(i: int) -> float: return phase + TAU * i / SIDES   # matches the plinth corners
	for i in range(SIDES):
		var a: float = corner_angle.call(i)
		_mi(column, marble, parent, Vector3(cos(a) * R, floor_y, sin(a) * R))

	# Arched faces between the columns: cusped arches, gems in the spandrels.
	var face_w := 2.0 * R * sin(PI / SIDES)
	var apothem := R * cos(PI / SIDES)
	var top := floor_y + col_h
	var spring := floor_y + col_h * 0.48
	var arch := cusped_arch(face_w * 0.36, spring - floor_y, col_h * 0.78, 5, 0.028)
	## Gold moulding that traces the arch.
	var outer := cusped_arch(face_w * 0.36 + 0.012, spring - floor_y, col_h * 0.78 + 0.014, 5, 0.028)
	var band := PackedVector2Array(outer)
	var inner := arch.duplicate()
	inner.reverse()
	band.append_array(inner)
	var trim := RoyalBoard.extrude_mesh(_xz(band), -0.03, 0.03)
	var outline := PackedVector2Array([Vector2(-face_w * 0.5, spring - floor_y)])
	outline.append_array(arch)
	outline.append(Vector2(face_w * 0.5, spring - floor_y))
	outline.append(Vector2(face_w * 0.5, col_h))
	outline.append(Vector2(-face_w * 0.5, col_h))
	var spandrel := RoyalBoard.extrude_mesh(_xz(outline), -0.025, 0.025)
	var jali_mesh := QuadMesh.new()
	jali_mesh.size = Vector2(face_w * 0.84, col_h * 0.26)
	for i in range(SIDES):
		var mid: float = corner_angle.call(i) + PI / SIDES
		var face := Node3D.new()
		face.position = Vector3(cos(mid) * apothem, floor_y, sin(mid) * apothem)
		face.rotation.y = -mid + PI * 0.5
		parent.add_child(face)
		var sp := _mi(spandrel, marble, face)
		sp.rotation.x = PI * 0.5     # stand the outline up in the face plane
		var tr := _mi(trim, gold, face)
		tr.rotation.x = PI * 0.5
		_mi(_gem_mesh(), gem, face, Vector3(face_w * 0.36, col_h * 0.84, 0.03))
		_mi(_gem_mesh(), gem, face, Vector3(-face_w * 0.36, col_h * 0.84, 0.03))
		# Jali screens on the lower part of three faces in four, leaving an entrance.
		if i % 4 != 1:
			var screen := _mi(jali_mesh, jali, face, Vector3(0, col_h * 0.15, 0))
			screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# Entablature and the chhajja (sloping eave) with brackets.
	_mi(lathe(PackedVector2Array([Vector2(0, top), Vector2(R * 1.08, top), Vector2(R * 1.08, top + 0.07), Vector2(0, top + 0.07)]), SIDES, flat, phase), marble, parent)
	_mi(lathe(PackedVector2Array([Vector2(R * 1.0, top + 0.03), Vector2(R * 1.28, top - 0.07), Vector2(R * 1.28, top - 0.045),
		Vector2(R * 1.05, top + 0.1), Vector2(0, top + 0.1)]), SIDES, flat, phase), marble, parent)
	_mi(lathe(PackedVector2Array([Vector2(R * 1.27, top - 0.075), Vector2(R * 1.3, top - 0.075), Vector2(R * 1.3, top - 0.055), Vector2(R * 1.27, top - 0.055)]), SIDES, flat, phase), gold, parent)
	# Corner pinnacles (guldastas) on the eave.
	var pinnacle := lathe(smooth_profile(PackedVector2Array([Vector2(0.04, 0), Vector2(0.03, 0.06), Vector2(0.045, 0.1),
		Vector2(0.02, 0.17), Vector2(0.008, 0.22), Vector2(0, 0.24)]), 5), 24)
	for i in range(SIDES):
		var a: float = corner_angle.call(i)
		_mi(pinnacle, gold, parent, Vector3(cos(a) * R * 1.0, top + 0.1, sin(a) * R * 1.0))

	# Drum, lotus collar and the onion dome.
	var drum_y := top + 0.1
	var dr := R * 0.82
	_mi(lathe(PackedVector2Array([Vector2(0, drum_y), Vector2(dr, drum_y), Vector2(dr, drum_y + 0.12), Vector2(dr * 1.04, drum_y + 0.12),
		Vector2(dr * 1.04, drum_y + 0.15), Vector2(0, drum_y + 0.15)]), SIDES * 2, flat, phase), marble, parent)
	var dome_y := drum_y + 0.15
	var dome_h := R * 1.7
	var ctrl := PackedVector2Array([Vector2(0.9, 0.0), Vector2(1.06, 0.1), Vector2(1.12, 0.26), Vector2(1.06, 0.43),
		Vector2(0.86, 0.6), Vector2(0.55, 0.77), Vector2(0.27, 0.89), Vector2(0.1, 0.96), Vector2(0.0, 1.0)])
	var dome_profile := PackedVector2Array()
	for p in smooth_profile(ctrl, 5):
		dome_profile.append(Vector2(p.x * dr, dome_y + p.y * dome_h))
	_mi(lathe(dome_profile, 96), marble, parent)
	# Lotus petals around the dome's base.
	var petal := SphereMesh.new()
	petal.radius = 0.5
	petal.height = 1.0
	petal.radial_segments = 24
	petal.rings = 12
	for i in range(16):
		var a := TAU * i / 16.0
		var holder := Node3D.new()
		holder.position = Vector3(0, dome_y + 0.01, 0)
		holder.rotation.y = -a
		parent.add_child(holder)
		var pm := _mi(petal, marble, holder, Vector3(dr * 0.98, 0.04, 0))
		pm.scale = Vector3(0.05, 0.14, 0.11)
		pm.rotation.z = -0.5
	# Inverted lotus crown and the kalash finial.
	var crown_y := dome_y + dome_h * 0.94
	_mi(lathe(smooth_profile(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.09, 0.0), Vector2(0.12, 0.03), Vector2(0.05, 0.07), Vector2(0, 0.08)]), 6), 48), gold, parent, Vector3(0, crown_y, 0))
	_mi(lathe(smooth_profile(PackedVector2Array([Vector2(0.015, 0.0), Vector2(0.05, 0.02), Vector2(0.065, 0.06), Vector2(0.03, 0.1),
		Vector2(0.045, 0.13), Vector2(0.02, 0.16), Vector2(0.012, 0.28), Vector2(0, 0.32)]), 6), 48), gold, parent, Vector3(0, crown_y + 0.07, 0))
	_mi(_gem_mesh(0.03), gem, parent, Vector3(0, crown_y + 0.18, 0))


static func _xz(points: PackedVector2Array) -> PackedVector2Array:
	# extrude_mesh builds in the XZ plane; the arch outline is drawn in XY. Flip Y to Z
	# so that standing it up (rotation.x = +90 degrees) puts it the right way up.
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(p.x, -p.y))
	return out


func _gem_mesh(r := 0.022) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	return s
