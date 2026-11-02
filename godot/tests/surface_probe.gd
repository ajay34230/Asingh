## Measures the walkable surface height of the board at given world (x, z) points,
## by finding the highest triangle that covers each point.
extends SceneTree

const BOARD := "res://assets/models/01_Board/Royal_India_Final_Ludo_Board.glb"

func _init() -> void:
	var board := (load(BOARD) as PackedScene).instantiate() as Node3D
	get_root().add_child(board)
	var tris: Array[PackedVector3Array] = []
	for mi in _meshes(board):
		if mi.mesh == null:
			continue
		var faces := mi.mesh.get_faces()
		var xf := _world_xf(mi)
		for i in range(0, faces.size(), 3):
			tris.append(PackedVector3Array([xf * faces[i], xf * faces[i + 1], xf * faces[i + 2]]))
	print("triangles: ", tris.size())
	var points := {
		"ring cell (1,6) red start": BoardPath.to_world(1.5, 6.5),
		"ring cell (7,0) top entry": BoardPath.to_world(7.5, 0.5),
		"lane cell (3,7)": BoardPath.to_world(3.5, 7.5),
		"centre (7.5,7.5)": BoardPath.to_world(7.5, 7.5),
		"blue courtyard disc (1.9,3.8)": BoardPath.to_world(1.9, 3.8),
		"blue courtyard floor (2.5,5.5)": BoardPath.to_world(2.5, 5.5),
	}
	for label in points:
		var p: Vector3 = points[label]
		print("%-34s x=%.3f z=%.3f top_y=%.3f" % [label, p.x, p.z, _top_y(tris, p.x, p.z)])
	quit(0)

func _top_y(tris: Array[PackedVector3Array], x: float, z: float) -> float:
	var best := -INF
	for t in tris:
		if t[0].y < best and t[1].y < best and t[2].y < best:
			continue
		if _inside(t, x, z):
			var y := _plane_y(t, x, z)
			if y > best:
				best = y
	return best

func _inside(t: PackedVector3Array, x: float, z: float) -> bool:
	var d1 := _sign(x, z, t[0].x, t[0].z, t[1].x, t[1].z)
	var d2 := _sign(x, z, t[1].x, t[1].z, t[2].x, t[2].z)
	var d3 := _sign(x, z, t[2].x, t[2].z, t[0].x, t[0].z)
	var has_neg := d1 < 0 or d2 < 0 or d3 < 0
	var has_pos := d1 > 0 or d2 > 0 or d3 > 0
	return not (has_neg and has_pos)

func _sign(px: float, pz: float, ax: float, az: float, bx: float, bz: float) -> float:
	return (px - bx) * (az - bz) - (ax - bx) * (pz - bz)

func _plane_y(t: PackedVector3Array, x: float, z: float) -> float:
	var v0 := t[1] - t[0]
	var v1 := t[2] - t[0]
	var denom := v0.x * v1.z - v1.x * v0.z
	if absf(denom) < 1e-9:
		return maxf(t[0].y, maxf(t[1].y, t[2].y))
	var u := ((x - t[0].x) * v1.z - v1.x * (z - t[0].z)) / denom
	var v := (v0.x * (z - t[0].z) - (x - t[0].x) * v0.z) / denom
	return t[0].y + u * v0.y + v * v1.y

## Composes local transforms up the parent chain (works before the node enters the tree).
func _world_xf(node: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_meshes(c))
	return out
