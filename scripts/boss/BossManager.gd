extends Node
## BossManager.gd — Autoload
## Cuida do encontro com o hacker na Casa 5: tranca a porta, conversa, abre o
## terminal em modo duelo (BossFight.gd) e mostra o final (bom ou game over).
##
## A casa pede o encontro pela opção "Interior boss fight" do Building
## (ver Building.gd e InteriorBase.gd).
##
## TODO(provisório): as falas e as telas de final são texto simples para
## teste; a História escreve o roteiro e a Arte cria as telas. O resultado do
## duelo ainda não é salvo (dá para jogar de novo quantas vezes quiser).

const BossFight := preload("res://scripts/boss/BossFight.gd")

const COLOR_WIN := Color("#0b3a8f")
const COLOR_LOSE := Color("#0d3b14")

## Texto do encontro (provisório).
const DOOR_LINES := [
	"A porta bate atrás de você e tranca sozinha.",
	"Uma luz azulada vem de dois computadores. Em um deles, alguém digita sem nem olhar para você.",
]
const HACKER_LINES := [
	"Então você é o famoso detetive digital. Esperava alguém... maior.",
	"Preparei um computador para você. Assim ninguém diz que eu ataquei pelas costas.",
	"Vamos ver quanto tempo você aguenta repetir tudo o que já fez. Só que agora, contra mim.",
]

var _fight: RefCounted = null
var _exit_locked: bool = false
var _busy: bool = false
var _overlay: CanvasLayer = null


## True durante a cena do encontro e nas telas de final (o jogador não anda).
func is_busy() -> bool:
	return _busy


## True enquanto a porta de saída está trancada.
func is_exit_locked() -> bool:
	return _exit_locked


## Chamado pelo interior da Casa 5 ao carregar.
func begin_encounter() -> void:
	if _busy or _exit_locked:
		return
	_busy = true
	# Espera a tela clarear depois do fade de entrada.
	await get_tree().create_timer(0.8).timeout
	_exit_locked = true
	SoundManager.play("error")
	DialogueManager.start_dialogue("SISTEMA", PackedStringArray(DOOR_LINES))
	await DialogueManager.closed
	DialogueManager.start_dialogue("HACKER", PackedStringArray(HACKER_LINES))
	await DialogueManager.closed
	_busy = false
	_start_fight()


func _start_fight() -> void:
	_fight = BossFight.new()
	TerminalManager.open_boss(_fight)


## Chamado pelo terminal quando o duelo termina.
func on_fight_finished(won: bool) -> void:
	_fight = null
	_busy = true
	_show_ending(won)


# --- Finais ----------------------------------------------------------------------

func _show_ending(won: bool) -> void:
	_clear_overlay()
	_overlay = CanvasLayer.new()
	_overlay.layer = 120
	add_child(_overlay)

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = COLOR_WIN if won else COLOR_LOSE
	_overlay.add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)

	var body := Label.new()
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 20)
	box.add_child(body)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	box.add_child(buttons)

	var first_button: Button = null
	if won:
		SoundManager.play("success")
		title.text = "TODOS OS COMPUTADORES DA CIDADE FICARAM AZUIS"
		body.text = "O computador do hacker também. A porta destranca e a polícia entra na sala. Cássio Vega (nome provisório) é levado, e a cidade volta a respirar.\n\nFINAL BOM — fim da versão de teste."
		first_button = _add_button(buttons, "Sair da casa", _leave_house)
	else:
		SoundManager.play("error")
		title.text = "GAME OVER"
		body.text = "Todos os computadores da cidade ficam verdes. O hacker agora controla tudo.\n\nVocê pode tentar de novo."
		first_button = _add_button(buttons, "Tentar de novo", _retry)
		_add_button(buttons, "Sair da casa", _leave_house)
	first_button.grab_focus.call_deferred()


func _add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 48)
	button.pressed.connect(func() -> void:
		SoundManager.play("interact")
		callback.call())
	parent.add_child(button)
	return button


func _clear_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


func _retry() -> void:
	_clear_overlay()
	_busy = false
	_start_fight()


func _leave_house() -> void:
	_clear_overlay()
	_exit_locked = false
	_busy = false
	SceneTransition.exit_to_city()
