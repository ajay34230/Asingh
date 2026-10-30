class_name StoryLinks
extends Node
## Ties the side missions into the main Sun-Queen story: the Sun-Hammer (Dhruv re-forges it with
## the Queen's light), the Sand Circuit as Ila's midsummer festival race, the Sun Pennant won there,
## and the temple altar that reveals who paid the Reavers.

var main: Node3D
var story: Story
var hud: QuestHUD
var cin: Cinematic
var player: Player
var terrain: TerrainBuilder
var race: RaceBuilder
var _hammer := false
var _won := false
var _blessed := false
var _ledger := false


func _init(m: Node3D, s: Story, h: QuestHUD, c: Cinematic, p: Player, t: TerrainBuilder, r: RaceBuilder) -> void:
	main = m
	story = s
	hud = h
	cin = c
	player = p
	terrain = t
	race = r
	name = "StoryLinks"


func build() -> void:
	main.add_child(self)
	_hammer = story.get_flag("sun_hammer")
	_won = story.get_flag("race_won")
	_blessed = story.get_flag("temple_blessed")
	_ledger = story.get_flag("ledger_given")
	player.hammer_mult = 1.4 if _hammer else 1.0
	story.changed.connect(_on_changed)
	_altar_pennant()


func _on_changed() -> void:
	var h: bool = story.get_flag("sun_hammer")
	if h and not _hammer:
		_hammer = true
		player.hammer_mult = 1.4
		hud.banner("SUN-HAMMER FORGED  (+40% damage)", "seal_found")
		Sfx.sting("discovery")
		StoryFX.sun_burst(main, player.global_position + Vector3(0, 0.8, 0), 1.0)
		StoryFX.shake(player, 0.1, 0.5)
	var w: bool = story.get_flag("race_won")
	if w and not _won:
		_won = true
		call_deferred("_victory_scene")
	var lg: bool = story.get_flag("ledger_given")
	if lg and not _ledger:
		_ledger = true
		story.add("coins", 120)
		hud.banner("LEDGER DELIVERED  +120 coins", "seal_found")
		Sfx.sting("reveal")
	var b: bool = story.get_flag("temple_blessed")
	if b and not _blessed:
		_blessed = true


func _victory_scene() -> void:
	main.atmosphere.set_weather("clear", 300.0)
	StoryFX.sun_burst(main, player.global_position + Vector3(0, 1.0, 0), 1.3)
	StoryFX.shake(player, 0.18, 0.6)
	hud.banner("SUN PENNANT EARNED", "mission_new")
	var rm: Node3D = story.refs.get("racemaster")
	if rm == null:
		return
	var pp := player.global_position
	var shots := [
		{"from": pp + Vector3(6, 4, 6), "to": pp + Vector3(3, 2.4, 3), "look": pp + Vector3(0, 1.2, 0), "dur": 3.0, "sfx": "chime"},
		{"from": rm.global_position + Vector3(2, 1.8, 3), "to": rm.global_position + Vector3(1, 1.7, 2), "look": rm.global_position + Vector3(0, 1.6, 0), "dur": 5.0,
		 "who": "Race Master Bhim", "voice": "deep", "text": "Take the Sun Pennant. Ila flew it from her own chariot, and the twelve rays on it match the mural in the old temple."},
		{"from": rm.global_position + Vector3(2, 1.8, 3), "look": rm.global_position + Vector3(0, 1.6, 0), "dur": 5.5,
		 "who": "Race Master Bhim", "voice": "deep", "text": "And one more thing. Karan's riders paid for their bulls with fresh coins stamped with the council's sun. Those are minted here, in this valley. Show the pennant at the temple altar; the old priests kept a record."},
	]
	cin.play(shots, "THE SUN PENNANT", func() -> void:
		story.set_flag("clue_coins", true)
		Sfx.sting("reveal")
		hud.banner("CLUE: the Reavers' gold was minted in the valley", "reveal"))


## A second altar interaction: place the pennant. Reveals the mural and rewards the player.
func _altar_pennant() -> void:
	var c := TerrainBuilder.TEMPLE_C
	var it := Interactable.new()
	it.position = Vector3(c.x + 1.6, terrain.temple_y + 1.4, c.y - 6.0)
	it.prompt = "Place the Sun Pennant"
	it.reach = 6.0
	it.on_interact = func(by: Node3D, _me: Interactable) -> void:
		if story.get_flag("temple_blessed"):
			(by as Player).say("The twelve rays of the mural glow softly. The pennant stands in the altar.")
			return
		if not story.get_flag("race_won"):
			(by as Player).say("A hollow on the altar, shaped for a pennant staff. The Race Master may know more.")
			return
		_blessing_scene()
	main.add_child(it)


func _blessing_scene() -> void:
	main.atmosphere.set_weather("drizzle", 90.0)        # a soft sacred rain while the altar wakes
	var c := TerrainBuilder.TEMPLE_C
	var at := Vector3(c.x, terrain.temple_y + 3.0, c.y - 4.0)
	var shots := [
		{"from": at + Vector3(8, 2.0, 10), "to": at + Vector3(2, 1.2, 4), "look": at, "dur": 3.5},
		{"from": at + Vector3(3, 1.5, 4), "to": at + Vector3(0, 3.0, 5), "look": at + Vector3(0, 1.0, 0), "dur": 5.0, "sfx": "temple_bell",
		 "who": "Narrator", "text": "The pennant slides into the altar. Twelve rays of light climb the mural, and the old plaster remembers."},
		{"from": at + Vector3(0, 3.0, 5), "look": at + Vector3(0, 1.8, 0), "dur": 6.0,
		 "who": "Narrator", "text": "Beneath the sun is a row of pressed coins, each with the council's mark. The Reavers' gold left this valley's own treasury."},
		{"from": at + Vector3(0, 3.0, 5), "to": at + Vector3(-4, 2.5, 8), "look": at + Vector3(-1, 1.2, 0), "dur": 6.5,
		 "who": "Pandit Rishi", "voice": "old", "text": "The full record is in the old ledger, kept at the forest shrine. My scribe Tara went for it at dawn, and she has not returned. The forest road is no place to be alone. Please find her."},
	]
	cin.play(shots, "THE TEMPLE REMEMBERS", func() -> void:
		StoryFX.sun_burst(main, at, 1.6)
		StoryFX.shake(player, 0.12, 0.6)
		story.set_flag("temple_blessed", true)
		player.heal(player.max_hp)
		player.apply_powerup("power")
		Sfx.sting("victory", -4.0)
		hud.banner("SUN'S BLESSING: health restored, power surge", "powerup"))
