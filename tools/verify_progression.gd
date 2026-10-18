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
	print("RESULTADO: ", "TUDO OK" if ok else "FALHOU")
	quit(0 if ok else 1)


func _check_unlocks() -> bool:
	var game = root.get_node("GameManager")
	var phone = root.get_node("PhoneManager")
	var ok := true
	game.reset()
	phone.reset()
	ok = _check("nivel 1: nenhuma ferramenta liberada", not game.is_tool_unlocked("mission_arrow") and not game.is_tool_unlocked("saved_history")) and ok
	ok = _check("ferramenta desconhecida nunca e liberada", not game.is_tool_unlocked("nao_existe")) and ok

	var unlocked: Array = []
	game.tool_unlocked.connect(func(tool_id): unlocked.append(tool_id))
	game.add_xp(100)
	ok = _check("nivel 2: ainda nada liberado", game.level == 2 and unlocked.is_empty()) and ok
	game.add_xp(200)
	ok = _check("nivel 3: libera a seta e o app Ferramentas", game.level == 3 and unlocked.has("mission_arrow") and unlocked.has("phone_tools") and unlocked.size() == 2) and ok
	ok = _check("nivel 3: is_tool_unlocked responde", game.is_tool_unlocked("mission_arrow") and game.is_tool_unlocked("phone_tools") and not game.is_tool_unlocked("network_map")) and ok
	ok = _check("a Central avisa pelo celular de cada ferramenta liberada", phone.messages.size() == 2 and String(phone.messages[0]["text"]).find("Seta de missão") != -1 and String(phone.messages[1]["text"]).find("Ferramentas do celular") != -1) and ok

	game.add_xp(300 + 400)  # sobe do 3 para o 4 (300) e do 4 para o 5 (400): dois niveis de uma vez
	ok = _check("subir dois niveis de uma vez libera as duas ferramentas", game.level == 5 and unlocked.has("network_map") and unlocked.has("saved_history")) and ok
	ok = _check("cada ferramenta e liberada uma unica vez", unlocked.size() == 4) and ok
	game.reset()
	phone.reset()
	ok = _check("reset volta a travar as ferramentas", not game.is_tool_unlocked("mission_arrow")) and ok
	return ok


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
	ok = _check("seta: desligada no nivel 1", not arrow.is_enabled()) and ok
	game.add_xp(300)
	dialogue.force_close()
	ok = _check("seta: ligada no nivel 3", arrow.is_enabled()) and ok
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


func _check_phone_tools() -> bool:
	var game = root.get_node("GameManager")
	var missions = root.get_node("MissionManager")
	var menu = root.get_node("GameMenu")
	var ok := true

	game.reset()
	missions.reset()
	menu.open()
	ok = _check("celular: app Ferramentas escondido no nivel 1", not menu.tools_button.visible) and ok
	menu.close()

	game.add_xp(300)
	menu.open()
	ok = _check("celular: app Ferramentas aparece no nivel 3", menu.tools_button.visible) and ok
	ok = _check("celular: o botao fica antes do 'Fechar'", menu.tools_button.get_index() < menu.close_button.get_index()) and ok

	menu._open_app("tools")
	var inputs: Array = menu.list.find_children("*", "LineEdit", true, false)
	ok = _check("celular: sem a m04, so hash e senha (2 campos) e o Cesar fica bloqueado", inputs.size() == 2) and ok

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
