extends Panel
## Browser.gd
## Navegador do desktop. Mostra as páginas das máquinas simuladas do desafio
## (as mesmas que o 'curl' lê no terminal), só que renderizadas: títulos,
## parágrafos e links clicáveis. O "Código-fonte" mostra o HTML cru, com os
## comentários que a página esconde. Quem fornece as páginas é o
## TerminalManager (browser_fetch).
##
## PROVISÓRIO: o visual é simples; a Arte pode trocar moldura e ícones.

const HtmlLite := preload("res://scripts/desktop/HtmlLite.gd")

const C_BG := Color("#0a1420")
const C_BORDER := Color("#2f8cff")
const C_TITLE := Color("#122238")
const C_PAGE := Color("#eef1ee")
const C_TEXT := Color("#1b1f24")
const C_LINK := "#0b5cd5"

signal close_requested

var _challenge: Dictionary = {}
var _history: Array = []
var _index: int = -1
var _showing_source: bool = false
var _current: Dictionary = {}

var _title_label: Label
var _back_button: Button
var _address: LineEdit
var _source_button: Button
var _view: RichTextLabel
var _status: Label


func _ready() -> void:
	_build()


## Abre o navegador para o computador deste desafio (histórico limpo, aba nova).
func open_for(challenge: Dictionary) -> void:
	_challenge = challenge
	_history = []
	_index = -1
	_current = {}
	_showing_source = false
	_source_button.set_pressed_no_signal(false)
	_show_start_page()


## Vai para o endereço (ou caminho, como "/robots.txt", dentro do site atual).
func navigate(address: String, push: bool = true) -> void:
	var url: String = _normalize(address)
	if url == "":
		return
	_current = TerminalManager.browser_fetch(url)
	_showing_source = false
	_source_button.set_pressed_no_signal(false)
	if push:
		_history = _history.slice(0, _index + 1)
		_history.append(url)
		_index = _history.size() - 1
	_address.text = url
	_render()
	_back_button.disabled = _index <= 0
	if String(_current["status"]) == "ok":
		_notify_loaded(String(_current["host"]), String(_current["path"]))


func _notify_loaded(host_name: String, path: String) -> void:
	# Um instante para o jogador ver a página antes de o desafio terminar.
	await get_tree().create_timer(1.0).timeout
	if DesktopManager.is_open():
		TerminalManager.browser_loaded(host_name, path)


# --- Endereço ------------------------------------------------------------------

func _normalize(address: String) -> String:
	var text: String = address.strip_edges()
	if text == "":
		return ""
	if text.begins_with("/"):
		var base: String = _current_host_text()
		if base == "":
			return ""
		return "http://" + base + text
	if not (text.begins_with("http://") or text.begins_with("https://")):
		text = "http://" + text
	var rest: String = text.trim_prefix("http://").trim_prefix("https://")
	if rest.find("/") == -1:
		text += "/"
	return text


## O "host" do endereço atual, como o jogador o escreveu (ex.: 192.168.1.50).
func _current_host_text() -> String:
	if _index < 0:
		return ""
	var rest: String = String(_history[_index]).trim_prefix("http://").trim_prefix("https://")
	var slash: int = rest.find("/")
	return rest if slash == -1 else rest.substr(0, slash)


# --- Páginas -------------------------------------------------------------------

func _show_start_page() -> void:
	_address.text = ""
	_title_label.text = "Navegador — Nova aba"
	_back_button.disabled = true
	var text := "[font_size=28][b]Nova aba[/b][/font_size]\n\nDigite um endereço na barra acima e pressione Enter.\n"
	var bookmarks: Array = _challenge.get("bookmarks", [])
	if not bookmarks.is_empty() and int(_challenge.get("guidance", 1)) < 3:
		text += "\n[b]Favoritos[/b]\n"
		for bookmark in bookmarks:
			text += "  [url=%s][color=%s][u]%s[/u][/color][/url]\n" % [bookmark["url"], C_LINK, HtmlLite.escape(String(bookmark["title"]))]
	_view.text = text
	_status.text = "Pronto"


func _render() -> void:
	var status: String = String(_current["status"])
	var path: String = String(_current["path"])
	var text := ""
	var title := path
	match status:
		"ok":
			var body: String = String(_current["body"])
			if _showing_source:
				text = _code(body)
				title = "Código-fonte de " + path
			elif HtmlLite.looks_like_html(body):
				text = HtmlLite.render(body)
				title = HtmlLite.title_of(body)
				if title == "":
					title = path
			elif body.begins_with("Index of"):
				text = _render_index(body, path)
				title = "Índice de " + path
			else:
				text = _code(body)
		"notfound":
			text = "[font_size=28][b]404 — Página não encontrada[/b][/font_size]\n\nO servidor não tem nada em [b]%s[/b]." % HtmlLite.escape(path)
			title = "404"
		"scope":
			text = "[font_size=28][b]Acesso bloqueado[/b][/font_size]\n\nO servidor [b]%s[/b] está FORA do escopo autorizado deste teste. Acessar sistemas sem autorização é crime." % HtmlLite.escape(String(_current["host"]))
			title = "Acesso bloqueado"
		_:
			text = "[font_size=28][b]Não foi possível acessar este site[/b][/font_size]\n\nNão encontramos o servidor [b]%s[/b]. Confira se o endereço está certo." % HtmlLite.escape(String(_current["host"]))
			title = "Erro"
	_view.text = text
	_view.scroll_to_line(0)
	_title_label.text = "Navegador — " + title
	_status.text = ("Carregado: " if status == "ok" else "Erro: ") + _address.text


