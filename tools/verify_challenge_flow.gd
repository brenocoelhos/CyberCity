extends SceneTree
## Joga os desafios pelo terminal e pelo quiz, comando a comando, sem a
## interface: abrir o computador aceita a missão, erro não conclui, acerto
## conclui e fecha o terminal, repetir não dá XP de novo, e as dicas em
## camadas aparecem iguais no terminal, no quiz e no celular.
## Rodar: Godot --headless --path . --script res://tools/verify_challenge_flow.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.
##
## Observação: o teste conclui vários capítulos seguidos sem fechar os
## diálogos, então o CampaignManager imprime "Signal 'closed' is already
## connected". Isso é esperado aqui (um jogador fecha o diálogo antes).

func _initialize() -> void:
	await process_frame
	var term = root.get_node("TerminalManager")
	var quiz = root.get_node("ChallengeManager")
	var session = root.get_node("ChallengeSession")
	var missions = root.get_node("MissionManager")
	var game = root.get_node("GameManager")
	var ok := true

	# --- logs (terminal) ---
	term.open("c_logs", "loja")
	ok = _check("abrir terminal ativa m08", missions.is_active("m08")) and ok
	term._on_command_submitted("report 2")
	ok = _check("erro nao conclui", not missions.is_completed("m08") and term.is_active()) and ok
	var phone = root.get_node("PhoneManager")
	ok = _check("celular ja tem 1 pista (gratis)", phone.get_revealed_clues("m08").size() == 1) and ok
	var signals := [0]
	phone.clue_revealed.connect(func(_id): signals[0] += 1)
	term._on_command_submitted("dica")
	ok = _check("dica no terminal revela a 2a camada tambem no celular", phone.get_revealed_clues("m08").size() == 2 and signals[0] == 1) and ok
	term._on_command_submitted("report 5")
	ok = _check("acerto conclui m08 e fecha terminal", missions.is_completed("m08") and not term.is_active()) and ok
	var s: Dictionary = session.get_stats("c_logs")
	ok = _check("stats logs: 2 tentativas, 1 erro, 1 dica", s["attempts"] == 2 and s["errors"] == 1 and s["hints"] == 1) and ok
	var xp_before: int = game.total_xp_earned
	term.open("c_logs", "loja")
	term._on_command_submitted("report 5")
	ok = _check("repetir nao da XP de novo", game.total_xp_earned == xp_before) and ok
	ok = _check("repetir nao fecha o terminal", term.is_active()) and ok
	term.close()

	# --- rede (terminal) ---
	term.open("c_rede", "servidor")
	term._on_command_submitted("connect 192.168.1.10")
	ok = _check("conectar em host normal nao conclui", not missions.is_completed("m06")) and ok
	term._on_command_submitted("connect 192.168.1.50")
	ok = _check("host suspeito conclui m06", missions.is_completed("m06")) and ok

	# --- firewall ---
	term.open("c_firewall", "fw")
	for cmd in ["firewall allow 80", "firewall allow 443", "firewall block 23", "firewall block 4444"]:
		term._on_command_submitted(cmd)
	ok = _check("firewall completo conclui m07", missions.is_completed("m07")) and ok

	# --- sqli e xss ---
	term.open("c_sqli", "login")
	term._on_command_submitted("login admin")
	ok = _check("sqli errado nao conclui", not missions.is_completed("m09")) and ok
	term._on_command_submitted("login ' OR '1'='1")
	ok = _check("sqli certo conclui m09", missions.is_completed("m09")) and ok
	term.open("c_xss", "coment")
	term._on_command_submitted("postar ola")
	ok = _check("xss comum nao conclui", not missions.is_completed("m10")) and ok
	term._on_command_submitted("postar <script>alert(1)</script>")
	ok = _check("xss certo conclui m10", missions.is_completed("m10")) and ok
	ok = _check("xss comum nao contou erro", session.get_stats("c_xss")["errors"] == 0) and ok

	# --- quiz ---
	quiz.start("c_senhas")
	ok = _check("quiz inicia m02", missions.is_active("m02")) and ok
	quiz._on_option_pressed(0)
	ok = _check("quiz errado nao conclui", not missions.is_completed("m02")) and ok
	quiz._on_hint_pressed()
	quiz._on_option_pressed(2)
	ok = _check("quiz certo conclui m02", missions.is_completed("m02") and not quiz.is_active()) and ok
	var q: Dictionary = session.get_stats("c_senhas")
	ok = _check("stats quiz: 2 tentativas, 1 erro, 1 dica", q["attempts"] == 2 and q["errors"] == 1 and q["hints"] == 1) and ok
	quiz.start("c_senhas")
	ok = _check("quiz concluido avisa na tela", quiz.feedback_label.text.find("já concluiu") != -1) and ok
	quiz.close()

	# --- celular pede a proxima pista (mesma fonte) ---
	missions.start_mission("m03")
	ok = _check("m03 comecou com 1 pista", phone.get_revealed_clues("m03").size() == 1) and ok
	ok = _check("celular revela a 2a", phone.reveal_next_clue("m03") and phone.get_revealed_clues("m03").size() == 2) and ok
	ok = _check("quiz ve as mesmas camadas", session.get_revealed_hints("c_hash").size() == 2) and ok
	phone.reveal_next_clue("m03")
	ok = _check("sem mais pistas apos a 3a", not phone.has_more_clues("m03") and not phone.reveal_next_clue("m03")) and ok

	# --- m01 (sem desafio) continua com as pistas locais ---
	missions.start_mission("m01")
	ok = _check("m01 usa CLUES local: 1 pista na partida", phone.get_revealed_clues("m01").size() == 1) and ok
	ok = _check("m01 revela a 2a pista", phone.reveal_next_clue("m01") and phone.get_revealed_clues("m01").size() == 2) and ok

	# --- arquivos que existem so em um computador ---
	term.open("c_roteador", "casa-6")
	term._on_command_submitted("files")
	ok = _check("roteador lista manual.txt", term.output.get_parsed_text().find("manual.txt") != -1) and ok
	ok = _check("roteador ainda lista os arquivos comuns", term.output.get_parsed_text().find("readme.txt") != -1) and ok
	term._on_command_submitted("read manual.txt")
	ok = _check("ler manual mostra a credencial de fabrica", term.output.get_parsed_text().find("senha:   admin") != -1) and ok
	term._on_command_submitted("clear")
	term._on_command_submitted("grep senha manual.txt")
	var grep_out: String = term.output.get_parsed_text()
	ok = _check("grep mostra a linha que tem o termo", grep_out.find("senha:   admin") != -1) and ok
	ok = _check("grep esconde as linhas sem o termo", grep_out.find("Ligue o roteador") == -1) and ok
	term._on_command_submitted("clear")
	term._on_command_submitted("grep GUIA manual.txt")
	ok = _check("grep ignora maiusculas", term.output.get_parsed_text().find("Guia rápido") != -1) and ok
	term._on_command_submitted("clear")
	term._on_command_submitted("grep xyz manual.txt")
	var none_out: String = term.output.get_parsed_text()
	ok = _check("grep sem resultado nao escreve linhas do arquivo", none_out.find("usuário") == -1 and none_out.find("Guia") == -1 and none_out.find("não encontrado") == -1) and ok
	term._on_command_submitted("clear")
	term._on_command_submitted("grep admin nao_existe.txt")
	ok = _check("grep em arquivo inexistente avisa", term.output.get_parsed_text().find("arquivo não encontrado") != -1) and ok
	term.close()
	term.open("c_logs", "loja")
	term._on_command_submitted("files")
	ok = _check("outro computador nao lista manual.txt", term.output.get_parsed_text().find("manual.txt") == -1) and ok
	term.close()

	# --- palavras-chave do report: curtas so valem como palavra inteira ---
	var kw_targets := [{"keywords": ["2fa", "3"]}, {"keywords": ["senha"]}]
	ok = _check("keyword curta como palavra inteira: 'ativar 2FA'", term._find_report_target("ativar 2FA", kw_targets) == 0) and ok
	ok = _check("keyword curta com pontuacao: 'mensagem 3.'", term._find_report_target("mensagem 3.", kw_targets) == 0) and ok
	ok = _check("keyword curta nao vale dentro de outra palavra: '23' e 'x2fax'", term._find_report_target("23", kw_targets) == -1 and term._find_report_target("x2fax", kw_targets) == -1) and ok
	ok = _check("keyword longa vale dentro do texto: 'trocar a senha'", term._find_report_target("trocar a senha", kw_targets) == 1) and ok

	# --- frases naturais devem achar o alvo certo (indice do alvo em "targets") ---
	var data = root.get_node("ChallengeData")
	var mail_targets: Array = data.CHALLENGES["c_email"]["targets"]
	var mail_cases := {
		"a autenticação falhou": 0, "o servidor reprovou o SPF": 0, "o reply-to é outro": 1, "manda a resposta para outro lugar": 1,
		"o domínio é falso": 2, "o remetente imita o banco": 2, "o link leva a outro site": 3, "o endereço do botão": 3,
		"tem urgência": 4, "ameaça de bloqueio em 24 horas": 4, "message-id": 5, "a data": 5,
	}
	for phrase in mail_cases.keys():
		ok = _check("e-mail: '%s' -> alvo %d" % [phrase, mail_cases[phrase]], term._find_report_target(phrase, mail_targets) == mail_cases[phrase]) and ok
	var leak_targets: Array = data.CHALLENGES["c_vazamento"]["targets"]
	var leak_cases := {
		"ele usa a mesma senha em tudo": 0, "senha repetida": 0, "reutilização de senha": 0, "credential stuffing": 0,
		"o ip 203.0.113.45": 1, "o atacante da Romênia": 1, "uma regra de encaminhamento": 2, "ele redirecionou os e-mails": 2,
		"verificação em duas etapas": 3, "ativar o MFA": 3, "autenticação de dois fatores": 3, "usar um gerenciador de senhas": 4,
		"uma senha única para cada site": 4, "ip habitual do marcos": 5,
	}
	for phrase in leak_cases.keys():
		ok = _check("vazamento: '%s' -> alvo %d" % [phrase, leak_cases[phrase]], term._find_report_target(phrase, leak_targets) == leak_cases[phrase]) and ok

	# --- roteador domestico (login + passwd) ---
	term.open("c_roteador", "casa-6")
	ok = _check("abrir o roteador ativa a m11", missions.is_active("m11")) and ok
	term._on_command_submitted("passwd Qualquer#Coisa2026")
	ok = _check("passwd sem login e recusado", not missions.is_completed("m11")) and ok
	term._on_command_submitted("login admin 1234")
	term._on_command_submitted("login root root")
	ok = _check("login errado nao entra", not term._router_logged_in) and ok
	term._on_command_submitted("login admin")
	ok = _check("login sem senha nao entra", not term._router_logged_in) and ok
	term._on_command_submitted("login admin admin")
	ok = _check("credencial de fabrica entra", term._router_logged_in and not missions.is_completed("m11")) and ok
	for weak in ["admin", "curta1!", "somenteletrasmuitolongas", "SemSimbolo12345", "Senha#Forte2026"]:
		term._on_command_submitted("passwd " + weak)
		ok = _check("senha fraca recusada: " + weak, not missions.is_completed("m11")) and ok
	ok = _check("senha fraca nao fecha o terminal", term.is_active()) and ok
	term._on_command_submitted("passwd Casa#Segura2026!")
	ok = _check("senha forte conclui a m11 e fecha o terminal", missions.is_completed("m11") and not term.is_active()) and ok
	var rs: Dictionary = session.get_stats("c_roteador")
	ok = _check("stats roteador: 7 erros (2 logins + 5 senhas fracas) e 9 tentativas", rs["errors"] == 7 and rs["attempts"] == 9) and ok
	term.open("c_roteador", "casa-6")
	term._on_command_submitted("login admin admin")
	term._on_command_submitted("passwd Casa#Segura2026!")
	ok = _check("repetir o roteador nao fecha nem da XP", term.is_active()) and ok
	term.close()
	term.open("c_logs", "loja")
	term._on_command_submitted("passwd Qualquer#Coisa2026")
	ok = _check("passwd em outro desafio nao existe", not term._router_logged_in) and ok
	term.close()

	# --- analise de e-mail (tipo "report": indicios com palavras-chave) ---
	term.open("c_email", "casa-2")
	ok = _check("abrir o e-mail ativa a m12", missions.is_active("m12")) and ok
	term._on_command_submitted("cat email.eml")
	ok = _check("e-mail mostra os cabecalhos reais", term.output.get_parsed_text().find("Authentication-Results") != -1 and term.output.get_parsed_text().find("Reply-To") != -1) and ok
	term._on_command_submitted("grep spf email.eml")
	ok = _check("grep acha o resultado do SPF no cabecalho", term.output.get_parsed_text().find("spf=fail") != -1) and ok
	term._on_command_submitted("clear")
	term._on_command_submitted("report")
	var list_out: String = term.output.get_parsed_text()
	ok = _check("'report' sozinho lista o que procurar (3 de 5)", list_out.find("O que procurar") != -1 and list_out.find("precisa de 3 de 5") != -1) and ok
	ok = _check("a lista tem 5 perguntas e nenhuma isca", list_out.find("A autenticação do remetente") != -1 and list_out.find("A pressão no texto") != -1 and list_out.find("Message-ID") == -1) and ok
	ok = _check("a lista nao entrega a resposta (sem 'spf=fail')", list_out.find("spf=fail") == -1) and ok
	ok = _check("listar nao conta como tentativa", session.get_stats("c_email")["attempts"] == 0) and ok
	term._on_command_submitted("clear")
	term._on_command_submitted("report xyzabc")
	ok = _check("palavra desconhecida sugere o 'report' sozinho", term.output.get_parsed_text().find("'report' sozinho") != -1) and ok
	ok = _check("palavra desconhecida nao conta como erro", session.get_stats("c_email")["errors"] == 0) and ok
	term._on_command_submitted("report message-id")
	ok = _check("campo normal (isca) conta como erro", session.get_stats("c_email")["errors"] == 1 and not missions.is_completed("m12")) and ok
	term._on_command_submitted("report SPF")
	term._on_command_submitted("clear")
	term._on_command_submitted("report")
	ok = _check("a lista marca o achado ja reportado com [x]", term.output.get_parsed_text().find("[x] A autenticação do remetente") != -1 and term.output.get_parsed_text().find("[ ] Para onde vai a resposta") != -1) and ok
	term._on_command_submitted("report dkim")
	ok = _check("mesmo indicio duas vezes nao conta duas", term._report_found.size() == 1) and ok
	term._on_command_submitted("report reply-to")
	ok = _check("2 de 3 indicios: ainda nao conclui", term._report_found.size() == 2 and not missions.is_completed("m12") and term.is_active()) and ok
	term._on_command_submitted("report o prazo de 24 horas")
	ok = _check("3 indicios concluem a m12 e fecham o terminal", missions.is_completed("m12") and not term.is_active()) and ok
	var es: Dictionary = session.get_stats("c_email")
	ok = _check("stats e-mail: 1 erro e 4 tentativas (1 erro + 3 acertos)", es["errors"] == 1 and es["attempts"] == 4) and ok
	term.open("c_logs", "loja")
	term._on_command_submitted("report urgente")
	ok = _check("report em desafio de logs continua pedindo numero de linha", term.output.get_parsed_text().find("Uso: report <linha>") != -1) and ok
	term.close()

	# --- phishing em massa (6 mensagens, 3 golpes) ---
	term.open("c_triagem", "casa-3")
	ok = _check("abrir a caixa de entrada ativa a m13", missions.is_active("m13")) and ok
	term._on_command_submitted("cat inbox.txt")
	ok = _check("inbox lista as 6 mensagens", term.output.get_parsed_text().find("Sua senha expira hoje") != -1 and term.output.get_parsed_text().find("Dicas da semana") != -1) and ok
	for n in range(1, 7):
		term._on_command_submitted("cat msg%d.eml" % n)
	ok = _check("as 6 mensagens abrem", term.output.get_parsed_text().find("Reuniao de equipe amanha") != -1 and term.output.get_parsed_text().find("cartoes-presente") != -1) and ok
	term._on_command_submitted("report")
	ok = _check("triagem: a lista pede o numero da mensagem e nao revela quais", term.output.get_parsed_text().find("pelo número da mensagem") != -1 and term.output.get_parsed_text().find("Golpe: mensagem") == -1) and ok
	term._on_command_submitted("report 2")
	term._on_command_submitted("report msg4")
	ok = _check("reportar legitima conta como erro (2 erros)", session.get_stats("c_triagem")["errors"] == 2 and not missions.is_completed("m13")) and ok
	term._on_command_submitted("report 1")
	term._on_command_submitted("report mensagem 3")
	ok = _check("2 de 3 golpes: ainda nao conclui", term._report_found.size() == 2 and not missions.is_completed("m13")) and ok
	term._on_command_submitted("clear")
	term._on_command_submitted("report")
	ok = _check("triagem: a lista mostra os golpes ja achados", term.output.get_parsed_text().find("[x] Golpe: mensagem 1") != -1 and term.output.get_parsed_text().find("[x] Golpe: mensagem 3") != -1) and ok
	term._on_command_submitted("report 1")
	ok = _check("golpe repetido nao conta duas vezes", term._report_found.size() == 2) and ok
	term._on_command_submitted("report 5")
	ok = _check("3 golpes concluem a m13", missions.is_completed("m13") and not term.is_active()) and ok
	var ts: Dictionary = session.get_stats("c_triagem")
	ok = _check("stats triagem: 2 erros e 5 tentativas", ts["errors"] == 2 and ts["attempts"] == 5) and ok

	# --- senha reutilizada (analise de log com grep, 4 de 5 achados) ---
	term.open("c_vazamento", "casa-4")
	ok = _check("abrir o computador ativa a m14", missions.is_active("m14")) and ok
	term._on_command_submitted("ls")
	ok = _check("lista os arquivos do vazamento", term.output.get_parsed_text().find("acessos_email.log") != -1 and term.output.get_parsed_text().find("lembretes.txt") != -1) and ok
	term._on_command_submitted("grep 203.0.113.45 acessos_email.log")
	ok = _check("grep isola as linhas do atacante", term.output.get_parsed_text().find("action=forward_all") != -1 and term.output.get_parsed_text().find("07:50:01") == -1) and ok
	term._on_command_submitted("clear")
	term._on_command_submitted("report")
	var leak_list: String = term.output.get_parsed_text()
	ok = _check("vazamento: a lista tem 5 perguntas (4 de 5)", leak_list.find("precisa de 4 de 5") != -1 and leak_list.find("Quem atacou") != -1 and leak_list.find("A defesa que barraria o login") != -1) and ok
	ok = _check("vazamento: a lista nao mostra o IP nem a isca", leak_list.find("203.0.113.45") == -1 and leak_list.find("198.51.100.23") == -1) and ok
	term._on_command_submitted("report ip do marcos")
	ok = _check("IP habitual (isca) conta como erro", session.get_stats("c_vazamento")["errors"] == 1) and ok
	term._on_command_submitted("report 203.0.113.45")
	term._on_command_submitted("report regra de encaminhamento")
	term._on_command_submitted("report a mesma senha em tudo")
	ok = _check("3 de 4 achados: ainda nao conclui", term._report_found.size() == 3 and not missions.is_completed("m14")) and ok
	term._on_command_submitted("report ativar 2FA")
	ok = _check("4 achados concluem a m14", missions.is_completed("m14") and not term.is_active()) and ok
	var vs: Dictionary = session.get_stats("c_vazamento")
	ok = _check("stats vazamento: 1 erro e 5 tentativas", vs["errors"] == 1 and vs["attempts"] == 5) and ok

	# --- dica no computador da casa (sem desafio): usa as pistas da m01 ---
	term.open("", "casa-1")
	var before: int = phone.get_revealed_clues("m01").size()
	term._on_command_submitted("dica")
	ok = _check("casa: dica revela pista da m01", phone.get_revealed_clues("m01").size() == before + 1) and ok
	term._on_command_submitted("dica")
	term._on_command_submitted("dica")
	ok = _check("casa: 3 pistas e depois so avisa", phone.get_revealed_clues("m01").size() == 3) and ok
	term.close()
	missions.reset()
	phone.reset()
	term.open("", "casa-1")
	term._on_command_submitted("dica")
	ok = _check("casa sem m01 ativa: nao revela nada", phone.get_revealed_clues("m01").size() == 0) and ok
	term.close()

	# --- dica alem da ultima no terminal ---
	term.open("c_xss", "coment")
	term._on_command_submitted("dica")
	term._on_command_submitted("dica")
	term._on_command_submitted("dica")
	ok = _check("c_xss: 3 camadas apos 3 pedidos (a 1a ja era gratis)", session.get_revealed_hints("c_xss").size() == 3) and ok
	# depois da ultima, 'dica' (ou 'dicas') mostra as tres de novo, sempre
	for command in ["dica", "dicas", "dica"]:
		term._on_command_submitted("clear")
		term._on_command_submitted(command)
		var again: String = term.output.get_parsed_text()
		ok = _check("'%s' depois da ultima mostra as 3 dicas de novo" % command, again.find("Dica 1/3") != -1 and again.find("Dica 2/3") != -1 and again.find("Dica 3/3") != -1) and ok
	ok = _check("repetir dicas nao conta como dica nova", session.get_stats("c_xss")["hints"] == 2) and ok
	term.close()

	# --- novo jogo ---
	session.reset()
	ok = _check("reset limpa estatisticas", session.get_stats("c_logs")["attempts"] == 0) and ok

	print("RESULTADO: ", "TUDO OK" if ok else "FALHOU")
	quit(0 if ok else 1)

func _check(label: String, cond: bool) -> bool:
	print(("  ok   " if cond else "  FAIL ") + label)
	return cond
