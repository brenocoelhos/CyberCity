extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var player: CharacterBody2D = load("res://scenes/player/Player.tscn").instantiate()
	root.add_child(player)
	player.get_node("Camera2D").enabled = false
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	var frames := sprite.sprite_frames
	var names := ["baixo", "esquerda", "direita", "cima"]
	var actions := ["move_down", "move_left", "move_right", "move_up"]
	assert(frames.get_animation_names().size() == 8)
	for index in range(4):
		var direction: String = names[index]
		assert(frames.get_frame_count("andar_" + direction) == 4)
		assert(frames.get_frame_count("parado_" + direction) == 1)
		for frame in range(4):
			var atlas: AtlasTexture = frames.get_frame_texture("andar_" + direction, frame)
			assert(atlas.region.position.y >= floori(index * 1254.0 / 4.0))
			assert(atlas.region.end.y <= floori((index + 1) * 1254.0 / 4.0))
			if index == 1:
				assert(atlas.region.end.x <= 627)
		Input.action_press(actions[index])
		await physics_frame
		await physics_frame
		await physics_frame
		assert(sprite.animation == StringName("andar_" + direction))
		assert(is_equal_approx(player.velocity.length(), player.speed))
		assert(not sprite.flip_h)
		Input.action_release(actions[index])
		await physics_frame
		await physics_frame
		assert(sprite.animation == StringName("parado_" + direction))
		assert(sprite.frame == 0 and player.velocity == Vector2.ZERO)
	Input.action_press("move_right")
	Input.action_press("move_up")
	await physics_frame
	await physics_frame
	assert(is_equal_approx(player.velocity.length(), player.speed))
	assert(sprite.animation == &"andar_direita")
	var previous_frame := sprite.frame
	await create_timer(0.16).timeout
	assert(sprite.frame != previous_frame)
	root.get_node("DialogueManager").start_dialogue("Teste", PackedStringArray(["Pausa"]))
	await physics_frame
	await physics_frame
	assert(player.velocity == Vector2.ZERO)
	assert(sprite.animation == &"parado_direita")
	assert(player.get_node("FootstepTimer").is_stopped())
	Input.action_release("move_right")
	Input.action_release("move_up")
	print("PASS: eight animations, correct source rows, four directions and diagonal at equal speed, idle memory, animation progress and dialogue pause.")
	if "--preview" in OS.get_cmdline_user_args():
		player.queue_free()
		await process_frame
		for child in root.get_children():
			if child is CanvasLayer:
				child.hide()
		root.size = Vector2i(640, 500)
		root.content_scale_size = Vector2i(640, 500)
		var background := ColorRect.new()
		background.color = Color("526977")
		background.size = Vector2(640, 500)
		root.add_child(background)
		for row in range(4):
			var label := Label.new()
			label.text = names[row]
			label.position = Vector2(16, 50 + row * 110)
			root.add_child(label)
			for col in range(4):
				var sample := AnimatedSprite2D.new()
				sample.sprite_frames = frames
				sample.animation = StringName("andar_" + names[row])
				sample.frame = col
				sample.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sample.scale = Vector2(0.25, 0.25)
				sample.position = Vector2(170 + col * 125, 60 + row * 110)
				root.add_child(sample)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://docs/player_preview.png") == OK)
		print("Saved docs/player_preview.png")
	quit()
