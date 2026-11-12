@tool
extends Control
## CyberIcon.gd
## Ícones simples de linha neon desenhados por código (sem imagens), no
## mesmo estilo das molduras do HUD. Escolha o desenho em "Kind" no Inspetor.

enum Kind { MONITOR, SERVER, PHONE, SIGNAL, MISSION, BUILDING, CHAT, CITY, MAGNIFIER, PERSON, GEAR, NOTE, WRENCH, POWER, WIFI, BATTERY, TERMINAL, FOLDER, GLOBE, MAIL, LOCK, BELL, VOLUME, EMBLEM, GRID }

@export var kind: Kind = Kind.MONITOR:
	set(v):
		kind = v
		queue_redraw()
@export var color: Color = Color(0.4, 0.92, 1.0, 1.0):
	set(v):
		color = v
		queue_redraw()
@export var line_width: float = 2.0:
	set(v):
		line_width = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


## Converte coordenadas de 0..1 para pixels, num quadrado centralizado.
func _p(x: float, y: float) -> Vector2:
	var s := minf(size.x, size.y)
	var off := (size - Vector2(s, s)) * 0.5
	return off + Vector2(x, y) * s


func _box(x0: float, y0: float, x1: float, y1: float, c: Color = Color(0, 0, 0, 0)) -> void:
	if c.a == 0.0:
		c = color
	var pts := PackedVector2Array([_p(x0, y0), _p(x1, y0), _p(x1, y1), _p(x0, y1), _p(x0, y0)])
	draw_polyline(pts, c, line_width, true)


