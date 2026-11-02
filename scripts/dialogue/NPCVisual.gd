extends Node2D
## Identidade por local: nomes como Morador e Funcionario nao sao exclusivos.
const LOCATION_DESIGNS := {
	"Casa 1": "house1", "Casa 2": "house2", "Casa 3": "house3",
	"Casa 4": "house4", "Casa 5": "house5", "Casa 6": "house6",
	"TechCorp Ltda.": "techcorp", "DataSoft Sistemas": "datasoft",
	"Centro de Tecnologia": "scientist", "Loja Eletrônica": "developer"
}
@export_enum("automatico","guide","house1","house2","house3","house4","house5","house6","techcorp","datasoft","scientist","developer") var design := "automatico"

func _ready() -> void:
	_apply_design.call_deferred()

func _apply_design() -> void:
	var selected := design
	if selected == "automatico":
		var title: String = $Interaction.npc_name.to_lower()
		if "guia" in title:
			selected = "guide"
		elif LOCATION_DESIGNS.has(SceneTransition.interior_title):
			selected = LOCATION_DESIGNS[SceneTransition.interior_title]
		elif "pesquisadora" in title:
			selected = "scientist"
		elif "desenvolvedora" in title:
			selected = "developer"
		elif "funcion" in title:
			selected = "techcorp"
		else:
			selected = "house1"
	$Sprite2D.texture = load("res://assets/characters/npcs/"+selected+".png")
