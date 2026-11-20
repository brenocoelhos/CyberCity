@tool
extends Control
## CyberFrame.gd
## Moldura "sci-fi" desenhada por código: fundo escuro translúcido, borda
## neon com brilho, cantos cortados na diagonal e, opcionalmente, uma ponta
## de seta no lado direito (como os cards de local e de nível do HUD).
##
## Use como fundo de qualquer card: crie um nó Control, anexe este script
## e deixe-o como PRIMEIRO filho do card (assim ele fica atrás do texto).
## Tudo aparece no editor (é @tool) e é ajustável no Inspetor.

## Cor de cima do fundo. Com "fill_bottom" (alfa > 0) o fundo vira um degradê.
@export var fill_color: Color = Color(0.05, 0.09, 0.3, 0.94):
	set(v):
		fill_color = v
		queue_redraw()
## Cor de baixo do fundo (alfa 0 = fundo de uma cor só).
@export var fill_bottom: Color = Color(0.25, 0.08, 0.46, 0.94):
	set(v):
		fill_bottom = v
		queue_redraw()
@export var border_color: Color = Color(0.42, 0.85, 1.0, 1.0):
	set(v):
		border_color = v
		queue_redraw()
@export var border_width: float = 2.0:
	set(v):
		border_width = v
		queue_redraw()

## Cantos arredondados (px). Acima de 0, vale no lugar dos cortes e da ponta.
@export var radius: float = 14.0:
	set(v):
		radius = v
		queue_redraw()
## Cor do brilho em volta (alfa 0 = mesma cor da borda).
@export var glow_color: Color = Color(0.6, 0.38, 1.0, 1.0):
	set(v):
		glow_color = v
		queue_redraw()

@export_group("Cantos cortados (px)")
@export var cut_top_left: float = 10.0:
	set(v):
		cut_top_left = v
		queue_redraw()
@export var cut_top_right: float = 0.0:
	set(v):
		cut_top_right = v
		queue_redraw()
@export var cut_bottom_right: float = 10.0:
	set(v):
		cut_bottom_right = v
		queue_redraw()
@export var cut_bottom_left: float = 0.0:
	set(v):
		cut_bottom_left = v
		queue_redraw()
## Ponta de seta no lado direito (0 = sem ponta). Substitui os cortes da direita.
@export var tip: float = 0.0:
	set(v):
		tip = v
		queue_redraw()
@export_group("")

@export_group("Efeitos")
## Brilho neon em volta da borda.
@export var glow: bool = true:
	set(v):
		glow = v
		queue_redraw()
## Segunda borda, fina e apagada, por dentro.
@export var inner_line: bool = true:
	set(v):
		inner_line = v
		queue_redraw()
## Traços mais claros e grossos nas bordas de cima e de baixo (detalhe sci-fi).
@export var accents: bool = false:
	set(v):
		accents = v
		queue_redraw()
## Pontinhos no canto de baixo à direita (0 = nenhum).
@export var dots: int = 0:
	set(v):
		dots = v
		queue_redraw()
## Destacado (aba selecionada / alvo da missão): mais claro e mais brilho.
@export var highlighted: bool = false:
	set(v):
		highlighted = v
		queue_redraw()
