extends Panel
## DesktopWindow.gd
## Moldura de janela do desktop: barra de título com os botões minimizar,
## maximizar e fechar, e uma área de conteúdo embaixo. Os apps (Navegador,
## Notas) herdam daqui e colocam o que querem em "content". Arrastar,
## redimensionar e a ordem das janelas ficam com o DesktopManager.
##
## PROVISÓRIO: visual simples; a Arte pode trocar a moldura.

signal title_changed

const C_BG := Color("#0a1420")
const C_BORDER := Color("#2f8cff")
const C_TITLE := Color("#122238")

## Tamanho mínimo ao redimensionar.
var min_size: Vector2 = Vector2(420, 280)
## Tipo do app ("browser", "notes"...), preenchido por quem cria a janela.
var kind: String = ""

var title_bar: PanelContainer
var title_label: Label
var min_button: Button
var max_button: Button
var close_button: Button
## Área abaixo da barra de título, onde o app monta a sua interface.
var content: Control


func _init() -> void:
	add_theme_stylebox_override("panel", _box(C_BG, C_BORDER, 2))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)

	title_bar = PanelContainer.new()
	title_bar.add_theme_stylebox_override("panel", _box(C_TITLE))
	title_bar.custom_minimum_size = Vector2(0, 30)
	column.add_child(title_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	title_bar.add_child(row)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.add_theme_color_override("font_color", Color("#e8ece9"))
	row.add_child(title_label)
	min_button = _title_button("–", "Minimizar")
	max_button = _title_button("□", "Maximizar")
	close_button = _title_button("×", "Fechar")
	row.add_child(min_button)
	row.add_child(max_button)
	row.add_child(close_button)

	content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.clip_contents = true
	column.add_child(content)


func set_title(text: String) -> void:
	title_label.text = text
	title_changed.emit()


func _title_button(glyph: String, tip: String) -> Button:
	var button := Button.new()
	button.text = glyph
	button.tooltip_text = tip
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(28, 22)
	return button


func _box(fill: Color, border: Color = Color(0, 0, 0, 0), width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	if width > 0:
		style.border_color = border
		style.set_border_width_all(width)
	style.content_margin_left = 10
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style
