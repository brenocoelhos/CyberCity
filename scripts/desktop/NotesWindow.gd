extends "res://scripts/desktop/DesktopWindow.gd"
## NotesWindow.gd
## Bloco de notas do desktop. É o mesmo texto do app "Notas" do celular
## (PlayerNotes): o que o jogador escreve aqui aparece lá e vice-versa. O jogo
## nunca lê esse texto.

var _editor: TextEdit
var _counter: Label


func _ready() -> void:
	kind = "notes"
	min_size = Vector2(320, 220)
	set_title("Notas")

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	content.add_child(column)

	_editor = TextEdit.new()
	_editor.placeholder_text = "Anote pistas, endereços, senhas achadas, o que falta fazer..."
	_editor.text = PlayerNotes.text
	_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor.text_changed.connect(_on_text_changed)
	column.add_child(_editor)

	_counter = Label.new()
	_counter.add_theme_font_size_override("font_size", 12)
	_counter.add_theme_color_override("font_color", Color("#5f8f6a"))
	_update_counter()
	column.add_child(_counter)


func _on_text_changed() -> void:
	PlayerNotes.set_text(_editor.text)
	# No limite o texto é cortado: o campo mostra o que ficou guardado.
	if _editor.text != PlayerNotes.text:
		_editor.text = PlayerNotes.text
		_editor.set_caret_line(_editor.get_line_count() - 1)
		_editor.set_caret_column(_editor.get_line(_editor.get_line_count() - 1).length())
	_update_counter()


func _update_counter() -> void:
	_counter.text = "%d / %d" % [PlayerNotes.text.length(), PlayerNotes.MAX_LENGTH]
