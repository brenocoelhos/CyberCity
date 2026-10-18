extends CanvasLayer
## GameMenu.gd — Autoload
## O CELULAR do jogador ("Cyber Phone"), aberto com TAB ou ESC ou
## clicando no ícone do celular no HUD. Também funciona como pausa.
##
## Tela inicial com apps:
##   Mensagens — recados que chegam com a história (PhoneManager)
##   Pistas    — pistas das missões em andamento, liberadas aos poucos
##   Missões   — lista de missões e seus estados
##   Perfil    — nível, XP e conhecimentos
##   Ajustes   — opções (volume/tela), menu principal e sair
##
## O conteúdo de cada app é montado por código dentro de AppView/Scroll/List.

const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const CITY_SCENE := "res://scenes/world/City.tscn"

const COLOR_TITLE := Color(0.3, 0.95, 1.0)
const COLOR_DIM := Color(0.65, 0.7, 0.8)
const COLOR_UNREAD := Color(1.0, 0.8, 0.3)

@onready var phone: Panel = $Phone
@onready var clock_label: Label = $Phone/StatusBar/ClockLabel
@onready var home: Control = $Phone/Screen/Home
@onready var messages_button: Button = $Phone/Screen/Home/Apps/MessagesButton
@onready var clues_button: Button = $Phone/Screen/Home/Apps/CluesButton
@onready var missions_button: Button = $Phone/Screen/Home/Apps/MissionsButton
@onready var profile_button: Button = $Phone/Screen/Home/Apps/ProfileButton
@onready var settings_button: Button = $Phone/Screen/Home/Apps/SettingsButton
@onready var close_button: Button = $Phone/Screen/Home/Apps/CloseButton
@onready var app_view: Control = $Phone/Screen/AppView
@onready var back_button: Button = $Phone/Screen/AppView/Header/BackButton
@onready var app_title: Label = $Phone/Screen/AppView/Header/AppTitle
@onready var scroll: ScrollContainer = $Phone/Screen/AppView/Scroll
@onready var list: VBoxContainer = $Phone/Screen/AppView/Scroll/List
@onready var options_panel: Panel = $OptionsPanel

var _active: bool = false
## App aberto no momento ("" = tela inicial).
var _current_app: String = ""


func _ready() -> void:
	phone.visible = false

	messages_button.pressed.connect(_open_app.bind("messages"))
	clues_button.pressed.connect(_open_app.bind("clues"))
	missions_button.pressed.connect(_open_app.bind("missions"))
	profile_button.pressed.connect(_open_app.bind("profile"))
	settings_button.pressed.connect(_open_app.bind("settings"))
	close_button.pressed.connect(toggle)
	back_button.pressed.connect(_on_back_pressed)
	options_panel.closed.connect(_on_options_closed)

	PhoneManager.unread_changed.connect(func(_count: int): _update_home_labels())
	PhoneManager.clue_revealed.connect(func(_id: String): _update_home_labels())


func is_active() -> bool:
	return _active


func toggle() -> void:
	SoundManager.play("blip")
	if _active:
		close()
	else:
		open()


## Abre o celular. Se "app" for passado (ex.: "messages"), já abre nele.
func open(app: String = "") -> void:
	_active = true
	phone.visible = true
	_update_clock()
	if app == "":
		_show_home()
	else:
		_open_app(app)


func close() -> void:
	_active = false
	phone.visible = false
	options_panel.visible = false
	_current_app = ""


func _process(_delta: float) -> void:
	if _active:
		_update_clock()


func _update_clock() -> void:
	clock_label.text = Time.get_time_string_from_system().substr(0, 5)


# --- Tela inicial ------------------------------------------------------

func _show_home() -> void:
	_current_app = ""
	app_view.visible = false
	home.visible = true
	_update_home_labels()
	messages_button.grab_focus()


