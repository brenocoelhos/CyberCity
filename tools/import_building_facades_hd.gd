extends SceneTree
## Regera as fachadas das casas e prédios da cidade (building_0 a building_19)
## em alta resolução, a partir das artes-fonte grandes:
##   building_0..7   <- assets/source/cyber_buildings_clean.png   (grade 4×2)
##   building_8..19  <- assets/source/cyber_buildings_variety.png (grade 6×2)
##
##   Godot --headless --path . --script res://tools/import_building_facades_hd.gd
##
## Antes, cada prédio (~250–380 px na arte) era reduzido para 96×224 sem
## suavizar, o que deixava as casas serrilhadas/borradas. Agora a textura tem
## DENSITY pixels por unidade do mapa (288×672), reduzida com Lanczos; o
## Building.gd desenha com scale 1/DENSITY e filtro Linear. O tamanho no mapa
## continua 96×224 (as colisões e posições não mudam).

const DEST := "res://assets/environment/cyber/"
const DENSITY := 3
const CANVAS := Vector2i(96, 224)


func _initialize() -> void:
	_sheet("res://assets/source/cyber_buildings_clean.png", Vector2i(4, 2), 0)
	_sheet("res://assets/source/cyber_buildings_variety.png", Vector2i(6, 2), 8)
	print("Fachadas em alta resolução geradas em ", DEST)
	quit(0)


func _sheet(path: String, grid: Vector2i, first_index: int) -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(path))
	source.convert(Image.FORMAT_RGBA8)
	var cell := Vector2i(source.get_width() / grid.x, source.get_height() / grid.y)
	for i in grid.x * grid.y:
		var region := Rect2i(Vector2i(i % grid.x, i / grid.x) * cell, cell)
		var cut := source.get_region(region)
		# Fundo semitransparente da arte vira transparente (como no import antigo).
		for y in cut.get_height():
			for x in cut.get_width():
				if cut.get_pixel(x, y).a < 0.9:
					cut.set_pixel(x, y, Color.TRANSPARENT)
		var used := cut.get_used_rect()
		cut = cut.get_region(used)
		_save(cut, "building_%d" % (first_index + i))


func _save(cut: Image, asset_name: String) -> void:
	var canvas_size := CANVAS * DENSITY
	var factor := minf(float(canvas_size.x - 2 * DENSITY) / cut.get_width(), float(canvas_size.y - 2 * DENSITY) / cut.get_height())
	var size := Vector2i(roundi(cut.get_width() * factor), roundi(cut.get_height() * factor))
	cut.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(cut, Rect2i(Vector2i.ZERO, size), Vector2i((canvas_size.x - size.x) / 2, canvas_size.y - size.y))
	canvas.save_png(ProjectSettings.globalize_path(DEST + asset_name + ".png"))
