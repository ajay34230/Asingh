class_name MapUI
extends CanvasLayer
## Guiding map: a small north-up minimap (tap it to open) and a full-screen map with landmarks,
## NPCs, mission markers and the player arrow. The terrain picture is rendered once from the
## height field (hill-shaded, no extra assets).

const HALF := TerrainBuilder.HALF
const TEX := 320
const MINI := 220.0
const MINI_RADIUS_M := 55.0

var terrain: TerrainBuilder
var player: Player
var story: Story
var main: Node3D
var tex: ImageTexture
var _mini: Control
var _full: Control
var _btn: Button
var landmarks := [
	["Sun Gate", Vector2(0, -168)], ["Village", Vector2(-90, 12)], ["Goods yard", Vector2(-20, 96)],
	["Caravan", Vector2(47, 45)], ["Arin's office", Vector2(92, 150)], ["Dig site", Vector2(-95, 25)],
]


func _ready() -> void:
	layer = 7
	tex = _render_terrain()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_mini = Control.new()
	_mini.anchor_left = 1.0
	_mini.anchor_right = 1.0
	_mini.offset_left = -MINI - 16.0
	_mini.offset_right = -16.0
	_mini.offset_top = 92.0
	_mini.offset_bottom = 92.0 + MINI
	_mini.clip_contents = true
	_mini.mouse_filter = Control.MOUSE_FILTER_STOP
	_mini.draw.connect(_draw_mini)
	_mini.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			toggle_full())
	root.add_child(_mini)
	_full = Control.new()
	_full.set_anchors_preset(Control.PRESET_FULL_RECT)
	_full.mouse_filter = Control.MOUSE_FILTER_STOP
	_full.visible = false
	_full.draw.connect(_draw_full)
	_full.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed):
			toggle_full())
	root.add_child(_full)
	_btn = Button.new()
	_btn.text = "Map"
	_btn.add_theme_font_size_override("font_size", 26)
	_btn.anchor_left = 1.0
	_btn.anchor_right = 1.0
	_btn.offset_left = -340
	_btn.offset_right = -262
	_btn.offset_top = 14
	_btn.offset_bottom = 76
	_btn.pressed.connect(toggle_full)
	root.add_child(_btn)


func toggle_full() -> void:
	_full.visible = not _full.visible
	Sfx.ui("page_turn", -6.0)


func _process(_d: float) -> void:
	_mini.queue_redraw()
	if _full.visible:
		_full.queue_redraw()


# --- terrain picture --------------------------------------------------------------------------

func _render_terrain() -> ImageTexture:
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGB8)
	var step := HALF * 2.0 / TEX
	for j in TEX:
		for i in TEX:
			var x := -HALF + (i + 0.5) * step
			var z := -HALF + (j + 0.5) * step
			var h := terrain.sample_height(x, z)
			var hx := terrain.sample_height(x + step, z) - terrain.sample_height(x - step, z)
			var hz := terrain.sample_height(x, z + step) - terrain.sample_height(x, z - step)
			var shade := clampf(0.78 - (hx * 0.9 + hz * 0.6) * 0.08, 0.35, 1.15)
			var t := clampf((h + 2.0) / 40.0, 0.0, 1.0)
			var base := Color(0.86, 0.74, 0.52).lerp(Color(0.62, 0.46, 0.30), t).lerp(Color(0.55, 0.50, 0.46), clampf((h - 28.0) / 40.0, 0.0, 1.0))
			if absf(x - terrain.river_x(z)) < 5.0 and h < 3.0:
				base = Color(0.52, 0.42, 0.33)        # dry riverbed
			img.set_pixel(i, j, Color(base.r * shade, base.g * shade, base.b * shade))
	return ImageTexture.create_from_image(img)


func _w2u(p: Vector3) -> Vector2:     # world -> 0..1 map coordinates
	return Vector2((p.x + HALF) / (HALF * 2.0), (p.z + HALF) / (HALF * 2.0))


# --- markers ---------------------------------------------------------------------------------

func _objectives() -> Array:
	return story.active_objectives(4) if story != null else []


func _arrow(c: CanvasItem, at: Vector2, yaw: float, size: float) -> void:
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(-fwd.y, fwd.x)
	var pts := PackedVector2Array([at + fwd * size, at - fwd * size * 0.7 + right * size * 0.65, at - fwd * size * 0.35, at - fwd * size * 0.7 - right * size * 0.65])
	c.draw_colored_polygon(pts, Color(1, 1, 1))
	c.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.1, 0.1, 0.1), 2.0)


func _diamond(c: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
	c.draw_colored_polygon(pts, col)
	c.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.1, 0.05, 0.0), 2.0)


