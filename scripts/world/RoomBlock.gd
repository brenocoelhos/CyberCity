extends Node2D
## RoomBlock.gd
## Um "pedaço de parede" dentro da sala, para os interiores não serem todos
## retângulos iguais (cantos cortados, sala em L, divisória do quarto...).
## InteriorBase.gd cria estes blocos a partir de ROOM_SHAPES; não é preciso
## pôr nada na cena.
##
## footprint = onde o bloco toca o chão (em coordenadas da sala). É a área
## bloqueada para o jogador. O desenho segue a vista 3/4 do jogo: o "teto" do
## bloco fica HEIGHT pixels acima do chão e as faces viradas para a câmera
## (para baixo) aparecem como parede, com uma faixa de neon.
## O nó fica na altura do topo do bloco: com o y-sort da sala, quem está atrás
## do bloco é coberto por ele e quem está na frente aparece por cima.

const HEIGHT := 26.0
const CAP := Color(0.02, 0.025, 0.055)
const CAP_LINE := Color(0.06, 0.08, 0.16)
const FACE_TOP := Color(0.27, 0.33, 0.52)
const FACE_BOTTOM := Color(0.07, 0.09, 0.18)
const NEON := Color(0.25, 0.9, 1.0)

var footprint := PackedVector2Array()


func setup(points: PackedVector2Array) -> void:
	footprint = points
	var top := INF
	for p in points:
		top = minf(top, p.y)
	position = Vector2(0, top)

	var body := StaticBody2D.new()
	body.collision_mask = 0
	var shape := CollisionPolygon2D.new()
	shape.polygon = _local(footprint, Vector2.ZERO)
	body.add_child(shape)
	add_child(body)
	queue_redraw()


func _local(points: PackedVector2Array, shift: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p - position + shift)
	return out


func _draw() -> void:
	if footprint.size() < 3:
		return
	var base := _local(footprint, Vector2.ZERO)
	var cap := _local(footprint, Vector2(0, -HEIGHT))
	var clockwise := Geometry2D.is_polygon_clockwise(base)

	# Faces viradas para a câmera (normal apontando para baixo).
	for i in base.size():
		var a: Vector2 = base[i]
		var b: Vector2 = base[(i + 1) % base.size()]
		var edge := b - a
		var normal := Vector2(edge.y, -edge.x).normalized()
		if clockwise:
			normal = -normal
		if normal.y < 0.2:
			continue
		var top_a := a - Vector2(0, HEIGHT)
		var top_b := b - Vector2(0, HEIGHT)
		draw_polygon(PackedVector2Array([top_a, top_b, b, a]),
			PackedColorArray([FACE_TOP, FACE_TOP, FACE_BOTTOM, FACE_BOTTOM]))
		var mid := Vector2(0, HEIGHT * 0.45)
		draw_line(top_a + mid, top_b + mid, Color(NEON, 0.85), 1.5)
		draw_line(top_a + mid, top_b + mid, Color(NEON, 0.25), 4.0)
		# painéis verticais, como nas paredes laterais
		var steps := int(edge.length() / 14.0)
		for k in range(1, steps):
			var p := a.lerp(b, float(k) / steps)
			draw_line(p - Vector2(0, HEIGHT - 2), p - Vector2(0, 2), Color(0.05, 0.06, 0.13, 0.8), 1.0)
		draw_line(top_a, top_b, Color(0.5, 0.6, 0.85), 1.0)
		draw_line(a, b, Color(0, 0, 0.04, 0.9), 1.0)
		draw_line(a + Vector2(0, 1), b + Vector2(0, 1), Color(0, 0, 0.05, 0.35), 3.0)

	# Teto do bloco, com um quadriculado discreto e borda de neon.
	draw_colored_polygon(cap, CAP)
	var box := Rect2(cap[0], Vector2.ZERO)
	for p in cap:
		box = box.expand(p)
	var x := box.position.x + 12.0
	while x < box.end.x:
		_clipped_line(cap, Vector2(x, box.position.y), Vector2(x, box.end.y))
		x += 16.0
	var y := box.position.y + 12.0
	while y < box.end.y:
		_clipped_line(cap, Vector2(box.position.x, y), Vector2(box.end.x, y))
		y += 16.0
	var outline := cap.duplicate()
	outline.append(cap[0])
	draw_polyline(outline, Color(NEON, 0.25), 4.0)
	draw_polyline(outline, Color(NEON, 0.9), 1.5)


## Linha do quadriculado cortada para ficar só dentro do teto.
func _clipped_line(poly: PackedVector2Array, from: Vector2, to: Vector2) -> void:
	for piece in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([from, to]), poly):
		if piece.size() >= 2:
			draw_line(piece[0], piece[piece.size() - 1], CAP_LINE, 1.0)
