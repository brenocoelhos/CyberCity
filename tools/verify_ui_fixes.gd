extends SceneTree
## Verifica os ajustes de interface:
##   - menu principal: setas/W/S sem nenhum botão com foco selecionam um botão;
##   - computador de quiz abre direto o quiz (sem o terminal);
##   - "!" do NPC some depois da 1ª conversa e isso vai no save;
##   - celular estilo iPhone: dock, bolinha de notificação e widget;
##   - desktop estilo Kali: menu de aplicativos por categoria e áreas de trabalho.
## Rodar: Godot --headless --path . --script res://tools/verify_ui_fixes.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.

const MENU := "res://scenes/ui/MainMenu.tscn"
const NPC_SCENE := "res://scenes/npc/NPC.tscn"


func _initialize() -> void:
	await process_frame
	var ok := true
	ok = await _check_menu() and ok
	ok = await _check_quiz() and ok
	ok = await _check_npc_marker() and ok
	ok = await _check_phone() and ok
	ok = await _check_desktop() and ok
	print("TUDO OK" if ok else "FALHOU")
	quit(0 if ok else 1)


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _check_menu() -> bool:
	var ok := true
	var menu: Control = (load(MENU) as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	ok = _check("menu: o fundo não tira o foco dos botões ao clicar", menu.mouse_filter == Control.MOUSE_FILTER_IGNORE) and ok
	root.gui_release_focus()
	menu._input(_key(KEY_DOWN))
	var focused: Control = root.gui_get_focus_owner()
	ok = _check("menu: seta sem foco seleciona o primeiro botão", focused != null and menu.main_buttons.is_ancestor_of(focused)) and ok
	var first: Control = focused
	menu._input(_key(KEY_S))
	ok = _check("menu: S desce para o próximo botão", root.gui_get_focus_owner() != first) and ok
	menu.queue_free()
	await process_frame
	return ok


func _check_quiz() -> bool:
	var ok := true
	var computer: Area2D = (load("res://scenes/computers/Computer.tscn") as PackedScene).instantiate()
	computer.challenge_id = "c_senhas"
	root.add_child(computer)
	await process_frame
	var data = root.get_node("ChallengeData")
	ok = _check("quiz: c_senhas é um quiz", String(data.get_challenge("c_senhas").get("type", "")) == "quiz") and ok
	computer._on_interact()
	ok = _check("quiz: o computador abre direto a tela do quiz", root.get_node("ChallengeManager").is_active()) and ok
	ok = _check("quiz: o terminal não abre", not root.get_node("TerminalManager").is_active()) and ok
	root.get_node("ChallengeManager").close()
	computer.queue_free()
	await process_frame
	return ok


func _check_npc_marker() -> bool:
	var ok := true
	var game = root.get_node("GameManager")
	game.reset()
	var npc: Node2D = (load(NPC_SCENE) as PackedScene).instantiate()
	root.add_child(npc)
	await process_frame
	await process_frame
	var interaction = npc.get_node("Interaction")
	interaction.npc_name = "Teste"
	interaction.mission_to_start = ""
	interaction._update_marker()
	var marker: Label = npc.get_node("Marker")
	ok = _check("npc: '!' aparece antes de conversar", marker.visible) and ok
	interaction._on_interact()
	ok = _check("npc: '!' some depois da conversa", not marker.visible) and ok
	var saved: Dictionary = game.get_save_data()
	game.reset()
	interaction._update_marker()
	ok = _check("npc: Novo jogo volta a mostrar o '!'", marker.visible) and ok
	game.load_save_data(saved)
	interaction._update_marker()
	ok = _check("npc: a conversa fica guardada no save", not marker.visible) and ok
	root.get_node("DialogueManager").force_close()
	npc.queue_free()
	game.reset()
	await process_frame
	return ok


func _check_phone() -> bool:
	var ok := true
	var phone = root.get_node("GameMenu")
	var messages = root.get_node("PhoneManager")
	messages.reset()
	messages.send_message("Teste", "olá")
	phone.open()
	await process_frame
	var dock: Node = phone.home.find_child("Dock", true, false)
	ok = _check("celular: tem dock com 4 apps", dock != null and dock.get_child_count() == 4) and ok
	var badge: Label = phone.messages_button.get_node("Badge")
	ok = _check("celular: bolinha vermelha com 1 mensagem nova", badge.visible and badge.text == "1") and ok
	ok = _check("celular: os apps viraram ícones com nome", phone.messages_button.get_node("AppName").text == "Mensagens") and ok
	ok = _check("celular: widget com o cronômetro", phone._stopwatch_label.text.begins_with("TEMPO")) and ok
	phone._open_app("messages")
	ok = _check("celular: o app tem título como no iOS", phone.app_title.text == "Mensagens") and ok
	phone.close()
	messages.reset()
	return ok


func _check_desktop() -> bool:
	var ok := true
	var desktop = root.get_node("DesktopManager")
	desktop.open("c_vazamento", "teste")
	await process_frame
	ok = _check("desktop: painel em cima (janelas começam abaixo dele)", desktop._windows.offset_top == desktop.TASKBAR_HEIGHT) and ok
	desktop._toggle_app_menu()
	ok = _check("desktop: o menu de aplicativos abre", desktop._app_menu.visible) and ok
	var names: Array = []
	for row in desktop._menu_list.get_children():
		if row is Button:
			names.append(String(row.text).strip_edges())
	ok = _check("desktop: favoritos mostram só os apps do laboratório", names.has("Cliente de E-mail") and not names.has("Navegador Web")) and ok
	desktop._menu_category = "15"
	desktop._render_menu_apps()
	var forensics: Array = []
	for row in desktop._menu_list.get_children():
		if row is Button:
			forensics.append(String(row.text).strip_edges())
	ok = _check("desktop: categoria 15 - Forense mostra o Gerenciador de Arquivos", forensics == ["Gerenciador de Arquivos"]) and ok
	desktop._menu_search.text = "termi"
	desktop._render_menu_apps()
	ok = _check("desktop: a busca acha o terminal", desktop._menu_list.get_child_count() == 1) and ok
	desktop._toggle_app_menu()
	desktop._switch_workspace(2)
	ok = _check("desktop: área de trabalho 2 está vazia", not desktop._windows.visible) and ok
	desktop.open_app("notes")
	ok = _check("desktop: abrir um app volta para a área 1", desktop._workspace == 1 and desktop._windows.visible) and ok
	desktop.close()
	return ok


func _check(label: String, passed: bool) -> bool:
	print(("  ok    " if passed else "  FALHA ") + label)
	return passed
