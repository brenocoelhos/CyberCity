extends Sprite2D
## HoloPulse.gd
## Faz um holograma "flutuar": sobe e desce devagar e o brilho pulsa.
## Use num Sprite2D (ex.: o globo da mesa de comando dos interiores).

@export var float_height: float = 8.0
@export var period: float = 2.4


func _ready() -> void:
	var base_y := position.y
	var move := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	move.tween_property(self, "position:y", base_y - float_height, period * 0.5)
	move.tween_property(self, "position:y", base_y, period * 0.5)
	var light := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	light.tween_property(self, "modulate:a", 0.7, period * 0.35)
	light.tween_property(self, "modulate:a", 1.0, period * 0.35)
