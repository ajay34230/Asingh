class_name SaveTransfer
extends RefCounted
## Back up your progress and move it to another phone, without any account: the whole save (story, coins,
## items, outfits, skills, Moti, festivals...) plus achievements become one short text code. Export puts the code on
## the clipboard (paste it into WhatsApp, an email or a note to yourself) and also writes it as a file in Downloads.
## Import reads a code from the clipboard or the newest backup file in Downloads, checks it, keeps your current save
## as user://save_before_import.json, and loads the game from the backup.

const PREFIX := "LKSAVE1"
const SAVE_PATH := "user://save.json"
const ACH_PATH := "user://achievements.json"
const BEFORE := "user://save_before_import.json"
const FILE_GLOB := "lostkingdom_save_"


static func _sum(s: String) -> int:
	return absi(s.hash()) % 1000000


## The current save and achievements as one code ("" if there is no save yet).
static func pack() -> String:
	var save := SaveSystem.read(SAVE_PATH)
	if save.is_empty():
		return ""
	var ach: Variant = {}
	if FileAccess.file_exists(ACH_PATH):
		ach = JSON.parse_string(FileAccess.get_file_as_string(ACH_PATH))
	var json := JSON.stringify({"save": save, "ach": ach if ach is Dictionary else {}})
	var raw := json.to_utf8_buffer()
	var z := raw.compress(FileAccess.COMPRESSION_GZIP)
	return "%s:%d:%d:%s" % [PREFIX, raw.size(), _sum(json), Marshalls.raw_to_base64(z)]


## Decodes a code. Returns {} if it is damaged, cut short or not a Lost Kingdom backup.
static func unpack(code: String) -> Dictionary:
	var c := code.strip_edges().replace("\n", "").replace(" ", "")
	var i := c.find(PREFIX + ":")
	if i < 0:
		return {}
	var parts := c.substr(i).split(":", false, 3)
	if parts.size() != 4:
		return {}
	var size := int(parts[1])
	var z := Marshalls.base64_to_raw(parts[3])
	if z.is_empty() or size <= 0 or size > 20000000:
		return {}
	var raw := z.decompress(size, FileAccess.COMPRESSION_GZIP)
	if raw.size() != size:
		return {}
	var json := raw.get_string_from_utf8()
	if _sum(json) != int(parts[2]):
		return {}
	var d: Variant = JSON.parse_string(json)
	if not (d is Dictionary) or not (d as Dictionary).has("save"):
		return {}
	var s: Variant = d["save"]
	if not (s is Dictionary) or not (s as Dictionary).has("flags") or not (s as Dictionary).has("pos"):
		return {}
	return d


## Copies the code to the clipboard and writes it to Downloads (or the game folder). Returns the file path ("" if
## only the clipboard worked, or nothing to export).
static func export_now() -> String:
	var code := pack()
	if code == "":
		return ""
	DisplayServer.clipboard_set(code)
	var name_ := "%s%s.txt" % [FILE_GLOB, Time.get_datetime_string_from_system(false, false).replace(":", "-")]
	for d in [OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS), OS.get_user_data_dir()]:
		if String(d) == "":
			continue
		var p := String(d).path_join(name_)
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f != null:
			f.store_string(code)
			f.close()
			return p
	return ""


## The newest backup file in Downloads or the game folder ("" if none).
static func newest_file() -> String:
	var best := ""
	var best_t := 0
	for d in [OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS), OS.get_user_data_dir()]:
		if String(d) == "":
			continue
		var da := DirAccess.open(String(d))
		if da == null:
			continue
		for f in da.get_files():
			if f.begins_with(FILE_GLOB) and f.ends_with(".txt"):
				var p := String(d).path_join(f)
				var t := FileAccess.get_modified_time(p)
				if t >= best_t:
					best_t = t
					best = p
	return best


## Restores a decoded backup. Your current save is kept as save_before_import.json first.
static func restore(d: Dictionary) -> bool:
	var cur := SaveSystem.read(SAVE_PATH)
	if not cur.is_empty():
		SaveSystem.write(BEFORE, cur)
	if not SaveSystem.write(SAVE_PATH, d["save"]):
		return false
	var ach: Variant = d.get("ach", {})
	if ach is Dictionary:
		var f := FileAccess.open(ACH_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(ach))
	LogCollector.event("save imported")
	return true


## Import from text (clipboard) or, if empty, from the newest backup file. Returns "" on success, else the reason.
static func import_from(text: String) -> String:
	var code := text
	if unpack(code).is_empty():
		var p := newest_file()
		if p == "":
			return "No backup code on the clipboard and no backup file in Downloads."
		code = FileAccess.get_file_as_string(p)
	var d := unpack(code)
	if d.is_empty():
		return "That backup is damaged or incomplete."
	if not restore(d):
		return "Could not write the save."
	return ""
