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
var _track := "menu"


func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_load_settings()
	for name in SOUND_FILES:
		_sounds[name] = load(SOUND_FILES[name])
	for i in range(10):
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
func play(sound_name: String, pitch_jitter := 0.04) -> void:
	if muted or not _sounds.has(sound_name):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _sounds[sound_name]
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.volume_db = sfx_volume_db
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


func stop_music() -> void:
	_music.stop()


func vibrate(milliseconds: int) -> void:
	if haptics and not muted:
		Input.vibrate_handheld(milliseconds)


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
