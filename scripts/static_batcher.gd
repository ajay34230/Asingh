class_name StaticBatcher
extends RefCounted
## Lag fix: the bazaar and hamlet are thousands of separate little meshes (one draw call each). This merges the
## ones that never move into a few big meshes per material and 24 m cell, then hides the originals (their
## colliders stay). Moving parts (doors, signs, animated or scripted things, transparent or shader materials,
## emissive materials that are changed at run time) are left alone.
## Plain-coloured (untextured) materials are merged further: their colour is baked into the vertices, so every
## plain surface in a cell with similar roughness shares one material and one draw call.

const CELL := 24.0
const SKIP_WORDS := ["door", "pivot", "leaf", "gate", "wheel", "flag", "cloth", "sign", "anim", "swing", "cart", "wagon", "lantern", "lamp", "glow", "flame", "fire", "trolley", "train", "engine", "coach", "loco", "boggie"]


static func _name_blocked(n: Node) -> bool:
	var l := String(n.name).to_lower()
	for w in SKIP_WORDS:
		if l.contains(w):
			return true
	return false


static func _ancestor_ok(mi: Node, root: Node) -> bool:
	var p := mi.get_parent()
	while p != null and p != root:
		if p.get_script() != null or not p.get_groups().is_empty() or _name_blocked(p):
			return false
		p = p.get_parent()
	return true


static func _flat_key(m: BaseMaterial3D) -> String:
	if m.albedo_texture != null or m.normal_enabled or m.emission_enabled or m.uv1_triplanar or m.roughness_texture != null \
			or m.metallic_texture != null or m.detail_enabled or m.albedo_color.a < 0.999:
		return ""
	return "flat|%d|%d|%d|%d" % [roundi(m.roughness * 4.0), roundi(m.metallic * 2.0), m.cull_mode, m.shading_mode]


static func _flat_material(m: BaseMaterial3D) -> StandardMaterial3D:
	var f := StandardMaterial3D.new()
	f.vertex_color_use_as_albedo = true
	f.vertex_color_is_srgb = true
	f.roughness = roundi(m.roughness * 4.0) / 4.0
	f.metallic = roundi(m.metallic * 2.0) / 2.0
	f.cull_mode = m.cull_mode
	f.shading_mode = m.shading_mode
	return f


