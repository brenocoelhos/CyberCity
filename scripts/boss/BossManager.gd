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
const Credits := preload("res://scripts/ui/Credits.gd")

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
# Final bom: os créditos sobem (Credits.gd) e o tempo vai para o placar.
# Game over: volta ao último save (ou, sem nenhum save, tenta o duelo de novo).

## Texto do final bom (provisório), mostrado no começo dos créditos.
const WIN_LINES := [
	"TODOS OS COMPUTADORES DA CIDADE FICARAM AZUIS",
	"O computador do hacker também. A porta destranca e a polícia entra na sala. Cássio Vega (nome provisório) é levado, e a cidade volta a respirar.",
]

func _show_ending(won: bool) -> void:
	_clear_overlay()
	if won:
		_show_credits()
	else:
		_show_game_over()


func _show_credits() -> void:
	SoundManager.play("success")
	# O tempo da partida fecha aqui e entra no placar.
	var result: Dictionary = Leaderboard.finish_run()
	_overlay = Credits.new()
	add_child(_overlay)
	_overlay.finished.connect(_leave_to_menu)
	_overlay.play(COLOR_WIN, PackedStringArray(WIN_LINES), result)


func _show_game_over() -> void:
	SoundManager.play("error")
	_overlay = CanvasLayer.new()
	_overlay.layer = 120
	add_child(_overlay)

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = COLOR_LOSE
	_overlay.add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)

	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)

	var has_save: bool = SaveManager.has_save()
	var body := Label.new()
	body.text = "Todos os computadores da cidade ficam verdes. O hacker agora controla tudo."
	body.text += "\n\nVocê volta ao último ponto salvo." if has_save else "\n\nNão há jogo salvo: você pode tentar o duelo de novo."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 20)
	box.add_child(body)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	var button: Button = _add_button(buttons, "Voltar ao último save" if has_save else "Tentar de novo", _load_last_save if has_save else _retry)
	button.grab_focus.call_deferred()


func _add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 48)
	button.pressed.connect(func() -> void:
		SoundManager.play("interact")
		callback.call())
	parent.add_child(button)
	return button


func _clear_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


## Sem nenhum save: recomeça só o duelo.
func _retry() -> void:
	_clear_overlay()
	_busy = false
	_start_fight()


## Game over: carrega o último save (o mesmo caminho do "Continuar" do menu
## principal) e o jogador volta de onde salvou.
func _load_last_save() -> void:
	var scene_path: String = SaveManager.load_game()
	if scene_path == "":
		_retry()
		return
	_reset_state()
	GameManager.game_started = true
	SceneTransition.change_scene(scene_path, func() -> void:
		HUD.refresh()
		HUD.visible = true)


## Depois dos créditos: volta ao menu principal. "Continuar" passa a carregar o
## último save do disco (o jogo em memória acabou).
func _leave_to_menu() -> void:
	_reset_state()
	GameManager.game_started = false
	SceneTransition.change_scene(SaveManager.MAIN_MENU_SCENE)


func _reset_state() -> void:
	_clear_overlay()
	_fight = null
	_exit_locked = false
	_busy = false
