extends Node2D
## InteriorBase.gd
## Script compartilhado pelas cenas de interior (HouseInterior, OfficeInterior).
## Mostra no topo da tela o nome do prédio que o jogador acabou de entrar,
## usando o valor guardado por SceneTransition.

@onready var title_label: Label = $UI/TitleLabel


func _ready() -> void:
	title_label.text = SceneTransition.interior_title
	_apply_config(SceneTransition.interior_config)


## Aplica o que o prédio pediu (ver Building.gd): quais NPC e computador
## existem e o que fazem. Só mexe nos nós "Morador" e "Computer" (a casa);
## sem pedido (dicionário vazio) o interior fica exatamente como na cena.
## A posição e o visual desses nós continuam sendo da Arte.
func _apply_config(config: Dictionary) -> void:
	if config.is_empty():
		return

	var npc := get_node_or_null("Morador")
	if npc != null:
		var npc_name: String = String(config.get("npc_name", ""))
		if npc_name == "":
			npc.queue_free()
		else:
			var interaction: Node = npc.get_node("Interaction")
			interaction.npc_name = npc_name
			interaction.dialogue_lines = PackedStringArray(config.get("npc_lines", PackedStringArray()))
			interaction.mission_to_start = String(config.get("npc_mission", ""))
			npc.get_node("NameLabel").text = npc_name

	var computer := get_node_or_null("Computer")
	if computer != null:
		var challenge_id: String = String(config.get("computer_challenge", ""))
		if challenge_id == "":
			computer.queue_free()
		else:
			computer.challenge_id = challenge_id
