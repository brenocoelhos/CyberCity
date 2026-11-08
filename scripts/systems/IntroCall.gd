extends Node
## IntroCall.gd
## A abertura de um jogo novo: o personagem aparece no meio da cidade, o
## celular toca, e a Central pergunta o nome do agente. O nome digitado é o
## que aparece no placar (Leaderboard), e o cronômetro da partida começa aqui.
## Depois, a abertura normal da campanha continua (CampaignManager.play_opening).
##
## TODO(História): as falas abaixo são PROVISÓRIAS; trocar pelo roteiro.

signal finished

const NamePrompt := preload("res://scripts/ui/NamePrompt.gd")

const CALL_LINES := [
	"(O celular toca. É a Central Cyber City.)",
	"Alô? Aqui é a Central. Ainda bem que você chegou à cidade.",
	"Antes de abrir o seu caso, preciso confirmar uma coisa: qual é o seu nome, agente?",
]
const WELCOME_LINES := [
	"Entendido, agente %s. Seu nome entra no registro oficial.",
	"Fique de olho no celular: as missões chegam por lá. Boa sorte.",
]

var _prompt: CanvasLayer


## Toca a abertura e, no fim, inicia a campanha. Se a partida já está em
## andamento (jogo carregado), só inicia a campanha.
func play() -> void:
	if Leaderboard.is_running():
		_finish()
		return
	HUD.set_overlay_active(true)
	await get_tree().create_timer(0.9).timeout
	for i in range(3):
		SoundManager.play("blip")
		await get_tree().create_timer(0.45).timeout
	HUD.set_overlay_active(false)
	DialogueManager.start_dialogue("CENTRAL", PackedStringArray(CALL_LINES))
	await DialogueManager.closed

	_prompt = NamePrompt.new()
	get_tree().root.add_child(_prompt)
	var chosen: String = await _prompt.confirmed
	Leaderboard.start_run(chosen)

	var welcome := PackedStringArray()
	for line in WELCOME_LINES:
		welcome.append(String(line) % Leaderboard.player_name if String(line).contains("%s") else String(line))
	DialogueManager.start_dialogue("CENTRAL", welcome)
	await DialogueManager.closed
	_finish()


func _finish() -> void:
	finished.emit()
	CampaignManager.play_opening()
	queue_free()
