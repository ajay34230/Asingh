## Bakes a group of small meshes into one mesh with a surface per material.
##
## A knight is built from ~270 little primitives; drawn as they are, 16 of them cost
## thousands of draw calls (and again in every shadow pass), which makes 4-player games
## crawl on a phone. Parts that move together (a body, a head, one limb segment...) are
## merged into a single mesh instead; the merged mesh is built once per colour and shared
## by every token of that colour. Materials stay per surface, so designs can still recolour
## a token with per-instance surface overrides.
class_name MeshMerge
extends RefCounted

static var _cache := {}


## Merges the meshes under `root` (not those under any node in `skip`) into one
## MeshInstance3D named `name`. `key` identifies the result in the shared cache, so the
## geometry is only merged the first time ("" disables caching). `shadows` false stops the
## result casting shadows.
static func bake(root: Node3D, key: String, skip: Array = [], shadows := true, free_parts := true) -> MeshInstance3D:
	var cached: Mesh = _cache.get(key) if key != "" else null
	var parts: Array[MeshInstance3D] = []
	_collect(root, skip, parts)
	var mesh: Mesh = cached
	if mesh == null:
		mesh = _merge(root, parts)
		if key != "" and mesh != null:
			_cache[key] = mesh
	for p in parts:   # the originals are no longer needed (unless this is only a copy for LOD)
		if free_parts and is_instance_valid(p) and p.get_parent() != null:
			p.get_parent().remove_child(p)
			p.free()
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = "Baked" if free_parts else "FarLOD"
	mi.mesh = mesh
	if not shadows:   # small details: not worth a draw call in every shadow pass
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


static func _collect(node: Node, skip: Array, out: Array[MeshInstance3D]) -> void:
	for c in node.get_children():
		if skip.has(c):
			continue
		if c is MeshInstance3D:
			out.append(c)
		_collect(c, skip, out)


## The transform of `n` relative to `root` (the nodes may not be in the scene tree yet).
static func _relative(n: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


static func _merge(root: Node3D, parts: Array[MeshInstance3D]) -> Mesh:
	var groups := {}      # Material -> {"v": PackedVector3Array, "n": ..., "uv": ..., "i": PackedInt32Array}
	var order: Array = []
	for mi in parts:
		if mi.mesh == null:
			continue
		var xf := _relative(mi, root)
		var flip := xf.basis.determinant() < 0.0
		var nb := xf.basis.inverse().transposed()
		for s in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.material_override
			if mat == null:
				mat = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if verts.is_empty():
				continue
			if not groups.has(mat):
				groups[mat] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "i": PackedInt32Array()}
				order.append(mat)
			var g: Dictionary = groups[mat]
			var base: int = (g["v"] as PackedVector3Array).size()
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var have_n := norms.size() == verts.size()
			var have_uv := uvs.size() == verts.size()
			var gv: PackedVector3Array = g["v"]
			var gn: PackedVector3Array = g["n"]
			var guv: PackedVector2Array = g["uv"]
			for k in range(verts.size()):
				gv.append(xf * verts[k])
				gn.append((nb * norms[k]).normalized() if have_n else Vector3.UP)
				guv.append(uvs[k] if have_uv else Vector2.ZERO)
			var idx: Variant = arrays[Mesh.ARRAY_INDEX]
			var gi: PackedInt32Array = g["i"]
			var count: int = idx.size() if idx != null and idx.size() > 0 else verts.size()
			for t in range(0, count, 3):
				var a: int = idx[t] if idx != null and idx.size() > 0 else t
				var b: int = idx[t + 1] if idx != null and idx.size() > 0 else t + 1
				var c: int = idx[t + 2] if idx != null and idx.size() > 0 else t + 2
				if flip:   # a mirrored part would otherwise be drawn inside out
					gi.append(base + a)
					gi.append(base + c)
					gi.append(base + b)
				else:
					gi.append(base + a)
					gi.append(base + b)
					gi.append(base + c)
			g["v"] = gv
			g["n"] = gn
			g["uv"] = guv
			g["i"] = gi
	if order.is_empty():
		return null
	## ImporterMesh builds automatic simplified levels (meshoptimizer); the renderer picks
	## one by on-screen size (viewport mesh_lod_threshold), so a token far away costs a
	## fraction of the triangles.
	var im := ImporterMesh.new()
	for mat in order:
		var g: Dictionary = groups[mat]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = g["v"]
		arr[Mesh.ARRAY_NORMAL] = g["n"]
		arr[Mesh.ARRAY_TEX_UV] = g["uv"]
		arr[Mesh.ARRAY_INDEX] = g["i"]
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, mat, "s%d" % im.get_surface_count())
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


