extends "res://scripts/systems/Interactable.gd"
## NPC.gd
## NPC parado que conversa com o jogador. Reaproveita toda a lógica de
## detecção/prompt de Interactable.gd — só precisa definir o nome e as
## falas.
##
## Se "mission_to_start" estiver preenchido, conversar com este NPC
## aceita/inicia essa missão (se ela estiver disponível).

@export var npc_name: String = "Morador"
@export var dialogue_lines: PackedStringArray = PackedStringArray()
@export var mission_to_start: String = ""


func _ready() -> void:
	super._ready()
	# O "!" amarelo fica sempre sobre o NPC (lembra o jogador de conversar
	# antes de ir aos computadores) e sobe e desce devagar.
	var marker: Label = get_node_or_null("../Marker")
	if marker:
		var base_y := marker.position.y
		var tween := create_tween().set_loops()
		tween.tween_property(marker, "position:y", base_y - 6.0, 0.5)
		tween.tween_property(marker, "position:y", base_y, 0.5)


func _on_interact() -> void:
	DialogueManager.start_dialogue(npc_name, dialogue_lines)

	if mission_to_start != "":
		MissionManager.start_mission(mission_to_start)
