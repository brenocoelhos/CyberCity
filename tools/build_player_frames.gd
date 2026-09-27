extends SceneTree
## Only creates Godot resources. Never modifies the supplied PNG.
const SHEET := "res://assets/characters/player_sheet.png"
const OUTPUT := "res://assets/characters/PlayerFrames.tres"

func _initialize() -> void:
	var sheet_image := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	assert(sheet_image != null)
	var texture := load(SHEET) as Texture2D
	assert(texture != null)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var directions := ["baixo", "esquerda", "direita", "cima"]
	var frame_canvas := Vector2i(314, 314)
	for row in range(4):
		var row_frames: Array[AtlasTexture] = []
		for col in range(4):
			# Integer edges cover the whole 1254px sheet with no overlaps or gaps.
			var start := Vector2i(col * sheet_image.get_width() / 4, row * sheet_image.get_height() / 4)
			var end := Vector2i((col + 1) * sheet_image.get_width() / 4, (row + 1) * sheet_image.get_height() / 4)
			var cell := Rect2i(start, end - start)
			var bounds := _visible_bounds(sheet_image, cell)
			var atlas := AtlasTexture.new()
			atlas.resource_name = "linha_%d_coluna_%d" % [row + 1, col + 1]
			atlas.atlas = texture
			atlas.region = Rect2(bounds)
			atlas.filter_clip = true
			# Transparent padding in the resource aligns feet and centers the sprite.
			var padding := frame_canvas - bounds.size
			atlas.margin = Rect2(Vector2(padding.x / 2, padding.y), Vector2(padding))
			row_frames.append(atlas)
		var walk := StringName("andar_" + directions[row])
		var idle := StringName("parado_" + directions[row])
		frames.add_animation(walk)
		frames.set_animation_speed(walk, 8.0)
		frames.set_animation_loop(walk, true)
		for frame_index in range(4):
			# Source row 2 columns 3/4 face right. Never mix them into walk-left.
			var source_col := frame_index % 2 if row == 1 else frame_index
			frames.add_frame(walk, row_frames[source_col])
		frames.add_animation(idle)
		frames.set_animation_speed(idle, 1.0)
		frames.set_animation_loop(idle, true)
		frames.add_frame(idle, row_frames[0])
	assert(ResourceSaver.save(frames, OUTPUT) == OK)
	print("Saved eight animations. Source unchanged; left uses row 2 columns 1,2,1,2.")
	quit()

func _visible_bounds(sheet: Image, cell: Rect2i) -> Rect2i:
	# Find meaningful alpha inside this cell; keep a small margin for the silhouette.
	var first := cell.end
	var last := cell.position
	for y in range(cell.position.y, cell.end.y):
		for x in range(cell.position.x, cell.end.x):
			if sheet.get_pixel(x, y).a > 0.5:
				first = first.min(Vector2i(x, y))
				last = last.max(Vector2i(x, y))
	assert(first.x <= last.x and first.y <= last.y)
	return Rect2i(first, last - first + Vector2i.ONE).grow(2).intersection(cell)
