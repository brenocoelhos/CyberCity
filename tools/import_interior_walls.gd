extends SceneTree
## Gera as paredes e o piso dos interiores a partir das artes originais em
## assets/source/interior/ (que ficam intactas). Reproduzível: rode de novo
## sempre que trocar uma arte original.
##
##   Godot --headless --path . --script res://tools/import_interior_walls.gd
##
## Saída (assets/environment/interior/), no tamanho certo do mundo (1 pixel da
## textura = 1 unidade do mapa; a sala tem 448×320, unidade de 32×32):
##   wall_top.png     448×72  painel | janela | janela | painel
##   wall_bottom.png  448×72  painel | painel | porta automática | painel | painel
##   wall_left.png     32×42  painel lateral esquerdo (repete na vertical)
##   wall_right.png    32×29  painel lateral direito (repete na vertical)
##   floor.png         32×32  piso de metal escuro (repete)
## A redução usa Lanczos (as artes originais têm ~400 px de altura); no jogo a
## textura é desenhada sem suavização (Nearest), como o resto do pixel art.

const SRC := "res://assets/source/interior/"
const OUT := "res://assets/environment/interior/"
const ROOM_WIDTH := 448
const WALL_HEIGHT := 72


func _initialize() -> void:
	var top_window := _load("WallTop_Janela")
	var door := _load("WallBottom_PortaAutomatica")
	var left := _load("WallLeft_PainelLateral")
	var right := _load("WallRight_PainelLateral")
	if top_window == null or door == null or left == null or right == null:
		push_error("Faltam artes em " + SRC)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	_save(_strip([left, top_window, top_window, right], WALL_HEIGHT, ROOM_WIDTH), "wall_top")
	_save(_strip([left, right, door, left, right], WALL_HEIGHT, ROOM_WIDTH), "wall_bottom")
	_save(_fit_width(left, 32), "wall_left")
	_save(_fit_width(right, 32), "wall_right")
	_save(_floor_tile(), "floor")
	print("Paredes e piso dos interiores gerados em ", OUT)
	quit(0)


func _load(file_name: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SRC + file_name + ".png"))
	if image:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _save(image: Image, file_name: String) -> void:
	image.save_png(ProjectSettings.globalize_path(OUT + file_name + ".png"))


## Põe as artes lado a lado (todas com a mesma altura) e ajusta a faixa à
## largura da sala.
func _strip(parts: Array, height: int, width: int) -> Image:
	var scaled: Array[Image] = []
	var total := 0
	for part in parts:
		var copy: Image = (part as Image).duplicate()
		var w := int(round(copy.get_width() * float(height) / copy.get_height()))
		copy.resize(w, height, Image.INTERPOLATE_LANCZOS)
		scaled.append(copy)
		total += w
	var strip := Image.create(total, height, false, Image.FORMAT_RGBA8)
	var x := 0
	for part in scaled:
		strip.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i(x, 0))
		x += part.get_width()
	strip.resize(width, height, Image.INTERPOLATE_LANCZOS)
	return _solid(strip)


func _fit_width(source: Image, width: int) -> Image:
	var copy := source.duplicate()
	var h := int(round(copy.get_height() * float(width) / copy.get_width()))
	copy.resize(width, h, Image.INTERPOLATE_LANCZOS)
	return _solid(copy)


## As artes têm emendas semitransparentes entre os painéis; numa parede isso
## deixaria ver o vazio atrás. Aqui toda área com cor fica opaca, sobre o
## cinza-azulado escuro do metal.
func _solid(image: Image) -> Image:
	var back := Color("#1b2230")
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0.02:
				var mixed := back.lerp(Color(c.r, c.g, c.b), c.a)
				image.set_pixel(x, y, Color(mixed.r, mixed.g, mixed.b, 1.0))
	return image


## Piso de placas de metal escuro com rebites e um fio de luz ciano.
func _floor_tile() -> Image:
	var tile := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	tile.fill(Color("#161c27"))
	for i in 32:
		tile.set_pixel(i, 0, Color("#0d121a"))
		tile.set_pixel(0, i, Color("#0d121a"))
		tile.set_pixel(i, 31, Color("#222b3a"))
		tile.set_pixel(31, i, Color("#222b3a"))
	for spot in [Vector2i(3, 3), Vector2i(28, 3), Vector2i(3, 28), Vector2i(28, 28)]:
		tile.set_pixelv(spot, Color("#3a4658"))
	for i in range(10, 22):
		tile.set_pixel(i, 16, Color("#1d3343"))
	return tile
