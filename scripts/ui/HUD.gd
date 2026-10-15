extends CanvasLayer
## HUD.gd — Autoload
## Interface permanente do jogo: nível, barra de XP e objetivo atual.
## Também mostra a tela de "MISSÃO CONCLUÍDA" com o conceito aprendido
## (parte importante do lado educativo do projeto).
## No canto fica o ícone do CELULAR: mostra quantas mensagens não lidas
## existem, "vibra" e mostra uma notificação quando chega mensagem nova.

@onready var level_label: Label = $Info/LevelLabel
@onready var xp_bar: ProgressBar = $Info/XPBar
@onready var xp_label: Label = $Info/XPLabel
@onready var objective_label: Label = $Info/ObjectiveLabel

@onready var complete_panel: Panel = $CompletePanel
@onready var complete_title: Label = $CompletePanel/TitleLabel
@onready var complete_text: Label = $CompletePanel/TextLabel
@onready var complete_concept: Label = $CompletePanel/ConceptLabel
@onready var complete_xp: Label = $CompletePanel/XPLabel

@onready var phone_button: Button = $PhoneButton
@onready var message_toast: Panel = $Notification
@onready var message_toast_title: Label = $Notification/TitleLabel
@onready var message_toast_text: Label = $Notification/TextLabel

var _toast_tween: Tween
var _phone_button_x: float = 0.0

var _popup_active: bool = false


func _ready() -> void:
	complete_panel.visible = false
	GameManager.xp_changed.connect(_on_xp_changed)
	MissionManager.mission_started.connect(_on_mission_changed)
	MissionManager.mission_completed.connect(_on_mission_completed)
	PhoneManager.message_received.connect(_on_message_received)
	PhoneManager.unread_changed.connect(_on_unread_changed)
	phone_button.pressed.connect(_on_phone_button_pressed)
	_phone_button_x = phone_button.position.x
	_refresh()


func is_popup_active() -> bool:
	return _popup_active


## Atualiza nível, XP e objetivo (usado ao começar um novo jogo).
func refresh() -> void:
	_refresh()


func _refresh() -> void:
	_update_xp_display()
	_update_objective()
	_on_unread_changed(PhoneManager.unread_count())
	message_toast.visible = false


# --- Celular -----------------------------------------------------------

func _on_unread_changed(count: int) -> void:
	if count > 0:
		phone_button.text = "CELULAR (%d) [TAB]" % count
	else:
		phone_button.text = "CELULAR [TAB]"


func _on_message_received(message: Dictionary) -> void:
	SoundManager.play("interact")
	message_toast_title.text = "Nova mensagem — " + String(message["from"])
	# Só a primeira linha, como a prévia de uma notificação.
	message_toast_text.text = String(message["text"]).get_slice("\n", 0)
	message_toast.visible = true
	message_toast.modulate.a = 1.0

	if _toast_tween:
		_toast_tween.kill()
	phone_button.position.x = _phone_button_x
	_toast_tween = create_tween()
	# "Vibração": o ícone do celular treme para os lados.
	for i in range(6):
		var shake: float = 4.0 if i % 2 == 0 else -4.0
		_toast_tween.tween_property(phone_button, "position:x", _phone_button_x + shake, 0.04)
	_toast_tween.tween_property(phone_button, "position:x", _phone_button_x, 0.04)
	# A notificação some sozinha depois de alguns segundos.
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(message_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func(): message_toast.visible = false)


func _on_phone_button_pressed() -> void:
	if _popup_active or GameMenu.is_active() or DialogueManager.is_active() \
		or TerminalManager.is_active() or ChallengeManager.is_active():
		return
	SoundManager.play("blip")
	# Com mensagem nova, já abre direto no app de Mensagens.
	GameMenu.open("messages" if PhoneManager.unread_count() > 0 else "")


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
