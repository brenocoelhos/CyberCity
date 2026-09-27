extends CharacterBody2D

## Velocidade em pixels por segundo, editável no Inspector.
@export var speed: float = 160.0

var last_direction: Vector2 = Vector2.DOWN
var _facing: String = "baixo"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var footstep_timer: Timer = $FootstepTimer

func _ready() -> void:
	sprite.play("parado_baixo")

func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO
	if not _is_ui_blocking():
		direction = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down")
		).normalized()

	velocity = direction * speed
	move_and_slide()
	_update_animation(direction)
	_update_footsteps(direction)

func _update_animation(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		last_direction = direction
		# Nas diagonais, a direção horizontal tem prioridade visual.
		if direction.x < 0.0:
			_facing = "esquerda"
		elif direction.x > 0.0:
			_facing = "direita"
		elif direction.y < 0.0:
			_facing = "cima"
		else:
			_facing = "baixo"

	var prefix := "parado_" if direction == Vector2.ZERO else "andar_"
	var animation_name := StringName(prefix + _facing)
	# Não reinicia o mesmo ciclo a cada frame.
	if sprite.animation != animation_name or not sprite.is_playing():
		sprite.play(animation_name)

func _is_ui_blocking() -> bool:
	# Integração com os menus e desafios já existentes no Cyber City.
	return DialogueManager.is_active() \
		or TerminalManager.is_active() \
		or ChallengeManager.is_active() \
		or GameMenu.is_active() \
		or HUD.is_popup_active()

func _update_footsteps(direction: Vector2) -> void:
	if direction == Vector2.ZERO or get_real_velocity().length() < 1.0:
		footstep_timer.stop()
		return
	if footstep_timer.is_stopped():
		SoundManager.play("footstep", -8.0)
		footstep_timer.start()
