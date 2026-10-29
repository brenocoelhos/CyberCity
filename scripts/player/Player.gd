extends CharacterBody2D

## Velocidade em pixels por segundo, editável no Inspector.
@export var speed: float = 160.0

var last_direction: Vector2 = Vector2.DOWN
var _facing: String = "baixo"

## Caminhada automática (clique numa aba de computador no HUD).
## Tamanho de cada "quadradinho" usado para achar o caminho, em pixels.
const AUTO_CELL := 8.0
## Distância extra em volta do jogador e do alvo onde o caminho é procurado.
const AUTO_MARGIN := 192.0
var _pending_target: Node2D = null
var _auto_target: Node2D = null
var _auto_path: PackedVector2Array = PackedVector2Array()
var _auto_index: int = 0
var _stuck_time: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var footstep_timer: Timer = $FootstepTimer

func _ready() -> void:
	sprite.play("parado_baixo")

func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	if _is_ui_blocking():
		_cancel_auto_walk()
	else:
		direction = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down")
		).normalized()
		if direction != Vector2.ZERO:
			# Apertou uma tecla de movimento: o jogador retoma o controle.
			_cancel_auto_walk()
		else:
			if _pending_target != null:
				_plan_auto_walk(_pending_target)
				_pending_target = null
			direction = _auto_walk_direction(delta)

	velocity = direction * speed
	move_and_slide()
	_update_animation(direction)
	_update_footsteps(direction)

