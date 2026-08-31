class_name SpawnManager
extends Node
## Zentraler Spawner: entscheidet Lane, Timing und Objekt-Typ (Gegner vs. Upgrade).
## Gegner/Upgrades spawnt sich nie selbst. Phase 6 ersetzt Intervall durch datengetriebene Waves.

signal enemy_spawned(enemy: Enemy)
signal upgrade_spawned(upgrade: UpgradeObject)
signal upgrade_collected_from_world(upgrade: UpgradeObject)  # Game hookt Effekt + Feedback

var spawn_interval := 1.6   # Sekunden zwischen Spawns
var upgrade_chance := 0.22  # 22% der Spawns sind Upgrade-Träger
var difficulty := 1.0
var _timer := 0.0
var _world: Node2D

const UPGRADE_TYPES := ["damage", "firerate", "soldier"]

func setup(world: Node2D) -> void:
	_world = world
	_timer = spawn_interval * 0.6  # Erster Spawn nach kurzer Verzögerung

func set_world_reference(w: Node2D) -> void:
	_world = w

func _physics_process(delta: float) -> void:
	if _world == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval / maxf(difficulty, 0.1)
		if randf() < upgrade_chance:
			_spawn_upgrade()
		else:
			_spawn_enemy()

func _spawn_enemy() -> void:
	var enemy := Enemy.new()
	var hp := int(50 * difficulty)
	var speed := 150.0 * difficulty
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
	up.configure_upgrade(lane, type, 150.0 * difficulty)
	_world.add_child(up)
	up.position = Vector2(up.lane_x_now(), -80.0)
	up.upgrade_collected.connect(_on_upgrade_collected)
	upgrade_spawned.emit(up)

func _on_enemy_reached_bottom(_enemy: LaneObject) -> void:
	pass

func _on_upgrade_collected(u: UpgradeObject) -> void:
	upgrade_collected_from_world.emit(u)

func _on_enemy_killed(_enemy: Enemy) -> void:
	pass

func set_difficulty(d: float) -> void:
	difficulty = maxf(d, 0.1)