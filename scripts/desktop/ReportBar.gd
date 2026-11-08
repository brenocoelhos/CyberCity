extends VBoxContainer
## ReportBar.gd
## A barra "Aponte o que achou" dos apps do desktop que analisam material (E-mail,
## Arquivos): um campo para escrever o achado, o botão "Apontar", o botão "O que
## procurar?" e, embaixo, a resposta do jogo. É o mesmo que o comando 'report'
## do terminal (TerminalManager.report_from_app).

## Emitido depois de cada envio: "kind" é "hit", "miss", "dup" ou "unknown".
signal reported(kind: String, answer: String)

const C_OK := "#3dff6e"
const C_BAD := "#ff5f5f"
const C_DIM := "#8aa0b4"

var field: LineEdit
var feedback: RichTextLabel


func _init() -> void:
	add_theme_constant_override("separation", 4)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	field = LineEdit.new()
	field.placeholder_text = "Aponte o que achou de suspeito (ex.: um cabeçalho, um IP, um hábito) e Enter"
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.text_submitted.connect(submit_text)
	row.add_child(field)
	var send := Button.new()
	send.text = "Apontar"
	send.pressed.connect(func() -> void: submit_text(field.text))
	row.add_child(send)
	var help := Button.new()
	help.text = "O que procurar?"
	help.pressed.connect(show_checklist)
	row.add_child(help)

	feedback = RichTextLabel.new()
	feedback.bbcode_enabled = true
	feedback.custom_minimum_size = Vector2(0, 74)
	add_child(feedback)


## Mostra uma frase neutra (cinza) na área de resposta.
func say(text: String) -> void:
	feedback.text = "[color=%s]%s[/color]" % [C_DIM, text.replace("[", "[lb]")]


## Envia o que está escrito no campo (e limpa o campo).
func submit_text(text: String) -> void:
	if text.strip_edges() == "":
		return
	submit(text)
	field.clear()


## Envia um achado e mostra a resposta. Devolve o resultado do terminal.
func submit(answer: String) -> Dictionary:
	var result: Dictionary = TerminalManager.report_from_app(answer)
	var kind: String = String(result.get("kind", "unknown"))
	var color: String = C_OK if kind == "hit" else (C_BAD if kind == "miss" else C_DIM)
	var text: String = "[color=%s]%s[/color]" % [color, String(result.get("message", "")).replace("[", "[lb]")]
	if kind == "hit":
		var progress: Vector2i = TerminalManager.report_progress()
		text += "\n[color=%s]Indícios encontrados: %d/%d[/color]" % [C_DIM, mini(progress.x, progress.y), progress.y]
	feedback.text = text
	reported.emit(kind, answer)
	return result


## A lista "O que procurar" do desafio (do jeito que o nível de guia permite).
func show_checklist() -> void:
	feedback.text = "\n".join(TerminalManager.report_checklist_lines())
