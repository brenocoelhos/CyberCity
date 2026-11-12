extends "res://scripts/desktop/DesktopWindow.gd"
## MailWindow.gd
## App de E-mail do desktop: caixa de entrada à esquerda, mensagem à direita.
## Como num programa de e-mail de verdade, a mensagem mostra só o resumo
## (remetente, assunto, data); os cabeçalhos completos, onde estão o SPF, o
## DKIM, o Reply-To e a rota, ficam atrás do botão "Cabeçalhos completos".
##
## As mensagens são arquivos do próprio desafio, listados em "mailbox" no
## ChallengeData. O jogador aponta o que achou na barra de baixo (o mesmo que o
## comando 'report' do terminal) ou, em caixas com várias mensagens, com o botão
## "Denunciar como golpe". A resposta do jogo aparece aqui embaixo.
##
## Visual no estilo do Thunderbird (o cliente de e-mail do Kali), tema escuro:
## barra de ferramentas, pastas da conta, caixa de entrada em "cartões" (remetente
## e assunto) e a mensagem com o assunto em destaque.

const MailParser := preload("res://scripts/desktop/MailParser.gd")
const ReportBar := preload("res://scripts/desktop/ReportBar.gd")

const C_DIM := "#8aa0b4"
const TB_BG := Color("#1c1b22")
const TB_PANE := Color("#2b2a33")
const TB_TOOLBAR := Color("#23222b")
const TB_ACCENT := Color("#0a84ff")
const TB_TEXT := Color("#fbfbfe")
const TB_DIM := Color("#a3a3ad")

var _challenge: Dictionary = {}
var _messages: Array = []
var _current: int = -1
var _flagged: Dictionary = {}

var _list: ItemList
var _head_label: RichTextLabel
var _body_label: RichTextLabel
var _raw_button: Button
var _flag_button: Button
var _bar: Control
var _feedback: RichTextLabel   # o da barra de baixo (os testes leem)


func _ready() -> void:
	kind = "mail"
	min_size = Vector2(640, 440)
	set_title("E-mail")
	_build()


## Carrega a caixa de entrada do desafio (arquivos citados em "mailbox").
func open_for(challenge: Dictionary) -> void:
	_challenge = challenge
	_messages = []
	_flagged = {}
	_current = -1
	var files: Dictionary = challenge.get("files", {})
	var mailbox: Array = challenge.get("mailbox", [])
	for i in range(mailbox.size()):
		var file_name: String = String(mailbox[i])
		if files.has(file_name):
			_messages.append(MailParser.parse(file_name, String(files[file_name]), i + 1))
	_flag_button.visible = _messages.size() > 1
	_refresh_list()
	_bar.say("Leia as mensagens. Aponte o que achar de suspeito aqui embaixo.")
	if _messages.size() == 1:
		_list.select(0)
		_show_message(0)
	else:
		_head_label.text = "[color=%s]Selecione uma mensagem da caixa de entrada.[/color]" % C_DIM
		_body_label.text = ""


func message_count() -> int:
	return _messages.size()


## Abre a mensagem do índice dado na caixa de entrada.
func show_message(index: int) -> void:
	if index < 0 or index >= _messages.size():
		return
	_list.select(index)
	_show_message(index)


# --- Mensagem -----------------------------------------------------------------------

func _show_message(index: int) -> void:
	_current = index
	var message: Dictionary = _messages[index]
	if _raw_button.button_pressed:
		_head_label.text = "[code]%s[/code]" % _escape(String(message["headers"]))
	else:
		# Como no Thunderbird: assunto grande, depois De / Para / Data.
		_head_label.text = "[font_size=18][b]%s[/b][/font_size]\n[color=#a3a3ad]De:[/color] [b]%s[/b]\n[color=#a3a3ad]Para:[/color] %s     [color=#a3a3ad]Data:[/color] %s" % [
			_escape(String(message["subject"])), _escape(String(message["from"])),
			_escape(String(message["to"])), _escape(String(message["date"]))]
	_avatar_label.text = MailParser.sender_name(String(message["from"])).substr(0, 1).to_upper()
	_avatar.visible = not _raw_button.button_pressed
	_body_label.text = _escape(String(message["body"]))
	_body_label.scroll_to_line(0)


