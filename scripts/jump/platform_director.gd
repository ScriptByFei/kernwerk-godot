class_name PlatformDirector
extends RefCounted

var active_positions: Array[Vector2] = []
var active_platform_count: int:
	get:
		return active_positions.size()

var _platform_parent: Node
var _active_platforms: Array[JumpPlatform] = []
var _random := RandomNumberGenerator.new()
var _last_position := Vector2.ZERO

func _init(run_seed: int = JumpConfig.PLATFORM_RUN_SEED) -> void:
	_random.seed = run_seed

func initialize(platform_parent: Node, initial_positions: Array[Vector2]) -> void:
	_clear_platforms()
	_platform_parent = platform_parent
	for position in initial_positions:
		_add_platform(position)
	_last_position = active_positions.back()

func maintain(visible_top_y: float, visible_bottom_y: float) -> void:
	while _last_position.y > visible_top_y - JumpConfig.PLATFORM_LOOKAHEAD:
		_add_platform(_next_position())
	_remove_platforms_below(visible_bottom_y + JumpConfig.PLATFORM_CLEANUP_MARGIN)

func _next_position() -> Vector2:
	var horizontal_offset := _random.randf_range(-JumpConfig.PLATFORM_MAX_HORIZONTAL_STEP, JumpConfig.PLATFORM_MAX_HORIZONTAL_STEP)
	return Vector2(
		clampf(_last_position.x + horizontal_offset, JumpConfig.PLATFORM_MIN_CENTER_X, JumpConfig.PLATFORM_MAX_CENTER_X),
		_last_position.y - JumpConfig.PLATFORM_VERTICAL_GAP
	)

func _add_platform(position: Vector2) -> void:
	var platform := JumpPlatform.new()
	platform.position = position
	platform.add_to_group("platforms")
	_platform_parent.add_child(platform)
	_active_platforms.append(platform)
	active_positions.append(position)
	_last_position = position

func _remove_platforms_below(cleanup_y: float) -> void:
	while not active_positions.is_empty() and (active_positions.front().y > cleanup_y or active_positions.size() > JumpConfig.MAX_ACTIVE_PLATFORMS):
		_active_platforms.pop_front().queue_free()
		active_positions.pop_front()

func _clear_platforms() -> void:
	for platform in _active_platforms:
		platform.queue_free()
	_active_platforms.clear()
	active_positions.clear()
