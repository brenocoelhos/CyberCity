extends CanvasLayer
## DesktopManager.gd — Autoload
## O computador como um desktop de verdade: papel de parede, ícones, barra de
## tarefas e janelas. As janelas podem ser arrastadas pela barra de título,
## redimensionadas pelo canto, maximizadas (botão ou duplo clique), minimizadas
## e fechadas; podem estar várias abertas ao mesmo tempo, e a que recebe o
## clique vai para a frente e fica com o teclado.
##
## Apps: Terminal (uma janela, o TerminalManager de sempre), Navegador (quantas
## janelas quiser) e Notas (o mesmo texto do app Notas do celular).
##
## Quem abre o desktop é o computador (Computer.gd), e só quando o desafio dele
## tem "desktop": true no ChallengeData (hoje, só o piloto c_site). O terminal e
## os navegadores compartilham a mesma sessão do desafio.
##
## PROVISÓRIO: ícones e papel de parede são de teste; a Arte pode trocar.

const Browser := preload("res://scripts/desktop/Browser.gd")
const NotesWindow := preload("res://scripts/desktop/NotesWindow.gd")
const MailWindow := preload("res://scripts/desktop/MailWindow.gd")
const FilesWindow := preload("res://scripts/desktop/FilesWindow.gd")
const CyberWallpaper := preload("res://scripts/desktop/CyberWallpaper.gd")
const CyberIcon := preload("res://scripts/ui/CyberIcon.gd")

const C_ACCENT := Color("#2f8cff")
const C_GREEN := Color("#3dff6e")
const C_TASKBAR := Color("#0b1622")
## Painel de cima (estilo Xfce, como no Kali): menu, atalhos, áreas de trabalho,
## janelas abertas, bandeja e relógio. As janelas ficam abaixo dele.
const TASKBAR_HEIGHT := 32.0
const C_PANEL := Color(0.1, 0.11, 0.13, 0.97)
const C_MENU := Color(0.12, 0.13, 0.15, 0.98)
const C_MENU_SIDE := Color(0.09, 0.1, 0.12, 1.0)
const C_HOVER := Color(1, 1, 1, 0.08)
const C_KALI_BLUE := Color("#367bf0")
const C_TEXT := Color("#e6e9ef")
const C_TEXT_DIM := Color("#9aa3b2")

## Como cada app aparece no painel e no menu: [ícone, nome longo, cor, categorias].
const APP_INFO := {
	"terminal": [CyberIcon.Kind.TERMINAL, "Emulador de Terminal", Color("#d7dbe3"), ["fav", "01", "09", "16"]],
	"browser": [CyberIcon.Kind.GLOBE, "Navegador Web", Color("#4aa3ff"), ["fav", "01", "03"]],
	"mail": [CyberIcon.Kind.MAIL, "Cliente de E-mail", Color("#7cc4ff"), ["fav", "03", "11"]],
	"files": [CyberIcon.Kind.FOLDER, "Gerenciador de Arquivos", Color("#4a8ff0"), ["fav", "11", "15"]],
	"notes": [CyberIcon.Kind.NOTE, "Editor de Texto (Notas)", Color("#f2f4f8"), ["fav", "16"]],
}
## Categorias do menu, na ordem do menu do Kali (táticas do MITRE ATT&CK).
const MENU_CATEGORIES := [
	["fav", "Favoritos"], ["recent", "Usados recentemente"], ["all", "Todos os aplicativos"],
	["01", "01 - Reconhecimento"], ["02", "02 - Desenvolvimento de recursos"],
	["03", "03 - Acesso inicial"], ["04", "04 - Execução"], ["05", "05 - Persistência"],
	["06", "06 - Escalada de privilégios"], ["07", "07 - Evasão de defesa"],
	["08", "08 - Acesso a credenciais"], ["09", "09 - Descoberta"],
	["10", "10 - Movimento lateral"], ["11", "11 - Coleta"],
	["12", "12 - Comando e controle"], ["13", "13 - Exfiltração"], ["14", "14 - Impacto"],
	["15", "15 - Forense"], ["16", "16 - Serviços e outras ferramentas"],
]
const GRIP_SIZE := 18.0
const MAX_BROWSERS := 4

## Apps do desktop: id -> [símbolo do ícone, nome]. Cada desafio escolhe quais
## aparecem com "apps" no ChallengeData (sem "apps": os de DEFAULT_APPS).
const APPS := {
	"terminal": [">_", "Terminal"],
	"browser": ["www", "Navegador"],
	"mail": ["@", "E-mail"],
	"files": ["dir", "Arquivos"],
	"notes": ["txt", "Notas"],
}
const DEFAULT_APPS := ["terminal", "browser", "notes"]

