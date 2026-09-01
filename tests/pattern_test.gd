extends SceneTree
## Phase-2-Fundament: faire Reihen, Rollen, Vorwarnung und deterministische Auswahl.

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

	# Jede definierte Reihe muss drei Lanes und eine nicht-feindliche Wahl lassen.
	for pattern in SpawnPatternData.PATTERNS:
		_check(SpawnPatternData.is_fair(pattern), "%s ist fair" % pattern["id"])
	var wave_one := SpawnPatternData.patterns_for_wave(1)
	var wave_one_is_calm := true
	for pattern in wave_one:
		wave_one_is_calm = wave_one_is_calm and SpawnPatternData.enemy_count(pattern["slots"]) == 1
	_check(wave_one_is_calm, "Welle 1 enthält höchstens einen Gegner pro Reihe")
	_check(not _contains_type(wave_one, EnemyArchetypeData.RUNNER), "Runner ist in Welle 1 gesperrt")
	_check(_contains_type(SpawnPatternData.patterns_for_wave(2), EnemyArchetypeData.RUNNER), "Runner startet in Welle 2")
	_check(_contains_type(SpawnPatternData.patterns_for_wave(3), EnemyArchetypeData.TANK), "Tank startet in Welle 3")

	# Rollenwerte übersetzen die Silhouette in echtes Gameplay.
	var grunt := EnemyArchetypeData.get_definition(EnemyArchetypeData.GRUNT)
	var runner := EnemyArchetypeData.get_definition(EnemyArchetypeData.RUNNER)
	var tank := EnemyArchetypeData.get_definition(EnemyArchetypeData.TANK)
	_check(float(runner["speed_multiplier"]) > float(grunt["speed_multiplier"]) and float(runner["hp_multiplier"]) < float(grunt["hp_multiplier"]), "Runner ist schneller und leichter")
	_check(float(tank["speed_multiplier"]) < float(grunt["speed_multiplier"]) and float(tank["hp_multiplier"]) > float(grunt["hp_multiplier"]), "Tank ist langsamer und zäher")
	_check(int(tank["score_reward"]) > int(runner["score_reward"]) and int(runner["score_reward"]) > int(grunt["score_reward"]), "Rollen besitzen gestaffelte Score-Werte")

	# Gleicher Seed ergibt dieselbe vollständige Muster- und Lane-Folge.
	var spawner_a := SpawnManager.new()
	var spawner_b := SpawnManager.new()
	spawner_a.setup(world, 90210)
	spawner_b.setup(world, 90210)
	spawner_a.set_wave_params(2.3, 0.3, 1.0, 1.0, 4)
	spawner_b.set_wave_params(2.3, 0.3, 1.0, 1.0, 4)
	var sequence_a: Array[String] = []
	var sequence_b: Array[String] = []
	for index in 20:
		var pattern_a := spawner_a._choose_pattern()
		var pattern_b := spawner_b._choose_pattern()
		sequence_a.append("%s:%s" % [pattern_a["id"], str(pattern_a["slots"])])
		sequence_b.append("%s:%s" % [pattern_b["id"], str(pattern_b["slots"])])
	_check(sequence_a == sequence_b, "Seed reproduziert Muster inklusive Lane-Verteilung")

	# Zwei-Stufen-Ablauf: erst Telegraph, dann exakt diese Reihe.
	var spawner := SpawnManager.new()
	world.add_child(spawner)
	spawner.setup(world, 77)
	spawner.set_wave_params(2.3, 0.3, 1.0, 1.0, 3)
	var warned := [0]
	var spawned := [0]
	spawner.pattern_telegraphed.connect(func(_id, _slots): warned[0] += 1)
	spawner.pattern_spawned.connect(func(_id, _slots): spawned[0] += 1)
	spawner._prepare_next_pattern()
	_check(warned[0] == 1 and not spawner._pending_pattern.is_empty(), "Muster wird vor dem Spawn angekündigt")
	_check(spawner._telegraph != null and spawner._telegraph.is_inside_tree(), "sichtbarer Telegraph hängt in der Welt")
	var expected_slots: Array = spawner._pending_pattern["slots"].duplicate()
	spawner._spawn_pending_pattern()
	_check(spawned[0] == 1 and spawner._pending_pattern.is_empty(), "angekündigte Reihe spawnt genau einmal")
	var found_by_lane := {}
	for child in world.get_children():
		if child is Enemy:
			found_by_lane[child.lane] = child.enemy_type
		elif child is UpgradeObject:
			found_by_lane[child.lane] = SpawnPatternData.UPGRADE
	var row_matches := true
	for lane in expected_slots.size():
		var token := str(expected_slots[lane])
		if token != SpawnPatternData.EMPTY:
			row_matches = row_matches and str(found_by_lane.get(lane, "missing")) == token
	_check(row_matches, "Spawnobjekte entsprechen angekündigten Lanes und Rollen")

	# Der Scorewert wird vom Gegnertyp bis zum zentralen GameManager durchgereicht.
	var manager := GameManager.new()
	world.add_child(manager)
	manager.start_run()
	manager.add_kill(int(tank["score_reward"]))
	_check(manager.kills == 1 and manager.score == 20, "Tank-Kill vergibt zentral 20 Punkte")

	if fails == 0:
		print("PATTERN TESTS: ALLE OK")
	else:
		print("PATTERN TESTS: %d FEHLER" % fails)
	spawner_a.free()
	spawner_b.free()
	world.queue_free()
	await process_frame
	quit(1 if fails > 0 else 0)

func _contains_type(patterns: Array[Dictionary], enemy_type: String) -> bool:
	for pattern in patterns:
		if enemy_type in pattern["slots"]:
			return true
	return false
