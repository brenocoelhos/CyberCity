extends Node
## GameManager.gd — Autoload
## Guarda o progresso global do jogador: XP, nível e os "conhecimentos"
## de cibersegurança adquiridos ao completar missões.
## Sem dinheiro, sem inventário, sem combate — só progressão educativa.

signal xp_changed(current_xp: int, xp_to_next: int, level: int)
signal leveled_up(new_level: int)

var level: int = 1
var xp: int = 0

## XP total acumulado ao longo do jogo (diferente de "xp", que zera a
## cada subida de nível). Usado só para exibir o total no fim do jogo.
var total_xp_earned: int = 0

## Conhecimentos aprendidos: nome do conceito -> quantidade de vezes
## reforçado. Usado na tela de Perfil para mostrar a evolução educativa.
var knowledge: Dictionary = {}


## XP necessário para passar do nível atual para o próximo.
## Fórmula simples e previsível: nível 1 -> 100, nível 2 -> 200, etc.
func xp_to_next_level() -> int:
	return level * 100


func add_xp(amount: int) -> void:
	if amount <= 0:
		return

	total_xp_earned += amount
	xp += amount

	# while (não if) para o caso de um ganho grande subir mais de um nível.
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		leveled_up.emit(level)

	xp_changed.emit(xp, xp_to_next_level(), level)


func add_knowledge(concept: String) -> void:
	if concept == "":
		return
	knowledge[concept] = int(knowledge.get(concept, 0)) + 1


func has_knowledge(concept: String) -> bool:
	return knowledge.has(concept)
