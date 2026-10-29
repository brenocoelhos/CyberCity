extends Node
## CampaignManager.gd — Autoload
## Camada narrativa fina por cima do que já existe: agrupa as 17 missões em
## 7 capítulos + um capítulo final, mostrando uma pequena introdução quando o
## capítulo começa e uma mensagem de fechamento quando termina. Não cria
## nenhum sistema novo: só encadeia diálogos (DialogueManager) reagindo a
## missões concluídas (MissionManager).
##
## A ORDEM dos capítulos segue a curva de dificuldade/realismo do jogo: os
## quizzes de conceitos primeiro, depois fraude e rede, depois exploração e
## acessos, e por fim o teste de invasão completo (m15). Cada missão continua
## no lugar do mapa onde acontece, então nenhuma missão mudou de local.

signal chapter_unlocked(chapter_id: String)
signal game_completed

var chapters: Dictionary = {
	"ch1": {
		"title": "CAPÍTULO 1 — PRIMEIRO TRABALHO",
		"missions": ["m01"],
		"intro": PackedStringArray([
			"Mensagem recebida: \"Precisamos de ajuda para verificar um problema de segurança.\"",
			"Você aceita o primeiro trabalho como hacker ético da Cyber City.",
			"Ande pela cidade e converse com os moradores — alguém precisa de ajuda.",
		]),
		"outro": PackedStringArray([
			"Primeiro caso resolvido. A cidade já está de olho em você.",
		]),
	},
	"ch2": {
		"title": "CAPÍTULO 2 — A EMPRESA",
		"missions": ["m02", "m03"],
		"intro": PackedStringArray([
			"Uma empresa da cidade pediu ajuda com segurança básica de acesso.",
			"Vá até uma empresa e use os computadores das estações de trabalho.",
		]),
		"outro": PackedStringArray([
			"Senhas e hash não têm mais segredo pra você.",
		]),
	},
	"ch3": {
		"title": "CAPÍTULO 3 — CRIPTOGRAFIA E FRAUDE",
		"missions": ["m04", "m05", "m12", "m13"],
		"intro": PackedStringArray([
			"O Centro de Tecnologia guarda uma mensagem cifrada e um caso de phishing por resolver.",
			"Explore as estações do Centro de Tecnologia.",
			"Uma vizinha da Casa 2 também recebeu um e-mail que parece golpe.",
			"E o morador da Casa 3 recebeu seis mensagens de uma vez e não sabe em quais confiar.",
		]),
		"outro": PackedStringArray([
			"Cifra decifrada, fraudes identificadas. Agora é hora de olhar a rede.",
		]),
	},
	"ch4": {
		"title": "CAPÍTULO 4 — REDE E PERÍMETRO",
		"missions": ["m06", "m07", "m11", "m16"],
		"intro": PackedStringArray([
			"A mesma empresa suspeita de um dispositivo estranho na rede.",
			"Investigue o Servidor da empresa e configure o Firewall do Centro de Tecnologia.",
			"Uma moradora da Casa 6 também reclama que o wi-fi de casa está estranho.",
			"E a DataSoft quer saber o que um visitante qualquer descobre sobre o site dela.",
		]),
		"outro": PackedStringArray([
			"Rede mapeada e perímetro protegido. A cidade está mais segura.",
		]),
	},
	"ch5": {
		"title": "CAPÍTULO 5 — A APLICAÇÃO",
		"missions": ["m08", "m09", "m10"],
		"intro": PackedStringArray([
			"A Loja Eletrônica tem um sistema interno cheio de falhas.",
			"Analise os logs e teste as vulnerabilidades dos computadores da loja.",
		]),
		"outro": PackedStringArray([
			"Todas as falhas da aplicação foram documentadas e explicadas.",
		]),
	},
	"ch6": {
		"title": "CAPÍTULO 6 — ACESSOS E SEGREDOS",
		"missions": ["m14", "m17"],
		"intro": PackedStringArray([
			"Um morador da Casa 4 está preocupado: uma loja vazou senhas e ele usa a mesma em tudo.",
			"E a DataSoft emprestou um acesso comum a um estagiário e quer saber até onde ele chegaria.",
		]),
		"outro": PackedStringArray([
			"Senhas repetidas e segredos esquecidos: pequenos descuidos abrem portas grandes.",
		]),
	},
	"ch7": {
		"title": "CAPÍTULO 7 — O TESTE DE INVASÃO",
		"missions": ["m15"],
		"intro": PackedStringArray([
			"A Orion Logística pede um teste de invasão completo, feito no Terminal Público da praça.",
			"Use tudo o que aprendeu: reconhecimento, credenciais achadas, movimento entre máquinas e, no fim, um relatório.",
		]),
		"outro": PackedStringArray([
			"Teste concluído e documentado. A Orion agora sabe onde estava vulnerável.",
		]),
	},
}

