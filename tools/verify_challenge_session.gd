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
