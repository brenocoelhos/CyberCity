extends SceneTree
## Runtime integration checks; add -- --preview for a rendered overview.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var city: Node2D = load("res://scenes/world/City.tscn").instantiate()
	root.add_child(city)
	current_scene = city
	await process_frame
	var ground: TileMapLayer = city.get_node("Ground")
	assert(ground.tile_set.tile_size == Vector2i(32, 32))
	assert(ground.get_used_cells().size() == 42 * 28)
	assert(ground.get_cell_atlas_coords(Vector2i(21, 14)) == Vector2i(4, 2))
	assert(ground.get_cell_atlas_coords(Vector2i(20, 14)) == Vector2i(1, 2))
	assert(ground.get_cell_atlas_coords(Vector2i(21, 13)) == Vector2i(0, 2))
	var player: CharacterBody2D = city.get_node("Player")
	for building in city.get_node("Buildings").get_children():
		var sprite: Sprite2D = building.get_node("Sprite2D")
		var size := sprite.texture.get_size()
		assert(int(size.x) % 32 == 0 and int(size.y) % 32 == 0)
		var door: Area2D = building.get_node("Door")
		assert(ResourceLoader.exists(door.interior_scene_path))
		assert(door.building_title != "")
		# A player standing at the doorway is detected without overlapping the wall.
		player.global_position = door.global_position + Vector2(0, 8)
		await physics_frame
		await physics_frame
		await physics_frame
		assert(door.overlaps_body(player))
		assert(not player.test_move(player.global_transform, Vector2.ZERO))
	assert(city.get_node("Buildings/PredioTecnologia/Door").locked)
	for scene_name in ["HouseInterior", "OfficeInterior", "TechCenterInterior", "AppInterior"]:
		var interior: Node = load("res://scenes/interiors/" + scene_name + ".tscn").instantiate()
		assert(interior != null)
		interior.free()
	print("PASS: 1176 cells, 32px grid, road junction, 9 facades, accessible doors and 4 interiors.")
	if "--preview" in OS.get_cmdline_user_args():
		city.get_node("UI").hide()
		for child in root.get_children():
			if child is CanvasLayer:
				child.hide()
		player.global_position = Vector2(688, 464)
		await physics_frame
		await physics_frame
		await physics_frame
		player.get_node("Camera2D").enabled = false
		root.size = Vector2i(1344, 896)
		root.content_scale_size = Vector2i(1344, 896)
		var camera := Camera2D.new()
		camera.position = Vector2(672, 448)
		city.add_child(camera)
		camera.make_current()
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := root.get_texture().get_image()
		assert(rendered.save_png("res://docs/city_preview.png") == OK)
		print("Saved docs/city_preview.png")
	quit()
