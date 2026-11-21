extends Node
## Gerenciador central de música. Autoload já registrado em project.godot.
## Não altera missões, combate nem lógica de troca de cenas.
## Ajustes de volume são valores iniciais: revise ouvindo no Godot.

const TRACKS := {
    "menu": "res://assets/audio/music/music_menu.ogg",
    "city": "res://assets/audio/music/music_city.ogg",
    "investigation": "res://assets/audio/music/music_investigation.ogg",
    "boss": "res://assets/audio/music/music_boss.ogg",
    "victory": "res://assets/audio/music/music_victory.ogg",
    "defeat": "res://assets/audio/music/music_defeat.ogg",
}

## As faixas têm volumes médios diferentes; estes ganhos tentam equilibrá-las.
## Não são os valores do controle de volume Master, que permanece inalterado.
const TRACK_VOLUME_DB := {
    "menu": -17.0,
    "city": -13.0,
    "investigation": -12.0,
    "boss": -21.0,
    "victory": -20.0,
    "defeat": -10.0,
}

## Música de fundo faz loop; músicas de encerramento tocam somente uma vez.
const LOOP_TRACKS := ["menu", "city", "investigation", "boss"]

## A música da cidade tem ~3,33 s de silêncio no início e ~1,07 s no fim.
## Saltamos essas partes ao iniciar/repetir, sem alterar o OGG original.
const START_OFFSET_SEC := {"city": 3.30}
const END_PADDING_SEC := {"city": 1.10}

const SILENT_DB := -65.0
const CHANGE_FADE_SEC := 1.0
const STOP_FADE_SEC := 0.65
const LOOP_FADE_SEC := 1.55

var _players: Array[AudioStreamPlayer] = []
var _active_index: int = 0
var _current_track: String = ""
var _fade_tween: Tween = null
var _transitioning: bool = false
var _boss_active: bool = false
var _ending_active: bool = false
var _investigating: bool = false


func _ready() -> void:
    for i in range(2):
        var player := AudioStreamPlayer.new()
        player.name = "BackgroundMusic%d" % (i + 1)
        player.volume_db = SILENT_DB
        add_child(player)
        _players.append(player)
    get_tree().scene_changed.connect(_on_scene_changed)
    call_deferred("_sync_to_scene")


func _process(_delta: float) -> void:
    # Recupera a trilha da cena caso uma janela de servidor seja fechada
    # sem avisar que a investigacao terminou. Nao interfere no duelo/finais.
    if not _transitioning and not _investigating and not _boss_active and not _ending_active:
        var scene: Node = get_tree().current_scene
        if scene != null:
            var expected_track: String = ""
            match String(scene.name):
                "City":
                    expected_track = "city"
                "MainMenu":
                    expected_track = "menu"
            if expected_track != "" and _current_track != expected_track:
                play_music(expected_track)
    if _transitioning or _current_track == "" or not LOOP_TRACKS.has(_current_track):
        return
    var player: AudioStreamPlayer = _players[_active_index]
    if player.stream == null:
        return
    if not player.playing:
        _switch_track(_current_track, true)
        return
    var length: float = player.stream.get_length()
    var end_padding: float = float(END_PADDING_SEC.get(_current_track, 0.0))
    if length <= LOOP_FADE_SEC + end_padding + 2.0:
        return
    if player.get_playback_position() >= length - end_padding - LOOP_FADE_SEC:
        _switch_track(_current_track, true)


func _sync_to_scene() -> void:
    _on_scene_changed(get_tree().current_scene)


func _on_scene_changed(scene: Node) -> void:
    if scene == null:
        return
    _boss_active = false
    _ending_active = false
    _investigating = false
    _play_for_scene(scene)


func _play_for_scene(scene: Node) -> void:
    if scene == null:
        stop_music()
        return
    match String(scene.name):
        "MainMenu":
            play_music("menu")
        "City":
            play_music("city")
        _:
            # As salas possuem efeitos ambientes próprios em InteriorBase.gd.
            stop_music()


func start_investigation() -> void:
    if _boss_active or _ending_active:
        return
    _investigating = true
    if _track_exists("investigation"):
        play_music("investigation")


func end_investigation() -> void:
    # Idempotente: mesmo que o terminal tenha sido minimizado antes de
    # fechar o desktop, tenta restaurar a trilha correta da cena.
    _investigating = false
    if not _boss_active and not _ending_active:
        _play_for_scene(get_tree().current_scene)


func start_boss() -> void:
    _boss_active = true
    _ending_active = false
    _investigating = false
    play_music("boss")


func play_ending(won: bool) -> void:
    _boss_active = false
    _ending_active = true
    _investigating = false
    play_music("victory" if won else "defeat")


func play_music(track_name: String) -> void:
    _switch_track(track_name, false)


## Usa dois players para fazer crossfade, inclusive ao reiniciar o loop.
func _switch_track(track_name: String, is_loop: bool) -> void:
    if _players.size() < 2:
        return
    var old_player: AudioStreamPlayer = _players[_active_index]
    if not is_loop and track_name == _current_track and old_player.playing:
        return
    if not _track_exists(track_name):
        stop_music()
        return
    var stream: AudioStream = load(String(TRACKS[track_name]))
    if stream == null:
        stop_music()
        return
    # Desativar o loop embutido: dois players permitem uma repetição suave.
    if stream is AudioStreamOggVorbis:
        (stream as AudioStreamOggVorbis).loop = false
    if _fade_tween != null and _fade_tween.is_running():
        _fade_tween.kill()
    var next_index: int = 1 - _active_index
    var next_player: AudioStreamPlayer = _players[next_index]
    next_player.stop()
    next_player.stream = stream
    next_player.volume_db = SILENT_DB
    var offset: float = float(START_OFFSET_SEC.get(track_name, 0.0))
    next_player.play(offset)
    _active_index = next_index
    _current_track = track_name
    _transitioning = true
    var fade_seconds: float = LOOP_FADE_SEC if is_loop else CHANGE_FADE_SEC
    var target_db: float = float(TRACK_VOLUME_DB.get(track_name, -17.0))
    _fade_tween = create_tween()
    _fade_tween.tween_property(next_player, "volume_db", target_db, fade_seconds)
    if old_player.playing:
        _fade_tween.parallel().tween_property(old_player, "volume_db", SILENT_DB, fade_seconds)
    _fade_tween.tween_callback(func() -> void:
        old_player.stop()
        old_player.stream = null
        _transitioning = false
    )


func stop_music() -> void:
    if _players.is_empty():
        return
    _current_track = ""
    if _fade_tween != null and _fade_tween.is_running():
        _fade_tween.kill()
    var first: AudioStreamPlayer = _players[0]
    var second: AudioStreamPlayer = _players[1]
    if not first.playing and not second.playing:
        _transitioning = false
        return
    _transitioning = true
    _fade_tween = create_tween()
    _fade_tween.tween_property(first, "volume_db", SILENT_DB, STOP_FADE_SEC)
    _fade_tween.parallel().tween_property(second, "volume_db", SILENT_DB, STOP_FADE_SEC)
    _fade_tween.tween_callback(func() -> void:
        first.stop()
        second.stop()
        first.stream = null
        second.stream = null
        _transitioning = false
    )


func _track_exists(track_name: String) -> bool:
    return TRACKS.has(track_name) and ResourceLoader.exists(String(TRACKS[track_name]))
