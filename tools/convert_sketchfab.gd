extends SceneTree
## Shrinks downloaded models (models_src/, gitignored) to phone size and saves them to assets/sketchfab/.
## Triangles: Godot's mesh simplifier (ImporterMesh LODs) down to a target count; textures: at most 1024 px.
## Run: godot --headless --path . --script res://tools/convert_sketchfab.gd

const SRC := "C:/Users/ajay/Desktop/Asingh/models_src/"
const OUT := "res://assets/sketchfab/"
## file -> [output name, target triangles]
const JOBS := {
	"morwenna__the_pale_widow.glb": ["morwenna", 15000],
	"sister_vesper__the_veiled_oath.glb": ["vesper", 15000],
	"x/fenwillow-the-meadowlight-wanderer/fenwillow.glb": ["fenwillow", 15000],
	"x/thalvoris-the-hollowcore-revenant/thalvoris.glb": ["thalvoris", 15000],
	"x/overgrown-courtyard-patio-ruin/source/tripo_convert_255855e4-5787-4406-9579-b6dcaeec1173.fbx": ["courtyard_ruin", 20000],
	"x/ruined-stone-bridge-broken-arch/source/tripo_convert_c5c143b1-3d2d-4267-824f-285d4b3f9f43.fbx": ["stone_bridge", 20000],
	"alien_space_nebula_2_skybox.glb": ["nebula_sky", 4000],
	"desert_mud_concrete_house_lowpoly.glb": ["mud_house", 8000],
	"low_poly_desert_village.glb": ["desert_village", 40000],
	"medieval__tavern_west.glb": ["tavern", 12000],
	"jungle_house_3d_model_free.glb": ["jungle_house", 10000],
	"low_poly_wooden_house_rusty_3d_model_free.glb": ["wood_house_a", 8000],
	"rusty_roof_wooden_house_3d_model_free.glb": ["wood_house_b", 10000],
	"wooden_with_rusty_roof_house_3d_model_free.glb": ["wood_house_c", 10000],
	"residential_buildings_ancient_villages.glb": ["ancient_houses", 30000],
	"residential_buildings_villages_country_house.glb": ["country_house", 20000],
	"haunted_house.glb": ["haunted_house", 15000],
	"church.glb": ["church", 20000],
	"collapsed_gothic_chapel_ruin.glb": ["chapel_ruin", 20000],
	"belarusian_village.glb": ["belarus_village", 30000],
	"volgar_village.glb": ["volgar_village", 30000],
	"tree_low_poly_lowpoly.glb": ["tree_low", 3000],
	"grass_pack_lowpoly_game-ready.glb": ["grass_pack", 6000],
	"realistic_vine_plants_3d_model_free.glb": ["vines", 5000],
	"oak_trees_pack_17var_lods_seasons_gameready.glb": ["oak_pack", 25000],
	"zombie_monster_slasher_necromorph.glb": ["necromorph", 15000],
	"x/pine-forest-at-sunset/source/ponderosa_stand_sketchfab.glb": ["pine_stand", 20000],
	"x/realistic-beech-fern-plant-games-film/source/Beech Fern.fbx": ["beech_fern", 3000],
	"x/tree-broken-mossy-branch-pbr-photogrammetry-free/source/mossybranchMesh.fbx": ["mossy_branch", 1500],
	"x/vine-with-branch-3d-model-free/vine_branch.glb": ["vine_branch", 3000],
	"x/free-skybox-fantasy-village/source/basic_skybox_3d_flip.fbx": ["fantasy_sky", 2000],
}
const MAX_TEX := 512                 # phone: 512 px is plenty and a quarter of the memory of 1024


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_tex_n = 0
	for f in JOBS:
		var job: Array = JOBS[f]
		if OS.get_environment("CONV_ONLY") != "" and String(job[0]) != OS.get_environment("CONV_ONLY"):
			continue
		var path: String = SRC + f
		var fbx: bool = String(f).ends_with(".fbx")
		if not fbx and not String(f).ends_with(".glb"):
			var bytes := FileAccess.get_file_as_bytes(path)        # Sketchfab "source" files are GLB without an extension
			var tmp := path.get_base_dir().get_base_dir() + "/" + String(job[0]) + ".glb"    # beside textures/
			var fw := FileAccess.open(tmp, FileAccess.WRITE)
			fw.store_buffer(bytes)
			fw.close()
			path = tmp
		var doc: GLTFDocument = FBXDocument.new() if fbx else GLTFDocument.new()
		var st: GLTFState = FBXState.new() if fbx else GLTFState.new()
		if doc.append_from_file(path, st) != OK:
			print("[conv] cannot load ", f)
			continue
		var total := 0
		for gm in st.get_meshes():
			var im: ImporterMesh = (gm as GLTFMesh).mesh
			for s in im.get_surface_count():
				total += (im.get_surface_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var ratio := clampf(float(job[1]) / maxf(float(total), 1.0), 0.0005, 1.0)
		var out_tris := 0
		var processed: Array = []
		for gm in st.get_meshes():
			var im: ImporterMesh = (gm as GLTFMesh).mesh
			if ratio < 0.95:
				im.generate_lods(75.0, 180.0, [])        # welds by position first, so seams can collapse
			var am := ArrayMesh.new()
			for s in im.get_surface_count():
				var arr := im.get_surface_arrays(s)
				var full: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				var best: PackedInt32Array = full
				var want := int(full.size() * ratio)
				for l in im.get_surface_lod_count(s):
					var li: PackedInt32Array = im.get_surface_lod_indices(s, l)
					if li.size() < best.size() and (li.size() >= want * 0.3 or l == im.get_surface_lod_count(s) - 1):
						best = li
				arr = _compact(arr, best)
				best = arr[Mesh.ARRAY_INDEX]
				# heavy meshes stop early: simplify the reduced mesh again (up to 3 times) until near the target
				for it in 3:
					if ratio >= 0.95 or best.size() <= want * 1.3:
						break
					var again := ImporterMesh.new()
					again.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
					again.generate_lods(80.0, 180.0, [])
					var b2: PackedInt32Array = best
					for l in again.get_surface_lod_count(0):
						var li2: PackedInt32Array = again.get_surface_lod_indices(0, l)
						if li2.size() < b2.size() and (li2.size() >= want * 0.3 or l == again.get_surface_lod_count(0) - 1):
							b2 = li2
					if b2.size() >= best.size():
						break
					arr = _compact(arr, b2)
					best = arr[Mesh.ARRAY_INDEX]
				out_tris += best.size() / 3
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
				var mat := im.get_surface_material(s)
				if mat is BaseMaterial3D:
					_shrink((mat as BaseMaterial3D), String(job[0]))
				am.surface_set_material(s, mat)
			processed.append(am)
			(gm as GLTFMesh).mesh = ImporterMesh.new()
			for s in am.get_surface_count():
				(gm as GLTFMesh).mesh.add_surface(Mesh.PRIMITIVE_TRIANGLES, am.surface_get_arrays(s), [], {}, am.surface_get_material(s))
		if OS.get_environment("CONV_PASS") == "tex":
			print("[conv] %s: textures written" % job[0])
			continue
		var root := doc.generate_scene(st) as Node3D
		if fbx:
			# the FBX reader rebuilds meshes from its own data: put the reduced ones in directly
			var k := 0
			for mi in root.find_children("*", "MeshInstance3D", true, false):
				if k < processed.size():
					(mi as MeshInstance3D).mesh = processed[k]
					(mi as MeshInstance3D).material_override = null
				k += 1
		for n in root.find_children("*", "", true, false):
			n.owner = root
		var ps := PackedScene.new()
		ps.pack(root)
		var err := ResourceSaver.save(ps, OUT + String(job[0]) + ".scn", ResourceSaver.FLAG_COMPRESS)
		print("[conv] %s: %d -> %d triangles, saved %s (err %d)" % [job[0], total, out_tris, OUT + String(job[0]) + ".scn", err])
		root.free()
	quit()


var _tex_n := 0
var _seen := {}                    # image hash -> saved texture path


func _shrink(m: BaseMaterial3D, model: String) -> void:
	for p in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "emission_texture", "ao_texture", "orm_texture"]:
		var t = m.get(p)
		if t is Texture2D:
			if (t as Texture2D).resource_path.begins_with(OUT):
				continue                      # already swapped for the saved file (materials shared by several surfaces)
			var img: Image = (t as Texture2D).get_image()
			if img == null:
				continue
			if img.is_compressed():
				img.decompress()
			if img.get_width() > MAX_TEX or img.get_height() > MAX_TEX:
				var k := float(MAX_TEX) / maxf(img.get_width(), img.get_height())
				img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
			# saved as an imported JPG (small file, compressed by Godot), not raw pixels inside the scene
			# one file per distinct image: village models reuse the same picture across dozens of materials
			var key := hash(img.get_data()) ^ (img.get_width() << 20) ^ img.get_height()
			var tp: String
			if OS.get_environment("CONV_DEBUG") != "":
				print("[conv]   ", p, " key ", key, " ", img.get_width(), "x", img.get_height())
			if _seen.has(key):
				tp = _seen[key]
			else:
				tp = OUT + "tex/t_%08x.jpg" % (key & 0xffffffff)     # named by content, so both passes agree
				_tex_n += 1
				_seen[key] = tp
			if OS.get_environment("CONV_PASS") == "tex":
				DirAccess.make_dir_recursive_absolute(OUT + "tex")
				if FileAccess.file_exists(tp) or FileAccess.file_exists(tp.replace(".jpg", ".png")):
					continue
				if img.detect_alpha() != Image.ALPHA_NONE:
					tp = tp.replace(".jpg", ".png")
					img.save_png(ProjectSettings.globalize_path(tp))
				else:
					img.save_jpg(ProjectSettings.globalize_path(tp), 0.88)
			elif ResourceLoader.exists(tp.replace(".jpg", ".png")):
				m.set(p, load(tp.replace(".jpg", ".png")))
			elif ResourceLoader.exists(tp):
				m.set(p, load(tp))
			else:
				print("[conv]   no saved texture for ", tp, " key ", key)
				img.generate_mipmaps()
				m.set(p, ImageTexture.create_from_image(img))


## Keeps only the vertices the reduced triangle list uses (otherwise every original vertex is still stored).
func _compact(arr: Array, idx: PackedInt32Array) -> Array:
	var remap := {}
	var order := PackedInt32Array()
	var ni := PackedInt32Array()
	ni.resize(idx.size())
	for k in idx.size():
		var o := idx[k]
		if not remap.has(o):
			remap[o] = order.size()
			order.append(o)
		ni[k] = remap[o]
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for t in Mesh.ARRAY_MAX:
		var a = arr[t]
		if a == null or t == Mesh.ARRAY_INDEX:
			continue
		var per := 1
		if t == Mesh.ARRAY_TANGENT:
			per = 4
		elif (t == Mesh.ARRAY_BONES or t == Mesh.ARRAY_WEIGHTS):
			per = (a.size() / maxi((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 1))
		var b = a.duplicate()
		b.resize(order.size() * per)
		for k in order.size():
			for j in per:
				b[k * per + j] = a[order[k] * per + j]
		out[t] = b
	out[Mesh.ARRAY_INDEX] = ni
	return out
