class_name Story
extends Node
## Story state, missions and dialogue for The Lost Kingdom (Act 1: "The Sun Gate").
## Pure data and rules: no scene building here (see StoryBuilder) and no UI (DialogueUI, QuestHUD).
##
## Premise: you are an archaeologist who arrives in the Valley of Sands, where your mentor
## Dr. Arin Rao has vanished at the Sun Gate, the sealed entrance to the legendary kingdom of
## Suryavan. Three Sun-Seals hidden among the valley's people open it. Everything here is
## original writing for this game.

signal changed                      # any flag changed (missions refresh)
signal mission_event(kind: String, text: String)   # "new", "update", "done"

var flags: Dictionary = {}
var refs: Dictionary = {}           # name -> Node3D / Vector3, filled by StoryBuilder
var quests: Array = []
var _announced: Dictionary = {}

const SEALS := ["seal_forge", "seal_rail", "seal_well"]


func _init() -> void:
	_define_quests()


func get_flag(k: String, d: Variant = false) -> Variant:
	return flags.get(k, d)


func set_flag(k: String, v: Variant = true) -> void:
	if flags.get(k, null) == v:
		return
	flags[k] = v
	changed.emit()


func add(k: String, n: int = 1) -> int:
	flags[k] = int(flags.get(k, 0)) + n
	changed.emit()
	return flags[k]


func seals_held() -> int:
	var n := 0
	for s in SEALS:
		if get_flag(s):
			n += 1
	return n


# --- missions ------------------------------------------------------------------------------

func _pos(key: String) -> Vector3:
	var r: Variant = refs.get(key)
	if r is Node3D and is_instance_valid(r):
		return (r as Node3D).global_position
	if r is Vector3:
		return r
	return Vector3.ZERO


