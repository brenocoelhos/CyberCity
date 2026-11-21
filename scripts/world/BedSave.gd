extends "res://scripts/systems/Interactable.gd"
## BedSave.gd
## Cama das casas: ao apertar E o personagem "dorme" (a tela escurece um
## pouco) e o jogo é salvo, como no Terminal de Salvamento da praça.

var _sleeping: bool = false


func _on_interact() -> void:
	if _sleeping:
		return
	if not SaveManager.can_save():
		SoundManager.play("error")
		HUD.show_notice("Agora não dá para dormir", "Termine o que está fazendo e tente de novo.")
		return
	_sleeping = true
	var player: Node = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(false)
	await Fade.fade_out(0.45)
	await get_tree().create_timer(0.5).timeout
	var ok: bool = SaveManager.save_game("bed")
	await Fade.fade_in(0.45)
	if player and is_instance_valid(player):
		player.set_physics_process(true)
	SoundManager.play("success" if ok else "error")
	_sleeping = false
