extends Panel
## DesktopWindow.gd
## Moldura de janela do desktop: barra de título com os botões minimizar,
## maximizar e fechar, e uma área de conteúdo embaixo. Os apps (Navegador,
## Notas) herdam daqui e colocam o que querem em "content". Arrastar,
## redimensionar e a ordem das janelas ficam com o DesktopManager.
##
## PROVISÓRIO: visual simples; a Arte pode trocar a moldura.

signal title_changed

## Moldura no estilo das janelas do Xfce no Kali: barra de título cinza-escuro
## com o nome centralizado e os botões à direita.
const C_BG := Color("#14161a")
const C_BORDER := Color("#3a3d44")
const C_TITLE := Color("#26282d")

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
	var frame := _box(C_BG, C_BORDER, 1)
	frame.corner_radius_top_left = 6
	frame.corner_radius_top_right = 6
	frame.shadow_color = Color(0, 0, 0, 0.45)
	frame.shadow_size = 10
	add_theme_stylebox_override("panel", frame)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)

	title_bar = PanelContainer.new()
	var bar := _box(C_TITLE)
	bar.corner_radius_top_left = 6
	bar.corner_radius_top_right = 6
	title_bar.add_theme_stylebox_override("panel", bar)
	title_bar.custom_minimum_size = Vector2(0, 30)
	column.add_child(title_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	title_bar.add_child(row)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color("#e6e9ef"))
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
	button.add_theme_color_override("font_color", Color("#c9ced8"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
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


## A fonte de largura fixa dos apps (logs, cabeçalhos, código-fonte). A mesma
## cadeia de reserva do terminal: usa a primeira que existir no sistema, assim
## o jogo exportado não depende de uma fonte só.
static func mono_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "DejaVu Sans Mono", "Liberation Mono", "Menlo", "Courier New", "monospace"])
	return font
