extends CanvasLayer
## DialogueManager.gd
## Autoload que controla a caixa de diálogo simples usada pelos NPCs
## (e por qualquer outro objeto que precise "falar" com o jogador).
## Fica sempre disponível, em qualquer cena (cidade ou interiores).

## Emitido quando o diálogo termina e a caixa fecha — usado pelo
## CampaignManager para encadear intro/outro de capítulos sem
## sobrepor um diálogo no outro.
signal closed

@onready var panel: Panel = $Panel
@onready var speaker_label: Label = $Panel/SpeakerLabel
@onready var text_label: Label = $Panel/TextLabel
@onready var hint_label: Label = $Panel/HintLabel

var _lines: PackedStringArray = PackedStringArray()
var _index: int = 0
var _active: bool = false


func _ready() -> void:
	panel.visible = false


## Inicia um diálogo com um "falante" (nome mostrado no topo) e uma
## lista de falas, mostradas uma por vez.
func start_dialogue(speaker: String, lines: PackedStringArray) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_index = 0
	_active = true
	speaker_label.text = speaker
	panel.visible = true
	_show_current_line()


func is_active() -> bool:
	return _active


func _show_current_line() -> void:
	text_label.text = _lines[_index]
	if _index < _lines.size() - 1:
		hint_label.text = "[E] Continuar"
	else:
		hint_label.text = "[E] Fechar"


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("interact"):
		_advance()
		get_viewport().set_input_as_handled()


func _advance() -> void:
	SoundManager.play("blip")
	_index += 1
	if _index >= _lines.size():
		_close()
	else:
		_show_current_line()


## Esconde a caixa sem avisar ninguém (sem emitir "closed"). Usado ao
## sair para o menu principal, para não disparar o próximo capítulo.
func force_close() -> void:
	_active = false
	panel.visible = false


func _close() -> void:
	_active = false
	panel.visible = false
	closed.emit()
