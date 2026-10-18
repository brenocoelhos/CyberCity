extends Area2D
## Door.gd
## Porta de entrada de um prédio na cidade. Quando o jogador está por perto
## e pressiona "interact" (E), leva para a cena de interior configurada.
## Se "locked" for true, mostra que o local está bloqueado (reservado para
## futuras missões) e não permite entrar.

@export var interior_scene_path: String = ""
@export var building_title: String = ""
@export var locked: bool = false

## Se preenchido, esta porta destrava sozinha assim que a missão
## indicada for concluída (demonstra o desbloqueio de áreas).
@export var unlock_after_mission: String = ""

## O que o interior deve ter (preenchido pelo Building). Ver SceneTransition.
var interior_config: Dictionary = {}

@onready var prompt: Label = $PromptLabel

var _player_in_range: bool = false


func _ready() -> void:
	prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_lock_state()


func _update_lock_state() -> void:
	if unlock_after_mission != "" and MissionManager.is_completed(unlock_after_mission):
		locked = false


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_update_lock_state()
	_player_in_range = true
	prompt.text = "🔒 Bloqueado" if locked else "[E] Entrar"
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
	if not _player_in_range or locked:
		return
	if event.is_action_pressed("interact"):
		SoundManager.play("interact")
		SceneTransition.enter_building(interior_scene_path, building_title, global_position + Vector2(0, 40), interior_config)
