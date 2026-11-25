extends StaticBody2D
## HoloGlobe.gd
## Holograma central do escritório: plataforma redonda com anéis de luz e um
## globo digital (linhas de latitude/longitude girando) com um anel em órbita.
## A colisão é só a plataforma. O nó fica na base da plataforma (y-sort).

const CYAN := Color(0.3, 0.88, 1.0)
const BLUE := Color(0.25, 0.55, 1.0)
const MAGENTA := Color(1.0, 0.35, 0.85)
const GLOBE_Y := -70.0
const R := 26.0

var _time := 0.0


func _ready() -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(104, 30)
	collision.shape = shape
	collision.position = Vector2(0, -10)
	add_child(collision)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	for spec in [[Vector2(0, GLOBE_Y), Vector2(150, 150), 0.4, CYAN], [Vector2(0, -10), Vector2(170, 70), 0.4, BLUE]]:
		var glow := Sprite2D.new()
		glow.texture = texture
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = material
		glow.position = spec[0]
		glow.scale = spec[1] / 64.0
		glow.modulate = Color(spec[3], spec[2])
		glow.z_index = 1
		add_child(glow)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 2.0)
	# Plataforma em degraus.
	_ellipse(Vector2(0, 4), Vector2(58, 22), Color("0b1426"))
	_ellipse(Vector2(0, 0), Vector2(56, 20), Color("2a3a5e"))
	_ellipse(Vector2(0, -2), Vector2(52, 18), Color("17233d"))
	_ring(Vector2(0, -2), Vector2(52, 18), Color(CYAN, 0.85), 1.5)
	for k in range(12):
		var a := TAU * k / 12.0 + _time * 0.3
		draw_rect(Rect2(Vector2(cos(a) * 49, -2 + sin(a) * 16.5) - Vector2(1.5, 1), Vector2(3, 2)), Color(MAGENTA, 0.9))
	_ellipse(Vector2(0, -8), Vector2(34, 12), Color("31446b"))
	_ellipse(Vector2(0, -10), Vector2(30, 10), Color("0d2340"))
	_ring(Vector2(0, -10), Vector2(30, 10), CYAN, 1.5)
	_ring(Vector2(0, -10), Vector2(18, 6), Color(CYAN, 0.5 + 0.4 * pulse), 1.0)
	var wave := fposmod(_time * 0.45, 1.0)
	_ring(Vector2(0, -10), Vector2(30, 10) * (1.0 + wave * 0.8), Color(CYAN, 0.5 * (1.0 - wave)), 1.0)
	_ellipse(Vector2(0, -10), Vector2(10, 3.5), Color(0.85, 0.97, 1.0, 0.8))

	# Feixe de luz.
	var beam := PackedVector2Array([Vector2(-22, -10), Vector2(22, -10), Vector2(16, GLOBE_Y + 10), Vector2(-16, GLOBE_Y + 10)])
	draw_polygon(beam, PackedColorArray([Color(CYAN, 0.3), Color(CYAN, 0.3), Color(CYAN, 0.05), Color(CYAN, 0.05)]))

	# Globo: disco translúcido, latitudes e longitudes girando.
	var c := Vector2(0, GLOBE_Y + sin(_time * 1.2) * 2.0)
	draw_circle(c, R, Color(0.1, 0.45, 0.85, 0.35))
	for lat in [-0.66, -0.33, 0.0, 0.33, 0.66]:
		var y: float = lat * R
		var half: float = sqrt(maxf(R * R - y * y, 0.0))
		_ring(c + Vector2(0, y), Vector2(half, half * 0.18), Color(CYAN, 0.55), 1.0)
	for k in range(6):
		var phase := fposmod(_time * 0.6 + k * PI / 6.0, PI)
		var rx := R * cos(phase)
		_ring(c, Vector2(absf(rx), R), Color(CYAN, 0.35 + 0.35 * absf(cos(phase))), 1.0)
	# "Continentes": pontos que giram junto.
	for k in range(14):
		var lon := fposmod(_time * 0.6 + k * 0.9, TAU)
		if cos(lon) < 0.0:
			continue
		var lat2 := sin(k * 2.1) * 0.7
		var p := c + Vector2(sin(lon) * R * cos(lat2), sin(lat2) * R)
		draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.75, 1.0, 1.0, 0.85))
	draw_arc(c, R, 0, TAU, 40, Color(0.7, 0.95, 1.0), 1.5)
	# Anel em órbita (inclinado) com um satélite.
	var orbit := Vector2(R * 1.55, R * 0.42)
	_ring(c, orbit, Color(CYAN, 0.7), 1.0)
	var sa := _time * 1.4
	draw_circle(c + Vector2(cos(sa) * orbit.x, sin(sa) * orbit.y), 2.5, Color(1, 1, 1, 0.95))


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for k in range(40):
		var a := TAU * k / 40.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)


func _ring(center: Vector2, radii: Vector2, color: Color, width: float) -> void:
	if radii.x < 0.5 or radii.y < 0.5:
		return
	var points := PackedVector2Array()
	for k in range(41):
		var a := TAU * k / 40.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_polyline(points, color, width)
