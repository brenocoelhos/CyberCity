extends CanvasLayer
## NamePrompt.gd
## Janelinha "qual é o seu nome?": um campo de texto e um botão. Usada no
## telefonema da abertura (IntroCall.gd). Segura o jogo parado enquanto aberta.
## Quando o jogador confirma, emite "confirmed" com o nome já limpo (até 10
## letras; vazio vira "JOGADOR") e se apaga.

signal confirmed(player_name: String)

var _field: LineEdit


func _ready() -> void:
	layer = 40
	HUD.set_overlay_active(true)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.01, 0.03, 0.06, 0.78)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"FlatPanel"
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "QUAL É O SEU NOME, AGENTE?"
	title.theme_type_variation = &"HudTitle"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_field = LineEdit.new()
	_field.max_length = Leaderboard.MAX_NAME_LENGTH
	_field.placeholder_text = Leaderboard.DEFAULT_NAME
	_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_field.add_theme_font_size_override("font_size", 22)
	_field.text_submitted.connect(func(_text: String) -> void: _confirm())
	box.add_child(_field)

	var hint := Label.new()
	hint.text = "Este nome aparece no placar. Até %d letras." % Leaderboard.MAX_NAME_LENGTH
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("#5f8f6a"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	var button := Button.new()
	button.text = "Confirmar"
	button.custom_minimum_size = Vector2(0, 42)
	button.pressed.connect(_confirm)
	box.add_child(button)

	_field.grab_focus.call_deferred()


func _confirm() -> void:
	SoundManager.play("interact")
	var chosen: String = Leaderboard.clean_name(_field.text)
	HUD.set_overlay_active(false)
	confirmed.emit(chosen)
	queue_free()
