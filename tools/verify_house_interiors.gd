extends SceneTree
## Verifica o interior de casa configurável pelo prédio: o Building monta o
## pedido, a Door o entrega e o InteriorBase o aplica (NPC e computador).
## Sem pedido, o interior fica como na cena. Não usa a interface.
## Rodar: Godot --headless --path . --script res://tools/verify_house_interiors.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.

const HOUSE := "res://scenes/interiors/HouseInterior.tscn"
const BUILDING := "res://scenes/world/Building.tscn"


func _initialize() -> void:
	await process_frame
	var transition = root.get_node("SceneTransition")
	var ok := true

	# --- sem pedido: interior como na cena (morador da m01 e computador comum) ---
	transition.interior_config = {}
	var house := await _open_house()
	var npc = house.get_node_or_null("Morador")
	ok = _check("padrao: morador existe e inicia a m01", npc != null and npc.get_node("Interaction").mission_to_start == "m01") and ok
	var pc = house.get_node_or_null("Computer")
	ok = _check("padrao: computador existe sem desafio", pc != null and pc.challenge_id == "") and ok
	house.queue_free()
	await process_frame

	# --- com NPC e sem computador ---
	transition.interior_config = {
		"npc_name": "Vizinha",
		"npc_lines": PackedStringArray(["Oi!", "Tchau."]),
		"npc_mission": "",
		"computer_challenge": "",
	}
	house = await _open_house()
	npc = house.get_node_or_null("Morador")
	ok = _check("NPC usa o nome pedido", npc != null and npc.get_node("Interaction").npc_name == "Vizinha") and ok
	ok = _check("NPC usa as falas pedidas", npc.get_node("Interaction").dialogue_lines.size() == 2) and ok
	ok = _check("NPC nao inicia missao", npc.get_node("Interaction").mission_to_start == "") and ok
	ok = _check("etiqueta do NPC acompanha o nome", npc.get_node("NameLabel").text == "Vizinha") and ok
	ok = _check("sem desafio pedido, o computador some", house.get_node_or_null("Computer") == null) and ok
	house.queue_free()
	await process_frame

	# --- sem NPC e com computador de desafio ---
	transition.interior_config = {
		"npc_name": "",
		"npc_lines": PackedStringArray(),
		"npc_mission": "",
		"computer_challenge": "c_roteador",
	}
	house = await _open_house()
	ok = _check("sem nome pedido, o NPC some", house.get_node_or_null("Morador") == null) and ok
	pc = house.get_node_or_null("Computer")
	ok = _check("computador recebe o desafio pedido", pc != null and pc.challenge_id == "c_roteador") and ok
	house.queue_free()
	await process_frame

	# --- Building monta o pedido e a Door o guarda ---
	var scene: PackedScene = load(BUILDING)
	var plain = scene.instantiate()
	root.add_child(plain)
	await process_frame
	ok = _check("Building sem configure_interior: pedido vazio", plain.get_node("Door").interior_config.is_empty()) and ok
	plain.queue_free()
	await process_frame

	var configured = scene.instantiate()
	configured.configure_interior = true
	configured.interior_npc_name = "Moradora"
	configured.interior_npc_lines = PackedStringArray(["Meu wi-fi esta lento."])
	configured.interior_npc_mission = "m11"
	configured.interior_computer_challenge = "c_roteador"
	root.add_child(configured)
	await process_frame
	var config: Dictionary = configured.get_node("Door").interior_config
	ok = _check("Building configurado: pedido chega na Door", config.get("npc_name") == "Moradora" and config.get("npc_mission") == "m11" and config.get("computer_challenge") == "c_roteador" and config.get("npc_lines").size() == 1) and ok
	configured.queue_free()
	await process_frame

	transition.interior_config = {}
	print("RESULTADO: ", "TUDO OK" if ok else "FALHOU")
	quit(0 if ok else 1)


func _open_house() -> Node:
	var house: Node = (load(HOUSE) as PackedScene).instantiate()
	root.add_child(house)
	await process_frame
	return house


func _check(label: String, cond: bool) -> bool:
	print(("  ok   " if cond else "  FAIL ") + label)
	return cond
