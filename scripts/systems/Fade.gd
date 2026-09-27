extends CanvasLayer
## Fade.gd — Autoload
## Uma tela preta que cobre tudo (layer bem alta) e faz fade in/out,
## usada pelo SceneTransition ao trocar entre a cidade e os interiores.
## Sem isso, a troca de cena era um corte seco.

@onready var rect: ColorRect = $Rect


func _ready() -> void:
	rect.modulate.a = 0.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func fade_out(duration: float = 0.22) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, duration)
	await tween.finished


func fade_in(duration: float = 0.22) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration)
	await tween.finished
