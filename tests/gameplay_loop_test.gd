extends SceneTree

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const PlatformDirector = preload("res://scripts/jump/platform_director.gd")

var failures := 0

func _init() -> void:
	await _test_gameplay_loop()
	await _test_platform_director_difficulty()
	print("GAMEPLAY LOOP: ALLE OK" if failures == 0 else "GAMEPLAY LOOP: %d FEHLER" % failures)
	quit(1 if failures > 0 else 0)

func _test_gameplay_loop() -> void:
	var game := Game.new()
	get_root().add_child(game)
	await process_frame
	game.jumper.set_physics_process(false)
	game.camera.set_physics_process(false)

	_check(game.score == 0, "a new run starts at score zero")
	game.jumper.global_position.y = game.START_Y - 100.0
	game._update_score()
	_check(game.score == 10, "score increases by one point per ten pixels of height")
	_check(game.difficulty == 0, "difficulty stays at zero before the first score step")

	game.jumper.global_position.y = game.START_Y - 1000.0
	game._update_score()
	_check(game.score == 100, "score reaches 100 at 1000 pixels of height")
	_check(game.difficulty == 1, "difficulty rises after one difficulty score step")

	game.camera.global_position = JumpConfig.CAMERA_START
	game.jumper.global_position.y = game.camera.global_position.y + JumpConfig.FALL_DEATH_MARGIN + 1.0
	game._check_game_over()
	_check(game.is_game_over, "falling below the camera margin triggers game over")
	_check(is_equal_approx(game._restart_timer, JumpConfig.RESTART_DELAY), "game over starts the configured restart timer")

	game._restart()
	game.set_process(false)
	game.jumper.set_physics_process(false)
	game.camera.set_physics_process(false)
	await process_frame
	_check(not game.is_game_over, "restart clears game over")
	_check(game.score == 0 and game.difficulty == 0, "restart resets score and difficulty")
	_check(game.jumper.global_position == Vector2(540.0, game.START_Y), "restart restores the jumper start position")
	_check(game.camera.global_position == Vector2(540.0, game.START_Y + JumpConfig.CAMERA_LEAD), "restart restores the camera start position")
	_check(game.platform_director.active_positions == JumpConfig.PLATFORM_LAYOUT, "restart restores the initial platform route")

	game.queue_free()
	await process_frame

func _test_platform_director_difficulty() -> void:
	var base_world := Node2D.new()
	var hard_world := Node2D.new()
	get_root().add_child(base_world)
	get_root().add_child(hard_world)
	var base_director := PlatformDirector.new(JumpConfig.PLATFORM_RUN_SEED)
	var hard_director := PlatformDirector.new(JumpConfig.PLATFORM_RUN_SEED)
	base_director.initialize(base_world, JumpConfig.PLATFORM_LAYOUT)
	hard_director.initialize(hard_world, JumpConfig.PLATFORM_LAYOUT)
	base_director.maintain(-1800.0, 120.0, 0)
	hard_director.maintain(-1800.0, 120.0, 2)

	var base_gap := base_director.active_positions[7].y - base_director.active_positions[8].y
	var hard_gap := hard_director.active_positions[7].y - hard_director.active_positions[8].y
	_check(base_gap == JumpConfig.PLATFORM_VERTICAL_GAP, "difficulty zero keeps the base vertical gap")
	_check(hard_gap == JumpConfig.PLATFORM_VERTICAL_GAP + 2.0 * JumpConfig.DIFFICULTY_VERTICAL_BONUS, "difficulty adds the configured vertical bonus")
	_check(
		absf(hard_director.active_positions[7].x - hard_director.active_positions[6].x) <= JumpConfig.PLATFORM_MAX_HORIZONTAL_STEP + 2.0 * JumpConfig.DIFFICULTY_HORIZONTAL_BONUS,
		"difficulty expands the horizontal transition limit"
	)
	_check(hard_director.get_vertical_gap(99) == JumpConfig.PLATFORM_VERTICAL_GAP + JumpConfig.MAX_DIFFICULTY * JumpConfig.DIFFICULTY_VERTICAL_BONUS, "difficulty is capped at the configured maximum")

	base_world.queue_free()
	hard_world.queue_free()
	await process_frame

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ✓ " + description)
		return
	failures += 1
	print("  ✗ " + description)
