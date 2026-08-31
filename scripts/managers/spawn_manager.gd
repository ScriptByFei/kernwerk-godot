class_name SpawnManager
extends Node
## Zentraler Spawner: entscheidet Lane, Timing und Objekt-Typ (Gegner vs. Upgrade).
## Gegner/Upgrades spawnt sich nie selbst. WaveManager steuert Parameter pro Welle.

signal enemy_spawned(enemy: Enemy)
signal upgrade_spawned(upgrade: UpgradeObject)
signal upgrade_collected_from_world(upgrade: UpgradeObject)  # Game hookt Effekt + Feedback
signal boss_spawned(boss: Enemy)
signal enemy_killed_from_world(enemy: Enemy)
signal boss_defeated(boss: Enemy)

var spawn_interval := 1.6   # Sekunden zwischen Spawns (vom WaveManager gesteuert)
var upgrade_chance := 0.22  # Anteil Upgrade-Spawns
var hp_factor := 1.0        # von WaveManager gesetzt
var speed_factor := 1.0
var _timer := 0.0
var _world: Node2D
var spawning_enabled := true

const UPGRADE_TYPES := ["damage", "firerate", "soldier"]

func setup(world: Node2D) -> void:
	_world = world
	_timer = spawn_interval * 0.6  # Erster Spawn nach kurzer Verzögerung

func set_world_reference(w: Node2D) -> void:
	_world = w

func _physics_process(delta: float) -> void:
	if _world == null or not spawning_enabled:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval
		if randf() < upgrade_chance:
			_spawn_upgrade()
		else:
			_spawn_enemy()

func set_wave_params(interval: float, chance: float, hp_f: float, speed_f: float) -> void:
	## Kompletter Parameter-Satz einer Welle (aus WaveData), zentral gesetzt.
	spawn_interval = maxf(interval, 0.4)
	upgrade_chance = clampf(chance, 0.0, 1.0)
	hp_factor = maxf(hp_f, 0.1)
	speed_factor = maxf(speed_f, 0.1)

func set_spawning_enabled(enabled: bool) -> void:
	spawning_enabled = enabled
	if enabled:
		_timer = minf(_timer, spawn_interval)

func spawn_boss() -> void:
	# Phase 6 MVP-Boss: viel HP, langsam, Spawn oben in zufälliger Lane
	var boss := Enemy.new()
	var lane := randi_range(0, GameConfig.LANE_COUNT - 1)
	boss.configure(lane, int(WaveData.BOSS_HP), WaveData.BOSS_SPEED, true)
	_world.add_child(boss)
	boss.position = Vector2(boss.lane_x_now(), -140.0)
	boss.reached_bottom.connect(_on_enemy_reached_bottom)
	boss.enemy_killed.connect(_on_enemy_killed)
	boss_spawned.emit(boss)

func _spawn_enemy() -> void:
	var enemy := Enemy.new()
	var hp := int(50.0 * hp_factor)
	var speed := 150.0 * speed_factor
	var lane := randi_range(0, GameConfig.LANE_COUNT - 1)
	enemy.configure(lane, hp, speed)
	_world.add_child(enemy)
	# Spawn-Position NACH add_child setzen — erst im Baum ist das Viewport-Rect
	# verfügbar (davor liefert lane_x_now() 0 → Gegner klebten am linken Rand).
	enemy.position = Vector2(enemy.lane_x_now(), -80.0)
	enemy.reached_bottom.connect(_on_enemy_reached_bottom)
	enemy.enemy_killed.connect(_on_enemy_killed)
	enemy_spawned.emit(enemy)

func _spawn_upgrade() -> void:
	var up := UpgradeObject.new()
	var lane := randi_range(0, GameConfig.LANE_COUNT - 1)
	var type: String = UPGRADE_TYPES[randi_range(0, UPGRADE_TYPES.size() - 1)]
	up.configure_upgrade(lane, type, 150.0 * speed_factor)
	_world.add_child(up)
	up.position = Vector2(up.lane_x_now(), -80.0)
	up.upgrade_collected.connect(_on_upgrade_collected)
	upgrade_spawned.emit(up)

func _on_enemy_reached_bottom(_enemy: LaneObject) -> void:
	pass

func _on_upgrade_collected(u: UpgradeObject) -> void:
	upgrade_collected_from_world.emit(u)

func _on_enemy_killed(enemy: Enemy) -> void:
	enemy_killed_from_world.emit(enemy)
	if enemy.is_boss:
		boss_defeated.emit(enemy)
