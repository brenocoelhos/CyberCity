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

## Posição do jogador DENTRO de um interior ao carregar um save (só vale para
## a próxima cena carregada). Ver SaveManager.gd e InteriorBase.gd.
var has_interior_spawn: bool = false
var interior_spawn_position: Vector2 = Vector2.ZERO

## Título mostrado dentro do interior (ex.: "Casa 2", "TechCorp Ltda").
var interior_title: String = ""

## O que o prédio pede para ter dentro do interior (NPC, computador...).
## Vazio = o interior fica como está na cena. Ver Building.gd e InteriorBase.gd.
var interior_config: Dictionary = {}


## true durante uma troca de cena (do escurecer até clarear de novo). Uma
## segunda troca pedida nesse meio tempo é ignorada: sem isso, apertar E duas
## vezes rápido numa porta carregava a cena duas vezes, e na segunda o jogador
## reaparecia no ponto inicial da cidade em vez de na porta.
var _changing: bool = false


func is_changing() -> bool:
	return _changing


## Chamado pela porta de um prédio na cidade.
func enter_building(interior_scene_path: String, title: String, city_return_position: Vector2, config: Dictionary = {}) -> void:
	if _changing:
		return
	interior_title = title
	interior_config = config
	return_spawn_position = city_return_position
	has_pending_spawn = true
	await _change_to(interior_scene_path)


## Troca para qualquer cena com fade (usado pelos menus). Roda aqui no
## autoload porque a cena que chamou (ex.: o menu principal) é apagada
## no meio da troca. "before_change" roda com a tela já preta.
func change_scene(scene_path: String, before_change: Callable = Callable()) -> void:
	if _changing:
		return
	await _change_to(scene_path, before_change)


## Chamado pela porta de saída dentro de um interior.
func exit_to_city() -> void:
	if _changing:
		return
	await _change_to(return_scene_path)


func _change_to(scene_path: String, before_change: Callable = Callable()) -> void:
	_changing = true
	await Fade.fade_out()
	if before_change.is_valid():
		before_change.call()
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await Fade.fade_in()
	_changing = false
