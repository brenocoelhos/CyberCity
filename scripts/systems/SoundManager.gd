extends Node
## SoundManager.gd — Autoload
## Toca efeitos sonoros curtos (passos, interação, terminal, sucesso,
## erro). Usa um pequeno pool de AudioStreamPlayer em vez de um único
## player, para um som novo não cortar o anterior (ex.: passos rápidos
## ou teclas digitadas em sequência no terminal).
##
## Os sons são placeholders gerados por código (assets/audio/*.wav) —
## dá pra trocar por sons de verdade depois só substituindo os arquivos.

const SOUNDS := {
	"footstep": "res://assets/audio/footstep.wav",
	"interact": "res://assets/audio/interact.wav",
	"blip": "res://assets/audio/blip.wav",
	"menu_hover": "res://assets/audio/menu_hover.wav",
	"keypress": "res://assets/audio/keypress.wav",
	"success": "res://assets/audio/success.wav",
	"error": "res://assets/audio/error.wav",
	# Extras opcionais: so tocam quando os arquivos forem adicionados.
	"phone_ring": "res://assets/audio/phone_ring.wav",
	"phone_message": "res://assets/audio/phone_message.wav",
	"mission_new": "res://assets/audio/mission_new.wav",
	"chapter_new": "res://assets/audio/chapter_new.wav",
	"door": "res://assets/audio/door.wav",
	"alarm": "res://assets/audio/alarm.wav",
	"warning": "res://assets/audio/warning.wav",
	"game_over": "res://assets/audio/game_over.wav",
}

const POOL_SIZE := 6

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
## Uma temporização por canal evita parar por engano um som novo no mesmo canal.
var _cutoff_tweens: Array[Tween] = []


func _ready() -> void:
	for key in SOUNDS.keys():
		var path: String = String(SOUNDS[key])
		if not ResourceLoader.exists(path):
			continue
		var stream: AudioStream = load(path)
		if stream:
			_streams[key] = stream

	call_deferred("_connect_event_sounds")

	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
		_cutoff_tweens.append(null)


## Toca um efeito sonoro pelo nome (ver SOUNDS acima). Silenciosamente
## ignora nomes desconhecidos, para nunca travar o jogo por causa de som.
func play(sound_name: String, volume_db: float = 0.0, max_duration: float = 0.0) -> void:
	if not _streams.has(sound_name) or _players.is_empty():
		return

	var index: int = _next_player
	_next_player = (_next_player + 1) % _players.size()
	var player: AudioStreamPlayer = _players[index]

	# Se este canal for reutilizado, cancela a interrupção agendada do som anterior.
	if _cutoff_tweens[index] != null:
		_cutoff_tweens[index].kill()
		_cutoff_tweens[index] = null

	player.stop()
	player.stream = _streams[sound_name]
	player.volume_db = volume_db
	player.play()

	# Limita efeitos longos sem precisar recortar o arquivo WAV original.
	# Faz um fade-out curto para não produzir clique ao interromper.
	if max_duration > 0.0:
		var duration: float = max_duration
		var length: float = player.stream.get_length()
		if length > 0.0:
			duration = minf(duration, length)
		var fade_seconds: float = minf(0.16, duration * 0.3)
		var tween: Tween = create_tween()
		tween.tween_interval(maxf(0.0, duration - fade_seconds))
		tween.tween_property(player, "volume_db", -65.0, fade_seconds)
		tween.tween_callback(player.stop)
		_cutoff_tweens[index] = tween


## Escuta eventos que ja existem no jogo, sem modificar suas regras.
func _connect_event_sounds() -> void:
	if not PhoneManager.message_received.is_connected(_on_message_received):
		PhoneManager.message_received.connect(_on_message_received)
	if not MissionManager.mission_started.is_connected(_on_mission_started):
		MissionManager.mission_started.connect(_on_mission_started)
	if not CampaignManager.chapter_unlocked.is_connected(_on_chapter_unlocked):
		CampaignManager.chapter_unlocked.connect(_on_chapter_unlocked)


func _on_message_received(_message: Dictionary) -> void:
	play("phone_message", -7.0)


func _on_mission_started(_mission_id: String) -> void:
	play("mission_new", -5.0)


func _on_chapter_unlocked(_chapter_id: String) -> void:
	play("chapter_new", -5.0)


func has_sound(sound_name: String) -> bool:
	return _streams.has(sound_name)
