extends Node2D
## CityShape.gd
## Deixa a cidade menos "retangular":
##   - os quatro cantos do anel de ruas viram curvas suaves (raios diferentes
##     em cima e embaixo), desenhadas por cima do chão de tiles;
##   - em volta da cidade há água com a margem ondulada e neon
##     (assets/shaders/city_water.gdshader), e os cantos de água bloqueiam o
##     jogador.
## City.gd cria este nó e já tira do chão as ruas dos cantos (ver
## City.ROUND_CORNERS); aqui só se desenha e se cria a colisão.

const ASPHALT := Color8(33, 34, 53)
const LANE := Color8(125, 128, 150)
const SIDEWALK := Color8(100, 101, 114)
const SIDEWALK_LINE := Color8(78, 79, 92)
const CURB := Color8(140, 142, 160)

var _city: Node2D
var _tile: float = 32.0


func setup(city: Node2D) -> void:
	_city = city
	_tile = float(city.TILE_SIZE)
	z_index = -1
	_add_water()
	_add_corner_walls()
	queue_redraw()


## Centro de cada curva e de que ângulo a que ângulo ela vai (em graus).
func corner_arcs() -> Array:
	var c: Dictionary = _city.ROUND_CORNERS
	var left: float = (_city.ROADS_X[0] + 0.5) * _tile
	var right: float = (_city.ROADS_X[-1] + 0.5) * _tile
	var top: float = (_city.ROADS_Y[0] + 0.5) * _tile
	var bottom: float = (_city.ROADS_Y[-1] + 0.5) * _tile
	return [
		[Vector2(left + c["tl"] * _tile, top + c["tl"] * _tile), c["tl"] * _tile, 180.0, 270.0],
		[Vector2(right - c["tr"] * _tile, top + c["tr"] * _tile), c["tr"] * _tile, 270.0, 360.0],
		[Vector2(right - c["br"] * _tile, bottom - c["br"] * _tile), c["br"] * _tile, 0.0, 90.0],
		[Vector2(left + c["bl"] * _tile, bottom - c["bl"] * _tile), c["bl"] * _tile, 90.0, 180.0],
	]


func _draw() -> void:
	for arc in corner_arcs():
		var center: Vector2 = arc[0]
		var radius: float = arc[1]
		var from: float = deg_to_rad(arc[2])
		var to: float = deg_to_rad(arc[3])
		var points := 48
		# calçadas dos dois lados, depois o asfalto por cima
		_band(center, radius - _tile * 1.5, radius + _tile * 1.5, from, to, SIDEWALK, points)
		# juntas da calçada (raios curtos)
		for i in range(0, 13):
			var a: float = lerpf(from, to, i / 12.0)
			var dir := Vector2.from_angle(a)
			draw_line(center + dir * (radius - _tile * 1.5), center + dir * (radius - _tile * 0.5), SIDEWALK_LINE, 1.0)
			draw_line(center + dir * (radius + _tile * 0.5), center + dir * (radius + _tile * 1.5), SIDEWALK_LINE, 1.0)
		draw_arc(center, radius - _tile, from, to, points, SIDEWALK_LINE, 1.0)
		draw_arc(center, radius + _tile, from, to, points, SIDEWALK_LINE, 1.0)
		_band(center, radius - _tile * 0.5, radius + _tile * 0.5, from, to, ASPHALT, points)
		draw_arc(center, radius - _tile * 0.5, from, to, points, CURB, 2.0)
		draw_arc(center, radius + _tile * 0.5, from, to, points, CURB, 2.0)
		# faixa do meio tracejada
		var dashes := int(radius * (to - from) / 14.0)
		for i in range(dashes):
			if i % 2 == 0:
				var a0: float = lerpf(from, to, float(i) / dashes)
				var a1: float = lerpf(from, to, float(i + 1) / dashes)
				draw_arc(center, radius, a0, a1, 4, LANE, 2.0)


## Faixa em forma de anel (pedaço de coroa circular) preenchida.
func _band(center: Vector2, r0: float, r1: float, from: float, to: float, color: Color, points: int) -> void:
	var poly := PackedVector2Array()
	for i in range(points + 1):
		poly.append(center + Vector2.from_angle(lerpf(from, to, float(i) / points)) * r1)
	for i in range(points, -1, -1):
		poly.append(center + Vector2.from_angle(lerpf(from, to, float(i) / points)) * r0)
	draw_colored_polygon(poly, color)


func _map_size() -> Vector2:
	return Vector2(_city.MAP_WIDTH, _city.MAP_HEIGHT) * _tile


func _add_water() -> void:
	var c: Dictionary = _city.ROUND_CORNERS
	var water := ColorRect.new()
	water.name = "Water"
	water.size = _map_size()
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/city_water.gdshader")
	material.set_shader_parameter("map_size", _map_size())
	material.set_shader_parameter("inset", _tile)
	# A margem fica na beira de fora da calçada externa (raio da curva + 1,5 tile).
	material.set_shader_parameter("radii", Vector4(c["tl"] + 1.5, c["tr"] + 1.5, c["br"] + 1.5, c["bl"] + 1.5) * _tile)
	water.material = material
	add_child(water)  # filho: desenhado depois (por cima) das curvas deste nó


## Os cantos de água bloqueiam o jogador (as bordas retas já têm as paredes
## de City._build_map_bounds).
func _add_corner_walls() -> void:
	var size := _map_size()
	var corners := [Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]
	var arcs := corner_arcs()
	for i in 4:
		var center: Vector2 = arcs[i][0]
		var outer: float = arcs[i][1] + _tile * 1.5
		var from: float = deg_to_rad(arcs[i][2])
		var to: float = deg_to_rad(arcs[i][3])
		var poly := PackedVector2Array()
		poly.append(corners[i])
		var start := center + Vector2.from_angle(from) * outer
		var finish := center + Vector2.from_angle(to) * outer
		poly.append(_to_edge(start, center, corners[i]))
		for k in range(17):
			poly.append(center + Vector2.from_angle(lerpf(from, to, k / 16.0)) * outer)
		poly.append(_to_edge(finish, center, corners[i]))
		var body := StaticBody2D.new()
		body.collision_mask = 0
		var shape := CollisionPolygon2D.new()
		shape.polygon = poly
		body.add_child(shape)
		add_child(body)


## Leva a ponta da curva até a borda do mapa: pontas à esquerda/direita do
## centro vão para a borda vertical; pontas em cima/embaixo, para a horizontal.
func _to_edge(point: Vector2, center: Vector2, corner: Vector2) -> Vector2:
	if absf(point.y - center.y) < 1.0:
		return Vector2(corner.x, point.y)
	return Vector2(point.x, corner.y)
