class_name Festival
extends Node3D
## X19: every fifth day in the valley is a festival. Evening of a "lights" festival: strings of glowing lanterns
## over the bazaar square. Evening of a "colours" festival: bursts of coloured powder around the fountain.

const C := Vector3(22.0, 0.0, -42.0)
const EVERY := 5

var atmo: Atmosphere
var hud: Node
var terrain: TerrainBuilder
var day := 0
var kind := ""                     # "", "lights", "colours"
var lanterns: Array[MeshInstance3D] = []
var powder: CPUParticles3D
var _last_tod := 0.0
var _burst_t := 0.0
var _announced := -1


func _ready() -> void:
	var glow := PropFactory.glow_lamp()
	for i in 24:
		var a := i * TAU / 24.0
		var r := 9.0 + 3.0 * (i % 2)
		var p := Vector3(C.x + cos(a) * r, 0, C.z + sin(a) * r)
		p.y = terrain.sample_height(p.x, p.z) + 3.4 + 0.5 * sin(i * 1.7)
		var m := PropFactory.sphere(self, 0.22, p, PropFactory.material(Color.from_hsv(float(i) / 24.0, 0.6, 1.0), 0.4, 0.0, Color.from_hsv(float(i) / 24.0, 0.7, 1.0), 2.5))
		m.visible = false
		lanterns.append(m)
	powder = CPUParticles3D.new()
	powder.one_shot = true
	powder.emitting = false
	powder.amount = 120
	powder.lifetime = 2.6
	powder.explosiveness = 0.9
	powder.direction = Vector3(0, 1, 0)
	powder.spread = 70.0
	powder.initial_velocity_min = 3.0
	powder.initial_velocity_max = 7.0
	powder.gravity = Vector3(0, -2.2, 0)
	powder.scale_amount_min = 0.12
	powder.scale_amount_max = 0.3
	powder.color_initial_ramp = _powder_ramp()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m2 := StandardMaterial3D.new()
	m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m2.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m2.vertex_color_use_as_albedo = true
	m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m2
	powder.mesh = q
	add_child(powder)
	powder.global_position = Vector3(C.x, terrain.sample_height(C.x, C.z) + 1.5, C.z)


func _powder_ramp() -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.95, 0.2, 0.5), Color(1.0, 0.8, 0.1), Color(0.2, 0.7, 1.0), Color(0.3, 0.9, 0.4)])
	g.offsets = PackedFloat32Array([0.0, 0.34, 0.67, 1.0])
	return g


func is_festival_day(d: int) -> bool:
	return d > 0 and d % EVERY == 0


func kind_for(d: int) -> String:
	if not is_festival_day(d):
		return ""
	return "lights" if (d / EVERY) % 2 == 1 else "colours"


func evening() -> bool:
	return atmo != null and atmo.time_of_day > 0.68 and atmo.time_of_day < 0.97


func refresh() -> void:
	kind = kind_for(day)
	var on := kind != "" and evening()
	for l in lanterns:
		l.visible = on and kind == "lights"


func _process(delta: float) -> void:
	if atmo == null:
		return
	if atmo.time_of_day < _last_tod - 0.5:        # the clock wrapped past midnight: a new day
		day += 1
	_last_tod = atmo.time_of_day
	refresh()
	if kind != "" and evening() and _announced != day:
		_announced = day
		hud.banner(Loc.t("Festival of Lights tonight in the bazaar!") if kind == "lights" else Loc.t("Festival of Colours tonight in the bazaar!"), "cheer")
	if kind == "colours" and evening():
		_burst_t -= delta
		if _burst_t <= 0.0:
			_burst_t = 14.0
			powder.restart()
			powder.emitting = true
