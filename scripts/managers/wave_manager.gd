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

func attach(world: Node2D, spawner_ref: SpawnManager) -> void:
	_world = world
	spawner = spawner_ref

func start_level() -> void:
	current_wave = 0
	is_level_done = false
	_wave_time = 0.0
	_next_wave()

func _physics_process(delta: float) -> void:
	if _world == null or is_level_done or spawner == null:
		return
	_wave_time += delta
	var data := WaveData.get_wave(current_wave - 1)
	if data.is_empty():
		return
	if _wave_time >= float(data["duration"]):
		_next_wave()

func _next_wave() -> void:
	_wave_time = 0.0
	var next := current_wave + 1
	var data := WaveData.get_wave(next - 1)  # 0-based lookup
	if data.is_empty():
		is_level_done = true
		level_completed.emit()
		return
	current_wave = next
	spawner.set_wave_params(
		float(data["spawn_interval"]),
		float(data["upgrade_chance"]),
		float(data["hp_factor"]),
		float(data["speed_factor"])
	)
	wave_started.emit(next)
	if bool(data.get("boss", false)):
		spawner.spawn_boss()
		boss_appeared.emit()

func restart() -> void:
	is_level_done = false
	current_wave = 0
	_wave_time = 0.0
	_next_wave()