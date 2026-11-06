class_name LogCollector
extends RefCounted
## Crash and log collector. Keeps a small event log (missions, saves, quality changes, warnings from game code),
## stores a crash report whenever the previous run ended unexpectedly (see Diag), and builds one plain-text report
## with device info, crash reports, recent events and the tail of Godot's own log files. The report can be copied
## to the clipboard (paste it into WhatsApp, email or a GitHub issue) or saved as a file in Downloads.
## Nothing is sent anywhere by the game itself.

const EVENTS := "user://events.log"
const EVENTS_MAX := 120_000            # bytes; the older half is dropped when it grows past this
const CRASH_DIR := "user://crashes"
const CRASH_KEEP := 10
const LOG_DIR := "user://logs"
const TAIL_LINES := 250


## Append one timestamped line to the event log.
static func event(msg: String) -> void:
	var line := "%s %s\n" % [Time.get_datetime_string_from_system(false, true), msg]
	var f := FileAccess.open(EVENTS, FileAccess.READ_WRITE) if FileAccess.file_exists(EVENTS) else FileAccess.open(EVENTS, FileAccess.WRITE)
	if f == null:
		return
	if f.get_length() > EVENTS_MAX:
		f.close()
		var keep := FileAccess.get_file_as_string(EVENTS).right(EVENTS_MAX / 2)
		f = FileAccess.open(EVENTS, FileAccess.WRITE)
		if f == null:
			return
		f.store_string("...(older events dropped)\n" + keep.substr(keep.find("\n") + 1))
	f.seek_end()
	f.store_string(line)


## Godot's log files, newest first (godot.log is the current run; rotated ones carry a date).
static func log_files() -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(LOG_DIR)
	if d == null:
		return out
	var files: Array = []
	for fn in d.get_files():
		if fn.ends_with(".log"):
			var p := LOG_DIR + "/" + fn
			files.append([FileAccess.get_modified_time(p), p])
	files.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	for e in files:
		out.append(String(e[1]))
	return out


static func _tail(path: String, n: int) -> String:
	if not FileAccess.file_exists(path):
		return "(missing)"
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var start := maxi(0, lines.size() - n)
	return "\n".join(lines.slice(start))


## Called once at start-up when the previous run did not exit cleanly: saves a crash report built from the last
## breadcrumb and the end of the previous run's Godot log.
static func record_crash(breadcrumb: String) -> void:
	DirAccess.make_dir_recursive_absolute(CRASH_DIR)
	var logs := log_files()
	var prev := logs[1] if logs.size() > 1 else ""      # [0] is this run's fresh log
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", "-")
	var f := FileAccess.open("%s/crash_%s.txt" % [CRASH_DIR, stamp], FileAccess.WRITE)
	if f != null:
		f.store_string("Crash detected at start-up %s\nLast state: %s\nPrevious log: %s\n--- last %d lines ---\n%s\n" % [
			stamp, breadcrumb, prev, TAIL_LINES, _tail(prev, TAIL_LINES) if prev != "" else "(no previous log file)"])
	event("CRASH previous run ended unexpectedly: " + breadcrumb)
	var all := crash_files()
	for i in range(CRASH_KEEP, all.size()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(all[i]))


static func crash_files() -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(CRASH_DIR)
	if d == null:
		return out
	var names := Array(d.get_files())
	names.sort()
	names.reverse()
	for fn in names:
		out.append(CRASH_DIR + "/" + String(fn))
	return out


static func device_info() -> String:
	return "\n".join([
		"Game: The Lost Kingdom %s (%s)" % [BuildInfo.VERSION, BuildInfo.BUILD],
		"Device: %s, %s %s" % [OS.get_model_name(), OS.get_name(), OS.get_version()],
		"GPU: %s / %s" % [RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_name()],
		"Driver: %s" % RenderingServer.get_video_adapter_api_version(),
		"Screen: %s  Memory used: %d MB" % [str(DisplayServer.window_get_size()), int(OS.get_static_memory_usage() / 1048576)],
		"Settings: quality=%s fps_cap=%s" % [str(GameSettings.v.get("quality", "?")), str(GameSettings.v.get("fps_cap", "?"))],
		"Report made: %s" % Time.get_datetime_string_from_system(false, true),
	])


## The whole report as text. `max_chars` keeps clipboard pastes manageable.
static func build_report(max_chars: int = 180_000) -> String:
	var parts := PackedStringArray()
	parts.append("===== LOST KINGDOM BUG REPORT =====")
	parts.append(device_info())
	var crashes := crash_files()
	parts.append("\n===== CRASHES (%d stored, newest first) =====" % crashes.size())
	for i in mini(crashes.size(), 3):
		parts.append("--- " + crashes[i].get_file() + " ---")
		parts.append(FileAccess.get_file_as_string(crashes[i]))
	parts.append("\n===== RECENT EVENTS =====")
	parts.append(_tail(EVENTS, 150))
	var logs := log_files()
	for i in mini(logs.size(), 2):
		parts.append("\n===== GODOT LOG %s (last %d lines) =====" % [logs[i].get_file(), TAIL_LINES])
		parts.append(_tail(logs[i], TAIL_LINES))
	var txt := "\n".join(parts)
	if txt.length() > max_chars:
		txt = txt.left(max_chars) + "\n...(cut)"
	return txt


static func copy_report() -> int:
	var r := build_report(90_000)
	DisplayServer.clipboard_set(r)
	return r.length()


## Saves the report as a text file, first in the phone's Downloads folder, else in the game's own folder.
## Returns the path written, or "" on failure.
static func save_report() -> String:
	var r := build_report()
	var name_ := "lostkingdom_report_%s.txt" % Time.get_datetime_string_from_system(false, false).replace(":", "-")
	var dirs := [OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS), OS.get_user_data_dir()]
	for d in dirs:
		if String(d) == "":
			continue
		var p := String(d).path_join(name_)
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f != null:
			f.store_string(r)
			f.close()
			return p
	return ""


static func clear_all() -> void:
	for p in crash_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if FileAccess.file_exists(EVENTS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(EVENTS))


static func summary_line() -> String:
	return "%d crash report(s) stored. Godot log files: %d." % [crash_files().size(), log_files().size()]
