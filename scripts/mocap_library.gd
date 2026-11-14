class_name MocapLibrary
extends Resource
## Motion-captured animations (from Mixamo, made on its X Bot), converted for our characters by
## tools/bake_mixamo.gd. Per clip, every frame stores each bone's rotation relative to the T-pose, in model space
## (Y up, the character facing +Z, +X its left), and the hips' offset from the T-pose in hip-heights.
## RealHuman plays them (see RealHuman.play_clip and the locomotion clips).
##
## clips[name] = {
##   "fps": 30.0, "n": frames, "len": seconds, "loop": bool,
##   "speed": forward travel of the original in hip-heights per second (the travel itself is removed),
##   "hit": seconds into the clip where the striking hand (or foot) moves fastest,
##   "bones": {our bone name: PackedFloat32Array of n quaternions (x, y, z, w)},
##   "hips": PackedFloat32Array of n offsets (x, y, z), in hip-heights }
## rest_dirs[our bone name] = the X Bot's T-pose direction from that bone to the next one (model space), used to
## line each character's own rest pose up with the X Bot's.

@export var clips: Dictionary = {}
@export var rest_dirs: Dictionary = {}

static var _lib: MocapLibrary
static var _tried := false


static func get_lib() -> MocapLibrary:
	if not _tried:
		_tried = true
		if ResourceLoader.exists("res://assets/anims/mocap.res"):
			_lib = load("res://assets/anims/mocap.res") as MocapLibrary
	return _lib


static func has_clip(n: String) -> bool:
	var l := get_lib()
	return l != null and l.clips.has(n)
