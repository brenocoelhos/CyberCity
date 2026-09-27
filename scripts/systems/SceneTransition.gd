extends Node
## SceneTransition.gd — Autoload (Singleton)
## Centraliza a troca de cena entre a cidade e os interiores (casas/empresas).
## Guarda o suficiente para o jogador "voltar" no lugar certo da rua.

const CITY_SCENE := "res://scenes/world/City.tscn"

## Caminho da cena para onde devemos voltar ao sair de um interior.
var return_scene_path: String = CITY_SCENE

## Posição (na cidade) onde o jogador deve reaparecer ao sair de um interior.
var return_spawn_position: Vector2 = Vector2.ZERO

## Se true, a próxima cena carregada deve reposicionar o jogador em
## return_spawn_position (usado apenas ao voltar de um interior).
var has_pending_spawn: bool = false

## Título mostrado dentro do interior (ex.: "Casa 2", "TechCorp Ltda").
var interior_title: String = ""


## Chamado pela porta de um prédio na cidade.
func enter_building(interior_scene_path: String, title: String, city_return_position: Vector2) -> void:
	interior_title = title
	return_spawn_position = city_return_position
	has_pending_spawn = true
	await Fade.fade_out()
	get_tree().change_scene_to_file(interior_scene_path)
	await get_tree().process_frame
	await Fade.fade_in()


## Chamado pela porta de saída dentro de um interior.
func exit_to_city() -> void:
	await Fade.fade_out()
	get_tree().change_scene_to_file(return_scene_path)
	await get_tree().process_frame
	await Fade.fade_in()
