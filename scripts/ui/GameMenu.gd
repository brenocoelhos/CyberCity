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

const StudyTools := preload("res://scripts/systems/StudyTools.gd")

## Missão que precisa estar concluída para o decifrador de César abrir (para
## não entregar a resposta da m04).
const CAESAR_REQUIRES_MISSION := "m04"

const CyberIcon := preload("res://scripts/ui/CyberIcon.gd")
const DesktopWindowScript := preload("res://scripts/desktop/DesktopWindow.gd")

## Cores no estilo do iOS (modo escuro).
const COLOR_TITLE := Color(0.39, 0.7, 1.0)
const COLOR_DIM := Color(0.6, 0.6, 0.64)
const COLOR_UNREAD := Color(1.0, 0.62, 0.04)
const IOS_BLUE := Color(0.04, 0.52, 1.0)
const IOS_RED := Color(1.0, 0.23, 0.19)
const IOS_CELL := Color(0.11, 0.11, 0.12)
const IOS_CELL_HI := Color(0.19, 0.19, 0.21)

## Tamanho do aparelho na tela e das partes dele (em pixels).
const PHONE_RECT := Rect2(475, 8, 330, 704)
const SCREEN_INSET := 9.0

## Cada app: cor do ícone e desenho (ver CyberIcon.gd).
const APP_STYLE := {
	"MessagesButton": [Color(0.2, 0.78, 0.35), "Mensagens", CyberIcon.Kind.CHAT],
	"CluesButton": [Color(1.0, 0.58, 0.0), "Pistas", CyberIcon.Kind.MAGNIFIER],
	"MissionsButton": [Color(1.0, 0.23, 0.19), "Missões", CyberIcon.Kind.MISSION],
	"ProfileButton": [Color(0.04, 0.52, 1.0), "Perfil", CyberIcon.Kind.PERSON],
	"SettingsButton": [Color(0.5, 0.5, 0.53), "Ajustes", CyberIcon.Kind.GEAR],
	"NotesButton": [Color(1.0, 0.78, 0.0), "Notas", CyberIcon.Kind.NOTE],
	"ToolsButton": [Color(0.19, 0.69, 0.78), "Ferramentas", CyberIcon.Kind.WRENCH],
	"CloseButton": [Color(0.2, 0.2, 0.22), "Fechar", CyberIcon.Kind.POWER],
}

@onready var phone: Panel = $Phone
@onready var clock_label: Label = $Phone/StatusBar/ClockLabel
@onready var home: Control = $Phone/Screen/Home
@onready var messages_button: Button = $Phone/Screen/Home/Apps/MessagesButton
@onready var clues_button: Button = $Phone/Screen/Home/Apps/CluesButton
@onready var missions_button: Button = $Phone/Screen/Home/Apps/MissionsButton
@onready var profile_button: Button = $Phone/Screen/Home/Apps/ProfileButton
@onready var settings_button: Button = $Phone/Screen/Home/Apps/SettingsButton
@onready var close_button: Button = $Phone/Screen/Home/Apps/CloseButton
@onready var apps_grid: GridContainer = $Phone/Screen/Home/Apps
@onready var app_view: Control = $Phone/Screen/AppView
@onready var back_button: Button = $Phone/Screen/AppView/Header/BackButton
@onready var app_title: Label = $Phone/Screen/AppView/Header/AppTitle
@onready var scroll: ScrollContainer = $Phone/Screen/AppView/Scroll
@onready var list: VBoxContainer = $Phone/Screen/AppView/Scroll/List
@onready var options_panel: Panel = $OptionsPanel

var _active: bool = false
## App aberto no momento ("" = tela inicial).
var _current_app: String = ""

## Botão do app "Ferramentas": criado por código (copiando o estilo dos outros
## botões) e só aparece depois que o nível libera a ferramenta.
var tools_button: Button

## Botão do app "Notas" (bloco de notas do jogador), também criado por código.
## Está sempre disponível. "_notes_dirty" avisa que o texto mudou desde o
## último save, para gravar ao sair do app.
var notes_button: Button
var _notes_dirty: bool = false
var _stopwatch_label: Label


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

	_setup_tools_button()
	_setup_notes_button()
	_setup_stopwatch()
	_apply_iphone_look()
	GameManager.tool_unlocked.connect(func(_id: String): _update_home_labels())

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
	_save_notes_if_changed()
	_active = false
	phone.visible = false
	options_panel.visible = false
	_current_app = ""


func _process(_delta: float) -> void:
	if _active:
		_update_clock()


func _update_clock() -> void:
	clock_label.text = Time.get_time_string_from_system().substr(0, 5)
	if _stopwatch_label != null:
		_stopwatch_label.text = "TEMPO " + Leaderboard.format_clock(Leaderboard.elapsed_msec())


## Cronômetro da partida, na barra de cima do celular (é o tempo que vai para o
## placar). O relógio da hora fica na direita.
func _setup_stopwatch() -> void:
	# Fica no widget da tela inicial (montado em _apply_iphone_look).
	_stopwatch_label = Label.new()
	_stopwatch_label.add_theme_font_size_override("font_size", 26)
	_stopwatch_label.tooltip_text = "Tempo de jogo: é o que vale no placar"


# --- Tela inicial ------------------------------------------------------

func _show_home() -> void:
	_save_notes_if_changed()
	_current_app = ""
	app_view.visible = false
	home.visible = true
	_wallpaper.visible = true
	_update_home_labels()
	messages_button.grab_focus()


func _setup_tools_button() -> void:
	# duplicate(0): copia o visual do botão de Perfil sem copiar as conexões.
	tools_button = profile_button.duplicate(0) as Button
	tools_button.name = "ToolsButton"
	tools_button.text = "Ferramentas"
	tools_button.pressed.connect(_open_app.bind("tools"))
	apps_grid.add_child(tools_button)
	apps_grid.move_child(tools_button, close_button.get_index())
	tools_button.visible = GameManager.is_tool_unlocked("phone_tools")


func _setup_notes_button() -> void:
	notes_button = profile_button.duplicate(0) as Button
	notes_button.name = "NotesButton"
	notes_button.text = "Notas"
	notes_button.pressed.connect(_open_app.bind("notes"))
	apps_grid.add_child(notes_button)
	apps_grid.move_child(notes_button, close_button.get_index())


## Grava o jogo (sem aviso na tela) quando o jogador sai do app Notas depois
## de escrever, para as anotações não se perderem se ele fechar o jogo.
func _save_notes_if_changed() -> void:
	if not _notes_dirty:
		return
	_notes_dirty = false
	if SaveManager.can_save():
		SaveManager.save_game("notes")