## ---------------------------------------------------------------------------------------
## Static scenery (the board, statues, fountain, dice): everything that never moves relative
## to `root` becomes one mesh with a surface per material, and that mesh is kept at three
## levels of detail so the quality setting can swap them without rebuilding anything.
## ---------------------------------------------------------------------------------------

const DETAIL_GROUP := "baked_detail"
## Share of the full triangle count kept at each graphics quality.
const DETAIL_SHARE := {"low": 0.22, "medium": 0.5, "high": 1.0}

static var _static_cache := {}


## Merges every visible, unskinned MeshInstance3D under `root` (but not under any node in
## `skip`). Parts that do not cast shadows stay in a second mesh so they still do not.
## Returns the new instances. `key` shares the result between identical models.
static func bake_static(root: Node3D, key: String, skip: Array = [], levels := true) -> Array[MeshInstance3D]:
	var parts: Array[MeshInstance3D] = []
	_collect_static(root, skip, parts)
	var out: Array[MeshInstance3D] = []
	if parts.size() < 2:
		return out
	var sets: Dictionary = _static_cache.get(key, {}) if key != "" else {}
	if sets.is_empty():
		var lit: Array[MeshInstance3D] = []
		var unlit: Array[MeshInstance3D] = []
		for p in parts:
			if p.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				unlit.append(p)
			else:
				lit.append(p)
		for pair in [["shadow", lit], ["flat", unlit]]:
			var im := _merge_fast(root, pair[1])
			if im != null:
				sets[pair[0]] = {"high": im.get_mesh()}
				if levels:
					sets[pair[0]]["medium"] = _reduced(im, DETAIL_SHARE["medium"])
					sets[pair[0]]["low"] = _reduced(im, DETAIL_SHARE["low"])
		if key != "":
			_static_cache[key] = sets
	for p in parts:
		if is_instance_valid(p) and p.get_parent() != null:
			if p.get_child_count() == 0:
				p.get_parent().remove_child(p)
				p.free()
			else:           # something hangs off this part (a light, a label): keep the node
				p.mesh = null
	for kind in sets:
		var mi := MeshInstance3D.new()
		mi.name = "BakedStatic_" + String(kind)
		mi.mesh = sets[kind]["high"]
		if kind == "flat":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if levels:
			mi.set_meta("detail_meshes", sets[kind])
			mi.add_to_group(DETAIL_GROUP)
		root.add_child(mi)
		out.append(mi)
	return out


## Swaps every baked scenery mesh to the level for a graphics quality ("low", "medium", "high").
static func apply_detail(tree: SceneTree, quality: String) -> void:
	for n in tree.get_nodes_in_group(DETAIL_GROUP):
		var meshes: Dictionary = n.get_meta("detail_meshes", {})
		if meshes.has(quality):
			(n as MeshInstance3D).mesh = meshes[quality]


static func _collect_static(node: Node, skip: Array, out: Array[MeshInstance3D]) -> void:
	for c in node.get_children():
		if skip.has(c) or c.has_meta("no_merge"):
			continue
		if c is Node3D and not (c as Node3D).visible:
			continue
		if c is MeshInstance3D:
			var m := c as MeshInstance3D
			if m.mesh != null and m.skin == null and not (m.mesh is ArrayMesh and (m.mesh as ArrayMesh).get_blend_shape_count() > 0) and m.material_overlay == null and m.transparency == 0.0 and not String(m.name).begins_with("BakedStatic"):
				out.append(m)
		_collect_static(c, skip, out)


