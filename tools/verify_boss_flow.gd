extends SceneTree
## Verifica o encontro com o hacker de ponta a ponta: o interior da Casa 5 pede
## o duelo, a porta tranca, o terminal abre em modo duelo, e os dois finais:
##   - vitoria: sobem os creditos, o tempo entra no placar e o jogo volta ao menu;
##   - derrota: game over que volta ao ultimo save (ou refaz o duelo sem save).
## NUNCA mexe no save nem no placar do jogador: usa arquivos temporarios.
## Rodar: Godot --headless --path . --script res://tools/verify_boss_flow.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.

const HOUSE := "res://scenes/interiors/HouseInterior.tscn"
const CITY := "res://scenes/world/City.tscn"
const TEMP_SAVE := "user://teste_boss_save.json"
const TEMP_BOARD := "user://teste_boss_placar.cfg"

const WIN_COMMANDS := [
	"block citycred-seguro.net", "unmask 10.13.37.5",
	"block 203.0.113.77", "unmask n0va_",
	"firewall block 23",
]


func _initialize() -> void:
	await process_frame
	var boss = root.get_node("BossManager")
	var terminal = root.get_node("TerminalManager")
	var dialogue = root.get_node("DialogueManager")
	var transition = root.get_node("SceneTransition")
	var save = root.get_node("SaveManager")
	var board = root.get_node("Leaderboard")
	var game = root.get_node("GameManager")
	var hud = root.get_node("HUD")
	var ok := true

	# Arquivos de teste: o save e o placar do jogador ficam intocados.
	save.save_path = TEMP_SAVE
	board.scores_path = TEMP_BOARD
	board.clear_scores()
	_remove(TEMP_SAVE)

	# --- a Casa 5 da cidade pede o duelo e esta liberada para teste ---
	var city: Node = (load(CITY) as PackedScene).instantiate()
	var casa5: Node = city.get_node("Buildings/Casa5")
	ok = _check("Casa 5 pede o duelo", casa5.interior_boss_fight) and ok
	ok = _check("Casa 5 liberada para teste", not casa5.starts_locked) and ok
	ok = _check("config do interior leva 'boss'", bool(casa5._build_interior_config().get("boss", false))) and ok
	city.free()

	# --- entrar na casa: porta tranca depois da cena ---
	transition.interior_config = {
		"npc_name": "Hacker",
		"npc_lines": PackedStringArray(["..."]),
		"npc_mission": "",
		"computer_challenge": "",
		"computers": {},
		"boss": true,
	}
	board.start_run("Tester")
	board._elapsed_msec = 125000.0
	var house: Node = (load(HOUSE) as PackedScene).instantiate()
	root.add_child(house)
	await process_frame
	ok = _check("o computador da casa fica no modo duelo", house.get_node_or_null("Computer") != null) and ok
	ok = _check("jogador bloqueado durante a cena", boss.is_busy()) and ok
	await create_timer(1.0).timeout
	ok = _check("porta tranca", boss.is_exit_locked()) and ok
	ok = _check("fala da cena aparece", dialogue.is_active()) and ok
	dialogue._close()
	await process_frame
	ok = _check("segunda fala (o hacker)", dialogue.is_active()) and ok
	dialogue._close()
	await process_frame
	ok = _check("terminal abre sozinho no duelo", terminal.is_active() and terminal.get("_boss") != null) and ok
	ok = _check("jogador solto durante o duelo (terminal bloqueia)", not boss.is_busy()) and ok
	terminal.close()
	ok = _check("terminal nao fecha durante o duelo", terminal.is_active()) and ok
	ok = _check("nao se salva durante o duelo (porta trancada)", not save.can_save()) and ok

	# --- vitoria: creditos + placar ---
	for command in WIN_COMMANDS:
		terminal._on_command_submitted(command)
	ok = _check("barra em 100 depois das respostas", terminal.get("_boss") == null) and ok
	await create_timer(1.8).timeout
	ok = _check("terminal fecha ao fim", not terminal.is_active()) and ok
	var credits: Node = boss._overlay
	ok = _check("os creditos aparecem", credits != null and String(credits.get_script().resource_path).ends_with("Credits.gd")) and ok
	ok = _check("creditos comecam com o final bom (azul)", _any_label(credits, "AZUIS")) and ok
	ok = _check("creditos mostram o agente e o tempo", _any_label(credits, "AGENTE Tester") and _any_label(credits, "Tempo de jogo: 02:")) and ok
	ok = _check("creditos mostram o placar com o tempo da partida", _any_label(credits, "Tester") and _any_label(credits, "PLACAR")) and ok
	ok = _check("o tempo entrou no placar", board.get_scores().size() == 1 and board.get_scores()[0]["name"] == "Tester" and int(board.get_scores()[0]["time_msec"]) >= 125000 and int(board.get_scores()[0]["time_msec"]) < 140000) and ok
	ok = _check("a partida terminou (cronometro parado)", not board.is_running()) and ok
	ok = _check("jogador bloqueado nos creditos", hud.is_popup_active()) and ok
	await process_frame
	ok = _check("creditos ainda subindo", not credits.is_finished() and not credits._back_button.visible) and ok
	credits.skip()
	ok = _check("pular leva ao fim e mostra o botao de voltar", credits.is_finished() and credits._back_button.visible) and ok
	credits._leave()
	await create_timer(1.0).timeout
	ok = _check("voltar leva ao menu principal e solta o estado", get_current_scene() != null and get_current_scene().scene_file_path.ends_with("MainMenu.tscn") and not boss.is_exit_locked() and not boss.is_busy() and not game.game_started) and ok

	# --- derrota sem nenhum save: tentar de novo ---
	boss._start_fight()
	terminal._on_command_submitted("desistir")
	await create_timer(1.8).timeout
	ok = _check("game over aparece", boss._overlay != null and _any_label(boss._overlay, "GAME OVER")) and ok
	ok = _check("sem save: oferece tentar de novo", _any_button(boss._overlay, "Tentar de novo") and not _any_button(boss._overlay, "Voltar ao último save")) and ok
	boss._retry()
	await process_frame
	ok = _check("tentar de novo reabre o duelo", terminal.is_active() and terminal.get("_boss") != null) and ok

	# --- derrota com save: volta ao ultimo save ---
	var file := FileAccess.open(TEMP_SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 1,
		"game": {"level": 4, "xp": 10, "total_xp_earned": 410},
		"run": {"name": "Voltou", "elapsed_msec": 99000, "running": true},
		"location": {"scene": CITY, "position": [1024.0, 320.0]},
	}))
	file.close()
	boss._exit_locked = true
	terminal._on_command_submitted("desistir")
	await create_timer(1.8).timeout
	ok = _check("com save: o game over oferece voltar ao ultimo save", boss._overlay != null and _any_button(boss._overlay, "Voltar ao último save")) and ok
	boss._load_last_save()
	await create_timer(1.2).timeout
	var scene: Node = get_current_scene()
	ok = _check("o ultimo save foi carregado (nivel 4)", game.level == 4 and game.game_started) and ok
	ok = _check("o jogador volta para a cidade", scene != null and scene.scene_file_path == CITY) and ok
	ok = _check("a partida continua do tempo salvo, com o nome salvo", board.is_running() and board.player_name == "Voltou" and board.elapsed_msec() >= 99000) and ok
	ok = _check("porta destrancada e jogador livre depois de carregar", not boss.is_exit_locked() and not boss.is_busy() and boss._overlay == null) and ok

	# limpeza: nada do teste fica em disco
	_remove(TEMP_SAVE)
	_remove(TEMP_BOARD)
	save.save_path = save.SAVE_PATH
	board.cancel_run()
	game.game_started = false

	print("")
	print("OK: o fluxo do duelo funciona." if ok else "FALHOU: veja as linhas FALHA acima.")
	quit(0 if ok else 1)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _any_label(node: Node, needle: String) -> bool:
	if node is Label and (node as Label).text.contains(needle):
		return true
	for child in node.get_children():
		if _any_label(child, needle):
			return true
	return false


func _any_button(node: Node, text: String) -> bool:
	if node is Button and (node as Button).text == text:
		return true
	for child in node.get_children():
		if _any_button(child, text):
			return true
	return false


func _check(label: String, passed: bool) -> bool:
	print(("  ok     " if passed else "  FALHA  ") + label)
	return passed
