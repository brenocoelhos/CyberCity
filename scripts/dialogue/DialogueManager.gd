extends CanvasLayer
## DialogueManager.gd
## Autoload que controla a caixa de diálogo usada pelos NPCs (e por
## qualquer outro objeto que precise "falar" com o jogador).
## Fica sempre disponível, em qualquer cena (cidade ou interiores).
##
## A caixa mostra o retrato de quem fala (o sprite do NPC, ampliado sem
## suavizar os pixels). Mensagens sem retrato (capítulos da campanha)
## mostram um ícone de mensagem no lugar.

## Emitido quando o diálogo termina e a caixa fecha — usado pelo
## CampaignManager para encadear intro/outro de capítulos sem
## sobrepor um diálogo no outro.
signal closed

@onready var panel: Control = $Panel
@onready var speaker_label: Label = $Panel/SpeakerLabel
@onready var text_label: Label = $Panel/TextLabel
@onready var hint_label: Label = $Panel/HintLabel
@onready var next_arrow: Label = $Panel/NextArrow
@onready var portrait: TextureRect = $Panel/Portrait
@onready var portrait_icon: Control = $Panel/PortraitIcon

var _lines: PackedStringArray = PackedStringArray()
var _index: int = 0
var _active: bool = false
var _arrow_tween: Tween


func _ready() -> void:
	panel.visible = false


## Inicia um diálogo com um "falante" (nome mostrado no topo) e uma
## lista de falas, mostradas uma por vez. "portrait_texture" é opcional.
func start_dialogue(speaker: String, lines: PackedStringArray, portrait_texture: Texture2D = null) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_index = 0
	_active = true
	speaker_label.text = speaker.to_upper()
	portrait.texture = portrait_texture
	portrait.visible = portrait_texture != null
	portrait_icon.visible = portrait_texture == null
	panel.visible = true
	_show_current_line()
	_start_arrow_blink()


func is_active() -> bool:
	return _active


func _show_current_line() -> void:
	text_label.text = _lines[_index]
	if _index < _lines.size() - 1:
		hint_label.text = "Continuar"
		next_arrow.visible = true
	else:
		hint_label.text = "Fechar"
		next_arrow.visible = false


## O "»" pisca devagar, avisando que ainda há mais falas.
func _start_arrow_blink() -> void:
	if _arrow_tween:
		_arrow_tween.kill()
	next_arrow.modulate.a = 1.0
	_arrow_tween = create_tween().set_loops()
	_arrow_tween.tween_property(next_arrow, "modulate:a", 0.25, 0.5)
	_arrow_tween.tween_property(next_arrow, "modulate:a", 1.0, 0.5)


func _stop_arrow_blink() -> void:
	if _arrow_tween:
		_arrow_tween.kill()
		_arrow_tween = null


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
	_stop_arrow_blink()


func _close() -> void:
	_active = false
	panel.visible = false
	_stop_arrow_blink()
	closed.emit()
