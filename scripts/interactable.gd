class_name Interactable
extends Node3D
## Marks a spot in the world the player can use when standing within `reach` metres and
## facing it. Gameplay code sets `on_interact` (a Callable taking the player and this node)
## and may change `prompt` at any time (for example "Open door" / "Close door").
## Phase 2 only provides the mechanism plus a few neutral test interactions; no story content.

signal interacted(by: Node3D)

var prompt := "Interact"
var reach := 2.5
var enabled := true
var on_interact := Callable()


func _ready() -> void:
	add_to_group("interactables")


func interact(by: Node3D) -> void:
	if not enabled:
		return
	if on_interact.is_valid():
		on_interact.call(by, self)
	interacted.emit(by)
