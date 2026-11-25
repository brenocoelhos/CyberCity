extends Node2D
## StatusCard.gd
## Cartãozinho flutuante sobre a mesa de um colega (decoração), como os
## painéis de status de jogos cyberpunk: foto, nome, status e uma barra de
## progresso que anda devagar. Fica acima dos personagens (z 45).

@export var person_name := "Dev. Jr."
@export var status := "Trabalhando"
@export var portrait: Texture2D

const SIZE := Vector2(86, 30)
var _time := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = 45


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.06, 0.14, 0.88)
	box.set_corner_radius_all(4)
	box.set_border_width_all(1)
	box.border_color = Color(0.3, 0.85, 1.0, 0.7)
	draw_style_box(box, Rect2(Vector2.ZERO, SIZE))
	# Foto.
	draw_rect(Rect2(3, 3, 24, 24), Color(0.08, 0.14, 0.26))
	if portrait:
		var src := Rect2(portrait.get_width() * 0.28, portrait.get_height() * 0.08, portrait.get_width() * 0.44, portrait.get_height() * 0.44)
		draw_texture_rect_region(portrait, Rect2(3, 3, 24, 24), src)
	draw_rect(Rect2(3, 3, 24, 24), Color(0.3, 0.85, 1.0, 0.6), false, 1.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(31, 11), person_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.92, 0.96, 1.0))
	draw_circle(Vector2(34, 17), 2.0, Color(0.3, 1.0, 0.5))
	draw_string(font, Vector2(39, 20), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.45, 0.9, 1.0))
	# Barra de progresso (enche e recomeça).
	var progress := fposmod(_time * 0.08, 1.0)
	draw_rect(Rect2(31, 23, 51, 3), Color(0.3, 0.5, 0.8, 0.3))
	draw_rect(Rect2(31, 23, 51 * progress, 3), Color(0.3, 0.88, 1.0))
