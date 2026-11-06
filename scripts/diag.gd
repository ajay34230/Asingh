class_name Diag
extends Node
## Crash breadcrumbs and adaptive quality. Every few seconds the game writes where the player is, FPS and memory
## to user://breadcrumb.txt; a clean exit removes the marker file. If the marker is still there at the next launch,
## the previous run ended unexpectedly and the title screen shows the last breadcrumb so the cause can be traced.
## Also: if the frame rate stays low, the graphics preset is lowered one step automatically.

const CRUMB := "user://breadcrumb.txt"
const RUNNING := "user://running.flag"

var main: Node3D
var player: Player
var hud: Node
var previous_crash := ""
var _t := 0.0
var _low := 0.0
var _cool := 0.0
var _enabled := true


func _ready() -> void:
	if FileAccess.file_exists(RUNNING) and FileAccess.file_exists(CRUMB):
		previous_crash = FileAccess.get_file_as_string(CRUMB)
		LogCollector.record_crash(previous_crash)
	LogCollector.event("start " + LogCollector.device_info().replace("\n", " | "))
	var f := FileAccess.open(RUNNING, FileAccess.WRITE)
	if f != null:
		f.store_string("1")


func _notification(what: int) -> void:
	# leaving the app (home button, swipe away) is not a crash: only a run that dies while active keeps the flag
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE or what == NOTIFICATION_APPLICATION_PAUSED:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUNNING))
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		var f := FileAccess.open(RUNNING, FileAccess.WRITE)
		if f != null:
			f.store_string("1")


func summary() -> String:
	var pos := Vector3.ZERO
	if player != null and is_instance_valid(player):
		pos = player.global_position
	return "t=%d fps=%d pos=(%d,%d,%d) mem=%dMB vram=%dMB draws=%d nodes=%d quality=%d" % [
		int(Time.get_ticks_msec() / 1000), int(Engine.get_frames_per_second()), int(pos.x), int(pos.y), int(pos.z),
		int(OS.get_static_memory_usage() / 1048576), int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(GameSettings.v.get("quality", 0))]


func _process(delta: float) -> void:
	_t -= delta
	_cool -= delta
	if _t <= 0.0:
		_t = 3.0
		var f := FileAccess.open(CRUMB, FileAccess.WRITE)
		if f != null:
			f.store_string(summary())
	# adaptive quality: 8 s below 22 fps lowers the preset one step (at most once per 40 s)
	if player == null or player.locked or not _enabled:
		_low = 0.0
		return
	if Engine.get_frames_per_second() < 22:
		_low += delta
	else:
		_low = maxf(0.0, _low - delta * 2.0)
	var q := int(GameSettings.v.get("quality", 0))
	if _low > 8.0 and _cool <= 0.0 and q < 2:
		_low = 0.0
		_cool = 40.0
		GameSettings.set_value("quality", q + 1)
		LogCollector.event("low fps, quality lowered to %d (%s)" % [q + 1, summary()])
		if hud != null:
			hud.banner(Loc.t("Frame rate was low: graphics lowered a step."), "")


## Debug page: show or hide one part of the world, so a glitch can be pinned on it.
static func debug_toggle(main_node: Node, key: String, on: bool) -> void:
	if main_node == null or not main_node.is_inside_tree():
		return
	var tree := main_node.get_tree()
	match key:
		"dbg_rain":
			var atmo: Atmosphere = main_node.get("atmosphere") as Atmosphere
			if atmo != null:
				for pn in ["_rain_p", "_splash_p"]:
					var rp: Variant = atmo.get(pn)
					if rp != null:
						(rp as Node3D).visible = on
		"dbg_smoke":
			for n in tree.get_nodes_in_group("dbg_smoke"):
				(n as Node3D).visible = on
		"dbg_clouds":
			var c: Node = main_node.find_child("Clouds", true, false)
			if c != null:
				(c as Node3D).visible = on
		"dbg_foliage":
			for g in ["foliage_grass", "foliage_reeds", "foliage_palm", "foliage_stone"]:
				for n in tree.get_nodes_in_group(g):
					(n as Node3D).visible = on
		"dbg_lights":
			for n in main_node.find_children("*", "Light3D", true, false):
				if not (n is DirectionalLight3D):
					(n as Light3D).visible = on
		"dbg_people":
			for g in ["npcs", "animals"]:
				for n in tree.get_nodes_in_group(g):
					(n as Node3D).visible = on
		"dbg_terrain":
			var t: Node = main_node.get_node_or_null("Terrain")
			if t != null:
				(t as Node3D).visible = on
		"dbg_ruins":
			var ru: Node = main_node.get_node_or_null("Ruins")
			if ru != null:
				(ru as Node3D).visible = on
		"dbg_farm":
			var f: Node = main_node.get_node_or_null("Farm")
			if f != null:
				(f as Node3D).visible = on
