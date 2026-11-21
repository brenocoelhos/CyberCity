extends Node2D
## InteriorBase.gd
## Script compartilhado pelas cenas de interior (HouseInterior, OfficeInterior).
## Mostra no topo da tela o nome do prédio que o jogador acabou de entrar,
## usando o valor guardado por SceneTransition.

@onready var title_label: Label = $UI/TitleLabel


func _ready() -> void:
	title_label.text = SceneTransition.interior_title
	_apply_config(SceneTransition.interior_config)
	_apply_saved_spawn()
	_setup_room_camera()
	_build_room_shape()
	var lighting := Node2D.new()
	lighting.name = "Lighting"
	lighting.set_script(preload("res://scripts/world/InteriorLighting.gd"))
	add_child(lighting)
	_start_ambient()


## Formato de cada sala: blocos de parede que tiram pedaços do retângulo
## (o chão vai de (32, 32) a (416, 288)). Cada bloco é a área no chão que
## fica bloqueada; o desenho em 3/4 é feito por RoomBlock.gd.
const ROOM_SHAPES := {
	# Central de comando: cantos de baixo recortados (formato de "T").
	"OfficeInterior": [
		[Vector2(32, 224), Vector2(100, 224), Vector2(100, 288), Vector2(32, 288)],
		[Vector2(352, 224), Vector2(416, 224), Vector2(416, 288), Vector2(352, 288)],
	],
	# Laboratório: cantos de baixo em diagonal (sala hexagonal).
	"TechCenterInterior": [
		[Vector2(32, 190), Vector2(130, 288), Vector2(32, 288)],
		[Vector2(416, 190), Vector2(416, 288), Vector2(318, 288)],
	],
	# Café: os quatro cantos chanfrados (octógono).
	"AppInterior": [
		[Vector2(32, 32), Vector2(96, 32), Vector2(32, 96)],
		[Vector2(352, 32), Vector2(416, 32), Vector2(416, 96)],
		[Vector2(32, 240), Vector2(80, 288), Vector2(32, 288)],
		[Vector2(416, 240), Vector2(416, 288), Vector2(368, 288)],
	],
	# Casa em "L": sala de estar + quarto no canto de cima (com divisória).
	"HouseInterior": [
		[Vector2(320, 196), Vector2(416, 196), Vector2(416, 288), Vector2(320, 288)],
		[Vector2(300, 32), Vector2(312, 32), Vector2(312, 128), Vector2(300, 128)],
	],
}


func _build_room_shape() -> void:
	for points in ROOM_SHAPES.get(String(name), []):
		var block := Node2D.new()
		block.name = "RoomBlock"
		block.set_script(preload("res://scripts/world/RoomBlock.gd"))
		add_child(block)
		block.setup(PackedVector2Array(points))


## Som ambiente de cada sala, em loop e baixinho (ver tools/gen_ambient_sounds.py).
const AMBIENT := {
	"OfficeInterior": "res://assets/audio/ambient_office.wav",
	"TechCenterInterior": "res://assets/audio/ambient_lab.wav",
	"AppInterior": "res://assets/audio/ambient_cafe.wav",
	"HouseInterior": "res://assets/audio/ambient_house.wav",
}


func _start_ambient() -> void:
	var path: String = AMBIENT.get(String(name), "")
	if path == "" or not ResourceLoader.exists(path):
		return
	var stream: AudioStreamWAV = (load(path) as AudioStreamWAV).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	var player := AudioStreamPlayer.new()
	player.name = "Ambient"
	player.stream = stream
	player.volume_db = -16.0
	add_child(player)
	player.play()


## Câmera fixa no centro da sala, com zoom que mostra a sala inteira (parede
## de cima com as janelas até a porta embaixo). 1,78 deixa os móveis em pixel
## art com tamanho exato de 2 pixels de tela numa tela Full HD (sem borrar).
const ROOM_CENTER := Vector2(224, 154)
const ROOM_ZOOM := 1.78


func _setup_room_camera() -> void:
	var camera := Camera2D.new()
	camera.name = "RoomCamera"
	camera.position = ROOM_CENTER
	camera.zoom = Vector2(ROOM_ZOOM, ROOM_ZOOM)
	add_child(camera)
	camera.make_current()


## Aplica o que o prédio pediu (ver Building.gd): quais NPC e computador
## existem e o que fazem. Só mexe nos nós "Morador" e "Computer" (a casa);
## sem pedido (dicionário vazio) o interior fica exatamente como na cena.
## A posição e o visual desses nós continuam sendo da Arte.
func _apply_config(config: Dictionary) -> void:
	if config.is_empty():
		return

	var npc := get_node_or_null("Morador")
	if npc != null:
		var npc_name: String = String(config.get("npc_name", ""))
		if npc_name == "":
			npc.queue_free()
		else:
			var interaction: Node = npc.get_node("Interaction")
			interaction.npc_name = npc_name
			interaction.dialogue_lines = PackedStringArray(config.get("npc_lines", PackedStringArray()))
			interaction.mission_to_start = String(config.get("npc_mission", ""))
			npc.get_node("NameLabel").text = npc_name

	var is_boss_house: bool = bool(config.get("boss", false))
	var computer := get_node_or_null("Computer")
	if computer != null:
		var challenge_id: String = String(config.get("computer_challenge", ""))
		# Na casa do hacker o computador fica (é o do jogador no duelo).
		if challenge_id == "" and not is_boss_house:
			computer.queue_free()
		else:
			computer.challenge_id = challenge_id

	# Interiores com vários computadores (escritórios): nó -> desafio.
	var computers: Dictionary = Dictionary(config.get("computers", {}))
	for node_name in computers.keys():
		var node := get_node_or_null(String(node_name))
		if node == null:
			continue
		var wanted: String = String(computers[node_name])
		if wanted == "":
			node.queue_free()
		else:
			node.challenge_id = wanted

	if is_boss_house:
		BossManager.begin_encounter()


## Ao carregar um save feito dentro do prédio, põe o jogador onde ele estava.
func _apply_saved_spawn() -> void:
	if not SceneTransition.has_interior_spawn:
		return
	SceneTransition.has_interior_spawn = false
	var player: Node2D = get_node_or_null("Player")
	if player == null:
		return
	player.global_position = SceneTransition.interior_spawn_position
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if camera:
		camera.reset_smoothing()
