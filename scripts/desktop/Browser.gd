extends "res://scripts/desktop/DesktopWindow.gd"
## Browser.gd
## Navegador do desktop. Mostra as páginas das máquinas simuladas do desafio
## (as mesmas que o 'curl' lê no terminal), só que renderizadas: títulos,
## parágrafos e links clicáveis. O "Código-fonte" mostra o HTML cru, com os
## comentários que a página esconde. Quem fornece as páginas é o
## TerminalManager (browser_fetch).
##
## PROVISÓRIO: o visual é simples; a Arte pode trocar moldura e ícones.

const HtmlLite := preload("res://scripts/desktop/HtmlLite.gd")

const C_PAGE := Color("#eef1ee")
const C_TEXT := Color("#1b1f24")
const C_LINK := "#0b5cd5"


var _challenge: Dictionary = {}
var _history: Array = []
var _index: int = -1
var _showing_source: bool = false
var _current: Dictionary = {}

var _back_button: Button
var _address: LineEdit
var _source_button: Button
var _view: RichTextLabel
var _status: Label
var _scroll: ScrollContainer
var _blocks: VBoxContainer
var _forms: Array = []
var _alert: PanelContainer
var _alert_label: Label


func _ready() -> void:
	kind = "browser"
	min_size = Vector2(520, 340)
	set_title("Navegador")
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
	set_title("Navegador — Nova aba")
	_back_button.disabled = true
	var text := "[font_size=28][b]Nova aba[/b][/font_size]\n\nDigite um endereço na barra acima e pressione Enter.\n"
	var bookmarks: Array = _challenge.get("bookmarks", [])
	if not bookmarks.is_empty() and int(_challenge.get("guidance", 1)) < 3:
		text += "\n[b]Favoritos[/b]\n"
		for bookmark in bookmarks:
			text += "  [url=%s][color=%s][u]%s[/u][/color][/url]\n" % [bookmark["url"], C_LINK, HtmlLite.escape(String(bookmark["title"]))]
	_clear_extra_blocks()
	_view.text = text
	_status.text = "Pronto"


func _render() -> void:
	var status: String = String(_current["status"])
	var path: String = String(_current["path"])
	var text := ""
	var extra_parts: Array = []
	var title := path
	match status:
		"ok":
			var body: String = String(_current["body"])
			if _showing_source:
				text = _code(body)
				title = "Código-fonte de " + path
			elif HtmlLite.looks_like_html(body):
				var parts: Array = HtmlLite.blocks(body)
				text = HtmlLite.render(String(parts[0]["html"]))
				extra_parts = parts.slice(1)
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
	_clear_extra_blocks()
	_view.text = text
	_scroll.scroll_vertical = 0
	# Páginas com formulário: o resto da página vem em blocos depois do primeiro.
	for part in extra_parts:
		if String(part["type"]) == "form":
			_add_form(part)
		else:
			var rendered: String = HtmlLite.render(String(part["html"]))
			if rendered == "":
				continue
			var more: RichTextLabel = _new_text_block()
			more.text = rendered
			_blocks.add_child(more)
	set_title("Navegador — " + title)
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
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	content.add_child(column)

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
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(_scroll)
	_blocks = VBoxContainer.new()
	_blocks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blocks.add_theme_constant_override("separation", 10)
	_scroll.add_child(_blocks)
	_view = _new_text_block()
	_blocks.add_child(_view)

	# Janelinha de alerta da página (como o alert() de um site), escondida.
	_alert = PanelContainer.new()
	_alert.visible = false
	_alert.set_anchors_preset(Control.PRESET_CENTER)
	_alert.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_alert.grow_vertical = Control.GROW_DIRECTION_BOTH
	_alert.custom_minimum_size = Vector2(420, 0)
	_alert.add_theme_stylebox_override("panel", _box(Color("#f4f4f4"), Color("#555b66"), 2))
	var alert_box := VBoxContainer.new()
	alert_box.add_theme_constant_override("separation", 10)
	_alert.add_child(alert_box)
	var alert_title := Label.new()
	alert_title.text = "Aviso da página:"
	alert_title.add_theme_color_override("font_color", Color("#1b1f24"))
	alert_box.add_child(alert_title)
	_alert_label = Label.new()
	_alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_alert_label.custom_minimum_size = Vector2(390, 0)
	_alert_label.add_theme_color_override("font_color", Color("#1b1f24"))
	alert_box.add_child(_alert_label)
	var alert_ok := Button.new()
	alert_ok.text = "OK"
	alert_ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	alert_ok.pressed.connect(func() -> void: _alert.visible = false)
	alert_box.add_child(alert_ok)
	content.add_child(_alert)

	# Barra de status
	_status = Label.new()
	_status.text = "Pronto"
	_status.clip_text = true
	_status.add_theme_color_override("font_color", Color("#5f8f6a"))
	column.add_child(_status)


