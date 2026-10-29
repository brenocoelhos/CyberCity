extends Node
## GameManager.gd — Autoload
## Guarda o progresso global do jogador: XP, nível e os "conhecimentos"
## de cibersegurança adquiridos ao completar missões.
## Sem dinheiro, sem inventário, sem combate — só progressão educativa.

signal xp_changed(current_xp: int, xp_to_next: int, level: int)
signal leveled_up(new_level: int)
## Emitido quando o nível alcançado libera uma ferramenta nova.
signal tool_unlocked(tool_id: String)

## Ferramentas liberadas por nível: id -> nível mínimo. São conveniências e
## apoios de estudo, nunca atalhos para resolver missões: nenhuma missão
## depende delas.
const TOOL_UNLOCK_LEVELS := {
	"mission_arrow": 1,  # seta que aponta para a missão (opcional nos Ajustes). PROVISÓRIO, para teste: o plano é o nível 3
	"phone_tools": 1,    # app "Ferramentas" do celular. PROVISÓRIO, para teste: o plano é o nível 3
	"network_map": 4,    # mapa de rede desenhado pelo 'scan'
	"saved_history": 5,  # histórico de comandos guardado entre terminais e partidas
}

## Nome e descrição de cada ferramenta, usados na mensagem do celular.
const TOOL_TEXTS := {
	"mission_arrow": ["Seta de missão", "uma seta na borda da tela aponta para onde ir. Dá para desligar em Ajustes."],
	"phone_tools": ["Ferramentas do celular", "um app novo com decifrador de César, calculadora de hash e verificador de senha."],
	"network_map": ["Mapa de rede", "o comando 'scan' agora desenha um mapa das máquinas encontradas."],
	"saved_history": ["Histórico salvo", "o terminal guarda os comandos entre computadores e entre partidas."],
}

var level: int = 1
var xp: int = 0

## XP total acumulado ao longo do jogo (diferente de "xp", que zera a
## cada subida de nível). Usado só para exibir o total no fim do jogo.
var total_xp_earned: int = 0

## Conhecimentos aprendidos: nome do conceito -> quantidade de vezes
## reforçado. Usado na tela de Perfil para mostrar a evolução educativa.
var knowledge: Dictionary = {}

## true depois que o jogador clica em "Novo jogo" no menu principal.
## O menu usa isso para mostrar (ou não) o botão "Continuar".
var game_started: bool = false

## Cena onde o jogador estava ao voltar para o menu principal
## (usada pelo botão "Continuar").
var resume_scene_path: String = ""


## Volta o progresso ao início (usado por "Novo jogo").
func reset() -> void:
	level = 1
	xp = 0
	total_xp_earned = 0
	knowledge.clear()
	xp_changed.emit(xp, xp_to_next_level(), level)


## XP necessário para passar do nível atual para o próximo.
## Fórmula simples e previsível: nível 1 -> 100, nível 2 -> 200, etc.
## Dados para o save (ver SaveManager.gd).
func get_save_data() -> Dictionary:
	return {
		"level": level,
		"xp": xp,
		"total_xp_earned": total_xp_earned,
		"knowledge": knowledge.duplicate(),
	}


## Restaura o progresso salvo. Não emite "leveled_up" (não é um nível novo).
func load_save_data(data: Dictionary) -> void:
	level = maxi(1, int(data.get("level", 1)))
	xp = maxi(0, int(data.get("xp", 0)))
	total_xp_earned = maxi(0, int(data.get("total_xp_earned", 0)))
	knowledge.clear()
	var saved_knowledge: Dictionary = data.get("knowledge", {})
	for concept in saved_knowledge.keys():
		knowledge[String(concept)] = int(saved_knowledge[concept])
	game_started = true
	xp_changed.emit(xp, xp_to_next_level(), level)


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
		for tool_id in TOOL_UNLOCK_LEVELS.keys():
			if int(TOOL_UNLOCK_LEVELS[tool_id]) == level:
				tool_unlocked.emit(String(tool_id))

	xp_changed.emit(xp, xp_to_next_level(), level)


## true se o nível atual já liberou a ferramenta (ver TOOL_UNLOCK_LEVELS).
func is_tool_unlocked(tool_id: String) -> bool:
	return TOOL_UNLOCK_LEVELS.has(tool_id) and level >= int(TOOL_UNLOCK_LEVELS[tool_id])


func add_knowledge(concept: String) -> void:
	if concept == "":
		return
	knowledge[concept] = int(knowledge.get(concept, 0)) + 1


func has_knowledge(concept: String) -> bool:
	return knowledge.has(concept)
