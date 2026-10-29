extends CanvasLayer
## HUD.gd — Autoload
## Interface permanente do jogo, no estilo "painel sci-fi":
##   - canto superior esquerdo: o local atual (prédio ou cidade) e o card
##     MISSÃO ATUAL, com o objetivo e o progresso do capítulo;
##   - canto superior direito (dentro dos prédios): uma aba para cada
##     computador da sala, com o alvo da missão destacado;
##   - canto inferior esquerdo: nível e barra de XP;
##   - canto inferior direito: botão do CELULAR, com contador de mensagens.
## Também mostra a tela de "DESAFIO CONCLUÍDO" com o conceito aprendido
## (parte importante do lado educativo do projeto).

const CyberFrame := preload("res://scripts/ui/CyberFrame.gd")
const CyberIcon := preload("res://scripts/ui/CyberIcon.gd")
const MissionTarget := preload("res://scripts/ui/MissionTarget.gd")
const UiStyle := preload("res://scripts/ui/UiStyle.gd")

## Subtítulo mostrado embaixo do nome de cada prédio.
const LOCATION_SUBTITLES := {
	"TechCorp Ltda.": "Infraestrutura e Tecnologia",
	"DataSoft Sistemas": "Software e Dados",
	"Centro de Tecnologia": "Pesquisa e Segurança",
	"Loja Eletrônica": "Comércio e Aplicações",
}

const TAB_SIZE := Vector2(126, 66)
const TAB_GAP := 8.0
const MAX_TABS := 4

@onready var location_icon: CyberIcon = $Location/Icon
@onready var location_title: Label = $Location/TitleLabel
@onready var location_subtitle: Label = $Location/SubtitleLabel

@onready var mission_header: Label = $Mission/HeaderLabel
@onready var mission_progress_label: Label = $Mission/ProgressLabel
@onready var objective_label: Label = $Mission/ObjectiveLabel
@onready var mission_bar: ProgressBar = $Mission/ProgressBar

@onready var stations: Control = $Stations

@onready var level_label: Label = $Info/LevelLabel
@onready var xp_bar: ProgressBar = $Info/XPBar
@onready var xp_label: Label = $Info/XPLabel

@onready var complete_panel: Control = $CompletePanel
@onready var complete_title: Label = $CompletePanel/TitleLabel
@onready var complete_text: Label = $CompletePanel/TextLabel
@onready var complete_concept: Label = $CompletePanel/ConceptLabel
@onready var complete_xp: Label = $CompletePanel/XPLabel

@onready var phone_button: Button = $PhoneButton
@onready var phone_badge: Label = $PhoneButton/Badge
@onready var message_toast: Control = $Notification
@onready var message_toast_title: Label = $Notification/TitleLabel
@onready var message_toast_text: Label = $Notification/TextLabel

var _toast_tween: Tween
var _phone_button_x: float = 0.0

var _popup_active: bool = false

## Cena atual da última vez que o HUD olhou (para saber quando o jogador
## entrou ou saiu de um prédio).
var _last_scene: Node = null
## Aba de cada computador da sala: computador -> moldura da aba.
var _tab_frames: Dictionary = {}


func _ready() -> void:
	complete_panel.visible = false
	GameManager.xp_changed.connect(_on_xp_changed)
	MissionManager.mission_started.connect(_on_mission_changed)
	MissionManager.mission_completed.connect(_on_mission_completed)
	CampaignManager.chapter_unlocked.connect(_on_mission_changed)
	PhoneManager.message_received.connect(_on_message_received)
	PhoneManager.unread_changed.connect(_on_unread_changed)
	phone_button.pressed.connect(_on_phone_button_pressed)
	_phone_button_x = phone_button.position.x
	_add_mission_arrow()
	_refresh()


## A seta que aponta para a missão (liberada pelo nível, ver MissionArrow.gd)
## é criada por código, sem mexer na cena do HUD.
func _add_mission_arrow() -> void:
	var arrow := Control.new()
	arrow.name = "MissionArrow"
	arrow.set_script(preload("res://scripts/ui/MissionArrow.gd"))
	add_child(arrow)


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


func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene != _last_scene:
		_last_scene = scene
		_on_scene_changed.call_deferred()


# --- Local atual e abas dos computadores ---------------------------------

func _on_scene_changed() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var path: String = scene.scene_file_path
	if path.contains("/interiors/"):
		var title: String = SceneTransition.interior_title
		location_title.text = title.to_upper() if title != "" else "INTERIOR"
		if LOCATION_SUBTITLES.has(title):
			location_subtitle.text = LOCATION_SUBTITLES[title]
		elif title.begins_with("Casa"):
			location_subtitle.text = "Residência"
		else:
			location_subtitle.text = "Interior"
		location_icon.kind = CyberIcon.Kind.BUILDING
	else:
		location_title.text = "CYBER CITY"
		location_subtitle.text = "Centro da cidade"
		location_icon.kind = CyberIcon.Kind.CITY
	# Espera um quadro: o interior pode remover computadores ao carregar.
	await get_tree().process_frame
	_build_station_tabs()


