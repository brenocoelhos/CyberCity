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
## de jogos de mundo aberto): amarelo forte = porta da missão (com coluna de
## luz alta e "!" em cima), azul-claro discreto = outras portas abertas,
## cinza = trancada.
const MARKER_MISSION := Color(1.0, 0.82, 0.18)
const MARKER_OPEN := Color(0.45, 0.78, 1.0)
const MARKER_LOCKED := Color(0.62, 0.66, 0.74)

## Ligado pelo Building quando há missão para fazer neste prédio.
var mission_door: bool = false:
	set(value):
		mission_door = value
		if _mission_mark:
			_mission_mark.visible = value
var _mission_mark: Label

var _player_in_range: bool = false
var _marker: Node2D
var _marker_time: float = 0.0
var _lock_check: float = 0.0


func _ready() -> void:
	# O balão "[E] Entrar" fica logo acima da cabeça de quem está na porta
	# (e não lá embaixo, em cima da rua).
	prompt.offset_top = -48.0
	prompt.offset_bottom = -32.0
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
	# "!" logo acima da porta: aparece mesmo de perto, quando o "!" do telhado
	# já saiu da tela.
	_mission_mark = Label.new()
	_mission_mark.text = "!"
	_mission_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mission_mark.add_theme_color_override("font_color", MARKER_MISSION)
	_mission_mark.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	_mission_mark.add_theme_constant_override("outline_size", 6)
	_mission_mark.add_theme_font_size_override("font_size", 22)
	_mission_mark.position = Vector2(-10, -84)
	_mission_mark.size = Vector2(20, 28)
	_mission_mark.z_as_relative = false
	_mission_mark.z_index = 50
	_mission_mark.visible = mission_door
	_mission_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mission_mark)


func _process(delta: float) -> void:
	_marker_time += delta
	# A porta pode destrancar enquanto o jogador está longe (missão concluída).
	_lock_check -= delta
	if _lock_check <= 0.0:
		_lock_check = 0.5
		_update_lock_state()
	_marker.queue_redraw()
	if _mission_mark.visible:
		_mission_mark.position.y = -84.0 - 5.0 * (0.5 + 0.5 * sin(_marker_time * 4.0))


## Marcador de entrada: disco de luz achatado no chão, anel que pulsa e uma
## coluna de luz suave subindo. Soma luz sobre o cenário (blend aditivo).
func _draw_marker() -> void:
	var color: Color = MARKER_LOCKED if locked else (MARKER_MISSION if mission_door else MARKER_OPEN)
	var pulse: float = 0.5 + 0.5 * sin(_marker_time * 3.2)
	# Portas comuns: luz mais fraca e coluna baixa; a da missão chama atenção.
	var strength: float = 1.0 if mission_door else 0.55
	var column: float = 96.0 if mission_door else 40.0
	_marker.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	for i in range(6):
		_marker.draw_circle(Vector2.ZERO, 24.0 - i * 3.5, Color(color, (0.05 + i * 0.035) * strength))
	_marker.draw_arc(Vector2.ZERO, 19.0 + pulse * 2.5, 0.0, TAU, 40, Color(color, (0.55 + pulse * 0.4) * strength), 2.5)
	_marker.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var base := Color(color, 0.0 if locked else (0.28 + pulse * 0.12) * strength)
	var top := Color(color, 0.0)
	_marker.draw_polygon(
		PackedVector2Array([Vector2(-17, 0), Vector2(17, 0), Vector2(13, -column), Vector2(-13, -column)]),
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
		SoundManager.play("door", -6.0)
		SceneTransition.enter_building(interior_scene_path, building_title, global_position + Vector2(0, 40), interior_config)
