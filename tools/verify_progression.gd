extends SceneTree
## Verifica o que o nível do jogador libera: as ferramentas por nível (seta de
## missão, app Ferramentas do celular, mapa de rede, histórico salvo), a seta
## de missão, as ferramentas do celular, o mapa de rede e o placar estilo
## arcade. Não usa a interface.
## Rodar: Godot --headless --path . --script res://tools/verify_progression.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.


func _initialize() -> void:
	await process_frame
	var ok := true
	ok = await _check_unlocks() and ok
	ok = await _check_arrow() and ok
	ok = _check_study_tools() and ok
	ok = _check_phone_tools() and ok
	ok = _check_network_map() and ok
	ok = _check_saved_history() and ok
	ok = _check_leaderboard() and ok
	print("RESULTADO: ", "TUDO OK" if ok else "FALHOU")
	quit(0 if ok else 1)


func _check_unlocks() -> bool:
	var game = root.get_node("GameManager")
	var phone = root.get_node("PhoneManager")
	var ok := true
	game.reset()
	phone.reset()
	# Os niveis de cada ferramenta vem de GameManager.TOOL_UNLOCK_LEVELS (a seta
	# pode ser liberada mais cedo para teste), entao nada aqui fixa esses numeros.
	var levels: Dictionary = game.TOOL_UNLOCK_LEVELS
	ok = _check("nivel 1: cada ferramenta so esta liberada se o nivel dela e 1", _unlocked_match_levels(game)) and ok
	ok = _check("nivel 1: o mapa de rede e o historico ainda estao travados", not game.is_tool_unlocked("network_map") and not game.is_tool_unlocked("saved_history")) and ok
	ok = _check("ferramenta desconhecida nunca e liberada", not game.is_tool_unlocked("nao_existe")) and ok

	var unlocked: Array = []
	game.tool_unlocked.connect(func(tool_id): unlocked.append(tool_id))
	var expected_events := 0
	game.add_xp(100)
	ok = _check("nivel 2: libera so o que e do nivel 2", game.level == 2 and _unlocked_match_levels(game)) and ok
	game.add_xp(200)
	ok = _check("nivel 3: o evento do app Ferramentas so existe se ele nao comeca liberado", game.level == 3 and unlocked.has("phone_tools") == (int(game.TOOL_UNLOCK_LEVELS["phone_tools"]) > 1) and _unlocked_match_levels(game)) and ok
	ok = _check("nivel 3: o mapa e o historico continuam travados", not game.is_tool_unlocked("network_map") and not game.is_tool_unlocked("saved_history")) and ok
	var expected_messages := 0
	for tool_id in levels.keys():
		if int(levels[tool_id]) > 1 and int(levels[tool_id]) <= 3:
			expected_messages += 1
	ok = _check("a Central manda uma mensagem por ferramenta liberada ao subir de nivel (ate o 3)", phone.messages.size() == expected_messages) and ok

	game.add_xp(300 + 400)  # sobe do 3 para o 4 (300) e do 4 para o 5 (400): dois niveis de uma vez
	ok = _check("subir dois niveis de uma vez libera as duas ferramentas", game.level == 5 and unlocked.has("network_map") and unlocked.has("saved_history")) and ok
	for tool_id in levels.keys():
		if int(levels[tool_id]) > 1 and int(levels[tool_id]) <= 5:
			expected_events += 1
	ok = _check("cada ferramenta e liberada uma unica vez (so as que nao comecam liberadas)", unlocked.size() == expected_events) and ok
	game.reset()
	phone.reset()
	ok = _check("reset volta ao estado do nivel 1", _unlocked_match_levels(game) and not game.is_tool_unlocked("saved_history")) and ok
	return ok


## true se is_tool_unlocked bate com a tabela de niveis no nivel atual.
func _unlocked_match_levels(game) -> bool:
	for tool_id in game.TOOL_UNLOCK_LEVELS.keys():
		if game.is_tool_unlocked(tool_id) != (game.level >= int(game.TOOL_UNLOCK_LEVELS[tool_id])):
			return false
	return true


# Carregado só na hora do teste (depois dos autoloads), porque o script usa MissionManager etc.
var MissionTarget: GDScript


