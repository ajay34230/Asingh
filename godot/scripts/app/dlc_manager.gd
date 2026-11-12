## Optional downloadable graphics packs (Godot PCK files).
##
## The core game never depends on a pack: every pack only adds or overrides assets, so
## if a pack is missing, removed or fails to mount the original graphics are used.
##
## Hosting is configuration only. `manifest_url` points at a JSON manifest:
##   {"schema": 1, "packs": [{"id": "ultra_textures", "name": "Ultra HD Texture Pack",
##     "version": "1.0.0", "size": 123456, "sha256": "<hex>", "url": "https://.../x.pck",
##     "min_game_version": "1.9.0", "description": "..."}]}
## Defaults to the dlc/ folder of the game repository on GitHub; switching to Cloudflare R2 or another CDN only needs a
## different URL (Settings key dlc/manifest_url, or edit DEFAULT_MANIFEST_URL).
class_name DLCManager
extends Node

signal manifest_changed(from_cache: bool)
signal progress(id: String, received: int, total: int)
signal pack_finished(id: String, ok: bool, message: String)
signal installed_changed

const DEFAULT_MANIFEST_URL := "https://raw.githubusercontent.com/ajay34230/asingh/ccr-1a31b667-aqu8jk/dlc/manifest.json"
const DIR := "user://dlc"
const MAX_ATTEMPTS := 4

var manifest_url := DEFAULT_MANIFEST_URL
var packs: Array = []                 ## the manifest's packs (the cached copy when offline)
var offline := false                  ## the last refresh could not reach the server
var _installed := {}                  ## id -> {version, size, file}
var _mounted := {}                    ## id -> true
var _busy := {}                       ## id -> true while downloading
var _cancel := {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var override: Variant = GameSettings.load_value("dlc", "manifest_url", "")
	if override is String and override != "":
		manifest_url = override
	_load_state()
	mount_installed()


# --- state -----------------------------------------------------------------------------

func game_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "1.0.0"))


