extends Node2D
## InteriorLighting.gd
## Iluminação dos interiores, montada sozinha a partir do que há na sala:
##   - cantos e bordas um pouco mais escuros (vinheta), para dar clima;
##   - halos de luz (soma de luz, blend "Add") nos neons das paredes, no
##     holograma, nos tubos, telas, quadros, máquinas e computadores;
##   - algumas luzes piscam de leve.
## Fica abaixo das etiquetas de nome (z_index 50), então os nomes não escurecem.
## InteriorBase.gd cria este nó; não é preciso pôr nada na cena.

const ROOM := Rect2(0, -44, 448, 396)

## Cor do halo por móvel (pelo nome da textura em assets/.../props/).
const PROP_LIGHTS := {
	"hologram": [Color(0.3, 0.8, 1.0), 120.0, 0.55],
	"holo_globe": [Color(0.35, 0.85, 1.0), 90.0, 0.6],
	"tube": [Color(0.25, 0.75, 1.0), 70.0, 0.45],
	"tube_big": [Color(0.25, 0.75, 1.0), 95.0, 0.5],
	"screen_triple": [Color(0.3, 0.75, 1.0), 110.0, 0.35],
	"screen_dna": [Color(0.8, 0.4, 1.0), 90.0, 0.35],
	"screen_graph": [Color(0.3, 1.0, 0.7), 60.0, 0.3],
	"tv": [Color(0.3, 0.75, 1.0), 90.0, 0.35],
	"poster": [Color(1.0, 0.3, 0.8), 55.0, 0.35],
	"vending": [Color(0.4, 0.8, 1.0), 70.0, 0.35],
	"arcade": [Color(1.0, 0.3, 0.8), 60.0, 0.4],
	"counter": [Color(0.3, 0.8, 1.0), 130.0, 0.3],
	"crystals": [Color(0.7, 0.4, 1.0), 50.0, 0.5],
	"holo_rug": [Color(0.3, 0.8, 1.0), 80.0, 0.25],
	"rack": [Color(0.3, 1.0, 0.6), 45.0, 0.2],
}

var _glow_texture: GradientTexture2D
var _flicker: Array = []
var _time: float = 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = 40
	_glow_texture = _radial([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)], [0.0, 0.35, 1.0])
	_add_vignette()
	_add_wall_lights()
	_add_prop_lights.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	for entry in _flicker:
		var sprite: Sprite2D = entry[0]
		if is_instance_valid(sprite):
			sprite.modulate.a = entry[1] * (0.85 + 0.15 * sin(_time * entry[2] + entry[3]))


func _radial(colors: Array, offsets: Array) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(colors)
	gradient.offsets = PackedFloat32Array(offsets)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


## Escurece de leve as bordas da sala (o centro fica como está).
func _add_vignette() -> void:
	var dark := Sprite2D.new()
	dark.texture = _radial([Color(0, 0, 0.05, 0.0), Color(0, 0, 0.05, 0.0), Color(0.0, 0.0, 0.06, 0.55)], [0.0, 0.55, 1.0])
	dark.position = ROOM.get_center()
	dark.scale = ROOM.size / 128.0 * 1.05
	dark.z_as_relative = false
	dark.z_index = 39
	add_child(dark)


## Halos ao longo das paredes, onde ficam as luzes de neon da arte.
func _add_wall_lights() -> void:
	for x in range(56, 420, 74):
		_light(Vector2(x, 28), Color(0.3, 0.8, 1.0), 44.0, 0.28, true)
	for y in range(70, 300, 56):
		_light(Vector2(24, y), Color(0.3, 0.8, 1.0), 34.0, 0.22, false)
		_light(Vector2(424, y), Color(0.3, 0.8, 1.0), 34.0, 0.22, false)
	_light(Vector2(224, 300), Color(0.3, 0.8, 1.0), 70.0, 0.3, true)  # porta automática


## Um halo para cada móvel que tem luz e para cada computador.
func _add_prop_lights() -> void:
	var room: Node = get_parent()
	for sprite in room.find_children("*", "Sprite2D", true, false):
		if sprite.texture == null or sprite.get_parent() == self:
			continue
		var key: String = sprite.texture.resource_path.get_file().get_basename()
		if not PROP_LIGHTS.has(key):
			continue
		var spec: Array = PROP_LIGHTS[key]
		var size: Vector2 = sprite.texture.get_size() * sprite.global_scale
		var center: Vector2 = sprite.global_position + Vector2(0, sprite.offset.y * sprite.global_scale.y)
		if key == "holo_rug":
			center = sprite.global_position
		_light(center, spec[0], maxf(spec[1], size.x * 0.9), spec[2], key in ["hologram", "holo_globe", "arcade", "poster", "crystals"])
	for area in room.find_children("*", "Area2D", true, false):
		if "challenge_id" in area:
			_light(area.global_position + Vector2(0, -10), Color(0.3, 0.85, 1.0), 64.0, 0.3, true)


func _light(at: Vector2, color: Color, diameter: float, strength: float, flicker: bool) -> void:
	var glow := Sprite2D.new()
	glow.texture = _glow_texture
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = material
	glow.position = at
	glow.scale = Vector2.ONE * diameter / 128.0
	glow.modulate = Color(color, strength)
	glow.z_as_relative = false
	glow.z_index = 41
	add_child(glow)
	if flicker:
		_flicker.append([glow, strength, randf_range(1.5, 3.0), randf() * TAU])
