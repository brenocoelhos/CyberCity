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
	term.close()
	term.open("c_logs", "loja")
	term._on_command_submitted("files")
	ok = _check("outro computador nao lista manual.txt", term.output.get_parsed_text().find("manual.txt") == -1) and ok
	term.close()

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
	term.close()

	# --- novo jogo ---
	session.reset()
	ok = _check("reset limpa estatisticas", session.get_stats("c_logs")["attempts"] == 0) and ok

	print("RESULTADO: ", "TUDO OK" if ok else "FALHOU")
	quit(0 if ok else 1)

func _check(label: String, cond: bool) -> bool:
	print(("  ok   " if cond else "  FAIL ") + label)
	return cond
