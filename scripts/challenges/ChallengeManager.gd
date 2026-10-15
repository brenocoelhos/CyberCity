extends CanvasLayer
## ChallengeManager.gd — Autoload
## Mostra a tela de um desafio educativo (enunciado + alternativas),
## valida a resposta e, quando o jogador acerta, conclui a missão
## ligada ao desafio (o que dispara o XP e a tela de explicação do HUD).
##
## Errar não penaliza: mostra uma dica e deixa tentar de novo, porque a
## proposta do projeto é ensinar, não punir.

@onready var title_label: Label = $Monitor/Panel/TitleLabel
@onready var prompt_label: RichTextLabel = $Monitor/Panel/PromptLabel
@onready var options_box: VBoxContainer = $Monitor/Panel/OptionsBox
@onready var feedback_label: Label = $Monitor/Panel/FeedbackLabel
@onready var hint_button: Button = $Monitor/Panel/HintButton
@onready var monitor: Panel = $Monitor

var _active: bool = false
var _current_id: String = ""
var _current: Dictionary = {}


func _ready() -> void:
	visible = false
	for i in range(options_box.get_child_count()):
		var button: Button = options_box.get_child(i)
		button.pressed.connect(_on_option_pressed.bind(i))
	hint_button.pressed.connect(_on_hint_pressed)


func is_active() -> bool:
	return _active


func start(challenge_id: String) -> void:
	var challenge: Dictionary = ChallengeData.get_challenge(challenge_id)
	if challenge.is_empty():
		return

	_current_id = challenge_id
	_current = challenge
	_active = true

	title_label.text = String(challenge["title"])
	prompt_label.text = String(challenge["prompt"])
	feedback_label.text = ""

	var options: Array = challenge["options"]
	for i in range(options_box.get_child_count()):
		var button: Button = options_box.get_child(i)
		if i < options.size():
			button.text = "%d) %s" % [i + 1, String(options[i])]
			button.visible = true
			button.disabled = false
		else:
			button.visible = false

	visible = true
	monitor.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(monitor, "modulate:a", 1.0, 0.15)

	# Aceita a missão ligada ao desafio e começa a registrar tentativas.
	ChallengeSession.begin(challenge_id)
	if ChallengeSession.is_completed(challenge_id):
		feedback_label.text = "Você já concluiu este desafio (sem XP novo)."


func close() -> void:
	_active = false
	visible = false
	_current_id = ""
	_current = {}


func _on_option_pressed(index: int) -> void:
	if not _active or _current.is_empty():
		return

	if index == int(_current["correct"]):
		ChallengeSession.record_attempt(_current_id, true)
		SoundManager.play("success")
		_on_correct()
	else:
		ChallengeSession.record_attempt(_current_id, false)
		SoundManager.play("error")
		feedback_label.text = "Não é essa. " + String(_current.get("hint", ""))


func _on_hint_pressed() -> void:
	if not _active or _current.is_empty():
		return
	SoundManager.play("blip")
	feedback_label.text = "💡 Dica: " + String(_current.get("hint", "Sem dica disponível para este desafio."))


func _on_correct() -> void:
	var challenge_id: String = _current_id
	close()
	# Concluir o desafio dispara o XP e a tela de explicação do conceito
	# (via a missão ligada a ele).
	ChallengeSession.complete(challenge_id)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	# ESC desiste do desafio (a missão continua em andamento e pode ser
	# retomada voltando ao mesmo computador).
	if event.is_action_pressed("open_menu"):
		close()
		get_viewport().set_input_as_handled()
