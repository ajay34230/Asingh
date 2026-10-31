class_name CompanionSystem
extends Node
## S3: Sher, a sellsword waiting by the inn. Hire him for 120 coins and he follows and fights beside you
## (Npc companion AI). He fights harder as trust grows, trust rises with every enemy that falls while he is with you.

const COST := 120
const NAME := "Sher"

var main: Node3D
var town: TownBuilder
var story: Story
var player: Player
var hud: Node
var npc: Npc
var it: Interactable
var trust := 0
var _t := 0.0


func build() -> void:
	add_to_group("companion_system")
	npc = Npc.new().setup(NpcBuilder.PRESETS["guard"], "idle", NAME)
	npc.player = player
	main.add_child(npc)
	var p: Vector3 = town.inn_pos + Vector3(5.0, 0.0, 5.0)
	p.y = main.get("terrain").sample_height(p.x, p.z) + 0.05
	npc.global_position = p
	main.npcs.append(npc)
	it = Interactable.new()
	it.position = Vector3(0, 1.1, 0)
	it.reach = 3.0
	npc.add_child(it)
	it.on_interact = func(_by: Node3D, _me: Interactable) -> void: toggle()
	trust = int(story.get_flag("sher_trust", 0))
	_refresh()


func is_hired() -> bool:
	return bool(story.get_flag("sher_hired", false))


func _refresh() -> void:
	npc.companion = is_hired()
	npc.companion_damage = 16.0 + minf(float(trust), 12.0) * 1.5
	it.prompt = ("Dismiss %s" % NAME) if is_hired() else ("Hire %s (%d coins)" % [NAME, COST])


func toggle() -> bool:
	if is_hired():
		story.set_flag("sher_hired", false)
		_refresh()
		hud.banner(Loc.t("Sher: Call me if you need a blade."), "")
		return true
	var coins := int(story.get_flag("coins", 0))
	if coins < COST:
		hud.banner(Loc.t("Sher: 120 coins, friend. Not a coin less."), "")
		return false
	story.set_flag("coins", coins - COST)
	story.set_flag("sher_hired", true)
	_refresh()
	hud.banner(Loc.t("Sher: Lead on. I have your back."), "")
	return true


## Called when any enemy dies: trust grows while Sher is along.
func note_kill() -> void:
	if not is_hired():
		return
	trust += 1
	story.set_flag("sher_trust", trust)
	_refresh()
	if trust == 5:
		hud.banner(Loc.t("Sher trusts you. He strikes harder now."), "")


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	if npc != null and npc.companion != is_hired():   # restore after loading a save
		_refresh()
