class_name LockMarker
extends Node3D
## Soft lock-on: a small red arrow over the nearest living enemy in front of the player.

var player: Player
var _label: Label3D
var _t := 0.0
var _bob := 0.0


func _ready() -> void:
	_label = Label3D.new()
	_label.text = "▼"
	_label.modulate = Color(1.0, 0.25, 0.2)
	_label.outline_size = 6
	_label.pixel_size = 0.012
	_label.font_size = 48
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.visible = false
	add_child(_label)


func _process(delta: float) -> void:
	_bob += delta
	_t -= delta
	if _t <= 0.0:
		_t = 0.12
		var e: Enemy = player._nearest_enemy(9.0) if player != null and not player.dead else null
		if e != null:
			_label.visible = true
			_label.set_meta("foe", e)
		else:
			_label.visible = false
			_label.remove_meta("foe")
	if _label.visible and _label.has_meta("foe"):
		var f: Variant = _label.get_meta("foe")
		if f == null or not is_instance_valid(f) or (f as Enemy).dead:
			_label.visible = false
			return
		_label.global_position = (f as Enemy).global_position + Vector3(0, 2.6 + sin(_bob * 5.0) * 0.1, 0)
