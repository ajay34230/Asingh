## Scenery merging (MeshMerge.bake_static): the merged mesh must hold exactly the triangles
## of the parts it replaced, sit in the same place, skip hidden and excluded parts, keep
## shadow-less parts shadow-less, and offer smaller meshes for lower graphics quality.
## Needs a real renderer (meshes are empty under --headless):
##   xvfb-run -a godot --rendering-driver opengl3 --path godot --script tests/merge_test.gd
extends SceneTree

var _fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)


func _tris(mesh: Mesh) -> int:
	return mesh.get_faces().size() / 3


func _part(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	m.scale = scl
	parent.add_child(m)
	return m


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var root := Node3D.new()
	get_root().add_child(root)
	var red := StandardMaterial3D.new()
	var blue := StandardMaterial3D.new()
	var box := BoxMesh.new()
	var ball := SphereMesh.new()
	var expected := 0
	for i in range(6):
		_part(root, box, red, Vector3(i * 2.0, 0, 0))
		expected += _tris(box)
	_part(root, ball, blue, Vector3(0, 3, 0), Vector3(2, 2, 2))
	_part(root, ball, blue, Vector3(4, 3, 0), Vector3(-1, 1, 1))     # mirrored part
	expected += _tris(ball) * 2
	var flat := _part(root, box, red, Vector3(0, 0, 5))
	flat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flat2 := _part(root, box, blue, Vector3(2, 0, 5))
	flat2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hidden := _part(root, box, red, Vector3(0, 9, 0))
	hidden.visible = false
	var kept := Node3D.new()
	root.add_child(kept)
	_part(kept, box, red, Vector3(0, 0, -5))
	_part(kept, box, red, Vector3(2, 0, -5))
	var out := MeshMerge.bake_static(root, "", [kept], true)
	_check(out.size() == 2, "two merged meshes (shadow and flat), got %d" % out.size())
	var lit: MeshInstance3D = root.get_node_or_null("BakedStatic_shadow")
	var unlit: MeshInstance3D = root.get_node_or_null("BakedStatic_flat")
	_check(lit != null and unlit != null, "merged nodes exist")
	if lit and unlit:
		_check(_tris(lit.mesh) == expected, "triangles kept: %d of %d" % [_tris(lit.mesh), expected])
		_check(lit.mesh.get_surface_count() == 2, "one surface per material")
		_check(_tris(unlit.mesh) == _tris(box) * 2, "flat parts merged separately")
		_check(unlit.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "flat mesh casts no shadow")
		var box_aabb := lit.mesh.get_aabb()
		_check(absf(box_aabb.position.x + 1.0) < 0.01 and absf(box_aabb.end.x - 10.5) < 0.01, "merged mesh keeps its place: %s" % box_aabb)
		_check(absf(box_aabb.end.y - 4.0) < 0.01, "scaled part keeps its size")
		var meshes: Dictionary = lit.get_meta("detail_meshes", {})
		_check(meshes.has("low") and meshes.has("medium") and meshes.has("high"), "three detail levels")
		if meshes.has("low"):
			_check(_tris(meshes["low"]) <= _tris(meshes["medium"]) and _tris(meshes["medium"]) <= _tris(meshes["high"]), "lower quality is never heavier")
			_check(_tris(meshes["low"]) < _tris(meshes["high"]), "low quality has fewer triangles (%d vs %d)" % [_tris(meshes["low"]), _tris(meshes["high"])])
		MeshMerge.apply_detail(self, "low")
		_check(lit.mesh == meshes.get("low"), "apply_detail swaps the mesh")
		MeshMerge.apply_detail(self, "high")
		_check(lit.mesh == meshes.get("high"), "apply_detail restores full detail")
	_check(is_instance_valid(hidden) and hidden.mesh != null, "hidden part left alone")
	_check(kept.get_child_count() == 2, "excluded branch left alone")
	var left := 0
	for c in root.get_children():
		if c is MeshInstance3D and not String(c.name).begins_with("BakedStatic"):
			left += 1
	_check(left == 1, "original parts removed (only the hidden one stays), %d left" % left)
	print("MERGE TEST PASS" if _fails == 0 else "MERGE TEST FAIL (%d)" % _fails)
	quit(1 if _fails > 0 else 0)
