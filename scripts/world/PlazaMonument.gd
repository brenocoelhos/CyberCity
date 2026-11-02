extends StaticBody2D
## Geometria nativa em pixels: pedestal e holograma central da praça.
func _ready() -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(104,32)
	collision.shape = shape
	collision.position = Vector2(0,-8)
	add_child(collision)
	queue_redraw()

func _draw() -> void:
	# Stepped stone plinth and recessed reflecting pool.
	draw_rect(Rect2(-60,-20,120,40),Color("101d30"))
	draw_rect(Rect2(-56,-24,112,36),Color("506480"))
	draw_rect(Rect2(-52,-24,104,28),Color("223953"))
	draw_rect(Rect2(-44,-20,88,20),Color("0b263d"))
	draw_line(Vector2(-48,6),Vector2(48,6),Color("5ce5ec"),2)
	for x in range(-36,40,12):
		draw_line(Vector2(x,-12),Vector2(x+6,-12),Color("247f9b"),1)
	draw_rect(Rect2(-16,-32,32,24),Color("162139"))
	draw_rect(Rect2(-20,-34,40,6),Color("64e9f5"))
	var diamond := PackedVector2Array([Vector2(0,-100),Vector2(24,-68),Vector2(0,-40),Vector2(-24,-68)])
	draw_colored_polygon(diamond,Color("143e68"))
	var outline := diamond.duplicate()
	outline.append(diamond[0])
	draw_polyline(outline,Color("61efff"),2)
	draw_line(Vector2(0,-100),Vector2(0,-40),Color("afeaff"),2)
	draw_line(Vector2(-24,-68),Vector2(24,-68),Color("447fda"),2)
	draw_line(Vector2(-8,-38),Vector2(-8,-32),Color("3c76a8"),1)
	draw_line(Vector2(8,-38),Vector2(8,-32),Color("3c76a8"),1)