## Um bloco de texto da página (títulos, parágrafos, links): cresce com o
## conteúdo, e quem rola é a página inteira.
func _new_text_block() -> RichTextLabel:
	var block := RichTextLabel.new()
	block.bbcode_enabled = true
	block.selection_enabled = true
	block.fit_content = true
	block.scroll_active = false
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_color_override("default_color", C_TEXT)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	block.add_theme_font_override("mono_font", mono)
	block.add_theme_color_override("font_selected_color", Color.WHITE)
	block.add_theme_color_override("selection_color", Color("#2f8cff"))
	block.meta_clicked.connect(_on_link)
	return block


## Tira os blocos além do primeiro (formulários e textos de páginas anteriores).
func _clear_extra_blocks() -> void:
	for i in range(_blocks.get_child_count() - 1, 0, -1):
		var child: Node = _blocks.get_child(i)
		_blocks.remove_child(child)
		child.queue_free()
	_forms = []
	_alert.visible = false


## Formulário da página: um rótulo e um campo para cada entrada e o botão de
## enviar. Os dados vão para o "servidor" da máquina (TerminalManager.browser_submit).
func _add_form(form: Dictionary) -> void:
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", _box(Color("#e2e7ea"), Color("#9aa5ad"), 1))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	holder.add_child(column)
	var inputs := {}
	for field in form["fields"]:
		if String(field["kind"]) == "hidden":
			inputs[String(field["name"])] = String(field["value"])
			continue
		var caption: String = String(field["label"]) if String(field["label"]) != "" else String(field["name"])
		var label := Label.new()
		label.text = caption
		label.add_theme_color_override("font_color", C_TEXT)
		column.add_child(label)
		var control: Control
		if String(field["kind"]) == "textarea":
			var area := TextEdit.new()
			area.custom_minimum_size = Vector2(0, 90)
			area.placeholder_text = String(field["placeholder"])
			area.text = String(field["value"])
			area.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			control = area
		else:
			var line := LineEdit.new()
			line.placeholder_text = String(field["placeholder"])
			line.text = String(field["value"])
			line.secret = String(field["kind"]) == "password"
			line.text_submitted.connect(func(_text: String) -> void: _submit_form(form, inputs))
			control = line
		column.add_child(control)
		inputs[String(field["name"])] = control
	var button := Button.new()
	button.text = String(form["submit"])
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(func() -> void: _submit_form(form, inputs))
	column.add_child(button)
	_blocks.add_child(holder)
	_forms.append({"form": form, "inputs": inputs, "button": button})


## Preenche (se "values" vier) e envia o formulário de número "index" da página.
## Serve ao botão e aos testes.
func submit_form(index: int, values: Dictionary = {}) -> void:
	if index < 0 or index >= _forms.size():
		return
	var entry: Dictionary = _forms[index]
	for field_name in values:
		var control: Variant = entry["inputs"].get(field_name)
		if control is LineEdit or control is TextEdit:
			control.text = String(values[field_name])
	_submit_form(entry["form"], entry["inputs"])


func _submit_form(form: Dictionary, inputs: Dictionary) -> void:
	var values := {}
	for field_name in inputs:
		var control: Variant = inputs[field_name]
		values[field_name] = String(control.text) if (control is LineEdit or control is TextEdit) else String(control)
	var host_text: String = _current_host_text()
	var host_name: String = String(_current.get("host", ""))
	if host_name == "" or host_text == "":
		return
	var action: String = String(form["action"])
	if action == "":
		action = String(_current.get("path", "/"))
	var result: Dictionary = TerminalManager.browser_submit(host_name, action, values)
	_current = result
	_showing_source = false
	_source_button.set_pressed_no_signal(false)
	var url: String = "http://" + host_text + String(result["path"])
	_history = _history.slice(0, _index + 1)
	_history.append(url)
	_index = _history.size() - 1
	_address.text = url
	_render()
	_back_button.disabled = _index <= 0
	if result.has("alert"):
		_alert_label.text = String(result["alert"])
		_alert.visible = true
