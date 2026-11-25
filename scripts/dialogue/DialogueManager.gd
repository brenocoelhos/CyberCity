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

## Dublagem opcional: não interfere se as vozes ainda não foram geradas.
const VOICE_INDEX_FILE: String = "res://assets/data/indice_godot.json"
const VOICE_KEY_SEPARATOR: String = "␟"
var _voice_player: AudioStreamPlayer
var _voice_index: Dictionary = {}


func _ready() -> void:
	panel.visible = false
	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "VoicePlayer"
	_voice_player.volume_db = -2.0
	add_child(_voice_player)
	_load_voice_index()


func _load_voice_index() -> void:
	if not FileAccess.file_exists(VOICE_INDEX_FILE):
		return
	var json_text: String = FileAccess.get_file_as_string(VOICE_INDEX_FILE)
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed is Dictionary:
		_voice_index = parsed


func _play_current_voice() -> void:
	if _voice_player == null:
		return
	_voice_player.stop()  # não deixar duas falas se sobreporem
	var line: String = _lines[_index]
	var speaker: String = speaker_label.text
	var key: String = speaker + VOICE_KEY_SEPARATOR + line
	var audio_path: String = String(_voice_index.get(key, ""))
	# O nome do jogador muda por partida; o áudio da Central omite o nome.
	if audio_path == "" and speaker == "CENTRAL" \
			and line.begins_with("Entendido, agente ") \
			and line.ends_with(". Seu nome entra no registro oficial."):
		key = speaker + VOICE_KEY_SEPARATOR + "Entendido, agente %s. Seu nome entra no registro oficial."
		audio_path = String(_voice_index.get(key, ""))
	# Falas genéricas (ditas por qualquer NPC) ficam no índice com "*" no
	# lugar do nome, ex.: "missão ainda não liberada".
	if audio_path == "":
		audio_path = String(_voice_index.get("*" + VOICE_KEY_SEPARATOR + line, ""))
	if audio_path != "" and ResourceLoader.exists(audio_path):
		var audio: AudioStream = load(audio_path) as AudioStream
		if audio != null:
			_voice_player.stream = audio
			_voice_player.play()


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
	_play_current_voice()
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
	if _voice_player:
		_voice_player.stop()


func _close() -> void:
	_active = false
	panel.visible = false
	_stop_arrow_blink()
	if _voice_player:
		_voice_player.stop()
	closed.emit()