func _update_home_labels() -> void:
	tools_button.visible = GameManager.is_tool_unlocked("phone_tools")
	# Como no iPhone: o número aparece numa bolinha vermelha no canto do ícone.
	_set_badge(messages_button, PhoneManager.unread_count())
	_set_badge(clues_button, _active_missions().size())
	if _widget_name != null:
		var who: String = Leaderboard.player_name if Leaderboard.player_name != "" else "Agente"
		_widget_name.text = "AGENTE " + who.to_upper()
		_widget_level.text = "Nível %d · %d/%d XP" % [GameManager.level, GameManager.xp, GameManager.xp_to_next_level()]


func _on_back_pressed() -> void:
	SoundManager.play("blip")
	# Dentro de uma conversa, voltar leva para a lista de conversas.
	if _current_app == "messages" and _chat_with != "":
		_chat_with = ""
		_render_current_app()
		_focus_first_button()
		return
	_show_home()


# --- Apps --------------------------------------------------------------
# Cada app imita um app de verdade: Mensagens (WhatsApp), Notas (Bloco de
# Notas), Missões (Lembretes), Pistas (Google Keep), Perfil e Ajustes (iOS).
# Tudo é montado dentro de "list" (a lista que rola); o topo e o fundo de cada
# app ("chrome") mudam conforme o app, em _set_chrome().

## Conversa aberta no app Mensagens ("" = lista de conversas).
var _chat_with: String = ""
var _app_bg: Panel
var _app_top: Control
var _app_bottom: Control

const WA_BG := Color("#0b141a")
const WA_BAR := Color("#1f2c34")
const WA_BUBBLE := Color("#202c33")
const WA_GREEN := Color("#00a884")
const WA_TEXT := Color("#e9edef")
const WA_DIM := Color("#8696a0")
const NP_BG := Color("#1c1c1c")
const NP_BAR := Color("#2b2b2b")
const AVATAR_COLORS := [Color("#25a3a3"), Color("#d9534f"), Color("#7e57c2"), Color("#f0a030"), Color("#3b82f6"), Color("#22a06b"), Color("#d6448b")]


func _open_app(app: String) -> void:
	SoundManager.play("blip")
	_current_app = app
	_chat_with = ""
	home.visible = false
	_wallpaper.visible = false
	app_view.visible = true
	_render_current_app()
	scroll.scroll_vertical = 0
	_focus_first_button()


func _render_current_app() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for holder in [_app_top, _app_bottom]:
		for child in holder.get_children():
			holder.remove_child(child)
			child.queue_free()

	match _current_app:
		"messages":
			app_title.text = "Mensagens"
			_render_messages()
		"clues":
			app_title.text = "Pistas"
			_set_chrome("ios", Color("#0d0d0f"))
			_render_clues()
		"missions":
			app_title.text = "Missões"
			_set_chrome("ios", Color.BLACK)
			_render_missions()
		"profile":
			app_title.text = "Perfil"
			_set_chrome("ios", Color.BLACK)
			_render_profile()
		"tools":
			app_title.text = "Ferramentas"
			_set_chrome("ios", Color.BLACK)
			_render_tools()
		"notes":
			app_title.text = "Notas"
			_render_notes()
		"settings":
			app_title.text = "Ajustes"
			_set_chrome("ios", Color.BLACK)
			_render_settings()


## Topo e fundo do app. "ios": "‹ Início" e título grande. "custom": o app
## monta a própria barra de cima em _app_top (altura top_h) e de baixo em
## _app_bottom (altura bottom_h).
func _set_chrome(mode: String, background: Color, top_h: float = 0.0, bottom_h: float = 0.0) -> void:
	var screen_size: Vector2 = $Phone/Screen.size
	_app_bg.add_theme_stylebox_override("panel", _box(background, 0))
	var ios: bool = mode == "ios"
	$Phone/Screen/AppView/Header.visible = ios
	app_title.visible = ios
	_app_top.size = Vector2(screen_size.x, top_h)
	_app_bottom.position = Vector2(0, screen_size.y - bottom_h)
	_app_bottom.size = Vector2(screen_size.x, bottom_h)
	if ios:
		scroll.position = Vector2(14, 126)
		scroll.size = Vector2(screen_size.x - 28, screen_size.y - 152)
	else:
		scroll.position = Vector2(0, top_h)
		scroll.size = Vector2(screen_size.x, screen_size.y - top_h - bottom_h)


## Barra colorida de cima (cobre a área da hora, como nos apps de verdade).
func _top_bar(color: Color, height: float) -> Panel:
	var bar := Panel.new()
	bar.add_theme_stylebox_override("panel", _box(color, 0))
	bar.size = Vector2($Phone/Screen.size.x, height)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_app_top.add_child(bar)
	return bar


func _flat_button(text: String, color: Color, font_size: int, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color.lightened(0.25))
	button.add_theme_color_override("font_focus_color", color.lightened(0.25))
	button.add_theme_font_size_override("font_size", font_size)
	var focus := _box(Color(1, 1, 1, 0.1), 8, 4, 0)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("hover", focus)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", focus)
	button.pressed.connect(callback)
	return button