func _build_station_tabs() -> void:
	for child in stations.get_children():
		child.queue_free()
	_tab_frames.clear()

	var scene: Node = get_tree().current_scene
	if scene == null or not scene.scene_file_path.contains("/interiors/"):
		return

	var computers: Array[Node2D] = []
	for area in scene.find_children("*", "Area2D", true, false):
		if computers.size() >= MAX_TABS:
			break
		if "challenge_id" in area and not area.is_queued_for_deletion():
			computers.append(area as Node2D)

	var count := computers.size()
	for i in count:
		var computer: Node2D = computers[i]
		var tab := Control.new()
		# Clicável: o personagem anda sozinho até este computador.
		tab.mouse_filter = Control.MOUSE_FILTER_STOP
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab.tooltip_text = "Clique para ir até " + _computer_name(computer)
		tab.size = TAB_SIZE
		tab.position = Vector2(-(count - i) * (TAB_SIZE.x + TAB_GAP) + TAB_GAP, 0)
		stations.add_child(tab)

		var frame: CyberFrame = CyberFrame.new()
		frame.cut_top_left = 10.0
		frame.cut_bottom_right = 10.0
		frame.accents = false
		frame.dots = 0
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		tab.add_child(frame)

		var name_text := _computer_name(computer)
		var icon: CyberIcon = CyberIcon.new()
		icon.kind = CyberIcon.Kind.SERVER if _looks_like_server(name_text) else CyberIcon.Kind.MONITOR
		icon.position = Vector2((TAB_SIZE.x - 30.0) * 0.5, 8)
		icon.size = Vector2(30, 28)
		tab.add_child(icon)

		var label := Label.new()
		label.theme_type_variation = &"HudText"
		label.text = name_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.position = Vector2(4, 38)
		label.size = Vector2(TAB_SIZE.x - 8.0, 20)
		tab.add_child(label)

		tab.gui_input.connect(_on_tab_gui_input.bind(computer))
		tab.mouse_entered.connect(func() -> void: tab.modulate = Color(1.3, 1.3, 1.3))
		tab.mouse_exited.connect(func() -> void: tab.modulate = Color.WHITE)

		_tab_frames[computer] = frame
	_update_tab_highlight()


func _on_tab_gui_input(event: InputEvent, computer: Node2D) -> void:
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	get_viewport().set_input_as_handled()
	if _popup_active or GameMenu.is_active() or DialogueManager.is_active() \
		or TerminalManager.is_active() or ChallengeManager.is_active():
		return
	if not is_instance_valid(computer):
		return
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("walk_to"):
		SoundManager.play("blip")
		player.walk_to(computer)


func _computer_name(computer: Node) -> String:
	var name_label: Label = computer.get_node_or_null("NameLabel")
	if name_label == null or name_label.text.strip_edges() == "":
		return "Computador"
	return UiStyle.clean_name(name_label.text)


func _looks_like_server(text: String) -> bool:
	var t := text.to_lower()
	return t.contains("servidor") or t.contains("firewall") or t.contains("registro")


## Acende a aba do computador onde está a missão atual.
func _update_tab_highlight() -> void:
	if _tab_frames.is_empty():
		return
	var target: Node = MissionTarget.find_target(get_tree().current_scene, MissionTarget.mission_to_guide())
	for computer in _tab_frames.keys():
		var frame: CyberFrame = _tab_frames[computer]
		if is_instance_valid(frame):
			frame.highlighted = computer == target


# --- Celular -----------------------------------------------------------

func _on_unread_changed(count: int) -> void:
	phone_badge.visible = count > 0
	phone_badge.text = str(count) if count < 10 else "9+"


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


# --- Nível, XP e missão ----------------------------------------------------

func _on_xp_changed(_current_xp: int, _xp_to_next: int, _level: int) -> void:
	_update_xp_display()


func _update_xp_display() -> void:
	level_label.text = "NÍVEL %d" % GameManager.level
	var to_next: int = GameManager.xp_to_next_level()
	xp_bar.max_value = to_next
	xp_bar.value = GameManager.xp
	xp_label.text = "XP %d / %d" % [GameManager.xp, to_next]


## Capítulo em andamento (o primeiro com missão "do capítulo atual").
func _current_chapter() -> Dictionary:
	for chapter_id in CampaignManager.chapters.keys():
		var chapter: Dictionary = CampaignManager.chapters[chapter_id]
		for mission_id in chapter["missions"]:
			if CampaignManager.is_mission_in_current_chapter(String(mission_id)):
				return chapter
	return {}


func _update_objective() -> void:
	var mission: Dictionary = MissionManager.get_active_mission()
	var chapter: Dictionary = _current_chapter()

	# Progresso = missões concluídas do capítulo atual.
	var done := 0
	var total := 0
	if not chapter.is_empty():
		for mission_id in chapter["missions"]:
			total += 1
			if MissionManager.is_completed(String(mission_id)):
				done += 1
	mission_progress_label.text = "%d/%d" % [done, total] if total > 0 else ""
	mission_bar.max_value = maxi(total, 1)
	mission_bar.value = done

	if not mission.is_empty():
		mission_header.text = "MISSÃO ATUAL"
		objective_label.text = String(mission["objective"])
	elif total > done:
		mission_header.text = "PRÓXIMA MISSÃO"
		objective_label.text = "Converse com quem tem o ! para receber a missão."
	else:
		mission_header.text = "MISSÃO ATUAL"
		objective_label.text = "Nenhuma missão no momento."
	_update_tab_highlight()


func _on_mission_changed(_id: String) -> void:
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
	# Desafios mostram também o rank e o bônus de XP (ver ChallengeSession).
	var result: Dictionary = ChallengeSession.last_result
	if String(result.get("mission_id", "")) == mission_id:
		var bonus: int = int(result.get("bonus_xp", 0))
		var bonus_text: String = "  +%d bônus" % bonus if bonus > 0 else ""
		complete_xp.text = "+%d XP%s  ·  RANK %s" % [int(mission["xp"]), bonus_text, String(result.get("rank", ""))]

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
