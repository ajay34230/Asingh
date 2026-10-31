class_name Hints
extends Node
## X21: short, skippable first-time tips. Each shows once (remembered in user://hints.json).

const PATH := "user://hints.json"
const TIPS := {
	"move": "Drag the left stick to walk. Push it fully to run.",
	"look": "Drag on the right side of the screen to look around.",
	"jump": "Tap JUMP to leap. Tap ATTACK while falling for a ground slam.",
	"fight": "Enemies near! Tap ATTACK to fight, BLOCK to guard, ROLL to dodge.",
	"mount": "Walk up to an animal and tap USE to ride it.",
	"map": "Open the map to tap a place and draw a route to it.",
}

var player: Player
var hud: Node
var shown := {}
var _t := 3.0
var _t_play := 0.0


func _ready() -> void:
	if FileAccess.file_exists(PATH):
		var d: Variant = JSON.parse_string(FileAccess.open(PATH, FileAccess.READ).get_as_text())
		if d is Dictionary:
			shown = d


func tip(id: String) -> bool:
	if shown.has(id) or not TIPS.has(id) or hud == null:
		return false
	shown[id] = true
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(shown))
	hud.banner(Loc.t(String(TIPS[id])), "")
	return true


func _process(delta: float) -> void:
	_t -= delta
	_t_play += delta
	if _t > 0.0 or player == null:
		return
	_t = 6.0                      # at most one tip every few seconds
	if _t_play > 4.0 and tip("move"):
		return
	if _t_play > 40.0 and tip("jump"):
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Node3D).global_position.distance_to(player.global_position) < 12.0:
			tip("fight")
			return
	for a in get_tree().get_nodes_in_group("animals"):
		if (a as Node3D).global_position.distance_to(player.global_position) < 3.5 and not player.mounted:
			tip("mount")
			return
