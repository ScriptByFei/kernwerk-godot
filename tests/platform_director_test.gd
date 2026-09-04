extends SceneTree

const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const PlatformDirector = preload("res://scripts/jump/platform_director.gd")

var failures := 0

func _init() -> void:
	await _test_initialization_and_generation()
	await _test_deterministic_generation()
	await _test_long_running_maintenance()
	print("PLATFORM DIRECTOR: ALLE OK" if failures == 0 else "PLATFORM DIRECTOR: %d FEHLER" % failures)
	quit(1 if failures > 0 else 0)

func _test_initialization_and_generation() -> void:
	var world := Node2D.new()
	get_root().add_child(world)
	var director := PlatformDirector.new(JumpConfig.PLATFORM_RUN_SEED)
	director.initialize(world, JumpConfig.PLATFORM_LAYOUT)
	await physics_frame
	_check(director.active_platform_count == JumpConfig.PLATFORM_LAYOUT.size(), "initialization creates every supplied starting ledge")
	_check(_has_only_jump_platforms(world), "initialization uses real JumpPlatform nodes")
	var initial_highest_y: float = director.active_positions.back().y
	director.maintain(0.0, 1920.0)
	_check(_has_one_way_collisions(world), "generated nodes retain one-way collisions")
	var generated_positions := director.active_positions.slice(7)
	_check(not generated_positions.is_empty(), "maintenance generates ledges above the existing highest ledge")
	_check(generated_positions.back().y < initial_highest_y, "generated ledges extend above the starting route")
	var generated_count := director.active_platform_count
	director.maintain(0.0, 1920.0)
	_check(director.active_platform_count == generated_count, "unchanged camera bounds do not duplicate ledges")
	_check(_has_valid_generated_transitions(director.active_positions), "generated ledges preserve safe vertical and horizontal transitions")
	world.queue_free()
	await process_frame

func _test_deterministic_generation() -> void:
	var first_world := Node2D.new()
	var second_world := Node2D.new()
	get_root().add_child(first_world)
	get_root().add_child(second_world)
	var first_director := PlatformDirector.new(JumpConfig.PLATFORM_RUN_SEED)
	var second_director := PlatformDirector.new(JumpConfig.PLATFORM_RUN_SEED)
	first_director.initialize(first_world, JumpConfig.PLATFORM_LAYOUT)
	second_director.initialize(second_world, JumpConfig.PLATFORM_LAYOUT)
	first_director.maintain(-3600.0, -1680.0)
	second_director.maintain(-3600.0, -1680.0)
	_check(first_director.active_positions == second_director.active_positions, "equal seeds and routes generate identical ordered positions")
	first_world.queue_free()
	second_world.queue_free()
	await process_frame

func _test_long_running_maintenance() -> void:
	var world := Node2D.new()
	get_root().add_child(world)
	var director := PlatformDirector.new(JumpConfig.PLATFORM_RUN_SEED)
	director.initialize(world, JumpConfig.PLATFORM_LAYOUT)
	for route_step in 80:
		var visible_top_y := -300.0 * route_step
		director.maintain(visible_top_y, visible_top_y + 1920.0)
		_check(_has_lookahead_platform(director.active_positions, visible_top_y), "step %d keeps a platform in the lookahead region" % route_step)
		_check(director.active_platform_count <= JumpConfig.MAX_ACTIVE_PLATFORMS, "step %d stays within the active-platform ceiling" % route_step)
	world.queue_free()
	await process_frame

func _has_only_jump_platforms(world: Node) -> bool:
	for child in world.get_children():
		if not child is JumpPlatform:
			return false
	return true

func _has_one_way_collisions(world: Node) -> bool:
	for platform in world.get_children():
		var collision := platform.get_children().filter(func(child: Node): return child is CollisionShape2D).front() as CollisionShape2D
		if collision == null or not collision.one_way_collision:
			return false
	return true

func _has_valid_generated_transitions(positions: Array[Vector2]) -> bool:
	for platform_index in range(6, positions.size() - 1):
		var current_position := positions[platform_index]
		var next_position := positions[platform_index + 1]
		if current_position.y - next_position.y != JumpConfig.PLATFORM_VERTICAL_GAP:
			return false
		if next_position.x < JumpConfig.PLATFORM_SIZE.x * 0.5 or next_position.x > 1080.0 - JumpConfig.PLATFORM_SIZE.x * 0.5:
			return false
		if absf(next_position.x - current_position.x) > 280.0:
			return false
	return true

func _has_lookahead_platform(positions: Array[Vector2], visible_top_y: float) -> bool:
	for position in positions:
		if position.y <= visible_top_y - JumpConfig.PLATFORM_LOOKAHEAD:
			return true
	return false

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ✓ " + description)
		return
	failures += 1
	print("  ✗ " + description)
