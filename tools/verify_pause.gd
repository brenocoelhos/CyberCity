extends SceneTree
## Verifica o menu de pausa: ESC congela o jogo e o cronometro, nao abre por
## cima de outras telas nem no menu principal, e fecha com ESC/Continuar.
## Rodar: Godot --headless --path . --script res://tools/verify_pause.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.

const CITY := "res://scenes/world/City.tscn"


func _initialize() -> void:
	await process_frame
	var save = root.get_node("SaveManager")
	# NUNCA gravar no save do jogador: usa um arquivo temporario.
	save.save_path = "user://teste_pausa_save.json"
	var pause = root.get_node("PauseMenu")
	var board = root.get_node("Leaderboard")
	var hud = root.get_node("HUD")
	var dialogue = root.get_node("DialogueManager")
	var game = root.get_node("GameManager")
	var ok := true

	board.start_run("Teste")
	game.game_started = true
	var city: Node = (load(CITY) as PackedScene).instantiate()
	root.add_child(city)
	current_scene = city
	await process_frame
	dialogue.force_close()

	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	esc.physical_keycode = KEY_ESCAPE

	ok = _check("pausa fechada no inicio", not pause.is_open() and not paused) and ok
	pause._unhandled_input(esc)
	ok = _check("ESC abre a pausa e congela a arvore", pause.is_open() and paused and hud.is_popup_active()) and ok
	ok = _check("a pausa mostra nome e tempo", pause._info.text.contains("Teste")) and ok

	# o relogio da partida nao corre pausado (a arvore pausada nem chama o _process)
	pause._unhandled_input(esc)
	ok = _check("ESC de novo fecha e solta o jogo", not pause.is_open() and not paused and not hud.is_popup_active()) and ok

	# nao abre por cima de outras telas
	dialogue.start_dialogue("X", PackedStringArray(["oi"]))
	pause._unhandled_input(esc)
	ok = _check("nao abre durante um dialogo", not pause.is_open()) and ok
	dialogue.force_close()
	city.city_map.open()
	pause._unhandled_input(esc)
	ok = _check("nao abre por cima do mapa grande", not pause.is_open()) and ok
	city.city_map.close()

	# nao abre no menu principal
	current_scene = null
	var menu: Node = (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	pause._unhandled_input(esc)
	ok = _check("nao abre no menu principal", not pause.is_open()) and ok
	menu.queue_free()
	current_scene = city

	# botoes
	pause.open()
	pause._on_save()
	ok = _check("salvar mostra o aviso na propria pausa", pause._status.text != "") and ok
	pause._on_options()
	ok = _check("opcoes abrem no lugar do menu", pause._options.visible and not pause._box.visible) and ok
	pause._options.close()
	ok = _check("fechar as opcoes volta ao menu", pause._box.visible and pause.is_open()) and ok
	pause.close()
	ok = _check("continuar solta o jogo", not paused) and ok

	board.cancel_run()
	game.game_started = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.save_path))
	save.save_path = save.SAVE_PATH
	print("")
	print("OK: a pausa funciona." if ok else "FALHOU: veja as linhas FALHA acima.")
	quit(0 if ok else 1)


func _check(label: String, passed: bool) -> bool:
	print(("  ok     " if passed else "  FALHA  ") + label)
	return passed