func _text(parent: Node, text: String, color: Color, font_size: int, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if bold:
		label.add_theme_font_override("font", _bold_font)
	parent.add_child(label)
	return label


## Círculo com as iniciais (foto de perfil), cor fixa por nome.
func _avatar(name_text: String, diameter: float) -> Panel:
	var circle := Panel.new()
	var color: Color = AVATAR_COLORS[absi(name_text.hash()) % AVATAR_COLORS.size()]
	circle.add_theme_stylebox_override("panel", _box(color, int(diameter / 2.0)))
	circle.custom_minimum_size = Vector2(diameter, diameter)
	circle.size = Vector2(diameter, diameter)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var initials := ""
	for word in name_text.replace("(", "").replace(")", "").split(" ", false):
		if initials.length() < 2 and word.length() > 0 and word[0] == word[0].to_upper():
			initials += word[0]
	var label := _text(circle, initials if initials != "" else "?", Color.WHITE, int(diameter * 0.38), true)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return circle


func _spacer(height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	list.add_child(gap)


# --- Mensagens (estilo WhatsApp) ----------------------------------------------

func _render_messages() -> void:
	if _chat_with == "":
		_render_chat_list()
	else:
		_render_chat()


## Lista de conversas: uma por contato, com a última mensagem, a hora e a
## bolinha verde de não lidas.
func _render_chat_list() -> void:
	_set_chrome("custom", WA_BG, 116, 0)
	var bar := _top_bar(WA_BG, 116)
	var back := _flat_button("‹", WA_TEXT, 26, _on_back_pressed)
	back.position = Vector2(6, 48)
	_app_top.add_child(back)
	var title := _text(bar, "Mensagens", WA_TEXT, 22, true)
	title.position = Vector2(36, 50)
	var search := Panel.new()
	search.add_theme_stylebox_override("panel", _box(Color("#202c33"), 18))
	search.position = Vector2(14, 82)
	search.size = Vector2(bar.size.x - 28, 30)
	bar.add_child(search)
	var hint := _text(search, "Pesquisar", WA_DIM, 13)
	hint.position = Vector2(34, 5)
	var glass := CyberIcon.new()
	glass.kind = CyberIcon.Kind.MAGNIFIER
	glass.color = WA_DIM
	glass.line_width = 1.5
	glass.position = Vector2(10, 7)
	glass.size = Vector2(16, 16)
	search.add_child(glass)

	if PhoneManager.messages.is_empty():
		_spacer(20)
		var empty := _text(list, "Nenhuma conversa ainda.", WA_DIM, 14)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return

	# Contatos na ordem da mensagem mais recente.
	var order: Array = []
	for i in range(PhoneManager.messages.size() - 1, -1, -1):
		var sender: String = String(PhoneManager.messages[i]["from"])
		if not order.has(sender):
			order.append(sender)
	for sender in order:
		var last: Dictionary = {}
		var unread := 0
		for message in PhoneManager.messages:
			if String(message["from"]) == sender:
				last = message
				if not message["read"]:
					unread += 1
		list.add_child(_chat_row(sender, last, unread))


func _chat_row(sender: String, last: Dictionary, unread: int) -> Button:
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 72)
	row.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	row.add_theme_stylebox_override("hover", _box(Color("#202c33"), 0))
	row.add_theme_stylebox_override("focus", _box(Color("#202c33"), 0))
	row.add_theme_stylebox_override("pressed", _box(Color("#2a3942"), 0))
	row.pressed.connect(func() -> void:
		SoundManager.play("blip")
		_chat_with = sender
		_render_current_app()
		_focus_first_button())
	var width: float = $Phone/Screen.size.x
	var avatar := _avatar(sender, 48)
	avatar.position = Vector2(14, 12)
	row.add_child(avatar)
	var name_label := _text(row, sender, WA_TEXT, 15, true)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.position = Vector2(74, 14)
	name_label.size = Vector2(width - 140, 20)
	var preview := _text(row, String(last.get("text", "")).get_slice("\n", 0), WA_DIM, 13)
	preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	preview.position = Vector2(74, 38)
	preview.size = Vector2(width - 118, 20)
	var time := _text(row, String(last.get("time", "")), WA_GREEN if unread > 0 else WA_DIM, 11)
	time.position = Vector2(width - 56, 16)
	time.size = Vector2(44, 16)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if unread > 0:
		var badge := _text(row, str(unread), Color("#0b141a"), 11, true)
		badge.add_theme_stylebox_override("normal", _box(Color("#25d366"), 10))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.position = Vector2(width - 34, 38)
		badge.size = Vector2(20, 20)
	for child in row.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


## Conversa com um contato: barra verde-escura com foto e nome, balões cinza
## com a hora no canto e a barra "Mensagem" embaixo (só enfeite: o jogador
## não responde por aqui).
func _render_chat() -> void:
	_set_chrome("custom", WA_BG, 100, 64)
	var bar := _top_bar(WA_BAR, 100)
	var back := _flat_button("‹", WA_TEXT, 28, _on_back_pressed)
	back.position = Vector2(4, 50)
	_app_top.add_child(back)
	var avatar := _avatar(_chat_with, 38)
	avatar.position = Vector2(34, 52)
	bar.add_child(avatar)
	var name_label := _text(bar, _chat_with, WA_TEXT, 15, true)
	name_label.position = Vector2(80, 52)
	name_label.size = Vector2(bar.size.x - 96, 20)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_text(bar, "online", WA_DIM, 12).position = Vector2(80, 72)

	_spacer(10)
	var chip_row := CenterContainer.new()
	var chip := _text(chip_row, "HOJE", WA_DIM, 11, true)
	chip.add_theme_stylebox_override("normal", _box(Color("#182229"), 7, 10, 3))
	list.add_child(chip_row)
	for message in PhoneManager.messages:
		if String(message["from"]) != _chat_with:
			continue
		var line := MarginContainer.new()
		line.add_theme_constant_override("margin_left", 10)
		line.add_theme_constant_override("margin_right", 46)
		line.add_theme_constant_override("margin_top", 3)
		line.add_theme_constant_override("margin_bottom", 3)
		var bubble := PanelContainer.new()
		var bubble_style := _box(WA_BUBBLE, 10, 10, 6)
		bubble_style.corner_radius_top_left = 0
		bubble.add_theme_stylebox_override("panel", bubble_style)
		bubble.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 0)
		var text := _text(column, String(message["text"]), WA_TEXT, 14)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(200, 0)
		var time := _text(column, String(message.get("time", "")), WA_DIM, 10)
		time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bubble.add_child(column)
		line.add_child(bubble)
		list.add_child(line)
	_spacer(8)
	PhoneManager.mark_all_read()

	# Barra de digitar (enfeite)
	var input := Panel.new()
	input.add_theme_stylebox_override("panel", _box(Color("#2a3942"), 20))
	input.position = Vector2(8, 10)
	input.size = Vector2(_app_bottom.size.x - 66, 40)
	_app_bottom.add_child(input)
	_text(input, "Mensagem", WA_DIM, 14).position = Vector2(16, 10)
	var mic := Panel.new()
	mic.add_theme_stylebox_override("panel", _box(WA_GREEN, 20))
	mic.position = Vector2(_app_bottom.size.x - 52, 10)
	mic.size = Vector2(40, 40)
	_app_bottom.add_child(mic)
	var mic_icon := CyberIcon.new()
	mic_icon.kind = CyberIcon.Kind.CHAT
	mic_icon.color = Color.WHITE
	mic_icon.position = Vector2(10, 10)
	mic_icon.size = Vector2(20, 20)
	mic.add_child(mic_icon)
	_app_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A conversa abre já no fim, na mensagem mais nova.
	_scroll_to_end.call_deferred()


func _scroll_to_end() -> void:
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


# --- Pistas (estilo Google Keep) ----------------------------------------------

