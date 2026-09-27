@tool
extends StaticBody2D
## One complete sprite per building; the origin is at ground level.
@export var facade: Texture2D:
	set(value):
		facade = value
		if is_node_ready():
			_update_building()
@export var building_name: String = "Casa":
	set(value):
		building_name = value
		if is_node_ready():
			_update_building()
@export_file("*.tscn") var interior_path := "res://scenes/interiors/HouseInterior.tscn"
@export var starts_locked := false
@export var unlock_mission := ""
@export var entrance_x: float = 0.0

func _ready() -> void:
	_update_building()
	if not Engine.is_editor_hint():
		$Door.interior_scene_path = interior_path
		$Door.building_title = building_name
		$Door.locked = starts_locked
		$Door.unlock_after_mission = unlock_mission

func _update_building() -> void:
	var texture: Texture2D = facade if facade != null else $Sprite2D.texture
	$Sprite2D.texture = texture
	var size := texture.get_size()
	$Sprite2D.centered = false
	$Sprite2D.position = Vector2(-size.x / 2.0, -size.y)
	var footprint := RectangleShape2D.new()
	footprint.size = Vector2(size.x - 16.0, 28.0)
	$CollisionShape2D.shape = footprint
	$CollisionShape2D.position = Vector2(0, -15)
	$NameLabel.position = Vector2(-80, -size.y - 22)
	$NameLabel.size = Vector2(160, 20)
	$NameLabel.text = building_name
	$Door.position = Vector2(entrance_x, 10)
