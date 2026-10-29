@tool
extends Control
## CyberIcon.gd
## Ícones simples de linha neon desenhados por código (sem imagens), no
## mesmo estilo das molduras do HUD. Escolha o desenho em "Kind" no Inspetor.

enum Kind { MONITOR, SERVER, PHONE, SIGNAL, MISSION, BUILDING, CHAT, CITY }

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
