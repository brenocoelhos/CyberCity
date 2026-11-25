extends Node2D
## PlazaDesign.gd
## A Praça Central (quarteirão de x 736..1248, y 128..384), montada por
## código como o resto da cidade. Tudo é simétrico em torno do eixo x = 992:
##   - piso de pedra com variação de tom, um caminho iluminado que sai da
##     calçada de baixo e chega ao monumento, um círculo de pedra em volta do
##     monumento e losangos gravados no chão;
##   - canteiros elevados (borda de pedra com faixa de neon) com árvores e
##     flores: dois em cima (ao lado dos terminais) e dois embaixo, ladeando a
##     entrada; floreiras menores nos cantos;
##   - painéis holográficos, bancos com luz embaixo e halos nos postes e nos
##     terminais.
## O monumento holográfico é PlazaMonument.gd. Os terminais, o Guia e as
## portas continuam sendo os nós da cena City.tscn (nada de mecânica muda).
## Os canteiros e bancos têm colisão pequena; os caminhos ficam livres:
## de baixo até o monumento, dos lados (y 214..318) e de cima até os terminais.

const PlazaBed := preload("res://scripts/world/PlazaBed.gd")

const BLOCK := Rect2(736, 128, 512, 256)
const AXIS := 992.0
const PATH := Rect2(946, 292, 92, 92)          # caminho de baixo até o monumento
const CIRCLE_CENTER := Vector2(992, 262)
const CIRCLE_RADII := Vector2(118, 64)

const STONE := Color(0.15, 0.16, 0.25)
const STONE_LIGHT := Color(0.2, 0.22, 0.33)
const STONE_LINE := Color(0.115, 0.125, 0.205)
const CYAN := Color(0.3, 0.88, 1.0)
const PURPLE := Color(0.65, 0.4, 1.0)

## Canteiros elevados: [retângulo no chão, árvores (x, y), flores (x, y)].
const BEDS := [
	[Rect2(780, 152, 116, 58), [Vector2(812, 196), Vector2(862, 188)], [Vector2(838, 206), Vector2(790, 208)]],
	[Rect2(1088, 152, 116, 58), [Vector2(1172, 196), Vector2(1122, 188)], [Vector2(1146, 206), Vector2(1194, 208)]],
	[Rect2(866, 318, 78, 40), [Vector2(892, 346)], [Vector2(922, 352)]],
	[Rect2(1040, 318, 78, 40), [Vector2(1092, 346)], [Vector2(1062, 352)]],
]
## Floreira baixa do canto.
## (O canto de baixo à direita já tem o ponto de ônibus de City.gd.)
const PLANTERS := [Vector2(784, 372)]
const BENCHES := [Vector2(816, 252), Vector2(1168, 252), Vector2(800, 330)]
const AD_PANELS := [Vector2(758, 214), Vector2(1226, 214)]
const LAMPS := [Vector2(720, 288), Vector2(1264, 288)]   # postes que já existem na calçada
const TERMINALS := [Vector2(960, 192), Vector2(1024, 192)]

var _glow: GradientTexture2D
var _pulse: Array = []
var _time := 0.0


