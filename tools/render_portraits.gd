extends SceneTree
## Portraits of the downloadable characters (head and shoulders, 256 px) and a full-body contact sheet.
## Run with a display: godot --path . --script res://tools/render_portraits.gd -- <glb dir> <portrait dir> <sheet.png>
func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var src: String = args[0]
	var out: String = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	var holder := Node3D.new()
	root.add_child(holder)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.13, 0.1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.58, 0.55)
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	holder.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.5, 0.5, 0)
	sun.light_energy = 1.4
	holder.add_child(sun)
	var cam := Camera3D.new()
	holder.add_child(cam)
	cam.current = true
	var files: Array = []
	for f in DirAccess.get_files_at(src):
		if f.ends_with(".glb"):
			files.append(f)
	files.sort()
	var full: Array = []
	for f in files:
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(src.path_join(f), st) != OK:
			print("[portrait] cannot read ", f)
			continue
		var m := doc.generate_scene(st) as Node3D
		holder.add_child(m)
		var aabb := AABB()
		var first := true
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var gi := mi as MeshInstance3D
			var bb := gi.global_transform * gi.get_aabb()
			aabb = bb if first else aabb.merge(bb)
			first = false
		var h := aabb.size.y
		var top := aabb.position + Vector3(aabb.size.x * 0.5, aabb.size.y, aabb.size.z * 0.5)
		# full body
		root.get_viewport().size = Vector2i(360, 640)
		cam.fov = 30.0
		cam.global_position = aabb.get_center() + Vector3(0, 0, h * 2.2)
		cam.look_at(aabb.get_center())
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		full.append([f.get_basename(), img])
		# head and shoulders
		root.get_viewport().size = Vector2i(256, 256)
		cam.fov = 30.0
		var face := top - Vector3(0, h * 0.13, 0)
		cam.global_position = face + Vector3(0, h * 0.02, h * 0.62)
		cam.look_at(face)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.path_join(f.get_basename() + ".png"))
		print("[portrait] ", f.get_basename(), " height ", snappedf(h, 0.01))
		m.queue_free()
		await process_frame
	# contact sheet
	var cols := 7
	var rows := int(ceil(full.size() / float(cols)))
	var sheet := Image.create(cols * 360, rows * 640, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.16, 0.13, 0.1))
	for i in full.size():
		var im: Image = full[i][1]
		im.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(im, Rect2i(0, 0, 360, 640), Vector2i((i % cols) * 360, (i / cols) * 640))
	sheet.save_png(args[2])
	print("[portrait] sheet ", args[2], " ", full.size())
	quit()