func _on_raw_toggled(_pressed: bool) -> void:
	if _current >= 0:
		_show_message(_current)


# --- Apontar o que achou ----------------------------------------------------------------

func _on_flag_pressed() -> void:
	if _current < 0:
		_bar.say("Abra uma mensagem antes de denunciar.")
		return
	_report(str(int(_messages[_current]["number"])), int(_messages[_current]["number"]))


func _on_field_submitted(text: String) -> void:
	_bar.submit_text(text)


func _on_help_pressed() -> void:
	_bar.show_checklist()


func _report(answer: String, number: int) -> void:
	var result: Dictionary = _bar.submit(answer)
	if String(result.get("kind", "")) == "hit" and number > 0:
		_flagged[number] = true
		_refresh_list()


# --- Lista -----------------------------------------------------------------------------

func _refresh_list() -> void:
	var keep: int = _current
	_list.clear()
	for message in _messages:
		var prefix := ""
		if _messages.size() > 1:
			prefix = "%d  " % int(message["number"])
		var flag := "[golpe] " if _flagged.has(int(message["number"])) else ""
		_list.add_item("%s%s%s  ·  %s" % [flag, prefix, MailParser.sender_name(String(message["from"])), String(message["subject"])])
	if keep >= 0 and keep < _messages.size():
		_list.select(keep)


func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


# --- Montagem ----------------------------------------------------------------------------

var _avatar: Panel
var _avatar_label: Label


