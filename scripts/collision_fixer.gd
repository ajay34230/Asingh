class_name CollisionFixer
extends RefCounted
## Safety net so the player cannot walk through visible solid objects: every large visible mesh
## that has no collision of its own gets a convex-hull collider matching its (scaled) shape.
## Things that are deliberately walk-through (stairs that use a ramp collider, overhead
## cloth, thin wires) are skipped: tag a node with meta "no_auto_collide" to exclude its subtree.

const MIN_HEIGHT := 0.5
const MIN_FOOTPRINT := 0.35
const MAX_SIZE := 300.0


static func _has_solid(mi: MeshInstance3D, root: Node) -> bool:
	var a: Node = mi
	while a != null and a != root:
		if a.has_meta("no_auto_collide"):
			return true
		if a is StaticBody3D or a is CharacterBody3D:
			return true
		for c in a.get_children():
			if c is StaticBody3D:
				return true
		a = a.get_parent()
	return false


## Returns the number of colliders added.
static func apply(root: Node3D, terrain: TerrainBuilder) -> int:
	var added := 0
	var stack: Array[Node] = [root]
	var todo: Array[MeshInstance3D] = []
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.visible:
			continue
		if _has_solid(mi, root):
			continue
		var bb := mi.global_transform * mi.get_aabb()
		var sz := bb.size
		if sz.y < MIN_HEIGHT or maxf(sz.x, sz.z) < MIN_FOOTPRINT or minf(sz.x, sz.z) < 0.08:
			continue
		if sz.x > MAX_SIZE or sz.z > MAX_SIZE:
			continue
		var c := bb.get_center()
		if bb.position.y - terrain.sample_height(c.x, c.z) > 2.0:
			continue                      # hanging overhead (awnings, lamps, wires)
		todo.append(mi)
	for mi in todo:
		var parent := mi.get_parent()
		if parent == null:
			continue
		var shape := mi.mesh.create_convex_shape(true, false) as ConvexPolygonShape3D
		if shape == null:
			continue
		var pts := shape.points
		for i in pts.size():
			pts[i] = pts[i] * mi.scale
		shape.points = pts
		var body := StaticBody3D.new()
		body.name = "AutoCollider"
		# Same position and rotation as the mesh, but scale baked into the points above.
		body.transform = Transform3D(mi.basis.orthonormalized(), mi.position)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		parent.add_child(body)
		added += 1
	return added
