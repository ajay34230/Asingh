class_name SaveSystem
extends RefCounted
## Safe save files. Versioned JSON, written atomically (temp file, verified, then renamed over
## the old file), with the previous save kept as `<path>.bak`. Old formats are migrated forward in
## memory. A damaged file is never deleted: it is renamed to `<path>.corrupt` and the backup is used.

const VERSION := 2


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


## Writes `data` (a Dictionary). Returns true only if the new file was written and read back OK.
static func write(path: String, data: Dictionary) -> bool:
	var d := data.duplicate()
	d["version"] = VERSION
	d["saved_unix"] = Time.get_unix_time_from_system()
	var text := JSON.stringify(d)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	if _parse(tmp).is_empty():                    # verify what actually reached the disk
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return false
	if FileAccess.file_exists(path) and not _parse(path).is_empty():
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) == OK


## Returns the migrated save, or an empty Dictionary if nothing usable exists.
static func read(path: String) -> Dictionary:
	var d := _parse(path)
	if d.is_empty() and FileAccess.file_exists(path):
		# Main file is damaged: keep it for inspection, fall back to the backup.
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".corrupt"))
	if d.is_empty():
		d = _parse(path + ".bak")
	if d.is_empty():
		return {}
	return _migrate(d)


static func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	if not (v is Dictionary):
		return {}
	var d: Dictionary = v
	if not d.has("flags") or not d.has("pos") or not (d["pos"] is Array) or d["pos"].size() < 3:
		return {}
	return d


## Brings any older save up to VERSION. Missing fields get safe defaults.
static func _migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 1))
	if v < 2:
		# v1 had only flags, pos, yaw and tod. v2 adds the player's health.
		d["hp"] = -1.0                                # -1 means "not saved": start at full health
		v = 2
	d["version"] = v
	return d
