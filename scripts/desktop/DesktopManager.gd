extends CanvasLayer
## DesktopManager.gd — Autoload
## O computador como um desktop de verdade: papel de parede, ícones, barra de
## tarefas e janelas (Terminal e Navegador). O jogador abre o navegador, vê o
## que está acontecendo, abre o terminal, e segue o processo completo.
##
## Quem abre o desktop é o computador (Computer.gd), e só quando o desafio dele
## tem "desktop": true no ChallengeData (hoje, só o piloto c_site). Os outros
## computadores continuam abrindo só o terminal.
##
## O terminal é o TerminalManager de sempre (em "desktop_mode": fechar/ESC só
## minimiza). Terminal e navegador compartilham a mesma sessão do desafio.
##
## PROVISÓRIO: ícones e papel de parede são de teste; a Arte pode trocar.

const Browser := preload("res://scripts/desktop/Browser.gd")

const C_ACCENT := Color("#2f8cff")
const C_GREEN := Color("#3dff6e")
const C_TASKBAR := Color("#0b1622")
const TASKBAR_HEIGHT := 36.0

var _open: bool = false
var _challenge: Dictionary = {}
var _terminal_shown: bool = false
var _browser_opened: bool = false

var _root: Control
var _browser: Panel
var _note: PanelContainer
var _note_label: Label
var _terminal_task: Button
var _browser_task: Button
var _clock: Label


func _ready() -> void:
	layer = 8
	visible = false
	_build()


func is_open() -> bool:
	return _open


## Abre o desktop do computador deste desafio.
func open(challenge_id: String, host: String) -> void:
	_challenge = ChallengeData.get_challenge(challenge_id)
	_terminal_shown = false
	_browser_opened = false
	TerminalManager.desktop_mode = true
	TerminalManager.start_session(challenge_id, host)
	_open = true
	visible = true
	_update_note()
	_show_app("")
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.2)
	SoundManager.play("blip")


## Desliga o desktop (e encerra a sessão do terminal).
func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	_browser.visible = false
	if TerminalManager.desktop_mode:
		TerminalManager.close()


func _process(_delta: float) -> void:
	if not _open:
		return
	_clock.text = Time.get_time_string_from_system().substr(0, 5)
	_refresh_taskbar()


## ESC: minimiza o navegador; com tudo minimizado, desliga o desktop. (Com o
## terminal na tela, é ele quem trata o ESC.)
func _input(event: InputEvent) -> void:
	if not _open or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ESCAPE or TerminalManager.is_window_visible():
		return
	if _browser.visible:
		_show_app("")
	else:
		close()
	get_viewport().set_input_as_handled()


# --- Janelas -------------------------------------------------------------------

## Mostra um app ("terminal", "browser") e minimiza o outro; "" = só o desktop.
func _show_app(app: String) -> void:
	if app != "terminal" and TerminalManager.is_window_visible():
		TerminalManager.minimize()
	_browser.visible = app == "browser"
	if app == "terminal":
		if _terminal_shown:
			TerminalManager.restore_window()
		else:
			_terminal_shown = true
			TerminalManager.show_window()
	elif app == "browser":
		if not _browser_opened:
			_browser_opened = true
			_browser.open_for(_challenge)
		SoundManager.play("blip")
	_refresh_taskbar()


func _toggle_app(app: String) -> void:
	var showing: bool = TerminalManager.is_window_visible() if app == "terminal" else _browser.visible
	_show_app("" if showing else app)


func _refresh_taskbar() -> void:
	_terminal_task.set_pressed_no_signal(TerminalManager.is_window_visible())
	_browser_task.set_pressed_no_signal(_browser.visible)
	_note.visible = not _browser.visible and not TerminalManager.is_window_visible() and _note_label.text != ""


## O recado do desafio na mesa, conforme o nível de guia (3 = nenhum).
func _update_note() -> void:
	var guidance: int = clampi(int(_challenge.get("guidance", 1)), 1, 3)
	var text := ""
	if guidance == 1:
		text = String(_challenge.get("desktop_intro", ""))
	elif guidance == 2:
		text = "Computador aberto. Use o Navegador e o Terminal."
	_note_label.text = text


# --- Montagem -------------------------------------------------------------------

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
	icons.add_child(_make_icon(">_", "Terminal", func() -> void: _show_app("terminal")))
	icons.add_child(_make_icon("www", "Navegador", func() -> void: _show_app("browser")))

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

	# Navegador
	_browser = Browser.new()
	_browser.position = Vector2(90, 36)
	_browser.size = Vector2(1100, 648)
	_browser.visible = false
	_browser.close_requested.connect(func() -> void: _show_app(""))
	_root.add_child(_browser)

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
	_terminal_task = _make_task("Terminal", "terminal")
	row.add_child(_terminal_task)
	_browser_task = _make_task("Navegador", "browser")
	row.add_child(_browser_task)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_clock = Label.new()
	row.add_child(_clock)
	var power := Button.new()
	power.text = "Desligar"
	power.tooltip_text = "Fecha o computador (ESC na área de trabalho)"
	power.pressed.connect(close)
	row.add_child(power)


func _make_task(title: String, app: String) -> Button:
	var button := Button.new()
	button.text = title
	button.toggle_mode = true
	button.pressed.connect(func() -> void: _toggle_app(app))
	return button


func _make_icon(glyph: String, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [glyph, title]
	button.custom_minimum_size = Vector2(110, 84)
	button.flat = true
	button.add_theme_color_override("font_color", Color("#e8ece9"))
	button.add_theme_color_override("font_hover_color", C_GREEN)
	button.pressed.connect(action)
	return button