var is_game_completed: bool = false

var _intro_played: bool = false
var _chapter_started: Dictionary = {}
var _chapter_finished: Dictionary = {}
var _queued_action: Callable = Callable()


func _ready() -> void:
	MissionManager.mission_completed.connect(_on_mission_completed)


## Volta a campanha ao início (usado por "Novo jogo").
func reset() -> void:
	is_game_completed = false
	_intro_played = false
	_chapter_started.clear()
	_chapter_finished.clear()
	_queued_action = Callable()
	if DialogueManager.closed.is_connected(_run_queued_action):
		DialogueManager.closed.disconnect(_run_queued_action)


## Dados para o save: em que ponto da campanha o jogador está.
func get_save_data() -> Dictionary:
	return {
		"is_game_completed": is_game_completed,
		"intro_played": _intro_played,
		"chapter_started": _chapter_started.duplicate(),
		"chapter_finished": _chapter_finished.duplicate(),
	}


func load_save_data(data: Dictionary) -> void:
	reset()
	is_game_completed = bool(data.get("is_game_completed", false))
	_intro_played = bool(data.get("intro_played", false))
	var started: Dictionary = data.get("chapter_started", {})
	for chapter_id in started.keys():
		_chapter_started[String(chapter_id)] = bool(started[chapter_id])
	var finished: Dictionary = data.get("chapter_finished", {})
	for chapter_id in finished.keys():
		_chapter_finished[String(chapter_id)] = bool(finished[chapter_id])


## true se a missão faz parte de um capítulo já começado e ainda não
## terminado. Usado pelos marcadores "!" dos prédios na cidade.
func is_mission_in_current_chapter(mission_id: String) -> bool:
	for chapter_id in chapters.keys():
		if _chapter_started.get(chapter_id, false) and not _chapter_finished.get(chapter_id, false):
			if Array(chapters[chapter_id]["missions"]).has(mission_id):
				return true
	return false


## Chamado pela cidade (City.gd) toda vez que a cena carrega. Só faz
## alguma coisa da primeira vez — é seguro chamar sempre.
func play_opening() -> void:
	if _intro_played:
		return
	_intro_played = true
	_start_chapter("ch1")


func _on_mission_completed(mission_id: String) -> void:
	for chapter_id in chapters.keys():
		var chapter: Dictionary = chapters[chapter_id]
		var missions: Array = chapter["missions"]
		if not missions.has(mission_id):
			continue
		if _all_missions_done(missions):
			_finish_chapter(chapter_id)
		return


func _all_missions_done(mission_ids: Array) -> bool:
	for id in mission_ids:
		if not MissionManager.is_completed(String(id)):
			return false
	return true


func _start_chapter(chapter_id: String) -> void:
	if _chapter_started.get(chapter_id, false):
		return
	_chapter_started[chapter_id] = true

	var chapter: Dictionary = chapters[chapter_id]
	DialogueManager.start_dialogue(String(chapter["title"]), chapter["intro"])
	chapter_unlocked.emit(chapter_id)


func _finish_chapter(chapter_id: String) -> void:
	if _chapter_finished.get(chapter_id, false):
		return
	_chapter_finished[chapter_id] = true

	var chapter: Dictionary = chapters[chapter_id]
	DialogueManager.start_dialogue(String(chapter["title"]), chapter["outro"])

	var next_id: String = _next_chapter_id(chapter_id)
	if next_id != "":
		_queued_action = func(): _start_chapter(next_id)
	else:
		_queued_action = func(): _finish_game()

	# Espera a caixa de diálogo do "outro" fechar antes de mostrar a
	# próxima (senão uma sobrescreveria a outra na mesma tela).
	DialogueManager.closed.connect(_run_queued_action, CONNECT_ONE_SHOT)


func _run_queued_action() -> void:
	if _queued_action.is_valid():
		_queued_action.call()
	_queued_action = Callable()


func _next_chapter_id(chapter_id: String) -> String:
	var ids: Array = chapters.keys()
	var index: int = ids.find(chapter_id)
	if index == -1 or index + 1 >= ids.size():
		return ""
	return String(ids[index + 1])


func _finish_game() -> void:
	is_game_completed = true
	DialogueManager.start_dialogue("CAPÍTULO FINAL — O INCIDENTE", PackedStringArray([
		"Um incidente atinge vários sistemas da cidade ao mesmo tempo.",
		"Usando tudo que você aprendeu — senhas, hash, criptografia, phishing, redes, firewall, logs, SQL Injection e XSS — a equipe consegue conter o incidente.",
		"CASO ENCERRADO.",
		"Nível final: %d   |   XP total conquistado: %d" % [GameManager.level, GameManager.total_xp_earned],
		"Obrigado por jogar Cyber City!",
	]))
	game_completed.emit()
