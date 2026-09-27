extends CanvasLayer
## HUD.gd — Autoload
## Interface permanente do jogo: nível, barra de XP e objetivo atual.
## Também mostra a tela de "MISSÃO CONCLUÍDA" com o conceito aprendido
## (parte importante do lado educativo do projeto).

@onready var level_label: Label = $Info/LevelLabel
@onready var xp_bar: ProgressBar = $Info/XPBar
@onready var xp_label: Label = $Info/XPLabel
@onready var objective_label: Label = $Info/ObjectiveLabel

@onready var complete_panel: Panel = $CompletePanel
@onready var complete_title: Label = $CompletePanel/TitleLabel
@onready var complete_text: Label = $CompletePanel/TextLabel
@onready var complete_concept: Label = $CompletePanel/ConceptLabel
@onready var complete_xp: Label = $CompletePanel/XPLabel

var _popup_active: bool = false


func _ready() -> void:
	complete_panel.visible = false
	GameManager.xp_changed.connect(_on_xp_changed)
	MissionManager.mission_started.connect(_on_mission_changed)
	MissionManager.mission_completed.connect(_on_mission_completed)
	_refresh()


func is_popup_active() -> bool:
	return _popup_active


func _refresh() -> void:
	_update_xp_display()
	_update_objective()


func _on_xp_changed(_current_xp: int, _xp_to_next: int, _level: int) -> void:
	_update_xp_display()


func _update_xp_display() -> void:
	level_label.text = "NÍVEL %d" % GameManager.level
	var to_next: int = GameManager.xp_to_next_level()
	xp_bar.max_value = to_next
	xp_bar.value = GameManager.xp
	xp_label.text = "XP %d/%d" % [GameManager.xp, to_next]


func _update_objective() -> void:
	var mission: Dictionary = MissionManager.get_active_mission()
	if mission.is_empty():
		objective_label.text = "Objetivo: —"
	else:
		objective_label.text = "Objetivo: " + String(mission["objective"])


func _on_mission_changed(_mission_id: String) -> void:
	_update_objective()


func _on_mission_completed(mission_id: String) -> void:
	var mission: Dictionary = MissionManager.get_mission(mission_id)
	if mission.is_empty():
		return

	SoundManager.play("success")

	complete_title.text = "DESAFIO CONCLUÍDO"
	complete_text.text = String(mission["explanation"])
	complete_concept.text = "CONCEITO APRENDIDO: " + String(mission["concept"])
	complete_xp.text = "+%d XP" % int(mission["xp"])

	complete_panel.visible = true
	_popup_active = true

	_update_objective()
	_update_xp_display()


func _unhandled_input(event: InputEvent) -> void:
	if not _popup_active:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("open_menu"):
		complete_panel.visible = false
		_popup_active = false
		get_viewport().set_input_as_handled()