## Appends one surface to a plain-colour bucket, its colour written into every vertex.
static func _append_flat(b: Dictionary, mesh: Mesh, s: int, xf: Transform3D, col: Color, use_vc: bool) -> bool:
	var arr: Array
	if mesh is PrimitiveMesh:
		arr = (mesh as PrimitiveMesh).get_mesh_arrays()
	else:
		if (mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return false
		arr = mesh.surface_get_arrays(s)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	if v.is_empty():
		return false
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var vc: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var base: int = (b["v"] as PackedVector3Array).size()
	var bv: PackedVector3Array = b["v"]
	var bn: PackedVector3Array = b["n"]
	var bc: PackedColorArray = b["c"]
	var bi: PackedInt32Array = b["i"]
	var nb := xf.basis.inverse().transposed()
	var flip := xf.basis.determinant() < 0.0
	for k in v.size():
		bv.append(xf * v[k])
		bn.append((nb * nrm[k]).normalized() if k < nrm.size() else Vector3.UP)
		bc.append(col * vc[k] if use_vc and k < vc.size() else col)
	if idx.is_empty():
		for k in v.size():
			bi.append(base + k)
	else:
		for k in idx.size():
			bi.append(base + idx[k])
	if flip:
		for t in range(bi.size() - (idx.size() if not idx.is_empty() else v.size()), bi.size(), 3):
			var tmp := bi[t + 1]
			bi[t + 1] = bi[t + 2]
			bi[t + 2] = tmp
	b["v"] = bv
	b["n"] = bn
	b["c"] = bc
	b["i"] = bi
	return true


static func _signature(m: BaseMaterial3D) -> String:
	return "%s|%.3f|%.3f|%d|%d|%d|%s|%s|%d" % [m.albedo_color.to_html(true), m.roughness, m.metallic, m.cull_mode, m.shading_mode,
		int(m.vertex_color_use_as_albedo), str(m.albedo_texture.get_instance_id()) if m.albedo_texture != null else "-",
		str(m.normal_texture.get_instance_id()) if m.normal_texture != null else "-", int(m.uv1_triplanar)]


## Returns {"merged": source meshes hidden, "batches": merged meshes created}.
static func merge(root: Node3D) -> Dictionary:
	var buckets := {}          # key -> {"mat": Material, "st": SurfaceTool, "verts": int}
	var order: Array = []
	var merged := 0
	var inv := root.global_transform.affine_inverse()
	var stack: Array[Node] = [root]
	var canon := {}            # signature -> Material
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.visible or mi.get_script() != null:
			continue
		if not (mi.mesh is ArrayMesh or mi.mesh is PrimitiveMesh) or not mi.get_groups().is_empty() or _name_blocked(mi):
			continue
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON or mi.visibility_range_end > 0.0 or mi.material_overlay != null or mi.layers != 1:
			continue
		var kids_ok := true
		for c in mi.get_children():
			if not (c is CollisionObject3D):
				kids_ok = false
		if not kids_ok or not _ancestor_ok(mi, root):
			continue
		var xf: Transform3D = inv * mi.global_transform
		var cell := Vector2i(floori(xf.origin.x / CELL), floori(xf.origin.z / CELL))
		var all_ok := true
		var mats: Array[Material] = []
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.material_override if mi.material_override != null else mi.mesh.surface_get_material(s)
			var bm := mat as BaseMaterial3D
			if bm == null or bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or bm.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or bm.next_pass != null:
				all_ok = false
				break
			if not bm.emission_enabled:
				var sig := _signature(bm)
				if not canon.has(sig):
					canon[sig] = bm
				mat = canon[sig]
			mats.append(mat)
		if not all_ok:
			continue
		for s in mi.mesh.get_surface_count():
			var mat2: Material = mats[s]
			var fb := mat2 as BaseMaterial3D
			var fk := _flat_key(fb) if fb != null and (mi.mesh is PrimitiveMesh or (mi.mesh as ArrayMesh).get_blend_shape_count() == 0) else ""
			if fk != "":
				var fkey := "%s_%d_%d" % [fk, cell.x, cell.y]
				if not buckets.has(fkey):
					buckets[fkey] = {"mat": _flat_material(fb), "flat": true, "v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
					order.append(fkey)
				if _append_flat(buckets[fkey], mi.mesh, s, xf, fb.albedo_color, fb.vertex_color_use_as_albedo):
					continue
			var key := "%d_%d_%d" % [mat2.get_instance_id(), cell.x, cell.y]
			if not buckets.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				buckets[key] = {"mat": mat2, "st": st, "verts": 0, "cell": cell}
				order.append(key)
			var b: Dictionary = buckets[key]
			(b["st"] as SurfaceTool).append_from(mi.mesh, s, xf)
			b["verts"] = int(b["verts"]) + 1
		mi.visible = false
		merged += 1
	var made := 0
	for key in order:
		var b2: Dictionary = buckets[key]
		var am: ArrayMesh
		if b2.has("flat"):
			if (b2["v"] as PackedVector3Array).is_empty():
				continue
			var arrs := []
			arrs.resize(Mesh.ARRAY_MAX)
			arrs[Mesh.ARRAY_VERTEX] = b2["v"]
			arrs[Mesh.ARRAY_NORMAL] = b2["n"]
			arrs[Mesh.ARRAY_COLOR] = b2["c"]
			arrs[Mesh.ARRAY_INDEX] = b2["i"]
			am = ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
			am.surface_set_material(0, b2["mat"] as Material)
		else:
			var st2: SurfaceTool = b2["st"]
			st2.set_material(b2["mat"] as Material)
			am = st2.commit()
		if am == null or am.get_surface_count() == 0:
			continue
		var out := MeshInstance3D.new()
		out.name = "Merged"
		out.mesh = am
		root.add_child(out)
		out.transform = Transform3D.IDENTITY
		made += 1
	return {"merged": merged, "batches": made}
