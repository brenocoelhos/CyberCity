extends SceneTree
## Verifica a progressao da campanha: as missoes comecam bloqueadas e cada
## capitulo libera as suas; os capitulos seguem em ordem; depois do capitulo 7
## vem o capitulo final (a Casa 5 abre e o duelo e o objetivo); vencer o duelo
## encerra o jogo. Tambem confere que carregar um save "parado entre capitulos"
## e saves antigos (todas as missoes liberadas) voltam a ficar certos.
## Rodar: Godot --headless --path . --script res://tools/verify_campaign.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.

const BUILDING := "res://scenes/world/Building.tscn"

var missions
var campaign
var dialogue
var MissionTarget: GDScript


func _initialize() -> void:
	await process_frame
	missions = root.get_node("MissionManager")
	campaign = root.get_node("CampaignManager")
	dialogue = root.get_node("DialogueManager")
	MissionTarget = load("res://scripts/ui/MissionTarget.gd")
	var ok := true
	ok = _check_order() and ok
	ok = _check_stalled_save() and ok
	ok = _check_old_save() and ok
	ok = await _check_boss_door() and ok
	print("RESULTADO: ", "TUDO OK" if ok else "FALHOU")
	quit(0 if ok else 1)


func _new_game() -> void:
	dialogue.force_close()
	root.get_node("GameManager").reset()
	missions.reset()
	campaign.reset()


## Fecha a caixa de dialogo como o jogador (E ate o fim), disparando "closed".
func _close_dialogue() -> void:
	var guard := 0
	while dialogue.is_active() and guard < 50:
		dialogue._advance()
		guard += 1


func _do_mission(mission_id: String) -> void:
	missions.start_mission(mission_id)
	missions.complete_mission(mission_id)
	_close_dialogue()


func _all_locked() -> bool:
	for mission_id in missions.missions.keys():
		if missions.get_state(mission_id) != missions.State.LOCKED:
			return false
	return true


func _check_order() -> bool:
	var ok := true
	_new_game()
	ok = _check("novo jogo: todas as missoes comecam bloqueadas", _all_locked()) and ok

	campaign.play_opening()
	ok = _check("capitulo 1: libera so a m01", missions.get_state("m01") == missions.State.AVAILABLE and missions.get_state("m02") == missions.State.LOCKED and missions.get_state("m15") == missions.State.LOCKED) and ok
	_close_dialogue()

	missions.start_mission("m15")
	ok = _check("missao de capitulo futuro nao pode ser aceita", missions.get_state("m15") == missions.State.LOCKED) and ok

	_do_mission("m01")
	ok = _check("fim do capitulo 1: o capitulo 2 comeca e libera m02 e m03", campaign.is_chapter_finished("ch1") and campaign.is_chapter_started("ch2") and missions.get_state("m02") == missions.State.AVAILABLE and missions.get_state("m03") == missions.State.AVAILABLE) and ok
	ok = _check("o capitulo 3 continua fechado", not campaign.is_chapter_started("ch3") and missions.get_state("m04") == missions.State.LOCKED) and ok
	_close_dialogue()

	# Joga os capitulos 2 a 7 em ordem.
	for chapter_id in ["ch2", "ch3", "ch4", "ch5", "ch6", "ch7"]:
		ok = _check("%s comecou antes das missoes dele" % chapter_id, campaign.is_chapter_started(chapter_id)) and ok
		for mission_id in campaign.chapters[chapter_id]["missions"]:
			_do_mission(String(mission_id))
		_close_dialogue()
		ok = _check("%s terminou" % chapter_id, campaign.is_chapter_finished(chapter_id)) and ok

	ok = _check("depois do capitulo 7 comeca o capitulo final", campaign.is_final_chapter_active()) and ok
	ok = _check("o jogo so termina com o duelo (ainda nao encerrado)", not campaign.is_game_completed) and ok
	ok = _check("capitulo final: a seta guia para a Casa 5", MissionTarget.mission_to_guide() == MissionTarget.FINAL_TARGET) and ok

	var completed: Array = []
	campaign.game_completed.connect(func(): completed.append(1), CONNECT_ONE_SHOT)
	campaign.complete_game()
	ok = _check("vencer o duelo encerra o jogo e fecha o capitulo final", campaign.is_game_completed and campaign.is_chapter_finished(campaign.FINAL_CHAPTER) and completed.size() == 1) and ok
	ok = _check("depois do fim, a seta nao guia mais nada", MissionTarget.mission_to_guide() == "") and ok
	return ok


