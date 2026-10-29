extends Node
## SaveManager.gd — Autoload
## Salva e carrega o jogo em um único arquivo (user://savegame.json). Cada
## novo save sobrescreve o anterior.
##
## Quando salva:
##   - automaticamente a cada 5 minutos de jogo (AUTOSAVE_SECONDS);
##   - ao concluir uma missão;
##   - ao subir de nível;
##   - ao usar o Terminal de Salvamento na Praça Central (SaveTerminal.gd).
##
## O que é salvo: nível/XP/conhecimentos (GameManager), estado das missões
## (MissionManager), capítulos (CampaignManager), mensagens e pistas
## (PhoneManager), ranks e números dos desafios (ChallengeSession) e o local
## do jogador (cena e posição, inclusive dentro de prédios).
## As opções (volume, tela cheia) já têm arquivo próprio (Settings.gd).
##
## Onde fica o arquivo: no Godot, menu Projeto > Abrir pasta de dados do
## projeto do usuário (user://).

signal saved(reason: String)

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1
const AUTOSAVE_SECONDS := 300.0
const CITY_SCENE := "res://scenes/world/City.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"

## Texto mostrado no aviso "Jogo salvo" para cada motivo.
const REASON_TEXTS := {
	"auto": "Salvamento automático.",
	"mission": "Missão concluída.",
	"level": "Você subiu de nível.",
	"terminal": "Progresso gravado no terminal.",
}

var _seconds_since_save: float = 0.0
var _save_queued: bool = false


func _ready() -> void:
	MissionManager.mission_completed.connect(_on_mission_completed)
	GameManager.leveled_up.connect(_on_leveled_up)


func _process(delta: float) -> void:
	if not can_save():
		_seconds_since_save = 0.0
		return
	_seconds_since_save += delta
	if _seconds_since_save >= AUTOSAVE_SECONDS:
		save_game("auto")


# --- Quando salvar ---------------------------------------------------------

func _on_mission_completed(_mission_id: String) -> void:
	request_save("mission")


func _on_leveled_up(_new_level: int) -> void:
	request_save("level")


## Pede um save para o fim do quadro. Vários pedidos no mesmo quadro (ex.: uma
## missão que também sobe de nível, ou paga o bônus de XP depois do sinal)
## viram um save só, já com tudo atualizado.
func request_save(reason: String) -> void:
	if _save_queued or not can_save():
		return
	_save_queued = true
	_run_queued_save.call_deferred(reason)


func _run_queued_save(reason: String) -> void:
	_save_queued = false
	save_game(reason)


## Só salva com um jogo em andamento (não no menu principal) e com o
## personagem na cena.
func can_save() -> bool:
	if not GameManager.game_started:
		return false
	var scene: Node = get_tree().current_scene
	if scene == null or scene.scene_file_path == MAIN_MENU_SCENE:
		return false
	return get_tree().get_first_node_in_group("player") != null


# --- Salvar -------------------------------------------------------------------

## Grava o jogo agora. Devolve true se deu certo.
func save_game(reason: String = "auto") -> bool:
	if not can_save():
		return false
	var text: String = JSON.stringify(_to_json(_collect(reason)), "\t")

	# Escreve num arquivo temporário e só depois troca pelo definitivo: se o
	# jogo fechar no meio, o save anterior continua inteiro.
	var temp_path: String = SAVE_PATH + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: não consegui escrever %s (erro %d)." % [temp_path, FileAccess.get_open_error()])
		_announce(false, reason)
		return false
	file.store_string(text)
	file.close()

	var dir := DirAccess.open("user://")
	var ok: bool = dir != null and dir.rename(temp_path, SAVE_PATH) == OK
	if not ok:
		# Plano B: grava direto no arquivo definitivo.
		var direct := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if direct == null:
			push_warning("SaveManager: não consegui escrever %s." % SAVE_PATH)
			_announce(false, reason)
			return false
		direct.store_string(text)
		direct.close()

	_seconds_since_save = 0.0
	saved.emit(reason)
	_announce(true, reason)
	return true


