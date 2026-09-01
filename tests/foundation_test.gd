extends SceneTree
## Phase-1-Fundament: Lifecycle, Safe Area, UI-Schichtung, Gegnerankunft und RNG.

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

	# --- Zustandsmodell: Pause ist explizit und blockiert Mutationen ---
	var game := GameManager.new()
	world.add_child(game)
	var state_events: Array[int] = []
	var pause_events: Array[bool] = []
	game.state_changed.connect(func(value: int): state_events.append(value))
	game.pause_changed.connect(func(value: bool): pause_events.append(value))
	_check(game.state == GameManager.State.START, "GameManager beginnt im START-Zustand")
	game.start_run()
	_check(game.is_running(), "START wechselt explizit zu RUNNING")
	_check(game.pause_run(), "RUNNING kann pausiert werden")
	_check(game.state == GameManager.State.PAUSED and game.is_paused(), "Pause hat eigenen Zustand")
	game.add_score(50)
	_check(game.score == 0, "Pause blockiert Score-Mutationen")
	_check(game.resume_run() and game.is_running(), "Pause kann fortgesetzt werden")
	_check(state_events == [GameManager.State.RUNNING, GameManager.State.PAUSED, GameManager.State.RUNNING], "State-Signale sind vollständig")
	_check(pause_events == [true, false], "Pause-Signale sind symmetrisch")
	game.damage_player(GameConfig.MAX_HEALTH)
	_check(not game.resume_run(), "Game Over kann nicht versehentlich fortgesetzt werden")
	game.reset()
	_check(game.is_running() and game.player_hp == GameConfig.MAX_HEALTH, "Reset stellt RUNNING und HP wieder her")

	# --- Safe-Area-Abbildung: Geräte-Inset plus Mindestpolster ---
	var viewport := Vector2(1080, 1920)
	var safe := UiLayout.content_rect(
		viewport,
		Vector2(1080, 1920),
		Rect2(Vector2(30, 90), Vector2(1020, 1740))
	)
	_check(safe.position.x == GameConfig.UI_SAFE_SIDE, "seitliche Safe Area nutzt Mindestpolster")
	_check(safe.position.y == 90.0, "größeres Geräte-Top-Inset bleibt erhalten")
	_check(safe.end.y == 1830.0, "Geräte-Bottom-Inset wird abgebildet")
	_check(safe.size.x > 0.0 and safe.size.y > 0.0, "Safe-Area-Inhaltsfläche bleibt gültig")

	# --- Deterministischer Spawn-Zufall für reproduzierbare QA-Runs ---
	var spawner_a := SpawnManager.new()
	var spawner_b := SpawnManager.new()
	spawner_a.setup(world, 424242)
	spawner_b.setup(world, 424242)
	var sequence_a: Array[String] = []
	var sequence_b: Array[String] = []
	for i in 12:
		sequence_a.append("%d:%s" % [spawner_a._roll_lane(), spawner_a._roll_upgrade_type()])
		sequence_b.append("%d:%s" % [spawner_b._roll_lane(), spawner_b._roll_upgrade_type()])
	_check(sequence_a == sequence_b, "gleicher Seed erzeugt gleiche Spawnfolge")

	# --- Gegner melden die Spielerlinie genau einmal ---
	var enemy := Enemy.new()
	enemy.configure(1, 50, 0.0)
	world.add_child(enemy)
	var reached := [0]
	enemy.reached_bottom.connect(func(_obj): reached[0] += 1)
	var reach_y := enemy.get_viewport_rect().size.y * GameConfig.ENEMY_REACH_Y_RATIO
	enemy.position.y = reach_y - 1.0
	enemy._physics_process(0.0)
	_check(reached[0] == 0, "vor der Spielerlinie entsteht kein Schaden-Signal")
	enemy.position.y = reach_y
	enemy._physics_process(0.0)
	enemy._physics_process(0.0)
	_check(reached[0] == 1, "Spielerlinie wird genau einmal gemeldet")

	# --- Ergebnis- und Pause-UI liegen garantiert über HUD/Welt ---
	var game_over := GameOverUI.new()
	var complete := LevelCompleteUI.new()
	var pause := PauseUI.new()
	world.add_child(game_over)
	world.add_child(complete)
	world.add_child(pause)
	await process_frame
	_check(game_over.layer == UiLayout.MODAL_LAYER, "Game Over liegt auf Modal-Ebene")
	_check(complete.layer == UiLayout.MODAL_LAYER, "Level Complete liegt auf Modal-Ebene")
	_check(pause.layer == UiLayout.PAUSE_LAYER, "Pause liegt zwischen HUD und Modals")
	_check(game_over._root != null and game_over._safe_margin != null, "Game Over besitzt responsive Safe-Area-Struktur")
	game_over.show_stats(120, 8)
	_check(game_over.visible and game_over._score_label.text == "SCORE: 120", "Game-Over-Statistik wird sichtbar aktualisiert")
	pause.show_paused(true)
	_check(pause.visible, "Pause-Overlay ist explizit schaltbar")

	if fails == 0:
		print("FOUNDATION TESTS: ALLE OK")
	else:
		print("FOUNDATION TESTS: %d FEHLER" % fails)
	spawner_a.free()
	spawner_b.free()
	world.queue_free()
	await process_frame
	quit(1 if fails > 0 else 0)
