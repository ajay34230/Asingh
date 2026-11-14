extends SceneTree
## Diagnostics: a picture of a character model from the front, the side and the back.
## Run with a display: godot --path . --script res://tools/render_model.gd -- <res path> <out.png>
func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var path := args[0]
	var out := args[1]
	var holder := Node3D.new()
	root.add_child(holder)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.22, 0.26)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.57, 0.62)
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	holder.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	holder.add_child(sun)
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 6)
	floor_m.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.32, 0.33, 0.36)
	floor_m.material_override = fm
	holder.add_child(floor_m)
	var ps := load(path) as PackedScene
	for i in 3:
		var m := ps.instantiate() as Node3D
		holder.add_child(m)
		m.position = Vector3(-2.2 + i * 2.2, 0, 0)
		m.rotation.y = [0.0, PI * 0.5, PI][i]
	var cam := Camera3D.new()
	holder.add_child(cam)
	cam.fov = 40
	cam.position = Vector3(0, 1.0, 7.6)
	cam.look_at(Vector3(0, 0.9, 0))
	cam.current = true
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("[render] saved ", out)
	quit()
