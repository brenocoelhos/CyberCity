extends SceneTree
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var city: Node2D = load("res://scenes/world/City.tscn").instantiate()
	root.add_child(city)
	await process_frame
	await process_frame
	var textures: Array[String] = []
	_check_npc(city.get_node("Vizinho"), textures)
	for building in city.get_node("Buildings").get_children():
		root.get_node("SceneTransition").interior_title = building.building_name
		root.get_node("SceneTransition").interior_config = building._build_interior_config()
		var interior: Node = load(building.interior_path).instantiate()
		root.add_child(interior)
		await process_frame
		await process_frame
		var npc: Node = interior.get_node_or_null("Morador")
		if npc == null:
			npc = interior.get_node("Funcionario")
		_check_npc(npc,textures)
		interior.queue_free()
		await process_frame
	assert(textures.size() == 11)
	print("PASS: 11 actual NPC instances across city and ten interiors, all unique static textures and portraits.")
	quit()

func _check_npc(npc: Node, textures: Array[String]) -> void:
	var sprite: Sprite2D = npc.get_node("Sprite2D")
	assert(sprite.texture != null)
	assert(not textures.has(sprite.texture.resource_path), "Duplicate NPC design: "+sprite.texture.resource_path)
	textures.append(sprite.texture.resource_path)
	assert(sprite.texture.get_size() == Vector2(314,314))
	assert(sprite.scale == Vector2(0.125,0.125))
	assert(npc.get_node("Interaction")._portrait() == sprite.texture)
	assert(npc.get_node_or_null("AnimatedSprite2D") == null)
