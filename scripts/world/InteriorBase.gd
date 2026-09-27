extends Node2D
## InteriorBase.gd
## Script compartilhado pelas cenas de interior (HouseInterior, OfficeInterior).
## Mostra no topo da tela o nome do prédio que o jogador acabou de entrar,
## usando o valor guardado por SceneTransition.

@onready var title_label: Label = $UI/TitleLabel


func _ready() -> void:
	title_label.text = SceneTransition.interior_title
