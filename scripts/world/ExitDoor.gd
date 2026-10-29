extends Area2D
## ExitDoor.gd
## Porta de saída dentro de uma casa/empresa. Leva o jogador de volta
## para a cidade, na posição salva por SceneTransition.

const UiStyle := preload("res://scripts/ui/UiStyle.gd")

@onready var prompt: Label = $PromptLabel

var _player_in_range: bool = false


func _ready() -> void:
	UiStyle.prompt(prompt, "[E] Sair")
	prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = true
	prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = false
	prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if DialogueManager.is_active() or TerminalManager.is_active() \
		or ChallengeManager.is_active() \
		or GameMenu.is_active() or HUD.is_popup_active():
		return
	if _player_in_range and event.is_action_pressed("interact"):
		SoundManager.play("interact")
		SceneTransition.exit_to_city()