const DEFAULT_SIZES := {
	"terminal": Vector2(820, 500),
	"browser": Vector2(760, 500),
	"notes": Vector2(400, 380),
	"mail": Vector2(860, 540),
	"files": Vector2(860, 540),
}
const TERMINAL_MIN_SIZE := Vector2(520, 320)

var _open: bool = false
var _challenge: Dictionary = {}
var _terminal_shown: bool = false

## Janelas registradas: {node, title_bar, kind, min_size, maximized,
## restore_rect, closed, button}. A ordem na tela é a dos filhos de _windows.
var _entries: Array[Dictionary] = []
var _terminal_entry: Dictionary = {}
var _terminal_grip: Control
var _focused: Control = null
var _drag: Dictionary = {}
var _resize: Dictionary = {}
var _cascade: int = 0

var _root: Control
var _windows: Control
var _icons: Dictionary = {}
var _apps: Array = DEFAULT_APPS
var _note: PanelContainer
var _note_label: Label
var _task_row: HBoxContainer
var _clock: Label
## Atalhos do painel (um por app) e o menu de aplicativos.
var _launchers: Dictionary = {}
var _app_menu: PanelContainer
var _menu_button: Button
var _menu_search: LineEdit
var _menu_list: VBoxContainer
var _menu_categories: VBoxContainer
var _menu_user: Label
var _menu_category: String = "fav"
var _recent: Array = []
var _workspace_buttons: Array = []
var _workspace: int = 1


func _ready() -> void:
	layer = 8
	visible = false
	_build()
	_setup_terminal()


func is_open() -> bool:
	return _open


## Abre o desktop do computador deste desafio.
func open(challenge_id: String, host: String) -> void:
	_challenge = ChallengeData.get_challenge(challenge_id)
	_terminal_shown = false
	_reset_windows()
	TerminalManager.desktop_mode = true
	TerminalManager.start_session(challenge_id, host)
	var size: Vector2 = DEFAULT_SIZES["terminal"]
	TerminalManager.attach_window(_windows, Vector2(90, 36), size)
	_terminal_entry["closed"] = true
	_terminal_entry["maximized"] = false
	_terminal_grip.visible = true
	_entries.append(_terminal_entry)
	_open = true
	visible = true
	_apps = Array(_challenge.get("apps", DEFAULT_APPS))
	for app in _icons:
		(_icons[app] as Button).visible = _apps.has(app)
		(_launchers[app] as Button).visible = _apps.has(app)
	_app_menu.visible = false
	_switch_workspace(1)
	_update_note()
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.2)
	SoundManager.play("blip")


## Desliga o desktop (e encerra a sessão do terminal).
func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	_drag = {}
	_resize = {}
	if _find_entry("notes").size() > 0:
		SaveManager.request_save("notes")
	_reset_windows()
	if TerminalManager.desktop_mode:
		TerminalManager.close()
	_terminal_grip.visible = false
	TerminalManager.detach_window()


func _process(_delta: float) -> void:
	if not _open:
		return
	_clock.text = Time.get_time_string_from_system().substr(0, 5)
	_refresh_taskbar()


## Mouse: o clique traz a janela para a frente; arrastar e redimensionar
## acompanham o mouse mesmo fora da barra. ESC: minimiza a janela da frente e,
## sem janelas abertas, desliga o desktop.
func _input(event: InputEvent) -> void:
	if not _open:
		return
	# Menu de aplicativos aberto: clique fora fecha; ESC fecha só o menu.
	if _app_menu.visible:
		if event is InputEventMouseButton and event.pressed \
				and not _app_menu.get_global_rect().has_point(event.position) \
				and not _menu_button.get_global_rect().has_point(event.position):
			_app_menu.visible = false
		elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_app_menu.visible = false
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_focus_at(event.position)
		else:
			_drag = {}
			_resize = {}
	elif event is InputEventMouseMotion:
		if not _drag.is_empty():
			var node: Control = _drag["node"]
			# A área das janelas começa abaixo do painel de cima.
			node.position = _clamp_position(event.position - Vector2(_drag["offset"]) - _windows.global_position, node.size)
		elif not _resize.is_empty():
			_apply_resize(event.position)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _focused != null and _focused.visible:
			minimize_window(_focused)
		else:
			close()
		get_viewport().set_input_as_handled()


# --- Apps ---------------------------------------------------------------------------

