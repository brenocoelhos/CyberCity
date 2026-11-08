extends SceneTree
## Verifica o nome do jogador e o cronômetro da partida: guardados no save,
## mostrados no celular, parados no menu e na pausa.
## Rodar: Godot --headless --path . --script res://tools/verify_run.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.


func _initialize() -> void:
	await process_frame
	var board = root.get_node("Leaderboard")
	var menu = root.get_node("GameMenu")
	var ok := true
	board.scores_path = "user://teste_run_placar.cfg"
	board.clear_scores()

	# --- formato do relogio ---
	ok = _check("relogio MM:SS", board.format_clock(754000) == "12:34") and ok
	ok = _check("relogio H:MM:SS", board.format_clock(3723000) == "1:02:03") and ok

	# --- nome e tempo vao para o save e voltam ---
	board.start_run("  Gabriel Nunes Silva  ")
	ok = _check("nome limpo e cortado em 10 letras", board.player_name == "Gabriel Nu") and ok
	board._elapsed_msec = 65000.0
	var saved: Dictionary = board.get_save_data()
	board.cancel_run()
	ok = _check("cancelar zera tudo", not board.is_running() and board.elapsed_msec() == 0) and ok
	board.load_save_data(saved)
	ok = _check("carregar devolve nome, tempo e partida ativa", board.player_name == "Gabriel Nu" and board.elapsed_msec() == 65000 and board.is_running()) and ok
	board.load_save_data({})
	ok = _check("save antigo (sem dados) continua valendo, sem nome", board.is_running() and board.player_name == "JOGADOR" and board.elapsed_msec() == 0) and ok

	# --- o tempo corre no jogo e para na pausa e no menu principal ---
	board.start_run("Ana")
	var before: int = board.elapsed_msec()
	board._process(0.5)
	ok = _check("fora do menu o tempo corre", board.elapsed_msec() == before + 500) and ok
	board.set_paused(true)
	board._process(0.5)
	ok = _check("pausado, o tempo para", board.elapsed_msec() == before + 500) and ok
	board.set_paused(false)

	# --- celular mostra o cronometro e o nome ---
	board._elapsed_msec = 754000.0
	menu.open()
	ok = _check("celular mostra o cronometro da partida", menu._stopwatch_label.text == "TEMPO 12:34") and ok
	menu._open_app("profile")
	var texts: Array = []
	for child in menu.list.get_children():
		if child is Label:
			texts.append((child as Label).text)
	ok = _check("perfil mostra o nome do agente e o tempo", texts.has("AGENTE Ana") and texts.has("Tempo de jogo: 12:34")) and ok
	menu.close()

	board.cancel_run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://teste_run_placar.cfg"))
	print("")
	print("OK: nome e cronometro funcionam." if ok else "FALHOU: veja as linhas FALHA acima.")
	quit(0 if ok else 1)


func _check(label: String, passed: bool) -> bool:
	print(("  ok     " if passed else "  FALHA  ") + label)
	return passed