func _update_home_labels() -> void:
	var unread: int = PhoneManager.unread_count()
	messages_button.text = "Mensagens\n(%d nova%s)" % [unread, "" if unread == 1 else "s"] if unread > 0 else "Mensagens"

	var active_count: int = _active_missions().size()
	if active_count == 0:
		clues_button.text = "Pistas"
	elif active_count == 1:
		clues_button.text = "Pistas\n(1 missão)"
	else:
		clues_button.text = "Pistas\n(%d missões)" % active_count


func _on_back_pressed() -> void:
	SoundManager.play("blip")
	_show_home()


# --- Apps --------------------------------------------------------------

func _open_app(app: String) -> void:
	SoundManager.play("blip")
	_current_app = app
	home.visible = false
	app_view.visible = true
	_render_current_app()
	scroll.scroll_vertical = 0
	_focus_first_button()


func _render_current_app() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()

	match _current_app:
		"messages":
			app_title.text = "MENSAGENS"
			_render_messages()
		"clues":
			app_title.text = "PISTAS"
			_render_clues()
		"missions":
			app_title.text = "MISSÕES"
			_render_missions()
		"profile":
			app_title.text = "PERFIL"
			_render_profile()
		"settings":
			app_title.text = "AJUSTES"
			_render_settings()


func _render_messages() -> void:
	if PhoneManager.messages.is_empty():
		_add_label("Nenhuma mensagem ainda.", COLOR_DIM)
		return

	# Mais nova primeiro, como num celular de verdade.
	for i in range(PhoneManager.messages.size() - 1, -1, -1):
		var message: Dictionary = PhoneManager.messages[i]
		var unread: bool = not message["read"]
		_add_label(("● " if unread else "") + String(message["from"]), COLOR_UNREAD if unread else COLOR_TITLE)
		_add_label(String(message["text"]))
		list.add_child(HSeparator.new())

	PhoneManager.mark_all_read()


func _render_clues() -> void:
	var active: Array = _active_missions()
	if active.is_empty():
		_add_label("Nenhuma missão em andamento.", COLOR_DIM)
		_add_label("Converse com os moradores e use os computadores da cidade para aceitar uma missão. As pistas aparecem aqui.", COLOR_DIM)
		return

	for mission in active:
		var mission_id: String = String(mission["id"])
		_add_label(String(mission["title"]), COLOR_TITLE)
		_add_label("Objetivo: " + String(mission["objective"]), COLOR_DIM)

		var clues: PackedStringArray = PhoneManager.get_revealed_clues(mission_id)
		for i in range(clues.size()):
			_add_label("Pista %d: %s" % [i + 1, clues[i]])

		if PhoneManager.has_more_clues(mission_id):
			_add_button("Revelar próxima pista", _on_reveal_clue.bind(mission_id))
		else:
			_add_label("(todas as pistas já foram reveladas)", COLOR_DIM)
		list.add_child(HSeparator.new())


func _on_reveal_clue(mission_id: String) -> void:
	SoundManager.play("interact")
	PhoneManager.reveal_next_clue(mission_id)
	var old_scroll: int = scroll.scroll_vertical
	_render_current_app()
	scroll.scroll_vertical = old_scroll
	_focus_first_button()


func _render_missions() -> void:
	for mission in MissionManager.missions.values():
		var state: int = mission["state"]
		var color: Color = COLOR_TITLE if state == MissionManager.State.ACTIVE else Color.WHITE
		_add_label("[%s] %s" % [MissionManager.state_to_text(state), String(mission["title"])], color)
		_add_label(String(mission["description"]))
		_add_label("Local: %s\nDificuldade: %s · Recompensa: %d XP" % [
			String(mission["location"]),
			String(mission["difficulty"]),
			int(mission["xp"]),
		], COLOR_DIM)
		list.add_child(HSeparator.new())


