extends Node
## PhoneManager.gd — Autoload
## Os "dados" do celular do jogador: mensagens recebidas e pistas de
## cada missão. A tela do celular (GameMenu) e o ícone no HUD só leem
## daqui.
##
## As mensagens chegam sozinhas, reagindo aos sinais que já existem:
## início de capítulo (CampaignManager), missão aceita e missão
## concluída (MissionManager).
##
## As pistas são liberadas uma de cada vez: a primeira chega junto com
## a missão, e as próximas o jogador pede no app "Pistas". A última
## pista de cada missão é a dica do desafio (ChallengeData).

## Emitido quando chega mensagem nova (o HUD mostra a notificação).
signal message_received(message: Dictionary)
## Emitido quando o número de mensagens não lidas muda.
signal unread_changed(count: int)
## Emitido quando uma pista nova é liberada.
signal clue_revealed(mission_id: String)

## Quem manda a mensagem de cada missão.
const CONTACTS := {
	"m01": "Morador",
	"m02": "Morador",
	"m03": "DataSoft Sistemas",
	"m04": "Centro de Tecnologia",
	"m05": "Centro de Tecnologia",
	"m06": "DataSoft Sistemas",
	"m07": "Centro de Tecnologia",
	"m08": "Loja Eletrônica",
	"m09": "Loja Eletrônica",
	"m10": "Loja Eletrônica",
}

const CENTRAL := "Central Cyber City"

## Pistas extras de cada missão, da mais vaga para a mais direta.
const CLUES := {
	"m01": [
		"O e-mail está guardado no computador da casa. No terminal, 'files' lista os arquivos.",
		"Use 'read email_suspeito.eml' para abrir o e-mail.",
		"Compare o endereço do remetente com o de uma empresa real e repare no tom de urgência.",
	],
	"m02": [
		"Senhas curtas podem ser descobertas em segundos por um programa.",
		"Palavras comuns, sequências e dados pessoais estão nas listas de ataque.",
	],
	"m03": [
		"Um hash funciona como uma \"impressão digital\" da senha.",
		"O sistema compara hashes no login — ele nunca precisa ver a senha original.",
	],
	"m04": [
		"Na Cifra de César, todas as letras andam o mesmo número de casas no alfabeto.",
		"A chave é 3. Para decifrar, ande 3 casas para TRÁS.",
	],
	"m05": [
		"Leia o endereço do remetente letra por letra.",
		"Desconfie de mensagens que pedem pressa ou a sua senha.",
	],
	"m06": [
		"No Servidor, o comando 'scan' mostra todos os dispositivos da rede.",
		"Todo dispositivo deveria estar no inventário da empresa. Algum não tem nome conhecido?",
	],
	"m07": [
		"No computador de Firewall, 'firewall status' lista as conexões.",
		"O site da empresa precisa continuar funcionando (HTTP e HTTPS).",
	],
	"m08": [
		"No Registro de Acessos, 'logs' mostra cada linha numerada.",
		"Várias falhas de login seguidas, no mesmo minuto, são suspeitas.",
	],
	"m09": [
		"O sistema cola o que você digita direto dentro de uma consulta SQL.",
		"Aspas simples ( ' ) podem \"fechar\" o texto que o sistema esperava.",
	],
	"m10": [
		"O sistema mostra o comentário na página sem tratar o conteúdo.",
		"E se o comentário tivesse uma tag HTML, como <b> ou <script>?",
	],
}

## Lista de mensagens: {from, text, read}. A mais nova fica no fim.
var messages: Array[Dictionary] = []

## Quantas pistas de cada missão já foram liberadas: id -> número.
var _revealed: Dictionary = {}


func _ready() -> void:
	CampaignManager.chapter_unlocked.connect(_on_chapter_unlocked)
	CampaignManager.game_completed.connect(_on_game_completed)
	MissionManager.mission_started.connect(_on_mission_started)
	MissionManager.mission_completed.connect(_on_mission_completed)


## Apaga mensagens e pistas (usado por "Novo jogo").
func reset() -> void:
	messages.clear()
	_revealed.clear()
	unread_changed.emit(0)


# --- Mensagens ---------------------------------------------------------

func send_message(from: String, text: String) -> void:
	var message := {"from": from, "text": text, "read": false}
	messages.append(message)
	message_received.emit(message)
	unread_changed.emit(unread_count())


func unread_count() -> int:
	var count := 0
	for message in messages:
		if not message["read"]:
			count += 1
	return count


func mark_all_read() -> void:
	for message in messages:
		message["read"] = true
	unread_changed.emit(0)


# --- Pistas ------------------------------------------------------------

## Todas as pistas da missão: as de CLUES + a dica do desafio.
func get_all_clues(mission_id: String) -> PackedStringArray:
	var clues := PackedStringArray(CLUES.get(mission_id, []))
	var challenge: Dictionary = ChallengeData.get_challenge_for_mission(mission_id)
	if challenge.has("hint"):
		clues.append(String(challenge["hint"]))
	return clues


func get_revealed_clues(mission_id: String) -> PackedStringArray:
	var clues := get_all_clues(mission_id)
	var count: int = mini(int(_revealed.get(mission_id, 0)), clues.size())
	return clues.slice(0, count)


func has_more_clues(mission_id: String) -> bool:
	return int(_revealed.get(mission_id, 0)) < get_all_clues(mission_id).size()


## Libera a próxima pista da missão. Devolve false se não há mais.
func reveal_next_clue(mission_id: String) -> bool:
	if not has_more_clues(mission_id):
		return false
	_revealed[mission_id] = int(_revealed.get(mission_id, 0)) + 1
	clue_revealed.emit(mission_id)
	return true


# --- Reações aos eventos do jogo ---------------------------------------

func _on_chapter_unlocked(chapter_id: String) -> void:
	var chapter: Dictionary = CampaignManager.chapters.get(chapter_id, {})
	if chapter.is_empty():
		return
	var lines := PackedStringArray(chapter["intro"])
	send_message(CENTRAL, String(chapter["title"]) + "\n" + "\n".join(lines))


func _on_mission_started(mission_id: String) -> void:
	var mission: Dictionary = MissionManager.get_mission(mission_id)
	if mission.is_empty():
		return
	# A primeira pista chega junto com o pedido de ajuda.
	if int(_revealed.get(mission_id, 0)) == 0:
		reveal_next_clue(mission_id)
	send_message(String(CONTACTS.get(mission_id, CENTRAL)), "%s\n%s\nObjetivo: %s\n(Veja as pistas no app Pistas.)" % [
		String(mission["title"]),
		String(mission["description"]),
		String(mission["objective"]),
	])


func _on_mission_completed(mission_id: String) -> void:
	var mission: Dictionary = MissionManager.get_mission(mission_id)
	if mission.is_empty():
		return
	send_message(String(CONTACTS.get(mission_id, CENTRAL)), "Muito obrigado pela ajuda! Problema resolvido.\nConceito aprendido: %s (+%d XP)" % [
		String(mission["concept"]),
		int(mission["xp"]),
	])


func _on_game_completed() -> void:
	send_message(CENTRAL, "CASO ENCERRADO. A Cyber City está mais segura graças a você. Obrigado por jogar!")