func _fill(x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
	draw_rect(Rect2(_p(x0, y0), _p(x1, y1) - _p(x0, y0)), c)


func _draw() -> void:
	var faint := color
	faint.a *= 0.25
	match kind:
		Kind.MONITOR:
			_fill(0.1, 0.14, 0.9, 0.66, faint)
			_box(0.1, 0.14, 0.9, 0.66)
			draw_line(_p(0.5, 0.66), _p(0.5, 0.8), color, line_width)
			draw_line(_p(0.3, 0.84), _p(0.7, 0.84), color, line_width)
		Kind.SERVER:
			for i in 3:
				var y := 0.1 + i * 0.28
				_fill(0.15, y, 0.85, y + 0.22, faint)
				_box(0.15, y, 0.85, y + 0.22)
				draw_line(_p(0.25, y + 0.11), _p(0.5, y + 0.11), color, line_width * 0.75)
				_fill(0.68, y + 0.08, 0.75, y + 0.15, color)
		Kind.PHONE:
			_fill(0.3, 0.05, 0.7, 0.95, faint)
			_box(0.3, 0.05, 0.7, 0.95)
			_box(0.36, 0.15, 0.64, 0.78, Color(color, color.a * 0.6))
			draw_line(_p(0.45, 0.87), _p(0.55, 0.87), color, line_width)
		Kind.SIGNAL:
			for i in 4:
				var x := 0.12 + i * 0.22
				var top := 0.8 - (i + 1) * 0.17
				_fill(x, top, x + 0.14, 0.82, color)
		Kind.MISSION:
			# Mira: círculo + cruz
			draw_arc(_p(0.5, 0.5), minf(size.x, size.y) * 0.32, 0.0, TAU, 32, color, line_width, true)
			draw_circle(_p(0.5, 0.5), minf(size.x, size.y) * 0.07, color)
			draw_line(_p(0.5, 0.04), _p(0.5, 0.28), color, line_width)
			draw_line(_p(0.5, 0.72), _p(0.5, 0.96), color, line_width)
			draw_line(_p(0.04, 0.5), _p(0.28, 0.5), color, line_width)
			draw_line(_p(0.72, 0.5), _p(0.96, 0.5), color, line_width)
		Kind.BUILDING:
			_fill(0.22, 0.1, 0.78, 0.92, faint)
			_box(0.22, 0.1, 0.78, 0.92)
			for row in 3:
				for col in 2:
					var wx := 0.33 + col * 0.22
					var wy := 0.22 + row * 0.19
					_fill(wx, wy, wx + 0.12, wy + 0.1, color)
			draw_line(_p(0.1, 0.92), _p(0.9, 0.92), color, line_width)
		Kind.CHAT:
			var pts := PackedVector2Array([_p(0.08, 0.15), _p(0.92, 0.15), _p(0.92, 0.68), _p(0.42, 0.68), _p(0.22, 0.88), _p(0.25, 0.68), _p(0.08, 0.68), _p(0.08, 0.15)])
			draw_colored_polygon(pts.slice(0, pts.size() - 1), faint)
			draw_polyline(pts, color, line_width, true)
			for i in 3:
				draw_circle(_p(0.3 + i * 0.2, 0.42), minf(size.x, size.y) * 0.05, color)
		Kind.CITY:
			var heights := [0.45, 0.25, 0.55, 0.35, 0.5]
			for i in heights.size():
				var x := 0.08 + i * 0.17
				_fill(x, heights[i], x + 0.14, 0.9, faint)
				_box(x, heights[i], x + 0.14, 0.9)
			draw_line(_p(0.04, 0.9), _p(0.96, 0.9), color, line_width)
		Kind.MAGNIFIER:
			var r := minf(size.x, size.y)
			draw_arc(_p(0.42, 0.42), r * 0.26, 0.0, TAU, 32, color, line_width, true)
			draw_line(_p(0.61, 0.61), _p(0.86, 0.86), color, line_width * 1.6, true)
		Kind.PERSON:
			var r2 := minf(size.x, size.y)
			draw_circle(_p(0.5, 0.33), r2 * 0.17, color)
			draw_arc(_p(0.5, 0.95), r2 * 0.38, PI, TAU, 32, color, line_width * 2.6, true)
		Kind.GEAR:
			var r3 := minf(size.x, size.y)
			for i in 8:
				var a := i * TAU / 8.0
				draw_line(_p(0.5, 0.5) + Vector2(cos(a), sin(a)) * r3 * 0.24, _p(0.5, 0.5) + Vector2(cos(a), sin(a)) * r3 * 0.42, color, line_width * 2.2)
			draw_circle(_p(0.5, 0.5), r3 * 0.27, color)
			draw_circle(_p(0.5, 0.5), r3 * 0.11, Color(0, 0, 0, 0.45))
		Kind.NOTE:
			for i in 4:
				var y := 0.28 + i * 0.16
				draw_line(_p(0.2, y), _p(0.8 if i < 3 else 0.55, y), color, line_width, true)
		Kind.WRENCH:
			var r4 := minf(size.x, size.y)
			draw_line(_p(0.3, 0.7), _p(0.62, 0.38), color, line_width * 2.2, true)
			draw_arc(_p(0.68, 0.32), r4 * 0.16, -2.4, 2.0, 16, color, line_width * 1.6, true)
		Kind.POWER:
			var r5 := minf(size.x, size.y)
			draw_arc(_p(0.5, 0.54), r5 * 0.3, -PI * 0.32 - PI * 0.5 + PI, PI * 2.32 - PI * 0.5, 32, color, line_width * 1.4, true)
			draw_line(_p(0.5, 0.14), _p(0.5, 0.5), color, line_width * 1.4, true)
		Kind.WIFI:
			var r6 := minf(size.x, size.y)
			for i in 3:
				draw_arc(_p(0.5, 0.88), r6 * (0.22 + i * 0.24), -PI * 0.75, -PI * 0.25, 16, color, line_width, true)
			draw_circle(_p(0.5, 0.84), r6 * 0.07, color)
		Kind.BATTERY:
			var w := size.x
			var h := size.y
			var body := Rect2(Vector2(0.5, h * 0.18), Vector2(w * 0.86, h * 0.64))
			draw_rect(body, Color(color, color.a * 0.45), false, 1.0)
			draw_rect(Rect2(body.position + Vector2(2, 2), Vector2((body.size.x - 4) * 0.8, body.size.y - 4)), color)
			draw_rect(Rect2(Vector2(w * 0.9, h * 0.38), Vector2(w * 0.08, h * 0.24)), Color(color, color.a * 0.45))
		Kind.TERMINAL:
			_fill(0.06, 0.14, 0.94, 0.86, Color(0.05, 0.06, 0.08, color.a))
			_box(0.06, 0.14, 0.94, 0.86)
			_fill(0.06, 0.14, 0.94, 0.26, faint)
			draw_polyline(PackedVector2Array([_p(0.2, 0.4), _p(0.36, 0.53), _p(0.2, 0.66)]), color, line_width, true)
			draw_line(_p(0.44, 0.68), _p(0.68, 0.68), color, line_width)
		Kind.FOLDER:
			var tab := PackedVector2Array([_p(0.06, 0.2), _p(0.38, 0.2), _p(0.46, 0.3), _p(0.94, 0.3), _p(0.94, 0.84), _p(0.06, 0.84)])
			draw_colored_polygon(tab, Color(color, color.a * 0.85))
			_fill(0.06, 0.38, 0.94, 0.84, color.lightened(0.2))
		Kind.GLOBE:
			var rg := minf(size.x, size.y)
			draw_circle(_p(0.5, 0.5), rg * 0.4, faint)
			draw_arc(_p(0.5, 0.5), rg * 0.4, 0.0, TAU, 32, color, line_width, true)
			draw_line(_p(0.1, 0.5), _p(0.9, 0.5), color, line_width * 0.7)
			draw_line(_p(0.5, 0.1), _p(0.5, 0.9), color, line_width * 0.7)
			draw_arc(_p(0.5, 0.5), rg * 0.2, -PI * 0.5, PI * 1.5, 24, color, line_width * 0.7, true)
		Kind.MAIL:
			_fill(0.08, 0.22, 0.92, 0.78, faint)
			_box(0.08, 0.22, 0.92, 0.78)
			draw_polyline(PackedVector2Array([_p(0.08, 0.22), _p(0.5, 0.54), _p(0.92, 0.22)]), color, line_width, true)
		Kind.LOCK:
			var rl := minf(size.x, size.y)
			draw_arc(_p(0.5, 0.42), rl * 0.2, PI, TAU, 16, color, line_width, true)
			draw_line(_p(0.3, 0.42), _p(0.3, 0.5), color, line_width)
			draw_line(_p(0.7, 0.42), _p(0.7, 0.5), color, line_width)
			_fill(0.22, 0.48, 0.78, 0.88, color)
		Kind.BELL:
			var bell := PackedVector2Array([_p(0.5, 0.12), _p(0.72, 0.3), _p(0.74, 0.62), _p(0.86, 0.74), _p(0.14, 0.74), _p(0.26, 0.62), _p(0.28, 0.3)])
			draw_colored_polygon(bell, color)
			draw_circle(_p(0.5, 0.84), minf(size.x, size.y) * 0.08, color)
		Kind.VOLUME:
			draw_colored_polygon(PackedVector2Array([_p(0.1, 0.38), _p(0.28, 0.38), _p(0.5, 0.18), _p(0.5, 0.82), _p(0.28, 0.62), _p(0.1, 0.62)]), color)
			var rv := minf(size.x, size.y)
			draw_arc(_p(0.52, 0.5), rv * 0.18, -0.9, 0.9, 12, color, line_width, true)
			draw_arc(_p(0.52, 0.5), rv * 0.34, -0.9, 0.9, 12, color, line_width, true)
		Kind.EMBLEM:
			# Emblema do CYBER-OS: hexágono com um cadeado dentro.
			var re := minf(size.x, size.y)
			var hexagon := PackedVector2Array()
			for i in 7:
				var a := PI / 6.0 + i * TAU / 6.0
				hexagon.append(_p(0.5, 0.5) + Vector2(cos(a), sin(a)) * re * 0.46)
			draw_colored_polygon(hexagon.slice(0, 6), faint)
			draw_polyline(hexagon, color, line_width, true)
			draw_arc(_p(0.5, 0.44), re * 0.13, PI, TAU, 16, color, line_width, true)
			draw_line(_p(0.37, 0.44), _p(0.37, 0.5), color, line_width)
			draw_line(_p(0.63, 0.44), _p(0.63, 0.5), color, line_width)
			_fill(0.32, 0.5, 0.68, 0.72, color)
		Kind.GRID:
			for row in 3:
				for col in 3:
					_fill(0.12 + col * 0.28, 0.12 + row * 0.28, 0.32 + col * 0.28, 0.32 + row * 0.28, color)
