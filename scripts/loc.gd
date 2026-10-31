class_name Loc
extends RefCounted
## Language switch (English / Hindi). Story lines, ambient chatter and dialogue choices are looked up by
## their English text in data/hindi.json; anything without a translation stays in English. Spoken Hindi
## clips are keyed by the Hindi text (tools/render_voices_hi.py), so Sfx finds them by passing the
## translated text through the usual lookup.

static var lang := "en"
static var _tr: Dictionary = {}
static var _loaded := false

const NAMES := {
	"Chief Bhairav": "सरदार भैरव", "Dr. Arin Rao": "डॉक्टर अरिन राव", "Dhruv the blacksmith": "लुहार धुरव",
	"Kabir": "कबीर", "Hari the farmer": "किसान हरि", "Anita": "अनीता", "Race Master Bhim": "दौड़-मास्टर भीम",
	"Arin's journal": "अरिन की पत्रिका", "Mohan": "मोहन", "Elder Kamla": "बड़ी माँ कमला", "Meera the weaver": "बुनकर मीरा",
	"Imran the trader": "सौदागर इमरान", "Merchant": "सौदागर", "Dev the potter": "कुम्हार देव", "Old Ganesh": "बूढ़े गणेश",
	"Chhoti": "छोटी", "Bholu": "भोलू", "Pandit Rishi": "पंडित ऋषि", "Shanta": "शांता", "Roshni": "रोशनी",
	"Scholar Vikram": "विद्वान विक्रम", "Guard Veer": "पहरेदार वीर", "Guard Shera": "पहरेदार शेरा",
	"The map table": "नक़्शे की मेज़", "You": "आप", "Reaver Garr": "लुटेरा गर्र", "Reaver Naag": "लुटेरा नाग", "Tara": "तारा",
	"Salim": "सलीम", "Villager": "गाँव वाला", "Raju": "राजू", "Old Lakshmi": "बूढ़ी लक्ष्मी", "Pinky": "पिंकी",
	"Traveller": "मुसाफ़िर", "Narrator": "सूत्रधार", "Raju the chaiwala": "चायवाला राजू", "Pansari Lal": "मसालेवाला लाल",
}


static func set_language(code: String) -> void:
	lang = "hi" if code == "hi" else "en"


static func hindi() -> bool:
	return lang == "hi"


static func t(text: String) -> String:
	if lang != "hi" or text == "":
		return text
	if not _loaded:
		_loaded = true
		var f := FileAccess.open("res://data/hindi.json", FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_tr = parsed
	var hit: Variant = _tr.get(text, null)
	if hit != null:
		return str(hit)
	# lines with numbers ("Clear the camp (2/4)"): look up the pattern with each number written as #
	var re := RegEx.create_from_string("[0-9]+")
	var found := re.search_all(text)
	if found.is_empty():
		return text
	var pattern := re.sub(text, "#", true)
	var out: Variant = _tr.get(pattern, null)
	if out == null:
		return text
	var res := str(out)
	for m in found:
		var i := res.find("#")
		if i < 0:
			break
		res = res.substr(0, i) + m.get_string() + res.substr(i + 1)
	return res


## Speaker names in the dialogue box.
static func name_of(who: String) -> String:
	if lang != "hi":
		return who
	return str(NAMES.get(who, who))
