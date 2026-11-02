extends RefCounted
## Called by import_environment.gd. Source rectangles use cyber_exterior.jpg.
const DEST = "res://assets/environment/cyber/"
var source: Image

func run() -> void:
	source = Image.load_from_file(ProjectSettings.globalize_path("res://assets/source/cyber_exterior.jpg"))
	source.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(DEST)
	var buildings = [Rect2i(850, 228, 68, 167), Rect2i(920, 228, 69, 167), Rect2i(991, 228, 67, 167), Rect2i(1059, 228, 65, 167), Rect2i(1125, 228, 47, 167), Rect2i(1173, 228, 62, 167), Rect2i(1236, 228, 49, 167), Rect2i(1286, 228, 73, 167)]
	for i in range(buildings.size()):
		crop("building_%d" % i, buildings[i], Vector2i(96, 224))
	crop("tech_center", Rect2i(1398, 222, 171, 286), Vector2i(160, 288))
	var original_source = source
	var refined_path = ProjectSettings.globalize_path("res://assets/source/cyber_buildings_clean.png")
	if FileAccess.file_exists(refined_path):
		source = Image.load_from_file(refined_path)
		source.convert(Image.FORMAT_RGBA8)
		for py in range(source.get_height()):
			for px in range(source.get_width()):
				if source.get_pixel(px,py).a < 0.9:
					source.set_pixel(px,py,Color.TRANSPARENT)
		var cell = Vector2i(source.get_width()/4,source.get_height()/2)
		for i in range(8):
			var region = Rect2i(Vector2i(i%4,i/4)*cell,cell)
			var bounds = source.get_region(region).get_used_rect()
			bounds.position += region.position
			crop("building_%d" % i,bounds,Vector2i(96,224))
		source = original_source
	var variety_path = ProjectSettings.globalize_path("res://assets/source/cyber_buildings_variety.png")
	if FileAccess.file_exists(variety_path):
		source = Image.load_from_file(variety_path)
		source.convert(Image.FORMAT_RGBA8)
		for py in range(source.get_height()):
			for px in range(source.get_width()):
				if source.get_pixel(px,py).a < 0.9:
					source.set_pixel(px,py,Color.TRANSPARENT)
		var cell = Vector2i(source.get_width()/6,source.get_height()/2)
		for i in range(12):
			var region = Rect2i(Vector2i(i%6,i/6)*cell,cell)
			var bounds = source.get_region(region).get_used_rect()
			bounds.position += region.position
			crop("building_%d" % (8+i),bounds,Vector2i(96,224))
		source = original_source
	crop("bench", Rect2i(20, 249, 54, 46), Vector2i(64, 32))
	crop("planter", Rect2i(248, 320, 63, 43), Vector2i(64, 32))
	crop("lamp", Rect2i(488, 239, 25, 74), Vector2i(32, 96))
	crop("kiosk", Rect2i(364, 244, 37, 65), Vector2i(32, 64))
	crop("shelter", Rect2i(580, 240, 98, 74), Vector2i(96, 96))
	crop("bin", Rect2i(296, 247, 27, 48), Vector2i(32, 32))
	crop("tree", Rect2i(1300, 105, 58, 66), Vector2i(64, 96))
	crop("flowers", Rect2i(1360, 108, 56, 62), Vector2i(64, 64))
	var atlas = Image.load_from_file(ProjectSettings.globalize_path("res://assets/environment/extracted/terrain_32.png"))
	# Keep all road junctions and their atlas coordinates compatible.
	for y in range(atlas.get_height()):
		for x in range(atlas.get_width()):
			var c = atlas.get_pixel(x, y)
			atlas.set_pixel(x, y, Color(c.r * 0.55, c.g * 0.62, c.b * 0.8, c.a))
	var tiles = [[Vector2i(0,1), Rect2i(14,48,43,53)], [Vector2i(2,1), Rect2i(195,48,49,53)]]
	for entry in tiles:
		var tile = source.get_region(entry[1])
		tile.resize(32,32,Image.INTERPOLATE_NEAREST)
		atlas.blit_rect(tile,Rect2i(0,0,32,32),entry[0]*32)
	for i in range(6):
		var tile = source.get_region(Rect2i(1305 + mini(i,2)*55,48,49,49))
		tile.resize(32,32,Image.INTERPOLATE_NEAREST)
		atlas.blit_rect(tile,Rect2i(0,0,32,32),Vector2i(i*32,0))
	assert(atlas.save_png(DEST+"terrain_32.png") == OK)
	print("Cyber exterior imported.")

func crop(asset_name: String, rect: Rect2i, canvas_size: Vector2i) -> void:
	var cut = source.get_region(rect)
	# Remove only dark backdrop connected to the crop edges, preserving windows.
	var queue: Array[Vector2i] = []
	for x in range(cut.get_width() if asset_name.begins_with("building_") == false else 0):
		queue.append(Vector2i(x,0))
		queue.append(Vector2i(x,cut.get_height()-1))
	for y in range(cut.get_height() if asset_name.begins_with("building_") == false else 0):
		queue.append(Vector2i(0,y))
		queue.append(Vector2i(cut.get_width()-1,y))
	var seen = {}
	while not queue.is_empty():
		var pos = queue.pop_back()
		if seen.has(pos) or pos.x < 0 or pos.y < 0 or pos.x >= cut.get_width() or pos.y >= cut.get_height():
			continue
		seen[pos] = true
		var c = cut.get_pixelv(pos)
		if c.r > 0.10 or c.g > 0.16 or c.b > 0.20:
			continue
		cut.set_pixelv(pos, Color.TRANSPARENT)
		for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			queue.append(pos+delta)
	var factor = minf(float(canvas_size.x-2)/rect.size.x,float(canvas_size.y-2)/rect.size.y)
	var size = Vector2i(roundi(rect.size.x*factor),roundi(rect.size.y*factor))
	cut.resize(size.x,size.y,Image.INTERPOLATE_NEAREST)
	var canvas = Image.create(canvas_size.x,canvas_size.y,false,Image.FORMAT_RGBA8)
	canvas.blit_rect(cut,Rect2i(Vector2i.ZERO,size),Vector2i((canvas_size.x-size.x)/2,canvas_size.y-size.y))
	assert(canvas.save_png(DEST+asset_name+".png") == OK)
