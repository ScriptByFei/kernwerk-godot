extends SceneTree

const Game = preload("res://scripts/game/game.gd")
var failures := 0
var checks := 0

func _init() -> void:
	_run.call_deferred()

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + description)

func _run() -> void:
	# Dynamic calls deliberately produce an assertion failure on the baseline,
	# rather than a parser failure, before the implementation exists.
	var config := JumpConfig.new()
	_check(config.has_method("classify_landing"), "landing quality contract exists")
	if not config.has_method("classify_landing"):
		print("CORE POLISH RED: landing quality contract missing")
		quit(1)
		return
	for width in [120.0, 240.0, 360.0]:
		for side in [-1.0, 1.0]:
			for boundary in [0.08, 0.22]:
				var expected := 2 if boundary == 0.08 else 1
				_check(config.call("classify_landing", side * width * boundary, width) == expected, "inclusive edge width=%s boundary=%s" % [width,boundary])
				_check(config.call("classify_landing", side * (width * boundary + 0.001), width) == expected - 1, "outside edge width=%s boundary=%s" % [width,boundary])
		_check(config.call("classify_landing", 0.0, width) == 2, "exact center perfect")
	_check(config.call("classify_landing", 0.0, 0.0) == 0, "invalid width is normal")
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second = hz
		for offset in [0.0, 36.0, 90.0]:
			await _physical_contact(hz, offset)
	Engine.physics_ticks_per_second = 60
	await _fast_diagonal_contact()
	await _bonus_once_per_platform()
	await _airborne_touch_reversal()
	await _camera_monotonic()
	await _shutdown_frozen()
	await _deterministic_reset()
	await _retry()
	print("CORE POLISH: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _physical_contact(hz: int, offset: float) -> void:
	var world := Node2D.new()
	var platform := JumpPlatform.new()
	platform.position = Vector2(540, 500)
	world.add_child(platform)
	var jumper := Jumper.new()
	jumper.position = Vector2(540 + offset, 400)
	jumper.velocity.y = 600
	world.add_child(jumper)
	var stats := {"bounce":0,"land":0,"quality":-1,"instant":false}
	jumper.bounced.connect(func(): stats.bounce += 1)
	jumper.connect("landed", func(_p, quality, _bonus):
		stats.land += 1
		stats.quality = quality
		stats.instant = jumper.velocity.y < 0 and jumper._reactor_visual.animation == &"land")
	root.add_child(world)
	for frame in ceili(hz * 0.3):
		await physics_frame
	_check(stats.bounce == 1 and stats.land == 1, "one real bounce/contact %dHz offset=%s" % [hz,offset])
	_check(stats.instant, "impact animation and launch available in contact callback")
	_check(stats.quality == (2 if offset == 0 else (1 if offset == 36 else 0)), "real collision quality %dHz offset=%s" % [hz,offset])
	_check(platform.get("impact_count") == 1, "one platform impact")
	_check(not jumper.bounce_from(platform, false), "duplicate rising contact rejected")
	print("CONTACT physics=%d offset=%s bounce=%s land=%s quality=%s" % [hz,offset,stats.bounce,stats.land,stats.quality])
	world.queue_free()
	await process_frame

func _fast_diagonal_contact() -> void:
	# A fast lateral landing must classify by the core center at the moment of
	# first top contact (reconstructed from pre-slide position + travel), not by
	# the end-of-tick position after move_and_slide continues sliding.
	var world := Node2D.new()
	var platform := JumpPlatform.new()
	platform.position = Vector2(540, 500)
	world.add_child(platform)
	var jumper := Jumper.new()
	jumper.position = Vector2(540 + 36.0, 400)
	jumper.velocity = Vector2(420.0, 600)
	world.add_child(jumper)
	var stats := {"quality": -1, "impact_x": 0.0, "final_x": 0.0}
	jumper.connect("landed", func(_p, quality, _bonus):
		stats.quality = quality
		stats.impact_x = platform.get("_impact_local_x"))
	root.add_child(world)
	for frame in 30:
		await physics_frame
	stats.final_x = jumper.global_position.x
	# Entry at 36px from center is RESONANCE (0.22*240=52.8). Sliding right
	# toward center must NOT upgrade it to PERFECT.
	_check(stats.quality == 1, "fast diagonal entry at 36px stays RESONANCE (impact_x=%.1f final_x=%.1f)" % [stats.impact_x, stats.final_x])
	_check(absf(stats.impact_x - 36.0) < 6.0, "impact x reflects entry, not post-slide x (impact_x=%.1f final_x=%.1f)" % [stats.impact_x, stats.final_x])
	_check(stats.final_x > stats.impact_x, "jumper actually slid horizontally after contact")
	world.queue_free()
	await process_frame

func _bonus_once_per_platform() -> void:
	var platform := JumpPlatform.new()
	platform.platform_size = Vector2(240.0, 34.0)
	var first := platform.claim_landing_bonus(JumpConfig.LandingQuality.PERFECT, true)
	var second := platform.claim_landing_bonus(JumpConfig.LandingQuality.PERFECT, true)
	_check(first == JumpConfig.LANDING_SCORE_BONUSES[JumpConfig.LandingQuality.PERFECT], "first perfect landing awards the configured bonus")
	_check(second == 0, "bonus cannot be farmed on the same platform")
	_check(platform.claim_landing_bonus(JumpConfig.LandingQuality.NORMAL, false) == 0, "disabled bonuses award nothing")
	platform.free()

func _airborne_touch_reversal() -> void:
	# Late-descent authority: a target left of the current motion must brake and
	# reverse within a bounded time, without snapping position.
	var jumper := Jumper.new()
	root.add_child(jumper)
	await process_frame
	jumper.velocity = Vector2(1000.0, 0.0)
	jumper.set_horizontal_target(jumper.global_position.x - 200.0)
	var reversed := false
	for step in 40:
		jumper.apply_horizontal_steering(1.0 / 60.0)
		if jumper.velocity.x < 0.0:
			reversed = true
			break
	_check(reversed, "late-descent target reverses horizontal velocity")
	_check(jumper.global_position.x < 1000.0, "reversal does not teleport (position bounded)")
	jumper.queue_free()
	await process_frame

func _camera_monotonic() -> void:
	var world := Node2D.new()
	var target := CharacterBody2D.new()
	world.add_child(target)
	var camera := VerticalCamera.new()
	camera.target = target
	world.add_child(camera)
	root.add_child(world)
	await process_frame
	var last_y := camera.global_position.y
	var monotonic := true
	# Simulate ascent then descent; camera must never move downward.
	for i in 60:
		target.global_position.y -= 20.0
		target.velocity = Vector2(0.0, -800.0)
		camera._physics_process(1.0 / 60.0)
		if camera.global_position.y > last_y + 0.001:
			monotonic = false
		last_y = camera.global_position.y
	for i in 60:
		target.global_position.y += 30.0
		target.velocity = Vector2(0.0, 800.0)
		camera._physics_process(1.0 / 60.0)
		if camera.global_position.y > last_y + 0.001:
			monotonic = false
		last_y = camera.global_position.y
	_check(monotonic, "camera never moves downward through ascent and descent")
	world.queue_free()
	await process_frame

func _shutdown_frozen() -> void:
	var jumper := Jumper.new()
	root.add_child(jumper)
	await process_frame
	jumper._reactor_visual.play()
	jumper.shutdown()
	var frame_before := jumper._reactor_visual.frame
	await process_frame
	await process_frame
	_check(not jumper.is_physics_processing(), "shutdown disables physics")
	_check(not jumper.is_processing(), "shutdown disables process")
	_check(jumper._reactor_visual.frame == frame_before, "shutdown freezes the reactor animation")
	jumper.queue_free()
	await process_frame

func _deterministic_reset() -> void:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game._start_game()
	game._start_tween.pause()
	game._start_tween.custom_step(JumpConfig.START_TOTAL + 0.01)
	await process_frame
	game.jumper.position.y = game.camera.position.y + JumpConfig.FALL_DEATH_MARGIN + 1
	game._check_game_over()
	await create_timer(JumpConfig.RESTART_DELAY + 0.05).timeout
	_check(game._phase == game.Phase.PLAYING, "deterministic reset reaches PLAYING")
	_check(game.platform_director.active_positions.slice(0, JumpConfig.PLATFORM_LAYOUT.size()) == JumpConfig.PLATFORM_LAYOUT, "retry restores the seeded initial route")
	_check(game.jumper.global_position.x == 540.0, "retry restores the start x")
	_check(game.jumper.global_position.y <= game.START_Y, "retry launches upward from the start platform (y=%.1f)" % game.jumper.global_position.y)
	game.queue_free()
	await process_frame

func _retry() -> void:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game._start_game()
	game._start_tween.pause()
	game._start_tween.custom_step(JumpConfig.START_TOTAL + 0.01)
	await process_frame
	for run in 5:
		game.jumper.position.y = game.camera.position.y + JumpConfig.FALL_DEATH_MARGIN + 1
		game._check_game_over()
		_check(game.is_game_over and not game.jumper.is_physics_processing(), "death freezes physics")
		await create_timer(JumpConfig.RESTART_DELAY + 0.05).timeout
		_check(game._phase == game.Phase.PLAYING and not game.is_game_over, "automatic retry stays PLAYING")
		_check(not is_instance_valid(game.start_menu), "death retry never restores menu")
		_check(not game.jumper.has_horizontal_target, "retry clears steering")
		_check(game.platform_director.active_platform_count <= JumpConfig.MAX_ACTIVE_PLATFORMS, "retry bounded platforms")
	game.queue_free()
	await process_frame
