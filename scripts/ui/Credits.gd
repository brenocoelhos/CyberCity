extends CanvasLayer
## Credits.gd
## Créditos do fim do jogo: o texto sobe pela tela (como no cinema), com o
## resumo da partida, os créditos da equipe e o placar, e no fim aparece o
## botão para voltar ao menu principal. ESC ou o botão "Pular" vão direto ao fim.
##
## PROVISÓRIO: os nomes são "lorem ipsum" até a equipe passar os reais.

signal finished

const SCROLL_SPEED := 70.0
const FAST_FACTOR := 5.0
const WIDTH := 760.0

## Créditos provisórios: cargo -> linhas.
const TEAM := [
	["ROTEIRO", ["Lorem Ipsum", "Dolor Sit Amet"]],
	["ARTE", ["Consectetur Adipiscing", "Elit Sed Do"]],
	["MÚSICA", ["Eiusmod Tempor"]],
	["PROGRAMAÇÃO", ["Incididunt Ut Labore", "Et Dolore Magna"]],
	["AGRADECIMENTOS", ["Aliqua Ut Enim Ad Minim", "Veniam Quis Nostrud"]],
]

var _scroller: Control
var _end_y: float = 0.0
var _finished: bool = false
var _rolling: bool = false
var _skip_button: Button
var _back_button: Button


## Monta e começa os créditos. "ending_lines" é o texto do final, "background"
## a cor de fundo, "run" o resultado da partida ({"entry", "position"}, como
## devolve Leaderboard.finish_run()).
func play(background: Color, ending_lines: PackedStringArray, run: Dictionary) -> void:
	layer = 130
	HUD.set_overlay_active(true)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = background
	add_child(bg)

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_scroller = VBoxContainer.new()
	_scroller.custom_minimum_size = Vector2(WIDTH, 0)
	_scroller.add_theme_constant_override("separation", 18)
	add_child(_scroller)

	_big("CYBER CITY", 56)
	_big("FIM", 30, Color("#ffd75f"))
	_gap(30)
	for line in ending_lines:
		_text(String(line), 22)
	_gap(40)
	_add_summary(run)
	_gap(50)
	for group in TEAM:
		_big(String(group[0]), 24, Color("#7fd6ff"))
		for person in group[1]:
			_text(String(person), 20)
		_gap(34)
	_gap(10)
	_add_board(run)
	_gap(50)
	_big("Obrigado por jogar!", 34, Color("#3dff6e"))
	_gap(60)

	# Espera o layout para saber a altura e começa abaixo da tela.
	await get_tree().process_frame
	await get_tree().process_frame
	var height: float = _scroller.size.y
	_scroller.position = Vector2((viewport_size.x - WIDTH) / 2.0, viewport_size.y)
	# Termina quando o fim do texto chega a 55% da altura da tela.
	_end_y = viewport_size.y * 0.55 - height

	_skip_button = Button.new()
	_skip_button.text = "Pular (ESC)"
	_skip_button.position = Vector2(viewport_size.x - 160, 16)
	_skip_button.focus_mode = Control.FOCUS_NONE
	_skip_button.pressed.connect(skip)
	add_child(_skip_button)

	_back_button = Button.new()
	_back_button.text = "Voltar ao menu principal"
	_back_button.custom_minimum_size = Vector2(300, 48)
	_back_button.position = Vector2((viewport_size.x - 300) / 2.0, viewport_size.y - 90)
	_back_button.visible = false
	_back_button.pressed.connect(_leave)
	add_child(_back_button)
	_rolling = true


func _process(delta: float) -> void:
	if not _rolling or _finished:
		return
	var speed: float = SCROLL_SPEED
	if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_DOWN):
		speed *= FAST_FACTOR
	_scroller.position.y -= speed * delta
	if _scroller.position.y <= _end_y:
		_reach_end()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and not _finished:
		skip()
		get_viewport().set_input_as_handled()


func skip() -> void:
	if not _rolling or _finished:
		return
	_scroller.position.y = _end_y
	_reach_end()


func is_finished() -> bool:
	return _finished


func _reach_end() -> void:
	_finished = true
	_scroller.position.y = _end_y
	_skip_button.visible = false
	_back_button.visible = true
	_back_button.grab_focus.call_deferred()


func _leave() -> void:
	SoundManager.play("interact")
	HUD.set_overlay_active(false)
	finished.emit()
	queue_free()


# --- Conteúdo ---------------------------------------------------------------------------

func _add_summary(run: Dictionary) -> void:
	var entry: Dictionary = run.get("entry", {})
	var name_text: String = String(entry.get("name", Leaderboard.player_name))
	_big("AGENTE " + (name_text if name_text != "" else "—"), 28, Color("#7fd6ff"))
	_text("Nível final: %d" % GameManager.level, 20)
	_text("XP conquistado: %d" % GameManager.total_xp_earned, 20)
	var time_msec: int = int(entry.get("time_msec", Leaderboard.elapsed_msec()))
	_text("Tempo de jogo: %s" % Leaderboard.format_time(time_msec), 20)


func _add_board(run: Dictionary) -> void:
	_big("PLACAR", 30, Color("#ffd75f"))
	var scores: Array = Leaderboard.get_scores()
	if scores.is_empty():
		_text("Nenhum tempo registrado ainda.", 18)
		return
	var position: int = int(run.get("position", 0))
	for i in range(scores.size()):
		var score: Dictionary = scores[i]
		var is_player: bool = position == i + 1
		var row := "%2d.  %-10s  %s" % [i + 1, String(score["name"]), Leaderboard.format_time(int(score["time_msec"]))]
		var label := _text(row, 20)
		label.add_theme_color_override("font_color", Color("#ffd75f") if is_player else Color("#e8ece9"))
	if position == 0:
		_text("Seu tempo não entrou no top %d desta vez." % Leaderboard.MAX_ENTRIES, 16)
	elif position == 1:
		_big("NOVO RECORDE!", 26, Color("#3dff6e"))


func _big(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var label := _text(text, size)
	label.add_theme_color_override("font_color", color)
	return label


func _text(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDTH, 0)
	_scroller.add_child(label)
	return label


func _gap(height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	_scroller.add_child(gap)
