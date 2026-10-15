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
## Missões que acontecem dentro deste prédio. Quando uma delas é do
## capítulo atual (ou está em andamento), aparece um "!" sobre o prédio.
@export var mission_ids: PackedStringArray = PackedStringArray()

var _marker_tween: Tween

func _ready() -> void:
	_update_building()
	if not Engine.is_editor_hint():
		$Door.interior_scene_path = interior_path
		$Door.building_title = building_name
		$Door.locked = starts_locked
		$Door.unlock_after_mission = unlock_mission
		MissionManager.mission_started.connect(_on_missions_changed)
		MissionManager.mission_completed.connect(_on_missions_changed)
		CampaignManager.chapter_unlocked.connect(_on_missions_changed)
		_update_marker()

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
	$MissionMarker.position = Vector2(-10, -size.y - 52)
	$MissionMarker.visible = false

func _on_missions_changed(_id: String) -> void:
	_update_marker()

func _update_marker() -> void:
	var show_marker := false
	for mission_id in mission_ids:
		if MissionManager.is_completed(mission_id):
			continue
		if MissionManager.is_active(mission_id) or CampaignManager.is_mission_in_current_chapter(mission_id):
			show_marker = true
	var marker: Label = $MissionMarker
	marker.visible = show_marker
	if show_marker and _marker_tween == null:
		# O "!" sobe e desce devagar para chamar atenção.
		var base_y := marker.position.y
		_marker_tween = create_tween().set_loops()
		_marker_tween.tween_property(marker, "position:y", base_y - 6.0, 0.5)
		_marker_tween.tween_property(marker, "position:y", base_y, 0.5)
