extends "res://scripts/desktop/DesktopWindow.gd"
## FilesWindow.gd
## App de Arquivos do desktop: a lista de arquivos do computador à esquerda e o
## conteúdo do escolhido à direita, com número de linha. Dá para filtrar as
## linhas por um termo (como o 'grep' do terminal), o que é o jeito de achar
## o que importa num log grande. Embaixo, a barra de achados (a do 'report').
##
## Os arquivos são os do próprio desafio, listados em "filesbox" no ChallengeData.
##
## PROVISÓRIO: o visual é simples; a Arte pode trocar.

const ReportBar := preload("res://scripts/desktop/ReportBar.gd")

const HIGHLIGHT := "#fff2a8"

var _names: PackedStringArray = PackedStringArray()
var _files: Dictionary = {}
var _current: String = ""

var _list: ItemList
var _info: Label
var _filter: LineEdit
var _viewer: RichTextLabel
var _bar: Control


func _ready() -> void:
	kind = "files"
	min_size = Vector2(640, 440)
	set_title("Arquivos")
	_build()


## Carrega os arquivos do desafio (os citados em "filesbox").
func open_for(challenge: Dictionary) -> void:
	_files = Dictionary(challenge.get("files", {}))
	_names = PackedStringArray()
	for file_name in challenge.get("filesbox", []):
		if _files.has(file_name):
			_names.append(String(file_name))
	_current = ""
	_list.clear()
	for file_name in _names:
		_list.add_item(file_name)
	_filter.clear()
	_info.text = "Escolha um arquivo."
	_viewer.text = ""
	_bar.say("Abra os arquivos e aponte o que achar de importante aqui embaixo. Nos logs, filtre as linhas por um termo.")


func file_names() -> PackedStringArray:
	return _names


## Abre o arquivo "file_name" (e limpa o filtro).
func open_file(file_name: String) -> void:
	if not _names.has(file_name):
		return
	_list.select(_names.find(file_name))
	_current = file_name
	_filter.clear()
	_render()


## Mostra só as linhas que têm o termo (vazio = o arquivo todo).
func set_filter(term: String) -> void:
	_filter.text = term
	_render()


## As linhas hoje na tela, com o número de cada uma (para os testes).
func visible_line_count() -> int:
	return _visible_lines


var _visible_lines: int = 0


func _render() -> void:
	if _current == "":
		return
	var lines: PackedStringArray = String(_files[_current]).split("\n")
	var term: String = _filter.text.strip_edges().to_lower()
	var out := ""
	_visible_lines = 0
	for i in range(lines.size()):
		var line: String = lines[i]
		var shown: String = line.replace("[", "[lb]")
		if term != "":
			var at: int = line.to_lower().find(term)
			if at == -1:
				continue
			shown = "%s[bgcolor=%s][color=#1b1f24]%s[/color][/bgcolor]%s" % [
				line.substr(0, at).replace("[", "[lb]"), HIGHLIGHT,
				line.substr(at, term.length()).replace("[", "[lb]"), line.substr(at + term.length()).replace("[", "[lb]")]
		out += "[color=#8aa0b4]%3d[/color]  %s\n" % [i + 1, shown]
		_visible_lines += 1
	if term != "" and _visible_lines == 0:
		out = "[color=#8aa0b4]Nenhuma linha com \"%s\".[/color]" % term.replace("[", "[lb]")
	_viewer.text = out
	var total: int = lines.size()
	if term == "":
		_info.text = "%s — %d linha%s" % [_current, total, "" if total == 1 else "s"]
	else:
		_info.text = "%s — %d de %d linhas com \"%s\"" % [_current, _visible_lines, total, term]


func _on_file_selected(index: int) -> void:
	open_file(_names[index])


# --- Montagem ----------------------------------------------------------------------------

func _build() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	content.add_child(column)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(split)

	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(210, 0)
	_list.item_selected.connect(_on_file_selected)
	split.add_child(_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	split.add_child(right)

	_info = Label.new()
	_info.clip_text = true
	_info.add_theme_color_override("font_color", Color("#e0b44a"))
	right.add_child(_info)

	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	right.add_child(filter_row)
	_filter = LineEdit.new()
	_filter.placeholder_text = "Filtrar linhas por um termo (como o grep) ex.: 203.0.113"
	_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter.text_changed.connect(func(_text: String) -> void: _render())
	filter_row.add_child(_filter)
	var clear := Button.new()
	clear.text = "Limpar"
	clear.pressed.connect(func() -> void:
		_filter.clear()
		_render())
	filter_row.add_child(clear)

	_viewer = RichTextLabel.new()
	_viewer.bbcode_enabled = true
	_viewer.selection_enabled = true
	_viewer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var mono: SystemFont = mono_font()
	_viewer.add_theme_font_override("normal_font", mono)
	_viewer.add_theme_font_size_override("normal_font_size", 13)
	right.add_child(_viewer)

	_bar = ReportBar.new()
	column.add_child(_bar)
