extends CanvasLayer
## PauseMenu.gd — Autoload
## Pausa de verdade: ESC no mundo (cidade e prédios) congela o jogo inteiro
## (get_tree().paused), inclusive o cronômetro da partida e o relógio do
## duelo, e abre um menu com Continuar, Salvar jogo, Opções e Menu principal.
##
## Não abre por cima de diálogo, terminal, desktop, celular, mapa ou telas de
## final (todos já usam o ESC), nem no menu principal.

const OptionsScene := preload("res://scenes/ui/OptionsPanel.tscn")

var _open: bool = false
var _box: Control
var _options: Panel
var _status: Label
var _info: Label
var _resume_button: Button


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func is_open() -> bool:
	return _open


func open() -> void:
	if _open or not _can_open():
		return
	_open = true
	visible = true
	get_tree().paused = true
	HUD.set_overlay_active(true)
	_status.text = ""
	_refresh_info()
	_box.visible = true
	_options.visible = false
	SoundManager.play("blip")
	_resume_button.grab_focus.call_deferred()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	_options.visible = false
	get_tree().paused = false
	HUD.set_overlay_active(false)
	SoundManager.play("blip")


## Só no mundo, e sem outra tela aberta.
func _can_open() -> bool:
	if not GameManager.game_started:
		return false
	var scene: Node = get_tree().current_scene
	if scene == null or scene.scene_file_path == SaveManager.MAIN_MENU_SCENE:
		return false
	return not (DialogueManager.is_active() or TerminalManager.is_active()
		or ChallengeManager.is_active() or GameMenu.is_active() or HUD.is_popup_active()
		or BossManager.is_busy())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _open:
		# Com as Opções abertas, o ESC é delas (fecha só o painel).
		if not _options.visible:
			close()
		get_viewport().set_input_as_handled()
	elif _can_open():
		open()
		get_viewport().set_input_as_handled()


func _refresh_info() -> void:
	var who: String = Leaderboard.player_name if Leaderboard.player_name != "" else "Agente"
	_info.text = "%s   ·   Tempo %s   ·   Nível %d" % [who, Leaderboard.format_clock(Leaderboard.elapsed_msec()), GameManager.level]


func _on_save() -> void:
	SoundManager.play("blip")
	if SaveManager.save_game("pause"):
		_status.text = "Jogo salvo."
		_status.add_theme_color_override("font_color", Color("#3dff6e"))
	else:
		_status.text = "Não dá para salvar agora."
		_status.add_theme_color_override("font_color", Color("#ff5f5f"))


func _on_options() -> void:
	SoundManager.play("blip")
	_box.visible = false
	_options.open()


func _on_options_closed() -> void:
	_box.visible = true
	_resume_button.grab_focus.call_deferred()


func _on_main_menu() -> void:
	# Despausa antes: a troca de cena usa tweens, que parados não terminam.
	close()
	GameMenu._on_main_menu_pressed()


# --- Montagem ------------------------------------------------------------------------

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.01, 0.03, 0.06, 0.82)
	add_child(backdrop)

	_box = CenterContainer.new()
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_box)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"FlatPanel"
	panel.custom_minimum_size = Vector2(380, 0)
	_box.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "PAUSADO"
	title.theme_type_variation = &"HudTitle"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 13)
	_info.add_theme_color_override("font_color", Color("#e0b44a"))
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_info)

	_resume_button = _add_button(column, "Continuar", close)
	_add_button(column, "Salvar jogo", _on_save)
	_add_button(column, "Opções", _on_options)
	_add_button(column, "Menu principal", _on_main_menu)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)

	_options = OptionsScene.instantiate()
	_options.closed.connect(_on_options_closed)
	add_child(_options)


func _add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 42)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
