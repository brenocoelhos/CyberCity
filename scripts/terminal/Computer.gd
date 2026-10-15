extends "res://scripts/systems/Interactable.gd"
## Computer.gd
## Computador interativo: abre o terminal fictício (TerminalManager).
##
## Se "challenge_id" estiver preenchido, este computador oferece um
## desafio educativo, iniciado pelo comando 'desafio' dentro do terminal.

@export var challenge_id: String = ""
## Nome da máquina no prompt do terminal (kali㉿<host_name>). Se ficar
## vazio, usa o nome do prédio atual (ex.: "techcorp-ltda").
@export var host_name: String = ""


func _on_interact() -> void:
	TerminalManager.open(challenge_id, _resolve_host())


func _resolve_host() -> String:
	if host_name != "":
		return host_name
	var title: String = SceneTransition.interior_title
	if title == "":
		return "cybercity"
	# "TechCorp Ltda." -> "techcorp-ltda"
	var slug := ""
	for character in title.to_lower().strip_edges():
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			slug += character
		elif character == " " and not slug.ends_with("-"):
			slug += "-"
		elif "áàâã".contains(character):
			slug += "a"
		elif "éê".contains(character):
			slug += "e"
		elif "í".contains(character):
			slug += "i"
		elif "óôõ".contains(character):
			slug += "o"
		elif "ú".contains(character):
			slug += "u"
		elif character == "ç":
			slug += "c"
	return slug.trim_suffix("-")
