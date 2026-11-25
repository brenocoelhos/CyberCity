extends StaticBody2D
## PlazaMonument.gd
## Monumento holográfico do centro da Praça Central: base redonda em
## degraus com anéis de luz que pulsam, um feixe de luz e um cristal
## flutuante que sobe e desce devagar, com faíscas subindo.
## A colisão é só a base (o Guia e o jogador andam em volta).

const CYAN := Color(0.3, 0.88, 1.0)
const BLUE := Color(0.25, 0.5, 1.0)
const PURPLE := Color(0.6, 0.4, 1.0)

var _time := 0.0
var _glow_texture: GradientTexture2D


func _ready() -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(104, 32)
	collision.shape = shape
	collision.position = Vector2(0, -8)
	add_child(collision)
	_add_glow()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Luz forte em volta do cristal (soma de luz, acima de tudo).
func _add_glow() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	_glow_texture = GradientTexture2D.new()
	_glow_texture.gradient = gradient
	_glow_texture.fill = GradientTexture2D.FILL_RADIAL
	_glow_texture.fill_from = Vector2(0.5, 0.5)
	_glow_texture.fill_to = Vector2(1.0, 0.5)
	for spec in [[Vector2(0, -72), 150.0, 0.45, CYAN], [Vector2(0, -4), 190.0, 0.35, BLUE]]:
		var glow := Sprite2D.new()
		glow.texture = _glow_texture
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = material
		glow.position = spec[0]
		glow.scale = Vector2(spec[1], spec[1] * (0.55 if spec[0].y > -10 else 1.0)) / 64.0
		glow.modulate = Color(spec[3], spec[2])
		glow.z_index = 1
		add_child(glow)


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 2.0)
	# Base em dois degraus (vista de cima, achatada).
	_ellipse(Vector2(0, 6), Vector2(66, 26), Color("0b1426"))
	_ellipse(Vector2(0, 2), Vector2(64, 24), Color("27375a"))
	_ellipse(Vector2(0, 0), Vector2(60, 22), Color("1a2742"))
	_ellipse(Vector2(0, -6), Vector2(46, 17), Color("31446b"))
	_ellipse(Vector2(0, -8), Vector2(42, 15), Color("0d2340"))
	# Anéis de luz (um deles se expande e some, em loop).
	_ring(Vector2(0, 0), Vector2(60, 22), Color(CYAN, 0.75), 1.5)
	_ring(Vector2(0, -8), Vector2(42, 15), Color(CYAN, 0.9), 1.5)
	_ring(Vector2(0, -8), Vector2(28, 10), Color(CYAN, 0.5 + 0.3 * pulse), 1.0)
	var wave := fposmod(_time * 0.5, 1.0)
	_ring(Vector2(0, -8), Vector2(42, 15) * (1.0 + wave * 0.9), Color(CYAN, 0.5 * (1.0 - wave)), 1.0)
	# Poça de luz no centro.
	_ellipse(Vector2(0, -8), Vector2(18, 6.5), Color(CYAN, 0.35 + 0.25 * pulse))
	_ellipse(Vector2(0, -8), Vector2(9, 3.2), Color(0.85, 0.97, 1.0, 0.8))

	# Feixe de luz até o cristal.
	var beam := PackedVector2Array([Vector2(-14, -8), Vector2(14, -8), Vector2(6, -112), Vector2(-6, -112)])
	draw_polygon(beam, PackedColorArray([Color(CYAN, 0.35), Color(CYAN, 0.35), Color(CYAN, 0.0), Color(CYAN, 0.0)]))

	# Cristal (octaedro) flutuando.
	var float_y := -74.0 + sin(_time * 1.3) * 4.0
	var c := Vector2(0, float_y)
	var top := c + Vector2(0, -30)
	var bottom := c + Vector2(0, 30)
	var left := c + Vector2(-20, 0)
	var right := c + Vector2(20, 0)
	var front := c + Vector2(4, 4)
	draw_colored_polygon(PackedVector2Array([top, left, front]), Color("2f7fe0"))
	draw_colored_polygon(PackedVector2Array([top, front, right]), Color("6fd8ff"))
	draw_colored_polygon(PackedVector2Array([bottom, front, left]), Color("1a4fb0"))
	draw_colored_polygon(PackedVector2Array([bottom, right, front]), Color("3d9df0"))
	draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color(0.75, 0.97, 1.0), 1.5)
	draw_line(top, front, Color(0.85, 1.0, 1.0, 0.8), 1.0)
	draw_line(front, bottom, Color(0.6, 0.85, 1.0, 0.6), 1.0)
	draw_line(left, front, Color(0.6, 0.85, 1.0, 0.5), 1.0)
	draw_line(front, right, Color(0.85, 1.0, 1.0, 0.7), 1.0)
	# Brilho na ponta.
	draw_circle(top + Vector2(0, 4), 2.0, Color(1, 1, 1, 0.6 + 0.4 * pulse))

	# Faíscas subindo pelo feixe.
	for i in range(6):
		var t := fposmod(_time * 0.35 + i / 6.0, 1.0)
		var x := sin(i * 2.3 + _time) * 10.0
		var p := Vector2(x, lerpf(-12.0, -110.0, t))
		draw_rect(Rect2(p, Vector2(2, 2)), Color(PURPLE if i % 2 == 0 else CYAN, 1.0 - t))


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for k in range(40):
		var a := TAU * k / 40.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)


func _ring(center: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for k in range(41):
		var a := TAU * k / 40.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_polyline(points, color, width)
