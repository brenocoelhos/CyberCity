extends RefCounted
## UiStyle.gd
## Ajudantes para as etiquetas que aparecem no mundo (acima/abaixo de NPCs,
## computadores e portas), no estilo do HUD:
##   - name_tag(): nome numa "pílula" com cantos cortados;
##   - prompt(): balão de interação com a tecla [E] numa caixinha.
## As cores e bordas vêm do tema (assets/ui/cyber_theme.tres, variações
## NameTag, PromptChip e KeyCap).


## Faz o Label crescer a partir do centro para os dois lados, do tamanho do
## texto. Assim a etiqueta fica sempre centralizada, qualquer que seja o nome.
static func _center_fit(label: Label, grow_up: bool) -> void:
	if label.has_meta("ui_fitted"):
		return
	label.set_meta("ui_fitted", true)
	var cx := (label.offset_left + label.offset_right) * 0.5
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN if grow_up else Control.GROW_DIRECTION_END
	label.offset_left = cx
	label.offset_right = cx
	if grow_up:
		label.offset_top = label.offset_bottom
	else:
		label.offset_bottom = label.offset_top
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Etiqueta de nome (fica acima do personagem/objeto).
static func name_tag(label: Label) -> void:
	if label == null:
		return
	label.text = clean_name(label.text)
	label.theme_type_variation = &"NameTag"
	label.remove_theme_font_size_override("font_size")
	label.remove_theme_color_override("font_color")
	label.remove_theme_color_override("font_outline_color")
	label.remove_theme_constant_override("outline_size")
	_center_fit(label, true)


## Balão de interação. "[E] Conversar" vira [E] numa caixinha + "Conversar".
## Textos sem "[E]" (ex.: "🔒 Bloqueado") aparecem sem a tecla.
static func prompt(label: Label, text: String) -> void:
	if label == null:
		return
	var has_key := text.begins_with("[E]")
	label.text = text.trim_prefix("[E]").strip_edges()
	label.theme_type_variation = &"PromptChip" if has_key else &"NameTag"
	label.remove_theme_font_size_override("font_size")
	_center_fit(label, false)

	var key: Label = label.get_node_or_null("Key")
	if key == null:
		key = Label.new()
		key.name = "Key"
		key.text = "E"
		key.theme_type_variation = &"KeyCap"
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key.position = Vector2(3, 2)
		label.add_child(key)
	key.visible = has_key


## Tira o emoji do começo do nome ("🖥️ Estação 1" -> "Estação 1").
static func clean_name(text: String) -> String:
	var t := text.strip_edges()
	while t.length() > 0 and t.unicode_at(0) > 0x2000:
		t = t.substr(1)
	return t.strip_edges()
