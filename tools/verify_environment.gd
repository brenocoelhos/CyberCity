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
	assert(ground.get_used_cells().size() == city.MAP_WIDTH * city.MAP_HEIGHT)
	# Cruzamento de 4 vias, T, curva do anel, retas e faixas de pedestre.
	assert(ground.get_cell_atlas_coords(Vector2i(21, 13)) == Vector2i(4, 2))
	assert(ground.get_cell_atlas_coords(Vector2i(21, 2)) == Vector2i(6, 2))
	assert(ground.get_cell_atlas_coords(Vector2i(2, 2)) == Vector2i(2, 4))
	assert(ground.get_cell_atlas_coords(Vector2i(10, 13)) == Vector2i(1, 2))
	assert(ground.get_cell_atlas_coords(Vector2i(21, 8)) == Vector2i(0, 2))
	assert(ground.get_cell_atlas_coords(Vector2i(24, 13)) == Vector2i(7, 2))
	assert(ground.get_cell_atlas_coords(Vector2i(21, 16)) == Vector2i(7, 2))
	assert(ground.get_cell_alternative_tile(Vector2i(21, 16)) == TileSetAtlasSource.TRANSFORM_TRANSPOSE)
	assert(ground.get_cell_atlas_coords(Vector2i(10, 12)) == Vector2i(0, 1))
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
		# Cada porta fica na calçada, de frente para uma rua.
		var door_cell := ground.local_to_map(door.global_position)
		assert(ground.get_cell_atlas_coords(door_cell) == Vector2i(0, 1))
	var building_count: int = city.get_node("Buildings").get_child_count()
	assert(city.get_node("Buildings/PredioTecnologia/Door").locked)
	for scene_name in ["HouseInterior", "OfficeInterior", "TechCenterInterior", "AppInterior"]:
		var interior: Node = load("res://scenes/interiors/" + scene_name + ".tscn").instantiate()
		assert(interior != null)
		interior.free()
	print("PASS: %d cells, 32px grid, road pieces, %d facades, accessible doors and 4 interiors." % [city.MAP_WIDTH * city.MAP_HEIGHT, building_count])
	if "--preview" in OS.get_cmdline_user_args():
		city.get_node("UI").hide()
		for child in root.get_children():
			if child is CanvasLayer:
				child.hide()
		player.global_position = Vector2(1024, 320)
		await physics_frame
		await physics_frame
		await physics_frame
		player.get_node("Camera2D").enabled = false
		var map_size := Vector2i(city.MAP_WIDTH * 32, city.MAP_HEIGHT * 32)
		root.size = map_size
		root.content_scale_size = map_size
		var camera := Camera2D.new()
		camera.position = Vector2(map_size) / 2.0
		city.add_child(camera)
		camera.make_current()
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := root.get_texture().get_image()
		assert(rendered.save_png("res://docs/city_preview.png") == OK)
		print("Saved docs/city_preview.png")
	quit()
