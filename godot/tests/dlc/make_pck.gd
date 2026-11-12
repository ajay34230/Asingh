## Builds a tiny test PCK (res://dlc_test/hello.txt) for the DLC download test.
extends SceneTree
func _initialize() -> void:
	var out := OS.get_environment("DLC_PCK_OUT")
	var src := OS.get_environment("DLC_PCK_SRC")
	var pck := PCKPacker.new()
	pck.pck_start(out)
	pck.add_file("res://dlc_test/hello.txt", src)
	# Padding so the download takes several chunks and can be interrupted.
	pck.flush(true)
	quit()