func setup(city: Node2D) -> void:
	name = "PlazaDesign"
	z_index = -1
	_glow = _radial()
	var decor: Node2D = city.get_node("Decor")
	for bed in BEDS:
		_add_bed(city, decor, bed[0], bed[1], bed[2])
	for at in PLANTERS:
		_add_sprite(decor, "planter", at)
		_add_body(city, Rect2(at.x - 28, at.y - 12, 56, 12))
		_floor_light(at + Vector2(0, -4), CYAN, 70.0, 0.18)
	for at in BENCHES:
		_add_sprite(decor, "bench", at)
		_add_body(city, Rect2(at.x - 26, at.y - 10, 52, 10))
		_floor_light(at + Vector2(0, -2), CYAN, 76.0, 0.22, true)
	for at in AD_PANELS:
		_add_sprite(decor, "kiosk", at)
		_add_body(city, Rect2(at.x - 12, at.y - 8, 24, 8))
		_floor_light(at + Vector2(0, -26), PURPLE, 90.0, 0.35, true)
	for at in LAMPS:
		_floor_light(at + Vector2(0, -2), Color(0.55, 0.75, 1.0), 120.0, 0.3)
		_halo(at + Vector2(0, -84), Color(0.6, 0.8, 1.0), 46.0, 0.55)
	for at in TERMINALS:
		_floor_light(at + Vector2(0, 2), CYAN, 64.0, 0.3, true)
	# Luz do caminho de entrada.
	for y in range(int(PATH.position.y) + 10, int(PATH.end.y), 24):
		_floor_light(Vector2(PATH.position.x + 2, y), CYAN, 22.0, 0.35)
		_floor_light(Vector2(PATH.end.x - 2, y), CYAN, 22.0, 0.35)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	for entry in _pulse:
		var sprite: Sprite2D = entry[0]
		if is_instance_valid(sprite):
			sprite.modulate.a = entry[1] * (0.8 + 0.2 * sin(_time * 1.6 + entry[2]))


# --- Piso -------------------------------------------------------------------

func _draw() -> void:
	# Pedras de 32 px com tom variando um pouco e bisel claro/escuro.
	for ty in range(int(BLOCK.position.y), int(BLOCK.end.y), 32):
		for tx in range(int(BLOCK.position.x), int(BLOCK.end.x), 32):
			var shade := float(posmod(tx * 7 + ty * 13 + tx * ty / 32, 9)) / 9.0
			var color := STONE.lerp(STONE_LIGHT, shade * 0.45)
			var cell := Rect2(tx, ty, 32, 32)
			draw_rect(cell, color)
			draw_line(cell.position + Vector2(1, 1), Vector2(cell.end.x - 1, cell.position.y + 1), color.lightened(0.12), 1.0)
			draw_line(cell.position + Vector2(1, 1), Vector2(cell.position.x + 1, cell.end.y - 1), color.lightened(0.08), 1.0)
			draw_rect(cell, STONE_LINE, false, 1.0)
			# Meia junta no meio de algumas pedras (pedra retangular).
			if posmod(tx + ty * 3, 5) == 0:
				draw_line(Vector2(tx + 16, ty + 2), Vector2(tx + 16, ty + 30), STONE_LINE, 1.0)
	# Faixa mais escura em volta do quarteirão (meio-fio interno).
	draw_rect(BLOCK, Color(0.05, 0.06, 0.11), false, 2.0)
	draw_rect(BLOCK.grow(-3), Color(0.3, 0.4, 0.6, 0.25), false, 1.0)

	# Círculo de pedra em volta do monumento.
	_ellipse(CIRCLE_CENTER, CIRCLE_RADII, Color(0.12, 0.13, 0.22))
	_ellipse(CIRCLE_CENTER, CIRCLE_RADII - Vector2(10, 6), Color(0.18, 0.2, 0.31))
	for k in range(16):
		var a := TAU * k / 16.0
		var dir := Vector2(cos(a), sin(a))
		draw_line(CIRCLE_CENTER + dir * (CIRCLE_RADII - Vector2(10, 6)), CIRCLE_CENTER + dir * CIRCLE_RADII * 0.55, STONE_LINE, 1.0)
	_ellipse_line(CIRCLE_CENTER, CIRCLE_RADII * 0.55, STONE_LINE, 1.0)
	_ellipse_line(CIRCLE_CENTER, CIRCLE_RADII, Color(CYAN, 0.55), 1.5)
	_ellipse_line(CIRCLE_CENTER, CIRCLE_RADII + Vector2(3, 2), Color(CYAN, 0.15), 3.0)

	# Caminho de entrada: pedras claras e bordas de neon.
	draw_rect(PATH, Color(0.21, 0.23, 0.35))
	for y in range(int(PATH.position.y), int(PATH.end.y), 24):
		draw_line(Vector2(PATH.position.x, y), Vector2(PATH.end.x, y), STONE_LINE, 1.0)
	draw_line(Vector2(AXIS, PATH.position.y), Vector2(AXIS, PATH.end.y), STONE_LINE, 1.0)
	for x in [PATH.position.x, PATH.end.x]:
		draw_line(Vector2(x, PATH.position.y), Vector2(x, PATH.end.y), Color(CYAN, 0.25), 4.0)
		draw_line(Vector2(x, PATH.position.y), Vector2(x, PATH.end.y), Color(CYAN, 0.9), 1.5)

	# Losangos gravados no piso (dos lados e na entrada).
	for center in [Vector2(816, 296), Vector2(1168, 296), Vector2(AXIS, 160)]:
		_diamond(center, 22.0)


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for k in range(48):
		var a := TAU * k / 48.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)


