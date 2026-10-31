class_name Items
extends Node
## S1 + S4: a small item system. Counts live in story flags ("item_<id>") so they save with the game.
## Equipment changes the player's damage, reach and damage taken; consumables heal; recipes craft new items.

const DEFS := {
	"herb": {"name": "Healing herb", "type": "consumable", "heal": 25.0, "desc": "Heals 25."},
	"potion": {"name": "Healing potion", "type": "consumable", "heal": 70.0, "desc": "Heals 70."},
	"hide": {"name": "Hide", "type": "material", "desc": "Crafting material."},
	"iron": {"name": "Iron scrap", "type": "material", "desc": "Crafting material."},
	"spear": {"name": "Spear", "type": "weapon", "dmg": 1.15, "reach": 0.7, "desc": "Longer reach."},
	"axe": {"name": "Axe", "type": "weapon", "dmg": 1.4, "reach": 0.0, "desc": "Heavy hits."},
	"leather": {"name": "Leather armour", "type": "armour", "armor": 0.8, "desc": "Takes 20% less damage."},
	"chain": {"name": "Chain mail", "type": "armour", "armor": 0.62, "desc": "Takes 38% less damage."},
}

## recipe id -> [result, {ingredient: count}]
const RECIPES := {
	"potion": ["potion", {"herb": 3}],
	"spear": ["spear", {"iron": 2, "hide": 1}],
	"axe": ["axe", {"iron": 4}],
	"leather": ["leather", {"hide": 4}],
	"chain": ["chain", {"iron": 8, "hide": 2}],
}

var story: Story
var player: Player
var hud: Node


func _ready() -> void:
	add_to_group("items")
	# the hides you already hunted count as crafting material
	if story != null and int(story.get_flag("hides", 0)) > 0 and count("hide") == 0:
		give("hide", int(story.get_flag("hides", 0)))
	apply_gear()


func count(id: String) -> int:
	return int(story.get_flag("item_" + id, 0))


func give(id: String, n: int = 1) -> void:
	if not DEFS.has(id):
		return
	story.set_flag("item_" + id, count(id) + n)
	if hud != null:
		hud.banner("+ %d %s" % [n, Loc.t(String(DEFS[id]["name"]))], "")


func take(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	story.set_flag("item_" + id, count(id) - n)
	return true


func equipped(slot: String) -> String:
	return String(story.get_flag("eq_" + slot, ""))


func equip(id: String) -> bool:
	if not DEFS.has(id) or count(id) < 1:
		return false
	var t: String = DEFS[id]["type"]
	if t != "weapon" and t != "armour":
		return false
	story.set_flag("eq_" + t, id)
	apply_gear()
	return true


func unequip(slot: String) -> void:
	story.set_flag("eq_" + slot, "")
	apply_gear()


func apply_gear() -> void:
	if player == null:
		return
	var w: String = equipped("weapon")
	var a: String = equipped("armour")
	player.gear_dmg = float(DEFS[w]["dmg"]) if DEFS.has(w) else 1.0
	player.gear_reach = float(DEFS[w]["reach"]) if DEFS.has(w) else 0.0
	player.armor_mult = float(DEFS[a]["armor"]) if DEFS.has(a) else 1.0


func use(id: String) -> bool:
	if not DEFS.has(id) or DEFS[id]["type"] != "consumable" or player == null or player.dead:
		return false
	if player.hp >= player.max_hp:
		return false
	if not take(id):
		return false
	player.heal(float(DEFS[id]["heal"]))
	return true


func can_craft(rid: String) -> bool:
	if not RECIPES.has(rid):
		return false
	var need: Dictionary = RECIPES[rid][1]
	for k in need:
		if count(String(k)) < int(need[k]):
			return false
	return true


func craft(rid: String) -> bool:
	if not can_craft(rid):
		return false
	var need: Dictionary = RECIPES[rid][1]
	for k in need:
		take(String(k), int(need[k]))
	give(String(RECIPES[rid][0]))
	return true


## Random loot from a defeated enemy (called by Enemy): herbs often, iron and hides sometimes.
func loot(role: String, rng: RandomNumberGenerator) -> void:
	var r := rng.randf()
	if r < 0.30:
		give("herb")
	elif r < 0.50:
		give("iron", 2 if role == "brute" else 1)
	elif r < 0.60 and role != "ambusher":
		give("hide")