## Abre (ou traz para a frente) um app: "terminal", "browser" (uma nova janela a
## cada vez) ou "notes". Devolve a janela.
func open_app(kind: String) -> Control:
	if not _apps.has(kind):
		return null
	_recent.erase(kind)
	_recent.push_front(kind)
	if _workspace != 1:
		_switch_workspace(1)
	match kind:
		"terminal":
			var node: Control = _terminal_entry["node"]
			if not bool(_terminal_entry["closed"]):
				focus_window(node)
				return node
			_terminal_entry["closed"] = false
			_add_task_button(_terminal_entry)
			if not _terminal_shown:
				_terminal_shown = true
				node.position = _next_position(node.size)
				TerminalManager.show_window()
			else:
				TerminalManager.restore_window()
			focus_window(node)
			return node
		"browser":
			if _count_kind("browser") >= MAX_BROWSERS:
				SoundManager.play("error")
				return null
			var browser: Control = Browser.new()
			return _add_app_window(browser, "browser", func() -> void: browser.open_for(_challenge))
		"notes":
			var existing: Dictionary = _find_entry("notes")
			if not existing.is_empty():
				focus_window(existing["node"])
				return existing["node"]
			return _add_app_window(NotesWindow.new(), "notes", Callable())
		"mail":
			var existing_mail: Dictionary = _find_entry("mail")
			if not existing_mail.is_empty():
				focus_window(existing_mail["node"])
				return existing_mail["node"]
			var mail: Control = MailWindow.new()
			return _add_app_window(mail, "mail", func() -> void: mail.open_for(_challenge))
		"files":
			var existing_files: Dictionary = _find_entry("files")
			if not existing_files.is_empty():
				focus_window(existing_files["node"])
				return existing_files["node"]
			var files_window: Control = FilesWindow.new()
			return _add_app_window(files_window, "files", func() -> void: files_window.open_for(_challenge))
	return null


func _add_app_window(window, kind: String, on_ready: Callable) -> Control:
	var size: Vector2 = DEFAULT_SIZES[kind]
	window.size = size
	window.position = _next_position(size)
	_windows.add_child(window)
	var entry := _register(window, window.title_bar, kind, window.min_size)
	window.min_button.pressed.connect(minimize_window.bind(window))
	window.max_button.pressed.connect(toggle_maximize.bind(window))
	window.close_button.pressed.connect(close_window.bind(window))
	_add_task_button(entry)
	if on_ready.is_valid():
		on_ready.call()
	focus_window(window)
	SoundManager.play("blip")
	return window


## As janelas abertas (não minimizadas), da de trás para a da frente.
func visible_windows() -> Array[Control]:
	var result: Array[Control] = []
	for child in _windows.get_children():
		if child is Control and child.visible and not _find_entry_of(child).is_empty() and not bool(_find_entry_of(child)["closed"]):
			result.append(child)
	return result


func focused_window() -> Control:
	return _focused


func window_count(kind: String = "") -> int:
	var count := 0
	for entry in _entries:
		if bool(entry["closed"]):
			continue
		if kind == "" or String(entry["kind"]) == kind:
			count += 1
	return count


# --- Janelas ------------------------------------------------------------------------

func focus_window(node: Control) -> void:
	var entry: Dictionary = _find_entry_of(node)
	if entry.is_empty() or bool(entry["closed"]):
		return
	if not node.visible:
		if String(entry["kind"]) == "terminal":
			TerminalManager.restore_window()
		else:
			node.visible = true
	_windows.move_child(node, _windows.get_child_count() - 1)
	var changed: bool = _focused != node
	_focused = node
	TerminalManager.set_window_focused(String(entry["kind"]) == "terminal")
	if changed and String(entry["kind"]) != "terminal":
		# Tira o cursor do campo de texto do terminal.
		get_viewport().gui_release_focus()


func minimize_window(node: Control) -> void:
	var entry: Dictionary = _find_entry_of(node)
	if entry.is_empty():
		return
	if String(entry["kind"]) == "terminal":
		TerminalManager.minimize()
	else:
		node.visible = false
	if _focused == node:
		_focused = null
		_focus_top()


## Fecha a janela. Navegador e Notas somem; o terminal só sai da tela e da barra
## de tarefas (a sessão continua, e o ícone o traz de volta como estava).
func close_window(node: Control) -> void:
	var entry: Dictionary = _find_entry_of(node)
	if entry.is_empty():
		return
	_remove_task_button(entry)
	if String(entry["kind"]) == "terminal":
		entry["closed"] = true
		TerminalManager.minimize()
	else:
		_entries.erase(entry)
		if String(entry["kind"]) == "notes":
			SaveManager.request_save("notes")
		node.queue_free()
	if _focused == node:
		_focused = null
		_focus_top()


