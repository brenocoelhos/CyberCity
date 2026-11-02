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
	_build_cyber_streetscape()
	_build_plaza()
	_join_frontages()
	_fill_city_blocks()
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
	if x >= 23 and x <= 38 and y >= 4 and y <= 11:
		return SIDEWALK if (x >= 29 and x <= 32) or (y >= 7 and y <= 8) else PAVED
	for area in PAVED_AREAS:
		if area.has_point(Vector2i(x, y)):
			return PAVED
	if not (x >= 25 and x <= 36 and y >= 5 and y <= 10):
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

## Fachadas decorativas completam os quarteiroes sem criar portas de missao.
func _build_cyber_streetscape() -> void:
	var frontage := Node2D.new()
	frontage.name = "CyberFrontage"
	frontage.y_sort_enabled = true
	add_child(frontage)
	var rows = [[Vector2(144,384),7],[Vector2(528,384),11],[Vector2(624,384),16],
		[Vector2(176,736),14],[Vector2(560,736),6],[Vector2(624,736),2],
		[Vector2(1344,384),2],[Vector2(1440,384),9],[Vector2(1728,384),4],[Vector2(1824,384),12],
		[Vector2(1392,736),10],[Vector2(1488,736),11],[Vector2(1680,736),17],[Vector2(1776,736),5],[Vector2(1856,736),18]]
	for entry in rows:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/environment/cyber/building_%d.png" % entry[1])
		sprite.position = entry[0]
		sprite.offset = Vector2(0,-112)
		frontage.add_child(sprite)
		var wall := StaticBody2D.new()
		wall.position = entry[0] + Vector2(0,-15)
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(80,28)
		collision.shape = shape
		wall.add_child(collision)
		frontage.add_child(wall)
		sprite.set_meta("wall",wall)
	for entry in [["shelter",Vector2(1200,384)],["bin",Vector2(736,736)]]:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/environment/cyber/%s.png" % entry[0])
		sprite.position = entry[1]
		sprite.offset.y = -sprite.texture.get_height()/2.0
		frontage.add_child(sprite)

func _build_plaza() -> void:
	$Decor/Bench5.hide()
	# All solid decoration stays outside the north/south access to terminals.
	for node_name in ["Tree3","Tree4","Treetall2","Treetall3","Bushflowers2","Bushflowers3","Planter1","Planter2","Bench1","Bench2","Bench3","Bench4"]:
		get_node("Decor/"+node_name).hide()
	var monument := StaticBody2D.new()
	monument.name = "PracaMemorial"
	monument.position = Vector2(992,272)
	monument.set_script(load("res://scripts/world/PlazaMonument.gd"))
	add_child(monument)
	for entry in [["planter",Vector2(816,208)],["planter",Vector2(1168,208)],
		["bench",Vector2(816,304)],["bench",Vector2(1168,304)],
		["planter",Vector2(816,368)],["planter",Vector2(1136,368)],
		["kiosk",Vector2(864,208)],
		["shelter",Vector2(816,656)],["kiosk",Vector2(1168,656)],
		["bench",Vector2(832,752)],["bench",Vector2(1152,752)],
		["planter",Vector2(864,704)],["planter",Vector2(1120,704)]]:
		var prop := Sprite2D.new()
		prop.texture = load("res://assets/environment/cyber/%s.png" % entry[0])
		prop.position = entry[1]
		prop.offset.y = -prop.texture.get_height()/2.0
		$Decor.add_child(prop)
	for i in range(4):
		var rack: Sprite2D = get_node("Decor/ServerRack%d" % (i+1))
		rack.show()
		rack.texture = load("res://assets/environment/cyber/kiosk.png")
		rack.offset = Vector2(0,-32)
		rack.position = Vector2(784+(i%2)*48+(i/2)*320,576)
	$Decor/Treetall5.position = Vector2(768,736)
	$Decor/Treetall6.position = Vector2(1216,736)
	$Decor/Lamp9.position = Vector2(896,756)
	$Decor/Lamp10.position = Vector2(1088,756)

## Pack the visible silhouettes, not their transparent 96px canvases.
func _join_frontages() -> void:
	for row in [Rect2(96,383,576,2),Rect2(96,735,576,2),Rect2(1312,383,576,2),Rect2(1312,735,576,2)]:
		var items: Array[Node2D] = []
		for building in $Buildings.get_children():
			if row.has_point(building.position):
				items.append(building)
		for sprite in $CyberFrontage.get_children():
			if sprite is Sprite2D and sprite.has_meta("wall") and row.has_point(sprite.position):
				items.append(sprite)
		items.sort_custom(func(a,b): return a.position.x < b.position.x)
		var total := 0.0
		for item in items:
			var sprite: Sprite2D = item if item is Sprite2D else item.get_node("Sprite2D")
			total += sprite.texture.get_image().get_used_rect().size.x - 8
		var cursor: float = row.position.x + (row.size.x-total)/2.0
		for item in items:
			var sprite: Sprite2D = item if item is Sprite2D else item.get_node("Sprite2D")
			var bounds := sprite.texture.get_image().get_used_rect()
			item.position.x = roundf(cursor - bounds.position.x + sprite.texture.get_width()/2.0)
			if item.has_meta("wall"):
				item.get_meta("wall").position.x = item.position.x
			cursor += bounds.size.x - 8

## Segunda fileira de construcoes: ocupa os fundos sem bloquear as entradas.
func _fill_city_blocks() -> void:
	var rear := Node2D.new()
	rear.name = "RearBuildings"
	rear.y_sort_enabled = true
	add_child(rear)
	var variants := [[8,1,14,3,16,6,10,19],[4,13,0,18,9,2,17,12],[11,6,15,0,19,3,14,1],[16,8,2,12,5,18,4,13]]
	var block_index := 0
	for block in [Vector2(160,224),Vector2(1376,224),Vector2(160,576),Vector2(1376,576)]:
		for index in range(8):
			_add_rear_building(rear,block+Vector2(index*64,0),variants[block_index][index],0.65)
		block_index += 1
	# Anexos laterais do centro, mantendo o eixo da entrada livre.
	for entry in [[Vector2(800,576),1],[Vector2(864,576),4],[Vector2(1120,576),6],[Vector2(1184,576),0]]:
		_add_rear_building(rear,entry[0],entry[1],0.65)
	for i in range(4):
		get_node("Decor/ServerRack%d" % (i+1)).hide()

func _add_rear_building(parent_node: Node2D, base: Vector2, variant: int, ratio: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/environment/cyber/building_%d.png" % variant)
	sprite.position = base
	sprite.offset = Vector2(0,-112)
	sprite.scale = Vector2(ratio,ratio)
	parent_node.add_child(sprite)
	var body := StaticBody2D.new()
	body.position = base+Vector2(0,-10)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(56,20)
	collider.shape = shape
	body.add_child(collider)
	parent_node.add_child(body)
