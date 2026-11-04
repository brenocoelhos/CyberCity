extends SceneTree
## Verifica o mapa grande da cidade: abre ao clicar no minimapa e com a tecla M,
## mostra o nome de todos os prédios sem etiquetas se sobrepondo, bloqueia o
## jogo enquanto aberto e fecha com ESC/M/Fechar.
## Rodar: Godot --headless --path . --script res://tools/verify_city_map.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.

const CITY := "res://scenes/world/City.tscn"


func _initialize() -> void:
	await process_frame
	var hud = root.get_node("HUD")
	var dialogue = root.get_node("DialogueManager")
	var ok := true

	var city: Node = (load(CITY) as PackedScene).instantiate()
	root.add_child(city)
	await process_frame
	await process_frame
	dialogue.force_close()
	var map = city.city_map
	ok = _check("a cidade cria o mapa grande", map != null and not map.is_open()) and ok
	ok = _check("minimapa deixa o clique passar", city.minimap_container.mouse_filter == Control.MOUSE_FILTER_IGNORE) and ok

	# --- abrir pelo clique no minimapa ---
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	city._on_minimap_input(click)
	await process_frame
	ok = _check("clicar no minimapa abre o mapa", map.is_open() and map.visible) and ok
	ok = _check("jogo fica parado com o mapa aberto", hud.is_popup_active()) and ok

	# --- etiquetas ---
	var names: Array = []
	var pills: Array = []
	_collect(map._markers, names, pills)
	for wanted in ["Casa 1", "Casa 2", "Casa 3", "Casa 4", "Casa 5", "Casa 6", "TechCorp Ltda.", "DataSoft Sistemas", "Centro de Tecnologia", "Loja Eletrônica", "Terminal Público", "Salvar o jogo", "Você"]:
		var found := false
		for text in names:
			if String(text).begins_with(wanted):
				found = true
		ok = _check("etiqueta: " + wanted, found) and ok
	var districts := 0
	for text in names:
		if String(text) in ["BAIRRO RESIDENCIAL", "PRAÇA CENTRAL", "DISTRITO EMPRESARIAL", "VILA RESIDENCIAL", "CENTRO DE TECNOLOGIA", "COMÉRCIO"]:
			districts += 1
	ok = _check("os 6 bairros aparecem", districts == 6) and ok

	var overlap := false
	var outside := false
	var view := Rect2(Vector2.ZERO, Vector2(map.VIEW_SIZE))
	for i in range(pills.size()):
		if not view.encloses(pills[i]):
			outside = true
		for j in range(i + 1, pills.size()):
			if (pills[i] as Rect2).intersects(pills[j]):
				overlap = true
	ok = _check("nenhuma etiqueta de lugar se sobrepoe", not overlap) and ok
	ok = _check("todas as etiquetas ficam dentro do mapa", not outside) and ok

	# --- textos pequenos do mundo nao aparecem no mapa (mas continuam no jogo) ---
	var sign_label: Label = city.get_node("Districts/PlacaPraca")
	var map_viewport: SubViewport = map._container.get_child(0)
	ok = _check("placas pequenas dos bairros saem do mapa", sign_label.visibility_layer == map.WORLD_TEXT_LAYER and (map_viewport.canvas_cull_mask & map.WORLD_TEXT_LAYER) == 0) and ok
	ok = _check("o jogo normal continua vendo as placas", sign_label.visible and (root.canvas_cull_mask & map.WORLD_TEXT_LAYER) != 0) and ok

	# --- o objetivo da missao fica marcado ---
	ok = _check("objetivo atual recebe um anel", map._ring != null) and ok

	# --- fechar ---
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	map._unhandled_input(esc)
	ok = _check("ESC fecha o mapa e solta o jogo", not map.is_open() and not hud.is_popup_active()) and ok
	var key_m := InputEventKey.new()
	key_m.keycode = KEY_M
	key_m.pressed = true
	map._unhandled_input(key_m)
	ok = _check("tecla M abre", map.is_open()) and ok
	map._unhandled_input(key_m)
	ok = _check("tecla M fecha", not map.is_open() and not hud.is_popup_active()) and ok

	# --- nao abre por cima de um dialogo ---
	dialogue.start_dialogue("Teste", PackedStringArray(["oi"]))
	map.open()
	ok = _check("nao abre durante um dialogo", not map.is_open()) and ok
	dialogue.force_close()

	print("")
	print("OK: o mapa grande funciona." if ok else "FALHOU: veja as linhas FALHA acima.")
	quit(0 if ok else 1)


## Junta os textos das etiquetas e o retângulo de cada "pílula" de lugar.
func _collect(node: Node, names: Array, pills: Array) -> void:
	for child in node.get_children():
		if child is PanelContainer:
			var label := child.get_child(0) as Label
			names.append(label.text)
			pills.append(Rect2(child.position, child.size))
		elif child is Label:
			names.append((child as Label).text)


func _check(label: String, passed: bool) -> bool:
	print(("  ok     " if passed else "  FALHA  ") + label)
	return passed
