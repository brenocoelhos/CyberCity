extends Node2D
## PlazaBed.gd
## Canteiro elevado da Praça Central (PlazaDesign.gd cria): borda de pedra,
## terra com grama e uma faixa de neon ciano na frente. O nó fica na linha da
## frente do canteiro (y de baixo), para o y-sort cobrir quem passa atrás.

const RIM := Color(0.36, 0.4, 0.56)
const RIM_TOP := Color(0.52, 0.57, 0.74)
const FACE := Color(0.2, 0.22, 0.34)
const GRASS := Color(0.2, 0.42, 0.2)
const GRASS_LIGHT := Color(0.3, 0.56, 0.26)
const NEON := Color(0.3, 0.88, 1.0)
const HEIGHT := 10.0

var _size := Vector2(64, 32)


func setup(size_value: Vector2) -> void:
	_size = size_value
	queue_redraw()


func _draw() -> void:
	var top := Rect2(0, -_size.y - HEIGHT, _size.x, _size.y)
	# Frente (face de pedra) com a faixa de neon.
	draw_rect(Rect2(0, -HEIGHT, _size.x, HEIGHT), FACE)
	draw_line(Vector2(2, -HEIGHT * 0.45), Vector2(_size.x - 2, -HEIGHT * 0.45), Color(NEON, 0.3), 4.0)
	draw_line(Vector2(2, -HEIGHT * 0.45), Vector2(_size.x - 2, -HEIGHT * 0.45), NEON, 1.5)
	draw_line(Vector2(0, 0), Vector2(_size.x, 0), Color(0, 0, 0.05, 0.6), 1.0)
	# Borda de cima e terra com grama.
	draw_rect(top, RIM)
	draw_rect(Rect2(top.position + Vector2(0, 0), Vector2(top.size.x, 2)), RIM_TOP)
	var soil := top.grow(-4)
	draw_rect(soil, GRASS)
	for i in range(int(soil.size.x * soil.size.y / 40.0)):
		var x := soil.position.x + fposmod(i * 37.0 + i * i * 3.0, soil.size.x - 2)
		var y := soil.position.y + fposmod(i * 23.0 + i * 11.0, soil.size.y - 2)
		draw_rect(Rect2(x, y, 2, 1), GRASS_LIGHT)
	# Luzinhas na borda (como na referência).
	for x in [4.0, _size.x - 6.0]:
		draw_rect(Rect2(x, -HEIGHT - 4, 3, 3), Color(1.0, 0.9, 0.6))
