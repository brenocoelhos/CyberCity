extends Node
## Settings.gd — Autoload
## Guarda as opções do jogador (volume e tela cheia) em
## user://settings.cfg, para continuarem iguais na próxima vez que o
## jogo abrir. Usado pela tela de Opções do menu principal e do menu
## de pausa.

const SETTINGS_PATH := "user://settings.cfg"

## Volume geral de 0.0 (mudo) a 1.0 (máximo).
var master_volume: float = 1.0
var fullscreen: bool = false


func _ready() -> void:
	_load()
	_apply()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply()
	_save()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply()
	_save()


func _apply() -> void:
	var bus: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(master_volume))
	AudioServer.set_bus_mute(bus, master_volume <= 0.0)

	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	master_volume = clampf(float(config.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
	fullscreen = bool(config.get_value("video", "fullscreen", false))


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.save(SETTINGS_PATH)