func _load_state() -> void:
	var f := FileAccess.open(DIR + "/installed.json", FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_installed = d
	var m := FileAccess.open(DIR + "/manifest.json", FileAccess.READ)
	if m:
		var d2: Variant = JSON.parse_string(m.get_as_text())
		if d2 is Dictionary and d2.get("packs") is Array:
			packs = d2["packs"]


func _save_installed() -> void:
	var f := FileAccess.open(DIR + "/installed.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_installed))
	installed_changed.emit()


## Mounts every installed pack (offline, at startup). A pack whose file vanished or
## will not mount is dropped, which simply means its extras are not shown.
func mount_installed() -> void:
	for id in _installed.keys():
		var file := String(_installed[id].get("file", ""))
		if file == "" or not FileAccess.file_exists(file) or not ProjectSettings.load_resource_pack(file):
			_installed.erase(id)
			continue
		_mounted[id] = true
	_save_installed()


func has_pack(id: String) -> bool:
	return _mounted.has(id)


# --- manifest ----------------------------------------------------------------------------

## Compares dotted versions: -1, 0 or 1.
static func compare_versions(a: String, b: String) -> int:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in range(maxi(pa.size(), pb.size())):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return -1 if x < y else 1
	return 0


func is_compatible(pack: Dictionary) -> bool:
	return compare_versions(game_version(), String(pack.get("min_game_version", "0"))) >= 0


## Fetches the manifest; falls back to the cached copy when there is no connection.
func refresh() -> void:
	var http := HTTPRequest.new()
	http.timeout = 12.0
	http.max_redirects = 8
	add_child(http)
	var err := http.request(manifest_url)
	var ok := false
	if err == OK:
		var res: Array = await http.request_completed
		if res[0] == HTTPRequest.RESULT_SUCCESS and res[1] == 200:
			var d: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
			if d is Dictionary and d.get("packs") is Array:
				packs = d["packs"]
				var f := FileAccess.open(DIR + "/manifest.json", FileAccess.WRITE)
				f.store_string(JSON.stringify(d))
				ok = true
	http.queue_free()
	offline = not ok
	manifest_changed.emit(not ok)


## Everything the Resource Centre shows: the manifest's packs plus installed ones the
## manifest no longer lists, each with its status.
func entries() -> Array:
	var out: Array = []
	var seen := {}
	for p in packs:
		var e: Dictionary = (p as Dictionary).duplicate()
		var id := String(e.get("id", ""))
		seen[id] = true
		e["status"] = status(id)
		e["installed_version"] = String(_installed.get(id, {}).get("version", ""))
		out.append(e)
	for id in _installed:
		if not seen.has(id):
			out.append({"id": id, "name": id, "version": _installed[id]["version"], "size": _installed[id]["size"], "status": "installed", "installed_version": _installed[id]["version"], "description": ""})
	return out


## "available", "installed", "update", "incompatible" or "downloading".
func status(id: String) -> String:
	if _busy.has(id):
		return "downloading"
	var pack := _find(id)
	if _installed.has(id):
		if not pack.is_empty() and compare_versions(String(pack.get("version", "0")), String(_installed[id]["version"])) > 0 and is_compatible(pack):
			return "update"
		return "installed"
	if not pack.is_empty() and not is_compatible(pack):
		return "incompatible"
	return "available"


func _find(id: String) -> Dictionary:
	for p in packs:
		if String(p.get("id", "")) == id:
			return p
	return {}


## Bytes the installed packs take on this device.
func storage_used() -> int:
	var total := 0
	var d := DirAccess.open(DIR)
	if d:
		for f in d.get_files():
			total += FileAccess.open(DIR + "/" + f, FileAccess.READ).get_length() if f.ends_with(".pck") or f.ends_with(".part") else 0
	return total


# --- download / install / remove ----------------------------------------------------------

func cancel(id: String) -> void:
	_cancel[id] = true


## Downloads a pack (resuming a partly downloaded file), verifies its SHA-256 and mounts it.
func download(id: String) -> void:
	var pack := _find(id)
	if pack.is_empty() or _busy.has(id):
		return
	if not is_compatible(pack):
		pack_finished.emit(id, false, "This pack needs game version %s or newer." % pack.get("min_game_version", "?"))
		return
	_busy[id] = true
	_cancel.erase(id)
	installed_changed.emit()
	var final_path := "%s/%s_%s.pck" % [DIR, id, pack["version"]]
	var part := final_path + ".part"
	var total := int(pack.get("size", 0))
	var message := "Download failed."
	var ok := false
	for attempt in range(MAX_ATTEMPTS):
		if _cancel.has(id):
			message = "Cancelled."
			break
		var have := FileAccess.open(part, FileAccess.READ).get_length() if FileAccess.file_exists(part) else 0
		if total > 0 and have >= total:
			ok = true
			break
		var chunk := part + ".chunk"
		var http := HTTPRequest.new()
		http.download_file = chunk
		http.max_redirects = 8
		http.timeout = 30.0
		add_child(http)
		var headers := PackedStringArray()
		if have > 0:
			headers.append("Range: bytes=%d-" % have)
		var err := http.request(String(pack["url"]), headers)
		if err != OK:
			http.queue_free()
			message = "Could not start the download."
			await get_tree().create_timer(1.0 * (attempt + 1)).timeout
			continue
		var done := [false]
		var result: Array = []
		http.request_completed.connect(func(r: int, code: int, h: PackedStringArray, b: PackedByteArray) -> void:
			result = [r, code]
			done[0] = true)
		while not done[0]:
			await get_tree().create_timer(0.2).timeout
			progress.emit(id, have + http.get_downloaded_bytes(), total)
			if _cancel.has(id):
				http.cancel_request()
				break
		var code: int = result[1] if result.size() > 1 else 0
		http.queue_free()
		if FileAccess.file_exists(chunk):
			## 206 continues the file; a plain 200 is the whole file from the start.
			if code == 200 or have == 0:
				DirAccess.remove_absolute(part)
			_append(part, chunk)
			DirAccess.remove_absolute(chunk)
		if code == 200 or code == 206 or code == 416:
			var got := FileAccess.open(part, FileAccess.READ).get_length() if FileAccess.file_exists(part) else 0
			if total <= 0 or got >= total:
				ok = true
				break
		message = "Connection lost, retrying..."
		await get_tree().create_timer(1.0 * (attempt + 1)).timeout
	if ok:
		ok = _verify_and_install(id, pack, part, final_path)
		if not ok:
			message = "The downloaded file did not match its checksum and was discarded."
			DirAccess.remove_absolute(part)
	_busy.erase(id)
	_cancel.erase(id)
	installed_changed.emit()
	pack_finished.emit(id, ok, "Installed." if ok else message)


func _append(dest: String, src: String) -> void:
	var out := FileAccess.open(dest, FileAccess.READ_WRITE) if FileAccess.file_exists(dest) else FileAccess.open(dest, FileAccess.WRITE)
	out.seek_end()
	var input := FileAccess.open(src, FileAccess.READ)
	while input.get_position() < input.get_length():
		out.store_buffer(input.get_buffer(1 << 20))


func _verify_and_install(id: String, pack: Dictionary, part: String, final_path: String) -> bool:
	var want := String(pack.get("sha256", "")).to_lower()
	if want == "" or FileAccess.get_sha256(part).to_lower() != want:
		return false
	if _installed.has(id):   # an update: drop the old file
		DirAccess.remove_absolute(String(_installed[id]["file"]))
	DirAccess.rename_absolute(part, final_path)
	_installed[id] = {"version": String(pack["version"]), "size": FileAccess.open(final_path, FileAccess.READ).get_length(), "file": final_path}
	_save_installed()
	if ProjectSettings.load_resource_pack(final_path):
		_mounted[id] = true
	return true


## Removes a pack. Godot cannot unmount a pack that is already loaded, so its assets
## disappear at the next start; the original graphics are used from then on.
func remove(id: String) -> void:
	if _installed.has(id):
		DirAccess.remove_absolute(String(_installed[id]["file"]))
		_installed.erase(id)
		_save_installed()
	pack_finished.emit(id, true, "Removed. Restart the game to finish.")
