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
var _run_seed: int

func _init(run_seed: int = JumpConfig.PLATFORM_RUN_SEED) -> void:
	_run_seed = run_seed
	_random.seed = run_seed

func initialize(platform_parent: Node, initial_positions: Array[Vector2]) -> void:
	_clear_platforms()
	_random.seed = _run_seed
	_platform_parent = platform_parent
	for position in initial_positions:
		_add_platform(position)
	_last_position = active_positions.back()

func maintain(visible_top_y: float, visible_bottom_y: float, difficulty: int = 0) -> void:
	var clamped_difficulty := clampi(difficulty, 0, JumpConfig.MAX_DIFFICULTY)
	while _last_position.y > visible_top_y - JumpConfig.PLATFORM_LOOKAHEAD:
		var previous := _last_position
		var next_position := _next_position(clamped_difficulty)
		# Der Zweig wird ZWISCHEN Vorgaenger und naechster Sprosse eingehaengt und
		# verschiebt die Hauptroute nicht: `advance` bleibt fuer ihn aus, sonst
		# waere die sichere Route nach der ersten Abzweigung eine Sackgasse.
		_add_platform(next_position, _roll_variant())
		if _random.randf() < JumpConfig.RISKY_CHANCE:
			var branch := _branch_between(previous, next_position, clamped_difficulty)
			if branch.is_finite():
				_add_platform(branch, JumpPlatform.Variant.RISKY, false)
	_remove_platforms_below(visible_bottom_y + JumpConfig.PLATFORM_CLEANUP_MARGIN)

func _roll_variant() -> JumpPlatform.Variant:
	var roll := _random.randi_range(0, 9)
	if roll < 2:
		return JumpPlatform.Variant.NARROW
	if roll < 4:
		return JumpPlatform.Variant.RESONANCE_FOCUS
	return JumpPlatform.Variant.STANDARD

## Position der riskanten Abzweigung. Sie liegt zwischen Vorgaenger und naechster
## Sprosse und muss von BEIDEN aus erreichbar sein — sonst gaebe es keine Wahl,
## sondern eine Falle. Der Abstand wird deshalb geprueft, nicht gewuerfelt.
func _branch_between(previous: Vector2, next_position: Vector2, difficulty: int) -> Vector2:
	var step: float = minf(get_horizontal_step(difficulty), JumpConfig.PLATFORM_MAX_HORIZONTAL_STEP)
	var side: float = 1.0 if previous.x <= 540.0 else -1.0
	var candidates: Array[float] = [side, -side]
	for direction in candidates:
		var x: float = previous.x + direction * step * JumpConfig.RISKY_MIN_GAP_FACTOR
		if x < JumpConfig.PLATFORM_MIN_CENTER_X or x > JumpConfig.PLATFORM_MAX_CENTER_X:
			continue
		if absf(x - next_position.x) > step:
			continue
		return Vector2(x, next_position.y - JumpConfig.RISKY_LIFT)
	return Vector2(INF, INF)

func _next_position(difficulty: int = 0) -> Vector2:
	var horizontal_step := get_horizontal_step(difficulty)
	var horizontal_offset := _random.randf_range(-horizontal_step, horizontal_step)
	return Vector2(
		clampf(_last_position.x + horizontal_offset, JumpConfig.PLATFORM_MIN_CENTER_X, JumpConfig.PLATFORM_MAX_CENTER_X),
		_last_position.y - get_vertical_gap(difficulty)
	)

func get_vertical_gap(difficulty: int = 0) -> float:
	var clamped_difficulty := clampi(difficulty, 0, JumpConfig.MAX_DIFFICULTY)
	return JumpConfig.PLATFORM_VERTICAL_GAP + clamped_difficulty * JumpConfig.DIFFICULTY_VERTICAL_BONUS

func get_horizontal_step(difficulty: int = 0) -> float:
	var clamped_difficulty := clampi(difficulty, 0, JumpConfig.MAX_DIFFICULTY)
	return JumpConfig.PLATFORM_MAX_HORIZONTAL_STEP + clamped_difficulty * JumpConfig.DIFFICULTY_HORIZONTAL_BONUS

func _add_platform(position: Vector2, variant := JumpPlatform.Variant.STANDARD, advance := true) -> void:
	var platform := JumpPlatform.new()
	platform.configure_variant(variant)
	platform.position = position
	platform.add_to_group("platforms")
	_platform_parent.add_child(platform)
	_active_platforms.append(platform)
	active_positions.append(position)
	if advance:
		_last_position = position

func _remove_platforms_below(cleanup_y: float) -> void:
	while not active_positions.is_empty() and (active_positions.front().y > cleanup_y or active_positions.size() > JumpConfig.MAX_ACTIVE_PLATFORMS):
		_active_platforms.pop_front().queue_free()
		active_positions.pop_front()

func _clear_platforms() -> void:
	for platform in _active_platforms:
		# Retry occurs in process, outside the physics query: immediately detach
		# old colliders before creating the new route, then defer destruction.
		if is_instance_valid(platform):
			platform.get_parent().remove_child(platform)
			platform.queue_free()
	_active_platforms.clear()
	active_positions.clear()
