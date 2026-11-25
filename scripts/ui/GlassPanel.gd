@tool
extends Control
## GlassPanel.gd
## Painel "vidro escuro" do HUD: fundo escuro semitransparente, cantos
## arredondados e uma borda fina e discreta. Sem cortes, pontos ou brilho
## forte (o CyberFrame continua sendo usado nas telas grandes).
## Fica atrás do conteúdo: ponha como primeiro filho, com âncoras na tela toda.

@export var fill_color := Color(0.03, 0.05, 0.12, 0.7):
	set(value):
		fill_color = value
		queue_redraw()
@export var border_color := Color(0.55, 0.7, 1.0, 0.16):
	set(value):
		border_color = value
		queue_redraw()
@export var radius := 8:
	set(value):
		radius = value
		queue_redraw()
## Faixa colorida fina do lado esquerdo (0 = sem faixa).
@export var accent_width := 0.0:
	set(value):
		accent_width = value
		queue_redraw()
@export var accent_color := Color(0.3, 0.85, 1.0, 0.9):
	set(value):
		accent_color = value
		queue_redraw()
## Destaque (ex.: a aba do computador da missão): borda ciano mais viva.
@export var highlighted := false:
	set(value):
		highlighted = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill_color
	box.set_corner_radius_all(radius)
	box.corner_detail = 6
	box.anti_aliasing = true
	box.set_border_width_all(1)
	box.border_color = Color(0.35, 0.9, 1.0, 0.75) if highlighted else border_color
	if highlighted:
		box.shadow_color = Color(0.2, 0.8, 1.0, 0.25)
		box.shadow_size = 6
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	if accent_width > 0.0:
		var bar := StyleBoxFlat.new()
		bar.bg_color = accent_color
		bar.set_corner_radius_all(int(accent_width))
		draw_style_box(bar, Rect2(Vector2(5, 8), Vector2(accent_width, size.y - 16)))
