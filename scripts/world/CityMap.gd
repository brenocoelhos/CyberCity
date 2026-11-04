extends CanvasLayer
## CityMap.gd
## Mapa grande da cidade: abre ao clicar no minimapa (ou na tecla M) e mostra
## a cidade inteira com o nome de cada prédio, os bairros, os terminais, onde
## o jogador está e para onde vai o objetivo da missão.
##
## O desenho do terreno é o do próprio mundo (um SubViewport que enxerga o
## mesmo mundo da cidade); por cima ficam as etiquetas, montadas por código a
## cada abertura (assim refletem o estado atual: "!" de missão, portas
## trancadas, objetivo).

const MissionTarget := preload("res://scripts/ui/MissionTarget.gd")

## Área da cidade na tela (a cidade tem 62×27 tiles: proporção ~2,3 : 1).
const VIEW_SIZE := Vector2i(1176, 512)
const VIEW_POS := Vector2(52, 112)

## Nomes mais curtos só para o mapa (o nome completo continua no prédio e no jogo).
const SHORT_NAMES := {
	"TechCorp Ltda.": "TechCorp",
	"DataSoft Sistemas": "DataSoft",
	"Centro de Tecnologia": "Centro Tech",
	"Loja Eletrônica": "Loja",
}

## Nomes dos bairros: linha (de cima para baixo) × coluna (da esquerda para a direita).
const DISTRICTS := [
	["Bairro Residencial", "Praça Central", "Distrito Empresarial"],
	["Vila Residencial", "Centro de Tecnologia", "Comércio"],
]

## Camada de visibilidade (bit 2) dos textos do mundo que o mapa esconde.
const WORLD_TEXT_LAYER := 2

const C_ACCENT := Color("#2f8cff")
const C_GREEN := Color("#3dff6e")
const C_YELLOW := Color("#ffd75f")
const C_RED := Color("#ff5f5f")
const C_LOCKED := Color("#8a8f98")

var _city: Node2D
var _zoom: float = 1.0
var _open: bool = false

var _container: SubViewportContainer
var _markers: Control
var _legend: RichTextLabel
var _player_marker: Control
var _ring: Control
var _placed: Array[Rect2] = []
var _time: float = 0.0


## Liga o mapa a uma cidade (City.gd chama isto uma vez).
func setup(city: Node2D) -> void:
	_city = city
	layer = 6
	visible = false
	_zoom = float(VIEW_SIZE.x) / float(city.MAP_WIDTH * city.TILE_SIZE)
	_build()


func is_open() -> bool:
	return _open


func open() -> void:
	if _open or not _can_open():
		return
	_rebuild_markers()
	_open = true
	visible = true
	HUD.set_overlay_active(true)
	SoundManager.play("blip")


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	HUD.set_overlay_active(false)
	SoundManager.play("blip")


## Não abre por cima de diálogo, terminal, celular etc.
func _can_open() -> bool:
	return not (DialogueManager.is_active() or TerminalManager.is_active()
		or ChallengeManager.is_active() or GameMenu.is_active() or HUD.is_popup_active()
		or BossManager.is_busy())


func _exit_tree() -> void:
	if _open:
		HUD.set_overlay_active(false)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE and _open:
		close()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_M:
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _open:
		return
	_time += delta
	var player: Node2D = _city.get_node_or_null("Player")
	if player != null and _player_marker != null:
		_player_marker.position = _to_map(player.global_position)
		_player_marker.scale = Vector2.ONE * (1.0 + 0.25 * sin(_time * 5.0))
	if _ring != null:
		_ring.scale = Vector2.ONE * (1.0 + 0.2 * sin(_time * 4.0))


## Posição do mundo -> posição dentro da área do mapa.
func _to_map(world_position: Vector2) -> Vector2:
	return world_position * _zoom


# --- Montagem fixa -----------------------------------------------------------------

