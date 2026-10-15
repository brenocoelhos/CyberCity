extends Panel
## OptionsPanel.gd
## Painel de Opções (volume e tela cheia), usado tanto no menu
## principal quanto no menu de pausa (Cyber Phone). As mudanças são
## aplicadas na hora e salvas pelo autoload Settings.

## Emitido quando o jogador clica em "Voltar" ou aperta ESC.
signal closed

@onready var volume_slider: HSlider = $VBox/VolumeRow/VolumeSlider
@onready var volume_value: Label = $VBox/VolumeRow/VolumeValue
@onready var fullscreen_check: CheckButton = $VBox/FullscreenCheck
@onready var back_button: Button = $VBox/BackButton


func _ready() -> void:
	visible = false
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(close)


func open() -> void:
	volume_slider.set_value_no_signal(Settings.master_volume * 100.0)
	fullscreen_check.set_pressed_no_signal(Settings.fullscreen)
	_update_volume_label()
	visible = true
	volume_slider.grab_focus()


func close() -> void:
	if not visible:
		return
	SoundManager.play("blip")
	visible = false
	closed.emit()


func _on_volume_changed(value: float) -> void:
	Settings.set_master_volume(value / 100.0)
	_update_volume_label()
	# Um "blip" curto para o jogador ouvir o volume novo.
	SoundManager.play("blip")


func _on_fullscreen_toggled(pressed: bool) -> void:
	SoundManager.play("blip")
	Settings.set_fullscreen(pressed)


func _update_volume_label() -> void:
	volume_value.text = "%d%%" % int(volume_slider.value)


func _input(event: InputEvent) -> void:
	# _input (e não _unhandled_input) para o ESC fechar só este painel,
	# antes de chegar ao menu que está por baixo.
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
