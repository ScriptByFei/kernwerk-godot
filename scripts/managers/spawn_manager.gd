class_name SpawnManager
extends Node
## Zentraler Spawner: wählt faire Reihen, warnt sie vor und erzeugt deren Objekte.
## Gegner/Upgrades spawnt sich nie selbst. WaveManager steuert Parameter pro Welle.

signal enemy_spawned(enemy: Enemy)
signal upgrade_spawned(upgrade: UpgradeObject)
signal upgrade_collected_from_world(upgrade: UpgradeObject)  # Game hookt Effekt + Feedback
signal boss_spawned(boss: Boss)
signal enemy_killed_from_world(enemy: Enemy)
signal boss_defeated(boss: Enemy)
signal enemy_reached_player(enemy: Enemy)
signal pattern_telegraphed(pattern_id: String, slots: Array)
signal pattern_spawned(pattern_id: String, slots: Array)

var spawn_interval := 1.6   # Sekunden zwischen Spawns (vom WaveManager gesteuert)
var upgrade_chance := 0.22  # Anteil Upgrade-Spawns
var hp_factor := 1.0        # von WaveManager gesetzt
var speed_factor := 1.0
var _timer := 0.0
var _world: Node2D
var spawning_enabled := true
var _rng := RandomNumberGenerator.new()
var current_wave := 1
var _pending_pattern: Dictionary = {}
var _telegraph: SpawnTelegraph
var _boss_alive := false  # true zwischen spawn_boss() und Boss-Tod (Summons-Guard)

const UPGRADE_TYPES := ["damage", "firerate", "soldier"]
const TELEGRAPH_DURATION := 0.6

func setup(world: Node2D, random_seed: int = -1) -> void:
	_world = world
	if random_seed >= 0:
		_rng.seed = random_seed
	else:
		_rng.randomize()
	_timer = spawn_interval * 0.6  # Erster Spawn nach kurzer Verzögerung

func set_random_seed(random_seed: int) -> void:
	_rng.seed = random_seed

func set_world_reference(w: Node2D) -> void:
	_world = w

func _physics_process(delta: float) -> void:
	if _world == null or not spawning_enabled:
		return
	_timer -= delta
	if _timer <= 0.0:
		if _pending_pattern.is_empty():
			_prepare_next_pattern()
			_timer = TELEGRAPH_DURATION
		else:
			_spawn_pending_pattern()
			_timer = maxf(spawn_interval - TELEGRAPH_DURATION, 0.4)

func set_wave_params(interval: float, chance: float, hp_f: float, speed_f: float, wave_index: int = 1) -> void:
	## Kompletter Parameter-Satz einer Welle (aus WaveData), zentral gesetzt.
	spawn_interval = maxf(interval, 0.4)
	upgrade_chance = clampf(chance, 0.0, 1.0)
	hp_factor = maxf(hp_f, 0.1)
	speed_factor = maxf(speed_f, 0.1)
	if current_wave != wave_index:
		_clear_pending_pattern()
	current_wave = maxi(wave_index, 1)

func set_spawning_enabled(enabled: bool) -> void:
	spawning_enabled = enabled
	if enabled:
		_timer = minf(_timer, spawn_interval)
	else:
		_clear_pending_pattern()

func spawn_boss() -> void:
	var boss := Boss.new()
	var lane := _roll_lane()
	boss.configure(lane)
	_world.add_child(boss)
	boss.position = Vector2(boss.lane_x_now(), -140.0)
	boss.reached_bottom.connect(_on_enemy_reached_bottom)
	boss.enemy_killed.connect(_on_enemy_killed)
	boss.summon_requested.connect(_on_boss_summon_requested)
	_boss_alive = true
	boss_spawned.emit(boss)

func _on_boss_summon_requested(summon_lanes: Array, enemy_type: String) -> void:
	if not is_instance_valid(_world):
		return
	var telegraph := SpawnTelegraph.new()
	telegraph.name = "BossSummonTelegraph"
	_world.add_child(telegraph)
	var slots := [SpawnPatternData.EMPTY, SpawnPatternData.EMPTY, SpawnPatternData.EMPTY]
	for summon_lane in summon_lanes:
		slots[clampi(int(summon_lane), 0, GameConfig.LANE_COUNT - 1)] = enemy_type
	telegraph.configure(slots)
	get_tree().create_timer(TELEGRAPH_DURATION).timeout.connect(_spawn_boss_summons.bind(summon_lanes.duplicate(), enemy_type, telegraph))

func _spawn_boss_summons(summon_lanes: Array, enemy_type: String, telegraph: SpawnTelegraph) -> void:
	# Boss tot / Level vorbei → keine Adds mehr nach dem Kampfende nachziehen.
	# (Crash-Review-Fix 099ac2f → M-Finding.)
	if not _boss_alive:
		return
	if is_instance_valid(telegraph):
		telegraph.queue_free()
	if not is_instance_valid(_world):
		return
	for summon_lane in summon_lanes:
		_spawn_enemy(int(summon_lane), enemy_type)

