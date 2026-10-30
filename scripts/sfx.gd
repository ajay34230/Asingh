class_name Sfx
extends Node
## Sound: procedurally generated audio (tools/make_audio.py) played as 3D one-shots, ambient loops
## (wind, desert music, birds), footsteps and speech blips. Created once by Main; other scripts use
## the static helpers (`Sfx.at`, `Sfx.ui`, `Sfx.speak`), which do nothing when no manager exists.

static var instance: Sfx

const DIR := "res://assets/audio/"
const MAX_ONESHOTS := 14

var player: Player
var houses: HouseBuilder
var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer3D] = []
var _pool_i := 0
var _music: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _room: AudioStreamPlayer
var _pad: AudioStreamPlayer
var _rain_loop: AudioStreamPlayer
var _music_night: AudioStreamPlayer
var _music_village: AudioStreamPlayer
var _bell_t := 30.0
var _chime_t := 10.0
var atmo: Atmosphere:
	set(v):
		atmo = v
		if v != null:
			v.thunder.connect(func() -> void: ui_at("thunder", -4.0))
var voices_on := true             # NPC speech through the phone's text-to-speech engine
var _tts_voices: Array = []
var _ui: AudioStreamPlayer
var _bird_t := 4.0
var _rng := RandomNumberGenerator.new()
var _was_air := false
var _fall_v := 0.0


func setup(p: Player, h: HouseBuilder) -> Sfx:
	instance = self
	name = "Sfx"
	player = p
	houses = h
	_rng.randomize()
	_tts_voices = _find_voices()
	for i in MAX_ONESHOTS:
		var a := AudioStreamPlayer3D.new()
		a.max_distance = 70.0
		a.unit_size = 6.0
		a.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(a)
		_pool.append(a)
	_music = _loop_player("music_desert", -12.0)
	_wind = _loop_player("wind_loop", -10.0)
	_pad = _loop_player("ambient_pad", -15.0)
	_rain_loop = _loop_player("rain_loop", -80.0)
	_music_night = _loop_player("music_night", -60.0)
	_music_village = _loop_player("music_village", -60.0)
	_crickets = _loop_player("crickets_loop", -24.0)
	_room = _loop_player("room_tone", -80.0)
	_ui = AudioStreamPlayer.new()
	add_child(_ui)
	p.stepped.connect(_on_step)
	p.jumped.connect(func() -> void: ui_at("jump", -9.0))
	p.landed.connect(func(v: float) -> void: ui_at("land", clampf(-14.0 + v * 0.8, -14.0, -2.0)))
	p.message.connect(func(_t: String) -> void: ui("chime", -6.0))
	return self


func _stream(n: String) -> AudioStream:
	if not _cache.has(n):
		_cache[n] = load(DIR + n + ".wav")
	return _cache[n]


func _loop_player(n: String, db: float) -> AudioStreamPlayer:
	var s := (_stream(n) as AudioStreamWAV).duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = s.data.size() / 2
	var a := AudioStreamPlayer.new()
	a.stream = s
	a.volume_db = db
	add_child(a)
	a.play()
	return a


# --- helpers -------------------------------------------------------------------------------

static func at(n: String, pos: Vector3, db: float = 0.0, pitch: float = 1.0) -> void:
	if instance != null:
		instance._play3d(n, pos, db, pitch)


static func ui(n: String, db: float = 0.0) -> void:
	if instance != null:
		instance._ui.stream = instance._stream(n)
		instance._ui.volume_db = db
		instance._ui.pitch_scale = 1.0
		instance._ui.play()


static func ui_at(n: String, db: float = 0.0) -> void:
	if instance != null and instance.player != null:
		instance._play3d(n, instance.player.global_position + Vector3(0, 0.3, 0), db, 1.0)


## Speech babble: one blip per ~3 letters, pitch varied by the text so each line sounds different.
static func speak(voice: String, text: String, pos_node: Node3D, db: float = 0.0, dialogue: bool = false) -> void:
	if instance == null:
		return
	if instance.voices_on and instance._say_tts(voice, text, pos_node, dialogue):
		return
	if pos_node == null:
		return
	instance._speak(voice, text, pos_node, db)


static func stop_speech() -> void:
	if instance != null and not instance._tts_voices.is_empty():
		DisplayServer.tts_stop()


## English voices installed on the device (Android: Google / Samsung TTS). Prefers Indian English.
func _find_voices() -> Array:
	var out: Array = []
	var all: Array = DisplayServer.tts_get_voices()
	for v in all:
		var lang: String = str(v.get("language", "")).to_lower().replace("_", "-")
		if lang.begins_with("en"):
			out.append(v)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ai := 0 if str(a.get("language", "")).to_lower().replace("_", "-").contains("in") else 1
		var bi := 0 if str(b.get("language", "")).to_lower().replace("_", "-").contains("in") else 1
		return ai < bi)
	return out


const VOICE_PITCH := {"man": 1.0, "deep": 0.7, "old": 0.82, "woman": 1.22, "girl": 1.55}
const VOICE_RATE := {"man": 1.0, "deep": 0.92, "old": 0.85, "woman": 1.0, "girl": 1.08}


