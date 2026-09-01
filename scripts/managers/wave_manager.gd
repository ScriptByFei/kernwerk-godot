class_name WaveManager
extends Node
## Steuert den Wellen-Ablauf (Phase 6): liest WaveData, setzt SpawnManager-Parameter
## pro Welle, feuert wave_started / level_completed. Boss spawnt beim boss-Flag.

signal wave_started(wave_index: int)     # 1-basiert fürs UI
signal level_completed
signal boss_appeared

var current_wave := 0          # 1-basiert für UI; 0 = nicht gestartet
var is_level_done := false
var _wave_time := 0.0
var spawner: SpawnManager
var _world: Node2D
var _waiting_for_boss := false

func attach(world: Node2D, spawner_ref: SpawnManager) -> void:
	_world = world
	spawner = spawner_ref
	if not spawner.boss_defeated.is_connected(_on_boss_defeated):
		spawner.boss_defeated.connect(_on_boss_defeated)

func start_level() -> void:
	current_wave = 0
	is_level_done = false
	_wave_time = 0.0
	_waiting_for_boss = false
	spawner.set_spawning_enabled(true)
	_next_wave()

func _physics_process(delta: float) -> void:
	if _world == null or is_level_done or spawner == null:
		return
	_wave_time += delta
	var data := WaveData.get_wave(current_wave - 1)
	if data.is_empty():
		return
	if _wave_time >= float(data["duration"]):
		if bool(data.get("boss", false)):
			# Nach Ablauf der Boss-Welle keine Adds mehr erzeugen. Das Level endet
			# aber erst mit dem Boss-Kill, nicht aufgrund eines Timers.
			spawner.set_spawning_enabled(false)
		else:
			_next_wave()

func _next_wave() -> void:
	_wave_time = 0.0
	var next := current_wave + 1
	var data := WaveData.get_wave(next - 1)  # 0-based lookup
	if data.is_empty():
		_finish_level()
		return
	current_wave = next
	spawner.set_spawning_enabled(true)
	spawner.set_wave_params(
		float(data["spawn_interval"]),
		float(data["upgrade_chance"]),
		float(data["hp_factor"]),
		float(data["speed_factor"]),
		next
	)
	wave_started.emit(next)
	if bool(data.get("boss", false)):
		_waiting_for_boss = true
		spawner.spawn_boss()
		boss_appeared.emit()

func _on_boss_defeated(_boss: Enemy) -> void:
	if _waiting_for_boss and not is_level_done:
		_finish_level()

func _finish_level() -> void:
	is_level_done = true
	_waiting_for_boss = false
	spawner.set_spawning_enabled(false)
	level_completed.emit()

func restart() -> void:
	is_level_done = false
	current_wave = 0
	_wave_time = 0.0
	_waiting_for_boss = false
	spawner.set_spawning_enabled(true)
	_next_wave()
