extends SceneTree
## Verifica o desktop do computador (piloto c_site): o conversor de HTML, o
## navegador, as janelas Terminal/Navegador e o fim do desafio ao abrir a
## página-objetivo. Não usa a interface do jogador.
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
	ok = _check("terminal nao aparece sozinho", not terminal.is_window_visible()) and ok
	ok = _check("jogador bloqueado com o desktop aberto", terminal.is_active()) and ok
	ok = _check("recado do desafio aparece", desktop._note.visible and desktop._note_label.text.contains("Navegador")) and ok

	# --- janelas ---
	desktop._show_app("terminal")
	ok = _check("terminal abre como janela", terminal.is_window_visible() and not terminal.backdrop.visible) and ok
	terminal._on_command_submitted("whoami")
	desktop._show_app("browser")
	ok = _check("navegador minimiza o terminal", desktop._browser.visible and not terminal.is_window_visible()) and ok
	ok = _check("fechar o terminal nao encerra a sessao", desktop.is_open()) and ok
	desktop._show_app("terminal")
	ok = _check("terminal volta com a sessao", terminal.is_window_visible() and terminal.output.get_total_character_count() > 50) and ok
	terminal._close_window()
	ok = _check("ESC/exit no desktop so minimiza", not terminal.is_window_visible() and desktop.is_open()) and ok

	# --- navegador ---
	desktop._show_app("browser")
	var browser = desktop._browser
	ok = _check("nova aba mostra o favorito do alvo", browser._view.text.contains("192.168.1.50")) and ok
	browser.navigate("192.168.1.50")
	ok = _check("endereco sem http e sem barra funciona", browser._address.text == "http://192.168.1.50/" and String(browser._current["status"]) == "ok") and ok
	ok = _check("pagina renderizada sem o comentario", browser._view.text.contains("DataSoft Sistemas") and not browser._view.text.contains("legado")) and ok
	browser._on_source_toggled(true)
	ok = _check("codigo-fonte mostra o comentario escondido", browser._view.text.contains("/legado/")) and ok
	browser._on_source_toggled(false)
	browser.navigate("/robots.txt")
	ok = _check("caminho relativo usa o mesmo servidor", browser._address.text == "http://192.168.1.50/robots.txt" and browser._view.text.contains("/interno/")) and ok
	browser.navigate("/legado/")
	ok = _check("indice de pasta vira links", browser._view.text.contains("[url=/legado/config.php.bak]")) and ok
	browser.navigate("10.9.9.9")
	ok = _check("endereco desconhecido mostra erro", String(browser._current["status"]) == "dns" and browser._view.text.contains("Não foi possível")) and ok
	browser.navigate("/naoexiste")
	ok = _check("pagina inexistente mostra 404", browser._view.text.contains("404") or String(browser._current["status"]) == "dns") and ok
	browser.navigate("192.168.1.50/zzz")
	ok = _check("404 em servidor conhecido", String(browser._current["status"]) == "notfound" and browser._view.text.contains("404")) and ok
	browser._on_back()
	ok = _check("voltar retorna a pagina anterior", browser._address.text != "http://192.168.1.50/zzz") and ok

	# --- ESC: navegador, depois desktop ---
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	desktop._input(esc)
	ok = _check("ESC minimiza o navegador", not desktop._browser.visible and desktop.is_open()) and ok
	desktop._show_app("browser")

	# --- abrir a pagina-objetivo conclui o desafio e fecha o desktop ---
	ok = _check("desafio ainda nao concluido", not session.is_completed("c_site")) and ok
	browser.navigate("192.168.1.50/legado/config.php.bak")
	ok = _check("config exposto aparece como texto", browser._view.text.contains("Painel@2019")) and ok
	await create_timer(1.3).timeout
	ok = _check("desafio concluido pelo navegador", session.is_completed("c_site")) and ok
	ok = _check("desktop fecha ao concluir", not desktop.is_open() and not terminal.desktop_mode) and ok
	ok = _check("jogador solto depois", not terminal.is_active()) and ok

	# --- Desligar: encerra tudo ---
	desktop.open("c_site", "teste")
	ok = _check("abre de novo", desktop.is_open()) and ok
	desktop.close()
	ok = _check("desligar encerra o desktop e a sessao", not desktop.is_open() and not terminal.desktop_mode and not terminal.is_active()) and ok

	print("")
	print("OK: o desktop funciona." if ok else "FALHOU: veja as linhas FALHA acima.")
	quit(0 if ok else 1)


func _check(label: String, passed: bool) -> bool:
	print(("  ok     " if passed else "  FALHA  ") + label)
	return passed