## Speak with the system voice. Returns false when no voice exists (caller falls back to blips).
func _say_tts(voice: String, text: String, node: Node3D, dialogue: bool) -> bool:
	if _tts_voices.is_empty():
		return false
	var vol := 100
	if not dialogue:
		if node == null or player == null:
			return true
		var d := node.global_position.distance_to(player.global_position)
		vol = int(clampf(1.0 - (d - 4.0) / 14.0, 0.0, 1.0) * 100.0)
		if vol < 15 or DisplayServer.tts_is_speaking():
			return true
	else:
		DisplayServer.tts_stop()
	var who: String = node.name if node != null else "narrator"
	var pool := _tts_voices
	# distinct voices per person; spread the first few so neighbours differ
	var v: Dictionary = pool[absi(hash(who)) % mini(pool.size(), 6)]
	var clean := text.replace("...", ", ").replace("%", " percent")
	DisplayServer.tts_speak(clean, str(v["id"]), vol, VOICE_PITCH.get(voice, 1.0), VOICE_RATE.get(voice, 1.0))
	return true


func _play3d(n: String, pos: Vector3, db: float, pitch: float) -> void:
	var a := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	a.stream = _stream(n)
	a.global_position = pos
	a.volume_db = db
	a.pitch_scale = pitch
	a.play()


func _speak(voice: String, text: String, pos_node: Node3D, db: float) -> void:
	var count := clampi(int(text.length() / 3.0), 3, 22)
	var h := absi(hash(text))
	for i in count:
		var vi := (h + i * 7) % 6
		var pitch := 0.88 + float((h >> (i % 12)) % 25) * 0.011
		var delay := float(i) * 0.135
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(pos_node) and pos_node.is_inside_tree():
				_play3d("voice_%s_%d" % [voice, vi], pos_node.global_position + Vector3(0, 1.6, 0), db, pitch))


func _on_step(run: bool) -> void:
	var wood := false
	if houses != null:
		for hs in houses.houses:
			var n: Node3D = hs.node
			var lp := n.global_transform.affine_inverse() * player.global_position
			var half: Vector2 = hs.half
			if absf(lp.x) < half.x and absf(lp.z) < half.y and lp.y > -0.5 and lp.y < 3.5:
				wood = true
				break
	var p := player.global_position
	var stone := p.z < -118.0 and absf(p.x) < 45.0
	var kind := "step_wood_%d" % _rng.randi_range(0, 2) if wood else ("step_stone_%d" % _rng.randi_range(0, 2) if stone else "step_sand_%d" % _rng.randi_range(0, 3))
	_play3d(kind, p, -2.0 if run else -5.0, _rng.randf_range(0.92, 1.08) * (1.1 if run else 1.0))


func _process(delta: float) -> void:
	if player == null:
		return
	# inside a house the wind is muffled
	var indoors := false
	if houses != null:
		for hs in houses.houses:
			var n: Node3D = hs.node
			var lp := n.global_transform.affine_inverse() * player.global_position
			var half: Vector2 = hs.half
			if absf(lp.x) < half.x and absf(lp.z) < half.y and lp.y > -0.5 and lp.y < 3.5:
				indoors = true
				break
	var k := 1.0 - exp(-3.0 * delta)
	var night0 := atmo.night if atmo != null else 0.0
	var rain0 := atmo.rain if atmo != null else 0.0
	_rain_loop.volume_db = lerpf(_rain_loop.volume_db, (-80.0 if rain0 < 0.02 else (lerpf(-34.0, -11.0, rain0) - (12.0 if indoors else 0.0))), k)
	var near_house := INF
	var near_pos := Vector3.ZERO
	if houses != null:
		for hs in houses.houses:
			var hn: Node3D = hs.node
			var hd := hn.global_position.distance_to(player.global_position)
			if hd < near_house:
				near_house = hd
				near_pos = hn.global_position
	_music.volume_db = lerpf(_music.volume_db, lerpf(-12.0, -42.0, night0) - (6.0 if near_house < 40.0 else 0.0), k)
	_music_night.volume_db = lerpf(_music_night.volume_db, lerpf(-48.0, -12.0, night0), k)
	_music_village.volume_db = lerpf(_music_village.volume_db, (-15.0 - night0 * 8.0) if near_house < 45.0 else -52.0, k * 0.5)
	_bell_t -= delta
	if _bell_t <= 0.0:
		_bell_t = _rng.randf_range(50.0, 100.0)
		ui_at("temple_bell", -15.0)
	_chime_t -= delta
	if _chime_t <= 0.0:
		_chime_t = _rng.randf_range(9.0, 22.0)
		if near_house < 35.0 and not indoors:
			_play3d("wind_chime_%d" % _rng.randi_range(0, 2), near_pos + Vector3(0, 3.2, 0), -6.0, _rng.randf_range(0.95, 1.05))
	_wind.volume_db = lerpf(_wind.volume_db, -22.0 if indoors else -10.0, k)
	var night := atmo.night if atmo != null else 0.0
	_crickets.volume_db = lerpf(_crickets.volume_db, -60.0 if indoors else lerpf(-34.0, -14.0, night), k)
	_room.volume_db = lerpf(_room.volume_db, -16.0 if indoors else -80.0, k)
	_bird_t -= delta
	if _bird_t <= 0.0 and not indoors and (atmo == null or atmo.night < 0.5):
		_bird_t = _rng.randf_range(5.0, 13.0)
		var ang := _rng.randf() * TAU
		var d := _rng.randf_range(14.0, 40.0)
		_play3d("bird_%d" % _rng.randi_range(0, 4), player.global_position + Vector3(cos(ang) * d, 7.0, sin(ang) * d), -5.0, _rng.randf_range(0.9, 1.15))