## Save feito logo depois da ultima missao de um capitulo: o capitulo terminou,
## mas o proximo so comecaria ao fechar o texto de fechamento.
func _check_stalled_save() -> bool:
	var ok := true
	_new_game()
	campaign.play_opening()
	_close_dialogue()
	missions.start_mission("m01")
	missions.complete_mission("m01")
	# Aqui o jogo salva (missao concluida), com o texto de fechamento na tela.
	var mission_data: Dictionary = missions.get_save_data()
	var campaign_data: Dictionary = campaign.get_save_data()
	ok = _check("save parado: capitulo 1 terminou e o 2 ainda nao comecou", bool(campaign_data["chapter_finished"].get("ch1", false)) and not campaign_data["chapter_started"].has("ch2")) and ok

	# O jogador fecha o jogo. Depois, "Continuar" carrega o save.
	_new_game()
	missions.load_save_data(mission_data)
	campaign.load_save_data(campaign_data)
	campaign.play_opening()
	ok = _check("ao voltar a cidade, o capitulo 2 comeca (introducao e missoes)", campaign.is_chapter_started("ch2") and dialogue.is_active() and missions.get_state("m02") == missions.State.AVAILABLE) and ok
	_close_dialogue()
	campaign.play_opening()
	ok = _check("chamar de novo nao repete nada", not dialogue.is_active()) and ok
	return ok


## Save antigo: todas as missoes liberadas e o jogo "encerrado" pelo capitulo 7.
func _check_old_save() -> bool:
	var ok := true
	_new_game()
	var states := {}
	for mission_id in missions.missions.keys():
		states[mission_id] = missions.State.AVAILABLE
	states["m15"] = missions.State.COMPLETED
	missions.load_save_data({"states": states})
	campaign.load_save_data({
		"is_game_completed": true,
		"intro_played": true,
		"chapter_started": {"ch1": true, "ch7": true},
		"chapter_finished": {"ch7": true},
	})
	ok = _check("save antigo: missoes de capitulos nao comecados voltam a ficar bloqueadas", missions.get_state("m02") == missions.State.LOCKED and missions.get_state("m09") == missions.State.LOCKED) and ok
	ok = _check("save antigo: o capitulo atual continua liberado e o concluido fica concluido", missions.get_state("m01") == missions.State.AVAILABLE and missions.is_completed("m15")) and ok
	ok = _check("save antigo: o jogo nao fica 'encerrado' sem o duelo", not campaign.is_game_completed) and ok
	return ok


func _check_boss_door() -> bool:
	var ok := true
	_new_game()
	var building: Node = (load(BUILDING) as PackedScene).instantiate()
	building.starts_locked = true
	building.unlock_chapter = campaign.FINAL_CHAPTER
	building.interior_boss_fight = true
	root.add_child(building)
	await process_frame
	var door: Node = building.get_node("Door")
	door._update_lock_state()
	ok = _check("Casa 5: trancada antes do capitulo final", door.locked and not building.get_node("MissionMarker").visible) and ok

	campaign._start_chapter(campaign.FINAL_CHAPTER)
	_close_dialogue()
	door._update_lock_state()
	ok = _check("Casa 5: abre e ganha o ! no capitulo final", not door.locked and building.get_node("MissionMarker").visible) and ok
	building.queue_free()
	await process_frame
	_new_game()
	return ok


func _check(label: String, cond: bool) -> bool:
	print(("  ok   " if cond else "  FAIL ") + label)
	return cond
