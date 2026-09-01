class_name Sfx
extends Node

const MAX_PLAYERS := 4
const SOUNDS := {
	"shoot": {"stream": preload("res://assets/sounds/shoot.ogg"), "db": -18.0},
	"enemy_hit": {"stream": preload("res://assets/sounds/enemy_hit.ogg"), "db": -12.0},
	"kill": {"stream": preload("res://assets/sounds/kill.ogg"), "db": -12.0},
	"upgrade": {"stream": preload("res://assets/sounds/upgrade.ogg"), "db": -10.0},
	"player_hit": {"stream": preload("res://assets/sounds/player_hit.ogg"), "db": -8.0},
	"wave_start": {"stream": preload("res://assets/sounds/wave_start.ogg"), "db": -10.0},
	"boss_pulse": {"stream": preload("res://assets/sounds/boss_pulse.ogg"), "db": -10.0},
	"level_complete": {"stream": preload("res://assets/sounds/level_complete.ogg"), "db": -8.0},
}

var _unlocked := false
var _pending: String = ""
var _players: Array[AudioStreamPlayer] = []

func unlock() -> void:
	if _unlocked:
		return
	_unlocked = true
	_play_unlock_stream()
	if not _pending.is_empty():
		var pending := _pending
		_pending = ""
		play(pending)

func play(sound_name: String, db: float = NAN) -> void:
	if not SOUNDS.has(sound_name):
		return
	if not _unlocked:
		_pending = sound_name
		return
	var definition: Dictionary = SOUNDS[sound_name]
	var volume: float = float(definition["db"]) if is_nan(db) else db
	_start_player(sound_name, definition["stream"] as AudioStream, volume)

func _play_unlock_stream() -> void:
	var player := AudioStreamPlayer.new()
	player.name = "AudioUnlock"
	player.stream = _silent_stream()
	player.volume_db = -80.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _silent_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 8000
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	var silence := PackedByteArray()
	silence.resize(160)
	stream.data = silence
	return stream

func _start_player(sound_name: String, stream: AudioStream, volume: float) -> void:
	while _players.size() >= MAX_PLAYERS:
		var oldest: AudioStreamPlayer = _players.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var player := AudioStreamPlayer.new()
	player.name = "Sfx_%s" % sound_name
	player.stream = stream
	player.volume_db = minf(volume, -6.0)
	add_child(player)
	_players.append(player)
	player.finished.connect(_on_player_finished.bind(player))
	player.play()

func _on_player_finished(player: AudioStreamPlayer) -> void:
	_players.erase(player)
	player.queue_free()
