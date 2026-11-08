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

const UiStyle := preload("res://scripts/ui/UiStyle.gd")

@onready var prompt: Label = $PromptLabel

## Cores do marcador de entrada (a luz no chão, como nos marcadores de missão
## de jogos de mundo aberto): amarelo = pode entrar, cinza = trancada.
const MARKER_OPEN := Color(1.0, 0.82, 0.18)
const MARKER_LOCKED := Color(0.62, 0.66, 0.74)

var _player_in_range: bool = false
var _marker: Node2D
var _marker_time: float = 0.0
var _lock_check: float = 0.0


func _ready() -> void:
	prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_lock_state()
	_marker = Node2D.new()
	_marker.name = "EntranceMarker"
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_marker.material = glow
	_marker.draw.connect(_draw_marker)
	add_child(_marker)
	move_child(_marker, 0)


func _process(delta: float) -> void:
	_marker_time += delta
	# A porta pode destrancar enquanto o jogador está longe (missão concluída).
	_lock_check -= delta
	if _lock_check <= 0.0:
		_lock_check = 0.5
		_update_lock_state()
	_marker.queue_redraw()


## Marcador de entrada: disco de luz achatado no chão, anel que pulsa e uma
## coluna de luz suave subindo. Soma luz sobre o cenário (blend aditivo).
func _draw_marker() -> void:
	var color: Color = MARKER_LOCKED if locked else MARKER_OPEN
	var pulse: float = 0.5 + 0.5 * sin(_marker_time * 3.2)
	_marker.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	for i in range(6):
		_marker.draw_circle(Vector2.ZERO, 24.0 - i * 3.5, Color(color, 0.05 + i * 0.035))
	_marker.draw_arc(Vector2.ZERO, 19.0 + pulse * 2.5, 0.0, TAU, 40, Color(color, 0.55 + pulse * 0.4), 2.5)
	_marker.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var base := Color(color, 0.0 if locked else 0.28 + pulse * 0.12)
	var top := Color(color, 0.0)
	_marker.draw_polygon(
		PackedVector2Array([Vector2(-17, 0), Vector2(17, 0), Vector2(13, -56), Vector2(-13, -56)]),
		PackedColorArray([base, base, top, top]))


func _update_lock_state() -> void:
	if unlock_after_mission != "" and MissionManager.is_completed(unlock_after_mission):
		locked = false


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_update_lock_state()
	_player_in_range = true
	UiStyle.prompt(prompt, "Bloqueado" if locked else "[E] Entrar")
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
