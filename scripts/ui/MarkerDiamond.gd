extends Control
## MarkerDiamond.gd
## Losango atrás do "!" dos NPCs (fica mais fácil de achar quem tem missão).
## Filho do Label "Marker" do NPC.tscn: aparece e some junto com ele.

func _ready() -> void:
	show_behind_parent = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(pts, Color(0.06, 0.08, 0.18, 0.9))
	pts.append(pts[0])
	draw_polyline(pts, Color(1, 0.85, 0.25, 0.35), 4.0)
	draw_polyline(pts, Color(1, 0.85, 0.25), 1.5)