func _check_arrow() -> bool:
	var game = root.get_node("GameManager")
	var missions = root.get_node("MissionManager")
	var campaign = root.get_node("CampaignManager")
	var transition = root.get_node("SceneTransition")
	var dialogue = root.get_node("DialogueManager")
	var ok := true
	MissionTarget = load("res://scripts/ui/MissionTarget.gd")

	game.reset()
	missions.reset()
	campaign.reset()
	ok = _check("seta: sem capitulo nem missao ativa, nada a guiar", MissionTarget.mission_to_guide() == "") and ok
	campaign.play_opening()
	dialogue.force_close()
	ok = _check("seta: capitulo 1 comecou, guia a m01", MissionTarget.mission_to_guide() == "m01") and ok
	missions.start_mission("m11")
	ok = _check("seta: missao em andamento tem prioridade", MissionTarget.mission_to_guide() == "m11") and ok
	missions.reset()

	# --- dentro das casas ---
	transition.interior_config = {}
	var house: Node = await _open("res://scenes/interiors/HouseInterior.tscn")
	var target: Node2D = MissionTarget.find_target(house, "m01")
	ok = _check("seta: na Casa 1 aponta o Morador ou o computador da m01", target != null and target.name in ["Interaction", "Computer"]) and ok
	house.queue_free()
	await process_frame

	transition.interior_config = {"npc_name": "Moradora", "npc_lines": PackedStringArray(["oi"]), "npc_mission": "m11", "computer_challenge": "c_roteador"}
	house = await _open("res://scenes/interiors/HouseInterior.tscn")
	target = MissionTarget.find_target(house, "m11")
	ok = _check("seta: na Casa 6 aponta o computador ou a Moradora da m11", target != null and target.name in ["Interaction", "Computer"]) and ok
	target = MissionTarget.find_target(house, "m12")
	ok = _check("seta: numa casa que nao tem a missao, aponta a saida", target != null and target.name == "ExitDoor") and ok
	house.queue_free()
	await process_frame

	# --- escritorio com varios computadores ---
	transition.interior_config = {"computers": {"Computer1": "c_site", "Computer2": "c_acesso", "Computer3": ""}}
	var office: Node = await _open("res://scenes/interiors/OfficeInterior.tscn")
	target = MissionTarget.find_target(office, "m17")
	ok = _check("seta: no escritorio aponta o computador certo (m17 = Computer2)", target != null and target.name == "Computer2") and ok
	target = MissionTarget.find_target(office, "m16")
	ok = _check("seta: no escritorio aponta o computador certo (m16 = Computer1)", target != null and target.name == "Computer1") and ok
	office.queue_free()
	await process_frame
	transition.interior_config = {}

	# --- cidade: o predio da missao e o Terminal Publico ---
	var city: Node = await _open("res://scenes/world/City.tscn")
	dialogue.force_close()
	target = MissionTarget.find_target(city, "m11")
	ok = _check("seta: na cidade a m11 aponta a Casa 6", target != null and target.name == "Casa6") and ok
	target = MissionTarget.find_target(city, "m16")
	ok = _check("seta: na cidade a m16 aponta a DataSoft", target != null and target.name == "Empresa2") and ok
	target = MissionTarget.find_target(city, "m15")
	ok = _check("seta: na cidade a m15 aponta o Terminal Publico", target != null and target.name == "TerminalPublico") and ok
	city.queue_free()
	await process_frame

	# --- quando a seta fica ligada ---
	var arrow = root.get_node("HUD").get_node("MissionArrow")
	game.reset()
	var arrow_level: int = int(game.TOOL_UNLOCK_LEVELS["mission_arrow"])
	ok = _check("seta: no nivel 1 so liga se a ferramenta ja for do nivel 1", arrow.is_enabled() == (arrow_level <= 1)) and ok
	game.add_xp(300)
	dialogue.force_close()
	ok = _check("seta: ligada no nivel 3 (depois do nivel dela)", arrow.is_enabled() and game.level >= arrow_level) and ok
	root.get_node("Settings").mission_arrow = false
	ok = _check("seta: desligada se o jogador a desliga nos Ajustes", not arrow.is_enabled()) and ok
	root.get_node("Settings").mission_arrow = true
	game.reset()
	missions.reset()
	campaign.reset()
	return ok


