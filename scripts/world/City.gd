extends Node2D
## Map unit: 32×32. Atlas coordinates are documented in docs/TILESET_32.md.
const TILE_SIZE := 32
const MAP_WIDTH := 42
const MAP_HEIGHT := 28
const ROAD_X := 21
const ROAD_Y := 14
const GRASS_TILES := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)]
const SIDEWALK := Vector2i(0, 1)
@onready var ground: TileMapLayer = $Ground
@onready var player: CharacterBody2D = $Player

func _ready() -> void:
	_generate_ground()
	_apply_pending_spawn()
	var camera: Camera2D = player.get_node("Camera2D")
	camera.zoom = Vector2(2, 2)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = MAP_WIDTH * TILE_SIZE
	camera.limit_bottom = MAP_HEIGHT * TILE_SIZE
	camera.reset_smoothing()
	CampaignManager.play_opening()

func _generate_ground() -> void:
	ground.clear()
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			ground.set_cell(Vector2i(x, y), 0, _tile_for(x, y))
	# Small paved entrances below each independent building sprite.
	for building in $Buildings.get_children():
		var entrance: Vector2i = ground.local_to_map(building.position)
		for dx in range(-1, 2):
			for dy in range(2):
				ground.set_cell(entrance + Vector2i(dx, dy), 0, SIDEWALK)

func _tile_for(x: int, y: int) -> Vector2i:
	if x == ROAD_X and y == ROAD_Y:
		return Vector2i(4, 2) # Four-way junction, once at the intersection.
	if y == ROAD_Y:
		if x == ROAD_X - 3 or x == ROAD_X + 3:
			return Vector2i(7, 2) # Pedestrian crossing.
		return Vector2i(1, 2)
	if x == ROAD_X:
		return Vector2i(0, 2)
	if absi(x - ROAD_X) == 1 or absi(y - ROAD_Y) == 1:
		return SIDEWALK
	# Sparse grass detail instead of repeating flowers in every cell.
	var variation := posmod(x * 73 + y * 37 + x * y, 31)
	if variation < 5:
		return GRASS_TILES[variation + 1]
	return GRASS_TILES[0]

func _apply_pending_spawn() -> void:
	if SceneTransition.has_pending_spawn:
		player.global_position = SceneTransition.return_spawn_position
		SceneTransition.has_pending_spawn = false