func _spawn_enemy(lane_override: int = -1, p_enemy_type: String = EnemyArchetypeData.GRUNT) -> void:
	var enemy := Enemy.new()
	var definition := EnemyArchetypeData.get_definition(p_enemy_type)
	var hp := maxi(1, int(50.0 * hp_factor * float(definition["hp_multiplier"])))
	var speed := 150.0 * speed_factor * float(definition["speed_multiplier"])
	var lane := _roll_lane() if lane_override < 0 else clampi(lane_override, 0, GameConfig.LANE_COUNT - 1)
	enemy.configure(lane, hp, speed, false, p_enemy_type)
	_world.add_child(enemy)
	# Spawn-Position NACH add_child setzen — erst im Baum ist das Viewport-Rect
	# verfügbar (davor liefert lane_x_now() 0 → Gegner klebten am linken Rand).
	enemy.position = Vector2(enemy.lane_x_now(), -80.0)
	enemy.reached_bottom.connect(_on_enemy_reached_bottom)
	enemy.enemy_killed.connect(_on_enemy_killed)
	enemy_spawned.emit(enemy)

func _spawn_upgrade(lane_override: int = -1) -> void:
	var up := UpgradeObject.new()
	var lane := _roll_lane() if lane_override < 0 else clampi(lane_override, 0, GameConfig.LANE_COUNT - 1)
	var type := _roll_upgrade_type()
	up.configure_upgrade(lane, type, 150.0 * speed_factor)
	_world.add_child(up)
	up.position = Vector2(up.lane_x_now(), -80.0)
	up.upgrade_collected.connect(_on_upgrade_collected)
	upgrade_spawned.emit(up)

func _on_enemy_reached_bottom(enemy: LaneObject) -> void:
	if enemy is Enemy:
		enemy_reached_player.emit(enemy as Enemy)

func _on_upgrade_collected(u: UpgradeObject) -> void:
	upgrade_collected_from_world.emit(u)

func _on_enemy_killed(enemy: Enemy) -> void:
	enemy_killed_from_world.emit(enemy)
	if enemy.is_boss:
		_boss_alive = false
		boss_defeated.emit(enemy)

func _roll_lane() -> int:
	return _rng.randi_range(0, GameConfig.LANE_COUNT - 1)

func _roll_upgrade_type() -> String:
	return UPGRADE_TYPES[_rng.randi_range(0, UPGRADE_TYPES.size() - 1)]

func _prepare_next_pattern() -> void:
	_pending_pattern = _choose_pattern()
	if _pending_pattern.is_empty():
		return
	_telegraph = SpawnTelegraph.new()
	_telegraph.name = "SpawnTelegraph"
	_world.add_child(_telegraph)
	_telegraph.configure(_pending_pattern["slots"])
	pattern_telegraphed.emit(str(_pending_pattern["id"]), _pending_pattern["slots"].duplicate())

func _spawn_pending_pattern() -> void:
	if _pending_pattern.is_empty():
		return
	var pattern_id := str(_pending_pattern["id"])
	var slots: Array = _pending_pattern["slots"].duplicate()
	for lane in slots.size():
		var token := str(slots[lane])
		if token == SpawnPatternData.UPGRADE:
			_spawn_upgrade(lane)
		elif EnemyArchetypeData.is_regular_type(token):
			_spawn_enemy(lane, token)
	pattern_spawned.emit(pattern_id, slots)
	_clear_pending_pattern()

func _choose_pattern() -> Dictionary:
	var candidates := SpawnPatternData.patterns_for_wave(current_wave)
	if candidates.is_empty():
		return {}
	var weights: Array[float] = []
	var total_weight := 0.0
	for pattern in candidates:
		var weight := float(pattern["weight"])
		if SpawnPatternData.has_upgrade(pattern["slots"]):
			weight *= upgrade_chance / 0.25
		else:
			weight *= (1.0 - upgrade_chance) / 0.75
		weight = maxf(weight, 0.0)
		weights.append(weight)
		total_weight += weight
	var roll := _rng.randf_range(0.0, total_weight)
	var selected: Dictionary = candidates.back().duplicate(true)
	for index in candidates.size():
		roll -= weights[index]
		if roll <= 0.0:
			selected = candidates[index].duplicate(true)
			break
	_shuffle_slots(selected["slots"])
	return selected

func _shuffle_slots(slots: Array) -> void:
	for index in range(slots.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var value = slots[index]
		slots[index] = slots[swap_index]
		slots[swap_index] = value

func _clear_pending_pattern() -> void:
	_pending_pattern.clear()
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null
