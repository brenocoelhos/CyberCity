extends SceneTree
## Verifica o app de Arquivos do desktop: a lista, o conteudo com numero de
## linha, o filtro de linhas (como o grep) e a missao m14 (senha reutilizada)
## resolvida so pelo desktop (E-mail + Arquivos). Nao grava nada do jogador.
## Rodar: Godot --headless --path . --script res://tools/verify_files.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.


func _initialize() -> void:
	await process_frame
	var desktop = root.get_node("DesktopManager")
	var terminal = root.get_node("TerminalManager")
	var data = root.get_node("ChallengeData")
	var session = root.get_node("ChallengeSession")
	var ok := true

	ok = _check("c_vazamento abre o desktop", data.uses_desktop("c_vazamento")) and ok
	desktop.open("c_vazamento", "casa-4")
	ok = _check("m14: icones E-mail, Arquivos, Terminal e Notas (sem Navegador)", desktop._icons["mail"].visible and desktop._icons["files"].visible and desktop._icons["terminal"].visible and desktop._icons["notes"].visible and not desktop._icons["browser"].visible) and ok

	# --- e-mail: o aviso de vazamento ---
	var mail: Control = desktop.open_app("mail")
	ok = _check("m14: o e-mail traz so o aviso de vazamento", mail.message_count() == 1 and mail._head_label.text.contains("Incidente de seguranca")) and ok

	# --- arquivos ---
	var files: Control = desktop.open_app("files")
	ok = _check("m14: 4 arquivos listados (o aviso fica no e-mail)", files.file_names().size() == 4 and not files.file_names().has("aviso_vazamento.txt") and files._list.item_count == 4) and ok
	ok = _check("m14: nada aberto no comeco", files._current == "" and files._info.text.contains("Escolha")) and ok
	files.open_file("acessos_email.log")
	ok = _check("arquivo mostra as 9 linhas numeradas", files.visible_line_count() == 9 and files._viewer.text.contains("  1") and files._info.text.contains("9 linhas")) and ok
	files.set_filter("203.0.113.45")
	ok = _check("filtro mostra so as linhas do IP estranho (6)", files.visible_line_count() == 6 and files._info.text.contains("6 de 9")) and ok
	ok = _check("o termo fica destacado e as linhas do Marcos somem", files._viewer.text.contains("bgcolor") and not files._viewer.text.contains("198.51.100.23")) and ok
	files.set_filter("ROMENIA")
	ok = _check("filtro ignora maiusculas", files.visible_line_count() == 4) and ok
	files.set_filter("zzz")
	ok = _check("filtro sem resultado avisa", files.visible_line_count() == 0 and files._viewer.text.contains("Nenhuma linha")) and ok
	files.set_filter("")
	ok = _check("limpar o filtro volta o arquivo todo", files.visible_line_count() == 9) and ok
	files.open_file("lembretes.txt")
	ok = _check("outro arquivo abre sem o filtro anterior", files.visible_line_count() == 4 and files._viewer.text.contains("marcos2020")) and ok
	files.open_file("vazamento_lojafacil.csv")
	ok = _check("o CSV vazado abre", files._viewer.text.contains("hash_md5")) and ok
	files.open_file("naoexiste.txt")
	ok = _check("arquivo que nao esta na lista nao abre", files._current == "vazamento_lojafacil.csv") and ok

	# --- apontar os achados no proprio app (4 de 5 concluem) ---
	files._bar.show_checklist()
	ok = _check("'O que procurar?' lista as perguntas sem entregar respostas", files._bar.feedback.text.contains("O que procurar") and not files._bar.feedback.text.contains("203.0.113.45")) and ok
	files._bar.submit_text("mesma senha em varios servicos")
	ok = _check("achado 1 (reuso de senha) conta", terminal.report_progress().x == 1 and files._bar.feedback.text.contains("1/4")) and ok
	files._bar.submit_text("o ip da romenia")
	files._bar.submit_text("198.51.100.23")
	ok = _check("o IP habitual do Marcos e isca (erro)", terminal.report_progress().x == 2 and files._bar.feedback.text.contains("habitual")) and ok
	files._bar.submit_text("regra de encaminhamento")
	files._bar.submit_text("verificacao em duas etapas")
	ok = _check("quarto achado: o recado aparece antes de o desktop fechar", desktop.is_open() and files._bar.feedback.text.contains("4/4")) and ok
	await create_timer(2.3).timeout
	ok = _check("m14: concluiu pelo desktop (E-mail + Arquivos)", session.is_completed("c_vazamento") and not desktop.is_open()) and ok

	# --- o terminal continua com os mesmos arquivos ---
	desktop.open("c_vazamento", "casa-4")
	session.reset()
	terminal._on_command_submitted("grep romenia acessos_email.log")
	ok = _check("terminal desse computador ainda filtra o log", terminal.output.get_total_character_count() > 100) and ok
	desktop.close()

	print("")
	print("OK: o app de arquivos funciona." if ok else "FALHOU: veja as linhas FALHA acima.")
	quit(0 if ok else 1)


func _check(label: String, passed: bool) -> bool:
	print(("  ok     " if passed else "  FALHA  ") + label)
	return passed