func _render_clues() -> void:
	var active: Array = _active_missions()
	if active.is_empty():
		_add_label("Nenhuma missão em andamento.", COLOR_DIM)
		_add_label("Converse com os moradores e use os computadores da cidade para aceitar uma missão. As pistas aparecem aqui.", COLOR_DIM)
		return

	for mission in active:
		var mission_id: String = String(mission["id"])
		var card := PanelContainer.new()
		var style := _box(Color("#5b5014"), 12, 14, 12)
		style.border_color = Color("#7a6c1e")
		style.set_border_width_all(1)
		card.add_theme_stylebox_override("panel", style)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		card.add_child(column)
		var title := _text(column, String(mission["title"]), Color("#fff8d6"), 15, true)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var objective := _text(column, String(mission["objective"]), Color("#e9e2b8"), 12)
		objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var clues: PackedStringArray = PhoneManager.get_revealed_clues(mission_id)
		for i in range(clues.size()):
			var clue := _text(column, "☐  Pista %d: %s" % [i + 1, clues[i]], Color.WHITE, 13)
			clue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if PhoneManager.has_more_clues(mission_id):
			var reveal := Button.new()
			reveal.text = "+  Revelar próxima pista"
			reveal.alignment = HORIZONTAL_ALIGNMENT_LEFT
			reveal.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0.22), 16, 12, 6))
			reveal.add_theme_stylebox_override("hover", _box(Color(0, 0, 0, 0.35), 16, 12, 6))
			var reveal_focus := _box(Color(0, 0, 0, 0.35), 16, 12, 6)
			reveal_focus.border_color = Color("#fff8d6")
			reveal_focus.set_border_width_all(1)
			reveal.add_theme_stylebox_override("focus", reveal_focus)
			reveal.pressed.connect(_on_reveal_clue.bind(mission_id))
			column.add_child(reveal)
		else:
			_text(column, "Todas as pistas já foram reveladas.", Color("#d8cf9a"), 11)
		list.add_child(card)
		_spacer(4)


func _on_reveal_clue(mission_id: String) -> void:
	SoundManager.play("interact")
	PhoneManager.reveal_next_clue(mission_id)
	var old_scroll: int = scroll.scroll_vertical
	_render_current_app()
	scroll.scroll_vertical = old_scroll
	_focus_first_button()


# --- Missões (estilo Lembretes) -----------------------------------------------

func _render_missions() -> void:
	var groups := [
		[MissionManager.State.ACTIVE, "Em andamento", IOS_BLUE],
		[MissionManager.State.AVAILABLE, "Disponíveis", Color("#ff9f0a")],
		[MissionManager.State.COMPLETED, "Concluídas", Color("#30d158")],
		[MissionManager.State.LOCKED, "Bloqueadas", Color("#8e8e93")],
		[MissionManager.State.FAILED, "Falhou", IOS_RED],
	]
	for group in groups:
		var items: Array = MissionManager.missions.values().filter(func(m) -> bool: return int(m["state"]) == int(group[0]))
		if items.is_empty():
			continue
		var header := HBoxContainer.new()
		var name_label := _text(header, String(group[1]), group[2], 18, true)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_text(header, str(items.size()), group[2], 18, true)
		list.add_child(header)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _box(IOS_CELL, 12, 12, 8))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		card.add_child(column)
		for i in items.size():
			var mission: Dictionary = items[i]
			if i > 0:
				column.add_child(HSeparator.new())
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			var check := Label.new()
			check.text = "✓" if int(group[0]) == MissionManager.State.COMPLETED else ""
			check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			check.custom_minimum_size = Vector2(22, 22)
			check.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			var ring := _box(group[2] if int(group[0]) == MissionManager.State.COMPLETED else Color(0, 0, 0, 0), 11)
			ring.border_color = group[2]
			ring.set_border_width_all(2)
			check.add_theme_stylebox_override("normal", ring)
			check.add_theme_color_override("font_color", Color.BLACK)
			row.add_child(check)
			var texts := VBoxContainer.new()
			texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			texts.add_theme_constant_override("separation", 2)
			var title := _text(texts, String(mission["title"]), Color.WHITE if int(group[0]) != MissionManager.State.COMPLETED else COLOR_DIM, 14, true)
			title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var description := _text(texts, String(mission["description"]), Color("#c7c7cc"), 12)
			description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_text(texts, "%s · %s · %d XP" % [String(mission["location"]), String(mission["difficulty"]), int(mission["xp"])], COLOR_DIM, 11).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(texts)
			column.add_child(row)
		list.add_child(card)
		_spacer(8)


# --- Perfil -------------------------------------------------------------------