## Like _merge, but the per-vertex work is done by the engine (whole arrays are transformed
## at once), so a 300,000-triangle statue merges in a fraction of a second.
static func _merge_fast(root: Node3D, parts: Array[MeshInstance3D]) -> ImporterMesh:
	var groups := {}
	var order: Array = []
	for mi in parts:
		var xf := _relative(mi, root)
		var flip := xf.basis.determinant() < 0.0
		var nb := Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO)
		var sc := xf.basis.get_scale()
		var unit := absf(sc.x - 1.0) < 0.001 and absf(sc.y - 1.0) < 0.001 and absf(sc.z - 1.0) < 0.001
		for s in range(mi.mesh.get_surface_count()):
			if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var mat: Material = mi.material_override
			if mat == null:
				mat = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if verts.is_empty():
				continue
			if not groups.has(mat):
				groups[mat] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
				order.append(mat)
			var g: Dictionary = groups[mat]
			var gv: PackedVector3Array = g["v"]
			var gn: PackedVector3Array = g["n"]
			var guv: PackedVector2Array = g["uv"]
			var gc: PackedColorArray = g["c"]
			var gi: PackedInt32Array = g["i"]
			var base := gv.size()
			var count := verts.size()
			gv.append_array(xf * verts)
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			if norms.size() == count:
				norms = nb * norms
				if not unit:
					for k in range(count):
						norms[k] = norms[k].normalized()
				gn.append_array(norms)
			else:
				var up := PackedVector3Array()
				up.resize(count)
				up.fill(Vector3.UP)
				gn.append_array(up)
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			if uvs.size() != count:
				uvs = PackedVector2Array()
				uvs.resize(count)
			guv.append_array(uvs)
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			if cols.size() == count:
				if gc.size() < base:      # earlier parts had no colours: they are white
					var pad := PackedColorArray()
					pad.resize(base - gc.size())
					pad.fill(Color.WHITE)
					gc.append_array(pad)
				gc.append_array(cols)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(count)
				for k in range(count):
					idx[k] = k
			if base == 0 and not flip:
				gi.append_array(idx)
			else:
				var n := idx.size()
				var start := gi.size()
				gi.resize(start + n)
				if flip:
					for t in range(0, n - 2, 3):
						gi[start + t] = base + idx[t]
						gi[start + t + 1] = base + idx[t + 2]
						gi[start + t + 2] = base + idx[t + 1]
				else:
					for t in range(n):
						gi[start + t] = base + idx[t]
			g["v"] = gv
			g["n"] = gn
			g["uv"] = guv
			g["c"] = gc
			g["i"] = gi
	if order.is_empty():
		return null
	var im := ImporterMesh.new()
	for mat in order:
		var g: Dictionary = groups[mat]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = g["v"]
		arr[Mesh.ARRAY_NORMAL] = g["n"]
		arr[Mesh.ARRAY_TEX_UV] = g["uv"]
		var gc: PackedColorArray = g["c"]
		if not gc.is_empty():
			if gc.size() < (g["v"] as PackedVector3Array).size():
				var pad := PackedColorArray()
				pad.resize((g["v"] as PackedVector3Array).size() - gc.size())
				pad.fill(Color.WHITE)
				gc.append_array(pad)
			arr[Mesh.ARRAY_COLOR] = gc
		arr[Mesh.ARRAY_INDEX] = g["i"]
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).normal_enabled:
			var st := SurfaceTool.new()        # normal maps need tangents
			st.create_from_arrays(arr)
			st.generate_tangents()
			arr = st.commit_to_arrays()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, mat, "s%d" % im.get_surface_count())
	im.generate_lods(25.0, 60.0, [])
	return im


## A mesh that starts at the automatic level nearest to `share` of the full triangle count.
static func _reduced(im: ImporterMesh, share: float) -> Mesh:
	var mesh := ArrayMesh.new()
	for s in range(im.get_surface_count()):
		var arr := im.get_surface_arrays(s)
		var full: int = (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
		var best: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for l in range(im.get_surface_lod_count(s)):
			var li := im.get_surface_lod_indices(s, l)
			if li.size() >= 3 and li.size() < best.size() and li.size() >= full * share * 0.6:
				best = li
		arr[Mesh.ARRAY_INDEX] = best
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(s, im.get_surface_material(s))
	return mesh


## Like bake, for token models whose glowing parts carry the meta "no_skin" (designs must
## not repaint them): skinnable parts and glowing parts become two separate meshes.
static func bake_split(root: Node3D, key: String, skip: Array = []) -> void:
	var all: Array[MeshInstance3D] = []
	_collect(root, skip, all)
	for glowing in [false, true]:
		var parts: Array[MeshInstance3D] = []
		for p in all:
			if is_instance_valid(p) and p.has_meta("no_skin") == glowing and p.get_child_count() == 0 and not String(p.name).begins_with("Baked"):
				parts.append(p)
		if parts.size() < 2:
			continue
		var k := "%s_%s" % [key, "g" if glowing else "s"]
		var mesh: Mesh = _cache.get(k)
		if mesh == null:
			mesh = _merge(root, parts)
			if mesh == null:
				continue
			_cache[k] = mesh
		for p in parts:
			p.get_parent().remove_child(p)
			p.free()
		var mi := MeshInstance3D.new()
		mi.name = "BakedGlow" if glowing else "Baked"
		mi.mesh = mesh
		if glowing:
			mi.set_meta("no_skin", true)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