func toggle_maximize(node: Control) -> void:
	var entry: Dictionary = _find_entry_of(node)
	if entry.is_empty():
		return
	if bool(entry["maximized"]):
		var saved: Rect2 = entry["restore_rect"]
		node.position = saved.position
		node.size = saved.size
		entry["maximized"] = false
	else:
		entry["restore_rect"] = Rect2(node.position, node.size)
		node.position = Vector2.ZERO
		node.size = _work_size()
		entry["maximized"] = true
	focus_window(node)


## Dá o foco à janela da frente que ainda está aberta.
func _focus_top() -> void:
	var open_windows: Array[Control] = visible_windows()
	if open_windows.is_empty():
		_focused = null
		TerminalManager.set_window_focused(false)
		return
	focus_window(open_windows[-1])


## Clique em (x, y): a janela de cima nesse ponto vem para a frente.
func _focus_at(point: Vector2) -> void:
	var open_windows: Array[Control] = visible_windows()
	for i in range(open_windows.size() - 1, -1, -1):
		if open_windows[i].get_global_rect().has_point(point):
			focus_window(open_windows[i])
			return


func _register(node: Control, title_bar: Control, kind: String, min_size: Vector2) -> Dictionary:
	var entry := {
		"node": node, "title_bar": title_bar, "kind": kind, "min_size": min_size,
		"maximized": false, "restore_rect": Rect2(), "closed": false, "button": null,
	}
	_entries.append(entry)
	title_bar.gui_input.connect(_on_title_input.bind(node))
	node.add_child(_make_grip(node, entry))
	return entry


## Liga o terminal ao desktop uma vez: a janela dele é a do TerminalManager.
func _setup_terminal() -> void:
	var node: Control = TerminalManager.monitor
	var title_bar: Control = node.get_node("TitleBar")
	_terminal_entry = {
		"node": node, "title_bar": title_bar, "kind": "terminal", "min_size": TERMINAL_MIN_SIZE,
		"maximized": false, "restore_rect": Rect2(), "closed": true, "button": null,
	}
	title_bar.gui_input.connect(_on_title_input.bind(node))
	_terminal_grip = _make_grip(node, _terminal_entry)
	_terminal_grip.visible = false
	node.add_child(_terminal_grip)
	TerminalManager.window_minimize_requested.connect(func() -> void: minimize_window(node))
	TerminalManager.window_maximize_requested.connect(func() -> void: toggle_maximize(node))
	TerminalManager.window_close_requested.connect(func() -> void: close_window(node))


func _reset_windows() -> void:
	for entry in _entries:
		_remove_task_button(entry)
		if String(entry["kind"]) != "terminal":
			(entry["node"] as Node).queue_free()
	_entries.clear()
	_focused = null
	_cascade = 0


# --- Arrastar e redimensionar --------------------------------------------------------

func _on_title_input(event: InputEvent, node: Control) -> void:
	if not _open or not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	focus_window(node)
	if event.double_click:
		toggle_maximize(node)
		return
	var entry: Dictionary = _find_entry_of(node)
	if not entry.is_empty() and not bool(entry["maximized"]):
		_drag = {"node": node, "offset": event.global_position - node.global_position}


func _make_grip(node: Control, entry: Dictionary) -> Control:
	var grip := Control.new()
	grip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grip.offset_left = -GRIP_SIZE
	grip.offset_top = -GRIP_SIZE
	grip.offset_right = 0.0
	grip.offset_bottom = 0.0
	grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	grip.draw.connect(func() -> void:
		for i in range(3):
			var d: float = 5.0 + i * 4.0
			grip.draw_line(Vector2(GRIP_SIZE - d, GRIP_SIZE - 2.0), Vector2(GRIP_SIZE - 2.0, GRIP_SIZE - d), Color(0.6, 0.7, 0.8, 0.7), 1.0))
	grip.gui_input.connect(func(event: InputEvent) -> void:
		if not _open or not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
			return
		if bool(entry["maximized"]):
			return
		focus_window(node)
		_resize = {"node": node, "min_size": entry["min_size"], "start_size": node.size, "start_mouse": event.global_position})
	return grip


