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
var atmo: Atmosphere
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
static func speak(voice: String, text: String, pos_node: Node3D, db: float = 0.0) -> void:
	if instance == null or pos_node == null:
		return
	instance._speak(voice, text, pos_node, db)


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