func _ellipse_line(center: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for k in range(49):
		var a := TAU * k / 48.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_polyline(points, color, width)


func _diamond(center: Vector2, r: float) -> void:
	for scale in [1.0, 0.6]:
		var pts := PackedVector2Array([center + Vector2(0, -r * scale * 0.6), center + Vector2(r * scale, 0),
			center + Vector2(0, r * scale * 0.6), center + Vector2(-r * scale, 0), center + Vector2(0, -r * scale * 0.6)])
		draw_polyline(pts, STONE_LINE, 2.0)
		draw_polyline(pts, Color(0.45, 0.55, 0.8, 0.35), 1.0)


# --- Canteiros, objetos e luzes ---------------------------------------------

func _add_bed(city: Node2D, decor: Node2D, rect: Rect2, trees: Array, flowers: Array) -> void:
	var bed := Node2D.new()
	bed.set_script(preload("res://scripts/world/PlazaBed.gd"))
	bed.position = Vector2(rect.position.x, rect.end.y)
	decor.add_child(bed)
	bed.setup(rect.size)
	_add_body(city, rect)
	# Plantas são filhas do canteiro: desenhadas logo depois dele (por cima da
	# terra) e ordenadas junto com ele em relação ao jogador.
	for at in flowers:
		_add_sprite(bed, "flowers", at - bed.position - Vector2(0, PlazaBed.HEIGHT), 0.7)
	for at in trees:
		_add_sprite(bed, "tree", at - bed.position - Vector2(0, PlazaBed.HEIGHT))
	# Faixa de neon da borda acesa no chão.
	_floor_light(Vector2(rect.get_center().x, rect.end.y + 4), CYAN, rect.size.x * 1.3, 0.25)


func _add_sprite(decor: Node, texture_name: String, at: Vector2, scale_value: float = 1.0) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/environment/cyber/%s.png" % texture_name)
	sprite.position = at
	sprite.scale = Vector2.ONE * scale_value
	sprite.offset.y = -sprite.texture.get_height() / 2.0
	decor.add_child(sprite)
	return sprite


func _add_body(city: Node2D, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)
	city.add_child(body)


func _radial() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


## Poça de luz no chão (achatada, embaixo dos personagens).
func _floor_light(at: Vector2, color: Color, diameter: float, strength: float, pulse: bool = false) -> void:
	var glow := _glow_sprite(at, color, Vector2(diameter, diameter * 0.5), strength)
	glow.z_index = 0  # relativo: -1 como o piso, desenhado depois dele
	add_child(glow)
	if pulse:
		_pulse.append([glow, strength, randf() * TAU])


## Halo no ar (luz do poste), acima dos personagens.
func _halo(at: Vector2, color: Color, diameter: float, strength: float) -> void:
	var glow := _glow_sprite(at, color, Vector2(diameter, diameter), strength)
	glow.z_as_relative = false
	glow.z_index = 30
	add_child(glow)


func _glow_sprite(at: Vector2, color: Color, size: Vector2, strength: float) -> Sprite2D:
	var glow := Sprite2D.new()
	glow.texture = _glow
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = material
	glow.position = at
	glow.scale = size / 128.0
	glow.modulate = Color(color, strength)
	return glow
