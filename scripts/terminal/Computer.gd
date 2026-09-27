extends "res://scripts/systems/Interactable.gd"
## Computer.gd
## Computador interativo: abre o terminal fictício (TerminalManager).
##
## Se "challenge_id" estiver preenchido, este computador oferece um
## desafio educativo, iniciado pelo comando 'desafio' dentro do terminal.

@export var challenge_id: String = ""


func _on_interact() -> void:
	TerminalManager.open(challenge_id)
