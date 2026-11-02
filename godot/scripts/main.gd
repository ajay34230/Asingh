## Main scene: the supplied Ludo board, a straight top-down camera, and a
## camera that fits the board to any screen without cropping it.
##
## Screenshot check (needs a display, e.g. xvfb-run):
##   godot --path . -- --screenshot=/tmp/board.png
extends Node3D

const BOARD_PATH := "res://assets/models/01_Board/Royal_India_Final_Ludo_Board.glb"
## Board footprint measured from the mesh: the frame is 12.46 m square, centred on the origin.
const BOARD_SIZE := 12.46
## Space kept free around the board for the HUD (fraction of the screen).
const SCREEN_MARGIN := 0.04

var camera: Camera3D
var board: Node3D


func _ready() -> void:
	_build_environment()
	board = (load(BOARD_PATH) as PackedScene).instantiate()
	board.name = "Board"
	add_child(board)
	camera = Camera3D.new()
	camera.name = "BoardCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.look_at_from_position(Vector3(0, 30, 0), Vector3.ZERO, Vector3(0, 0, -1))
	camera.near = 0.1
	camera.far = 100.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(camera)
	camera.make_current()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()

	var args := OS.get_cmdline_user_args()
	if "--grid" in args:
		_add_alignment_markers()
	for arg in args:
		if arg.begins_with("--screenshot="):
			_screenshot_and_quit(arg.trim_prefix("--screenshot="))


## Debug: marks every ring cell (small dot per team colour) and every courtyard
## spot, to check that the logical grid lines up with the supplied board.
func _add_alignment_markers() -> void:
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color("#ff00ff")
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color("#00ffff")
	base_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dot := SphereMesh.new()
	dot.radius = 0.12
	dot.height = 0.24
	for cell in BoardPath.ring():
		var m := MeshInstance3D.new()
		m.mesh = dot
		m.material_override = ring_mat
		m.position = BoardPath.to_world(cell.x + 0.5, cell.y + 0.5) + Vector3(0, 0.4, 0)
		add_child(m)
	for color in BoardPath.COLORS:
		for token in range(4):
			var p := BoardPath.base_spot(color, token)
			var m := MeshInstance3D.new()
			m.mesh = dot
			m.material_override = base_mat
			m.position = BoardPath.to_world(p.x, p.y) + Vector3(0, 0.4, 0)
			add_child(m)


## Orthographic size is the visible height. Choose the height that fits the
## board's width and height, whichever is the limit on this aspect ratio.
func _fit_camera() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var needed := BOARD_SIZE * (1.0 + SCREEN_MARGIN * 2.0)
	camera.size = maxf(needed, needed / aspect)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2a120c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff1d6")
	env.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.4
	sun.light_color = Color("#ffe7bf")
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)


func _screenshot_and_quit(path: String) -> void:
	for i in range(4):
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	print("saved " + path)
	get_tree().quit()
