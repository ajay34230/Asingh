extends SceneTree
func _init() -> void:
	await process_frame
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(OS.get_cmdline_user_args()[0], st)
	var m := doc.generate_scene(st) as Node3D
	root.add_child(m)
	await process_frame
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var gi := mi as MeshInstance3D
		for si in gi.mesh.get_surface_count():
			var mt := gi.mesh.surface_get_material(si) as StandardMaterial3D
			if mt != null:
				print("[glb]   mat %s transp %d alpha %.2f tex %s cull %d" % [mt.resource_name, mt.transparency, mt.albedo_color.a, str(mt.albedo_texture != null), mt.cull_mode])
		print("[glb] mesh %s skin %s aabb %s global %s vis %s surfaces %d" % [gi.name, str(gi.skin != null), str(gi.get_aabb()), str(gi.global_transform.origin), str(gi.visible), gi.mesh.get_surface_count()])
	for sk in m.find_children("*", "Skeleton3D", true, false):
		var s := sk as Skeleton3D
		var h := s.find_bone("mixamorig_Hips")
		var hd := s.find_bone("mixamorig_Head")
		print("[glb] skeleton scale %s hips %s head %s" % [str(s.global_transform.basis.get_scale()), str(s.global_transform * s.get_bone_global_pose(h).origin) if h >= 0 else "-", str(s.global_transform * s.get_bone_global_pose(hd).origin) if hd >= 0 else "-"])
	quit()
