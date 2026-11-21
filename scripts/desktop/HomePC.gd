extends RefCounted
## HomePC.gd
## O computador do quarto do jogador (Minha Casa): o mesmo desktop estilo Kali
## dos desafios, mas sem missão. Tudo aqui é montado na hora, a partir do
## progresso do jogo, então muda conforme o jogador avança:
##   - E-mail: boas-vindas da Central e um relatório por missão concluída;
##   - Arquivos: diário, lista de tarefas, relatório das missões e mochila;
##   - Navegador: CyberWiki (os conceitos aprendidos) e o placar da Central;
##   - Terminal: os mesmos arquivos, mais 'scan', 'ssh' e 'curl' na rede de casa;
##   - Notas: as mesmas do app Notas do celular.
## ChallengeData.get_challenge("c_casa") devolve o que build() monta.

const ID := "c_casa"


static func build() -> Dictionary:
	var files := {}
	var mailbox: Array = []
	var filesbox: Array = []

	# --- E-mails ---
	files["msg1.eml"] = _mail(1, "Central Cyber City <central@cybercity.example>", "Bem-vindo ao seu computador",
		"Ola, agente!\n\nEste e o seu computador pessoal. Aqui ficam seus e-mails, arquivos\ne anotacoes. Nada aqui e uma missao: explore com calma.\n\nDicas:\n - O Navegador tem a CyberWiki, com tudo o que voce ja aprendeu.\n - O Terminal funciona como nos desafios: experimente 'ls', 'cat',\n   'sha256sum', 'caesar' e 'passcheck'.\n - Para salvar o jogo, durma na cama do quarto.\n\nBom trabalho!\nCentral Cyber City")
	mailbox.append("msg1.eml")
	var number := 2
	for mission_id in _completed_missions():
		var mission: Dictionary = MissionManager.get_mission(mission_id)
		var name := "msg%d.eml" % number
		var item: String = Inventory.item_name(String(Inventory.MISSION_REWARDS.get(mission_id, "")))
		files[name] = _mail(number, "Central Cyber City <relatorios@cybercity.example>", "Relatorio: %s" % _ascii(String(mission["title"])),
			"Missao concluida com sucesso.\n\nConceito: %s\nXP ganho: %d\nItem na mochila: %s\n\nResumo:\n%s" % [
				String(mission["concept"]), int(mission["xp"]), item, String(mission.get("explanation", ""))])
		mailbox.append(name)
		number += 1
	files["msg%d.eml" % number] = _mail(number, "Boletim Seguranca <boletim@seguranca.example>", "Dica da semana: atualize tudo",
		"Atualizacoes corrigem falhas que os atacantes ja conhecem.\nAtive a atualizacao automatica do sistema, do navegador e dos apps.\n\nE lembre: senha longa, unica e com verificacao em duas etapas.")
	mailbox.append("msg%d.eml" % number)

	# --- Arquivos ---
	files["diario.txt"] = _diary()
	files["tarefas.txt"] = _tasks()
	files["relatorio_missoes.txt"] = _report()
	files["mochila.txt"] = _backpack()
	files["dicas_seguranca.txt"] = "DICAS QUE EU NAO POSSO ESQUECER\n\n1. Desconfie de pressa: golpe adora urgencia.\n2. Confira o dominio do remetente e o destino real dos links.\n3. Uma senha diferente para cada servico (use um gerenciador).\n4. Ative a verificacao em duas etapas.\n5. Confira o hash (sha256sum) de arquivos baixados.\n6. Troque a senha de fabrica de roteadores e cameras."
	files["leia_me.txt"] = "Computador pessoal do agente.\n\nArquivos:\n  diario.txt             o que aconteceu ate agora\n  tarefas.txt            o que falta fazer\n  relatorio_missoes.txt  missoes concluidas e notas (rank)\n  mochila.txt            itens que voce tem\n  dicas_seguranca.txt    resumo do que aprendeu\n\nRede de casa: 'scan' mostra as maquinas; 'curl wiki.casa' le a CyberWiki."
	filesbox = ["leia_me.txt", "diario.txt", "tarefas.txt", "relatorio_missoes.txt", "mochila.txt", "dicas_seguranca.txt"]

	return {
		"type": "home",
		"home": true,
		"desktop": true,
		"title": "Computador de casa",
		"apps": ["terminal", "browser", "mail", "files", "notes"],
		"desktop_intro": "Bem-vindo de volta! Este é o seu computador: veja os e-mails da Central, seus arquivos e a CyberWiki no Navegador. Aqui não há missão — explore à vontade.",
		"intro": "Computador pessoal. Digite 'ls' para ver seus arquivos, 'scan' para ver a rede de casa e 'help' para os comandos.",
		"files": files,
		"mailbox": mailbox,
		"filesbox": filesbox,
		"bookmarks": [
			{"title": "CyberWiki — o que você já aprendeu", "url": "http://wiki.casa/"},
			{"title": "Central Cyber City — placar do agente", "url": "http://central.casa/"},
			{"title": "Roteador de casa", "url": "http://roteador.casa/"},
		],
		"hosts": {
			"wiki.casa": {"ip": "192.168.0.10", "ports": "80/tcp  http   (CyberWiki)", "scope": true, "users": {}, "files": {}, "web": _wiki_pages()},
			"central.casa": {"ip": "192.168.0.20", "ports": "443/tcp https  (Central Cyber City)", "scope": true, "users": {}, "files": {}, "web": {"/": _central_page()}},
			"roteador.casa": {"ip": "192.168.0.1", "ports": "80/tcp  http   (painel do roteador)", "scope": true, "users": {}, "files": {}, "web": {"/": _router_page()}},
		},
	}


