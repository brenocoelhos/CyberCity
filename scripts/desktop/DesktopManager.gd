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

const C_ACCENT := Color("#2f8cff")
const C_GREEN := Color("#3dff6e")
const C_TASKBAR := Color("#0b1622")
const TASKBAR_HEIGHT := 36.0
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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_focus_at(event.position)
		else:
			_drag = {}
			_resize = {}
	elif event is InputEventMouseMotion:
		if not _drag.is_empty():
			var node: Control = _drag["node"]
			node.position = _clamp_position(event.position - Vector2(_drag["offset"]), node.size)
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

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Papel de parede: degradê escuro com o nome do sistema.
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#0a2748"), Color("#04070d")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0)
	texture.fill_to = Vector2(0.5, 1)
	var wallpaper := TextureRect.new()
	wallpaper.texture = texture
	wallpaper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wallpaper.stretch_mode = TextureRect.STRETCH_SCALE
	wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(wallpaper)

	var logo := Label.new()
	logo.text = "CYBER-OS"
	logo.set_anchors_preset(Control.PRESET_CENTER)
	logo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	logo.grow_vertical = Control.GROW_DIRECTION_BOTH
	logo.add_theme_font_size_override("font_size", 72)
	logo.add_theme_color_override("font_color", Color(0.18, 0.55, 1.0, 0.12))
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(logo)

	# Ícones
	var icons := VBoxContainer.new()
	icons.position = Vector2(20, 20)
	icons.add_theme_constant_override("separation", 14)
	_root.add_child(icons)
	for app in APPS:
		var icon: Button = _make_icon(String(APPS[app][0]), String(APPS[app][1]), func() -> void: open_app(String(app)))
		_icons[app] = icon
		icons.add_child(icon)

	# Recado do desafio
	_note = PanelContainer.new()
	_note.position = Vector2(170, 24)
	_note.custom_minimum_size = Vector2(360, 0)
	var note_style := StyleBoxFlat.new()
	note_style.bg_color = Color("#14202e")
	note_style.border_color = Color("#ffd75f")
	note_style.set_border_width_all(2)
	note_style.set_content_margin_all(12)
	_note.add_theme_stylebox_override("panel", note_style)
	_root.add_child(_note)
	_note_label = Label.new()
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.custom_minimum_size = Vector2(336, 0)
	_note_label.add_theme_color_override("font_color", Color("#ffd75f"))
	_note.add_child(_note_label)

	# Área das janelas (cobre a tela inteira, mas só as janelas pegam o mouse)
	_windows = Control.new()
	_windows.set_anchors_preset(Control.PRESET_FULL_RECT)
	_windows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_windows)

	# Barra de tarefas
	var taskbar := PanelContainer.new()
	taskbar.anchor_top = 1.0
	taskbar.anchor_right = 1.0
	taskbar.anchor_bottom = 1.0
	taskbar.offset_top = -TASKBAR_HEIGHT
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = C_TASKBAR
	bar_style.border_color = C_ACCENT
	bar_style.border_width_top = 2
	bar_style.content_margin_left = 10
	bar_style.content_margin_right = 10
	taskbar.add_theme_stylebox_override("panel", bar_style)
	_root.add_child(taskbar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	taskbar.add_child(row)
	var brand := Label.new()
	brand.text = "CYBER-OS"
	brand.add_theme_color_override("font_color", C_GREEN)
	row.add_child(brand)
	_task_row = HBoxContainer.new()
	_task_row.add_theme_constant_override("separation", 6)
	_task_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_task_row)
	_clock = Label.new()
	row.add_child(_clock)
	var power := Button.new()
	power.text = "Desligar"
	power.focus_mode = Control.FOCUS_NONE
	power.tooltip_text = "Fecha o computador (ESC sem janelas abertas)"
	power.pressed.connect(close)
	row.add_child(power)


func _make_icon(glyph: String, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [glyph, title]
	button.custom_minimum_size = Vector2(110, 84)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", Color("#e8ece9"))
	button.add_theme_color_override("font_hover_color", C_GREEN)
	button.pressed.connect(action)
	return button
