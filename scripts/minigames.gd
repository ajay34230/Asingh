class_name MiniGames
extends Node3D
## X26/X28: two bazaar pastimes. (1) Chausar dice with Imran at the tea square: bet coins, higher roll wins.
## (2) The Arena (opens once the story is finished as the bonus mode; also open from the start in practice):
## endless waves of mixed fighters, coins for each wave cleared, best wave remembered.

const DICE_C := Vector3(22.0, 0.0, -42.0)
var main: Node3D
var story: Story
var player: Player
var hud: Node
var dlg: DialogueUI
var combat: CombatBuilder
var terrain: TerrainBuilder
var town: TownBuilder
var dice_npc: Npc
var arena_it: Interactable
var wave := 0
var active := false
var _t := 0.0
var _rng := RandomNumberGenerator.new()
const ROLES := ["grunt", "shield", "archer", "brute", "ambusher"]


func build() -> void:
	add_to_group("minigames")
	_rng.randomize()
	var pr: Dictionary = (NpcBuilder.PRESETS["trader"] as Dictionary).duplicate()
	dice_npc = Npc.new().setup(pr, "idle", "Imran the dice player")
	dice_npc.player = player
	main.add_child(dice_npc)
	var p := Vector3(DICE_C.x - 14.0, 0.0, DICE_C.z + 10.0)
	p.y = terrain.sample_height(p.x, p.z) + 0.05
	dice_npc.global_position = p
	main.npcs.append(dice_npc)
	var it := Interactable.new()
	it.position = Vector3(0, 1.1, 0)
	it.prompt = "Play Chausar dice"
	it.reach = 3.2
	dice_npc.add_child(it)
	it.on_interact = func(_by: Node3D, _me: Interactable) -> void: open_dice()
	# arena marker: a ring of stones in the open ground beside the town
	var stone := PropFactory.stone(Color(0.6, 0.52, 0.4))
	var ap := Vector3(DICE_C.x + 32.0, 0.0, DICE_C.z + 28.0)
	ap.y = terrain.sample_height(ap.x, ap.z)
	var ring := Node3D.new()
	ring.name = "ArenaRing"
	add_child(ring)
	ring.global_position = ap
	for i in 16:
		var a := i * TAU / 16.0
		PropFactory.box(ring, Vector3(1.0, 1.2, 1.0), Vector3(cos(a) * 10.0, 0.6, sin(a) * 10.0), stone, Vector3.ZERO, false, false)
	arena_it = Interactable.new()
	arena_it.position = Vector3(0, 1.2, 0)
	arena_it.reach = 4.0
	ring.add_child(arena_it)
	arena_it.on_interact = func(_by: Node3D, _me: Interactable) -> void: start_arena()
	_refresh()


func arena_center() -> Vector3:
	var c := get_node("ArenaRing") as Node3D
	return c.global_position


func _refresh() -> void:
	var best := int(story.get_flag("arena_best", 0))
	arena_it.prompt = "Enter the Arena (best wave %d)" % best if not active else "Arena in progress"
	arena_it.enabled = not active


# --- dice ----------------------------------------------------------------------------------

func roll2() -> int:
	return _rng.randi_range(1, 6) + _rng.randi_range(1, 6)


## One round. Returns "win", "lose" or "tie" and moves the coins.
func dice_round(bet: int, mine: int = -1, theirs: int = -1) -> String:
	var coins := int(story.get_flag("coins", 0))
	if coins < bet:
		return "broke"
	if mine < 0:
		mine = roll2()
	if theirs < 0:
		theirs = roll2()
	var res: String = "tie"
	if mine > theirs:
		res = "win"
		story.set_flag("coins", coins + bet)
	elif mine < theirs:
		res = "lose"
		story.set_flag("coins", coins - bet)
	story.set_flag("dice_last", "%d-%d" % [mine, theirs])
	return res


func open_dice(msg: String = "") -> void:
	var coins := int(story.get_flag("coins", 0))
	var text := msg if msg != "" else Loc.t("Chausar! Two dice each, highest total wins. Care to wager, traveller?")
	var ch := []
	for bet in [10, 50]:
		ch.append({"t": "Bet %d coins" % bet, "go": "", "set": {"dice_bet": bet}})
	ch.append({"t": "Walk away", "go": ""})
	var nodes := {"a": {"who": "Imran the trader", "text": text + " (" + Loc.t("Coins") + ": %d)" % coins, "choices": ch}}
	story.set_flag("dice_bet", 0)
	dlg.open({"start": "a", "nodes": nodes}, dice_npc, "man", func() -> void:
		var bet := int(story.get_flag("dice_bet", 0))
		if bet > 0:
			story.set_flag("dice_bet", 0)
			var r := play_bet(bet)
			var last: String = String(story.get_flag("dice_last", ""))
			var line: String = {"win": Loc.t("You rolled higher! You win."), "lose": Loc.t("My dice win this round."), "tie": Loc.t("A tie!"), "broke": Loc.t("You cannot cover that bet.")}[r]
			open_dice.call_deferred(line + " [" + last + "]"))


## Used by the dialogue-free path (and the selftest): play one round and report it on the HUD.
func play_bet(bet: int) -> String:
	var r := dice_round(bet)
	var last := String(story.get_flag("dice_last", ""))
	match r:
		"win":
			hud.banner(Loc.t("You rolled higher! +%d coins (%s)") % [bet, last], "")
		"lose":
			hud.banner(Loc.t("Imran's dice win. -%d coins (%s)") % [bet, last], "")
		"tie":
			hud.banner(Loc.t("A tie. The coins stay put (%s)") % last, "")
		_:
			hud.banner(Loc.t("Not enough coins for that bet."), "")
	return r


# --- arena ---------------------------------------------------------------------------------

func start_arena() -> bool:
	if active:
		return false
	active = true
	wave = 0
	story.set_flag("arena_down", 0)
	_next_wave()
	_refresh()
	return true


func _next_wave() -> void:
	wave += 1
	var n := 2 + wave
	var c := arena_center()
	hud.banner(Loc.t("ARENA - Wave %d") % wave, "raid_panic")
	for k in n:
		var a: float = k * TAU / float(n) + wave * 0.5
		var p := c + Vector3(cos(a) * 7.0, 0.5, sin(a) * 7.0)
		p.y = terrain.sample_height(p.x, p.z) + 0.5
		var e := combat.spawn_enemy(p, false, 40.0, "arena")
		e.apply_role(ROLES[(k + wave) % ROLES.size()])
		e.hp *= 1.0 + 0.12 * float(wave - 1)
		e.max_hp = e.hp


func arena_alive() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).get_meta("tag", "") == "arena":
			n += 1
	return n


func end_arena(reason: String) -> void:
	if not active:
		return
	active = false
	if wave - 1 > int(story.get_flag("arena_best", 0)):
		story.set_flag("arena_best", wave - 1)
	hud.banner(Loc.t("Arena over: you cleared %d waves.") % maxi(0, wave - 1), "")
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).get_meta("tag", "") == "arena":
			(e as Node).queue_free()
	_refresh()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	if not active:
		return
	if player.dead or player.global_position.distance_to(arena_center()) > 45.0:
		end_arena("left")
		return
	if arena_alive() == 0:
		var reward := 20 * wave
		story.set_flag("coins", int(story.get_flag("coins", 0)) + reward)
		hud.banner(Loc.t("Wave cleared! +%d coins") % reward, "seal_found")
		_next_wave()
