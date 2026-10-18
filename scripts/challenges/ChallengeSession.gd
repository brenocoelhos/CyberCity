extends Node
## ChallengeSession.gd — Autoload
## Acompanha o que o jogador faz em cada desafio (tentativas, erros, dicas
## e tempo) e é o ÚNICO lugar que conclui um desafio. Antes, cada tipo de
## desafio (quiz, rede, firewall, logs, SQLi, XSS) repetia por conta
## própria "mostrar sucesso, fechar a tela e concluir a missão".
##
## Quem usa:
##   - TerminalManager e ChallengeManager chamam begin(), record_attempt(),
##     reveal_next_hint() e complete(). O celular (PhoneManager) lê as dicas
##     reveladas daqui, então terminal, quiz e celular mostram o mesmo.
##   - Os sistemas futuros (cronômetro, dificuldade, hacker inimigo) leem
##     get_stats() ou escutam challenge_completed.
##
## Esta classe não sabe nada sobre como cada desafio é resolvido: isso
## continua em ChallengeData (os dados) e nos comandos do terminal.

## Emitido quando o jogador abre um desafio (a missão ligada já foi aceita).
signal challenge_started(challenge_id: String)
## Emitido a cada resposta registrada (correta ou não).
signal attempt_recorded(challenge_id: String, correct: bool)
## Emitido quando uma camada de dica é revelada ("layer" começa em 1).
signal hint_revealed(challenge_id: String, layer: int, total: int)
## Emitido uma única vez, quando o desafio é concluído.
signal challenge_completed(challenge_id: String, stats: Dictionary)

## Rank de cada desafio, pelo jeito de resolver (não pelo tempo): S = sem
## dicas pedidas e sem erros; A = até 1 dica e até 2 erros; B = o resto.
## Dá um bônus de XP sobre o XP da missão. Errar e pedir dica continuam
## permitidos: o rank só premia quem resolveu limpo.
const RANK_XP_BONUS := {"S": 0.25, "A": 0.10, "B": 0.0}
const RANK_A_MAX_HINTS := 1
const RANK_A_MAX_ERRORS := 2

## Resultado da última conclusão ({challenge_id, mission_id, rank, bonus_xp}).
## O HUD lê isto na tela de "desafio concluído".
var last_result: Dictionary = {}

## Rank conquistado em cada desafio concluído: id -> "S"/"A"/"B".
var _ranks: Dictionary = {}

## id do desafio -> {attempts, errors, hints, revealed, started_msec, time_msec}
##   revealed - quantas camadas de dica já foram reveladas (a 1ª é grátis)
##   hints    - dicas "pedidas" = revealed menos a camada grátis (nunca < 0)
##   time_msec só é preenchido ao concluir: tempo desde a primeira abertura.
var _stats: Dictionary = {}


## Apaga o histórico (usado por "Novo jogo").
func reset() -> void:
	_stats.clear()
	_ranks.clear()
	last_result = {}


## Chamado quando o jogador abre um desafio. Aceita a missão ligada a ele
## se ainda estiver disponível e começa a contar o tempo (só na 1ª vez).
func begin(challenge_id: String) -> void:
	var challenge: Dictionary = ChallengeData.get_challenge(challenge_id)
	if challenge.is_empty():
		return

	var stats: Dictionary = _get_stats(challenge_id)
	if int(stats["started_msec"]) < 0:
		stats["started_msec"] = Time.get_ticks_msec()

	var mission_id: String = String(challenge.get("mission", ""))
	if mission_id != "" and MissionManager.get_state(mission_id) == MissionManager.State.AVAILABLE:
		MissionManager.start_mission(mission_id)

	# A 1ª camada de dica chega de graça junto com a missão.
	if int(stats["revealed"]) == 0:
		reveal_next_hint(challenge_id)

	challenge_started.emit(challenge_id)


## Registra uma resposta. Use "correct = false" só para erros de verdade
## (resposta errada), não para exploração (ex.: conectar num dispositivo
## normal da rede, ou postar um comentário comum).
func record_attempt(challenge_id: String, correct: bool) -> void:
	if ChallengeData.get_challenge(challenge_id).is_empty():
		return
	var stats: Dictionary = _get_stats(challenge_id)
	stats["attempts"] = int(stats["attempts"]) + 1
	if not correct:
		stats["errors"] = int(stats["errors"]) + 1
	attempt_recorded.emit(challenge_id, correct)


## --- Dicas em camadas -------------------------------------------------