func _apply_resize(mouse: Vector2) -> void:
	var node: Control = _resize["node"]
	var wanted: Vector2 = Vector2(_resize["start_size"]) + (mouse - Vector2(_resize["start_mouse"]))
	var limit: Vector2 = _work_size() - node.position
	node.size = Vector2(
		clampf(wanted.x, float(Vector2(_resize["min_size"]).x), maxf(limit.x, float(Vector2(_resize["min_size"]).x))),
		clampf(wanted.y, float(Vector2(_resize["min_size"]).y), maxf(limit.y, float(Vector2(_resize["min_size"]).y))))


## A janela não sai da tela: sempre sobra um pedaço da barra de título à vista.
func _clamp_position(wanted: Vector2, size: Vector2) -> Vector2:
	var work: Vector2 = _work_size()
	return Vector2(clampf(wanted.x, 120.0 - size.x, work.x - 120.0), clampf(wanted.y, 0.0, work.y - 30.0))


func _work_size() -> Vector2:
	return get_viewport().get_visible_rect().size - Vector2(0, TASKBAR_HEIGHT)


## Posição da próxima janela: em cascata, voltando ao início se não couber.
func _next_position(size: Vector2) -> Vector2:
	var work: Vector2 = _work_size()
	var start := Vector2(130.0 + _cascade * 32.0, 24.0 + _cascade * 28.0)
	_cascade += 1
	if start.x + size.x > work.x or start.y + size.y > work.y:
		_cascade = 1
		start = Vector2(130.0, 24.0)
	return start


# --- Barra de tarefas -----------------------------------------------------------------

func _add_task_button(entry: Dictionary) -> void:
	if entry["button"] != null:
		return
	var button := Button.new()
	button.toggle_mode = true
	# Sem foco de teclado: o terminal em foco reassume o cursor a cada quadro e,
	# se o botão tivesse foco, o clique seria cancelado no meio.
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.custom_minimum_size = Vector2(150, 0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", C_TEXT_DIM)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	# Janela da frente: fundo mais claro e risco azul embaixo, como no Xfce.
	var active := _row_style(Color(1, 1, 1, 0.1))
	active.border_color = C_KALI_BLUE
	active.border_width_bottom = 2
	button.add_theme_stylebox_override("normal", _row_style(Color(0, 0, 0, 0)))
	button.add_theme_stylebox_override("hover", _row_style(C_HOVER))
	button.add_theme_stylebox_override("pressed", active)
	button.add_theme_stylebox_override("hover_pressed", active)
	button.pressed.connect(_on_task_pressed.bind(entry["node"]))
	_task_row.add_child(button)
	entry["button"] = button


func _remove_task_button(entry: Dictionary) -> void:
	var button: Variant = entry["button"]
	if button != null and is_instance_valid(button):
		(button as Node).queue_free()
	entry["button"] = null


func _on_task_pressed(node: Control) -> void:
	if not node.visible:
		focus_window(node)
	elif _focused == node:
		minimize_window(node)
	else:
		focus_window(node)


func _refresh_taskbar() -> void:
	for entry in _entries:
		var button: Variant = entry["button"]
		var node: Control = entry["node"]
		if button != null and is_instance_valid(button):
			var title: String = "Terminal" if String(entry["kind"]) == "terminal" else String((node as Object).get("title_label").text)
			(button as Button).text = title
			(button as Button).set_pressed_no_signal(node.visible and node == _focused)
		# A janela sem foco fica com a barra de título mais apagada.
		(entry["title_bar"] as Control).modulate = Color.WHITE if node == _focused else Color(0.62, 0.66, 0.74)


## O recado do desafio na mesa, conforme o nível de guia (3 = nenhum).
func _update_note() -> void:
	var guidance: int = clampi(int(_challenge.get("guidance", 1)), 1, 3)
	var text := ""
	if guidance == 1:
		text = String(_challenge.get("desktop_intro", ""))
	elif guidance == 2:
		text = "Computador aberto. Use o Navegador e o Terminal."
	_note_label.text = text
	_note.visible = text != ""


func _count_kind(kind: String) -> int:
	var count := 0
	for entry in _entries:
		if String(entry["kind"]) == kind:
			count += 1
	return count


func _find_entry(kind: String) -> Dictionary:
	for entry in _entries:
		if String(entry["kind"]) == kind:
			return entry
	return {}


func _find_entry_of(node: Node) -> Dictionary:
	for entry in _entries:
		if entry["node"] == node:
			return entry
	return {}


# --- Montagem -------------------------------------------------------------------------
# Visual inspirado no Kali Linux (Xfce): painel escuro no topo, menu de
# aplicativos com categorias, papel de parede azul geométrico e ícones na área de
# trabalho. A identidade é a do CYBER-OS (emblema do hexágono com cadeado).

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var wallpaper: Control = CyberWallpaper.new()
	wallpaper.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(wallpaper)

	# Ícones da área de trabalho (abaixo do painel)
	var icons := VBoxContainer.new()
	icons.position = Vector2(14, TASKBAR_HEIGHT + 14)
	icons.add_theme_constant_override("separation", 8)
	_root.add_child(icons)
	for app in APPS:
		var icon: Button = _make_icon(String(app), String(APPS[app][1]), func() -> void: open_app(String(app)))
		_icons[app] = icon
		icons.add_child(icon)

	# Recado do desafio
	_note = PanelContainer.new()
	_note.position = Vector2(130, TASKBAR_HEIGHT + 16)
	_note.custom_minimum_size = Vector2(360, 0)
	var note_style := StyleBoxFlat.new()
	note_style.bg_color = Color(0.08, 0.1, 0.14, 0.92)
	note_style.border_color = Color("#ffd75f")
	note_style.border_width_left = 4
	note_style.set_corner_radius_all(6)
	note_style.set_content_margin_all(12)
	_note.add_theme_stylebox_override("panel", note_style)
	_root.add_child(_note)
	_note_label = Label.new()
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.custom_minimum_size = Vector2(336, 0)
	_note_label.add_theme_color_override("font_color", Color("#ffd75f"))
	_note.add_child(_note_label)

	# Área das janelas: abaixo do painel; só as janelas pegam o mouse.
	_windows = Control.new()
	_windows.set_anchors_preset(Control.PRESET_FULL_RECT)
	_windows.offset_top = TASKBAR_HEIGHT
	_windows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_windows)

	_build_panel()
	_build_app_menu()


