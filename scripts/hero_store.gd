class_name HeroStore
extends Node
## Characters downloaded on demand, so the APK stays small. The models live in this game's GitHub repository
## (branch "dlc", folder heroes/) and are fetched into user://dlc/ the first time they are needed:
##   - playable characters, picked in the Characters menu;
##   - the big monsters of some missions, asked for when the mission starts.
## A downloaded model is a plain .glb, loaded at run time (GLTFDocument). Portraits ship with the game.

const BASE_URL := "https://raw.githubusercontent.com/ajay34230/Asingh/dlc/heroes/"
const DIR := "user://dlc/"
# id: [name, kind ("hero" or "monster"), size in KB (shown before downloading)]
const CATALOG := {
	"remy": ["Remy", "hero", 4403],
	"ch22": ["Rohan", "hero", 5546],
	"akai": ["Akai the Archer", "hero", 1508],
	"medea": ["Medea", "hero", 3375],
	"peasant_man": ["Bhola", "hero", 2345],
	"peasant_girl": ["Champa", "hero", 2684],
	"ch39": ["Rishi", "hero", 3514],
	"ch43": ["Pehlwan", "hero", 3911],
	"ch14": ["Billu the Cat", "hero", 1965],
	"prisoner": ["Kaidi (zombie)", "hero", 2347],
	"girl_scout": ["Chudail (zombie)", "hero", 5177],
	"vampire": ["Vampire", "monster", 3801],
	"nightshade": ["Nightshade", "monster", 2843],
	"demon": ["Demon King", "monster", 3690],
}

static var _states := {}          # id -> GLTFState (parsed once, a fresh scene made from it each time)
static var _store: HeroStore


static func get_store(any: Node) -> HeroStore:
	if _store == null or not is_instance_valid(_store):
		_store = HeroStore.new()
		_store.name = "HeroStore"
		any.get_tree().root.add_child.call_deferred(_store)
	return _store


static func local_path(id: String) -> String:
	return DIR + id + ".glb"


static func is_downloaded(id: String) -> bool:
	return FileAccess.file_exists(local_path(id))


static func title(id: String) -> String:
	return String(CATALOG.get(id, [id.capitalize()])[0])


static func size_text(id: String) -> String:
	var kb := int(CATALOG.get(id, ["", "", 0])[2])
	return "%.1f MB" % (kb / 1024.0) if kb > 0 else ""


static func portrait(id: String) -> Texture2D:
	var p := "res://assets/heroes/%s.png" % id
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


## A new copy of the downloaded model (null if it is not here, or will not load).
static func load_scene(id: String) -> Node3D:
	if not is_downloaded(id):
		return null
	var st: GLTFState = _states.get(id)
	var doc := GLTFDocument.new()
	if st == null:
		st = GLTFState.new()
		if doc.append_from_file(ProjectSettings.globalize_path(local_path(id)), st) != OK:
			push_warning("HeroStore: cannot read " + local_path(id))
			return null
		_states[id] = st
	return doc.generate_scene(st) as Node3D


# --- downloading -----------------------------------------------------------------------------------
var _http: HTTPRequest
var _busy := ""
var _done_cb := Callable()
var progress := 0.0               # 0..1 of the current download


func busy() -> String:
	return _busy


## Fetch a model. done(ok: bool, message: String) is called at the end.
func download(id: String, done: Callable) -> void:
	if _busy != "":
		done.call(false, "Another download is running")
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	_busy = id
	if not is_inside_tree():
		await tree_entered      # made this frame: it joins the tree at the end of the frame
	_done_cb = done
	progress = 0.0
	_http = HTTPRequest.new()
	_http.download_file = local_path(id) + ".part"
	_http.use_threads = true
	_http.timeout = 120.0
	add_child(_http)
	_http.request_completed.connect(_on_done)
	var base := OS.get_environment("HERO_URL") if OS.get_environment("HERO_URL") != "" else BASE_URL   # tests serve locally
	var err := _http.request(base + id + ".glb")
	if err != OK:
		_finish(false, "Could not start the download")


func _process(_d: float) -> void:
	if _http != null and _busy != "":
		var total := _http.get_body_size()
		progress = float(_http.get_downloaded_bytes()) / float(total) if total > 0 else 0.0


func _on_done(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	var part := local_path(_busy) + ".part"
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(part))
		_finish(false, "Download failed. Check your internet and try again.")
		return
	var f := FileAccess.open(part, FileAccess.READ)
	var ok := f != null and f.get_length() > 50000 and f.get_buffer(4).get_string_from_ascii() == "glTF"
	if f != null:
		f.close()
	if not ok:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(part))
		_finish(false, "The download was damaged. Please try again.")
		return
	DirAccess.rename_absolute(ProjectSettings.globalize_path(part), ProjectSettings.globalize_path(local_path(_busy)))
	_finish(true, "")


func _finish(ok: bool, msg: String) -> void:
	var cb := _done_cb
	var id := _busy
	_busy = ""
	_done_cb = Callable()
	if _http != null:
		_http.queue_free()
		_http = null
	LogCollector.event("download %s: %s %s" % [id, "ok" if ok else "failed", msg])
	if cb.is_valid():
		cb.call(ok, msg)


## Delete a downloaded model (frees space).
static func remove(id: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(local_path(id)))
	_states.erase(id)