## Página de índice de pasta ("Index of /legado/"): cada arquivo vira um link.
func _render_index(body: String, path: String) -> String:
	var lines: PackedStringArray = body.split("\n")
	var out := "[font_size=24][b]%s[/b][/font_size]\n\n" % HtmlLite.escape(lines[0])
	for i in range(1, lines.size()):
		var line: String = lines[i].strip_edges()
		if line == "":
			continue
		var file_name: String = line.get_slice(" ", 0)
		var rest: String = line.substr(file_name.length())
		out += "[url=%s%s][color=%s][u]%s[/u][/color][/url]%s\n" % [path, file_name, C_LINK, HtmlLite.escape(file_name), HtmlLite.escape(rest)]
	return out


func _code(text: String) -> String:
	return "[code]%s[/code]" % HtmlLite.escape(text)


# --- Botões --------------------------------------------------------------------

func _on_back() -> void:
	if _index <= 0:
		return
	_index -= 1
	navigate(String(_history[_index]), false)


func _on_source_toggled(pressed: bool) -> void:
	if _current.is_empty() or String(_current["status"]) != "ok":
		_source_button.set_pressed_no_signal(false)
		return
	_showing_source = pressed
	_render()


func _on_link(meta: Variant) -> void:
	SoundManager.play("blip")
	navigate(String(meta))


# --- Montagem da janela ----------------------------------------------------------

func _build() -> void:
	add_theme_stylebox_override("panel", _box(C_BG, C_BORDER, 2))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)

	# Barra de título
	var title_bar := PanelContainer.new()
	title_bar.add_theme_stylebox_override("panel", _box(C_TITLE))
	title_bar.custom_minimum_size = Vector2(0, 32)
	column.add_child(title_bar)
	var title_row := HBoxContainer.new()
	title_bar.add_child(title_row)
	_title_label = Label.new()
	_title_label.text = "Navegador"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_color_override("font_color", Color("#e8ece9"))
	title_row.add_child(_title_label)
	var close := Button.new()
	close.text = " X "
	close.tooltip_text = "Minimizar (ESC)"
	close.pressed.connect(func() -> void: close_requested.emit())
	title_row.add_child(close)

	# Barra de ferramentas
	var tools := PanelContainer.new()
	tools.add_theme_stylebox_override("panel", _box(Color("#0e1b2c")))
	column.add_child(tools)
	var tool_row := HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 8)
	tools.add_child(tool_row)
	_back_button = Button.new()
	_back_button.text = " < "
	_back_button.tooltip_text = "Voltar"
	_back_button.disabled = true
	_back_button.pressed.connect(_on_back)
	tool_row.add_child(_back_button)
	_address = LineEdit.new()
	_address.placeholder_text = "Digite o endereço e pressione Enter"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address.text_submitted.connect(func(text: String) -> void: navigate(text))
	tool_row.add_child(_address)
	var go := Button.new()
	go.text = " Ir "
	go.pressed.connect(func() -> void: navigate(_address.text))
	tool_row.add_child(go)
	_source_button = Button.new()
	_source_button.text = "Código-fonte"
	_source_button.toggle_mode = true
	_source_button.tooltip_text = "Mostra o HTML da página, inclusive os comentários"
	_source_button.toggled.connect(_on_source_toggled)
	tool_row.add_child(_source_button)

	# Página
	var page := PanelContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_stylebox_override("panel", _box(C_PAGE))
	column.add_child(page)
	_view = RichTextLabel.new()
	_view.bbcode_enabled = true
	_view.selection_enabled = true
	_view.scroll_following = false
	_view.add_theme_color_override("default_color", C_TEXT)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	_view.add_theme_font_override("mono_font", mono)
	_view.add_theme_color_override("font_selected_color", Color.WHITE)
	_view.add_theme_color_override("selection_color", Color("#2f8cff"))
	_view.meta_clicked.connect(_on_link)
	page.add_child(_view)

	# Barra de status
	_status = Label.new()
	_status.text = "Pronto"
	_status.add_theme_color_override("font_color", Color("#5f8f6a"))
	column.add_child(_status)


func _box(fill: Color, border: Color = Color(0, 0, 0, 0), width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	if width > 0:
		style.border_color = border
		style.set_border_width_all(width)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
