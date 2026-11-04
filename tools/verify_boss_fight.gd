extends SceneTree
## Verifica a lógica do duelo final (BossFight.gd): barra, tempo dos ataques,
## atordoamento, desmascarar e os dois finais. Não usa a interface.
## Rodar: Godot --headless --path . --script res://tools/verify_boss_fight.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.

var BossFight: GDScript = load("res://scripts/boss/BossFight.gd")


func _initialize() -> void:
	await process_frame
	var ok := true

	# --- tempos decrescentes, primeiro ataque com 45 s ---
	var fight = BossFight.new()
	ok = _check("primeiro ataque tem 45 s", fight.attack_seconds(0) == 45.0) and ok
	var decreasing := true
	for i in range(1, BossFight.ATTACKS.size()):
		if fight.attack_seconds(i) >= fight.attack_seconds(i - 1):
			decreasing = false
	ok = _check("cada ataque e mais curto que o anterior", decreasing) and ok
	ok = _check("depois da lista o tempo fica no minimo", fight.attack_seconds(99) == BossFight.MIN_ATTACK_SECONDS) and ok

	# --- caminho da vitória: conter + desmascarar ---
	fight = BossFight.new()
	var result := {"won": null}
	fight.finished.connect(func(won: bool) -> void: result["won"] = won)
	fight.start()
	ok = _check("comeca em 50/50", fight.bar == 50 and fight.phase == "attack") and ok
	ok = _check("resposta errada nao conta", fight.handle_command("block 1.2.3.4") and fight.phase == "attack") and ok
	ok = _check("resposta errada tira tempo", fight.time_left < 45.0) and ok
	ok = _check("ataque 1 contido", fight.handle_command("block citycred-seguro.net") and fight.phase == "stun" and fight.bar == 60) and ok
	ok = _check("unmask errado nao avanca", fight.handle_command("unmask 9.9.9.9") and fight.phase == "stun" and fight.bar == 60) and ok
	ok = _check("unmask certo da bonus e passa ao ataque 2", fight.handle_command("unmask 10.13.37.5") and fight.phase == "attack" and fight.bar == 70 and fight.attack_index == 1) and ok
	ok = _check("ataque 2 contido", fight.handle_command("block 203.0.113.77") and fight.bar == 80) and ok
	ok = _check("segundo unmask (apelido, aceita acento/caixa)", fight.handle_command("UNMASK N0va_") and fight.bar == 90) and ok
	ok = _check("ataque 3 contido leva a 100 e vence", fight.handle_command("firewall block 23") and fight.phase == "won" and result["won"] == true) and ok
	ok = _check("depois de vencer nao consome mais comandos", not fight.handle_command("ls")) and ok

	# --- todas as respostas dos ataques estao na lista aceita ---
	for attack in BossFight.ATTACKS:
		ok = _check("ataque '%s' tem resposta e arquivo" % attack["title"], not attack["accept"].is_empty() and not attack["files"].is_empty()) and ok

	# --- caminho da derrota: tempo esgotado ---
	fight = BossFight.new()
	result = {"won": null}
	fight.finished.connect(func(won: bool) -> void: result["won"] = won)
	fight.start()
	var guard := 0
	while fight.is_running() and guard < 2000:
		fight.tick(1.0)
		guard += 1
	ok = _check("sem fazer nada, o hacker vence", result["won"] == false and fight.phase == "lost" and fight.bar == 0) and ok
	ok = _check("derrota em poucos minutos (<= 5 ataques de 50%)", guard < 400) and ok

	# --- stun sem ação: o hacker so provoca e o proximo ataque comeca ---
	fight = BossFight.new()
	var lines: Array = []
	fight.said.connect(func(kind: String, text: String) -> void: lines.append(kind + ":" + text))
	fight.start()
	fight.handle_command("block citycred-seguro.net")
	for i in 31:
		fight.tick(1.0)
	ok = _check("stun sem acao passa ao proximo ataque", fight.phase == "attack" and fight.attack_index == 1) and ok
	ok = _check("barra ficou em 60 (sem bonus)", fight.bar == 60) and ok
	ok = _check("hacker provocou na fase de stun", lines.any(func(l: String) -> bool: return l.begins_with("boss:") and (l.contains("decepção") or l.contains("iniciante")))) and ok

	# --- desistir ---
	fight = BossFight.new()
	result = {"won": null}
	fight.finished.connect(func(won: bool) -> void: result["won"] = won)
	fight.start()
	fight.handle_command("desistir")
	ok = _check("'desistir' encerra com derrota", result["won"] == false) and ok

	# --- ls/cat ---
	fight = BossFight.new()
	lines = []
	fight.said.connect(func(kind: String, text: String) -> void: lines.append(kind + ":" + text))
	fight.start()
	fight.handle_command("ls")
	ok = _check("ls lista o arquivo do ataque", lines.has("info:fila_envio.log")) and ok
	fight.handle_command("cat fila_envio.log")
	ok = _check("cat mostra o conteudo", lines.any(func(l: String) -> bool: return l.contains("citycred-seguro.net"))) and ok

	print("")
	print("OK: todos os testes do duelo passaram." if ok else "FALHOU: veja as linhas FALHA acima.")
	quit(0 if ok else 1)


func _check(label: String, passed: bool) -> bool:
	print(("  ok     " if passed else "  FALHA  ") + label)
	return passed
