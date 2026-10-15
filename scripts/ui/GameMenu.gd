extends CanvasLayer
## GameMenu.gd — Autoload
## "CYBER PHONE": menu simples do jogador, aberto com TAB ou ESC.
## Mostra as missões, os conhecimentos adquiridos e o perfil (nível/XP).
## Mantido como um painel único de texto para não complicar o escopo.
## Embaixo ficam os botões de pausa: Continuar, Opções, Menu principal
## e Sair do jogo.

const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const CITY_SCENE := "res://scenes/world/City.tscn"

@onready var panel: Panel = $Panel
@onready var content: RichTextLabel = $Panel/Content
@onready var resume_button: Button = $Panel/Buttons/ResumeButton
@onready var options_button: Button = $Panel/Buttons/OptionsButton
@onready var main_menu_button: Button = $Panel/Buttons/MainMenuButton
@onready var quit_button: Button = $Panel/Buttons/QuitButton
@onready var options_panel: Panel = $OptionsPanel

var _active: bool = false


func _ready() -> void:
	panel.visible = false
	# No navegador (exportação Web) não existe "fechar o jogo".
	quit_button.visible = not OS.has_feature("web")

	resume_button.pressed.connect(toggle)
	options_button.pressed.connect(_on_options_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	options_panel.closed.connect(_on_options_closed)


func is_active() -> bool:
	return _active


func toggle() -> void:
	SoundManager.play("blip")
	if _active:
		close()
	else:
		open()


func open() -> void:
	_active = true
	panel.visible = true
	_refresh()
	resume_button.grab_focus()


func close() -> void:
	_active = false
	panel.visible = false
	options_panel.visible = false


func _on_options_pressed() -> void:
	SoundManager.play("blip")
	panel.visible = false
	options_panel.open()


func _on_options_closed() -> void:
	if not _active:
		return
	panel.visible = true
	options_button.grab_focus()


## Volta para a tela inicial, guardando onde o jogador estava para o
## botão "Continuar" do menu principal.
func _on_main_menu_pressed() -> void:
	SoundManager.play("blip")
	var scene: Node = get_tree().current_scene
	GameManager.resume_scene_path = scene.scene_file_path
	if scene.scene_file_path == CITY_SCENE:
		var player: Node2D = scene.get_node_or_null("Player")
		if player:
			SceneTransition.return_spawn_position = player.global_position
			SceneTransition.has_pending_spawn = true

	close()
	SceneTransition.change_scene(MAIN_MENU_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _refresh() -> void:
	content.clear()
	_append_profile()
	_append("")
	_append_knowledge()
	_append("")
	_append_missions()


func _append_profile() -> void:
	_append("=== PERFIL ===")
	_append("")
	if CampaignManager.is_game_completed:
		_append("  🏆 CASO ENCERRADO — todas as missões concluídas")
		_append("")
	_append("  HACKER")
	_append("  Nível: %d" % GameManager.level)
	_append("  XP: %s %d/%d" % [
		_ascii_bar(GameManager.xp, GameManager.xp_to_next_level(), 20),
		GameManager.xp,
		GameManager.xp_to_next_level(),
	])


func _append_knowledge() -> void:
	_append("=== CONHECIMENTOS ===")
	_append("")
	if GameManager.knowledge.is_empty():
		_append("  (nenhum conceito aprendido ainda — complete uma missão)")
		return

	for concept in GameManager.knowledge.keys():
		var reinforced: int = int(GameManager.knowledge[concept])
		_append("  %-16s %s" % [String(concept), "█".repeat(reinforced) + "░".repeat(max(0, 5 - reinforced))])


func _append_missions() -> void:
	_append("=== MISSÕES ===")
	_append("")

	for mission in MissionManager.missions.values():
		var state_text: String = MissionManager.state_to_text(mission["state"])
		_append("[%s] %s" % [state_text, String(mission["title"])])
		_append("  " + String(mission["description"]))
		_append("  Objetivo: " + String(mission["objective"]))
		_append("  Local: %s | Dificuldade: %s | Recompensa: %d XP" % [
			String(mission["location"]),
			String(mission["difficulty"]),
			int(mission["xp"]),
		])
		if mission["state"] == MissionManager.State.ACTIVE:
			var challenge: Dictionary = ChallengeData.get_challenge_for_mission(String(mission["id"]))
			if challenge.has("hint"):
				_append("  💡 Dica: " + String(challenge["hint"]))
		_append("")


## Barra de progresso simples em texto (estilo "██████░░░░").
func _ascii_bar(current: int, total: int, length: int) -> String:
	if total <= 0:
		return "░".repeat(length)
	var filled: int = clampi(int(round(float(current) / float(total) * length)), 0, length)
	return "█".repeat(filled) + "░".repeat(length - filled)


func _append(text: String) -> void:
	content.append_text(text + "\n")


func _input(event: InputEvent) -> void:
	# Com o menu aberto, TAB/ESC fecham o menu aqui em _input: senão um
	# botão com foco "comeria" o TAB (que no Godot troca o foco).
	if not _active or options_panel.visible:
		return
	if event.is_action_pressed("open_menu"):
		toggle()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# Na tela inicial o Cyber Phone não abre.
	var scene: Node = get_tree().current_scene
	if scene and scene.scene_file_path == MAIN_MENU_SCENE:
		return

	# O menu não deve abrir por cima do terminal, de um diálogo ou da
	# tela de missão concluída (todos eles já usam ESC/E).
	if TerminalManager.is_active() or DialogueManager.is_active() \
		or ChallengeManager.is_active() or HUD.is_popup_active():
		return

	if event.is_action_pressed("open_menu"):
		toggle()
		get_viewport().set_input_as_handled()