static func _completed_missions() -> Array:
	var out: Array = []
	for mission_id in MissionManager.missions.keys():
		if MissionManager.is_completed(mission_id):
			out.append(mission_id)
	out.sort()
	return out


static func _mail(number: int, from: String, subject: String, body: String) -> String:
	var date: String = Time.get_date_string_from_system()
	return "From: %s\nTo: agente@cybercity.example\nSubject: %s\nDate: %s\n\n%s" % [from, subject, date, body]


## Os e-mails e arquivos ficam sem acento, como nos outros desafios.
static func _ascii(text: String) -> String:
	var map := {"á": "a", "à": "a", "â": "a", "ã": "a", "é": "e", "ê": "e", "í": "i", "ó": "o", "ô": "o", "õ": "o", "ú": "u", "ç": "c", "—": "-",
		"Á": "A", "É": "E", "Í": "I", "Ó": "O", "Ú": "U", "Ç": "C", "Ã": "A", "Õ": "O"}
	for key in map.keys():
		text = text.replace(key, map[key])
	return text


static func _agent() -> String:
	return Leaderboard.player_name if Leaderboard.player_name != "" else "Agente"


static func _diary() -> String:
	var done: Array = _completed_missions()
	var text := "DIARIO DE %s\n\n" % _ascii(_agent()).to_upper()
	text += "Dia 1: cheguei em Cyber City. A Central me deu um celular e um cracha.\n"
	if done.is_empty():
		text += "Ainda nao resolvi nenhum caso. Amanha eu comeco pela casa com o e-mail estranho.\n"
	else:
		for mission_id in done:
			var mission: Dictionary = MissionManager.get_mission(mission_id)
			text += "- %s: aprendi sobre %s.\n" % [_ascii(String(mission["title"])), _ascii(String(mission["concept"]))]
	text += "\nNivel atual: %d (%d XP no total)." % [GameManager.level, GameManager.total_xp_earned]
	return text


static func _tasks() -> String:
	var text := "TAREFAS\n\n"
	var active: Dictionary = MissionManager.get_active_mission()
	if not active.is_empty():
		text += "[ ] AGORA: %s\n    %s\n\n" % [_ascii(String(active["title"])), _ascii(String(active.get("objective", "")))]
	var pending := 0
	for mission_id in MissionManager.missions.keys():
		if not MissionManager.is_completed(mission_id):
			pending += 1
	text += "[x] Arrumar o quarto\n[x] Configurar este computador\n"
	text += "[ ] Resolver as missoes que faltam (%d)\n" % pending
	text += "[ ] Ativar a verificacao em duas etapas em todas as contas\n[ ] Comprar cafe"
	return text


static func _report() -> String:
	var done: Array = _completed_missions()
	var text := "RELATORIO DE MISSOES  (%d de %d concluidas)\n\n" % [done.size(), MissionManager.missions.size()]
	for mission_id in MissionManager.missions.keys():
		var mission: Dictionary = MissionManager.get_mission(mission_id)
		var mark := "[x]" if MissionManager.is_completed(mission_id) else "[ ]"
		var rank := ""
		var challenge_id: String = ChallengeData.get_challenge_id_for_mission(mission_id)
		if challenge_id != "" and ChallengeSession.get_rank(challenge_id) != "":
			rank = "  rank %s" % ChallengeSession.get_rank(challenge_id)
		text += "%s %s%s\n" % [mark, _ascii(String(mission["title"])), rank]
	return text


static func _backpack() -> String:
	var text := "MOCHILA (%d itens)\n\n" % Inventory.count()
	for item_id in Inventory.get_items():
		var info: Array = Inventory.item_info(item_id)
		text += "* %s\n  %s\n" % [_ascii(String(info[0])), _ascii(String(info[1]))]
	return text


static func _wiki_pages() -> Dictionary:
	var learned: Dictionary = {}
	for mission_id in _completed_missions():
		var mission: Dictionary = MissionManager.get_mission(mission_id)
		learned[String(mission["concept"])] = mission
	var index := "<h1>CyberWiki</h1><p>A enciclopédia do agente. Cada missão concluída libera um verbete.</p>"
	if learned.is_empty():
		index += "<p><i>Nenhum verbete ainda. Conclua uma missão para liberar o primeiro.</i></p>"
	var pages := {}
	var list := "<ul>"
	var n := 1
	for concept in learned.keys():
		var mission: Dictionary = learned[concept]
		var path := "/verbete%d" % n
		list += "<li><a href=\"%s\">%s</a></li>" % [path, concept]
		pages[path] = "<h1>%s</h1><p>%s</p><p><b>Aprendido em:</b> %s</p><p><a href=\"/\">Voltar ao índice</a></p>" % [
			concept, String(mission.get("explanation", "")), String(mission["title"])]
		n += 1
	list += "</ul>"
	pages["/"] = index + (list if not learned.is_empty() else "")
	return pages


static func _central_page() -> String:
	var done: int = _completed_missions().size()
	var total: int = MissionManager.missions.size()
	return "<h1>Central Cyber City</h1><p>Agente: <b>%s</b></p><ul><li>Nível: %d</li><li>XP total: %d</li><li>Missões concluídas: %d de %d</li><li>Itens na mochila: %d</li></ul><p>Continue protegendo a cidade!</p>" % [
		_agent(), GameManager.level, GameManager.total_xp_earned, done, total, Inventory.count()]


static func _router_page() -> String:
	return "<h1>Roteador de casa</h1><p>Status: <b>online</b></p><ul><li>Senha do painel: trocada (não é mais a de fábrica)</li><li>Wi-Fi: WPA3</li><li>Firmware: atualizado</li><li>Dispositivos conectados: 3 (seu PC, seu celular, a TV)</li></ul><p>Tudo certo por aqui.</p>"