func _nearest_rivet(from: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var bd := INF
	for r in refs.get("rivets", []):
		if is_instance_valid(r) and (r as Node3D).visible:
			var d := (r as Node3D).global_position.distance_to(from)
			if d < bd:
				bd = d
				best = (r as Node3D).global_position
	return best


func _define_quests() -> void:
	quests = [
		{
			"id": "arin", "title": "Where is Arin?",
			"blurb": "Dr. Arin Rao, your mentor, has been missing for three days. Start where he left off.",
			"show": func() -> bool: return true,
			"objs": [
				{"text": func() -> String: return "Search Arin's desk in the field office",
				 "done": func() -> bool: return get_flag("journal"), "target": func() -> Vector3: return _pos("desk")},
				{"text": func() -> String: return "Study the map table",
				 "done": func() -> bool: return get_flag("map"), "target": func() -> Vector3: return _pos("map")},
				{"text": func() -> String: return "Speak to Chief Bhairav in the village",
				 "done": func() -> bool: return get_flag("met_chief"), "target": func() -> Vector3: return _pos("Chief")},
			],
		},
		{
			"id": "seals", "title": "The Three Sun-Seals",
			"blurb": "Queen Ila hid three Sun-Seals among her people. Find them all.",
			"show": func() -> bool: return get_flag("met_chief"),
			"objs": [
				{"text": func() -> String:
					if not get_flag("forge_asked"):
						return "Hammer-Seal: talk to Dhruv the blacksmith"
					if int(get_flag("rivets", 0)) < 3:
						return "Hammer-Seal: find Dhruv's lost rivets (%d/3)" % int(get_flag("rivets", 0))
					return "Hammer-Seal: bring the rivets back to Dhruv",
				 "done": func() -> bool: return get_flag("seal_forge"),
				 "target": func() -> Vector3:
					if get_flag("forge_asked") and int(get_flag("rivets", 0)) < 3:
						return _nearest_rivet(_pos("player"))
					return _pos("Blacksmith")},
				{"text": func() -> String:
					if not get_flag("rail_talk"):
						return "Rail-Seal: talk to Mohan at the goods yard"
					return "Rail-Seal: open the crate marked LOT 7 in the goods train",
				 "done": func() -> bool: return get_flag("seal_rail"),
				 "target": func() -> Vector3: return _pos("RailWorker") if not get_flag("rail_talk") else _pos("crate")},
				{"text": func() -> String:
					if not get_flag("well_riddle"):
						return "Water-Seal: talk to Elder Kamla by the well"
					return "Water-Seal: dig at the stake with the red cloth",
				 "done": func() -> bool: return get_flag("seal_well"),
				 "target": func() -> Vector3: return _pos("Elder") if not get_flag("well_riddle") else _pos("dig")},
			],
		},
		{
			"id": "gate", "title": "The Sun Gate",
			"blurb": "With all three seals, the gate at the end of the valley will answer.",
			"show": func() -> bool: return seals_held() >= 3,
			"objs": [
				{"text": func() -> String: return "Carry the seals to the Sun Gate at the great stairs",
				 "done": func() -> bool: return get_flag("gate_open"), "target": func() -> Vector3: return _pos("gate")},
			],
		},
	]
	quests.append({
		"id": "lantern", "title": "The Lantern Trail",
		"blurb": "A lantern glows beyond the opened gate. Light the three lanterns of the Queen's road and find out what Arin discovered.",
		"show": func() -> bool: return get_flag("gate_open"),
		"objs": [
			{"text": func() -> String: return "Speak to Dr. Arin Rao at the Sun Gate",
			 "done": func() -> bool: return get_flag("arin_met"), "target": func() -> Vector3: return _pos("Arin")},
			{"text": func() -> String: return "Light the Queen's lanterns (%d/3)" % int(get_flag("lanterns", 0)),
			 "done": func() -> bool: return int(get_flag("lanterns", 0)) >= 3, "target": func() -> Vector3: return _nearest_lantern(_pos("player"))},
			{"text": func() -> String: return "Return to Arin",
			 "done": func() -> bool: return get_flag("arin_done"), "target": func() -> Vector3: return _pos("Arin")},
		],
	})

	quests.append({
		"id": "shards", "title": "Side: Sun-Pattern Shards",
		"blurb": "Meera the weaver studies the old twelve-rayed sun pattern. She needs six fragments of painted pottery from around the valley.",
		"show": func() -> bool: return get_flag("met_chief"),
		"objs": [
			{"text": func() -> String: return "Speak to Meera the weaver",
			 "done": func() -> bool: return get_flag("shards_ask"), "target": func() -> Vector3: return _pos("Weaver")},
			{"text": func() -> String: return "Find painted pottery shards (%d/6)" % int(get_flag("shards", 0)),
			 "done": func() -> bool: return int(get_flag("shards", 0)) >= 6, "target": func() -> Vector3: return _nearest("shards", _pos("player"))},
			{"text": func() -> String: return "Bring the shards to Meera",
			 "done": func() -> bool: return get_flag("shards_done"), "target": func() -> Vector3: return _pos("Weaver")},
		],
	})
	quests.append({
		"id": "cow", "title": "Side: The Lost Cow",
		"blurb": "Hari the farmer lost a cow in the western dunes. Find her before the night comes.",
		"show": func() -> bool: return get_flag("met_chief"),
		"objs": [
			{"text": func() -> String: return "Speak to Hari the farmer",
			 "done": func() -> bool: return get_flag("cow_ask"), "target": func() -> Vector3: return _pos("Farmer")},
			{"text": func() -> String: return "Find the lost cow in the western dunes",
			 "done": func() -> bool: return get_flag("cow_found"), "target": func() -> Vector3: return _pos("lostcow")},
			{"text": func() -> String: return "Tell Hari she is safe",
			 "done": func() -> bool: return get_flag("cow_done"), "target": func() -> Vector3: return _pos("Farmer")},
		],
	})
	quests.append({
		"id": "letter", "title": "Side: Anita's Letter",
		"blurb": "Anita has a letter for the merchant at the caravan station. She cannot make the long walk herself.",
		"show": func() -> bool: return get_flag("met_chief"),
		"objs": [
			{"text": func() -> String: return "Speak to Anita near the weaver's house",
			 "done": func() -> bool: return get_flag("letter_ask"), "target": func() -> Vector3: return _pos("VillagerGreen")},
			{"text": func() -> String: return "Deliver the letter to the merchant at the caravan station",
			 "done": func() -> bool: return get_flag("letter_delivered"), "target": func() -> Vector3: return _pos("Merchant")},
			{"text": func() -> String: return "Bring the merchant's reply to Anita",
			 "done": func() -> bool: return get_flag("letter_done"), "target": func() -> Vector3: return _pos("VillagerGreen")},
		],
	})


func _nearest(key: String, from: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var bd := INF
	for l in refs.get(key, []):
		if is_instance_valid(l):
			var d: float = from.distance_to((l as Node3D).global_position)
			if d < bd:
				bd = d
				best = (l as Node3D).global_position
	return best


func _nearest_lantern(from: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var bd := INF
	for l in refs.get("lanterns", []):
		if is_instance_valid(l):
			var d: float = from.distance_to((l as Node3D).global_position)
			if d < bd:
				bd = d
				best = (l as Node3D).global_position
	return best


## Mark every currently visible/finished mission as already announced (used after loading a save).
func silence() -> void:
	for q in quests:
		var id: String = q["id"]
		if (q["show"] as Callable).call():
			_announced["new_" + id] = true
		if quest_done(q) and (q["show"] as Callable).call():
			_announced["done_" + id] = true


## Visible, unfinished objectives as [{text, target}] for the tracker (max `limit`).
func active_objectives(limit: int = 4) -> Array:
	var out: Array = []
	for q in quests:
		if not (q["show"] as Callable).call():
			continue
		for o in q["objs"]:
			if not (o["done"] as Callable).call():
				out.append({"quest": q["title"], "text": (o["text"] as Callable).call(), "target": (o["target"] as Callable).call()})
		if out.size() >= limit:
			break
	return out


func quest_done(q: Dictionary) -> bool:
	for o in q["objs"]:
		if not (o["done"] as Callable).call():
			return false
	return true


## Call after state changes: emits "new" / "done" events once per mission.
func refresh() -> void:
	for q in quests:
		var id: String = q["id"]
		if (q["show"] as Callable).call() and not _announced.has("new_" + id):
			_announced["new_" + id] = true
			mission_event.emit("new", q["title"])
		if quest_done(q) and (q["show"] as Callable).call() and not _announced.has("done_" + id):
			_announced["done_" + id] = true
			mission_event.emit("done", q["title"])


# --- dialogue ------------------------------------------------------------------------------
# Node format: id -> {who, text, set: {flag: value}, add: {flag: n}, sfx: name,
#                     choices: [{t, go, set, add, if: flag}], go: next_id}  ("" = end)

func dialogue_for(who: String) -> Dictionary:
	match who:
		"Guide": return _guide()
		"Chief": return _chief()
		"Blacksmith": return _blacksmith()
		"RailWorker": return _railworker()
		"Elder": return _elder()
		"Arin": return _arin()
		"desk": return _journal()
		"map": return _map()
		"YardWorker": return _small("Salim", ["Mohan knows the goods yard better than the rails know him. Ask him.", "Heavy crates, light pay. Mind the dock ramp, friend."])
		"Trader": return _small("Imran the trader", ["Salt, thread, rope: the road brings everything but rain.", "The caravan will be gone by dusk. Buy now, regret later!", "Dr. Rao bought four coils of rope from me. Strange for a man who studies old stones."])
		"Merchant": return _merchant()
		"MerchantOld": return _small("Merchant", ["A scholar vanishes, and suddenly everyone wants maps. Business is good, sadly.", "I saw Dr. Rao's lantern at the ruins three nights ago. Then no more."])
		"Weaver": return _weaver()
		"WeaverOld": return _small("Meera the weaver", ["Look at this pattern: a sun with twelve rays. It was my grandmother's, and her mother's.", "The twelve-rayed sun. Funny; the old disc in Dhruv's forge has the same mark."])
		"VillagerGreen": return _anita()
		"VillagerGreenOld": return _small("Anita", ["Dr. Rao taught my son to read the old letters. Bring him back safe.", "At night the stairs glow, like a lamp left burning. I do not look."])
		"Farmer": return _hari()
		"FarmerOld": return _small("Hari the farmer", ["No rain for months. The barley is a prayer, not a crop.", "They say the Queen's kingdom drank the sun. I say it left none for us."])
		"Villager": return _small("Villager", ["Quiet day. Quiet days are the best days.", "My goats came back from the ruins yesterday, trembling. Goats know."])
		"Villager2": return _small("Raju", ["I carried Dr. Rao's bags once. He tipped me with a story about a golden gate.", "If you go to the gate, take water. And a friend."])
		"Villager3": return _small("Old Lakshmi", ["I remember when the well still sang. Child, listen to the old people about it.", "Kamla knows. Kamla always knows."])
		"Villager4": return _small("Pinky", ["Are you a treasure hunter? Dr. Rao said he was not, but he always smiled when I asked.", "Race you to the well! ...no? Fine."])
		"Traveller": return _small("Traveller", ["I came for the legend. I stayed for the silence. Be careful, friend.", "The wind sings at the stairs. Different from other winds."])
	return {}


func _small(name_: String, lines: Array) -> Dictionary:
	var nodes := {}
	for i in lines.size():
		nodes["n%d" % i] = {"who": name_, "text": lines[i],
			"choices": [{"t": "Tell me more.", "go": "n%d" % ((i + 1) % lines.size())}, {"t": "Thank you. Farewell.", "go": ""}]}
	return {"start": "n%d" % (absi(hash(name_)) % lines.size()), "nodes": nodes}


func _guide() -> Dictionary:
	var n := {
		"first": {"who": "Kabir", "text": "Namaste! You must be the one Dr. Rao was expecting. I am Kabir; I brought your message up the road. Three days now, and the lamp in his window still burns. Go inside. Read what he left.",
			"set": {"met_guide": true}, "choices": [
				{"t": "Where did he go?", "go": "where"}, {"t": "I'll look at his office.", "go": ""}]},
		"where": {"who": "Kabir", "text": "To the great stairs at dusk, alone, with a lantern and his notebook. He never came down. The desk will tell you more than I can.",
			"choices": [{"t": "Understood.", "go": ""}]},
		"office": {"who": "Kabir", "text": "The field office is the hut just up the slope. His desk first, then the map table. Take your time; I will watch the camp.",
			"choices": [{"t": "Thank you, Kabir.", "go": ""}]},
		"village": {"who": "Kabir", "text": "Now find the villagers. Old Bhairav, the chief, knows this valley better than any map. He lives by the well, to the west.",
			"choices": [{"t": "On my way.", "go": ""}]},
		"seals": {"who": "Kabir", "text": "Three seals, three keepers. I have carried travellers across these dunes for ten years, and I will say this: never walk the valley at night.",
			"choices": [{"t": "Noted.", "go": ""}]},
		"gate": {"who": "Kabir", "text": "You have them all? Then the gate is waiting, at the end of the valley, up the great stairs. Go well. I will keep the lamp lit.",
			"choices": [{"t": "Thank you for everything.", "go": ""}]},
	}
	var s := "first"
	if get_flag("met_guide"):
		s = "office"
		if get_flag("journal") and get_flag("map"):
			s = "village"
		if get_flag("met_chief"):
			s = "seals"
		if seals_held() >= 3:
			s = "gate"
	return {"start": s, "nodes": n}


func _journal() -> Dictionary:
	var n := {
		"p1": {"who": "Arin's journal", "sfx": "page_turn", "text": "Day 41. The Sun Gate is real. I have stood before it: twelve metres of carved sandstone, sealed by three discs of gold-bronze, set into the stone like eyes.",
			"go": "p2"},
		"p2": {"who": "Arin's journal", "sfx": "page_turn", "text": "The legend says Queen Ila sealed her kingdom to save it from a drought that would have emptied the valley. She hid the seals among her people: the one who shapes fire, the one who carries loads, the one who keeps the water.",
			"go": "p3"},
		"p3": {"who": "Arin's journal", "sfx": "page_turn", "text": "I traced all three. The forge in the village. A crate the railway company hauled away in 1923, never collected from the goods yard. And the old well, dry not for lack of water but because someone sealed its heart.",
			"go": "p4"},
		"p4": {"who": "Arin's journal", "sfx": "page_turn", "text": "If you are reading this, I did not come back from the gate in time. Do not come alone into the dark. Bring the seals. Trust Bhairav. And do not trust the lamplight you will see moving inside the ruins at night. Those lamps are not mine. A.",
			"set": {"journal": true}, "choices": [{"t": "Close the journal.", "go": ""}]},
		"done": {"who": "Arin's journal", "text": "The journal lies open at the last page: 'Bring the seals. Trust Bhairav.' His handwriting is steady, which is somehow worse.",
			"choices": [{"t": "Close the journal.", "go": ""}]},
	}
	return {"start": "done" if get_flag("journal") else "p1", "nodes": n}


func _map() -> Dictionary:
	var n := {
		"m1": {"who": "The map table", "sfx": "page_turn", "text": "A hand-drawn map of the valley, weighed down with stones. Three red circles: FORGE in the west village, THE WELL at its heart, GOODS YARD along the iron road to the south.",
			"go": "m2"},
		"m2": {"who": "The map table", "text": "At the top, a gate drawn in careful ink with a single line beneath it: 'Open at first light, with all three.' A fourth circle has been scratched out so hard it tore the paper.",
			"set": {"map": true}, "choices": [{"t": "Step back from the table.", "go": ""}]},
		"done": {"who": "The map table", "text": "Forge, well, goods yard, gate. Three seals to gather, then the stairs. The scratched-out circle still bothers you.",
			"choices": [{"t": "Step back from the table.", "go": ""}]},
	}
	return {"start": "done" if get_flag("map") else "m1", "nodes": n}


func _chief() -> Dictionary:
	var n := {
		"intro": {"who": "Chief Bhairav", "text": "Welcome, stranger. You wear the road's dust the way Rao did. Yes, I knew him. He sat at my fire for weeks, asking about queens and wells.",
			"set": {"met_chief": true}, "choices": [
				{"t": "Where is he now?", "go": "where"}, {"t": "What do you know of the seals?", "go": "seals"}]},
		"where": {"who": "Chief Bhairav", "text": "At the Sun Gate, three nights ago. Since then the ruins glow after dark, and no man here dares climb the stairs.",
			"choices": [{"t": "What do you know of the seals?", "go": "seals"}, {"t": "I will find him.", "go": "end"}]},
		"seals": {"who": "Chief Bhairav", "text": "Three discs, older than my grandfather's grandfather's name. Dhruv's forge keeps one. The goods yard holds another, shipped off like freight. And Kamla guards the secret of the well. Tell each of them that Bhairav sends you.",
			"choices": [{"t": "I will find all three.", "go": "end"}, {"t": "Why help me?", "go": "why"}]},
		"why": {"who": "Chief Bhairav", "text": "Because this village has kept that gate shut for centuries, and kept silent about why. Rao asked the right questions. I would like to hear you ask better ones.",
			"choices": [{"t": "I will find all three.", "go": "end"}]},
		"end": {"who": "Chief Bhairav", "text": "Go with care. Speak to Dhruv at the forge, Mohan at the goods yard, and Kamla by the well.",
			"choices": [{"t": "Farewell, Chief.", "go": ""}]},
		"again": {"who": "Chief Bhairav", "text": "Dhruv at the forge. Mohan at the goods yard. Kamla by the well. Do not leave the valley without all three.",
			"choices": [{"t": "I will return.", "go": ""}]},
		"ready": {"who": "Chief Bhairav", "text": "You carry the sun in your hands. The stairs are at the north end of the valley. Open the gate at first light if you can; the old stories say it is kinder then.",
			"choices": [{"t": "Thank you, Chief.", "go": ""}]},
		"after": {"who": "Chief Bhairav", "text": "The gate stands open. Whatever happens next, you have already done what we could not do in a hundred years.",
			"choices": [{"t": "Thank you, Chief.", "go": ""}]},
	}
	var s := "intro"
	if get_flag("met_chief"):
		s = "again"
		if seals_held() >= 3:
			s = "ready"
		if get_flag("gate_open"):
			s = "after"
	return {"start": s, "nodes": n}


func _blacksmith() -> Dictionary:
	var n := {
		"first": {"who": "Dhruv the blacksmith", "text": "Mind the sparks! ...Bhairav sent you? Then you want the sun-disc. Hah. It sits in my strongbox, and the strongbox is bolted with three rivets I lost when the cart tipped last week. They are scattered across my yard.",
			"choices": [{"t": "I will find your rivets.", "go": "ok", "set": {"forge_asked": true}},
				{"t": "Why does a blacksmith hold the seal?", "go": "why"}]},
		"why": {"who": "Dhruv the blacksmith", "text": "My family has hammered that disc back into shape once a century, since the Queen's day. Duty, not gold. Now: the rivets.",
			"choices": [{"t": "I will find your rivets.", "go": "ok", "set": {"forge_asked": true}}]},
		"ok": {"who": "Dhruv the blacksmith", "text": "Look for the glint of iron in the sand around the yard. Three of them. Small, dull, easily lost, like most good things.",
			"choices": [{"t": "Back soon.", "go": ""}]},
		"wait": {"who": "Dhruv the blacksmith", "text": "Three rivets, friend. Iron glints in the sand around my yard. You have found %d so far.",
			"choices": [{"t": "Still looking.", "go": ""}]},
		"give": {"who": "Dhruv the blacksmith", "text": "Those are the ones! Hold on. [CLANG] ...There. The Hammer-Seal. Take it to the gate, and may it open what must be opened.",
			"sfx": "anvil", "set": {"seal_forge": true}, "choices": [{"t": "Thank you, Dhruv.", "go": "", "sfx": "seal_found"}]},
		"after": {"who": "Dhruv the blacksmith", "text": "The sun-disc travels with you now. Strike true, traveller.",
			"choices": [{"t": "I will.", "go": ""}]},
	}
	var s := "first"
	if get_flag("forge_asked"):
		s = "wait"
		var r := int(get_flag("rivets", 0))
		(n["wait"] as Dictionary)["text"] = (n["wait"]["text"] as String) % r
		if r >= 3:
			s = "give"
	if get_flag("seal_forge"):
		s = "after"
	return {"start": s, "nodes": n}


func _railworker() -> Dictionary:
	var n := {
		"first": {"who": "Mohan", "text": "Careful on the dock! The goods train? It has stood here since before I was born, and nobody dares move it. What do you want?",
			"choices": [{"t": "Bhairav sent me. A crate: LOT 7.", "go": "crate"}, {"t": "Just looking around.", "go": ""}]},
		"crate": {"who": "Mohan", "text": "LOT 7... the company shipped it out of the valley in 1923 and never came back for it. Third boxcar, the one with the door open. Nobody has the key, but the lid is rotten. Pry it up.",
			"set": {"rail_talk": true}, "choices": [{"t": "Where is the ramp?", "go": "ramp"}, {"t": "On my way.", "go": ""}]},
		"ramp": {"who": "Mohan", "text": "The wooden ramp by the loading dock, at the front of the yard. Walk up onto the platform, then step into the open boxcar.",
			"choices": [{"t": "Thank you, Mohan.", "go": ""}]},
		"again": {"who": "Mohan", "text": "Third boxcar, open door. The crate marked LOT 7. The ramp is by the dock, can't miss it.",
			"choices": [{"t": "Thank you.", "go": ""}]},
		"after": {"who": "Mohan", "text": "You found it? Good. That crate was giving me the shivers for twenty years.",
			"choices": [{"t": "It was worth the wait.", "go": ""}]},
	}
	var s := "first"
	if get_flag("rail_talk"):
		s = "again"
	if get_flag("seal_rail"):
		s = "after"
	return {"start": s, "nodes": n}


func _elder() -> Dictionary:
	var n := {
		"first": {"who": "Elder Kamla", "text": "Sit, child. Bhairav's messenger, yes? The well is dry, and you wonder why. Because the Queen's engineers sealed its heart when they made the Seals. The bucket reaches nothing.",
			"choices": [{"t": "Where is the Water-Seal?", "go": "where"}, {"t": "Why was the well sealed?", "go": "why"}]},
		"why": {"who": "Elder Kamla", "text": "To keep the water for those who would one day need it more. Queen Ila feared a day when greedy hands would drain the valley. She was right, as queens often are.",
			"choices": [{"t": "Where is the Water-Seal?", "go": "where"}]},
		"where": {"who": "Elder Kamla", "text": "The water went sideways, into the sand, where the old diggers staked their mark. Look for a stake wrapped in red cloth, south of the well. Dig there, and listen to the sand.",
			"set": {"well_riddle": true}, "choices": [{"t": "I will dig.", "go": ""}]},
		"again": {"who": "Elder Kamla", "text": "A stake with a red cloth, south of the well. Dig, child. And listen to the sand.",
			"choices": [{"t": "I will.", "go": ""}]},
		"after": {"who": "Elder Kamla", "text": "The sand has given up its secret. The well will weep again, one day. Carry the disc gently.",
			"choices": [{"t": "Thank you, Elder.", "go": ""}]},
	}
	var s := "first"
	if get_flag("well_riddle"):
		s = "again"
	if get_flag("seal_well"):
		s = "after"
	return {"start": s, "nodes": n}


func _arin() -> Dictionary:
	var lit := int(get_flag("lanterns", 0))
	var n := {
		"first": {"who": "Dr. Arin Rao", "text": "You came. I told myself someone would, and then told myself no one should. The gate is open; then the seals are real, and so is everything I was afraid of.",
			"set": {"arin_met": true}, "choices": [
				{"t": "Where have you been?", "go": "where"}, {"t": "What is beyond the gate?", "go": "beyond"}]},
		"where": {"who": "Dr. Arin Rao", "text": "Inside, three nights. The Queen's road is lined with lanterns that must be lit in order to wake the corridor. I lit none; my hands shook too much. I made it back here and could go no further.",
			"choices": [{"t": "What is beyond the gate?", "go": "beyond"}, {"t": "I will light them.", "go": "task"}]},
		"beyond": {"who": "Dr. Arin Rao", "text": "A kingdom that was never destroyed. It was put to sleep, with its people, until the sun returned to the valley. Ila did not hide Suryavan. She waited.",
			"choices": [{"t": "I will light the lanterns.", "go": "task"}]},
		"task": {"who": "Dr. Arin Rao", "text": "Three lanterns stand on the platform: left, right and ahead. Touch each flame and the corridor will answer. I will be here. I have walked far enough.",
			"choices": [{"t": "Rest, Arin. I will be quick.", "go": ""}]},
		"waiting": {"who": "Dr. Arin Rao", "text": "%d of 3 lit. Keep going; I can feel the stone warming already." % lit,
			"choices": [{"t": "Almost there.", "go": ""}]},
		"finale": {"who": "Dr. Arin Rao", "text": "Look. The whole road is alight. All those years of reading about Suryavan, and it was only waiting for someone to ask it kindly.",
			"set": {"arin_done": true}, "choices": [{"t": "Together, then.", "go": "end"}]},
		"end": {"who": "Dr. Arin Rao", "text": "Together. Rest tonight; at dawn we walk the Queen's road. That is the next chapter of the valley's story, and I want you beside me for it.",
			"choices": [{"t": "At dawn.", "go": ""}]},
		"after": {"who": "Dr. Arin Rao", "text": "The lanterns will burn until dawn. I will bring the maps. Go, breathe, and thank the village.",
			"choices": [{"t": "Rest well, Arin.", "go": ""}]},
	}
	var s := "first"
	if get_flag("arin_met"):
		s = "waiting" if lit < 3 else "finale"
		if get_flag("arin_done"):
			s = "after"
	return {"start": s, "nodes": n}


func _simple(who: String, text: String, sets: Dictionary = {}, sfx: String = "") -> Dictionary:
	var n := {"who": who, "text": text, "choices": [{"t": "Farewell.", "go": ""}]}
	if not sets.is_empty():
		n["set"] = sets
	if sfx != "":
		n["sfx"] = sfx
	return {"start": "a", "nodes": {"a": n}}


func _weaver() -> Dictionary:
	var w := "Meera the weaver"
	if not get_flag("met_chief"):
		return _simple(w, "Look at this pattern: a sun with twelve rays. It was my grandmother's, and her mother's.")
	if not get_flag("shards_ask"):
		return {"start": "a", "nodes": {
			"a": {"who": w, "text": "The sun with twelve rays: I have only ever seen it in thread. The old pottery in the dunes carries it in paint. If you find six painted shards, I could finally weave it whole.",
				"choices": [{"t": "I will bring you six shards.", "go": "b", "set": {"shards_ask": true}}, {"t": "Maybe later.", "go": ""}]},
			"b": {"who": w, "text": "Look near old walls, dry riverbeds and the edge of the valley. They gleam when the light finds them.", "choices": [{"t": "I will look.", "go": ""}]}}}
	if int(get_flag("shards", 0)) < 6:
		return _simple(w, "%d of 6 shards. The valley hides them well, but the sun shows them to patient eyes." % int(get_flag("shards", 0)))
	if not get_flag("shards_done"):
		return {"start": "a", "nodes": {"a": {"who": w, "text": "Six! And they fit together: look, a sun with twelve rays and a tiny gate in its heart. The Queen's own mark. Thank you; I will weave it into the village banner.",
			"set": {"shards_done": true}, "sfx": "seal_found", "choices": [{"t": "It is yours.", "go": ""}]}}}
	return _simple(w, "The banner hangs on my loom, and the whole village visits to see it. You gave us back a piece of ourselves.")


func _hari() -> Dictionary:
	var w := "Hari the farmer"
	if not get_flag("met_chief"):
		return _simple(w, "No rain for months. The barley is a prayer, not a crop.")
	if not get_flag("cow_ask"):
		return {"start": "a", "nodes": {
			"a": {"who": w, "text": "Lakshmi, my best cow, wandered off into the western dunes two days ago. I cannot leave the barley. If you pass that way... would you look for her?",
				"choices": [{"t": "I will find her.", "go": "b", "set": {"cow_ask": true}}, {"t": "Not now.", "go": ""}]},
			"b": {"who": w, "text": "She is brown with a white star. She answers to a calm voice and a patient hand.", "choices": [{"t": "I will bring good news.", "go": ""}]}}}
	if not get_flag("cow_found"):
		return _simple(w, "West of the village, past the last dry well. Lakshmi will not wander far from shade.")
	if not get_flag("cow_done"):
		return {"start": "a", "nodes": {"a": {"who": w, "text": "She is safe! She found the old shade stones, clever girl. You have done a farmer a kindness he will not forget.",
			"set": {"cow_done": true}, "sfx": "seal_found", "choices": [{"t": "Glad to help.", "go": ""}]}}}
	return _simple(w, "Lakshmi is back among the herd, chewing as if nothing happened. Thank you, friend.")


func _anita() -> Dictionary:
	var w := "Anita"
	if not get_flag("met_chief"):
		return _simple(w, "Dr. Rao taught my son to read the old letters. Bring him back safe.")
	if not get_flag("letter_ask"):
		return {"start": "a", "nodes": {
			"a": {"who": w, "text": "Would you carry a letter for me to the merchant at the caravan station? It is about my brother. The walk is long, and my knees are not what they were.",
				"choices": [{"t": "Of course. I will deliver it.", "go": "b", "set": {"letter_ask": true}}, {"t": "Not now.", "go": ""}]},
			"b": {"who": w, "text": "Bless you. Give it to him and wait for his reply. He is slow with words but faithful.", "choices": [{"t": "Back soon.", "go": ""}]}}}
	if not get_flag("letter_delivered"):
		return _simple(w, "The merchant is at the caravan station, east of the railway. Please hurry; my brother's caravan leaves at dusk.")
	if not get_flag("letter_done"):
		return {"start": "a", "nodes": {"a": {"who": w, "text": "He says my brother will wait for me at the caravan! You have no idea what this means. Take these blessings; they are all I have.",
			"set": {"letter_done": true}, "sfx": "seal_found", "choices": [{"t": "Safe travels, Anita.", "go": ""}]}}}
	return _simple(w, "I am packing for the caravan road. The valley will miss you, friend.")


func _merchant() -> Dictionary:
	var w := "Merchant"
	if get_flag("letter_ask") and not get_flag("letter_delivered"):
		return {"start": "a", "nodes": {"a": {"who": w, "text": "A letter from Anita? Ah... tell her yes. Her brother's caravan waits one more night. Tell her I said so myself.",
			"set": {"letter_delivered": true}, "sfx": "pickup", "choices": [{"t": "I will tell her.", "go": ""}]}}}
	return _small(w, ["A scholar vanishes, and suddenly everyone wants maps. Business is good, sadly.", "I saw Dr. Rao's lantern at the ruins three nights ago. Then no more."])
