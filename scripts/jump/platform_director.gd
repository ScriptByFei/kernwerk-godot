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
## Der Anker der laufenden Form: ihre Startposition. Die Form bleibt in ihrer
## eigenen Region um diesen Punkt (`Patterns.span_limit_for`) — das begrenzt die
## Distanz je Pattern und macht sie als Abschnitt lesbar.
var _pattern_start_x := 0.0
## Senkrechter Abstand der laufenden Sequenz. Er gilt fuer die GANZE Sequenz und
## wird erst beim naechsten Pattern neu gesetzt — der Rhythmus eines Abschnitts
## darf nicht mitten drin umschlagen.
var _pattern_gap := JumpConfig.PLATFORM_VERTICAL_GAP
## Zaehlt die zuletzt vergebene Schwierigkeit. Sie wird beim ABSCHLUSS einer
## Sequenz nachgezogen, nicht waehrend: ein laufendes Pattern wird immer zu Ende
## gespielt (siehe `_next_position`).
var _pattern_difficulty := -1
## Schwierigkeit, die beim Start des NAECHSTEN Patterns gilt. Waehrend eines
## laufenden Patterns wird sie nur mitgeschrieben.
var _pending_difficulty := 0
## Zaehlt fertig gespielte Sequenzen. Nur fuer Pruefungen.
var patterns_completed := 0

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
	# Die Schwierigkeit wird nur GEMERKT, nicht sofort uebernommen: ein laufendes
	# Pattern wird immer vollstaendig zu Ende gespielt. Sonst brach eine
	# Stufenaenderung die Form nach wenigen Sprossen ab und der Abschnitt war
	# nicht mehr als Abschnitt erkennbar (siehe `_next_position`).
	_pending_difficulty = clamped_difficulty
	while _last_position.y > visible_top_y - JumpConfig.PLATFORM_LOOKAHEAD:
		var previous := _last_position
		var next_position := _next_position(clamped_difficulty)
		# Der Zweig wird ZWISCHEN Vorgaenger und naechster Sprosse eingehaengt und
		# verschiebt die Hauptroute nicht: `advance` bleibt fuer ihn aus, sonst
		# waere die sichere Route nach der ersten Abzweigung eine Sackgasse.
		_add_platform(next_position, _variant_for_current(), true, _pattern_kind, _pattern_step)
		# Die Risikowahl ist der EINZIGE Ort, an dem die riskante Abzweigung
		# angeboten wird. Sie ist das Thema dieses Abschnitts; in jeder anderen
		# Form widerspraeche sie der Identitaet (eine Abzweigung mitten in einer
		# Erholung ist keine Erholung mehr).
		var branch_chance := 0.0
		if Patterns.offers_branch(_pattern_kind) and _pattern_index < _pattern_length:
			branch_chance = JumpConfig.RISKY_PATTERN_CHANCE
		if branch_chance > 0.0 and _random.randf() < branch_chance:
			var branch := _branch_between(previous, next_position, clamped_difficulty)
			if branch.is_finite():
				# Die Abzweigung gehoert zur LAUFENDEN Sequenz: sie traegt deren
				# Form und deren Schrittmass. Ohne diese Angaben stuende sie in
				# der Pruefung mit Schritt 0 da (gemessen: 202 falsche Fehler).
				_add_platform(branch, JumpPlatform.Variant.RISKY, false, _pattern_kind, _pattern_step)
	_remove_platforms_below(visible_bottom_y + JumpConfig.PLATFORM_CLEANUP_MARGIN)

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

## Naechste Sprosse. Der horizontale Schritt UND der senkrechte Abstand kommen
## aus der laufenden Pattern-Sequenz; die Schwierigkeit bestimmt nur die
## GRUNDWERTE, auf die die Form ihren Faktor anwendet.
##
## Der entscheidende Punkt: die Sequenz endet AUSSCHLIESSLICH durch ihre eigene
## Laenge. Die uebergebene Schwierigkeit wird hier NICHT verglichen — sonst
## braeche ein Stufenwechsel das laufende Pattern nach wenigen Sprossen ab
## (`_pattern_difficulty != difficulty`). Die neue Stufe wird beim Start der
## NAECHSTEN Sequenz uebernommen; die laufende behaelt ihre Masse, damit sie als
## Form erkennbar bleibt und nicht mitten im Rhythmus die Groesse wechselt.
func _next_position(difficulty: int = 0) -> Vector2:
	var horizontal_step := get_horizontal_step(difficulty)
	if _pattern_index >= _pattern_length:
		if _pattern_length > 0:
			patterns_completed += 1
		_begin_pattern()
	var horizontal_offset := Patterns.step_offset(
		_pattern_kind,
		_pattern_index,
		_pattern_length,
		_last_position.x,
		_pattern_start_x,
		_pattern_step,
		_pattern_direction,
		JumpConfig.PLATFORM_MIN_CENTER_X,
		JumpConfig.PLATFORM_MAX_CENTER_X
	)
	_pattern_index += 1
	return Vector2(
		clampf(_last_position.x + horizontal_offset, JumpConfig.PLATFORM_MIN_CENTER_X, JumpConfig.PLATFORM_MAX_CENTER_X),
		_last_position.y - _pattern_gap
	)