func _update_animation(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		last_direction = direction
		# Nas diagonais, a direção horizontal tem prioridade visual.
		if direction.x < 0.0:
			_facing = "esquerda"
		elif direction.x > 0.0:
			_facing = "direita"
		elif direction.y < 0.0:
			_facing = "cima"
		else:
			_facing = "baixo"

	var prefix := "parado_" if direction == Vector2.ZERO else "andar_"
	var animation_name := StringName(prefix + _facing)
	# Não reinicia o mesmo ciclo a cada frame.
	if sprite.animation != animation_name or not sprite.is_playing():
		sprite.play(animation_name)

func _is_ui_blocking() -> bool:
	# Integração com os menus e desafios já existentes no Cyber City.
	return DialogueManager.is_active() \
		or TerminalManager.is_active() \
		or ChallengeManager.is_active() \
		or GameMenu.is_active() \
		or HUD.is_popup_active()

func _update_footsteps(direction: Vector2) -> void:
	if direction == Vector2.ZERO or get_real_velocity().length() < 1.0:
		footstep_timer.stop()
		return
	if footstep_timer.is_stopped():
		SoundManager.play("footstep", -8.0)
		footstep_timer.start()


# --- Caminhada automática ---------------------------------------------------

## Faz o personagem andar sozinho até perto de "target" (ex.: um computador).
## O caminho é calculado no próximo quadro de física, desviando de paredes,
## móveis e NPCs. Qualquer tecla de movimento cancela.
func walk_to(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	_pending_target = target


func is_auto_walking() -> bool:
	return not _auto_path.is_empty()


func _cancel_auto_walk() -> void:
	_pending_target = null
	_auto_target = null
	_auto_path = PackedVector2Array()
	_auto_index = 0


func _auto_walk_direction(delta: float) -> Vector2:
	if _auto_path.is_empty():
		return Vector2.ZERO
	# Chegou: já está dentro da área de interação do alvo.
	if _auto_target is Area2D and is_instance_valid(_auto_target) \
			and (_auto_target as Area2D).overlaps_body(self):
		_finish_auto_walk(true)
		return Vector2.ZERO
	while _auto_index < _auto_path.size() and global_position.distance_to(_auto_path[_auto_index]) < 3.0:
		_auto_index += 1
	if _auto_index >= _auto_path.size():
		# Fim do caminho: só conta como chegada se já está no alcance do alvo.
		_finish_auto_walk(_auto_target is Area2D and is_instance_valid(_auto_target) \
			and (_auto_target as Area2D).overlaps_body(self))
		return Vector2.ZERO
	# Preso em algum canto por muito tempo: desiste.
	if get_real_velocity().length() < speed * 0.2:
		_stuck_time += delta
		if _stuck_time > 0.8:
			_finish_auto_walk()
			return Vector2.ZERO
	else:
		_stuck_time = 0.0
	return (_auto_path[_auto_index] - global_position).normalized()


## Ao parar, vira de frente para o alvo. Se chegou de verdade ao alcance
## dele ("arrived"), já usa o alvo: no caso de um computador, abre o terminal.
func _finish_auto_walk(arrived: bool = false) -> void:
	var target := _auto_target
	if target != null and is_instance_valid(target):
		var d := target.global_position - global_position
		if absf(d.x) > absf(d.y):
			_facing = "direita" if d.x > 0.0 else "esquerda"
		else:
			_facing = "baixo" if d.y > 0.0 else "cima"
	_cancel_auto_walk()
	if arrived and target != null and is_instance_valid(target) and target.has_method("interact"):
		target.interact()


## Monta uma grade de quadradinhos em volta do jogador e do alvo, marca
## como bloqueado tudo onde o corpo do jogador bateria em algo (paredes,
## móveis, NPCs) e usa A* (AStarGrid2D) para achar o caminho.
func _plan_auto_walk(target: Node2D) -> void:
	_cancel_auto_walk()
	if not is_instance_valid(target):
		return
	var shape_node: CollisionShape2D = $CollisionShape2D
	var body_shape := RectangleShape2D.new()
	body_shape.size = (shape_node.shape as RectangleShape2D).size - Vector2(2, 2)

	var bounds := Rect2(global_position, Vector2.ZERO).expand(target.global_position).grow(AUTO_MARGIN)
	var cols := mini(int(ceil(bounds.size.x / AUTO_CELL)), 220)
	var rows := mini(int(ceil(bounds.size.y / AUTO_CELL)), 220)
	var origin := bounds.position

	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, cols, rows)
	grid.cell_size = Vector2(AUTO_CELL, AUTO_CELL)
	grid.offset = origin + Vector2(AUTO_CELL, AUTO_CELL) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()

	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body_shape
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	for y in rows:
		for x in cols:
			var center := grid.offset + Vector2(x, y) * AUTO_CELL
			query.transform = Transform2D(0.0, center + shape_node.position)
			if not space.intersect_shape(query, 1).is_empty():
				grid.set_point_solid(Vector2i(x, y), true)

	var start := Vector2i(((global_position - origin) / AUTO_CELL).floor())
	start = start.clamp(Vector2i.ZERO, Vector2i(cols - 1, rows - 1))
	grid.set_point_solid(start, false)

	# Lugares livres perto do alvo, do mais perto da "frente" (embaixo) para
	# o mais longe. Tenta um por um até achar um que dê para alcançar.
	var goal_hint := target.global_position + Vector2(0, 22)
	var candidates: Array[Vector2i] = []
	var radius := 56.0
	var center_cell := Vector2i(((goal_hint - origin) / AUTO_CELL).floor())
	var r := int(ceil(radius / AUTO_CELL))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := center_cell + Vector2i(dx, dy)
			if not grid.is_in_boundsv(c) or grid.is_point_solid(c):
				continue
			candidates.append(c)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var pa := grid.offset + Vector2(a) * AUTO_CELL
		var pb := grid.offset + Vector2(b) * AUTO_CELL
		return pa.distance_squared_to(goal_hint) < pb.distance_squared_to(goal_hint))

	for i in mini(candidates.size(), 25):
		var path := grid.get_point_path(start, candidates[i])
		if not path.is_empty():
			_auto_path = path
			_auto_index = 0
			_auto_target = target
			_stuck_time = 0.0
			return