func _build() -> void:
	# Fundo escuro: clicar fora do quadro fecha.
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.01, 0.03, 0.06, 0.97)
	backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close())
	add_child(backdrop)

	var frame := Panel.new()
	frame.position = Vector2(28, 24)
	frame.size = Vector2(1224, 672)
	frame.theme_type_variation = &"FlatPanel"
	add_child(frame)

	var title := Label.new()
	title.text = "MAPA DA CIDADE"
	title.position = Vector2(52, 36)
	title.theme_type_variation = &"HudTitle"
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)

	var hint := Label.new()
	hint.text = "M ou ESC para fechar"
	hint.position = Vector2(940, 42)
	hint.add_theme_color_override("font_color", Color("#5f8f6a"))
	add_child(hint)

	var close_button := Button.new()
	close_button.text = "Fechar"
	close_button.position = Vector2(1140, 36)
	close_button.pressed.connect(close)
	add_child(close_button)

	# O próprio mundo da cidade, visto de cima e inteiro.
	_container = SubViewportContainer.new()
	_container.position = VIEW_POS
	_container.size = Vector2(VIEW_SIZE)
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	viewport.world_2d = _city.get_viewport().world_2d
	# Os textos pequenos do mundo (placas de bairro, nomes sobre os prédios)
	# ficam na camada de visibilidade 2 e não aparecem neste mapa (as etiquetas
	# do mapa os substituem). No jogo normal continuam aparecendo.
	viewport.canvas_cull_mask = 0xFFFFFFFF & ~WORLD_TEXT_LAYER
	_container.add_child(viewport)
	var camera := Camera2D.new()
	camera.zoom = Vector2(_zoom, _zoom)
	camera.position = Vector2(_city.MAP_WIDTH, _city.MAP_HEIGHT) * _city.TILE_SIZE / 2.0
	viewport.add_child(camera)

	var border := ReferenceRect.new()
	border.position = VIEW_POS
	border.size = Vector2(VIEW_SIZE)
	border.border_color = C_ACCENT
	border.border_width = 2.0
	border.editor_only = false
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)

	_markers = Control.new()
	_markers.position = VIEW_POS
	_markers.size = Vector2(VIEW_SIZE)
	_markers.clip_contents = true
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_markers)

	_legend = RichTextLabel.new()
	_legend.bbcode_enabled = true
	_legend.fit_content = true
	_legend.scroll_active = false
	_legend.position = Vector2(52, VIEW_POS.y + VIEW_SIZE.y + 12)
	_legend.size = Vector2(1176, 30)
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend.text = "[color=#ff5f5f]Vermelho: você[/color]    [color=#ffd75f]Amarelo: objetivo da missão e prédios com ![/color]    [color=#2f8cff]Azul: entrada de prédio[/color]    [color=#3dff6e]Verde: terminal[/color]    [color=#8a8f98]Cinza: trancado[/color]"
	add_child(_legend)


# --- Etiquetas (refeitas a cada abertura) -----------------------------------------------

## Move os textos do mundo (Labels da cidade) para a camada que o mapa não desenha.
func _hide_world_texts() -> void:
	for label in _city.find_children("*", "Label", true, false):
		if is_ancestor_of(label) or _city.get_node("UI").is_ancestor_of(label):
			continue
		(label as Label).visibility_layer = WORLD_TEXT_LAYER


func _rebuild_markers() -> void:
	_hide_world_texts()
	for child in _markers.get_children():
		child.queue_free()
		_markers.remove_child(child)
	_placed = []
	_player_marker = null
	_ring = null

	_add_district_names()
	var target: Node2D = MissionTarget.find_target(_city, MissionTarget.mission_to_guide())

	var buildings: Node = _city.get_node_or_null("Buildings")
	if buildings != null:
		for building in buildings.get_children():
			if "building_name" in building:
				_add_building(building, target)
	for pair in [["TerminalPublico", "Terminal Público"], ["TerminalSalvamento", "Salvar o jogo"]]:
		var terminal: Node2D = _city.get_node_or_null(String(pair[0]))
		if terminal != null:
			var is_target: bool = terminal == target
			_add_pin(_to_map(terminal.global_position), C_YELLOW if is_target else C_GREEN, 6.0)
			_add_label(String(pair[1]), _to_map(terminal.global_position), C_YELLOW if is_target else C_GREEN, false)
			if is_target:
				_add_ring(_to_map(terminal.global_position))

	# O jogador por último, para ficar por cima.
	var player: Node2D = _city.get_node_or_null("Player")
	if player != null:
		_player_marker = _add_pin(_to_map(player.global_position), C_RED, 16.0, true)
		_add_label("Você", _to_map(player.global_position), C_RED, true, true)