func _render_profile() -> void:
	var who: String = Leaderboard.player_name if Leaderboard.player_name != "" else "Hacker"
	var avatar_row := CenterContainer.new()
	avatar_row.add_child(_avatar(who, 84))
	list.add_child(avatar_row)

	_add_label("AGENTE %s" % Leaderboard.player_name if Leaderboard.player_name != "" else "HACKER", Color.WHITE, 22)
	var name_label: Label = list.get_child(list.get_child_count() - 1)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", _bold_font)
	_add_label("Tempo de jogo: %s" % Leaderboard.format_clock(Leaderboard.elapsed_msec()), COLOR_DIM, 13)
	(list.get_child(list.get_child_count() - 1) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if CampaignManager.is_game_completed:
		_add_label("CASO ENCERRADO — todas as missões concluídas!", COLOR_UNREAD, 13)
		(list.get_child(list.get_child_count() - 1) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spacer(6)

	# Três números lado a lado, como os resumos do app Saúde.
	var done: int = MissionManager.missions.values().filter(func(m) -> bool: return int(m["state"]) == MissionManager.State.COMPLETED).size()
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	for stat in [["Nível", str(GameManager.level), IOS_BLUE], ["XP total", str(GameManager.total_xp_earned), Color("#ff9f0a")], ["Missões", "%d/%d" % [done, MissionManager.missions.size()], Color("#30d158")]]:
		var box := PanelContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_stylebox_override("panel", _box(IOS_CELL, 12, 8, 8))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 0)
		box.add_child(column)
		_text(column, String(stat[1]), stat[2], 20, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_text(column, String(stat[0]), COLOR_DIM, 11).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.add_child(box)
	list.add_child(stats)

	_add_label("Nível: %d" % GameManager.level, Color.WHITE, 13)
	var bar := ProgressBar.new()
	bar.max_value = GameManager.xp_to_next_level()
	bar.value = GameManager.xp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	list.add_child(bar)
	_add_label("XP: %d/%d para o próximo nível" % [GameManager.xp, GameManager.xp_to_next_level()], COLOR_DIM, 12)

	_spacer(6)
	_add_label("CONHECIMENTOS", COLOR_DIM, 12)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(IOS_CELL, 12, 12, 10))
	var column2 := VBoxContainer.new()
	column2.add_theme_constant_override("separation", 6)
	card.add_child(column2)
	if GameManager.knowledge.is_empty():
		_text(column2, "Nenhum conceito aprendido ainda — complete uma missão.", COLOR_DIM, 13).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		for concept in GameManager.knowledge.keys():
			var reinforced: int = int(GameManager.knowledge[concept])
			var row := HBoxContainer.new()
			var concept_label := _text(row, String(concept), Color.WHITE, 13)
			concept_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			concept_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_text(row, "★".repeat(mini(reinforced, 5)) + "☆".repeat(maxi(0, 5 - reinforced)), Color("#ffd60a"), 12)
			column2.add_child(row)
	list.add_child(card)


# --- Notas (estilo Bloco de Notas) --------------------------------------------

## Bloco de notas livre do jogador. O jogo nunca lê o texto; é para quem quer
## anotar pistas, IPs e senhas e resolver os enigmas por conta própria.
func _render_notes() -> void:
	_set_chrome("custom", NP_BG, 112, 30)
	_top_bar(NP_BAR, 112)
	var back := _flat_button("‹", Color.WHITE, 26, _on_back_pressed)
	back.position = Vector2(4, 46)
	_app_top.add_child(back)
	var tab := Panel.new()
	var tab_style := _box(NP_BG, 0)
	tab_style.corner_radius_top_left = 8
	tab_style.corner_radius_top_right = 8
	tab.add_theme_stylebox_override("panel", tab_style)
	tab.position = Vector2(34, 50)
	tab.size = Vector2(150, 30)
	_app_top.add_child(tab)
	_text(tab, "anotacoes.txt", Color.WHITE, 12).position = Vector2(12, 7)
	var close_x := _text(tab, "×", COLOR_DIM, 14)
	close_x.position = Vector2(130, 5)
	var menu_row := HBoxContainer.new()
	menu_row.position = Vector2(10, 84)
	menu_row.add_theme_constant_override("separation", 14)
	_app_top.add_child(menu_row)
	for entry in ["Arquivo", "Editar", "Exibir"]:
		_text(menu_row, entry, Color("#e6e6e6"), 12)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.08)
	line.position = Vector2(0, 111)
	line.size = Vector2(_app_top.size.x, 1)
	_app_top.add_child(line)

	var editor := TextEdit.new()
	editor.name = "NotesEditor"
	editor.placeholder_text = "Anote pistas, endereços, senhas achadas, o que falta fazer..."
	editor.text = PlayerNotes.text
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	editor.custom_minimum_size = Vector2(0, scroll.size.y - 2)
	editor.add_theme_font_override("font", DesktopWindowScript.mono_font())
	editor.add_theme_font_size_override("font_size", 13)
	editor.add_theme_color_override("font_color", Color("#f0f0f0"))
	editor.add_theme_color_override("caret_color", Color.WHITE)
	editor.add_theme_color_override("font_placeholder_color", Color("#7a7a7a"))
	var page := _box(NP_BG, 0, 12, 10)
	editor.add_theme_stylebox_override("normal", page)
	editor.add_theme_stylebox_override("focus", page)
	list.add_child(editor)

	# Barra de status: linha/coluna e caracteres, como no Bloco de Notas.
	var status_bar := Panel.new()
	status_bar.add_theme_stylebox_override("panel", _box(NP_BAR, 0))
	status_bar.size = _app_bottom.size
	_app_bottom.add_child(status_bar)
	var position_label := _text(status_bar, "", Color("#cfcfcf"), 11)
	position_label.position = Vector2(12, 7)
	var counter := _text(status_bar, "", Color("#cfcfcf"), 11)
	counter.position = Vector2(status_bar.size.x - 150, 7)
	counter.size = Vector2(136, 16)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var refresh_status := func() -> void:
		position_label.text = "Ln %d, Col %d" % [editor.get_caret_line() + 1, editor.get_caret_column() + 1]
		counter.text = "%d / %d   UTF-8" % [PlayerNotes.text.length(), PlayerNotes.MAX_LENGTH]
	refresh_status.call()
	editor.caret_changed.connect(refresh_status)

	editor.text_changed.connect(func():
		PlayerNotes.set_text(editor.text)
		# No limite o texto é cortado: o campo mostra o que ficou guardado.
		if editor.text != PlayerNotes.text:
			editor.text = PlayerNotes.text
			editor.set_caret_line(editor.get_line_count() - 1)
			editor.set_caret_column(editor.get_line(editor.get_line_count() - 1).length())
		refresh_status.call()
		_notes_dirty = true)


## App Ferramentas: apoios de estudo (liberado no nível 3). O decifrador de
## César só abre depois da missão de criptografia (m04), para não entregar a
## resposta dela; nenhuma missão depende destas ferramentas.
func _render_tools() -> void:
	_add_label("Apoios de estudo. Digite e veja o resultado na hora.", COLOR_DIM)

	_add_label("Cifra de César", COLOR_TITLE)
	if CAESAR_REQUIRES_MISSION == "" or MissionManager.is_completed(CAESAR_REQUIRES_MISSION):
		var text_input: LineEdit = _add_input("Texto (ex.: VHJXUR)")
		var shift_input: LineEdit = _add_input("Deslocamento (ex.: 3)", "3")
		var caesar_out: Label = _add_output()
		var update_caesar := func():
			var shift: int = int(shift_input.text) if shift_input.text.is_valid_int() else 0
			caesar_out.text = "Decifrar (−%d): %s\nCifrar (+%d): %s" % [shift, StudyTools.caesar(text_input.text, -shift), shift, StudyTools.caesar(text_input.text, shift)]
		text_input.text_changed.connect(func(_t: String): update_caesar.call())
		shift_input.text_changed.connect(func(_t: String): update_caesar.call())
		update_caesar.call()
	else:
		_add_label("Libera depois da missão de criptografia.", COLOR_DIM)

	_add_label("Hash (MD5 e SHA-256)", COLOR_TITLE)
	var hash_input: LineEdit = _add_input("Texto para calcular o hash")
	var hash_out: Label = _add_output()
	hash_input.text_changed.connect(func(value: String):
		hash_out.text = "MD5: %s\nSHA-256: %s" % [StudyTools.md5(value), StudyTools.sha256(value)] if value != "" else "")

	_add_label("Força de senha", COLOR_TITLE)
	var password_input: LineEdit = _add_input("Digite uma senha para avaliar")
	var password_out: Label = _add_output()
	password_input.text_changed.connect(func(value: String):
		if value == "":
			password_out.text = ""
			return
		var problems: PackedStringArray = StudyTools.password_problems(value)
		password_out.text = "Força: %s" % StudyTools.password_strength(value)
		for problem in problems:
			password_out.text += "\n- " + problem)


