extends RefCounted
## MissionTarget.gd
## Descobre para onde a seta de missão deve apontar: qual missão guiar e qual
## nó da cena atual (prédio, computador ou NPC) leva a ela. Só lógica, sem
## desenhar nada (o desenho está em MissionArrow.gd).


## Alvo especial do capítulo final: a casa do hacker (não é uma missão).
const FINAL_TARGET := "final"


## Missão a guiar: a primeira em andamento; sem nenhuma, a primeira ainda não
## concluída do capítulo atual; no capítulo final, FINAL_TARGET (a Casa 5).
## "" se não há para onde ir.
static func mission_to_guide() -> String:
	var active: Dictionary = MissionManager.get_active_mission()
	if not active.is_empty():
		return String(active["id"])
	for chapter_id in CampaignManager.chapters.keys():
		for mission_id in CampaignManager.chapters[chapter_id]["missions"]:
			if not MissionManager.is_completed(String(mission_id)) and CampaignManager.is_mission_in_current_chapter(String(mission_id)):
				return String(mission_id)
	if CampaignManager.is_final_chapter_active():
		return FINAL_TARGET
	return ""


## Nó da cena que leva à missão, o mais perto do jogador:
##   - na cidade: o prédio que lista a missão em "mission_ids" (e, no que está
##     fora de prédio, como o Terminal Público, o computador da missão);
##   - dentro de um prédio: o computador da missão ou o NPC que a entrega;
##   - dentro do prédio errado: a porta de saída.
## null se não há alvo.
static func find_target(scene: Node, mission_id: String) -> Node2D:
	if scene == null or mission_id == "":
		return null

	var candidates: Array[Node2D] = []

	var buildings: Node = scene.get_node_or_null("Buildings")
	if mission_id == FINAL_TARGET:
		# Capítulo final: o prédio marcado com "Interior boss fight" (Casa 5).
		if buildings != null:
			for building in buildings.get_children():
				if "interior_boss_fight" in building and building.interior_boss_fight:
					candidates.append(building)
		if candidates.is_empty():
			return scene.get_node_or_null("ExitDoor") as Node2D
		return _nearest(scene, candidates)

	if buildings != null:
		for building in buildings.get_children():
			if "mission_ids" in building and mission_id in building.mission_ids:
				candidates.append(building)

	var challenge_id: String = ChallengeData.get_challenge_id_for_mission(mission_id)
	for area in scene.find_children("*", "Area2D", true, false):
		if "challenge_id" in area:
			# Missão com desafio: o computador desse desafio. Missão sem
			# desafio (m01): o computador comum.
			if String(area.challenge_id) == challenge_id:
				candidates.append(area)
		elif "mission_to_start" in area and String(area.mission_to_start) == mission_id:
			candidates.append(area)

	if candidates.is_empty():
		# Está num interior que não tem a missão: o caminho é a saída.
		return scene.get_node_or_null("ExitDoor") as Node2D
	return _nearest(scene, candidates)


static func _nearest(scene: Node, candidates: Array[Node2D]) -> Node2D:
	var player: Node2D = scene.get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return candidates[0]
	var best: Node2D = candidates[0]
	for candidate in candidates:
		if candidate.global_position.distance_squared_to(player.global_position) < best.global_position.distance_squared_to(player.global_position):
			best = candidate
	return best
