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
## PROVISÓRIO: o visual é simples; a Arte pode trocar.

const MailParser := preload("res://scripts/desktop/MailParser.gd")
const ReportBar := preload("res://scripts/desktop/ReportBar.gd")

const C_DIM := "#8aa0b4"

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
		_head_label.text = "[b]De:[/b] %s\n[b]Para:[/b] %s\n[b]Assunto:[/b] %s\n[b]Data:[/b] %s" % [
			_escape(String(message["from"])), _escape(String(message["to"])),
			_escape(String(message["subject"])), _escape(String(message["date"]))]
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
		_list.add_item("%s%s%s — %s" % [flag, prefix, MailParser.sender_name(String(message["from"])), String(message["subject"])])
	if keep >= 0 and keep < _messages.size():
		_list.select(keep)


func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


# --- Montagem ----------------------------------------------------------------------------

func _build() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	content.add_child(column)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(split)

	# Caixa de entrada
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(270, 0)
	_list.auto_height = false
	_list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_list.item_selected.connect(_show_message)
	split.add_child(_list)

	# Mensagem
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	split.add_child(right)

	_head_label = RichTextLabel.new()
	_head_label.bbcode_enabled = true
	_head_label.fit_content = true
	_head_label.scroll_active = false
	_head_label.selection_enabled = true
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	_head_label.add_theme_font_override("mono_font", mono)
	_head_label.add_theme_font_size_override("mono_font_size", 12)
	right.add_child(_head_label)

	var buttons := HBoxContainer.new()
	right.add_child(buttons)
	_raw_button = Button.new()
	_raw_button.text = "Cabeçalhos completos"
	_raw_button.toggle_mode = true
	_raw_button.tooltip_text = "Mostra todos os cabeçalhos da mensagem (rota, SPF, DKIM, Reply-To...)"
	_raw_button.toggled.connect(_on_raw_toggled)
	buttons.add_child(_raw_button)
	_flag_button = Button.new()
	_flag_button.text = "Denunciar como golpe"
	_flag_button.pressed.connect(_on_flag_pressed)
	buttons.add_child(_flag_button)

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.selection_enabled = true
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_body_label)

	# Barra de baixo: apontar o que achou (a mesma dos outros apps de análise)
	_bar = ReportBar.new()
	_feedback = _bar.feedback
	column.add_child(_bar)