func _build() -> void:
	var page := Panel.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_stylebox_override("panel", _flat(TB_BG))
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(page)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	content.add_child(column)

	# Barra de ferramentas
	var toolbar := PanelContainer.new()
	toolbar.add_theme_stylebox_override("panel", _flat(TB_TOOLBAR, 8, 5))
	column.add_child(toolbar)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	toolbar.add_child(tools)
	var fetch := _tool_button("⟳  Receber", false)
	fetch.pressed.connect(func() -> void: _bar.say("Nenhuma mensagem nova no servidor."))
	tools.add_child(fetch)
	var write := _tool_button("✎  Escrever", true)
	write.tooltip_text = "Neste laboratório o e-mail é só para análise."
	write.pressed.connect(func() -> void: _bar.say("Este laboratório é só de análise: não dá para enviar e-mails."))
	tools.add_child(write)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(gap)
	var search := LineEdit.new()
	search.placeholder_text = "Pesquisar  <Ctrl+K>"
	search.custom_minimum_size = Vector2(220, 0)
	search.editable = false
	search.focus_mode = Control.FOCUS_NONE
	var search_style := _flat(Color("#1c1b22"), 10, 3)
	search_style.set_corner_radius_all(4)
	search_style.border_color = Color("#52525e")
	search_style.set_border_width_all(1)
	search.add_theme_stylebox_override("read_only", search_style)
	search.add_theme_stylebox_override("normal", search_style)
	tools.add_child(search)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(split)

	# Pastas da conta (só a Entrada tem algo neste laboratório)
	var folders := PanelContainer.new()
	folders.custom_minimum_size = Vector2(150, 0)
	folders.add_theme_stylebox_override("panel", _flat(TB_TOOLBAR, 8, 8))
	split.add_child(folders)
	var folder_list := VBoxContainer.new()
	folder_list.add_theme_constant_override("separation", 4)
	folders.add_child(folder_list)
	_folder_label(folder_list, "agente@cybercity.lab", TB_DIM, 11)
	_folder_label(folder_list, "  Entrada", TB_TEXT, 13, true)
	for name_text in ["  Rascunhos", "  Enviados", "  Arquivo", "  Spam", "  Lixeira"]:
		_folder_label(folder_list, name_text, TB_DIM, 13)

	var inner := HSplitContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(inner)

	# Caixa de entrada: cartões de duas linhas
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(240, 0)
	_list.auto_height = false
	_list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_list.add_theme_stylebox_override("panel", _flat(TB_PANE, 4, 4))
	_list.add_theme_stylebox_override("selected", _flat(Color("#0a84ff").darkened(0.35)))
	_list.add_theme_stylebox_override("selected_focus", _flat(Color("#0a84ff").darkened(0.25)))
	_list.add_theme_stylebox_override("hovered", _flat(Color(1, 1, 1, 0.06)))
	_list.add_theme_color_override("font_color", TB_TEXT)
	_list.add_theme_color_override("font_selected_color", Color.WHITE)
	_list.add_theme_constant_override("v_separation", 16)
	_list.add_theme_constant_override("line_separation", 3)
	_list.item_selected.connect(_show_message)
	inner.add_child(_list)

	# Mensagem
	var reader := PanelContainer.new()
	reader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reader.add_theme_stylebox_override("panel", _flat(TB_BG, 14, 10))
	inner.add_child(reader)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	reader.add_child(right)

	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 10)
	right.add_child(head_row)
	_avatar = Panel.new()
	var avatar_style := _flat(Color("#7e57c2"))
	avatar_style.set_corner_radius_all(20)
	_avatar.add_theme_stylebox_override("panel", avatar_style)
	_avatar.custom_minimum_size = Vector2(40, 40)
	_avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_avatar.visible = false
	head_row.add_child(_avatar)
	_avatar_label = Label.new()
	_avatar_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avatar_label.add_theme_font_size_override("font_size", 18)
	_avatar.add_child(_avatar_label)

	_head_label = RichTextLabel.new()
	_head_label.bbcode_enabled = true
	_head_label.fit_content = true
	_head_label.scroll_active = false
	_head_label.selection_enabled = true
	_head_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head_label.add_theme_color_override("default_color", TB_TEXT)
	var mono: SystemFont = mono_font()
	_head_label.add_theme_font_override("mono_font", mono)
	_head_label.add_theme_font_size_override("mono_font_size", 12)
	head_row.add_child(_head_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	right.add_child(buttons)
	for label in ["↩ Responder", "↪ Encaminhar", "Arquivar"]:
		var action := _tool_button(label, false)
		action.pressed.connect(func() -> void: _bar.say("Neste laboratório o e-mail é só para análise."))
		buttons.add_child(action)
	_raw_button = _tool_button("Cabeçalhos completos", false)
	_raw_button.toggle_mode = true
	_raw_button.tooltip_text = "Mostra todos os cabeçalhos da mensagem (rota, SPF, DKIM, Reply-To...)"
	_raw_button.toggled.connect(_on_raw_toggled)
	buttons.add_child(_raw_button)
	_flag_button = _tool_button("⚠ Denunciar como golpe", false)
	_flag_button.add_theme_color_override("font_color", Color("#ff6b6b"))
	_flag_button.pressed.connect(_on_flag_pressed)
	buttons.add_child(_flag_button)

	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.1)
	line.custom_minimum_size = Vector2(0, 1)
	right.add_child(line)

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.selection_enabled = true
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.add_theme_color_override("default_color", Color("#e8e8ee"))
	_body_label.add_theme_font_size_override("normal_font_size", 14)
	right.add_child(_body_label)

	# Barra de baixo: apontar o que achou (a mesma dos outros apps de análise)
	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", _flat(TB_TOOLBAR, 8, 6))
	column.add_child(bottom)
	_bar = ReportBar.new()
	_feedback = _bar.feedback
	bottom.add_child(_bar)


func _flat(color: Color, margin_x: int = 0, margin_y: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	return style


func _tool_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	var normal := _flat(TB_ACCENT if primary else Color("#3a3944"), 10, 4)
	normal.set_corner_radius_all(4)
	var hover := _flat((TB_ACCENT if primary else Color("#3a3944")).lightened(0.15), 10, 4)
	hover.set_corner_radius_all(4)
	var pressed := _flat(TB_ACCENT.darkened(0.2), 10, 4)
	pressed.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_color_override("font_color", TB_TEXT)
	button.add_theme_font_size_override("font_size", 12)
	return button


func _folder_label(parent: Node, text: String, color: Color, font_size: int, selected: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if selected:
		label.add_theme_stylebox_override("normal", _flat(TB_ACCENT.darkened(0.45), 6, 3))
	label.clip_text = true
	parent.add_child(label)