## Todas as camadas do desafio, da mais vaga para a mais direta. Aceita o
## formato antigo (um único campo "hint") como uma lista de uma camada.
func get_hints(challenge_id: String) -> PackedStringArray:
	var challenge: Dictionary = ChallengeData.get_challenge(challenge_id)
	if challenge.has("hints"):
		return PackedStringArray(challenge["hints"])
	if challenge.has("hint"):
		return PackedStringArray([String(challenge["hint"])])
	return PackedStringArray()


## Só as camadas que o jogador já viu.
func get_revealed_hints(challenge_id: String) -> PackedStringArray:
	var hints: PackedStringArray = get_hints(challenge_id)
	var count: int = mini(int(_get_stats(challenge_id)["revealed"]), hints.size())
	return hints.slice(0, count)


func has_more_hints(challenge_id: String) -> bool:
	return int(_get_stats(challenge_id)["revealed"]) < get_hints(challenge_id).size()


## Revela a próxima camada e devolve o texto dela ("" se não há mais).
func reveal_next_hint(challenge_id: String) -> String:
	if not has_more_hints(challenge_id):
		return ""
	var hints: PackedStringArray = get_hints(challenge_id)
	var stats: Dictionary = _get_stats(challenge_id)
	stats["revealed"] = int(stats["revealed"]) + 1
	stats["hints"] = maxi(0, int(stats["revealed"]) - 1)
	hint_revealed.emit(challenge_id, int(stats["revealed"]), hints.size())
	return hints[int(stats["revealed"]) - 1]


## Conclui o desafio: entrega XP, conceito e explicação pela missão ligada.
## Devolve false se o desafio não existe ou já tinha sido concluído antes
## (nesse caso nada é entregue de novo).
func complete(challenge_id: String) -> bool:
	var challenge: Dictionary = ChallengeData.get_challenge(challenge_id)
	if challenge.is_empty() or is_completed(challenge_id):
		return false

	# Garante que a missão está ativa (e o tempo começou), mesmo que o
	# desafio tenha sido concluído sem passar por begin().
	begin(challenge_id)

	var stats: Dictionary = _get_stats(challenge_id)
	stats["time_msec"] = Time.get_ticks_msec() - int(stats["started_msec"])

	# O rank é calculado antes de concluir a missão, porque o HUD o lê
	# (last_result) quando mostra a tela de "desafio concluído".
	var mission_id: String = String(challenge.get("mission", ""))
	var rank: String = rank_for(stats)
	var mission_xp: int = int(MissionManager.get_mission(mission_id).get("xp", 0))
	var bonus_xp: int = int(round(float(mission_xp) * float(RANK_XP_BONUS[rank])))
	stats["rank"] = rank
	stats["bonus_xp"] = bonus_xp
	_ranks[challenge_id] = rank
	last_result = {"challenge_id": challenge_id, "mission_id": mission_id, "rank": rank, "bonus_xp": bonus_xp}

	# A missão é a fonte da verdade sobre "concluído": ela dispara XP, a
	# tela de explicação no HUD e o avanço dos capítulos.
	MissionManager.complete_mission(mission_id)
	if bonus_xp > 0:
		GameManager.add_xp(bonus_xp)
	challenge_completed.emit(challenge_id, stats.duplicate())
	return true


## Rank S/A/B de um conjunto de números ({errors, hints}).
func rank_for(stats: Dictionary) -> String:
	var hints: int = int(stats.get("hints", 0))
	var errors: int = int(stats.get("errors", 0))
	if hints == 0 and errors == 0:
		return "S"
	if hints <= RANK_A_MAX_HINTS and errors <= RANK_A_MAX_ERRORS:
		return "A"
	return "B"


## Rank conquistado num desafio concluído ("" se ainda não foi concluído).
func get_rank(challenge_id: String) -> String:
	return String(_ranks.get(challenge_id, ""))


func is_completed(challenge_id: String) -> bool:
	var challenge: Dictionary = ChallengeData.get_challenge(challenge_id)
	if challenge.is_empty():
		return false
	return MissionManager.is_completed(String(challenge.get("mission", "")))


## Cópia dos números de um desafio (vazios se o jogador nunca o abriu).
func get_stats(challenge_id: String) -> Dictionary:
	return _get_stats(challenge_id).duplicate()


func _get_stats(challenge_id: String) -> Dictionary:
	if not _stats.has(challenge_id):
		_stats[challenge_id] = {
			"attempts": 0,
			"errors": 0,
			"hints": 0,
			"revealed": 0,
			"started_msec": -1,
			"time_msec": 0,
		}
	return _stats[challenge_id]