func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = TASKBAR_HEIGHT
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = C_PANEL
	bar_style.border_color = Color(1, 1, 1, 0.06)
	bar_style.border_width_bottom = 1
	bar_style.content_margin_left = 4
	bar_style.content_margin_right = 6
	panel.add_theme_stylebox_override("panel", bar_style)
	_root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	panel.add_child(row)

	# Botão do menu (emblema azul) e atalhos dos apps
	_menu_button = _panel_button(CyberIcon.Kind.EMBLEM, C_KALI_BLUE, "Aplicativos")
	_menu_button.custom_minimum_size = Vector2(34, 30)
	_menu_button.pressed.connect(_toggle_app_menu)
	row.add_child(_menu_button)
	row.add_child(_panel_separator())
	for app in APP_INFO:
		var info: Array = APP_INFO[app]
		var launcher := _panel_button(info[0], info[2], String(info[1]))
		launcher.pressed.connect(func() -> void: open_app(String(app)))
		_launchers[app] = launcher
		row.add_child(launcher)
	row.add_child(_panel_separator())

	# Áreas de trabalho 1 a 4
	for i in range(1, 5):
		var ws := Button.new()
		ws.text = str(i)
		ws.focus_mode = Control.FOCUS_NONE
		ws.custom_minimum_size = Vector2(24, 0)
		ws.tooltip_text = "Área de trabalho %d" % i
		ws.add_theme_font_size_override("font_size", 12)
		ws.pressed.connect(_switch_workspace.bind(i))
		_workspace_buttons.append(ws)
		row.add_child(ws)
	row.add_child(_panel_separator())

	# Janelas abertas
	_task_row = HBoxContainer.new()
	_task_row.add_theme_constant_override("separation", 2)
	_task_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_task_row)

	# Bandeja: rede, volume, notificações, relógio, bloquear e desligar
	for spec in [[CyberIcon.Kind.MONITOR, "Rede: laboratório da missão (conectado)"], [CyberIcon.Kind.VOLUME, "Volume"], [CyberIcon.Kind.BELL, "Notificações"]]:
		var tray := CyberIcon.new()
		tray.kind = spec[0]
		tray.color = C_TEXT
		tray.line_width = 1.4
		tray.custom_minimum_size = Vector2(26, 16)
		tray.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tray.tooltip_text = spec[1]
		tray.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(tray)
	_clock = Label.new()
	_clock.add_theme_color_override("font_color", C_TEXT)
	_clock.add_theme_font_size_override("font_size", 13)
	_clock.custom_minimum_size = Vector2(52, 0)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_clock)
	var lock := _panel_button(CyberIcon.Kind.LOCK, C_TEXT, "Bloquear tela (fecha o computador)")
	lock.pressed.connect(close)
	row.add_child(lock)
	var power := _panel_button(CyberIcon.Kind.POWER, C_TEXT, "Desligar: fecha o computador (ESC sem janelas abertas)")
	power.pressed.connect(close)
	row.add_child(power)


