class_name Walls
extends RefCounted
## Keeps scripted walkers (NPCs, animals) out of buildings and rocks. They move by setting their position
## directly, so after each step one ray along the step is tested against static bodies; a blocked step is
## cancelled sideways (they slide along the wall instead of walking through it).

static func fix(n: Node3D, prev: Vector3, radius: float) -> bool:
	var cur := n.global_position
	var step := Vector3(cur.x - prev.x, 0.0, cur.z - prev.z)
	var len := step.length()
	if len < 0.002 or not n.is_inside_tree():
		return false
	var dir := step / len
	var space := n.get_world_3d().direct_space_state
	var from := prev + Vector3(0.0, 0.7, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (len + radius))
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	var col := hit["collider"] as Node
	if col == null or not (col is StaticBody3D):
		return false
	var nrm: Vector3 = hit["normal"]
	nrm.y = 0.0
	if nrm.length() < 0.1 or nrm.dot(dir) > -0.2:
		return false                      # a ramp or glancing contact: let it through
	nrm = nrm.normalized()
	var slide := step - nrm * step.dot(nrm)
	var q2 := PhysicsRayQueryParameters3D.create(from, from + slide.normalized() * (slide.length() + radius)) if slide.length() > 0.001 else null
	if q2 != null and space.intersect_ray(q2).is_empty():
		n.global_position = Vector3(prev.x + slide.x, cur.y, prev.z + slide.z)
	else:
		n.global_position = Vector3(prev.x, cur.y, prev.z)
	return true
