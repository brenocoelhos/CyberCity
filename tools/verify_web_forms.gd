extends SceneTree
## Verifica os formularios do navegador: o conversor de HTML separa os campos,
## e m09 (SQL Injection), m10 (XSS) e m11 (roteador) se resolvem pelo
## Navegador do desktop. Nao grava nada do jogador.
## Rodar: Godot --headless --path . --script res://tools/verify_web_forms.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.

var HtmlLite: GDScript = load("res://scripts/desktop/HtmlLite.gd")


func _initialize() -> void:
	await process_frame
	var desktop = root.get_node("DesktopManager")
	var terminal = root.get_node("TerminalManager")
	var data = root.get_node("ChallengeData")
	var session = root.get_node("ChallengeSession")
	var ok := true

	# --- conversor: formularios ---
	var page := "<html><body><h1>Oi</h1><p>antes</p><form action=\"/x\" method=\"post\"><label>Nome</label><input name=\"nome\" placeholder=\"seu nome\"><label>Senha</label><input name=\"senha\" type=\"password\"><input type=\"hidden\" name=\"token\" value=\"abc\"><textarea name=\"msg\" placeholder=\"texto\"></textarea><button>Enviar já</button></form><p>depois</p></body></html>"
	var parts: Array = HtmlLite.blocks(page)
	ok = _check("html: pagina com formulario vira 3 blocos (texto, formulario, texto)", parts.size() == 3 and parts[1]["type"] == "form") and ok
	var form: Dictionary = parts[1]
	ok = _check("html: acao e metodo", form["action"] == "/x" and form["method"] == "post") and ok
	ok = _check("html: 4 campos na ordem", form["fields"].size() == 4 and form["fields"][0]["name"] == "nome" and form["fields"][3]["name"] == "msg") and ok
	ok = _check("html: rotulo e dica do campo", form["fields"][0]["label"] == "Nome" and form["fields"][0]["placeholder"] == "seu nome") and ok
	ok = _check("html: tipos (texto, senha, oculto, area)", form["fields"][0]["kind"] == "text" and form["fields"][1]["kind"] == "password" and form["fields"][2]["kind"] == "hidden" and form["fields"][3]["kind"] == "textarea") and ok
	ok = _check("html: valor do campo oculto e texto do botao", form["fields"][2]["value"] == "abc" and form["submit"] == "Enviar já") and ok
	ok = _check("html: pagina sem formulario e um bloco so", HtmlLite.blocks("<html><body><p>oi</p></body></html>").size() == 1) and ok

	# --- os tres desafios abrem o desktop com navegador ---
	for id in ["c_sqli", "c_xss", "c_roteador"]:
		ok = _check("%s abre o desktop com navegador e terminal" % id, data.uses_desktop(id) and Array(data.get_challenge(id)["apps"]) == ["browser", "terminal", "notes"]) and ok

	# --- m09: SQL Injection no formulario ---
	desktop.open("c_sqli", "prefeitura")
	var web: Control = desktop.open_app("browser")
	ok = _check("m09: o favorito leva ao portal", web._view.text.contains("192.168.0.20")) and ok
	web.navigate("192.168.0.20")
	ok = _check("m09: o portal mostra o formulario de login", web._forms.size() == 1 and web._forms[0]["inputs"].has("usuario") and web._forms[0]["inputs"]["senha"].secret) and ok
	ok = _check("m09: titulo e texto da pagina continuam acima do formulario", web._view.text.contains("Portal do Servidor")) and ok
	web.submit_form(0, {"usuario": "maria", "senha": "123456"})
	ok = _check("m09: login errado mostra o recado e continua no formulario", web._view.text.contains("inválidos") and web._forms.size() == 1) and ok
	ok = _check("m09: login errado conta como erro", session.get_stats("c_sqli")["errors"] >= 1) and ok
	web.submit_form(0, {"usuario": "admin", "senha": "senha' --"})
	ok = _check("m09: aspas sozinhas nao entram", not session.is_completed("c_sqli") and web._view.text.contains("inválidos")) and ok
	web.submit_form(0, {"usuario": "' OR '1'='1", "senha": "qualquer"})
	ok = _check("m09: injecao no campo de usuario entra no painel", web._address.text == "http://192.168.0.20/painel" and web._view.text.contains("Painel do Servidor") and web._view.text.contains("sem validar")) and ok
	ok = _check("m09: a pagina aparece antes de o desafio fechar", desktop.is_open() and not session.is_completed("c_sqli")) and ok
	await create_timer(2.6).timeout
	ok = _check("m09: concluiu pelo navegador", session.is_completed("c_sqli") and not desktop.is_open()) and ok

	# --- m10: XSS no campo de comentario ---
	desktop.open("c_xss", "blog")
	web = desktop.open_app("browser")
	web.navigate("192.168.0.30/comentarios")
	ok = _check("m10: pagina de comentarios com campo de texto", web._forms.size() == 1 and web._forms[0]["inputs"]["mensagem"] is TextEdit) and ok
	ok = _check("m10: lista de comentarios comeca vazia", web._view.text.contains("nenhum comentário")) and ok
	web.submit_form(0, {"mensagem": "Que bom ver o bairro animado!"})
	ok = _check("m10: comentario normal aparece na lista, sem concluir", web._view.text.contains("Que bom ver o bairro") and not session.is_completed("c_xss") and not web._alert.visible) and ok
	web.submit_form(0, {"mensagem": "<script>alert('oi')</script>"})
	ok = _check("m10: o <script> aparece como texto na lista (nao some)", web._view.text.contains("<script>alert")) and ok
	ok = _check("m10: aparece a janelinha de alerta (o script rodaria)", web._alert.visible and web._alert_label.text.contains("rodou")) and ok
	await create_timer(3.4).timeout
	ok = _check("m10: concluiu pelo navegador", session.is_completed("c_xss") and not desktop.is_open()) and ok

	# --- m11: roteador de fabrica ---
	desktop.open("c_roteador", "casa-6")
	web = desktop.open_app("browser")
	web.navigate("192.168.0.1/painel")
	ok = _check("m11: painel fechado leva de volta ao login com aviso", web._forms[0]["inputs"].has("usuario") and web._view.text.contains("Entre no painel primeiro")) and ok
	web.submit_form(0, {"usuario": "admin", "senha": "1234"})
	ok = _check("m11: senha errada e recusada", web._view.text.contains("incorretos") and not terminal.get("_router_logged_in")) and ok
	web.submit_form(0, {"usuario": "admin", "senha": "admin"})
	ok = _check("m11: senha de fabrica entra no painel", web._address.text == "http://192.168.0.1/painel" and web._view.text.contains("senha de fábrica") and terminal.get("_router_logged_in")) and ok
	web.submit_form(0, {"nova": "admin"})
	ok = _check("m11: senha nova fraca e recusada com o motivo", web._view.text.contains("recusada") and not session.is_completed("c_roteador")) and ok
	web.submit_form(0, {"nova": "Xk9#mPq2vL!zRt7"})
	ok = _check("m11: senha forte altera e mostra o recado antes de fechar", web._view.text.contains("alterada") and desktop.is_open()) and ok
	await create_timer(2.6).timeout
	ok = _check("m11: concluiu pelo navegador", session.is_completed("c_roteador") and not desktop.is_open()) and ok

	# --- o login do terminal e o do navegador compartilham o estado ---
	session.reset()
	desktop.open("c_roteador", "casa-6")
	terminal._on_command_submitted("login admin admin")
	web = desktop.open_app("browser")
	web.navigate("192.168.0.1/painel")
	ok = _check("m11: logar no terminal libera o painel no navegador", web._forms[0]["inputs"].has("nova")) and ok
	desktop.close()

	print("")
	print("OK: os formularios do navegador funcionam." if ok else "FALHOU: veja as linhas FALHA acima.")
	quit(0 if ok else 1)


func _check(label: String, passed: bool) -> bool:
	print(("  ok     " if passed else "  FALHA  ") + label)
	return passed
