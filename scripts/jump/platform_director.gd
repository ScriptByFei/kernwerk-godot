class_name PlatformDirector
extends RefCounted

const Patterns = preload("res://scripts/jump/platform_patterns.gd")

var active_positions: Array[Vector2] = []
var active_platform_count: int:
	get:
		return active_positions.size()

var _platform_parent: Node
var _active_platforms: Array[JumpPlatform] = []
var _random := RandomNumberGenerator.new()
var _last_position := Vector2.ZERO
var _run_seed: int
## Laufende Pattern-Sequenz: Form, Laenge, Index der naechsten Sprosse und die
## einmal festgelegte Richtung. Sie wird erst geleert, wenn die Sequenz
## abgearbeitet ist — dadurch bleibt ein Abschnitt als Form erkennbar, statt bei
## jeder Sprosse neu zu wuerfeln.
var _pattern_kind: Patterns.Kind = Patterns.Kind.ZIGZAG
var _pattern_length := 0
var _pattern_index := 0
var _pattern_direction := 1.0
var _pattern_step := 0.0
## Zaehlt die zuletzt vergebene Schwierigkeit, damit ein Stufenwechsel die
## laufende Sequenz beendet: ein Pattern, das auf Stufe 2 begonnen hat, darf
## nicht mit den Schrittmassen von Stufe 4 weiterlaufen.
var _pattern_difficulty := -1

func _init(run_seed: int = JumpConfig.PLATFORM_RUN_SEED) -> void:
	_run_seed = run_seed
	_random.seed = run_seed

func initialize(platform_parent: Node, initial_positions: Array[Vector2]) -> void:
	_clear_platforms()
	_random.seed = _run_seed
	_pattern_length = 0
	_pattern_index = 0
	_pattern_difficulty = -1
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
		_add_platform(next_position, _variant_for_current())
		# Die Risikowahl ist der einzige Ort, an dem die riskante Abzweigung
		# PLANMAESSIG angeboten wird; ueberall sonst bleibt sie dem Zufall
		# ueberlassen. So ist "spaeter haeufiger" eine Eigenschaft der Form und
		# nicht nur eine Zahl.
		var branch_chance := JumpConfig.RISKY_CHANCE
		if _pattern_kind == Patterns.Kind.RISK_CHOICE and _pattern_index < _pattern_length:
			branch_chance = JumpConfig.RISKY_PATTERN_CHANCE
		if _random.randf() < branch_chance:
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

## Naechste Sprosse. Der horizontale Schritt kommt aus der laufenden
## Pattern-Sequenz, die HOEHE weiterhin allein aus der Schwierigkeit: eine Form
## darf schnell und eng sein, aber nicht ploetzlich zu hoch.
func _next_position(difficulty: int = 0) -> Vector2:
	var horizontal_step := get_horizontal_step(difficulty)
	if _pattern_index >= _pattern_length or _pattern_difficulty != difficulty:
		_begin_pattern(difficulty, horizontal_step)
	var horizontal_offset := Patterns.step_offset(
		_pattern_kind,
		_pattern_index,
		_pattern_length,
		_last_position.x,
		horizontal_step,
		_pattern_direction,
		JumpConfig.PLATFORM_MIN_CENTER_X,
		JumpConfig.PLATFORM_MAX_CENTER_X
	)
	_pattern_index += 1
	return Vector2(
		clampf(_last_position.x + horizontal_offset, JumpConfig.PLATFORM_MIN_CENTER_X, JumpConfig.PLATFORM_MAX_CENTER_X),
		_last_position.y - get_vertical_gap(difficulty)
	)

## Beginnt eine neue Sequenz. Schwierigkeit, Zufall und Schachtgrenzen gehen in
## die Wahl ein; die Form selbst kennt keine Hoehen und kann deshalb keine
## unerreichbare Sprosse bauen.
func _begin_pattern(difficulty: int, horizontal_step: float) -> void:
	var kind := Patterns.pick_kind(_random.randf() * Patterns.total_weight(difficulty), difficulty)
	_pattern_kind = kind
	_pattern_length = Patterns.length_for(kind, _random.randf())
	_pattern_index = 0
	_pattern_difficulty = difficulty
	_pattern_step = horizontal_step
	_pattern_direction = Patterns.direction_for(
		kind,
		_last_position.x,
		_pattern_length,
		horizontal_step,
		JumpConfig.PLATFORM_MIN_CENTER_X,
		JumpConfig.PLATFORM_MAX_CENTER_X
	)

## Variante der aktuellen Sprosse. Sie gehoert zur Form: eine Precision-Rush
## besteht aus schmalen Sprossen, eine Erholung aus normalen. Nur wo die Form
## nichts vorgibt, entscheidet der Zufall wie bisher.
func _variant_for_current() -> JumpPlatform.Variant:
	if _pattern_length <= 0:
		return _roll_variant()
	var index := maxi(0, _pattern_index - 1)
	var variant := Patterns.variant_for(_pattern_kind, index)
	if variant != JumpPlatform.Variant.STANDARD:
		return variant
	return _roll_variant()

## Form des laufenden Abschnitts. Fuer Pruefungen und QA lesbar, ohne dass sie
## den internen Zufallsstrom anfassen muessen.
func current_pattern() -> Patterns.Kind:
	return _pattern_kind

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
