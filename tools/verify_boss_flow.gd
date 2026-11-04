extends SceneTree
## Verifica o encontro com o hacker de ponta a ponta, sem a interface do
## jogador: o interior da Casa 5 pede o duelo, a porta tranca, o terminal abre
## em modo duelo, e os dois finais (bom e game over) aparecem.
## Rodar: Godot --headless --path . --script res://tools/verify_boss_flow.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.

const HOUSE := "res://scenes/interiors/HouseInterior.tscn"
const CITY := "res://scenes/world/City.tscn"


func _initialize() -> void:
	await process_frame
	var boss = root.get_node("BossManager")
	var terminal = root.get_node("TerminalManager")
	var dialogue = root.get_node("DialogueManager")
	var transition = root.get_node("SceneTransition")
	var ok := true

	# --- a Casa 5 da cidade pede o duelo e esta liberada para teste ---
	var city: Node = (load(CITY) as PackedScene).instantiate()
	var casa5: Node = city.get_node("Buildings/Casa5")
	ok = _check("Casa 5 pede o duelo", casa5.interior_boss_fight) and ok
	ok = _check("Casa 5 liberada para teste", not casa5.starts_locked) and ok
	ok = _check("config do interior leva 'boss'", bool(casa5._build_interior_config().get("boss", false))) and ok
	city.free()

	# --- entrar na casa: porta tranca depois da cena ---
	transition.interior_config = {
		"npc_name": "Hacker",
		"npc_lines": PackedStringArray(["..."]),
		"npc_mission": "",
		"computer_challenge": "",
		"computers": {},
		"boss": true,
	}
	var house: Node = (load(HOUSE) as PackedScene).instantiate()
	root.add_child(house)
	await process_frame
	ok = _check("o computador da casa fica no modo duelo", house.get_node_or_null("Computer") != null) and ok
	ok = _check("jogador bloqueado durante a cena", boss.is_busy()) and ok
	await create_timer(1.0).timeout
	ok = _check("porta tranca", boss.is_exit_locked()) and ok
	ok = _check("fala da cena aparece", dialogue.is_active()) and ok
	dialogue._close()
	await process_frame
	ok = _check("segunda fala (o hacker)", dialogue.is_active()) and ok
	dialogue._close()
	await process_frame
	ok = _check("terminal abre sozinho no duelo", terminal.is_active() and terminal.get("_boss") != null) and ok
	ok = _check("jogador solto durante o duelo (terminal bloqueia)", not boss.is_busy()) and ok

	# --- ESC / fechar nao sai do duelo ---
	terminal.close()
	ok = _check("terminal nao fecha durante o duelo", terminal.is_active()) and ok

	# --- vitoria pelos comandos ---
	for command in [
		"block citycred-seguro.net", "unmask 10.13.37.5",
		"block 203.0.113.77", "unmask n0va_",
		"firewall block 23",
	]:
		terminal._on_command_submitted(command)
	ok = _check("barra em 100 depois das respostas", terminal.get("_boss") == null) and ok
	await create_timer(1.8).timeout
	ok = _check("terminal fecha ao fim", not terminal.is_active()) and ok
	ok = _check("tela do final bom aparece", boss._overlay != null and _any_label(boss._overlay, "AZUIS")) and ok
	ok = _check("jogador bloqueado na tela de final", boss.is_busy()) and ok

	# --- game over e tentar de novo ---
	boss._retry()
	await process_frame
	ok = _check("tentar de novo reabre o duelo", terminal.is_active() and terminal.get("_boss") != null) and ok
	terminal._on_command_submitted("desistir")
	await create_timer(1.8).timeout
	ok = _check("tela de game over aparece", boss._overlay != null and _any_label(boss._overlay, "GAME OVER")) and ok

	print("")
	print("OK: o fluxo do duelo funciona." if ok else "FALHOU: veja as linhas FALHA acima.")
	quit(0 if ok else 1)


func _any_label(node: Node, needle: String) -> bool:
	if node is Label and (node as Label).text.contains(needle):
		return true
	for child in node.get_children():
		if _any_label(child, needle):
			return true
	return false


func _check(label: String, passed: bool) -> bool:
	print(("  ok     " if passed else "  FALHA  ") + label)
	return passed