func _check_study_tools() -> bool:
	var tools: GDScript = load("res://scripts/systems/StudyTools.gd")
	var ok := true
	ok = _check("cesar: VHJXUR -3 = SEGURO (o da missao 4)", tools.caesar("VHJXUR", -3) == "SEGURO") and ok
	ok = _check("cesar: cifrar e decifrar se desfazem", tools.caesar(tools.caesar("Ataque ao amanhecer!", 7), -7) == "Ataque ao amanhecer!") and ok
	ok = _check("cesar: mantem maiusculas, espacos e simbolos", tools.caesar("Abc, xyz 123!", 3) == "Def, abc 123!") and ok
	ok = _check("cesar: deslocamento maior que 26 e negativo", tools.caesar("abc", 29) == "def" and tools.caesar("abc", -27) == "zab") and ok
	ok = _check("hash: md5 da senha de exemplo do vazamento", tools.md5("marcos2020") == "159e70e5dfbf44e74b2b20257657db3c") and ok
	ok = _check("hash: sha256 tem 64 caracteres e e estavel", tools.sha256("a").length() == 64 and tools.sha256("a") == tools.sha256("a")) and ok
	ok = _check("senha forte: sem problemas", tools.password_problems("Casa#Segura2026!").is_empty() and tools.password_strength("Casa#Segura2026!") == "forte") and ok
	ok = _check("senha curta: aponta o tamanho", tools.password_problems("Ab#1").size() >= 1 and String(tools.password_problems("Ab#1")[0]).find("10 caracteres") != -1) and ok
	ok = _check("senha 'admin' e fraca", tools.password_strength("admin") == "fraca") and ok
	ok = _check("senha sem simbolo e media", tools.password_strength("CasaSegura2026x") == "média") and ok
	ok = _check("palavra extra a evitar e respeitada", not tools.password_problems("Roteador#2026ok", 10, ["roteador"]).is_empty()) and ok
	ok = _check("senha vazia nao tem classificacao", tools.password_strength("") == "") and ok
	return ok


func _check_network_map() -> bool:
	var game = root.get_node("GameManager")
	var term = root.get_node("TerminalManager")
	var map: GDScript = load("res://scripts/terminal/NetworkMap.gd")
	var ok := true

	var nodes := [
		{"name": "web01", "sub": ["192.168.1.30", "22/ssh 80/http"]},
		{"name": "db01", "sub": ["192.168.1.40"]},
		{"name": "gateway", "sub": ["192.168.1.1"]},
	]
	var lines: PackedStringArray = map.render("kali@praca", nodes)
	var text: String = "\n".join(lines)
	ok = _check("mapa: mostra a origem e as 3 maquinas com seus enderecos", text.find("kali@praca") != -1 and text.find("web01") != -1 and text.find("db01") != -1 and text.find("gateway") != -1 and text.find("192.168.1.40") != -1 and text.find("22/ssh 80/http") != -1) and ok
	ok = _check("mapa: usa os tracos de caixa e liga a origem as maquinas", text.find("┌") != -1 and text.find("┬") != -1 and text.find("┴") != -1 and text.find("└") != -1) and ok
	ok = _check("mapa: sem maquinas nao desenha nada", map.render("kali@x", []).is_empty()) and ok
	ok = _check("mapa: uma so maquina e uma origem larga cabem", map.render("kali@casa", [nodes[0]]).size() > 5 and map.render("kali@estacao-do-escritorio-grande", [{"name": "a", "sub": []}, {"name": "b", "sub": []}]).size() > 5) and ok
	var widest := 0
	for line in lines:
		widest = maxi(widest, line.length())
	ok = _check("mapa: cabe numa janela de terminal (menos de 100 colunas)", widest < 100) and ok

	# o 'scan' so desenha o mapa a partir do nivel 4
	game.reset()
	term.open("c_cadeia", "praca-central")
	term._on_command_submitted("scan")
	ok = _check("scan no nivel 1: so a lista, sem mapa", term.output.get_parsed_text().find("Mapa de rede") == -1 and term.output.get_parsed_text().find("192.168.1.30") != -1) and ok
	game.add_xp(100 + 200 + 300)
	term._on_command_submitted("clear")
	term._on_command_submitted("scan")
	var scan_text: String = term.output.get_parsed_text()
	ok = _check("scan no nivel 4: a lista e o mapa", game.level == 4 and scan_text.find("Mapa de rede") != -1 and scan_text.find("┌") != -1 and scan_text.find("web01") != -1) and ok
	term.close()

	term.open("c_rede", "servidor")
	term._on_command_submitted("scan")
	ok = _check("scan do desafio de rede tambem desenha o mapa no nivel 4", term.output.get_parsed_text().find("Mapa de rede") != -1 and term.output.get_parsed_text().find("UNKNOWN") != -1) and ok
	term.close()
	game.reset()
	return ok


func _play(board, name_typed: String, seconds: float) -> Dictionary:
	board.start_run(name_typed)
	board._process(seconds)
	return board.finish_run()


