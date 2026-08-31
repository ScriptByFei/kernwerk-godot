class_name SpawnManager
extends Node
## Zentraler Spawner: entscheidet Lane, Timing und Gegner-Stats. Gegner spawnt sich nie selbst.
## Phase 3: einfacher Intervall-Spawner mit zufälliger Lane + skalierender HP.
## Phase 6 ersetzt das durch datengetriebene Waves — Schnittstelle bleibt gleich.

signal enemy_spawned(enemy: Enemy)

@export var spawn_interval := 1.6   # Sekunden zwischen Gegnern
var difficulty := 1.0               # steigt später über Wellen
var _timer := 0.0
var _world: Node2D

func setup(world: Node2D) -> void:
	_world = world
	# Erster Gegner nach kurzer Verzögerung, nicht sofort in den Spieler
	_timer = spawn_interval * 0.6

func set_world_reference(w: Node2D) -> void:
	_world = w

func _physics_process(delta: float) -> void:
	if _world == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval / maxf(difficulty, 0.1)
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

func _on_enemy_reached_bottom(_enemy: LaneObject) -> void:
	pass  # Schaden passiert in Game._check_enemy_reach (Spieler-Bereich, nichtViewportrand)

func _on_enemy_killed(_enemy: Enemy) -> void:
	pass  # Score/Coins in Phase 4/5 — Signal-Kette steht schon

func set_difficulty(d: float) -> void:
	difficulty = maxf(d, 0.1)