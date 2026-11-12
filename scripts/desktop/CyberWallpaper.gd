extends Control
## CyberWallpaper.gd
## Papel de parede do CYBER-OS, no espírito do visual das distribuições Linux de
## segurança: fundo azul profundo com grandes blocos geométricos translúcidos
## em perspectiva e, no centro, o emblema do sistema (hexágono com cadeado) ao
## lado do nome numa moldura arredondada. Tudo desenhado por código.

const CyberIcon := preload("res://scripts/ui/CyberIcon.gd")

var _emblem: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	_emblem = CyberIcon.new()
	_emblem.kind = CyberIcon.Kind.EMBLEM
	_emblem.color = Color(1, 1, 1, 0.95)
	_emblem.line_width = 5.0
	add_child(_emblem)
	_layout()


func _layout() -> void:
	if _emblem == null:
		return
	var center := size * 0.5
	_emblem.size = Vector2(150, 150)
	_emblem.position = center + Vector2(-250, -75)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Fundo: azul profundo no canto de cima, roxo-azulado embaixo à direita.
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([Color("#0b2a6b"), Color("#1d4fb8"), Color("#3b3fb0"), Color("#0a1f55")]))

	# Blocos geométricos (faces de cubos inclinados), do fundo para a frente.
	_block([Vector2(0.38, -0.1), Vector2(0.95, 0.08), Vector2(0.86, 0.62), Vector2(0.3, 0.45)], Color("#2a63d6"), 0.55)
	_block([Vector2(0.55, 0.55), Vector2(1.05, 0.38), Vector2(1.08, 1.05), Vector2(0.62, 1.1)], Color("#2f74e8"), 0.6)
	_block([Vector2(0.62, 0.55), Vector2(0.86, 0.62), Vector2(0.72, 1.1), Vector2(0.5, 1.1)], Color("#54a6ff"), 0.85)
	_block([Vector2(0.08, 0.32), Vector2(0.34, 0.24), Vector2(0.42, 0.58), Vector2(0.16, 0.7)], Color("#1f56c4"), 0.75)
	_block([Vector2(0.16, 0.7), Vector2(0.42, 0.58), Vector2(0.44, 0.78), Vector2(0.2, 0.92)], Color("#3a86f2"), 0.7)
	_block([Vector2(-0.05, 0.62), Vector2(0.12, 0.66), Vector2(0.18, 1.1), Vector2(-0.05, 1.1)], Color("#0d2f86"), 0.8)
	_block([Vector2(0.8, -0.1), Vector2(1.1, -0.1), Vector2(1.1, 0.3), Vector2(0.92, 0.22)], Color("#4c7ef0"), 0.45)

	# Moldura arredondada com o nome do sistema, à direita do emblema.
	var center := size * 0.5
	var font: Font = get_theme_default_font()
	var text := "CYBER-OS"
	var font_size := 60
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var frame := Rect2(center + Vector2(-80, -58), Vector2(text_size.x + 56, 116))
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = Color(1, 1, 1, 0.95)
	style.set_border_width_all(6)
	style.set_corner_radius_all(14)
	draw_style_box(style, frame)
	var baseline := frame.position + Vector2((frame.size.x - text_size.x) * 0.5, frame.size.y * 0.5 + font_size * 0.36)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


## Um bloco: quatro cantos em frações da tela (0..1), com um brilho na aresta
## de cima, como a face iluminada de um cubo.
func _block(corners: Array, color: Color, alpha: float) -> void:
	var points := PackedVector2Array()
	for corner in corners:
		points.append(Vector2(corner.x * size.x, corner.y * size.y))
	var top := Color(color.lightened(0.18), alpha)
	var bottom := Color(color.darkened(0.25), alpha)
	draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))
	draw_line(points[0], points[1], Color(1, 1, 1, alpha * 0.25), 2.0, true)
