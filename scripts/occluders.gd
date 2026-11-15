class_name Occluders
extends RefCounted
## Performance plan step 4: occlusion culling. Every large solid box collider (building blocks, walls) gets a
## matching box occluder, so whatever stands behind it is not drawn. Thin, small or low boxes are skipped.

static func add_for(root: Node3D) -> int:
	var n := 0
	for c in root.find_children("*", "CollisionShape3D", true, false):
		var cs := c as CollisionShape3D
		var b := cs.shape as BoxShape3D
		if b == null:
			continue
		var s := b.size * cs.global_transform.basis.get_scale().abs()
		if s.y < 2.5 or maxf(s.x, s.z) < 3.0 or minf(s.x, s.z) < 0.15:
			continue
		var oi := OccluderInstance3D.new()
		var bo := BoxOccluder3D.new()
		bo.size = b.size * 0.92            # a little inside the wall, so nothing visible is wrongly hidden
		oi.occluder = bo
		cs.add_child(oi)
		n += 1
	return n
