extends "res://scripts/systems/Interactable.gd"
## SaveTerminal.gd
## Terminal de Salvamento da Praça Central: ao apertar E, o jogo é salvo
## (ver SaveManager.gd). Não abre o terminal de comandos.


func _ready() -> void:
	super._ready()
	UiStyle.name_tag(get_node_or_null("NameLabel"))


func _on_interact() -> void:
	if SaveManager.save_game("terminal"):
		SoundManager.play("success")
	else:
		SoundManager.play("error")