func _render_profile() -> void:
	if CampaignManager.is_game_completed:
		_add_label("CASO ENCERRADO — todas as missões concluídas!", COLOR_UNREAD)

	_add_label("HACKER", COLOR_TITLE)
	_add_label("Nível: %d" % GameManager.level)

	var bar := ProgressBar.new()
	bar.max_value = GameManager.xp_to_next_level()
	bar.value = GameManager.xp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	list.add_child(bar)
	_add_label("XP: %d/%d   (total: %d)" % [GameManager.xp, GameManager.xp_to_next_level(), GameManager.total_xp_earned], COLOR_DIM)

	list.add_child(HSeparator.new())
	_add_label("CONHECIMENTOS", COLOR_TITLE)
	if GameManager.knowledge.is_empty():
		_add_label("Nenhum conceito aprendido ainda — complete uma missão.", COLOR_DIM)
		return
	for concept in GameManager.knowledge.keys():
		var reinforced: int = int(GameManager.knowledge[concept])
		_add_label("%s  %s" % [String(concept), "■".repeat(mini(reinforced, 5)) + "□".repeat(maxi(0, 5 - reinforced))])


func _render_settings() -> void:
	_add_button("Volume e tela", _on_options_pressed)
	# A seta de missão é liberada pelo nível; depois dela dá para desligar.
	if GameManager.is_tool_unlocked("mission_arrow"):
		_add_button("Seta de missão: %s" % ("ligada" if Settings.mission_arrow else "desligada"), _on_arrow_toggled)
	else:
		_add_label("Seta de missão: libera no nível %d" % int(GameManager.TOOL_UNLOCK_LEVELS["mission_arrow"]), COLOR_DIM)
	_add_button("Menu principal", _on_main_menu_pressed)
	# No navegador (exportação Web) não existe "fechar o jogo".
	if not OS.has_feature("web"):
		_add_button("Sair do jogo", _on_quit_pressed)


# --- Ajustes -----------------------------------------------------------

func _on_arrow_toggled() -> void:
	SoundManager.play("blip")
	Settings.set_mission_arrow(not Settings.mission_arrow)
	_render_current_app()
	_focus_first_button()


func _on_options_pressed() -> void:
	SoundManager.play("blip")
	phone.visible = false
	options_panel.open()


func _on_options_closed() -> void:
	if not _active:
		return
	phone.visible = true
	_focus_first_button()


## Volta para a tela inicial, guardando onde o jogador estava para o
## botão "Continuar" do menu principal.
func _on_main_menu_pressed() -> void:
	SoundManager.play("blip")
	var scene: Node = get_tree().current_scene
	GameManager.resume_scene_path = scene.scene_file_path
	if scene.scene_file_path == CITY_SCENE:
		var player: Node2D = scene.get_node_or_null("Player")
		if player:
			SceneTransition.return_spawn_position = player.global_position
			SceneTransition.has_pending_spawn = true

	close()
	SceneTransition.change_scene(MAIN_MENU_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()


# --- Ajudantes ---------------------------------------------------------

func _active_missions() -> Array:
	var result: Array = []
	for mission in MissionManager.missions.values():
		if mission["state"] == MissionManager.State.ACTIVE:
			result.append(mission)
	return result


func _add_label(text: String, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 14)
	list.add_child(label)


func _add_button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 36)
	button.pressed.connect(callback)
	list.add_child(button)


func _focus_first_button() -> void:
	for child in list.get_children():
		if child is Button:
			child.grab_focus()
			return
	back_button.grab_focus()


# --- Teclado -----------------------------------------------------------

func _input(event: InputEvent) -> void:
	# Com o celular aberto, o teclado é tratado aqui em _input: senão um
	# botão com foco "comeria" o TAB (que no Godot troca o foco).
	if not _active or options_panel.visible:
		return
	if app_view.visible and event.is_action_pressed("ui_cancel"):
		# ESC dentro de um app volta para a tela inicial do celular.
		_on_back_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_menu"):
		toggle()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# Na tela inicial do jogo o celular não abre.
	var scene: Node = get_tree().current_scene
	if scene and scene.scene_file_path == MAIN_MENU_SCENE:
		return

	# O celular não deve abrir por cima do terminal, de um diálogo ou da
	# tela de missão concluída (todos eles já usam ESC/E).
	if TerminalManager.is_active() or DialogueManager.is_active() \
		or ChallengeManager.is_active() or HUD.is_popup_active():
		return

	if event.is_action_pressed("open_menu"):
		toggle()
		get_viewport().set_input_as_handled()
