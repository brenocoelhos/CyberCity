extends Node2D
## Map unit: 32×32. Atlas coordinates are documented in docs/TILESET_32.md.
##
## A cidade é uma grade de ruas que forma 6 quarteirões (3 colunas × 2
## linhas). Cada quarteirão tem calçada em volta e um tema:
##
##   Bairro Residencial | Praça Central        | Distrito Empresarial
##   Vila Residencial   | Centro de Tecnologia | Comércio
##
## O terreno é pintado por código no início do jogo (_tile_for). Prédios,
## decoração, NPCs e placas ficam em City.tscn e podem ser movidos no editor.
const TILE_SIZE := 32
const MAP_WIDTH := 62
const MAP_HEIGHT := 27

## Colunas (x) das ruas verticais e linhas (y) das ruas horizontais.
## As ruas das pontas formam um anel em volta da cidade.
const ROADS_X := [2, 21, 40, 59]
const ROADS_Y := [2, 13, 24]

## Distância (em tiles) entre um cruzamento e sua faixa de pedestre.
const CROSSWALK_DISTANCE := 3

const GRASS_TILES := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)]
const SIDEWALK := Vector2i(0, 1)
const PAVED := Vector2i(2, 1)
const CROSSWALK := Vector2i(7, 2)

## Áreas calçadas dentro dos quarteirões (praça, pátios e caminhos).
## Rect2i(x, y, largura, altura) em tiles.
const PAVED_AREAS := [
	# Praça Central: largo no meio + caminhos até as calçadas.
	Rect2i(27, 6, 8, 5),
	Rect2i(30, 4, 2, 2),
	Rect2i(30, 11, 2, 2),
	Rect2i(23, 8, 4, 1),
	Rect2i(35, 8, 4, 1),
	# Centro de Tecnologia: pátio na frente dos servidores.
	Rect2i(24, 16, 14, 3),
	# Comércio: pracinha com bancos atrás da loja.
	Rect2i(46, 16, 8, 3),
]

## Ligações de cada peça de rua: [cima, baixo, esquerda, direita] -> atlas.
const ROAD_PIECES := {
	"0011": Vector2i(1, 2), # reta horizontal
	"1100": Vector2i(0, 2), # reta vertical
	"1111": Vector2i(4, 2), # cruzamento
	"0111": Vector2i(6, 2), # T com saída para baixo
	"1110": Vector2i(3, 4), # T com saída para a esquerda
	"1011": Vector2i(4, 4), # T com saída para cima
	"1101": Vector2i(5, 4), # T com saída para a direita
	"0110": Vector2i(2, 2), # curva esquerda/baixo
	"1010": Vector2i(0, 4), # curva esquerda/cima
	"1001": Vector2i(1, 4), # curva cima/direita
	"0101": Vector2i(2, 4), # curva direita/baixo
}

@onready var ground: TileMapLayer = $Ground
@onready var player: CharacterBody2D = $Player
@onready var minimap_viewport: SubViewport = $UI/MinimapPanel/SubViewportContainer/SubViewport
@onready var minimap_camera: Camera2D = $UI/MinimapPanel/SubViewportContainer/SubViewport/MinimapCamera
@onready var minimap_container: SubViewportContainer = $UI/MinimapPanel/SubViewportContainer
@onready var minimap_dot: ColorRect = $UI/MinimapPanel/PlayerDot

func _ready() -> void:
	_generate_ground()
	_build_map_bounds()
	_apply_pending_spawn()
	var camera: Camera2D = player.get_node("Camera2D")
	camera.zoom = Vector2(2, 2)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = MAP_WIDTH * TILE_SIZE
	camera.limit_bottom = MAP_HEIGHT * TILE_SIZE
	camera.reset_smoothing()
	_setup_minimap()
	CampaignManager.play_opening()

func _process(_delta: float) -> void:
	_update_minimap_dot()

func _generate_ground() -> void:
	ground.clear()
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var cell := Vector2i(x, y)
			if _is_road(x, y) and _is_crosswalk(x, y) and not ROADS_Y.has(y):
				# Faixa numa rua vertical: a mesma peça, girada (transposta).
				ground.set_cell(cell, 0, CROSSWALK, TileSetAtlasSource.TRANSFORM_TRANSPOSE)
			else:
				ground.set_cell(cell, 0, _tile_for(x, y))