func _check_leaderboard() -> bool:
	var board = root.get_node("Leaderboard")
	var ok := true
	var test_file := "user://teste_placar.cfg"
	board.scores_path = test_file
	DirAccess.remove_absolute(test_file)
	board.clear_scores()

	ok = _check("placar: sem partida, finish_run devolve vazio", board.finish_run().is_empty()) and ok
	ok = _check("placar: nome vazio vira JOGADOR e nome longo e cortado", board.clean_name("   ") == "JOGADOR" and board.clean_name("ABCDEFGHIJKLMNOP").length() == 10) and ok

	board.start_run("  Ana  ")
	ok = _check("placar: comeca a contar do zero com o nome aparado", board.is_running() and board.player_name == "Ana" and board.elapsed_msec() == 0) and ok
	board._process(2.5)
	ok = _check("placar: o tempo soma os quadros", board.elapsed_msec() == 2500) and ok
	board.set_paused(true)
	board._process(10.0)
	ok = _check("placar: pausado, o tempo para", board.elapsed_msec() == 2500) and ok
	board.set_paused(false)
	var result: Dictionary = board.finish_run()
	ok = _check("placar: 1o lugar e recorde", result["position"] == 1 and result["is_record"] and result["entry"]["name"] == "Ana" and result["entry"]["time_msec"] == 2500) and ok
	ok = _check("placar: depois de terminar, nao esta mais rodando", not board.is_running()) and ok

	var slower: Dictionary = _play(board, "Bia", 5.0)
	var faster: Dictionary = _play(board, "Caio", 1.0)
	ok = _check("placar: mais lento fica atras, mais rapido passa a frente", slower["position"] == 2 and faster["position"] == 1 and faster["is_record"]) and ok
	var names: Array = []
	for entry in board.get_scores():
		names.append(entry["name"])
	ok = _check("placar: ordem do menor para o maior tempo (Caio, Ana, Bia)", names == ["Caio", "Ana", "Bia"]) and ok
	var tie: Dictionary = _play(board, "Duda", 2.5)
	ok = _check("placar: em empate, quem chegou primeiro fica na frente", tie["position"] == 3) and ok

	board.start_run("Eva")
	board._process(1.0)
	board.cancel_run()
	ok = _check("placar: cancelar nao grava nada", not board.is_running() and board.get_scores().size() == 4 and board.finish_run().is_empty()) and ok

	# persistencia: recarregar do arquivo
	board._scores = []
	board.load_scores()
	ok = _check("placar: sobrevive a recarregar do disco", board.get_scores().size() == 4 and board.get_scores()[0]["name"] == "Caio") and ok

	# limite de 10 e quem fica de fora
	for i in range(8):
		_play(board, "P%d" % i, 10.0 + i)
	ok = _check("placar: guarda no maximo 10", board.get_scores().size() == 10) and ok
	var out: Dictionary = _play(board, "Lento", 999.0)
	ok = _check("placar: tempo pior que o 10o nao entra (posicao 0)", out["position"] == 0 and board.get_scores().size() == 10 and board.get_scores()[9]["name"] != "Lento") and ok

	ok = _check("tempo: formato MM:SS.cc", board.format_time(754560) == "12:34.56" and board.format_time(0) == "00:00.00" and board.format_time(2500) == "00:02.50") and ok
	ok = _check("tempo: passando de uma hora mostra as horas", board.format_time(3600000 + 61000 + 230) == "1:01:01.23") and ok

	var finished: Array = []
	board.run_finished.connect(func(entry, position): finished.append([entry["name"], position]))
	_play(board, "Sinal", 0.5)
	ok = _check("placar: avisa com o sinal run_finished", finished.size() == 1 and finished[0][0] == "Sinal") and ok

	board.clear_scores()
	DirAccess.remove_absolute(test_file)
	board.scores_path = "user://leaderboard.cfg"
	board.cancel_run()
	return ok


