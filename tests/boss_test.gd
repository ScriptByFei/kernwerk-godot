extends SceneTree
## Phase-7-Tests: Hover-Boss, Pulse, Summons, Phasenwechsel und Kill-Kette.

var fails := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ " + msg)
	else:
		fails += 1
		print("  ✗ " + msg)

func _init() -> void:
	var world := Node2D.new()
	get_root().add_child(world)
	await process_frame

	var boss := Boss.new()
	boss.configure(1)
	world.add_child(boss)
	boss.position = Vector2(boss.lane_x_now(), -140.0)
	_check(boss.is_boss and boss.enemy_type == EnemyArchetypeData.BOSS, "Boss.configure setzt Boss-Typ")
	_check(boss.current_hp == BossData.BOSS_HP and boss.max_hp == BossData.BOSS_HP, "Boss-HP stammt aus BossData")

	_check(not boss.is_phase_two, "Über 50% HP startet Phase 1")
	boss.take_damage(BossData.BOSS_HP / 2)
	_check(boss.is_phase_two, "Bei 50% HP startet Phase 2")

	var pulse_lanes: Array = []
	boss.lane_pulse_fired.connect(func(pulse_lane): pulse_lanes.append(pulse_lane))
	boss.fire_lane_pulse()
	_check(pulse_lanes == [boss.lane], "Lane-Pulse feuert die aktuelle Boss-Lane")

	var summon_lanes: Array = []
	var summon_types: Array = []
	boss.is_phase_two = false
	boss.summon_requested.connect(func(lanes, enemy_type):
		summon_lanes.append_array(lanes)
		summon_types.append(enemy_type)
	)
	boss.request_summons()
	_check(summon_lanes.size() == BossData.SUMMON_COUNT_P1 and _all_not_lane(summon_lanes, boss.lane), "Phase 1 beschwört 2 Adds außerhalb der Boss-Lane")
	summon_lanes.clear()
	summon_types.clear()
	boss.is_phase_two = true
	boss.request_summons()
	_check(summon_lanes.size() == BossData.SUMMON_COUNT_P2 and _all_not_lane(summon_lanes, boss.lane) and EnemyArchetypeData.RUNNER in summon_types, "Phase 2 beschwört 3 Adds inklusive Runner außerhalb der Boss-Lane")

	boss.position.y = -140.0
	boss._physics_process(10.0)
	_check(absf(boss.position.y - boss.get_viewport_rect().size.y * BossData.HOVER_Y_RATIO) < 0.1, "Boss stoppt am viewport-relativen Hover-Punkt")

	# --- Regression: kein Lane-Wechsel während Pulse-Telegraph (Review-Fix H) ---
	var boss2 := Boss.new()
	boss2.configure(0)
	world.add_child(boss2)
	boss2.position = Vector2(boss2.lane_x_now(), -140.0)
	boss2._physics_process(10.0)
	var pulse_emit_lanes: Array = []
	boss2.lane_pulse_fired.connect(func(pl): pulse_emit_lanes.append(pl))
	boss2._lane_switch_timer = 999.0
	boss2.begin_lane_pulse()
	boss2._update_combat_timers(0.1)
	_check(boss2.lane == 0, "Telegraph blockiert Lane-Wechsel")
	# Telegraph-Ende: Pulse feuert aus der GEWARNTEN Lane (0); erst danach ist der
	# Lane-Wechsel wieder erlaubt. (Deterministisch: ein einzelner Switch ∈ {1,2}.)
	boss2._update_combat_timers(BossData.PULSE_TELEGRAPH + 0.01)
	_check(pulse_emit_lanes == [0], "Pulse feuert aus der gewarnten Lane")
	_check(boss2.lane != 0, "Nach Telegraph wechselt der Boss wieder die Lane")
	boss2.queue_free()

	var game_scene := load("res://scenes/game/game.tscn") as PackedScene
	var game := game_scene.instantiate() as Node2D
	get_root().add_child(game)
	await process_frame
	var player := game.get_node("Player") as Player
	var health: PlayerHealth = game.player_health
	player.current_lane = 0
	game._on_boss_lane_pulse(1)
	_check(health.hp == GameConfig.MAX_HEALTH, "Pulse in anderer Lane verletzt den Spieler nicht")
	game.game_manager.clear_iframes()
	game._on_boss_lane_pulse(0)
	_check(health.hp == GameConfig.MAX_HEALTH - BossData.PULSE_DAMAGE, "Pulse in Spieler-Lane nutzt PlayerHealth")
	game.queue_free()
	await process_frame

	var spawner := SpawnManager.new()
	world.add_child(spawner)
	spawner.setup(world)
	var waves := WaveManager.new()
	world.add_child(waves)
	waves.attach(world, spawner)
	var completed := [0]
	waves.level_completed.connect(func(): completed[0] += 1)
	waves.start_level()
	for _step in 10:
		waves._physics_process(25.0)
	var spawned_boss: Boss = null
	for child in world.get_children():
		if child is Boss:
			spawned_boss = child
	if spawned_boss:
		spawned_boss.take_damage(BossData.BOSS_HP)
	_check(completed[0] == 1 and waves.is_level_done, "Boss-Kill läuft über SpawnManager zu WaveManager und beendet das Level")

	# --- Regression: keine Adds nach Boss-Tod (Review-Fix M) ---
	var enemies_before_summon := 0
	for child in world.get_children():
		if child is Enemy:
			enemies_before_summon += 1
	spawner._spawn_boss_summons([1], EnemyArchetypeData.GRUNT, null)
	var enemies_after_summon := 0
	for child in world.get_children():
		if child is Enemy:
			enemies_after_summon += 1
	_check(enemies_after_summon == enemies_before_summon, "Boss tot → Nachzügler-Summons unterdrückt (Guard)")
	spawner._boss_alive = true
	spawner._spawn_boss_summons([1], EnemyArchetypeData.GRUNT, null)
	enemies_after_summon = 0
	for child in world.get_children():
		if child is Enemy:
			enemies_after_summon += 1
	_check(enemies_after_summon == enemies_before_summon + 1, "Boss lebt → Summons spawnt Adds")

	# --- Boss-HP-Skalierung (Playtest: \"Boss instant tot durch Upgrades\") ---
	_check(BossData.scaled_hp(1.0) == BossData.BOSS_HP, "Ratio 1.0 → Basis-HP 500")
	_check(BossData.scaled_hp(0.5) == BossData.BOSS_HP, "Ratio <1 → Floor 500")
	_check(BossData.scaled_hp(4.0) == BossData.BOSS_HP * 2, "Ratio 4.0 (Wurzel) → 1000 HP")
	_check(BossData.scaled_hp(9.0) == BossData.BOSS_HP * 3, "Ratio 9.0 (Wurzel) → 1500 HP")
	_check(BossData.scaled_hp(9.0) > BossData.scaled_hp(4.0), "Mehr DPS → mehr Boss-HP (monoton)")
	# SpawnManager nutzt player_stats für die Skalierung
	var stats2 := PlayerStats.new()
	world.add_child(stats2)
	stats2.damage = 40  # 4× Base-Schaden → DPS-Ratio 4.0
	spawner.player_stats = stats2
	var scaled := spawner._boss_hp()
	_check(scaled == BossData.BOSS_HP * 2, "SpawnManager._boss_hp() folgt PlayerStats (4× DPS → 1000)")
	spawner.player_stats = null
	_check(spawner._boss_hp() == BossData.BOSS_HP, "Ohne PlayerStats → Basis-HP (nil-safe)")

	if fails == 0:
		print("BOSS TESTS: ALLE OK")
	else:
		print("BOSS TESTS: %d FEHLER" % fails)
	world.queue_free()
	await process_frame
	quit(1 if fails > 0 else 0)

func _all_not_lane(lanes: Array, boss_lane: int) -> bool:
	for summon_lane in lanes:
		if int(summon_lane) == boss_lane:
			return false
	return true
