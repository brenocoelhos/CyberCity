extends Area2D
## Interactable.gd
## Base genérica para qualquer objeto com o qual o jogador possa
## interagir pressionando "E" (NPCs, computadores, e no futuro outros
## objetos). Cuida de: detectar o jogador por perto, mostrar/esconder
## o prompt "[E] ..." e chamar _on_interact() quando a tecla é
## pressionada. Sub-classes (NPC.gd, Computer.gd, ...) só precisam
## sobrescrever _on_interact().
##
## Requer um Label filho chamado "PromptLabel" na cena.

const UiStyle := preload("res://scripts/ui/UiStyle.gd")

@export var prompt_text: String = "[E] Interagir"

@onready var prompt_label: Label = $PromptLabel

var player_in_range: bool = false


func _ready() -> void:
	if prompt_label:
		# Balão no estilo do HUD: tecla [E] numa caixinha + o texto.
		UiStyle.prompt(prompt_label, prompt_text)
		prompt_label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	player_in_range = true
	if prompt_label:
		prompt_label.visible = true


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	player_in_range = false
	if prompt_label:
		prompt_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	# Enquanto uma caixa de diálogo ou o terminal estão abertos, ignora
	# novas interações (evita reabrir o mesmo NPC/computador com a
	# mesma tecla que fecha o diálogo/terminal).
	if DialogueManager.is_active() or TerminalManager.is_active() \
		or ChallengeManager.is_active() \
		or GameMenu.is_active() or HUD.is_popup_active():
		return
	if player_in_range and event.is_action_pressed("interact"):
		interact()


## Usa o objeto, como se o jogador tivesse apertado E. Também é chamado pela
## caminhada automática (Player.gd) quando o personagem chega ao alcance.
func interact() -> void:
	if DialogueManager.is_active() or TerminalManager.is_active() \
		or ChallengeManager.is_active() \
		or GameMenu.is_active() or HUD.is_popup_active():
		return
	SoundManager.play("interact")
	_on_interact()


## Sobrescreva este método em cada tipo de objeto interativo.
func _on_interact() -> void:
	pass
