extends SceneTree
## Verifica o desktop do computador (piloto c_site): o conversor de HTML, o
## navegador e o gerenciador de janelas (várias janelas abertas, arrastar,
## redimensionar, maximizar, foco, minimizar/fechar, barra de tarefas) e o fim
## do desafio ao abrir a página-objetivo. Não usa a interface do jogador.
## Rodar: Godot --headless --path . --script res://tools/verify_desktop.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.

const COMPUTER := "res://scenes/computers/Computer.tscn"

var HtmlLite: GDScript = load("res://scripts/desktop/HtmlLite.gd")


func _initialize() -> void:
	await process_frame
	var desktop = root.get_node("DesktopManager")
	var terminal = root.get_node("TerminalManager")
	var data = root.get_node("ChallengeData")
	var session = root.get_node("ChallengeSession")
	var notes = root.get_node("PlayerNotes")
	var ok := true

	# --- conversor de HTML ---
	var home: String = data.CHALLENGES["c_site"]["hosts"]["site-datasoft"]["web"]["/"]
	var rendered: String = HtmlLite.render(home)
	ok = _check("html: titulo e texto aparecem", rendered.contains("DataSoft Sistemas") and rendered.contains("Solucoes em software")) and ok
	ok = _check("html: comentario fica escondido", not rendered.contains("legado") and not rendered.contains("TODO")) and ok
	ok = _check("html: sem tags soltas", not rendered.contains("<")) and ok
	ok = _check("html: <title> lido", HtmlLite.title_of(home) == "DataSoft Sistemas") and ok
	ok = _check("html: robots.txt nao e html", not HtmlLite.looks_like_html("User-agent: *\nDisallow: /interno/")) and ok
	var linked: String = HtmlLite.render("<html><body><p>Veja <a href=\"/x/\">aqui</a> [ok]</p></body></html>")
	ok = _check("html: link vira [url]", linked.contains("[url=/x/]") and linked.contains("aqui")) and ok
	ok = _check("html: colchetes do texto sao escapados", linked.contains("[lb]ok")) and ok

	# --- quais computadores abrem o desktop ---
	ok = _check("c_site abre o desktop", data.uses_desktop("c_site")) and ok
	ok = _check("os demais desafios continuam so no terminal", not data.uses_desktop("c_senhas") and not data.uses_desktop("c_cadeia") and not data.uses_desktop("")) and ok

	# --- o computador de c_site abre o desktop ---
	var computer: Node = (load(COMPUTER) as PackedScene).instantiate()
	computer.challenge_id = "c_site"
	root.add_child(computer)
	await process_frame
	computer._on_interact()
	await process_frame
	ok = _check("computador abre o desktop", desktop.is_open() and terminal.desktop_mode) and ok
	ok = _check("nenhuma janela aberta no inicio", desktop.window_count() == 0 and not terminal.is_window_visible()) and ok
	ok = _check("jogador bloqueado com o desktop aberto", terminal.is_active()) and ok
	ok = _check("recado do desafio aparece", desktop._note.visible and desktop._note_label.text.contains("Navegador")) and ok

	# --- varias janelas ao mesmo tempo ---
	var term_win: Control = desktop.open_app("terminal")
	var browser_a: Control = desktop.open_app("browser")
	var browser_b: Control = desktop.open_app("browser")
	var notes_win: Control = desktop.open_app("notes")
	await process_frame
	ok = _check("terminal, 2 navegadores e notas abertos juntos", desktop.window_count() == 4 and desktop.window_count("browser") == 2) and ok
	ok = _check("todas visiveis ao mesmo tempo", desktop.visible_windows().size() == 4 and term_win.visible and browser_a.visible) and ok
	ok = _check("terminal continua vivo atras das outras janelas", terminal.is_window_visible()) and ok
	ok = _check("a ultima aberta fica na frente e em foco", desktop.focused_window() == notes_win and desktop.visible_windows()[-1] == notes_win) and ok
	ok = _check("so o terminal em foco pega o teclado", not terminal.window_focused) and ok
	ok = _check("cada janela tem botao na barra de tarefas", desktop._task_row.get_child_count() == 4) and ok
	ok = _check("janelas em cascata (posicoes diferentes)", browser_a.position != browser_b.position and term_win.position != browser_a.position) and ok

	# --- foco por clique ---
	var inside_terminal: Vector2 = term_win.global_position + Vector2(8, 8)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = inside_terminal
	press.global_position = inside_terminal
	desktop._input(press)
	var covered: bool = false
	for other in desktop.visible_windows():
		if other != term_win and other.get_global_rect().has_point(inside_terminal) and other.get_index() > term_win.get_index():
			covered = true
	ok = _check("clicar numa janela a traz para a frente e em foco", covered or desktop.focused_window() == term_win) and ok
	desktop.focus_window(term_win)
	ok = _check("terminal em foco volta a pegar o teclado", desktop.focused_window() == term_win and terminal.window_focused and desktop.visible_windows()[-1] == term_win) and ok
	terminal._on_command_submitted("whoami")
	ok = _check("terminal em janela funciona (sessao viva)", terminal.output.get_total_character_count() > 50) and ok

	# --- botoes do desktop nao pegam foco de teclado: o terminal em foco reassume
	# o cursor a cada quadro e, se o botao tivesse foco, o clique no icone ou na
	# barra de tarefas era cancelado no meio (nao dava para abrir outro navegador) ---
	var focusable: Array = []
	for button in desktop._root.find_children("*", "Button", true, false):
		var inside_window: bool = false
		for window in desktop.visible_windows():
			if window.is_ancestor_of(button):
				inside_window = true
		if not inside_window and (button as Button).focus_mode != Control.FOCUS_NONE:
			focusable.append((button as Button).text)
	ok = _check("icones, barra de tarefas e Desligar nao pegam foco (clique nao e cancelado)", focusable.is_empty()) and ok

	# --- arrastar pela barra de titulo ---
	var drag_press := InputEventMouseButton.new()
	drag_press.button_index = MOUSE_BUTTON_LEFT
	drag_press.pressed = true
	var start: Vector2 = browser_a.global_position + Vector2(100, 10)
	drag_press.global_position = start
	drag_press.position = start
	desktop._on_title_input(drag_press, browser_a)
	var before: Vector2 = browser_a.position
	var motion := InputEventMouseMotion.new()
	motion.position = start + Vector2(150, 60)
	motion.global_position = motion.position
	desktop._input(motion)
	ok = _check("arrastar move a janela junto com o mouse", browser_a.position == before + Vector2(150, 60)) and ok
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	desktop._input(release)
	motion.position = start + Vector2(400, 200)
	desktop._input(motion)
	ok = _check("soltar o mouse encerra o arrasto", browser_a.position == before + Vector2(150, 60)) and ok
	desktop._drag = {"node": browser_a, "offset": Vector2.ZERO}
	motion.position = Vector2(-5000, -5000)
	desktop._input(motion)
	ok = _check("janela nao sai da tela (sobra a barra de titulo)", browser_a.position.x >= 120.0 - browser_a.size.x and browser_a.position.y >= 0.0) and ok
	desktop._drag = {}

	# --- redimensionar ---
	var grip: Control = browser_b.get_child(browser_b.get_child_count() - 1)
	var size_before: Vector2 = browser_b.size
	var grip_press := InputEventMouseButton.new()
	grip_press.button_index = MOUSE_BUTTON_LEFT
	grip_press.pressed = true
	grip_press.global_position = Vector2(500, 400)
	grip.gui_input.emit(grip_press)
	var grow := InputEventMouseMotion.new()
	grow.position = Vector2(500, 400) + Vector2(40, 30)
	desktop._input(grow)
	ok = _check("redimensionar pelo canto aumenta a janela", browser_b.size == size_before + Vector2(40, 30)) and ok
	grow.position = Vector2(500, 400) - Vector2(5000, 5000)
	desktop._input(grow)
	ok = _check("redimensionar respeita o tamanho minimo", browser_b.size == browser_b.min_size) and ok
	desktop._input(release)

	# --- maximizar e restaurar ---
	var rect_before := Rect2(browser_b.position, browser_b.size)
	desktop.toggle_maximize(browser_b)
	ok = _check("maximizar ocupa a area de trabalho", browser_b.position == Vector2.ZERO and browser_b.size == desktop._work_size()) and ok
	desktop.toggle_maximize(browser_b)
	ok = _check("maximizar de novo restaura o tamanho", Rect2(browser_b.position, browser_b.size) == rect_before) and ok

	# --- terminal redimensionado reorganiza o conteudo ---
	term_win.size = Vector2(640, 380)
	await process_frame
	var out: Control = terminal.output
	ok = _check("terminal redimensionado: o texto acompanha a janela", out.get_global_rect().end.x <= term_win.get_global_rect().end.x and out.get_global_rect().end.y < term_win.get_global_rect().end.y) and ok
	ok = _check("terminal redimensionado: campo de comando segue embaixo", terminal.input_line.get_global_rect().end.y <= term_win.get_global_rect().end.y) and ok
	var window_rect: Rect2 = term_win.get_global_rect()
	ok = _check("terminal: barra de status, prompt e campo ficam dentro da janela", window_rect.encloses(terminal.status_bar.get_global_rect()) and window_rect.encloses(terminal.prompt_top.get_global_rect()) and window_rect.encloses(terminal.input_line.get_global_rect())) and ok

	# --- minimizar / fechar ---
	desktop.minimize_window(notes_win)
	ok = _check("minimizar esconde a janela e mantem o botao", not notes_win.visible and desktop.window_count("notes") == 1) and ok
	ok = _check("foco passa para a janela de tras", desktop.focused_window() != notes_win and desktop.focused_window() != null) and ok
	desktop._on_task_pressed(notes_win)
	ok = _check("botao da barra de tarefas restaura a janela", notes_win.visible and desktop.focused_window() == notes_win) and ok
	desktop._on_task_pressed(notes_win)
	ok = _check("clicar no botao da janela em foco minimiza", not notes_win.visible) and ok
	desktop.close_window(browser_a)
	await process_frame
	ok = _check("fechar remove o navegador e o botao", desktop.window_count("browser") == 1 and desktop._task_row.get_child_count() == 3) and ok
	desktop.close_window(term_win)
	await process_frame
	ok = _check("fechar o terminal tira da tela e da barra, sem encerrar", not terminal.is_window_visible() and desktop.is_open() and desktop._task_row.get_child_count() == 2) and ok
	desktop.open_app("terminal")
	ok = _check("terminal reabre com a sessao e a tela de antes", terminal.is_window_visible() and terminal.output.get_total_character_count() > 50) and ok

	# --- notas sao as mesmas do celular ---
	notes_win = desktop.open_app("notes")
	notes_win._editor.text = "ip do alvo: 192.168.1.50"
	notes_win._on_text_changed()
	ok = _check("notas do desktop gravam no PlayerNotes", notes.text == "ip do alvo: 192.168.1.50") and ok
	ok = _check("so existe uma janela de notas", desktop.window_count("notes") == 1 and desktop.open_app("notes") == notes_win) and ok

	# --- navegador ---
	var browser: Control = browser_b
	desktop.focus_window(browser)
	ok = _check("nova aba mostra o favorito do alvo", browser._view.text.contains("192.168.1.50")) and ok
	browser.navigate("192.168.1.50")
	ok = _check("endereco sem http e sem barra funciona", browser._address.text == "http://192.168.1.50/" and String(browser._current["status"]) == "ok") and ok
	ok = _check("pagina renderizada sem o comentario", browser._view.text.contains("DataSoft Sistemas") and not browser._view.text.contains("legado")) and ok
	ok = _check("titulo da janela acompanha a pagina", browser.title_label.text.contains("DataSoft Sistemas")) and ok
	browser._on_source_toggled(true)
	ok = _check("codigo-fonte mostra o comentario escondido", browser._view.text.contains("/legado/")) and ok
	browser._on_source_toggled(false)
	browser.navigate("/robots.txt")
	ok = _check("caminho relativo usa o mesmo servidor", browser._address.text == "http://192.168.1.50/robots.txt" and browser._view.text.contains("/interno/")) and ok
	browser.navigate("/legado/")
	ok = _check("indice de pasta vira links", browser._view.text.contains("[url=/legado/config.php.bak]")) and ok
	browser.navigate("10.9.9.9")
	ok = _check("endereco desconhecido mostra erro", String(browser._current["status"]) == "dns" and browser._view.text.contains("Não foi possível")) and ok
	browser.navigate("192.168.1.50/zzz")
	ok = _check("404 em servidor conhecido", String(browser._current["status"]) == "notfound" and browser._view.text.contains("404")) and ok
	browser._on_back()
	ok = _check("voltar retorna a pagina anterior", browser._address.text != "http://192.168.1.50/zzz") and ok

	# --- ESC: minimiza a janela da frente ---
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	desktop.focus_window(browser)
	desktop._input(esc)
	ok = _check("ESC minimiza a janela da frente", not browser.visible and desktop.is_open()) and ok
	desktop.focus_window(browser)

	# --- abrir a pagina-objetivo conclui o desafio e fecha o desktop ---
	ok = _check("desafio ainda nao concluido", not session.is_completed("c_site")) and ok
	browser.navigate("192.168.1.50/legado/config.php.bak")
	ok = _check("config exposto aparece como texto", browser._view.text.contains("Painel@2019")) and ok
	await create_timer(1.3).timeout
	ok = _check("desafio concluido pelo navegador", session.is_completed("c_site")) and ok
	ok = _check("desktop fecha ao concluir", not desktop.is_open() and not terminal.desktop_mode) and ok
	ok = _check("jogador solto depois", not terminal.is_active()) and ok
	ok = _check("terminal volta ao lugar de tela cheia", terminal.monitor.get_parent() == terminal and terminal.monitor.visible and not desktop._terminal_grip.visible) and ok

	# --- Desligar: encerra tudo ---
	desktop.open("c_site", "teste")
	desktop.open_app("browser")
	ok = _check("abre de novo, sem janelas antigas", desktop.is_open() and desktop.window_count() == 1) and ok
	desktop.close()
	ok = _check("desligar encerra o desktop e a sessao", not desktop.is_open() and not terminal.desktop_mode and not terminal.is_active()) and ok

	# --- terminal comum (sem desktop) continua em tela cheia ---
	terminal.open("c_senhas", "estacao1")
	ok = _check("terminal fora do desktop: tela cheia com fundo", terminal.backdrop.visible and terminal.is_window_visible() and terminal.monitor.get_parent() == terminal) and ok
	terminal.close()

	print("")
	print("OK: o desktop funciona." if ok else "FALHOU: veja as linhas FALHA acima.")
	quit(0 if ok else 1)


func _check(label: String, passed: bool) -> bool:
	print(("  ok     " if passed else "  FALHA  ") + label)
	return passed


