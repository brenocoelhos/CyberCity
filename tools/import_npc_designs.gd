extends SceneTree
## Eleven unique static designs. Same 314px canvas and 0.125 display scale as player.
func _initialize() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/npcs/unique_designs_source.png"))
	assert(source != null)
	source.convert(Image.FORMAT_RGBA8)
	var names := ["guide","house1","house2","house3","house4","house5","house6","techcorp","datasoft","scientist","developer"]
	var column_width := source.get_width()/4
	# Source row baselines are uneven; crop the verified bands without cutting feet.
	var row_edges := [0,roundi(source.get_height()*0.385),roundi(source.get_height()*0.685),source.get_height()]
	for i in range(11):
		var row := i/4
		var crop := source.get_region(Rect2i((i%4)*column_width,row_edges[row],column_width,row_edges[row+1]-row_edges[row]))
		for y in range(crop.get_height()):
			for x in range(crop.get_width()):
				if crop.get_pixel(x,y).a < 0.9:
					crop.set_pixel(x,y,Color.TRANSPARENT)
		var bounds := crop.get_used_rect()
		assert(bounds.has_area())
		crop = crop.get_region(bounds)
		var factor := 280.0/crop.get_height()
		crop.resize(roundi(crop.get_width()*factor),280,Image.INTERPOLATE_NEAREST)
		var canvas := Image.create(314,314,false,Image.FORMAT_RGBA8)
		canvas.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i((314-crop.get_width())/2,34))
		assert(canvas.save_png("res://assets/characters/npcs/"+names[i]+".png") == OK)
	print("PASS: eleven static NPC sprites, 314px canvas, 35px visible height in game.")
	quit()
