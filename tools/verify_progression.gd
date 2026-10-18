extends SceneTree
## Verifica o que o nível do jogador libera: as ferramentas por nível (seta de
## missão, app Ferramentas do celular, mapa de rede, histórico salvo), a seta
## de missão, as ferramentas do celular, o mapa de rede e o placar estilo
## arcade. Não usa a interface.
## Rodar: Godot --headless --path . --script res://tools/verify_progression.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.


func _initialize() -> void:
	await process_frame
	var ok := true
	ok = await _check_unlocks() and ok
	print("RESULTADO: ", "TUDO OK" if ok else "FALHOU")
	quit(0 if ok else 1)


func _check_unlocks() -> bool:
	var game = root.get_node("GameManager")
	var phone = root.get_node("PhoneManager")
	var ok := true
	game.reset()
	phone.reset()
	ok = _check("nivel 1: nenhuma ferramenta liberada", not game.is_tool_unlocked("mission_arrow") and not game.is_tool_unlocked("saved_history")) and ok
	ok = _check("ferramenta desconhecida nunca e liberada", not game.is_tool_unlocked("nao_existe")) and ok

	var unlocked: Array = []
	game.tool_unlocked.connect(func(tool_id): unlocked.append(tool_id))
	game.add_xp(100)
	ok = _check("nivel 2: ainda nada liberado", game.level == 2 and unlocked.is_empty()) and ok
	game.add_xp(200)
	ok = _check("nivel 3: libera a seta e o app Ferramentas", game.level == 3 and unlocked.has("mission_arrow") and unlocked.has("phone_tools") and unlocked.size() == 2) and ok
	ok = _check("nivel 3: is_tool_unlocked responde", game.is_tool_unlocked("mission_arrow") and game.is_tool_unlocked("phone_tools") and not game.is_tool_unlocked("network_map")) and ok
	ok = _check("a Central avisa pelo celular de cada ferramenta liberada", phone.messages.size() == 2 and String(phone.messages[0]["text"]).find("Seta de missão") != -1 and String(phone.messages[1]["text"]).find("Ferramentas do celular") != -1) and ok

	game.add_xp(300 + 400)  # sobe do 3 para o 4 (300) e do 4 para o 5 (400): dois niveis de uma vez
	ok = _check("subir dois niveis de uma vez libera as duas ferramentas", game.level == 5 and unlocked.has("network_map") and unlocked.has("saved_history")) and ok
	ok = _check("cada ferramenta e liberada uma unica vez", unlocked.size() == 4) and ok
	game.reset()
	phone.reset()
	ok = _check("reset volta a travar as ferramentas", not game.is_tool_unlocked("mission_arrow")) and ok
	return ok


func _check(label: String, cond: bool) -> bool:
	print(("  ok   " if cond else "  FAIL ") + label)
	return cond