func _tile_for(x: int, y: int) -> Vector2i:
	if _is_road(x, y):
		if _is_crosswalk(x, y):
			return CROSSWALK
		return _road_piece(x, y)
	if _is_next_to_road(x, y):
		return SIDEWALK
	for area in PAVED_AREAS:
		if area.has_point(Vector2i(x, y)):
			return PAVED
	# Sparse grass detail instead of repeating flowers in every cell.
	var variation := posmod(x * 73 + y * 37 + x * y, 31)
	if variation < 5:
		return GRASS_TILES[variation + 1]
	return GRASS_TILES[0]

## Rua = linha ou coluna de rua, dentro do anel externo.
func _is_road(x: int, y: int) -> bool:
	var inside_x: bool = x >= ROADS_X[0] and x <= ROADS_X[-1]
	var inside_y: bool = y >= ROADS_Y[0] and y <= ROADS_Y[-1]
	return (ROADS_X.has(x) and inside_y) or (ROADS_Y.has(y) and inside_x)

func _is_next_to_road(x: int, y: int) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if _is_road(x + dx, y + dy):
				return true
	return false

## Escolhe reta, curva, T ou cruzamento olhando os 4 vizinhos.
func _road_piece(x: int, y: int) -> Vector2i:
	var key := ""
	for neighbor in [Vector2i(x, y - 1), Vector2i(x, y + 1), Vector2i(x - 1, y), Vector2i(x + 1, y)]:
		key += "1" if _is_road(neighbor.x, neighbor.y) else "0"
	return ROAD_PIECES.get(key, Vector2i(10, 2))

## Faixas de pedestre a CROSSWALK_DISTANCE tiles de cada cruzamento ou T.
func _is_crosswalk(x: int, y: int) -> bool:
	if ROADS_Y.has(y) and not ROADS_X.has(x):
		for road_x in ROADS_X:
			if absi(x - road_x) == CROSSWALK_DISTANCE:
				return true
	if ROADS_X.has(x) and not ROADS_Y.has(y):
		for road_y in ROADS_Y:
			if absi(y - road_y) == CROSSWALK_DISTANCE:
				return true
	return false

## Paredes invisíveis na borda de grama em volta da cidade.
func _build_map_bounds() -> void:
	var width := float(MAP_WIDTH * TILE_SIZE)
	var height := float(MAP_HEIGHT * TILE_SIZE)
	var half := TILE_SIZE / 2.0
	var walls := [
		[Vector2(width / 2.0, half), Vector2(width, TILE_SIZE)],
		[Vector2(width / 2.0, height - half), Vector2(width, TILE_SIZE)],
		[Vector2(half, height / 2.0), Vector2(TILE_SIZE, height)],
		[Vector2(width - half, height / 2.0), Vector2(TILE_SIZE, height)],
	]
	for wall in walls:
		var body := StaticBody2D.new()
		body.collision_mask = 0
		body.position = wall[0]
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = wall[1]
		shape.shape = rect
		body.add_child(shape)
		$MapBounds.add_child(body)

## O minimapa mostra a cidade inteira, vista pela mesma "câmera do mundo".
func _setup_minimap() -> void:
	minimap_viewport.world_2d = get_viewport().world_2d
	var map_size := Vector2(MAP_WIDTH * TILE_SIZE, MAP_HEIGHT * TILE_SIZE)
	var view_size := Vector2(minimap_viewport.size)
	var zoom_value := minf(view_size.x / map_size.x, view_size.y / map_size.y)
	minimap_camera.zoom = Vector2(zoom_value, zoom_value)
	minimap_camera.position = map_size / 2.0

func _update_minimap_dot() -> void:
	var view_size := Vector2(minimap_viewport.size)
	var local := (player.global_position - minimap_camera.position) * minimap_camera.zoom + view_size / 2.0
	var scale_to_container := minimap_container.size / view_size
	minimap_dot.position = minimap_container.position + local * scale_to_container - minimap_dot.size / 2.0

func _apply_pending_spawn() -> void:
	if SceneTransition.has_pending_spawn:
		player.global_position = SceneTransition.return_spawn_position
		SceneTransition.has_pending_spawn = false
