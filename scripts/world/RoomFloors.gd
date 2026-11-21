extends Node2D
## RoomFloors.gd
## Piso diferente em cada cômodo (madeira no quarto, azulejo no banheiro,
## xadrez na cozinha) e o nome do cômodo pintado no chão, bem discreto.
## InteriorBase.gd cria este nó como filho do piso, a partir de ROOM_ZONES.

var zones: Array = []


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for zone in zones:
		var rect: Rect2 = zone[0]
		match String(zone[1]):
			"wood":
				_wood(rect)
			"tile":
				_checker(rect, 12.0, Color(0.30, 0.43, 0.5), Color(0.25, 0.37, 0.44), Color(0.55, 0.7, 0.78, 0.35))
			"kitchen":
				_checker(rect, 16.0, Color(0.32, 0.32, 0.38), Color(0.16, 0.16, 0.22), Color(0, 0, 0, 0))
		var label: String = String(zone[2])
		if label != "":
			var at: Vector2 = zone[3] if zone.size() > 3 else rect.position + Vector2(6, 14)
			draw_string(font, at + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0.05, 0.5))
			draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.75, 0.92, 1.0, 0.6))


func _wood(rect: Rect2) -> void:
	draw_rect(rect, Color(0.26, 0.18, 0.2))
	var row := 0
	var y := rect.position.y
	while y < rect.end.y:
		var shade := Color(0.29, 0.2, 0.22) if row % 2 == 0 else Color(0.24, 0.165, 0.185)
		draw_rect(Rect2(rect.position.x, y, rect.size.x, minf(8.0, rect.end.y - y)), shade)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.13, 0.08, 0.1), 1.0)
		var x := rect.position.x + (0.0 if row % 2 == 0 else 24.0)
		while x < rect.end.x:
			draw_line(Vector2(x, y), Vector2(x, minf(y + 8.0, rect.end.y)), Color(0.13, 0.08, 0.1), 1.0)
			x += 48.0
		y += 8.0
		row += 1


func _checker(rect: Rect2, size: float, a: Color, b: Color, grout: Color) -> void:
	var j := 0
	var y := rect.position.y
	while y < rect.end.y:
		var i := 0
		var x := rect.position.x
		while x < rect.end.x:
			var cell := Rect2(x, y, minf(size, rect.end.x - x), minf(size, rect.end.y - y))
			draw_rect(cell, a if (i + j) % 2 == 0 else b)
			if grout.a > 0.0:
				draw_rect(cell, grout, false, 1.0)
			x += size
			i += 1
		y += size
		j += 1
