extends Control
## MissionArrow.gd
## Seta na borda da tela que aponta para a próxima missão (ver MissionTarget).
## Fica no HUD. Só aparece quando:
##   - o jogador já liberou a ferramenta (GameManager, nível 3);
##   - ela está ligada nos Ajustes do celular (Settings.mission_arrow);
##   - o alvo está fora da tela (quando está à vista, o "!" já basta);
##   - nenhum diálogo, terminal, desafio ou menu está aberto.

const MissionTarget := preload("res://scripts/ui/MissionTarget.gd")

## Distância (em pixels da tela) entre a seta e a borda.
const EDGE_MARGIN := 56.0
## Alvos mais perto da borda do que isto já contam como "à vista".
const ON_SCREEN_MARGIN := 24.0
const TILE_SIZE := 32.0
const ARROW_COLOR := Color(1.0, 0.85, 0.2)
const OUTLINE_COLOR := Color(0.05, 0.05, 0.08, 0.9)

var _target: Node2D = null
var _next_refresh: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	# Procurar o alvo percorre a cena, então só a cada meio segundo.
	_next_refresh -= delta
	if _next_refresh <= 0.0:
		_next_refresh = 0.5
		_refresh_target()
	queue_redraw()


func is_enabled() -> bool:
	if not GameManager.is_tool_unlocked("mission_arrow") or not Settings.mission_arrow:
		return false
	return not (DialogueManager.is_active() or TerminalManager.is_active() or ChallengeManager.is_active() or GameMenu.is_active() or HUD.is_popup_active())


func _refresh_target() -> void:
	_target = null
	if not is_enabled():
		return
	_target = MissionTarget.find_target(get_tree().current_scene, MissionTarget.mission_to_guide())


func _draw() -> void:
	if _target == null or not is_instance_valid(_target) or not is_enabled():
		return

	var screen_size: Vector2 = get_viewport_rect().size
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * _target.global_position
	if Rect2(Vector2.ZERO, screen_size).grow(-ON_SCREEN_MARGIN).has_point(screen_pos):
		return

	var center: Vector2 = screen_size / 2.0
	var direction: Vector2 = (screen_pos - center).normalized()
	var half: Vector2 = center - Vector2(EDGE_MARGIN, EDGE_MARGIN)
	var scale_x: float = half.x / absf(direction.x) if direction.x != 0.0 else INF
	var scale_y: float = half.y / absf(direction.y) if direction.y != 0.0 else INF
	var anchor: Vector2 = center + direction * minf(scale_x, scale_y)

	var side: Vector2 = direction.orthogonal()
	var points := PackedVector2Array([
		anchor + direction * 18.0,
		anchor - direction * 10.0 + side * 14.0,
		anchor - direction * 10.0 - side * 14.0,
	])
	draw_colored_polygon(points, ARROW_COLOR)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), OUTLINE_COLOR, 2.0)

	# Distância em tiles, para o jogador ter noção do quão longe fica.
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var tiles: int = int(round(player.global_position.distance_to(_target.global_position) / TILE_SIZE))
		var label: String = "%d" % tiles
		var font: Font = ThemeDB.fallback_font
		var text_pos: Vector2 = anchor - direction * 30.0 - Vector2(font.get_string_size(label).x / 2.0, -5.0)
		draw_string(font, text_pos + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, OUTLINE_COLOR)
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ARROW_COLOR)
