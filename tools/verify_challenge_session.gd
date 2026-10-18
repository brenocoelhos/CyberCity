extends SceneTree
## Verifica o ChallengeSession (tentativas, erros, dicas em camadas, tempo e
## conclusão única) e se todos os desafios do ChallengeData têm 3 camadas de
## dica e uma missão válida. Não usa a interface.
## Rodar: Godot --headless --path . --script res://tools/verify_challenge_session.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.

func _initialize() -> void:
	await process_frame
	var session = root.get_node("ChallengeSession")
	var missions = root.get_node("MissionManager")
	var game = root.get_node("GameManager")
	var ok := true

	session.reset()
	ok = _check("m07 comeca AVAILABLE", missions.get_state("m07") == missions.State.AVAILABLE) and ok
	session.begin("c_firewall")
	ok = _check("begin ativa a missao", missions.is_active("m07")) and ok
	session.record_attempt("c_firewall", false)
	ok = _check("begin revela a 1a camada (gratis)", session.get_revealed_hints("c_firewall").size() == 1 and session.get_stats("c_firewall")["hints"] == 0) and ok
	ok = _check("reveal_next_hint devolve a 2a camada", session.reveal_next_hint("c_firewall") == session.get_hints("c_firewall")[1]) and ok
	session.reveal_next_hint("c_firewall")
	ok = _check("3 camadas reveladas, sem mais", session.get_revealed_hints("c_firewall").size() == 3 and not session.has_more_hints("c_firewall")) and ok
	ok = _check("alem da ultima devolve vazio", session.reveal_next_hint("c_firewall") == "") and ok
	ok = _check("complete devolve true", session.complete("c_firewall")) and ok
	ok = _check("missao concluida", missions.is_completed("m07")) and ok
	ok = _check("XP entregue (250)", game.total_xp_earned == 250) and ok
	ok = _check("segundo complete devolve false", not session.complete("c_firewall")) and ok
	ok = _check("XP nao dobra", game.total_xp_earned == 250) and ok
	var stats: Dictionary = session.get_stats("c_firewall")
	ok = _check("stats tentativas=1 erros=1 dicas=2", stats["attempts"] == 1 and stats["errors"] == 1 and stats["hints"] == 2) and ok
	ok = _check("tempo registrado", stats["time_msec"] >= 0 and stats["started_msec"] >= 0) and ok

	# complete sem begin: ativa a missao sozinho
	session.reset()
	ok = _check("complete sem begin (c_logs)", session.complete("c_logs") and missions.is_completed("m08")) and ok

	# desafio inexistente
	ok = _check("id inexistente nao quebra", not session.complete("nao_existe") and not session.is_completed("nao_existe")) and ok

	# --- rank S/A/B pelo jeito de resolver, com bonus de XP ---
	ok = _check("rank: 0 dicas e 0 erros = S", session.rank_for({"hints": 0, "errors": 0}) == "S") and ok
	ok = _check("rank: 1 dica e 2 erros = A", session.rank_for({"hints": 1, "errors": 2}) == "A") and ok
	ok = _check("rank: 0 dicas e 3 erros = B", session.rank_for({"hints": 0, "errors": 3}) == "B") and ok
	ok = _check("rank: 2 dicas = B", session.rank_for({"hints": 2, "errors": 0}) == "B") and ok

	session.reset()
	var xp_before: int = game.total_xp_earned
	session.begin("c_senhas")
	session.complete("c_senhas")
	ok = _check("S: rank guardado e bonus de 25% (100 -> +25)", session.get_rank("c_senhas") == "S" and session.last_result["bonus_xp"] == 25) and ok
	ok = _check("S: XP total = XP da missao + bonus", game.total_xp_earned - xp_before == 125) and ok
	var hud = root.get_node("HUD")
	ok = _check("HUD mostra o rank e o bonus na tela de conclusao", hud.complete_xp.text.find("RANK S") != -1 and hud.complete_xp.text.find("+25 bônus") != -1) and ok

	xp_before = game.total_xp_earned
	session.begin("c_hash")
	session.record_attempt("c_hash", false)
	session.reveal_next_hint("c_hash")
	session.complete("c_hash")
	ok = _check("A: 1 erro e 1 dica, bonus de 10% (150 -> +15)", session.get_rank("c_hash") == "A" and game.total_xp_earned - xp_before == 165) and ok

	xp_before = game.total_xp_earned
	session.begin("c_cripto")
	for i in range(3):
		session.record_attempt("c_cripto", false)
	session.complete("c_cripto")
	ok = _check("B: 3 erros, sem bonus (150)", session.get_rank("c_cripto") == "B" and session.last_result["bonus_xp"] == 0 and game.total_xp_earned - xp_before == 150) and ok
	ok = _check("HUD com rank B nao mostra bonus", hud.complete_xp.text.find("RANK B") != -1 and hud.complete_xp.text.find("bônus") == -1) and ok
	ok = _check("rank de desafio nao concluido e vazio", session.get_rank("c_phishing") == "") and ok
	ok = _check("desafio ja concluido nao da bonus de novo", not session.complete("c_senhas") and game.total_xp_earned - xp_before == 150) and ok
	session.reset()
	ok = _check("reset limpa os ranks", session.get_rank("c_senhas") == "" and session.last_result.is_empty()) and ok

	# --- a m01 (sem desafio no ChallengeData) tambem tem rank ---
	var phone = root.get_node("PhoneManager")
	session.reset()
	phone.reset()
	missions.reset()
	ok = _check("m01: sem missao em andamento nao conclui", not session.complete_plain_mission("m01")) and ok
	missions.start_mission("m01")
	xp_before = game.total_xp_earned
	ok = _check("m01: concluir pela sessao", session.complete_plain_mission("m01") and missions.is_completed("m01")) and ok
	ok = _check("m01: sem pedir dicas e rank S com bonus de 25%", session.get_rank("m01") == "S" and game.total_xp_earned - xp_before == 125) and ok
	ok = _check("m01: o HUD mostra o rank na tela de conclusao", hud.complete_xp.text.find("RANK S") != -1) and ok
	ok = _check("m01: nao conclui duas vezes", not session.complete_plain_mission("m01")) and ok

	session.reset()
	phone.reset()
	missions.reset()
	missions.start_mission("m01")
	phone.reveal_next_clue("m01")
	phone.reveal_next_clue("m01")
	session.complete_plain_mission("m01")
	ok = _check("m01: 2 dicas pedidas alem da gratis dao rank B", session.get_rank("m01") == "B") and ok
	ok = _check("missao com desafio vai pelo caminho normal", missions.start_mission("m02") == null and session.complete_plain_mission("m02") and session.get_rank("c_senhas") != "") and ok

	# todos os desafios tem 3 camadas e missao valida
	var data = root.get_node("ChallengeData")
	for id in data.CHALLENGES.keys():
		var n: int = session.get_hints(id).size()
		ok = _check("%s tem 3 camadas" % id, n == 3) and ok
		ok = _check("%s: id da missao bate" % id, data.get_challenge_id_for_mission(data.get_challenge(id)["mission"]) == id) and ok
		ok = _check("%s: a missao existe no MissionManager" % id, not missions.get_mission(data.get_challenge(id)["mission"]).is_empty()) and ok
	ok = _check("id inexistente sem dicas", session.get_hints("nada").is_empty()) and ok
	ok = _check("missao sem desafio (m01) -> id vazio", data.get_challenge_id_for_mission("m01") == "") and ok

	print("RESULTADO: ", "TUDO OK" if ok else "FALHOU")
	quit(0 if ok else 1)

func _check(label: String, cond: bool) -> bool:
	print(("  ok   " if cond else "  FAIL ") + label)
	return cond