## Menu de aplicativos (estilo Whisker Menu): busca no topo, categorias à
## esquerda, apps à direita e o usuário embaixo.
func _build_app_menu() -> void:
	_app_menu = PanelContainer.new()
	_app_menu.visible = false
	_app_menu.position = Vector2(4, TASKBAR_HEIGHT + 2)
	_app_menu.custom_minimum_size = Vector2(500, 430)
	var style := StyleBoxFlat.new()
	style.bg_color = C_MENU
	style.border_color = Color(1, 1, 1, 0.08)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	_app_menu.add_theme_stylebox_override("panel", style)
	_root.add_child(_app_menu)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_app_menu.add_child(column)

	_menu_search = LineEdit.new()
	_menu_search.placeholder_text = "Buscar aplicativo..."
	_menu_search.clear_button_enabled = true
	var search_style := StyleBoxFlat.new()
	search_style.bg_color = Color(0.07, 0.08, 0.1)
	search_style.border_color = C_KALI_BLUE
	search_style.set_border_width_all(1)
	search_style.set_corner_radius_all(14)
	search_style.content_margin_left = 14
	search_style.content_margin_right = 10
	search_style.content_margin_top = 4
	search_style.content_margin_bottom = 4
	_menu_search.add_theme_stylebox_override("normal", search_style)
	_menu_search.add_theme_stylebox_override("focus", search_style)
	_menu_search.add_theme_color_override("font_color", C_TEXT)
	_menu_search.text_changed.connect(func(_text: String) -> void: _render_menu_apps())
	column.add_child(_menu_search)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	column.add_child(body)
	var side := PanelContainer.new()
	var side_style := StyleBoxFlat.new()
	side_style.bg_color = C_MENU_SIDE
	side_style.set_corner_radius_all(4)
	side_style.set_content_margin_all(4)
	side.add_theme_stylebox_override("panel", side_style)
	side.custom_minimum_size = Vector2(230, 0)
	body.add_child(side)
	_menu_categories = VBoxContainer.new()
	_menu_categories.add_theme_constant_override("separation", 0)
	side.add_child(_menu_categories)
	for category in MENU_CATEGORIES:
		var button := _menu_row(String(category[1]), 12)
		button.pressed.connect(func() -> void:
			_menu_category = String(category[0])
			_menu_search.text = ""
			_render_menu_apps())
		button.set_meta("category", String(category[0]))
		_menu_categories.add_child(button)
	var apps_panel := PanelContainer.new()
	apps_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apps_panel.add_theme_stylebox_override("panel", side_style)
	body.add_child(apps_panel)
	_menu_list = VBoxContainer.new()
	_menu_list.add_theme_constant_override("separation", 0)
	apps_panel.add_child(_menu_list)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	column.add_child(footer)
	var avatar := CyberIcon.new()
	avatar.kind = CyberIcon.Kind.PERSON
	avatar.color = C_KALI_BLUE
	avatar.custom_minimum_size = Vector2(22, 22)
	footer.add_child(avatar)
	_menu_user = Label.new()
	_menu_user.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_user.add_theme_color_override("font_color", C_TEXT)
	_menu_user.add_theme_font_size_override("font_size", 13)
	footer.add_child(_menu_user)
	var all_apps := _panel_button(CyberIcon.Kind.GRID, C_TEXT_DIM, "Todos os aplicativos")
	all_apps.pressed.connect(func() -> void:
		_menu_category = "all"
		_render_menu_apps())
	footer.add_child(all_apps)
	var off := _panel_button(CyberIcon.Kind.POWER, C_KALI_BLUE, "Desligar o computador")
	off.pressed.connect(close)
	footer.add_child(off)


func _toggle_app_menu() -> void:
	_app_menu.visible = not _app_menu.visible
	if _app_menu.visible:
		SoundManager.play("blip")
		_menu_category = "fav"
		_menu_search.text = ""
		var who: String = Leaderboard.player_name.to_lower() if Leaderboard.player_name != "" else "agente"
		_menu_user.text = who
		_render_menu_apps()


