extends Node
## CampaignManager.gd — Autoload
## Camada narrativa fina por cima do que já existe: agrupa as 10
## missões em 5 capítulos + um capítulo final, mostrando uma pequena
## introdução quando o capítulo começa e uma mensagem de fechamento
## quando termina. Não cria nenhum sistema novo — só encadeia diálogos
## (DialogueManager) reagindo a missões concluídas (MissionManager).
##
## O mapeamento dos capítulos segue os locais onde cada missão já
## acontece no jogo (casa → empresa → rede/firewall → centro de
## tecnologia → loja), então nenhuma missão precisou mudar de lugar.

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
		"title": "CAPÍTULO 3 — REDE E PERÍMETRO",
		"missions": ["m06", "m07"],
		"intro": PackedStringArray([
			"A mesma empresa suspeita de um dispositivo estranho na rede.",
			"Investigue o Servidor da empresa e configure o Firewall do Centro de Tecnologia.",
		]),
		"outro": PackedStringArray([
			"Rede mapeada e perímetro protegido. A cidade está mais segura.",
		]),
	},
	"ch4": {
		"title": "CAPÍTULO 4 — CRIPTOGRAFIA E FRAUDE",
		"missions": ["m04", "m05"],
		"intro": PackedStringArray([
			"O Centro de Tecnologia guarda uma mensagem cifrada e um caso de phishing por resolver.",
			"Explore as estações do Centro de Tecnologia.",
		]),
		"outro": PackedStringArray([
			"Cifra decifrada, fraude identificada. Só falta a loja.",
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