## Ajustes no estilo do iOS: grupos de linhas com ícone colorido à esquerda e
## "›" à direita; a seta de missão é um interruptor.
func _render_settings() -> void:
	var who: String = Leaderboard.player_name if Leaderboard.player_name != "" else "Agente"
	var account := _settings_group()
	var account_row := HBoxContainer.new()
	account_row.add_theme_constant_override("separation", 12)
	account_row.add_child(_avatar(who, 52))
	var account_text := VBoxContainer.new()
	_text(account_text, who, Color.WHITE, 17, true)
	_text(account_text, "Agente da Central Cyber City · Nível %d" % GameManager.level, COLOR_DIM, 12)
	account_row.add_child(account_text)
	account.add_child(account_row)
	_spacer(10)

	var group := _settings_group()
	_settings_row(group, "Volume e tela", Color("#8e8e93"), CyberIcon.Kind.GEAR, _on_options_pressed)
	# A seta de missão é liberada pelo nível; depois dela dá para desligar.
	if GameManager.is_tool_unlocked("mission_arrow"):
		group.add_child(HSeparator.new())
		var toggle := CheckButton.new()
		toggle.text = "Seta de missão"
		toggle.button_pressed = Settings.mission_arrow
		toggle.add_theme_color_override("font_color", Color.WHITE)
		toggle.add_theme_color_override("font_hover_color", Color.WHITE)
		toggle.add_theme_color_override("font_pressed_color", Color.WHITE)
		toggle.add_theme_color_override("font_focus_color", Color.WHITE)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			toggle.add_theme_stylebox_override(state, _box(Color(0, 0, 0, 0), 8, 44, 6))
		toggle.add_theme_stylebox_override("focus", _box(Color(1, 1, 1, 0.08), 8, 44, 6))
		toggle.toggled.connect(func(_on: bool) -> void: _on_arrow_toggled())
		var tile := _settings_icon(Color("#ff9f0a"), CyberIcon.Kind.MISSION)
		tile.position = Vector2(4, 6)
		toggle.add_child(tile)
		group.add_child(toggle)
	else:
		group.add_child(HSeparator.new())
		_text(group, "Seta de missão: libera no nível %d" % int(GameManager.TOOL_UNLOCK_LEVELS["mission_arrow"]), COLOR_DIM, 13)
	_spacer(10)

	var exit_group := _settings_group()
	_settings_row(exit_group, "Menu principal", IOS_BLUE, CyberIcon.Kind.CITY, _on_main_menu_pressed)
	# No navegador (exportação Web) não existe "fechar o jogo".
	if not OS.has_feature("web"):
		exit_group.add_child(HSeparator.new())
		_settings_row(exit_group, "Sair do jogo", IOS_RED, CyberIcon.Kind.POWER, _on_quit_pressed)


func _settings_group() -> VBoxContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(IOS_CELL, 12, 8, 6))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	card.add_child(column)
	list.add_child(card)
	return column


func _settings_icon(color: Color, kind: int) -> Panel:
	var tile := Panel.new()
	tile.add_theme_stylebox_override("panel", _box(color, 7))
	tile.size = Vector2(28, 28)
	tile.custom_minimum_size = Vector2(28, 28)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := CyberIcon.new()
	glyph.kind = kind
	glyph.color = Color.WHITE
	glyph.line_width = 1.6
	glyph.position = Vector2(5, 5)
	glyph.size = Vector2(18, 18)
	tile.add_child(glyph)
	return tile


func _settings_row(group: VBoxContainer, text: String, color: Color, kind: int, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 40)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, _box(Color(0, 0, 0, 0), 8, 44, 6))
	button.add_theme_stylebox_override("focus", _box(Color(1, 1, 1, 0.08), 8, 44, 6))
	button.pressed.connect(callback)
	var tile := _settings_icon(color, kind)
	tile.position = Vector2(4, 6)
	button.add_child(tile)
	var chevron := Label.new()
	chevron.text = "›"
	chevron.add_theme_color_override("font_color", COLOR_DIM)
	chevron.add_theme_font_size_override("font_size", 20)
	chevron.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	chevron.offset_left = -22
	chevron.offset_top = -14
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(chevron)
	group.add_child(button)


# --- Ajustes -----------------------------------------------------------

func _on_arrow_toggled() -> void:
	SoundManager.play("blip")
	Settings.set_mission_arrow(not Settings.mission_arrow)


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


func _add_label(text: String, color: Color = Color.WHITE, font_size: int = 14) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	list.add_child(label)


func _add_input(placeholder: String, initial: String = "") -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.text = initial
	input.custom_minimum_size = Vector2(0, 32)
	list.add_child(input)
	return input


## Rótulo onde uma ferramenta mostra o resultado (quebra até hashes longos).
func _add_output() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.add_theme_font_size_override("font_size", 13)
	list.add_child(label)
	return label


func _add_button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 42)
	button.pressed.connect(callback)
	list.add_child(button)


func _focus_first_button() -> void:
	for child in list.find_children("*", "", true, false):
		if (child is BaseButton or child is LineEdit or child is TextEdit) and child.is_visible_in_tree():
			child.grab_focus()
			return
	if back_button.is_visible_in_tree():
		back_button.grab_focus()


# --- Teclado -----------------------------------------------------------

func _input(event: InputEvent) -> void:
	# Com o celular aberto, o teclado é tratado aqui em _input: senão um
	# botão com foco "comeria" o TAB (que no Godot troca o foco).
	if not _active or options_panel.visible:
		return
	# Clique fora do aparelho fecha o celular (o clique não passa para o jogo).
	if event is InputEventMouseButton and event.pressed \
			and not phone.get_global_rect().has_point(event.position):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if app_view.visible and event.is_action_pressed("ui_cancel"):
		# ESC dentro de um app volta (conversa -> lista -> tela inicial).
		_on_back_pressed()
		get_viewport().set_input_as_handled()
	elif home.visible and event.is_action_pressed("ui_cancel"):
		# ESC na tela inicial fecha o celular.
		toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_menu"):
		# Escrevendo num campo (notas, ferramentas), o TAB é do campo e não
		# fecha o celular; o ESC continua voltando.
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused is TextEdit or focused is LineEdit:
			return
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


