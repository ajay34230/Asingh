## Speech bubbles: a short caption that pops up above a token while it speaks, follows
## it, and fades out. Billboards always face the camera and draw over the board.
class_name SpeechBubbles
extends Node3D

const COLORS := {"red": Color("#ffb3b8"), "green": Color("#b8f5c8"), "yellow": Color("#fff0b0"), "blue": Color("#bcd6ff")}

var _bubbles: Array[Dictionary] = []


func say(target: Node3D, text: String, color: String, seconds := 1.7) -> void:
	if text == "" or not is_instance_valid(target):
		return
	## One bubble per speaker: a new line replaces the old one.
	for b in _bubbles:
		if b["target"] == target:
			(b["label"] as Node).queue_free()
	_bubbles = _bubbles.filter(func(b: Dictionary) -> bool: return b["target"] != target)
	## Someone else is talking now: older bubbles bow out quickly.
	for b in _bubbles:
		b["life"] = minf(float(b["life"]), float(b["age"]) + 0.3)
	var label := Label3D.new()
	label.text = text
	label.font_size = 72
	label.pixel_size = 0.0007
	label.fixed_size = true   ## same size on screen in wide shots and close-ups
	label.outline_size = 18
	label.modulate = COLORS.get(color, Color.WHITE)
	label.outline_modulate = Color(0.12, 0.02, 0.03, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.scale = Vector3.ZERO
	add_child(label)
	_bubbles.append({"target": target, "label": label, "age": 0.0, "life": seconds})


func _process(delta: float) -> void:
	for b in _bubbles:
		var label: Label3D = b["label"]
		var target: Node3D = b["target"]
		b["age"] = float(b["age"]) + delta
		var age: float = b["age"]
		var life: float = b["life"]
		if not is_instance_valid(target) or age > life:
			label.queue_free()
			continue
		label.global_position = target.global_position + Vector3(0, 0.95 + age * 0.08, 0)
		var pop := clampf(age / 0.18, 0.0, 1.0)
		var s := (1.0 + 0.25 * sin(pop * PI)) * pop
		label.scale = Vector3.ONE * s
		label.modulate.a = clampf((life - age) / 0.35, 0.0, 1.0)
	_bubbles = _bubbles.filter(func(b: Dictionary) -> bool:
		return is_instance_valid(b["target"]) and float(b["age"]) <= float(b["life"]))
