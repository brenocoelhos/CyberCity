extends SceneTree
## Verifica o menu principal: a tela de Controles cita as teclas novas (M, ESC
## pausa, desktop) e o botao Placar mostra os melhores tempos (ou o aviso de
## placar vazio). Usa um arquivo de placar temporario.
## Rodar: Godot --headless --path . --script res://tools/verify_menu_extras.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.

const MENU := "res://scenes/ui/MainMenu.tscn"


func _initialize() -> void:
	await process_frame
	var board = root.get_node("Leaderboard")
	board.scores_path = "user://teste_menu_placar.cfg"
	board.clear_scores()
	var ok := true

	var menu: Control = (load(MENU) as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame

	# --- controles ---
	var controls: String = menu.get_node("ControlsPanel/TextLabel").text
	ok = _check("controles: citam o mapa (M)", controls.contains("M — mapa")) and ok
	ok = _check("controles: ESC pausa o jogo e TAB abre o celular", controls.contains("ESC — pausar") and controls.contains("TAB — celular")) and ok
	ok = _check("controles: explicam o desktop (arrastar, redimensionar, apps)", controls.contains("arraste as janelas") and controls.contains("E-mail")) and ok
	ok = _check("controles: o texto cabe no painel (nao passa do botao Voltar)", controls.split("\n").size() <= 14) and ok

	# --- placar vazio ---
	ok = _check("placar: botao entre Controles e Sair", menu.main_buttons.get_child(menu.scores_button.get_index() - 1) == menu.controls_button and menu.main_buttons.get_child(menu.scores_button.get_index() + 1) == menu.quit_button) and ok
	ok = _check("placar: painel comeca fechado", not menu.scores_panel.visible) and ok
	menu._on_scores_pressed()
	ok = _check("placar: abre e esconde os botoes do menu", menu.scores_panel.visible and not menu.main_buttons.visible) and ok
	ok = _check("placar vazio: avisa que nao ha tempos", menu.scores_panel.get_node("Rows") is Label and menu.scores_panel.get_node("Rows").text.contains("Nenhum tempo")) and ok
	menu._close_scores()
	ok = _check("placar: voltar fecha e mostra o menu", not menu.scores_panel.visible and menu.main_buttons.visible) and ok

	# --- placar com tempos ---
	for pair in [["BETO", 520000], ["ANA", 400000], ["CAIO", 610000]]:
		board.start_run(pair[0])
		board._elapsed_msec = pair[1]
		board.finish_run()
	menu._on_scores_pressed()
	var rows: Node = menu.scores_panel.get_node("Rows")
	var texts: Array = []
	for child in rows.get_children():
		texts.append((child as Label).text)
	ok = _check("placar: 3 linhas de 3 colunas", rows is GridContainer and texts.size() == 9) and ok
	ok = _check("placar: ordenado do menor tempo para o maior", texts.slice(0, 9) == ["1.", "ANA", "06:40.00", "2.", "BETO", "08:40.00", "3.", "CAIO", "10:10.00"]) and ok
	ok = _check("placar: o recordista fica em amarelo", (rows.get_child(1) as Label).get_theme_color("font_color") == Color("#ffd75f")) and ok
	menu._on_scores_pressed()
	ok = _check("placar: abrir de novo nao duplica a tabela", menu.scores_panel.get_children().filter(func(n: Node) -> bool: return n.name == "Rows").size() == 1) and ok

	# --- ESC fecha o placar ---
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	menu._unhandled_input(esc)
	ok = _check("placar: ESC fecha", not menu.scores_panel.visible) and ok

	board.clear_scores()
	board.cancel_run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://teste_menu_placar.cfg"))
	print("")
	print("OK: o menu principal esta certo." if ok else "FALHOU: veja as linhas FALHA acima.")
	quit(0 if ok else 1)


func _check(label: String, passed: bool) -> bool:
	print(("  ok     " if passed else "  FALHA  ") + label)
	return passed
