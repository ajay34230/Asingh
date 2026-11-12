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
static func bake(root: Node3D, key: String, skip: Array = [], shadows := true) -> MeshInstance3D:
	var cached: Mesh = _cache.get(key) if key != "" else null
	var parts: Array[MeshInstance3D] = []
	_collect(root, skip, parts)
	var mesh: Mesh = cached
	if mesh == null:
		mesh = _merge(root, parts)
		if key != "" and mesh != null:
			_cache[key] = mesh
	for p in parts:   # the originals are no longer needed
		if is_instance_valid(p) and p.get_parent() != null:
			p.get_parent().remove_child(p)
			p.free()
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = "Baked"
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
	var out := ArrayMesh.new()
	for mat in order:
		var g: Dictionary = groups[mat]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = g["v"]
		arr[Mesh.ARRAY_NORMAL] = g["n"]
		arr[Mesh.ARRAY_TEX_UV] = g["uv"]
		arr[Mesh.ARRAY_INDEX] = g["i"]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return out
