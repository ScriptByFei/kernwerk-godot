extends SceneTree
## Drohne (neuer Gegnertyp): Archetype-Definition, Spawn-Patterns, Visual.

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

	# --- Archetype-Definition ---
	var drone := EnemyArchetypeData.get_definition(EnemyArchetypeData.DRONE)
	_check(not drone.is_empty(), "Drohnen-Definition existiert")
	_check(float(drone["hp_multiplier"]) < 1.0, "Drohne hat weniger HP als Grunt")
	_check(float(drone["speed_multiplier"]) > 1.0, "Drohne ist schneller als Grunt")
	_check(int(drone["score_reward"]) > 0, "Drohne vergibt Score")
	_check(EnemyArchetypeData.is_regular_type(EnemyArchetypeData.DRONE), "Drohne ist regulärer Gegnertyp")

	# --- Enemy-Konfiguration ---
	var enemy := Enemy.new()
	world.add_child(enemy)
	enemy.configure(1, 40, 180.0, false, EnemyArchetypeData.DRONE)
	_check(enemy.enemy_type == EnemyArchetypeData.DRONE, "Enemy übernimmt Drohnen-Typ")
	_check(enemy.score_reward == int(drone["score_reward"]), "Drohnen-Score wird durchgereicht")
	_check(enemy.max_hp == 40, "Drohnen-HP wird übernommen")
	_check(enemy.is_boss == false, "Drohne ist kein Boss")
	# Visual: AnimatedSprite2D mit drone_sheet (Sheet existiert nach Pipeline-Lauf)
	var sprite := enemy.get_node_or_null("Sprite")
	_check(sprite != null, "Drohne hat ein Sprite")
	if sprite is AnimatedSprite2D:
		_check(sprite.sprite_frames.get_frame_count("idle") == 2, "Drohnen-Sheet hat 2 Idle-Frames")
	enemy.queue_free()

	# --- Spawn-Patterns ---
	var wave_three := SpawnPatternData.patterns_for_wave(3)
	_check(_contains_type(wave_three, EnemyArchetypeData.DRONE), "Drohne startet in Welle 3")
	var wave_two := SpawnPatternData.patterns_for_wave(2)
	_check(not _contains_type(wave_two, EnemyArchetypeData.DRONE), "Drohne ist in Welle 2 gesperrt")
	for pattern in SpawnPatternData.PATTERNS:
		_check(SpawnPatternData.is_fair(pattern), "%s ist fair" % pattern["id"])

	# --- Spawn via SpawnManager ---
	var spawner := SpawnManager.new()
	world.add_child(spawner)
	spawner.setup(world, 1234)
	spawner.set_wave_params(2.3, 0.3, 1.0, 1.0, 3)
	var drone_intro := {}
	for pattern in SpawnPatternData.PATTERNS:
		if pattern["id"] == "drone_intro":
			drone_intro = pattern
	_check(not drone_intro.is_empty(), "Pattern drone_intro existiert")
	_check(EnemyArchetypeData.DRONE in drone_intro["slots"], "drone_intro enthält eine Drohne")
	_check(SpawnPatternData.enemy_count(drone_intro["slots"]) == 1, "drone_intro hat genau einen Gegner")
	spawner._prepare_next_pattern()
	spawner._spawn_pending_pattern()
	var drone_spawned := false
	for child in world.get_children():
		if child is Enemy and child.enemy_type == EnemyArchetypeData.DRONE:
			drone_spawned = true
	_check(drone_spawned, "SpawnManager erzeugt Drohnen aus dem Pattern")

	if fails == 0:
		print("DRONE TESTS: ALLE OK")
	else:
		print("DRONE TESTS: %d FEHLER" % fails)
	world.queue_free()
	await process_frame
	quit(1 if fails > 0 else 0)

func _contains_type(patterns: Array[Dictionary], enemy_type: String) -> bool:
	for pattern in patterns:
		if enemy_type in pattern["slots"]:
			return true
	return false
