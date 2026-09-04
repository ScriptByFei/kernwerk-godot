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

	jumper.set_horizontal_intent(1.0)
	jumper.velocity.x = 0.0
	jumper.apply_horizontal_steering(10.0)
	_check(jumper.velocity.x == JumpConfig.MAX_HORIZONTAL_SPEED, "horizontal steering is speed-capped")

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

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ✓ " + description)
		return
	failures += 1
	print("  ✗ " + description)
