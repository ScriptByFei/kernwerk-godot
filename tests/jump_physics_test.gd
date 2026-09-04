extends SceneTree

const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const Jumper = preload("res://scripts/jump/jumper.gd")
const Platform = preload("res://scripts/jump/platform.gd")

var failures := 0

func _init() -> void:
	var jumper := Jumper.new()
	var platform := Platform.new()

	jumper.velocity = Vector2.ZERO
	jumper.apply_gravity(0.5)
	_check(jumper.velocity.y == JumpConfig.GRAVITY * 0.5, "gravity accelerates a resting jumper downward")

	jumper.velocity.y = 240.0
	_check(jumper.bounce_from(platform, false), "descending platform contact bounces")
	_check(jumper.velocity.y < 0.0, "descending bounce launches upward")
	_check(not jumper.bounce_from(platform, false), "a bounce cannot repeat while rising")
	await _check_physical_platform_bounce()

	jumper.velocity.y = -240.0
	_check(not jumper.bounce_from(platform, false), "rising platform contact never bounces")
	_check(
		JumpConfig.BASE_BOUNCE_SPEED * JumpConfig.BASE_BOUNCE_SPEED / (2.0 * JumpConfig.GRAVITY) >= 540.0,
		"base bounce reaches at least 540px"
	)

	jumper.set_horizontal_intent(1.0)
	jumper.velocity.x = 0.0
	jumper.apply_horizontal_steering(10.0)
	_check(jumper.velocity.x == JumpConfig.MAX_HORIZONTAL_SPEED, "horizontal steering is speed-capped")

	jumper.position.x = 540.0
	jumper.velocity.x = 0.0
	jumper.set_horizontal_target(360.0)
	jumper.apply_horizontal_steering(10.0)
	_check(jumper.velocity.x == -JumpConfig.MAX_HORIZONTAL_SPEED, "left target produces capped leftward motion")

	jumper.velocity.x = 0.0
	jumper.set_horizontal_target(720.0)
	jumper.apply_horizontal_steering(10.0)
	_check(jumper.velocity.x == JumpConfig.MAX_HORIZONTAL_SPEED, "right target produces capped rightward motion")
	_check(JumpConfig.MAX_HORIZONTAL_SPEED == 1100.0, "horizontal target impulse uses the 1100px/s cap")

	jumper.velocity.x = 0.0
	jumper.set_horizontal_target(720.0)
	jumper.apply_horizontal_steering(0.1)
	_check(jumper.velocity.x >= 800.0, "short right target step reaches at least 800px/s")

	jumper.velocity.x = 0.0
	jumper.set_horizontal_target(360.0)
	jumper.apply_horizontal_steering(0.1)
	_check(jumper.velocity.x <= -800.0, "short left target step reaches at least 800px/s")

	jumper.velocity.x = 1000.0
	jumper.clear_horizontal_target()
	jumper.apply_horizontal_steering(0.1)
	_check(jumper.velocity.x == 0.0, "releasing input stops 1000px/s within 0.1 seconds")

	_check(JumpConfig.PLATFORM_LAYOUT.size() == 7, "platform route has exactly seven elements")
	for platform_index in range(JumpConfig.PLATFORM_LAYOUT.size() - 1):
		var current_platform: Vector2 = JumpConfig.PLATFORM_LAYOUT[platform_index]
		var next_platform: Vector2 = JumpConfig.PLATFORM_LAYOUT[platform_index + 1]
		_check(current_platform.y - next_platform.y == 300.0, "adjacent platforms are 300px apart vertically")

	jumper.velocity.x = 300.0
	jumper.set_horizontal_target(jumper.position.x)
	jumper.apply_horizontal_steering(10.0)
	_check(jumper.velocity.x == 0.0, "target at jumper position damps horizontal velocity to zero")
	await _check_rising_platform_pass_through()

	jumper.velocity.y = 240.0
	jumper.bounce_from(platform, true)
	_check(-jumper.velocity.y > JumpConfig.BASE_BOUNCE_SPEED, "overload bounce is higher than base bounce")
	_check(-jumper.velocity.y <= JumpConfig.MAX_BOUNCE_SPEED, "overload bounce respects the future cap")

	print("JUMP PHYSICS: ALLE OK" if failures == 0 else "JUMP PHYSICS: %d FEHLER" % failures)
	jumper.free()
	platform.free()
	quit(1 if failures > 0 else 0)

func _check_physical_platform_bounce() -> void:
	var world := Node2D.new()
	var physical_platform := Platform.new()
	var physical_jumper := Jumper.new()
	var bounce_count := [0]
	physical_platform.position = Vector2(540.0, 500.0)
	physical_jumper.position = Vector2(540.0, 400.0)
	physical_jumper.velocity.y = 600.0
	physical_jumper.bounced.connect(func(): bounce_count[0] += 1)
	world.add_child(physical_platform)
	world.add_child(physical_jumper)
	get_root().add_child(world)
	for _frame in 12:
		await physics_frame
	_check(bounce_count[0] == 1 and physical_jumper.velocity.y < 0.0, "descending CharacterBody2D collision produces one bounce")
	world.queue_free()
	await process_frame

func _check_rising_platform_pass_through() -> void:
	var world := Node2D.new()
	var physical_platform := Platform.new()
	var physical_jumper := Jumper.new()
	var bounce_count := [0]
	physical_platform.position = Vector2(540.0, 500.0)
	physical_jumper.position = Vector2(540.0, 650.0)
	physical_jumper.velocity.y = -1200.0
	physical_jumper.bounced.connect(func(): bounce_count[0] += 1)
	world.add_child(physical_platform)
	world.add_child(physical_jumper)
	get_root().add_child(world)
	for _frame in 24:
		await physics_frame
	_check(bounce_count[0] == 0 and physical_jumper.position.y < physical_platform.position.y, "rising CharacterBody2D passes through platform underside")
	world.queue_free()
	await process_frame

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ✓ " + description)
		return
	failures += 1
	print("  ✗ " + description)
