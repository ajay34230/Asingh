extends SceneTree
## Turns the Mixamo character downloads in res://mixamo_src/heroes/ (FBX, "With Skin") into small .glb files for
## download in the game: no animation, textures shrunk (colour 1024 px, normal map 512 px, the rest dropped),
## plus a 256 px portrait. Output: OUT_DIR (set by the first user argument).
## Run: godot --headless --path . --script res://tools/convert_heroes.gd -- <out dir>

const SRC := "res://mixamo_src/heroes/"


func _shrink(tex: Texture2D, size: int) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	var s := maxi(img.get_width(), img.get_height())
	if s > size:
		var k := float(size) / float(s)
		img.resize(maxi(4, int(img.get_width() * k)), maxi(4, int(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	img.clear_mipmaps()
	return ImageTexture.create_from_image(img)


func _init() -> void:
	await process_frame
	var out_dir: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	for f in DirAccess.get_files_at(SRC):
		if not f.ends_with(".fbx"):
			continue
		var id := f.get_basename()
		var inst := (load(SRC + f) as PackedScene).instantiate() as Node3D
		root.add_child(inst)
		for ap in inst.find_children("*", "AnimationPlayer", true, false):
			ap.get_parent().remove_child(ap)
			ap.free()
		var mats := 0
		var tris := 0
		var nsurf := 0
		for m0 in inst.find_children("*", "MeshInstance3D", true, false):
			if (m0 as MeshInstance3D).mesh != null:
				nsurf += (m0 as MeshInstance3D).mesh.get_surface_count()
		var big := nsurf >= 4                     # many separate textures: half the size each
		var only := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else ""
		if only != "" and not id in only.split(","):
			inst.queue_free()
			continue
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(s)
				tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arr[Mesh.ARRAY_INDEX] != null else 0
				var mat := mi.get_active_material(s) as StandardMaterial3D
				if mat == null:
					continue
				mat = mat.duplicate() as StandardMaterial3D
				mat.albedo_texture = _shrink(mat.albedo_texture, 512 if big else 1024)
				mat.normal_texture = null if big else _shrink(mat.normal_texture, 512)
				mat.normal_enabled = mat.normal_texture != null
				if mat.emission_enabled and mat.emission_texture != null:
					mat.emission_texture = _shrink(mat.emission_texture, 512)
				mat.roughness_texture = null
				mat.metallic_texture = null
				mat.ao_texture = null
				mat.ao_enabled = false
				mat.metallic = 0.0
				mat.roughness = maxf(mat.roughness, 0.6)
				mi.mesh.surface_set_material(s, mat)
				mi.set_surface_override_material(s, null)
				mats += 1
		# some downloads number the rig ("mixamorig2_Hips"): one name for all
		for skn in inst.find_children("*", "Skeleton3D", true, false):
			var sk0 := skn as Skeleton3D
			for bi in sk0.get_bone_count():
				var bn := sk0.get_bone_name(bi)
				var re := RegEx.create_from_string("^mixamorig[0-9]+_")
				if re.search(bn) != null:
					sk0.set_bone_name(bi, re.sub(bn, "mixamorig_"))
			# the skins bind by bone name too, so rename those the same way
			for mn in inst.find_children("*", "MeshInstance3D", true, false):
				var sn := (mn as MeshInstance3D).skin
				if sn == null:
					continue
				var re2 := RegEx.create_from_string("^mixamorig[0-9]+_")
				for bi in sn.get_bind_count():
					var bn2 := String(sn.get_bind_name(bi))
					if re2.search(bn2) != null:
						sn.set_bind_name(bi, StringName(re2.sub(bn2, "mixamorig_")))
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		doc.append_from_scene(inst, st)
		var path := out_dir.path_join(id + ".glb")
		var err := doc.write_to_filesystem(st, path)
		var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0] if not inst.find_children("*", "Skeleton3D", true, false).is_empty() else null
		if sk != null and sk.find_bone("mixamorig_Hips") < 0:
			var names: PackedStringArray = []
			for bi in mini(sk.get_bone_count(), 8):
				names.append(sk.get_bone_name(bi))
			print("[hero]   %s bones start: %s" % [id, ", ".join(names)])
		var aabb := AABB()
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			aabb = aabb.merge((m as MeshInstance3D).get_aabb()) if aabb.size != Vector3.ZERO else (m as MeshInstance3D).get_aabb()
		print("[hero] %-12s err %d  %6.1f KB  materials %d  triangles %d  bones %d  hips %s" % [id, err, FileAccess.get_file_as_bytes(path).size() / 1024.0, mats, tris, sk.get_bone_count() if sk != null else 0, str(sk.find_bone("mixamorig_Hips")) if sk != null else "-"])
		inst.queue_free()
		await process_frame
	quit()