# --- Visual de iPhone ------------------------------------------------------
# O aparelho é montado aqui por código em cima dos nós da cena (que continuam
# com os mesmos nomes): corpo com borda de titânio e botões laterais, Dynamic
# Island, barra de status (hora, sinal, Wi-Fi, bateria), papel de parede,
# widget com o agente e o cronômetro, ícones arredondados com bolinha de
# notificação, dock embaixo e a barrinha de "home". Os apps usam o modo
# escuro do iOS.

var _wallpaper: TextureRect
var _bold_font: Font
var _widget_name: Label
var _widget_level: Label


func _apply_iphone_look() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["SF Pro Text", "Helvetica Neue", "Segoe UI", "Inter", "Roboto", "Ubuntu", "DejaVu Sans", "Sans-serif"])
	var bold := SystemFont.new()
	bold.font_names = font.font_names
	bold.font_weight = 700
	_bold_font = bold

	# Corpo do aparelho
	phone.position = PHONE_RECT.position
	phone.size = PHONE_RECT.size
	phone.theme = _phone_theme(font)
	var body := _box(Color(0.02, 0.02, 0.03), 56)
	body.border_color = Color(0.45, 0.46, 0.5)
	body.set_border_width_all(4)
	body.shadow_color = Color(0, 0, 0, 0.6)
	body.shadow_size = 18
	phone.add_theme_stylebox_override("panel", body)
	# Botões laterais: ação e volume à esquerda, power à direita.
	for side in [[-3.0, 112.0, 26.0], [-3.0, 158.0, 48.0], [-3.0, 214.0, 48.0], [PHONE_RECT.size.x - 1.0, 176.0, 74.0]]:
		var button_part := Panel.new()
		button_part.add_theme_stylebox_override("panel", _box(Color(0.38, 0.39, 0.43), 2))
		button_part.position = Vector2(side[0], side[1])
		button_part.size = Vector2(4, side[2])
		button_part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		phone.add_child(button_part)
		phone.move_child(button_part, 0)

	# Tela: cantos arredondados que "cortam" tudo o que está dentro.
	var screen: Panel = $Phone/Screen
	screen.position = Vector2(SCREEN_INSET, SCREEN_INSET)
	screen.size = PHONE_RECT.size - Vector2(SCREEN_INSET, SCREEN_INSET) * 2.0
	screen.add_theme_stylebox_override("panel", _box(Color.BLACK, 47))
	screen.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW

	_wallpaper = TextureRect.new()
	_wallpaper.name = "Wallpaper"
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([Color(0.09, 0.2, 0.52), Color(0.36, 0.14, 0.5), Color(0.04, 0.04, 0.12)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.2, 0.0)
	texture.fill_to = Vector2(0.8, 1.0)
	_wallpaper.texture = texture
	_wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wallpaper.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(_wallpaper)
	screen.move_child(_wallpaper, 0)

	# Barra de status (hora à esquerda, ícones à direita) e Dynamic Island.
	var status: Control = $Phone/StatusBar
	status.position = Vector2(24, 20)
	status.size = Vector2(PHONE_RECT.size.x - 48, 24)
	phone.move_child(status, phone.get_child_count() - 1)
	$Phone/StatusBar/NameLabel.visible = false
	clock_label.position = Vector2(14, 0)
	clock_label.size = Vector2(60, 24)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label.add_theme_font_override("font", bold)
	clock_label.add_theme_font_size_override("font_size", 15)
	clock_label.add_theme_color_override("font_color", Color.WHITE)
	var x := status.size.x - 74.0
	for spec in [[CyberIcon.Kind.SIGNAL, 18.0], [CyberIcon.Kind.WIFI, 18.0], [CyberIcon.Kind.BATTERY, 26.0]]:
		var icon: CyberIcon = CyberIcon.new()
		icon.kind = spec[0]
		icon.color = Color.WHITE
		icon.line_width = 1.6
		icon.position = Vector2(x, 5)
		icon.size = Vector2(spec[1], 13)
		status.add_child(icon)
		x += spec[1] + 5.0
	var island := Panel.new()
	island.name = "DynamicIsland"
	island.add_theme_stylebox_override("panel", _box(Color.BLACK, 15))
	island.position = Vector2((PHONE_RECT.size.x - 100.0) * 0.5, 18)
	island.size = Vector2(100, 30)
	island.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone.add_child(island)

	# Widget no topo da tela inicial: agente, cronômetro da partida e nível.
	var widget := Panel.new()
	widget.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.14), 22))
	widget.position = Vector2(18, 56)
	widget.size = Vector2(screen.size.x - 36, 104)
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.add_child(widget)
	_widget_name = _widget_label(widget, Vector2(16, 12), 12, Color(1, 1, 1, 0.75), bold)
	_stopwatch_label.position = Vector2(16, 30)
	_stopwatch_label.size = Vector2(widget.size.x - 32, 36)
	_stopwatch_label.add_theme_font_override("font", bold)
	_stopwatch_label.add_theme_color_override("font_color", Color.WHITE)
	widget.add_child(_stopwatch_label)
	_widget_level = _widget_label(widget, Vector2(16, 72), 12, Color(1, 1, 1, 0.75), font)

	# Grade de apps (4 colunas) e dock com os mais usados.
	apps_grid.columns = 4
	apps_grid.position = Vector2(18, 180)
	apps_grid.size = Vector2(screen.size.x - 36, 200)
	apps_grid.add_theme_constant_override("h_separation", 6)
	apps_grid.add_theme_constant_override("v_separation", 14)

	var dock_panel := Panel.new()
	dock_panel.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.16), 30))
	dock_panel.position = Vector2(12, screen.size.y - 112)
	dock_panel.size = Vector2(screen.size.x - 24, 88)
	dock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.add_child(dock_panel)
	var dock := HBoxContainer.new()
	dock.name = "Dock"
	dock.alignment = BoxContainer.ALIGNMENT_CENTER
	dock.add_theme_constant_override("separation", 4)
	dock.position = Vector2(8, 10)
	dock.size = Vector2(dock_panel.size.x - 16, 72)
	dock_panel.add_child(dock)
	for button in [messages_button, missions_button, notes_button, settings_button]:
		button.reparent(dock, false)

	for button in [messages_button, clues_button, missions_button, profile_button, settings_button, notes_button, tools_button, close_button]:
		_make_app_icon(button, bold)

	# Barrinha de "home" e a dica do teclado (ao lado do aparelho).
	var bar: Panel = $Phone/HomeIndicator
	bar.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.85), 3))
	bar.position = Vector2((PHONE_RECT.size.x - 120.0) * 0.5, PHONE_RECT.size.y - 18)
	bar.size = Vector2(120, 5)
	phone.move_child(bar, phone.get_child_count() - 1)
	var hint: Label = $Phone/HintLabel
	hint.position = Vector2(PHONE_RECT.size.x + 14, PHONE_RECT.size.y - 30)
	hint.size = Vector2(170, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	hint.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0.6), 8, 8, 3))

	# Apps: "‹ Início" em azul e título grande, como no iOS.
	var header: Control = $Phone/Screen/AppView/Header
	header.position = Vector2(10, 50)
	header.size = Vector2(screen.size.x - 20, 30)
	back_button.text = "‹ Início"
	back_button.flat = true
	back_button.custom_minimum_size = Vector2(80, 30)
	back_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back_button.add_theme_color_override("font_color", IOS_BLUE)
	back_button.add_theme_color_override("font_hover_color", IOS_BLUE.lightened(0.3))
	back_button.add_theme_color_override("font_focus_color", IOS_BLUE.lightened(0.3))
	back_button.add_theme_font_size_override("font_size", 16)
	var back_focus := _box(Color(1, 1, 1, 0.08), 8, 6, 2)
	back_button.add_theme_stylebox_override("focus", back_focus)
	back_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	back_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	app_title.reparent(app_view, false)
	app_title.position = Vector2(18, 82)
	app_title.size = Vector2(screen.size.x - 36, 36)
	app_title.add_theme_font_override("font", bold)
	app_title.add_theme_font_size_override("font_size", 26)
	app_title.add_theme_color_override("font_color", Color.WHITE)
	scroll.position = Vector2(14, 126)
	scroll.size = Vector2(screen.size.x - 28, screen.size.y - 152)
	# Como no iPhone, sem barra de rolagem à vista (roda do mouse e setas rolam).
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# Fundo e barras próprias de cada app (ver _set_chrome).
	_app_bg = Panel.new()
	_app_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_app_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app_view.add_child(_app_bg)
	app_view.move_child(_app_bg, 0)
	_app_top = Control.new()
	_app_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app_view.add_child(_app_top)
	_app_bottom = Control.new()
	_app_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app_view.add_child(_app_bottom)

	# Sem ícone "Fechar": clicar fora do aparelho ou ESC na tela inicial fecha.
	close_button.visible = false

	# Mouse andando por cima de um ícone = ícone selecionado (igual ao teclado).
	for button in phone.find_children("*", "BaseButton", true, false):
		button.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseMotion and event.relative.length() > 0.5 \
					and button.is_visible_in_tree() and not button.has_focus():
				button.grab_focus())


