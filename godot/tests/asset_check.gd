## Loads every supplied GLB through Godot's importer and reports its real bounds.
## godot --headless --path . --script res://tests/asset_check.gd
extends SceneTree

const FILES := [
	"01_Board/Royal_India_Final_Ludo_Board.glb",
	"02_Dice/Royal_India_Royal_Jewel_Dice.glb",
	"03_Player_Tokens/Royal_Red_Token.glb",
	"03_Player_Tokens/Royal_Green_Token.glb",
	"03_Player_Tokens/Royal_Blue_Token.glb",
	"03_Player_Tokens/Royal_Yellow_Token.glb",
	"04_Character_Limbs/Royal_Red_Token_Folding_Limbs.glb",
	"04_Character_Limbs/Royal_Green_Token_Folding_Limbs.glb",
	"04_Character_Limbs/Royal_Blue_Token_Folding_Limbs.glb",
	"04_Character_Limbs/Royal_Yellow_Token_Folding_Limbs.glb",
	"05_Animals_and_Statues/Royal_India_Elephant.glb",
	"05_Animals_and_Statues/Royal_India_Elephant_Statue.glb",
	"05_Animals_and_Statues/Royal_India_Peacock_HighPoly_Textured.glb",
	"05_Animals_and_Statues/Royal_India_Peacock_Statue.glb",
	"06_Decorations/Royal_India_Deepam_Lamp_Set.glb",
	"06_Decorations/Royal_India_Lotus_Fountain.glb",
]

var _ok := 0
var _failed: Array[String] = []


func _init() -> void:
	for rel in FILES:
		var path: String = "res://assets/models/" + rel
		var packed := load(path) as PackedScene
		if packed == null:
			_failed.append(rel)
			continue
		var root := packed.instantiate()
		var box := _aabb_of(root)
		print("OK  %-70s size=(%.3f, %.3f, %.3f) meshes=%d" % [rel, box.size.x, box.size.y, box.size.z, _count_meshes(root)])
		_ok += 1
		root.free()
	print("%d/%d models imported" % [_ok, FILES.size()])
	for rel in _failed:
		print("FAILED to import: " + rel)
	quit(0 if _failed.is_empty() else 1)


func _aabb_of(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for mi in _meshes(node):
		var box: AABB = mi.global_transform * mi.get_aabb() if node.is_inside_tree() else mi.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result


func _count_meshes(node: Node) -> int:
	return _meshes(node).size()


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out
