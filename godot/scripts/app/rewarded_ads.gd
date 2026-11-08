## "Watch a video" rewards.
##
## The game is offline today, so no ad network is linked. A real one (for example an
## AdMob Android plugin) plugs in by setting `provider` to an object with:
##     is_ready() -> bool
##     show_rewarded(done: Callable)   # done.call(true) only when the video was finished
## Until then, debug builds play a clearly labelled 6-second TEST video so the whole
## unlock flow can be tried, and release builds hide the video option.
class_name RewardedAds
extends RefCounted

const TEST_SECONDS := 6.0

static var provider: Object = null
static var force_test := false   ## tests: show the test video even in release builds


static func available() -> bool:
	if provider and provider.has_method("is_ready"):
		return bool(provider.call("is_ready"))
	return OS.is_debug_build() or force_test


## Plays a video over `parent`; `done` gets true when the player watched to the end.
static func show(parent: Node, done: Callable) -> void:
	if provider and provider.has_method("show_rewarded"):
		provider.call("show_rewarded", done)
		return
	if not available():
		done.call(false)
		return
	_test_video(parent, done)


static func _test_video(parent: Node, done: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.92)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.theme = RoyalTheme.build()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := Label.new()
	title.text = TranslationServer.translate("Test video")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", RoyalTheme.GOLD_LIGHT)
	box.add_child(title)
	var note := Label.new()
	note.text = TranslationServer.translate("Real video ads play here once an ad network is linked.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 20)
	box.add_child(note)
	var bar := ProgressBar.new()
	bar.max_value = TEST_SECONDS
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 22)
	var fill := StyleBoxFlat.new()
	fill.bg_color = RoyalTheme.GOLD
	fill.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 56)
	box.add_child(button)
	var state := {"start": Time.get_ticks_msec(), "finished": false, "closed": false}
	var finish := func(rewarded: bool) -> void:
		if state["closed"]:
			return
		state["closed"] = true
		layer.queue_free()
		done.call(rewarded)
	button.pressed.connect(func() -> void: finish.call(state["finished"]))
	button.text = TranslationServer.translate("Close (no reward)")
	## Counts real elapsed time (not timer ticks, which slow down at low frame rates),
	## also while the game is paused behind the menu.
	var tick := func() -> void:
		if state["finished"] or state["closed"]:
			return
		var t := (Time.get_ticks_msec() - int(state["start"])) / 1000.0
		bar.value = t
		if t >= TEST_SECONDS:
			state["finished"] = true
			button.text = TranslationServer.translate("Collect reward")
	var timer := Timer.new()
	timer.wait_time = 0.05
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.timeout.connect(tick)
	layer.add_child(timer)
	timer.start()