## Transforma um botão da tela inicial num ícone de app: quadrado arredondado
## colorido com o desenho, nome embaixo e bolinha vermelha de notificação.
func _make_app_icon(button: Button, bold: Font) -> void:
	var style: Array = APP_STYLE.get(String(button.name), [Color(0.3, 0.3, 0.32), button.text, CyberIcon.Kind.CHAT])
	button.text = ""
	button.custom_minimum_size = Vector2(64, 84)
	button.tooltip_text = String(style[1])
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	button.add_theme_stylebox_override("focus", _box(Color(1, 1, 1, 0.16), 18))

	var tile := Panel.new()
	tile.name = "Tile"
	var tile_style := _box(style[0], 15)
	tile_style.corner_detail = 10
	tile_style.shadow_color = Color(0, 0, 0, 0.3)
	tile_style.shadow_size = 4
	tile.add_theme_stylebox_override("panel", tile_style)
	tile.position = Vector2(3, 4)
	tile.size = Vector2(58, 58)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(tile)

	var glyph: CyberIcon = CyberIcon.new()
	glyph.kind = style[2]
	glyph.color = Color.WHITE
	glyph.line_width = 2.4
	glyph.position = Vector2(13, 13)
	glyph.size = Vector2(32, 32)
	tile.add_child(glyph)

	var name_label := Label.new()
	name_label.name = "AppName"
	name_label.text = String(style[1])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	name_label.position = Vector2(-6, 64)
	name_label.size = Vector2(76, 18)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(name_label)

	var badge := Label.new()
	badge.name = "Badge"
	badge.visible = false
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_override("font", bold)
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_stylebox_override("normal", _box(IOS_RED, 11))
	badge.position = Vector2(48, -4)
	badge.size = Vector2(22, 22)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(badge)


func _set_badge(button: Button, count: int) -> void:
	var badge: Label = button.get_node_or_null("Badge")
	if badge == null:
		return
	badge.visible = count > 0
	badge.text = str(count) if count < 100 else "99+"


func _widget_label(parent: Control, at: Vector2, font_size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.position = at
	label.size = Vector2(parent.size.x - 32, 20)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(label)
	return label


func _box(color: Color, radius: int, margin_x: int = 0, margin_y: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.corner_detail = 8
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	return box


## Tema dos apps: células escuras arredondadas (como as listas do iOS), campos de
## texto e barra de progresso azul.
func _phone_theme(font: Font) -> Theme:
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 14
	var normal := _box(IOS_CELL, 12, 14, 8)
	var focus := _box(IOS_CELL_HI, 12, 14, 8)
	focus.border_color = IOS_BLUE
	focus.set_border_width_all(2)
	var pressed := _box(Color(0.25, 0.25, 0.28), 12, 14, 8)
	for state in ["normal", "disabled"]:
		theme.set_stylebox(state, "Button", normal)
	theme.set_stylebox("hover", "Button", normal)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("hover_pressed", "Button", pressed)
	for color_name in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		theme.set_color(color_name, "Button", Color.WHITE)
	theme.set_color("font_color", "Label", Color.WHITE)
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 0)
	for type in ["LineEdit", "TextEdit"]:
		theme.set_stylebox("normal", type, _box(IOS_CELL, 10, 10, 6))
		var edit_focus := _box(IOS_CELL, 10, 10, 6)
		edit_focus.border_color = IOS_BLUE
		edit_focus.set_border_width_all(2)
		theme.set_stylebox("focus", type, edit_focus)
		theme.set_color("font_color", type, Color.WHITE)
		theme.set_color("caret_color", type, IOS_BLUE)
		theme.set_color("font_placeholder_color", type, COLOR_DIM)
	theme.set_stylebox("background", "ProgressBar", _box(Color(0.2, 0.2, 0.22), 4))
	theme.set_stylebox("fill", "ProgressBar", _box(IOS_BLUE, 4))
	var line := StyleBoxLine.new()
	line.color = Color(0.25, 0.25, 0.27)
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
	theme.set_constant("separation", "HSeparator", 14)
	return theme