func _add_district_names() -> void:
	var roads_x: Array = _city.ROADS_X
	var roads_y: Array = _city.ROADS_Y
	var tile: float = _city.TILE_SIZE
	for row in range(DISTRICTS.size()):
		for column in range(DISTRICTS[row].size()):
			var center_x: float = (roads_x[column] + roads_x[column + 1] + 1) * 0.5 * tile
			var top_y: float = (roads_y[row] + 1.6) * tile
			var label := Label.new()
			label.text = String(DISTRICTS[row][column]).to_upper()
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
			label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			label.add_theme_constant_override("outline_size", 6)
			_markers.add_child(label)
			var map_position := _to_map(Vector2(center_x, top_y))
			label.position = Vector2(map_position.x - label.get_combined_minimum_size().x / 2.0, map_position.y)


func _add_building(building: Node2D, target: Node2D) -> void:
	var door: Node2D = building.get_node_or_null("Door")
	var anchor: Vector2 = _to_map(door.global_position if door != null else building.global_position)
	var marker: Node = building.get_node_or_null("MissionMarker")
	var has_mission: bool = marker != null and marker.visible
	var locked: bool = false
	if door != null and "locked" in door:
		locked = bool(door.locked)
		if locked and String(door.unlock_after_mission) != "" and MissionManager.is_completed(String(door.unlock_after_mission)):
			locked = false

	var color: Color = C_ACCENT
	var text: String = String(SHORT_NAMES.get(String(building.building_name), building.building_name))
	if locked:
		color = C_LOCKED
		text += " (trancada)"
	elif has_mission or building == target:
		color = C_YELLOW
		text += " !"
	_add_pin(anchor, color, 8.0)
	_add_label(text, anchor, color, true)
	if building == target:
		_add_ring(anchor)


func _add_pin(map_position: Vector2, color: Color, size: float, hollow: bool = false) -> Control:
	var pin := Control.new()
	pin.position = map_position
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.draw.connect(func() -> void:
		if hollow:
			# Anel vazado: não esconde o ponto que está embaixo (ex.: uma porta).
			pin.draw_arc(Vector2.ZERO, size / 2.0, 0.0, TAU, 24, Color(0, 0, 0, 0.9), 5.0)
			pin.draw_arc(Vector2.ZERO, size / 2.0, 0.0, TAU, 24, color, 3.0)
			return
		pin.draw_circle(Vector2.ZERO, size / 2.0 + 2.0, Color(0, 0, 0, 0.85))
		pin.draw_circle(Vector2.ZERO, size / 2.0, color))
	_markers.add_child(pin)
	return pin


func _add_ring(map_position: Vector2) -> void:
	_ring = Control.new()
	_ring.position = map_position
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(func() -> void:
		_ring.draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 28, C_YELLOW, 3.0))
	_markers.add_child(_ring)


## Etiqueta com o nome, perto do ponto. Se bater em outra etiqueta, desce
## (ou sobe, com "below" falso) em degraus até achar lugar, e uma linha fina
## liga a etiqueta ao seu ponto. Com "side", fica ao lado do ponto (para o
## jogador, que muitas vezes está em cima de uma porta).
func _add_label(text: String, anchor: Vector2, color: Color, below: bool, side: bool = false) -> void:
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.13, 0.94)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", style)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color.lightened(0.45))
	pill.add_child(label)
	_markers.add_child(pill)

	var size: Vector2 = pill.get_combined_minimum_size()
	var x: float = anchor.x - size.x / 2.0
	var y: float = anchor.y + 10.0
	if side:
		x = anchor.x + 12.0
		y = anchor.y - size.y / 2.0
	x = clampf(x, 2.0, float(VIEW_SIZE.x) - size.x - 2.0)
	var default_y: float = y
	var step: float = size.y + 4.0
	var rect := Rect2(Vector2(x, y), size)
	for attempt in range(8):
		var free := true
		for other in _placed:
			if rect.grow(3.0).intersects(other):
				free = false
				break
		if free:
			break
		rect.position.y += step if (below or side) else -step
	pill.position = rect.position
	pill.size = size
	_placed.append(rect)

	# Etiqueta afastada do ponto: linha de ligação (atrás da etiqueta).
	if not side and absf(rect.position.y - default_y) > 1.0:
		var line := Control.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var end := Vector2(clampf(anchor.x, rect.position.x + 4.0, rect.end.x - 4.0), rect.position.y if rect.position.y > anchor.y else rect.end.y)
		line.draw.connect(func() -> void:
			line.draw_line(anchor, end, Color(color, 0.9), 1.5))
		_markers.add_child(line)
		_markers.move_child(line, pill.get_index())
