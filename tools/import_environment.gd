extends SceneTree
## Deterministic asset import: original pixels, exact crops and nearest scaling.
## Run: Godot --headless --path . --script res://tools/import_environment.gd

const DEST := "res://assets/environment/extracted/"
var source: Image
var entries: Array[Dictionary] = []

func _initialize() -> void:
	source = Image.load_from_file(ProjectSettings.globalize_path("res://assets/source/environment_reference.png"))
	assert(source != null and source.get_width() == 1254 and source.get_height() == 1254)
	source.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(DEST)
	var atlas := Image.create(352, 160, false, Image.FORMAT_RGBA8)
	# Interior rectangles exclude the presentation sheet's outlines and gaps.
	var columns := [67, 171, 274, 378, 482, 586, 689, 792, 895, 999, 1103]
	var rows := [72, 177, 278, 380]
	for row in range(4):
		for col in range(11):
			var rect := Rect2i(columns[col], rows[row], 82, 80)
			if row == 0 and col < 6:
				# Grass thumbnails have a decorative frame: exclude it for seamless ground.
				rect = rect.grow(-7)
			var tile := source.get_region(rect)
			tile.resize(32, 32, Image.INTERPOLATE_NEAREST)
			# Terrain must cover the whole cell, even where the source has tiny holes.
			for y in range(32):
				for x in range(32):
					var color := tile.get_pixel(x, y)
					if color.a < 0.95:
						color = tile.get_pixel(16, 16)
					color.a = 1.0
					tile.set_pixel(x, y, color)
			atlas.blit_rect(tile, Rect2i(0, 0, 32, 32), Vector2i(col * 32, row * 32))
			entries.append({"type": "tile", "atlas_cell": [col, row], "source_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "pixels": [32, 32]})
	# Rotations are native pixel rotations; they add the missing orientations.
	for family in range(3):
		var base_col: int = [2, 6, 8][family]
		var tile := atlas.get_region(Rect2i(base_col * 32, 64, 32, 32))
		for turn in range(3):
			tile.rotate_90(CLOCKWISE)
			atlas.blit_rect(tile, Rect2i(0, 0, 32, 32), Vector2i((family * 3 + turn) * 32, 128))
	assert(atlas.save_png(DEST + "terrain_32.png") == OK)
	_extract("house_01", Rect2i(63, 714, 184, 223), Vector2i(64, 64))
	_extract("house_02", Rect2i(269, 690, 220, 256), Vector2i(96, 96))
	_extract("house_03", Rect2i(522, 690, 210, 254), Vector2i(96, 96))
	_extract("house_04", Rect2i(750, 690, 203, 254), Vector2i(96, 96))
	_extract("shop_01", Rect2i(974, 701, 242, 241), Vector2i(96, 96))
	_extract("house_05", Rect2i(59, 944, 229, 270), Vector2i(96, 96))
	_extract("house_06", Rect2i(299, 944, 195, 270), Vector2i(96, 96))
	_extract("shop_02", Rect2i(523, 944, 223, 269), Vector2i(96, 96))
	_extract("house_07", Rect2i(752, 1002, 214, 210), Vector2i(96, 96))
	_extract("house_wide", Rect2i(960, 964, 263, 250), Vector2i(128, 96))
	_extract("tree_round", Rect2i(652, 508, 132, 166), Vector2i(64, 64))
	_extract("tree_tall", Rect2i(776, 470, 117, 157), Vector2i(64, 64))
	_extract("bush", Rect2i(287, 499, 88, 84), Vector2i(32, 32))
	_extract("bush_flowers", Rect2i(201, 499, 84, 85), Vector2i(32, 32))
	_extract("bush_berries", Rect2i(382, 494, 87, 88), Vector2i(32, 32))
	_extract("rock", Rect2i(477, 493, 86, 76), Vector2i(32, 32))
	_extract("lamp", Rect2i(1065, 493, 61, 129), Vector2i(32, 64))
	_extract("bench", Rect2i(62, 601, 127, 66), Vector2i(64, 32))
	_extract("fence", Rect2i(426, 604, 128, 61), Vector2i(64, 32))
	_extract("planter", Rect2i(562, 605, 84, 61), Vector2i(32, 32))
	var manifest := FileAccess.open(DEST + "manifest.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify(entries, "\t"))
	print("Imported 44 terrain cells, 9 road rotations and 20 independent sprites.")
	quit()

func _extract(asset_name: String, rect: Rect2i, canvas_size: Vector2i) -> void:
	var crop := source.get_region(rect)
	# Preserve alpha, aspect ratio and complete silhouette; align feet to bottom.
	var factor := minf(float(canvas_size.x - 2) / rect.size.x, float(canvas_size.y - 2) / rect.size.y)
	var size := Vector2i(maxi(1, roundi(rect.size.x * factor)), maxi(1, roundi(rect.size.y * factor)))
	crop.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	var canvas := Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(crop, Rect2i(Vector2i.ZERO, size), Vector2i((canvas_size.x - size.x) / 2, canvas_size.y - size.y - 1))
	assert(canvas.save_png(DEST + asset_name + ".png") == OK)
	entries.append({"name": asset_name, "source_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "pixels": [canvas_size.x, canvas_size.y], "tiles": [canvas_size.x / 32, canvas_size.y / 32]})