## Beginnt eine neue Sequenz. Erst HIER wird die gemerkte Schwierigkeit
## uebernommen — das ist die einzige Stelle, an der die Stufe wechselt.
func _begin_pattern() -> void:
	var difficulty := _pending_difficulty
	var horizontal_step := get_horizontal_step(difficulty)
	var kind := Patterns.pick_kind(_random.randf() * Patterns.total_weight(difficulty), difficulty)
	_pattern_kind = kind
	_pattern_length = Patterns.length_for(kind, _random.randf())
	_pattern_index = 0
	_pattern_difficulty = difficulty
	_pattern_step = horizontal_step
	## Der senkrechte Abstand gilt fuer die GANZE Sequenz: erst beim naechsten
	## Pattern wird eine andere Stufe wirksam. Sonst aenderte ein Stufenwechsel
	## mitten im Abschnitt den Rhythmus.
	_pattern_gap = get_vertical_gap(difficulty) * Patterns.gap_factor_for(kind)
	_pattern_start_x = _last_position.x
	_pattern_direction = Patterns.direction_for(
		kind,
		_last_position.x,
		_pattern_length,
		horizontal_step,
		JumpConfig.PLATFORM_MIN_CENTER_X,
		JumpConfig.PLATFORM_MAX_CENTER_X
	)

## Variante der aktuellen Sprosse. Sie gehoert zur Form und wird von ihr
## vollstaendig bestimmt — es gibt keinen Zufallswurf mehr, der sie verwaessern
## koennte (siehe `Patterns.variant_for`).
func _variant_for_current() -> JumpPlatform.Variant:
	return Patterns.variant_for(_pattern_kind, maxi(0, _pattern_index - 1))

## Form des laufenden Abschnitts. Fuer Pruefungen und QA lesbar, ohne dass sie
## den internen Zufallsstrom anfassen muessen.
func current_pattern() -> Patterns.Kind:
	return _pattern_kind

## Schwierigkeit, die fuer die LAUFENDE Sequenz gilt. Kann hinter `difficulty`
## zurueckliegen, solange ein Pattern noch laeuft — genau das ist gewollt.
func pattern_difficulty() -> int:
	return _pattern_difficulty

## Senkrechter Abstand der laufenden Sequenz (Form-Faktor bereits enthalten).
func pattern_gap() -> float:
	return _pattern_gap

## Index der naechsten Sprosse innerhalb der laufenden Sequenz.
func pattern_index() -> int:
	return _pattern_index

## Laenge der laufenden Sequenz.
func pattern_length() -> int:
	return _pattern_length

## Startposition der laufenden Sequenz (Anker ihrer Region).
func pattern_start_x() -> float:
	return _pattern_start_x

func get_vertical_gap(difficulty: int = 0) -> float:
	var clamped_difficulty := clampi(difficulty, 0, JumpConfig.MAX_DIFFICULTY)
	return JumpConfig.PLATFORM_VERTICAL_GAP + clamped_difficulty * JumpConfig.DIFFICULTY_VERTICAL_BONUS

## Abstand fuer eine konkrete Form bei einer konkreten Stufe. Gemeinsame Quelle
## fuer Director UND Fairness-Pruefung, damit beide nicht auseinanderlaufen.
func get_pattern_gap(kind: Patterns.Kind, difficulty: int) -> float:
	return get_vertical_gap(difficulty) * Patterns.gap_factor_for(kind)

## Der groesste Abstand, den IRGENDEINE Form auf dieser Stufe verlangen kann.
## Die Fairness wird dagegen gerechnet, nicht gegen den Mittelwert: sonst waere
## die Pruefung blind fuer die eine Form, die zu hoch greift.
func max_pattern_gap(difficulty: int) -> float:
	var worst := 0.0
	for kind in Patterns.Kind.values():
		worst = maxf(worst, get_pattern_gap(kind, difficulty))
	return worst

func get_horizontal_step(difficulty: int = 0) -> float:
	var clamped_difficulty := clampi(difficulty, 0, JumpConfig.MAX_DIFFICULTY)
	return JumpConfig.PLATFORM_MAX_HORIZONTAL_STEP + clamped_difficulty * JumpConfig.DIFFICULTY_HORIZONTAL_BONUS

func _add_platform(position: Vector2, variant := JumpPlatform.Variant.STANDARD, advance := true, pattern_kind := -1, pattern_step := 0.0) -> void:
	var platform := JumpPlatform.new()
	platform.configure_variant(variant)
	platform.pattern_kind = pattern_kind
	platform.pattern_step = pattern_step
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