func _check_saved_history() -> bool:
	var game = root.get_node("GameManager")
	var term = root.get_node("TerminalManager")
	var ok := true
	var test_file := "user://teste_historico_terminal.cfg"
	term.history_path = test_file
	DirAccess.remove_absolute(test_file)

	# Sem a ferramenta: cada computador comeca sem historico e nada vai para o disco.
	game.reset()
	term._command_history = PackedStringArray(["velho"])
	term.open("c_logs", "loja")
	ok = _check("historico: antes do nivel 5 o terminal abre com o historico vazio", term._command_history.is_empty()) and ok
	term._on_command_submitted("ls")
	ok = _check("historico: antes do nivel 5 nada e gravado em disco", not FileAccess.file_exists(test_file)) and ok
	term.close()

	# Com a ferramenta: o historico vai para o arquivo e volta em qualquer computador.
	term._command_history = PackedStringArray()
	game.add_xp(100 + 200 + 300 + 400)
	term.open("c_logs", "loja")
	term._on_command_submitted("ls")
	term._on_command_submitted("whoami")
	ok = _check("historico: no nivel 5 os comandos sao gravados", game.level == 5 and FileAccess.file_exists(test_file)) and ok
	term.close()
	term._command_history = PackedStringArray()
	term.open("c_senhas", "estacao-1")
	ok = _check("historico: ao abrir outro computador, os comandos voltam do arquivo", Array(term._command_history) == ["ls", "whoami"]) and ok
	ok = _check("historico: a seta para cima ja alcanca o ultimo comando guardado", term._history_index == 2) and ok
	term._history_prev()
	ok = _check("historico: seta para cima mostra 'whoami'", term.input_line.text == "whoami") and ok
	term.close()

	# O limite de comandos guardados.
	term._command_history = PackedStringArray()
	for i in range(term.MAX_SAVED_HISTORY + 20):
		term._command_history.append("cmd%d" % i)
	term._save_history()
	var config := ConfigFile.new()
	config.load(test_file)
	var saved: PackedStringArray = config.get_value("terminal", "history", PackedStringArray())
	ok = _check("historico: guarda no maximo os ultimos 200", saved.size() == term.MAX_SAVED_HISTORY and saved[saved.size() - 1] == "cmd%d" % (term.MAX_SAVED_HISTORY + 19)) and ok

	DirAccess.remove_absolute(test_file)
	term.history_path = "user://terminal_history.cfg"
	term._command_history = PackedStringArray()
	game.reset()
	return ok


func _check_phone_tools() -> bool:
	var game = root.get_node("GameManager")
	var missions = root.get_node("MissionManager")
	var menu = root.get_node("GameMenu")
	var ok := true

	game.reset()
	missions.reset()
	menu.open()
	ok = _check("celular: no nivel 1 o app Ferramentas so aparece se ele ja for do nivel 1", menu.tools_button.visible == (int(game.TOOL_UNLOCK_LEVELS["phone_tools"]) <= 1)) and ok
	menu.close()

	game.add_xp(300)
	menu.open()
	ok = _check("celular: app Ferramentas aparece depois do nivel dele", menu.tools_button.visible) and ok
	ok = _check("celular: o botao fica antes do 'Fechar'", menu.tools_button.get_index() < menu.close_button.get_index()) and ok

	menu._open_app("tools")
	var inputs: Array = menu.list.find_children("*", "LineEdit", true, false)
	var caesar_open_at_start: bool = menu.CAESAR_REQUIRES_MISSION == ""
	ok = _check("celular: o Cesar so abre antes da missao se o requisito estiver vazio", inputs.size() == (4 if caesar_open_at_start else 2)) and ok

	missions.start_mission("m04")
	missions.complete_mission("m04")
	menu._open_app("tools")
	inputs = menu.list.find_children("*", "LineEdit", true, false)
	ok = _check("celular: depois da m04 o Cesar abre (4 campos)", inputs.size() == 4) and ok

	inputs[0].text = "VHJXUR"
	inputs[0].text_changed.emit("VHJXUR")
	var labels: Array = menu.list.find_children("*", "Label", true, false)
	var found_caesar := false
	for label in labels:
		if String(label.text).find("Decifrar (−3): SEGURO") != -1:
			found_caesar = true
	ok = _check("celular: o decifrador mostra SEGURO para VHJXUR com deslocamento 3", found_caesar) and ok

	inputs[2].text = "marcos2020"
	inputs[2].text_changed.emit("marcos2020")
	inputs[3].text = "admin"
	inputs[3].text_changed.emit("admin")
	labels = menu.list.find_children("*", "Label", true, false)
	var found_hash := false
	var found_weak := false
	for label in labels:
		if String(label.text).find("MD5: 159e70e5dfbf44e74b2b20257657db3c") != -1:
			found_hash = true
		if String(label.text).find("Força: fraca") != -1:
			found_weak = true
	ok = _check("celular: a calculadora mostra o MD5 certo", found_hash) and ok
	ok = _check("celular: o verificador chama 'admin' de fraca", found_weak) and ok

	menu.close()
	game.reset()
	missions.reset()
	return ok


func _open(scene_path: String) -> Node:
	var scene: Node = (load(scene_path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	return scene


func _check(label: String, cond: bool) -> bool:
	print(("  ok   " if cond else "  FAIL ") + label)
	return cond
