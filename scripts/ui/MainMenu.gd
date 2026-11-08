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

@onready var title_label: Label = $TitleLabel

## Botão e painel do placar (criados em _setup_scores).
var scores_button: Button
var scores_panel: Panel
var scores_back_button: Button

## Evita clicar duas vezes em "Novo jogo" durante o fade.
var _leaving: bool = false

## Tempo até o próximo "tremido" (glitch) do título.
var _glitch_wait: float = 1.5


func _ready() -> void:
	# A interface do jogo (nível/XP) não aparece na tela inicial.
	HUD.visible = false
	GameMenu.close()

	# "Continuar" aparece com um jogo em andamento ou com um save no disco.
	continue_button.visible = GameManager.game_started or SaveManager.has_save()
	if not GameManager.game_started and SaveManager.has_save():
		var summary: Dictionary = SaveManager.get_save_summary()
		if not summary.is_empty():
			continue_button.text = "Continuar (Nível %d)" % int(summary["level"])
			continue_button.tooltip_text = "Último save: " + String(summary["saved_at"])
	# No navegador (exportação Web) não existe "fechar o jogo".
	quit_button.visible = not OS.has_feature("web")

	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	controls_back_button.pressed.connect(_close_controls)
	options_panel.closed.connect(_show_main_buttons)

	_setup_scores()

	# Mouse em cima de um botão = botão selecionado. Assim o mouse e o teclado
	# mostram sempre o mesmo destaque, e só um botão fica aceso por vez.
	for button in find_children("*", "BaseButton", true, false):
		button.mouse_entered.connect(func() -> void:
			if button.is_visible_in_tree() and not button.disabled:
				button.grab_focus())

	controls_panel.visible = false
	_show_main_buttons()


func _process(delta: float) -> void:
	_glitch_wait -= delta
	if _glitch_wait <= 0.0:
		_glitch_wait = randf_range(1.8, 4.0)
		_glitch_title()


## Efeito rápido de "defeito digital" no título: o texto treme de lado,
## a sombra ciano se afasta e o brilho pisca por uma fração de segundo.
func _glitch_title() -> void:
	var tween := create_tween()
	for i in 4:
		tween.tween_callback(func() -> void:
			title_label.position.x = randf_range(-7.0, 7.0)
			title_label.add_theme_constant_override("shadow_offset_x", randi_range(-10, 10))
			title_label.modulate = Color(1, 1, 1, randf_range(0.7, 1.0)))
		tween.tween_interval(0.045)
	tween.tween_callback(func() -> void:
		title_label.position.x = 0.0
		title_label.remove_theme_constant_override("shadow_offset_x")
		title_label.modulate = Color(1, 1, 1, 1))


func _show_main_buttons() -> void:
	main_buttons.visible = true
	if continue_button.visible:
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()


func _on_continue_pressed() -> void:
	if not GameManager.game_started:
		# Jogo recém-aberto: carrega o progresso do arquivo de save.
		var saved_scene: String = SaveManager.load_game()
		if saved_scene == "":
			SoundManager.play("error")
			continue_button.visible = false
			return
		_start_game(saved_scene)
		return
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
	PlayerNotes.reset()
	ChallengeSession.reset()
	# O nome e o cronômetro novos começam no telefonema da abertura (IntroCall.gd).
	Leaderboard.cancel_run()
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
	if scores_panel.visible and event.is_action_pressed("ui_cancel"):
		_close_scores()
		get_viewport().set_input_as_handled()
	elif controls_panel.visible and event.is_action_pressed("ui_cancel"):
		_close_controls()
		get_viewport().set_input_as_handled()


# --- Placar --------------------------------------------------------------------

## O botão "Placar" e o painel com os 10 melhores tempos. O painel é uma cópia do
## de Controles (mesmo visual), com as linhas do placar no lugar do texto.
func _setup_scores() -> void:
	scores_button = controls_button.duplicate(0) as Button
	scores_button.name = "ScoresButton"
	scores_button.text = "Placar"
	main_buttons.add_child(scores_button)
	main_buttons.move_child(scores_button, controls_button.get_index() + 1)
	# Mais um botão na coluna: abre espaço dos dois lados.
	main_buttons.offset_top -= 28.0
	main_buttons.offset_bottom += 28.0

	scores_panel = controls_panel.duplicate(0) as Panel
	scores_panel.name = "ScoresPanel"
	scores_panel.get_node("TitleLabel").text = "PLACAR"
	scores_panel.get_node("TextLabel").visible = false
	scores_panel.visible = false
	add_child(scores_panel)
	scores_back_button = scores_panel.get_node("BackButton")
	scores_button.pressed.connect(_on_scores_pressed)
	scores_back_button.pressed.connect(_close_scores)


func _on_scores_pressed() -> void:
	SoundManager.play("blip")
	main_buttons.visible = false
	_fill_scores()
	scores_panel.visible = true
	scores_back_button.grab_focus()


func _close_scores() -> void:
	SoundManager.play("blip")
	scores_panel.visible = false
	_show_main_buttons()


## Monta a tabela (posição, nome, tempo) a partir de Leaderboard.get_scores().
func _fill_scores() -> void:
	var old: Node = scores_panel.get_node_or_null("Rows")
	if old != null:
		scores_panel.remove_child(old)
		old.queue_free()
	var scores: Array = Leaderboard.get_scores()
	if scores.is_empty():
		var empty := Label.new()
		empty.name = "Rows"
		empty.text = "Nenhum tempo registrado ainda. Termine o jogo para aparecer aqui."
		empty.position = Vector2(60, 100)
		empty.add_theme_color_override("font_color", Color("#8aa0b4"))
		scores_panel.add_child(empty)
		return
	var rows := GridContainer.new()
	rows.name = "Rows"
	rows.columns = 3
	rows.position = Vector2(220, 64)
	rows.add_theme_constant_override("h_separation", 40)
	rows.add_theme_constant_override("v_separation", 4)
	scores_panel.add_child(rows)
	for i in range(scores.size()):
		var score: Dictionary = scores[i]
		var color: Color = Color("#ffd75f") if i == 0 else Color("#e8ece9")
		for text in ["%d." % (i + 1), String(score["name"]), Leaderboard.format_time(int(score["time_msec"]))]:
			var label := Label.new()
			label.text = text
			label.add_theme_color_override("font_color", color)
			rows.add_child(label)
