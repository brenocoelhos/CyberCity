extends Node
## Leaderboard.gd — Autoload
## Placar estilo arcade: o jogador digita um nome no começo da partida e, ao
## zerar o jogo, o nome aparece ao lado do tempo que levou. Quanto menor o
## tempo, melhor a posição. A lista fica gravada em disco.
##
## Este é só o SISTEMA. Nada o liga ainda ao menu nem ao fim do jogo, porque o
## final ainda não está definido. Para ligar:
##   - "Novo jogo" (MainMenu): Leaderboard.start_run(nome_digitado)
##   - fim do jogo (por ex. CampaignManager.game_completed):
##       var result := Leaderboard.finish_run()
##     e mostrar result["entry"] e result["position"] na tela do placar
##   - voltar ao menu sem terminar: Leaderboard.cancel_run()
##   - menus/pausa: Leaderboard.set_paused(true/false), para o tempo parar
##   - tela do placar: Leaderboard.get_scores() e Leaderboard.format_time()
##
## O tempo conta só enquanto a partida está ativa e não pausada (soma o tempo
## de cada quadro, não o relógio da parede).

## Emitido quando uma partida termina e entra (ou não) no placar.
signal run_finished(entry: Dictionary, position: int)

const MAX_ENTRIES := 10
const MAX_NAME_LENGTH := 10
const DEFAULT_NAME := "JOGADOR"

## Arquivo do placar. É uma variável para os testes usarem outro arquivo.
var scores_path: String = "user://leaderboard.cfg"

var player_name: String = ""

var _running: bool = false
var _paused: bool = false
var _elapsed_msec: float = 0.0
## Lista ordenada do menor para o maior tempo: {name, time_msec, date}.
var _scores: Array = []


func _ready() -> void:
	load_scores()


func _process(delta: float) -> void:
	if _running and not _paused:
		_elapsed_msec += delta * 1000.0


## Começa a contar uma partida para este jogador. O nome é aparado e cortado
## em MAX_NAME_LENGTH letras; vazio vira "JOGADOR".
func start_run(name_typed: String) -> void:
	player_name = clean_name(name_typed)
	_elapsed_msec = 0.0
	_running = true
	_paused = false


func is_running() -> bool:
	return _running


func set_paused(value: bool) -> void:
	_paused = value


## Tempo da partida em andamento, em milissegundos.
func elapsed_msec() -> int:
	return int(_elapsed_msec)


## Abandona a partida (voltar ao menu, novo jogo) sem gravar nada.
func cancel_run() -> void:
	_running = false
	_paused = false
	_elapsed_msec = 0.0


## Termina a partida e a coloca no placar. Devolve {"entry": {...},
## "position": posição de 1 a MAX_ENTRIES, ou 0 se não entrou no placar,
## "is_record": true se é o melhor tempo}. Vazio se não havia partida.
func finish_run() -> Dictionary:
	if not _running:
		return {}
	_running = false

	var entry := {
		"name": player_name if player_name != "" else DEFAULT_NAME,
		"time_msec": int(_elapsed_msec),
		"date": Time.get_date_string_from_system(),
	}

	# Em caso de empate, quem chegou primeiro fica na frente.
	var index: int = _scores.size()
	for i in range(_scores.size()):
		if int(entry["time_msec"]) < int(_scores[i]["time_msec"]):
			index = i
			break
	_scores.insert(index, entry)
	if _scores.size() > MAX_ENTRIES:
		_scores.resize(MAX_ENTRIES)

	var position: int = index + 1 if index < MAX_ENTRIES else 0
	save_scores()
	var result := {"entry": entry, "position": position, "is_record": position == 1}
	run_finished.emit(entry, position)
	return result


## Cópia do placar, do melhor para o pior tempo.
func get_scores() -> Array:
	return _scores.duplicate(true)


func clear_scores() -> void:
	_scores.clear()
	save_scores()


func load_scores() -> void:
	_scores = []
	var config := ConfigFile.new()
	if config.load(scores_path) != OK:
		return
	for entry in Array(config.get_value("board", "entries", [])):
		if entry is Dictionary and entry.has("name") and entry.has("time_msec"):
			_scores.append({"name": String(entry["name"]), "time_msec": int(entry["time_msec"]), "date": String(entry.get("date", ""))})
	_scores.sort_custom(func(a, b): return int(a["time_msec"]) < int(b["time_msec"]))
	if _scores.size() > MAX_ENTRIES:
		_scores.resize(MAX_ENTRIES)


func save_scores() -> void:
	var config := ConfigFile.new()
	config.set_value("board", "entries", _scores)
	config.save(scores_path)


static func clean_name(name_typed: String) -> String:
	var cleaned: String = name_typed.strip_edges().left(MAX_NAME_LENGTH).strip_edges()
	return cleaned if cleaned != "" else DEFAULT_NAME


## "MM:SS.cc" (ex.: 12:34.56) ou "H:MM:SS.cc" se passar de uma hora.
static func format_time(msec: int) -> String:
	var centis: int = (msec / 10) % 100
	var total_seconds: int = msec / 1000
	var seconds: int = total_seconds % 60
	var minutes: int = (total_seconds / 60) % 60
	var hours: int = total_seconds / 3600
	if hours > 0:
		return "%d:%02d:%02d.%02d" % [hours, minutes, seconds, centis]
	return "%02d:%02d.%02d" % [minutes, seconds, centis]
