extends Control
## MainMenu.gd
## Tela inicial do jogo (cena principal do projeto).
## Botões: Continuar (só aparece se já existe um jogo em andamento),
## Novo jogo, Opções, Controles e Sair.

const CITY_SCENE := "res://scenes/world/City.tscn"

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var continue_button: Button = $MainButtons/ContinueButton
@onready var new_game_button: Button = $MainButtons/NewGameButton
@onready var options_button: Button = $MainButtons/OptionsButton
@onready var controls_button: Button = $MainButtons/ControlsButton
@onready var quit_button: Button = $MainButtons/QuitButton
@onready var options_panel: Panel = $OptionsPanel
@onready var controls_panel: Panel = $ControlsPanel
@onready var controls_back_button: Button = $ControlsPanel/BackButton

## Evita clicar duas vezes em "Novo jogo" durante o fade.
var _leaving: bool = false


func _ready() -> void:
	# A interface do jogo (nível/XP) não aparece na tela inicial.
	HUD.visible = false
	GameMenu.close()

	continue_button.visible = GameManager.game_started
	# No navegador (exportação Web) não existe "fechar o jogo".
	quit_button.visible = not OS.has_feature("web")

	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	controls_back_button.pressed.connect(_close_controls)
	options_panel.closed.connect(_show_main_buttons)

	controls_panel.visible = false
	_show_main_buttons()


func _show_main_buttons() -> void:
	main_buttons.visible = true
	if continue_button.visible:
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()


func _on_continue_pressed() -> void:
	var path: String = GameManager.resume_scene_path
	if path == "":
		path = CITY_SCENE
	_start_game(path)


func _on_new_game_pressed() -> void:
	# Zera todo o progresso guardado nos autoloads.
	GameManager.reset()
	MissionManager.reset()
	CampaignManager.reset()
	PhoneManager.reset()
	ChallengeSession.reset()
	DialogueManager.force_close()
	SceneTransition.has_pending_spawn = false
	SceneTransition.return_scene_path = CITY_SCENE
	GameManager.resume_scene_path = ""
	_start_game(CITY_SCENE)


func _start_game(scene_path: String) -> void:
	if _leaving:
		return
	_leaving = true
	SoundManager.play("interact")
	GameManager.game_started = true

	SceneTransition.change_scene(scene_path, _show_hud)


func _show_hud() -> void:
	HUD.refresh()
	HUD.visible = true


func _on_options_pressed() -> void:
	SoundManager.play("blip")
	main_buttons.visible = false
	options_panel.open()


func _on_controls_pressed() -> void:
	SoundManager.play("blip")
	main_buttons.visible = false
	controls_panel.visible = true
	controls_back_button.grab_focus()


func _close_controls() -> void:
	SoundManager.play("blip")
	controls_panel.visible = false
	_show_main_buttons()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if controls_panel.visible and event.is_action_pressed("ui_cancel"):
		_close_controls()
		get_viewport().set_input_as_handled()