@export_group("")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _shape(rect: Rect2, shrink: float = 0.0) -> PackedVector2Array:
	if radius > 0.0:
		return _rounded(rect, maxf(2.0, radius - shrink * 0.6))
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := rect.end.x
	var y1 := rect.end.y
	var k := maxf(0.0, 1.0 - shrink * 0.04)
	var tl := cut_top_left * k
	var bl := cut_bottom_left * k
	var pts := PackedVector2Array()
	pts.append(Vector2(x0 + tl, y0))
	if tip > 0.0:
		var t := tip * k
		pts.append(Vector2(x1 - t, y0))
		pts.append(Vector2(x1, (y0 + y1) * 0.5))
		pts.append(Vector2(x1 - t, y1))
	else:
		var rt := cut_top_right * k
		var rb := cut_bottom_right * k
		pts.append(Vector2(x1 - rt, y0))
		pts.append(Vector2(x1, y0 + rt))
		pts.append(Vector2(x1, y1 - rb))
		pts.append(Vector2(x1 - rb, y1))
	pts.append(Vector2(x0 + bl, y1))
	pts.append(Vector2(x0, y1 - bl))
	pts.append(Vector2(x0, y0 + tl))
	# Remove pontos repetidos (corte = 0), que atrapalham o preenchimento.
	var clean := PackedVector2Array()
	for p in pts:
		if clean.is_empty() or clean[clean.size() - 1].distance_to(p) > 0.01:
			clean.append(p)
	if clean.size() > 1 and clean[0].distance_to(clean[clean.size() - 1]) < 0.01:
		clean.remove_at(clean.size() - 1)
	return clean


func _rounded(rect: Rect2, r: float) -> PackedVector2Array:
	r = minf(r, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var centers := [
		Vector2(rect.end.x - r, rect.position.y + r), Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r), Vector2(rect.position.x + r, rect.position.y + r)]
	for corner in 4:
		var start := -PI * 0.5 + corner * PI * 0.5
		for i in 7:
			var a := start + i * (PI * 0.5) / 6.0
			pts.append(centers[corner] + Vector2(cos(a), sin(a)) * r)
	return pts


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var half := border_width * 0.5
	var outer := _shape(Rect2(Vector2(half, half), size - Vector2(border_width, border_width)))
	if outer.size() < 3:
		return
	var line := _closed(outer)
	var edge := border_color
	var fill := fill_color
	if highlighted:
		edge = edge.lightened(0.25)
		fill = fill.lerp(Color(edge.r, edge.g, edge.b, fill.a), 0.18)

	if glow:
		# Brilho em duas camadas: a cor do brilho por fora, a da borda por dentro.
		var outer_glow := glow_color if glow_color.a > 0.0 else edge
		var g := outer_glow
		g.a = 0.2 if not highlighted else 0.35
		draw_polyline(line, g, border_width + 10.0, true)
		g = edge
		g.a = 0.3 if not highlighted else 0.5
		draw_polyline(line, g, border_width + 4.0, true)

	if fill_bottom.a > 0.0:
		# Degradê de cima (fill_color) para baixo (fill_bottom).
		var bottom := fill_bottom
		if highlighted:
			bottom = bottom.lerp(Color(edge.r, edge.g, edge.b, bottom.a), 0.18)
		var colors := PackedColorArray()
		for p in outer:
			colors.append(fill.lerp(bottom, clampf(p.y / maxf(size.y, 1.0), 0.0, 1.0)))
		draw_polygon(outer, colors)
	else:
		draw_colored_polygon(outer, fill)

	if inner_line:
		var inset := 4.0 + border_width
		var inner_rect := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
		if inner_rect.size.x > 8.0 and inner_rect.size.y > 8.0:
			var inner := _shape(inner_rect, inset)
			if inner.size() >= 3:
				var c := edge
				c.a *= 0.28
				draw_polyline(_closed(inner), c, 1.0, true)

	draw_polyline(line, edge, border_width, true)

	if accents:
		var a := edge.lightened(0.35)
		var x_start := cut_top_left + 6.0
		var length := minf(70.0, size.x * 0.25)
		draw_line(Vector2(x_start, half), Vector2(x_start + length, half), a, border_width + 2.0)
		var right := size.x - (tip if tip > 0.0 else cut_bottom_right) - 8.0
		draw_line(Vector2(right - length * 0.6, size.y - half), Vector2(right, size.y - half), a, border_width + 2.0)

	if dots > 0:
		var c2 := edge
		c2.a *= 0.6
		var base := Vector2(size.x - (tip if tip > 0.0 else 14.0) - 10.0 - dots * 7.0, size.y - 11.0)
		for i in dots:
			draw_rect(Rect2(base + Vector2(i * 7.0, 0), Vector2(3, 3)), c2)