## Lista da direita do menu: os apps instalados neste laboratório que estão na
## categoria escolhida (ou que batem com a busca).
func _render_menu_apps() -> void:
	for child in _menu_list.get_children():
		_menu_list.remove_child(child)
		child.queue_free()
	var query: String = _menu_search.text.strip_edges().to_lower()
	for button in _menu_categories.get_children():
		var selected: bool = query == "" and String(button.get_meta("category")) == _menu_category
		button.add_theme_stylebox_override("normal", _row_style(C_KALI_BLUE.darkened(0.35) if selected else Color(0, 0, 0, 0)))

	var ids: Array = []
	if query == "" and _menu_category == "recent":
		ids = _recent.filter(func(id) -> bool: return _apps.has(id))
	else:
		for app in APP_INFO:
			if not _apps.has(app):
				continue
			var info: Array = APP_INFO[app]
			var matches: bool
			if query != "":
				matches = String(info[1]).to_lower().contains(query) or String(APPS[app][1]).to_lower().contains(query)
			else:
				matches = _menu_category == "all" or (info[3] as Array).has(_menu_category)
			if matches:
				ids.append(app)

	if ids.is_empty():
		var empty := Label.new()
		empty.text = "Nenhum aplicativo aqui neste laboratório." if query == "" else "Nada encontrado."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(220, 0)
		empty.add_theme_color_override("font_color", C_TEXT_DIM)
		empty.add_theme_font_size_override("font_size", 12)
		_menu_list.add_child(empty)
		return
	for app in ids:
		var info: Array = APP_INFO[app]
		var button := _menu_row("      " + String(info[1]), 13)
		var glyph := CyberIcon.new()
		glyph.kind = info[0]
		glyph.color = info[2]
		glyph.line_width = 1.4
		glyph.position = Vector2(6, 5)
		glyph.size = Vector2(18, 18)
		button.add_child(glyph)
		button.pressed.connect(func() -> void:
			_app_menu.visible = false
			open_app(String(app)))
		_menu_list.add_child(button)


func _menu_row(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.custom_minimum_size = Vector2(0, 21 if font_size <= 12 else 28)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", C_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _row_style(Color(0, 0, 0, 0)))
	button.add_theme_stylebox_override("hover", _row_style(C_HOVER))
	button.add_theme_stylebox_override("pressed", _row_style(C_KALI_BLUE.darkened(0.2)))
	return button


func _row_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 6
	return style


func _switch_workspace(index: int) -> void:
	_workspace = index
	# As janelas e o recado ficam na área 1; as outras áreas estão vazias.
	_windows.visible = index == 1
	_note.visible = index == 1 and _note_label.text != ""
	for i in _workspace_buttons.size():
		var active: bool = i + 1 == index
		var button: Button = _workspace_buttons[i]
		button.add_theme_stylebox_override("normal", _row_style(C_KALI_BLUE if active else Color(0, 0, 0, 0)))
		button.add_theme_stylebox_override("hover", _row_style(C_KALI_BLUE if active else C_HOVER))
		button.add_theme_stylebox_override("pressed", _row_style(C_KALI_BLUE))
		button.add_theme_color_override("font_color", Color.WHITE if active else C_TEXT_DIM)


func _panel_button(kind: int, color: Color, tip: String) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(28, 30)
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", _row_style(C_HOVER))
	button.add_theme_stylebox_override("pressed", _row_style(Color(1, 1, 1, 0.14)))
	var glyph := CyberIcon.new()
	glyph.kind = kind
	glyph.color = color
	glyph.line_width = 1.5
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.offset_left = 6
	glyph.offset_top = 7
	glyph.offset_right = -6
	glyph.offset_bottom = -7
	button.add_child(glyph)
	return button


func _panel_separator() -> Control:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.12)
	line.custom_minimum_size = Vector2(1, 18)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var holder := MarginContainer.new()
	holder.add_theme_constant_override("margin_left", 4)
	holder.add_theme_constant_override("margin_right", 4)
	holder.add_child(line)
	return holder


## Ícone da área de trabalho: desenho do app e o nome embaixo, como no Xfce.
func _make_icon(app: String, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = ""
	button.tooltip_text = title
	button.custom_minimum_size = Vector2(84, 74)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", _row_style(Color(1, 1, 1, 0.12)))
	button.add_theme_stylebox_override("pressed", _row_style(Color(0.21, 0.48, 0.94, 0.35)))
	var info: Array = APP_INFO.get(app, [CyberIcon.Kind.MONITOR, title, C_TEXT, []])
	var glyph := CyberIcon.new()
	glyph.kind = info[0]
	glyph.color = info[2]
	glyph.line_width = 2.0
	glyph.position = Vector2(22, 6)
	glyph.size = Vector2(40, 40)
	button.add_child(glyph)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.position = Vector2(0, 50)
	label.size = Vector2(84, 20)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	return button