func _draw_mini() -> void:
	if tex == null or player == null:
		return
	var p := player.global_position
	var u := _w2u(p)
	var half_u := MINI_RADIUS_M / (HALF * 2.0)
	var src := Rect2((u.x - half_u) * TEX, (u.y - half_u) * TEX, half_u * 2.0 * TEX, half_u * 2.0 * TEX)
	_mini.draw_rect(Rect2(Vector2.ZERO, Vector2(MINI, MINI)), Color(0.08, 0.06, 0.04))
	_mini.draw_texture_rect_region(tex, Rect2(Vector2.ZERO, Vector2(MINI, MINI)), src)
	var scale := MINI / (MINI_RADIUS_M * 2.0)
	var centre := Vector2(MINI, MINI) * 0.5
	for n in main.npcs:
		var d := Vector2(n.global_position.x - p.x, n.global_position.z - p.z) * scale
		if absf(d.x) < MINI * 0.5 - 4.0 and absf(d.y) < MINI * 0.5 - 4.0:
			_mini.draw_circle(centre + d, 4.0, Color(0.35, 0.85, 1.0))
	for e in get_tree().get_nodes_in_group("enemies"):
		var d2 := Vector2(e.global_position.x - p.x, e.global_position.z - p.z) * scale
		if absf(d2.x) < MINI * 0.5 - 4.0 and absf(d2.y) < MINI * 0.5 - 4.0:
			_mini.draw_circle(centre + d2, 4.5, Color(1.0, 0.2, 0.15))
	for o in _objectives():
		var t: Vector3 = o["target"]
		if t == Vector3.ZERO:
			continue
		var d3 := Vector2(t.x - p.x, t.z - p.z) * scale
		var lim := MINI * 0.5 - 10.0
		if absf(d3.x) > lim or absf(d3.y) > lim:
			d3 = d3 * (lim / maxf(absf(d3.x), absf(d3.y)))
		_diamond(_mini, centre + d3, 8.0, Color(1.0, 0.82, 0.25))
		break
	_arrow(_mini, centre, player.look_yaw(), 11.0)
	_mini.draw_rect(Rect2(Vector2.ZERO, Vector2(MINI, MINI)), Color(0.9, 0.7, 0.3), false, 4.0)
	_mini.draw_string(ThemeDB.fallback_font, Vector2(MINI * 0.5 - 5, 20), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.9))


func _draw_full() -> void:
	var vp := _full.get_viewport_rect().size
	_full.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.04, 0.03, 0.94))
	var side := minf(vp.x - 40.0, vp.y - 120.0)
	var origin := Vector2((vp.x - side) * 0.5, 80.0)
	_full.draw_texture_rect(tex, Rect2(origin, Vector2(side, side)), false)
	_full.draw_rect(Rect2(origin, Vector2(side, side)), Color(0.9, 0.7, 0.3), false, 4.0)
	var font := ThemeDB.fallback_font
	_full.draw_string(font, Vector2(origin.x, 56), "Valley of Sands (tap to close)", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.95, 0.74, 0.32))
	for lm in landmarks:
		var w: Vector2 = lm[1]
		var q := origin + _w2u(Vector3(w.x, 0, w.y)) * side
		_full.draw_rect(Rect2(q - Vector2(6, 6), Vector2(12, 12)), Color(0.35, 0.2, 0.1))
		_full.draw_rect(Rect2(q - Vector2(6, 6), Vector2(12, 12)), Color(1, 0.9, 0.7), false, 2.0)
		_full.draw_string(font, q + Vector2(10, -8), lm[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1))
	for n in main.npcs:
		_full.draw_circle(origin + _w2u(n.global_position) * side, 4.0, Color(0.35, 0.85, 1.0))
	for e in get_tree().get_nodes_in_group("enemies"):
		_full.draw_circle(origin + _w2u(e.global_position) * side, 5.0, Color(1.0, 0.2, 0.15))
	var idx := 1
	for o in _objectives():
		var t: Vector3 = o["target"]
		if t == Vector3.ZERO:
			continue
		var q2 := origin + _w2u(t) * side
		_diamond(_full, q2, 11.0, Color(1.0, 0.82, 0.25))
		_full.draw_string(font, q2 + Vector2(-5, 7), str(idx), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.1, 0.05, 0))
		idx += 1
	_arrow(_full, origin + _w2u(player.global_position) * side, player.look_yaw(), 14.0)
	# legend
	var ly := origin.y + side + 28.0
	_full.draw_circle(Vector2(origin.x + 10, ly - 6), 5, Color(0.35, 0.85, 1.0))
	_full.draw_string(font, Vector2(origin.x + 24, ly), "people", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	_diamond(_full, Vector2(origin.x + 150, ly - 6), 8.0, Color(1.0, 0.82, 0.25))
	_full.draw_string(font, Vector2(origin.x + 166, ly), "mission goal", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	_full.draw_circle(Vector2(origin.x + 330, ly - 6), 5, Color(1.0, 0.2, 0.15))
	_full.draw_string(font, Vector2(origin.x + 344, ly), "enemies", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