func _announce(success: bool, reason: String) -> void:
	if success:
		HUD.show_notice("Jogo salvo", String(REASON_TEXTS.get(reason, "Progresso gravado.")))
	else:
		HUD.show_notice("Não foi possível salvar", "Verifique o espaço em disco e tente de novo.")


func _collect(reason: String) -> Dictionary:
	var scene: Node = get_tree().current_scene
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	return {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"reason": reason,
		"game": GameManager.get_save_data(),
		"missions": MissionManager.get_save_data(),
		"campaign": CampaignManager.get_save_data(),
		"phone": PhoneManager.get_save_data(),
		"challenges": ChallengeSession.get_save_data(),
		"location": {
			"scene": scene.scene_file_path,
			"position": player.global_position,
			"interior_title": SceneTransition.interior_title,
			"interior_config": SceneTransition.interior_config,
			"return_scene": SceneTransition.return_scene_path,
			"return_position": SceneTransition.return_spawn_position,
		},
	}


# --- Carregar -----------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Resumo do save para o menu: {"level": int, "saved_at": String}.
## Vazio se não há save legível.
func get_save_summary() -> Dictionary:
	var data: Dictionary = _read()
	if data.is_empty():
		return {}
	var game: Dictionary = data.get("game", {})
	return {"level": int(game.get("level", 1)), "saved_at": String(data.get("saved_at", ""))}


## Restaura o progresso do arquivo para os gerenciadores e prepara a posição
## do jogador. Devolve o caminho da cena onde o jogo deve continuar, ou ""
## se não há save válido. Quem chama (MainMenu) é quem troca a cena.
func load_game() -> String:
	var data: Dictionary = _read()
	if data.is_empty():
		return ""

	GameManager.reset()
	MissionManager.reset()
	CampaignManager.reset()
	PhoneManager.reset()
	ChallengeSession.reset()
	DialogueManager.force_close()

	GameManager.load_save_data(_dict(data, "game"))
	MissionManager.load_save_data(_dict(data, "missions"))
	CampaignManager.load_save_data(_dict(data, "campaign"))
	PhoneManager.load_save_data(_dict(data, "phone"))
	ChallengeSession.load_save_data(_dict(data, "challenges"))

	var location: Dictionary = _dict(data, "location")
	var scene_path: String = String(location.get("scene", CITY_SCENE))
	if not ResourceLoader.exists(scene_path):
		scene_path = CITY_SCENE
	var position: Vector2 = _vector(location.get("position"), Vector2.ZERO)

	GameManager.resume_scene_path = ""
	SceneTransition.has_interior_spawn = false
	if scene_path.contains("/interiors/"):
		SceneTransition.interior_title = String(location.get("interior_title", ""))
		SceneTransition.interior_config = _dict(location, "interior_config")
		SceneTransition.return_scene_path = String(location.get("return_scene", CITY_SCENE))
		# Ao sair do prédio, volta para a porta certa na cidade.
		SceneTransition.return_spawn_position = _vector(location.get("return_position"), Vector2.ZERO)
		SceneTransition.has_pending_spawn = true
		SceneTransition.interior_spawn_position = position
		SceneTransition.has_interior_spawn = true
	else:
		SceneTransition.return_scene_path = CITY_SCENE
		SceneTransition.return_spawn_position = position
		SceneTransition.has_pending_spawn = position != Vector2.ZERO
	return scene_path


func _read() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		push_warning("SaveManager: o arquivo de save está corrompido.")
		return {}
	if int(parsed.get("version", 0)) > SAVE_VERSION:
		push_warning("SaveManager: o save é de uma versão mais nova do jogo.")
		return {}
	return parsed


# --- JSON ---------------------------------------------------------------------
# JSON não tem Vector2 nem arrays "Packed". Na ida, Vector2 vira [x, y] e
# Packed vira lista comum; na volta, _vector() e _dict() refazem o que precisa.

func _to_json(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2:
			return [value.x, value.y]
		TYPE_DICTIONARY:
			var out := {}
			for key in value.keys():
				out[String(key)] = _to_json(value[key])
			return out
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			var list := []
			for item in value:
				list.append(_to_json(item))
			return list
		TYPE_STRING_NAME:
			return String(value)
	return value


func _dict(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return value if value is Dictionary else {}


func _vector(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback
