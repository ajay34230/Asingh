## Brings a RoboPawn to life: the head looks around, eyelids blink, the chest reactor
## pulses, the pedestal's inner ring turns and the crest idles (ears twitch, the
## peacock fan breathes, fins ripple, antennae sway). Victory and defeat reactions
## are played on request.
class_name RoboAnimator
extends Node3D

var head: Node3D
var lids: Array = []
var crest: Node3D
var kind := ""
var _t := 0.0
var _phase := randf() * TAU
var _next_blink := randf_range(1.0, 4.0)
var _blink := -1.0
var _celebrate := -1.0
var _defeat := -1.0
var _defeat_len := 1.0
var _spin: Node3D
var _core: MeshInstance3D
var _iris: Array = []


func _ready() -> void:
	var body := get_parent()
	_spin = body.get_node_or_null("PedestalSpin")
	_core = body.get_node_or_null("Reactor/ReactorCore")
	for eye in head.find_children("Eye", "", false, false):
		var iris := eye.get_node_or_null("Iris")
		if iris:
			_iris.append(iris)


func _process(delta: float) -> void:
	_t += delta
	var token := get_parent().get_parent()
	var plain := token == null or String(token.get_meta("design", "design_classic")) == "design_classic"
	## Head: slow look-around (only when no design gear sits on the body's head mount).
	if plain and _defeat < 0.0:
		head.rotation.y = sin(_t * 0.55 + _phase) * 0.28
		head.rotation.x = sin(_t * 0.37 + _phase * 2.0) * 0.06
	## Blink.
	_next_blink -= delta
	if _next_blink <= 0.0 and _blink < 0.0:
		_blink = 0.0
		_next_blink = randf_range(2.0, 5.0)
	if _blink >= 0.0:
		_blink += delta / 0.16
		var c := sin(clampf(_blink, 0.0, 1.0) * PI)
		for lid in lids:
			(lid as Node3D).rotation.x = lerpf(-1.55, 0.1, c)
		if _blink >= 1.0:
			_blink = -1.0
	## Reactor pulse and pedestal ring.
	if _core:
		var k := 1.0 + 0.12 * sin(_t * 3.2 + _phase)
		_core.scale = Vector3.ONE * k
	if _spin:
		_spin.rotation.y += delta * 0.6
	## Crest idle / victory.
	var party := 0.0
	if _celebrate >= 0.0:
		_celebrate += delta
		party = clampf(sin(minf(_celebrate / 1.6, 1.0) * PI), 0.0, 1.0)
		if _celebrate > 1.6:
			_celebrate = -1.0
	match kind:
		"green":
			for ear in crest.get_children():
				var side := signf(ear.position.x)
				ear.rotation.z = side * -0.45 + sin(_t * 2.2 + _phase) * 0.06 * side - party * side * 0.5
				ear.rotation.y = party * TAU * side * 0.5
		"red":
			var fan := crest.get_node_or_null("Fan")
			if fan:
				fan.scale = Vector3.ONE * (1.0 + sin(_t * 1.4 + _phase) * 0.03 + party * 0.35)
				fan.rotation.x = -0.35 - party * 0.4
				var i := 0
				for f in fan.get_children():
					if f.name.begins_with("Feather"):
						f.rotation.z = lerpf(-1.15, 1.15, i / 8.0) * (1.0 + party * 0.25) + sin(_t * 2.0 + i) * 0.02
						i += 1
		"blue":
			var i := 0
			for fin in crest.get_children():
				var t := (i - 2) / 2.0
				fin.rotation.x = -0.25 - t * 0.3 + sin(_t * 3.0 - i * 0.7) * 0.06 - party * 0.45
				fin.rotation.z = (0.16 if i % 2 == 0 else -0.16) * (1.0 + party)
				i += 1
		_:
			for ant in crest.get_children():
				var side := signf(ant.position.x)
				ant.rotation.z = -side * 0.35 + sin(_t * 1.8 + side) * 0.08 - party * side * 0.4
	## Defeat: flickering eyes, drooping head.
	if _defeat >= 0.0:
		_defeat += delta
		var on := fmod(_defeat * 9.0, 1.0) > 0.4 or _defeat > _defeat_len * 0.7
		for iris in _iris:
			(iris as Node3D).visible = on
		head.rotation.x = lerpf(head.rotation.x, 0.35, minf(1.0, delta * 6.0))
		if _defeat > _defeat_len:
			_defeat = -1.0
			for iris in _iris:
				(iris as Node3D).visible = true


func celebrate() -> void:
	_celebrate = 0.0


func defeated(seconds: float) -> void:
	_defeat = 0.0
	_defeat_len = seconds
