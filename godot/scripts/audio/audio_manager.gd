## Audio: sound effects from a small player pool, a looped background track, separate
## Music and SFX buses, mute, and haptic feedback. Settings persist in user://settings.cfg.
class_name AudioManager
extends Node

const SOUND_FILES := {
	"dice_roll": "res://assets/audio/dice_roll.wav",
	"dice_land": "res://assets/audio/dice_land.wav",
	"token_select": "res://assets/audio/token_select.wav",
	"token_step": "res://assets/audio/token_step.wav",
	"token_jump": "res://assets/audio/token_jump.wav",
	"token_land": "res://assets/audio/token_land.wav",
	"capture": "res://assets/audio/capture.wav",
	"token_finish": "res://assets/audio/token_finish.wav",
	"victory": "res://assets/audio/victory.wav",
	"ui_click": "res://assets/audio/ui_click.wav",
	"impact": "res://assets/audio/impact.wav",
	"six": "res://assets/audio/six.wav",
}
## Recorded CC0 effects (tools/import_sfx.py): event -> number of variants. A random
## variant plays each time, so repeated sounds never feel mechanical.
const SFX_VARIANTS := {
	"dice_shake": 3, "dice_bounce": 4, "dice_land": 3, "token_step": 10, "token_land": 4,
	"token_select": 3, "ui_click": 4, "ui_open": 3, "ui_back": 3, "error": 3, "blade": 3,
	"swish": 6, "punch": 6, "kick": 4, "thud": 4, "shield": 3, "coins": 2, "confirm": 4,
}
## Synthesised sounds that recorded ones replace (kept as files for the tools only).
const REPLACED := ["dice_land", "token_step", "token_land", "token_select", "ui_click"]

## Sitar and tanpura alaap for menus; sitar gat with tabla during play.
const MUSIC_FILES := {
	"menu": "res://assets/audio/music_menu.wav",
	"game": "res://assets/audio/music_loop.wav",
}

var music_volume_db := -10.0
var sfx_volume_db := -2.0
var muted := false
var haptics := true

var _sounds: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _tracks: Dictionary = {}
var _duck_tween: Tween
var _track := "menu"


func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	## Gentle limiter on the master output: music, effects and voices can stack up
	## during a fight; this keeps the mix loud but never distorted.
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.0
		limiter.pre_gain_db = 0.0
		AudioServer.add_bus_effect(master, limiter)
	_load_settings()
	for name in SOUND_FILES:
		if not REPLACED.has(name):
			_sounds[name] = [load(SOUND_FILES[name])]
	for name in SFX_VARIANTS:
		var list: Array = []
		for i in range(1, SFX_VARIANTS[name] + 1):
			list.append(load("res://assets/audio/sfx/%s_%d.ogg" % [name, i]))
		_sounds[name] = list
	for i in range(16):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for key in MUSIC_FILES:
		var stream := load(MUSIC_FILES[key]) as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_tracks[key] = stream
	_music = AudioStreamPlayer.new()
	_music.stream = _tracks["menu"]
	_music.bus = "Music"
	add_child(_music)
	apply_settings()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


## Plays a named sound effect. Pitch is varied slightly so repeats do not sound mechanical.
func play(sound_name: String, pitch_jitter := 0.04, volume_offset_db := 0.0) -> void:
	if muted or not _sounds.has(sound_name):
		return
	var variants: Array = _sounds[sound_name]
	for p in _pool:
		if not p.playing:
			p.stream = variants.pick_random()
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.volume_db = sfx_volume_db + volume_offset_db
			p.play()
			return


## Starts (or switches to) a music track, fading across when one is already playing.
func start_music(track := "") -> void:
	if track != "" and track != _track and _tracks.has(track):
		_track = track
		if _music.playing:
			var fade := create_tween()
			fade.tween_property(_music, "volume_db", -40.0, 0.6)
			fade.tween_callback(func() -> void:
				_music.stream = _tracks[_track]
				_music.play()
				_music.volume_db = music_volume_db)
			return
		_music.stream = _tracks[_track]
	if not muted and not _music.playing:
		_music.volume_db = music_volume_db
		_music.play()


## Dips the music under spoken dialogue.
func duck_music(on: bool) -> void:
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(_music, "volume_db", music_volume_db - (7.0 if on else 0.0), 0.25 if on else 0.6)


func stop_music() -> void:
	_music.stop()


func vibrate(milliseconds: int) -> void:
	if haptics and not muted:
		Input.vibrate_handheld(milliseconds)


## A rhythm of buzzes: [on, off, on, off, ...] in milliseconds.
func vibrate_pattern(pattern: Array) -> void:
	if not haptics or muted:
		return
	for i in range(0, pattern.size(), 2):
		Input.vibrate_handheld(int(pattern[i]))
		var gap := int(pattern[i]) + (int(pattern[i + 1]) if i + 1 < pattern.size() else 0)
		await get_tree().create_timer(gap / 1000.0, true, false, true).timeout


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		_music.stop()
	else:
		start_music()
	apply_settings()
	_save_settings()


func set_music_volume_db(value: float) -> void:
	music_volume_db = value
	_music.volume_db = value
	_save_settings()


func set_sfx_volume_db(value: float) -> void:
	sfx_volume_db = value
	_save_settings()


func apply_settings() -> void:
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_mute(music_bus, muted)
	AudioServer.set_bus_mute(sfx_bus, muted)
	AudioServer.set_bus_volume_db(music_bus, music_volume_db)
	AudioServer.set_bus_volume_db(sfx_bus, sfx_volume_db)


func _load_settings() -> void:
	music_volume_db = float(GameSettings.load_value("audio", "music_db", music_volume_db))
	sfx_volume_db = float(GameSettings.load_value("audio", "sfx_db", sfx_volume_db))
	muted = bool(GameSettings.load_value("audio", "muted", muted))
	haptics = bool(GameSettings.load_value("audio", "haptics", haptics))


func _save_settings() -> void:
	GameSettings.save_value("audio", "music_db", music_volume_db)
	GameSettings.save_value("audio", "sfx_db", sfx_volume_db)
	GameSettings.save_value("audio", "muted", muted)
	GameSettings.save_value("audio", "haptics", haptics)
