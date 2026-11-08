extends SceneTree
## Verifica a abertura de um jogo novo: o celular toca, a Central pergunta o
## nome, o nome vai para o placar (e o cronometro comeca) e a campanha segue.
## Com a partida ja em andamento (jogo carregado), a abertura nao repete.
## Rodar: Godot --headless --path . --script res://tools/verify_intro.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.

const CITY := "res://scenes/world/City.tscn"


func _initialize() -> void:
	await process_frame
	var board = root.get_node("Leaderboard")
	var dialogue = root.get_node("DialogueManager")
	var hud = root.get_node("HUD")
	var ok := true

	# --- jogo novo: sem partida, entra o telefonema ---
	board.cancel_run()
	var city: Node = (load(CITY) as PackedScene).instantiate()
	root.add_child(city)
	await process_frame
	ok = _check("jogo novo: jogador parado durante o telefone tocando", hud.is_popup_active()) and ok
	await create_timer(2.6).timeout
	ok = _check("a Central fala depois do toque", dialogue.is_active() and dialogue.speaker_label.text == "CENTRAL") and ok
	ok = _check("a pergunta do nome esta no dialogo", dialogue.text_label.text.length() > 0) and ok
	dialogue._close()
	await process_frame
	var prompt: Node = _find_prompt()
	ok = _check("aparece a janela do nome", prompt != null and hud.is_popup_active()) and ok
	ok = _check("a partida so comeca depois do nome", not board.is_running()) and ok

	# nome vazio vira JOGADOR; aqui um nome comprido e cortado
	prompt._field.text = "Gabriel Nunes Silva"
	prompt._confirm()
	await process_frame
	ok = _check("o nome digitado vira o do placar (10 letras)", board.player_name == "Gabriel Nu") and ok
	ok = _check("o cronometro comecou", board.is_running()) and ok
	ok = _check("a janela do nome some e solta o jogador", _find_prompt() == null or _find_prompt().is_queued_for_deletion()) and ok
	ok = _check("a Central da as boas-vindas com o nome", dialogue.is_active() and dialogue.text_label.text.contains("Gabriel Nu")) and ok
	dialogue._close()
	await process_frame
	await process_frame
	ok = _check("depois do telefonema, comeca o capitulo 1", dialogue.is_active() and dialogue.speaker_label.text != "CENTRAL") and ok
	dialogue.force_close()
	city.queue_free()
	await process_frame

	# --- nome vazio ---
	board.cancel_run()
	var city2: Node = (load(CITY) as PackedScene).instantiate()
	root.add_child(city2)
	await create_timer(2.6).timeout
	dialogue._close()
	await process_frame
	var prompt2: Node = _find_prompt()
	prompt2._field.text = "   "
	prompt2._confirm()
	await process_frame
	ok = _check("nome vazio vira JOGADOR", board.player_name == "JOGADOR") and ok
	dialogue.force_close()
	city2.queue_free()
	await process_frame

	# --- jogo carregado (partida em andamento): nao repete ---
	board.start_run("Ana")
	var city3: Node = (load(CITY) as PackedScene).instantiate()
	root.add_child(city3)
	await create_timer(1.2).timeout
	ok = _check("partida em andamento: nao pergunta o nome de novo", _find_prompt() == null and board.player_name == "Ana") and ok
	dialogue.force_close()
	board.cancel_run()

	print("")
	print("OK: a abertura funciona." if ok else "FALHOU: veja as linhas FALHA acima.")
	quit(0 if ok else 1)


func _find_prompt() -> Node:
	for child in root.get_children():
		if child.get_script() != null and String(child.get_script().resource_path).ends_with("NamePrompt.gd"):
			return child
	return null


func _check(label: String, passed: bool) -> bool:
	print(("  ok     " if passed else "  FALHA  ") + label)
	return passed
