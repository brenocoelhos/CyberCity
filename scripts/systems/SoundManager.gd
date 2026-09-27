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
	"keypress": "res://assets/audio/keypress.wav",
	"success": "res://assets/audio/success.wav",
	"error": "res://assets/audio/error.wav",
}

const POOL_SIZE := 6

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0


func _ready() -> void:
	for key in SOUNDS.keys():
		var stream: AudioStream = load(String(SOUNDS[key]))
		if stream:
			_streams[key] = stream

	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


## Toca um efeito sonoro pelo nome (ver SOUNDS acima). Silenciosamente
## ignora nomes desconhecidos, para nunca travar o jogo por causa de som.
func play(sound_name: String, volume_db: float = 0.0) -> void:
	if not _streams.has(sound_name):
		return

	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()

	player.stream = _streams[sound_name]
	player.volume_db = volume_db
	player.play()
