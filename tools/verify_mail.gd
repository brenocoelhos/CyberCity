extends SceneTree
## Verifica o app de E-mail do desktop: leitura das mensagens (resumo e
## cabecalhos completos), denuncias e a conclusao de m12 (c_email) e m13
## (c_triagem) so pelo app. Nao grava nada do jogador.
## Rodar: Godot --headless --path . --script res://tools/verify_mail.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.

var MailParser: GDScript = load("res://scripts/desktop/MailParser.gd")


func _initialize() -> void:
	await process_frame
	var desktop = root.get_node("DesktopManager")
	var terminal = root.get_node("TerminalManager")
	var data = root.get_node("ChallengeData")
	var session = root.get_node("ChallengeSession")
	var ok := true

	# --- leitor de mensagens ---
	var parsed: Dictionary = MailParser.parse("msg3.eml", data.get_challenge("c_triagem")["files"]["msg3.eml"], 9)
	ok = _check("parser: numero vem do nome do arquivo", int(parsed["number"]) == 3) and ok
	ok = _check("parser: remetente, assunto e data", String(parsed["from"]).contains("Roberto") and String(parsed["subject"]).contains("favor urgente") and String(parsed["date"]).contains("Oct 2026")) and ok
	ok = _check("parser: cabecalhos e corpo separados", String(parsed["headers"]).contains("Authentication-Results") and String(parsed["body"]).begins_with("Estou em reuniao") and not String(parsed["body"]).contains("Authentication")) and ok
	ok = _check("parser: nome do remetente sem o endereco", MailParser.sender_name(String(parsed["from"])) == "Roberto Mendes (Diretor)") and ok
	var multi: Dictionary = MailParser.parse("email.eml", data.get_challenge("c_email")["files"]["email.eml"])
	ok = _check("parser: cabecalho em varias linhas (Authentication-Results)", String(multi["headers"]).contains("dmarc=fail") and String(multi["from"]).contains("Suporte Banco Central")) and ok
	var portuguese: Dictionary = MailParser.parse("aviso.txt", data.get_challenge("c_vazamento")["files"]["aviso_vazamento.txt"])
	ok = _check("parser: cabecalhos em portugues (De/Assunto)", String(portuguese["subject"]).contains("Incidente") and String(portuguese["from"]).contains("lojafacil")) and ok

	# --- m12: um e-mail, indicios apontados no app ---
	ok = _check("c_email e c_triagem abrem o desktop com e-mail", data.uses_desktop("c_email") and data.uses_desktop("c_triagem")) and ok
	desktop.open("c_email", "casa-2")
	ok = _check("m12: icones E-mail, Terminal e Notas (sem Navegador)", desktop._icons["mail"].visible and desktop._icons["terminal"].visible and desktop._icons["notes"].visible and not desktop._icons["browser"].visible) and ok
	ok = _check("m12: o navegador nao abre", desktop.open_app("browser") == null) and ok
	var mail: Control = desktop.open_app("mail")
	ok = _check("m12: o e-mail abre ja com a unica mensagem", mail.message_count() == 1 and mail._current == 0) and ok
	ok = _check("m12: resumo mostra remetente e assunto, sem os cabecalhos de autenticacao", mail._head_label.text.contains("Suporte Banco Central") and mail._head_label.text.contains("URGENTE") and not mail._head_label.text.contains("spf=fail")) and ok
	ok = _check("m12: sem botao de denunciar mensagem (so uma)", not mail._flag_button.visible) and ok
	mail._raw_button.button_pressed = true
	ok = _check("m12: 'Cabecalhos completos' revela SPF/DKIM/Reply-To", mail._head_label.text.contains("spf=fail") and mail._head_label.text.contains("Reply-To")) and ok
	mail._on_help_pressed()
	ok = _check("m12: 'O que procurar?' lista as perguntas sem entregar respostas", mail._feedback.text.contains("O que procurar") and not mail._feedback.text.contains("spf=fail")) and ok

	mail._on_field_submitted("o spf falhou")
	ok = _check("m12: apontar um indicio certo conta", mail._feedback.text.contains("autenticação falhou") and mail._feedback.text.contains("1/3")) and ok
	mail._on_field_submitted("o spf falhou")
	ok = _check("m12: repetir o mesmo indicio nao conta de novo", mail._feedback.text.contains("já reportou") and terminal.report_progress().x == 1) and ok
	mail._on_field_submitted("data")
	ok = _check("m12: apontar algo que e normal em qualquer e-mail e erro", mail._feedback.text.contains("qualquer e-mail") and terminal.report_progress().x == 1) and ok
	mail._on_field_submitted("banana")
	ok = _check("m12: palavra sem sentido so pede para reler", mail._feedback.text.contains("Releia")) and ok
	ok = _check("m12: ainda nao concluiu", not session.is_completed("c_email")) and ok
	mail._on_field_submitted("reply-to")
	mail._on_field_submitted("o link leva para outro lugar")
	ok = _check("m12: terceiro indicio mostra a mensagem antes de fechar", desktop.is_open() and mail._feedback.text.contains("3/3")) and ok
	await create_timer(2.3).timeout
	ok = _check("m12: concluiu pelo app e o desktop fechou", session.is_completed("c_email") and not desktop.is_open()) and ok

	# --- m13: seis mensagens, tres golpes ---
	desktop.open("c_triagem", "casa-3")
	mail = desktop.open_app("mail")
	ok = _check("m13: seis mensagens na caixa de entrada", mail.message_count() == 6 and mail._list.item_count == 6) and ok
	ok = _check("m13: nenhuma aberta no comeco", mail._current == -1) and ok
	ok = _check("m13: botao de denunciar aparece com varias mensagens", mail._flag_button.visible) and ok
	mail._on_flag_pressed()
	ok = _check("m13: denunciar sem abrir mensagem pede para abrir uma", mail._feedback.text.contains("Abra uma mensagem")) and ok
	mail.show_message(1)
	mail._on_flag_pressed()
	ok = _check("m13: denunciar uma mensagem legitima e erro", mail._feedback.text.contains("legítima") and terminal.report_progress().x == 0) and ok
	mail.show_message(0)
	mail._on_flag_pressed()
	ok = _check("m13: denunciar um golpe conta e marca na lista", terminal.report_progress().x == 1 and mail._list.get_item_text(0).begins_with("[golpe]")) and ok
	mail.show_message(2)
	mail._on_flag_pressed()
	ok = _check("m13: o golpe do 'diretor' (passa no SPF) exige olhar o conjunto", terminal.report_progress().x == 2) and ok
	mail.show_message(4)
	mail._raw_button.button_pressed = true
	ok = _check("m13: cabecalhos completos da mensagem 5 mostram spf=fail", mail._head_label.text.contains("spf=fail")) and ok
	mail._on_flag_pressed()
	ok = _check("m13: terceiro golpe", terminal.report_progress().x == 3) and ok
	await create_timer(2.3).timeout
	ok = _check("m13: concluiu pelo app", session.is_completed("c_triagem") and not desktop.is_open()) and ok

	# --- o terminal continua funcionando nesses computadores ---
	desktop.open("c_triagem", "casa-3")
	session.reset()
	terminal._on_command_submitted("cat msg1.eml")
	ok = _check("terminal no desktop de e-mail ainda le os arquivos", terminal.output.get_total_character_count() > 100) and ok
	desktop.close()

	print("")
	print("OK: o app de e-mail funciona." if ok else "FALHOU: veja as linhas FALHA acima.")
	quit(0 if ok else 1)


func _check(label: String, passed: bool) -> bool:
	print(("  ok     " if passed else "  FALHA  ") + label)
	return passed
