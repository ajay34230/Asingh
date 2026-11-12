## Packs every file under DLC_SRC (a folder laid out like res://) into the PCK DLC_OUT.
## Run: DLC_SRC=... DLC_OUT=... godot --headless --path godot --script ../tools/dlc/pack_folder.gd
extends SceneTree

func _initialize() -> void:
	var src := OS.get_environment("DLC_SRC")
	var pck := PCKPacker.new()
	pck.pck_start(OS.get_environment("DLC_OUT"))
	var count := _add(pck, src, src)
	pck.flush(true)
	print("packed %d files" % count)
	quit()

func _add(pck: PCKPacker, root: String, dir: String) -> int:
	var n := 0
	for f in DirAccess.get_files_at(dir):
		pck.add_file("res://" + (dir + "/" + f).trim_prefix(root + "/"), dir + "/" + f)
		n += 1
	for d in DirAccess.get_directories_at(dir):
		n += _add(pck, root, dir + "/" + d)
	return n
