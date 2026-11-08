class_name Items
extends Node
## S1 + S4: a small item system. Counts live in story flags ("item_<id>") so they save with the game.
## Equipment changes the player's damage, reach and damage taken; consumables heal; recipes craft new items.

const DEFS := {
	"herb": {"name": "Healing herb", "type": "consumable", "heal": 25.0, "desc": "Heals 25."},
	"potion": {"name": "Healing potion", "type": "consumable", "heal": 70.0, "desc": "Heals 70."},
	"hide": {"name": "Hide", "type": "material", "desc": "Crafting material."},
	"iron": {"name": "Iron scrap", "type": "material", "desc": "Crafting material."},
	"fire_arrow": {"name": "Fire arrow", "type": "ammo", "desc": "Used on fully drawn, aimed shots: burns the target. Ghosts fear fire."},
	"oil": {"name": "Lamp oil", "type": "material", "desc": "Crafting material. Sold by the bazaar, dropped by raiders."},
	"essence": {"name": "Monster essence", "type": "material", "desc": "Dropped by ghosts and monsters. The blacksmith uses it to upgrade weapons."},
	"spear": {"name": "Spear", "type": "weapon", "dmg": 1.15, "reach": 0.7, "desc": "Longer reach."},
	"axe": {"name": "Axe", "type": "weapon", "dmg": 1.4, "reach": 0.0, "desc": "Heavy hits."},
	"bow": {"name": "Hunting bow", "type": "weapon", "dmg": 0.8, "reach": 0.0, "ranged": true, "desc": "Fires arrows at the nearest foe, even from the saddle. Arrows hurt ghosts twice as much."},
	"sword": {"name": "Talwar sword", "type": "weapon", "dmg": 1.55, "reach": 0.5, "desc": "Fast, sharp, and cuts through spirits."},
	"dagger": {"name": "Silver dagger", "type": "weapon", "dmg": 1.25, "reach": 0.0, "desc": "Quick strikes. Silver bites the restless dead."},
	"leather": {"name": "Leather armour", "type": "armour", "armor": 0.8, "desc": "Takes 20% less damage."},
	"chain": {"name": "Chain mail", "type": "armour", "armor": 0.62, "desc": "Takes 38% less damage."},
}

## recipe id -> [result, {ingredient: count}]
const RECIPES := {
	"potion": ["potion", {"herb": 3}],
	"spear": ["spear", {"iron": 2, "hide": 1}],
	"axe": ["axe", {"iron": 4}],
	"bow": ["bow", {"hide": 3, "iron": 1}],
	"sword": ["sword", {"iron": 6}],
	"dagger": ["dagger", {"iron": 3}],
	"leather": ["leather", {"hide": 4}],
	"chain": ["chain", {"iron": 8, "hide": 2}],
	"fire_arrow": ["fire_arrow", {"oil": 1, "hide": 1}, 5],
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
	if DEFS.has(id) and String(DEFS[id]["type"]) == "weapon" and count(id) == 0:
		# carried gear (quiver, scabbard) appears on the body once you own the weapon
		var wr := get_tree().get_first_node_in_group("wardrobe") if is_inside_tree() else null
		if wr != null:
			(func() -> void: wr.call("wear", String(wr.call("worn")))).call_deferred()
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
	if t == "weapon" and player != null and player.weapon != id:
		player.weapon = id                     # equipping from the menu also puts it in hand
		player._rig.set_weapon(id)
		story.set_flag("weapon_sel", id)
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
	player.gear_ranged = DEFS.has(w) and bool(DEFS[w].get("ranged", false))
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
	give(String(RECIPES[rid][0]), int(RECIPES[rid][2]) if RECIPES[rid].size() > 2 else 1)
	return true


## Random loot from a defeated enemy (called by Enemy): herbs often, iron and hides sometimes.
func loot(role: String, rng: RandomNumberGenerator) -> void:
	if role in Monster.KINDS:
		# monsters: essence for weapon upgrades (bosses drop a handful), sometimes iron
		var boss := bool(Monster.KINDS[role].get("boss", false))
		if boss:
			give("essence", 4)
			give("iron", 3)
		elif rng.randf() < 0.55:
			give("essence")
		elif rng.randf() < 0.3:
			give("iron")
		return
	var r := rng.randf()
	if r < 0.30:
		give("herb")
	elif r < 0.50:
		give("iron", 2 if role == "brute" else 1)
	elif r < 0.60 and role != "ambusher":
		give("hide")
	elif r < 0.72:
		give("oil")


## X17: give a herb to the nearest animal within 4 m. It calms it; three feedings earn an achievement.
func feed_nearest() -> bool:
	if player == null or count("herb") < 1:
		return false
	var best: Animal = null
	var bd := 4.0
	for a in get_tree().get_nodes_in_group("animals"):
		var an := a as Animal
		if an == null or an.dead:
			continue
		var d := an.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = an
	if best == null:
		return false
	take("herb", 1)
	best.feed()
	var n := int(story.get_flag("animals_fed", 0)) + 1
	story.set_flag("animals_fed", n)
	if hud != null:
		hud.banner(Loc.t("The animal trusts you a little more."), "")
	return true
