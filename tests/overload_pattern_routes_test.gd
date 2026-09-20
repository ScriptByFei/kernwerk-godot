extends SceneTree

## Generierte Hauptrouten mit Produktionskraft/-gravitation/-lenkung abfahren.
## Diskrete 30/60-Hz-Integration bis zur ABSTEIGENDEN Plattformquerung;
## keine reine v²/2g-Formel und kein Overload fuer eine sichere Route.
const KINDS := [PlatformPatterns.Kind.RISK_CHOICE, PlatformPatterns.Kind.CROSS,
	PlatformPatterns.Kind.PRECISION_RUSH, PlatformPatterns.Kind.RECOVERY]
var checks := 0
var failures := 0
var jumper: Jumper
var coverage := {}
var min_vertical_margin := INF
var min_horizontal_margin := INF

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	jumper = Jumper.new()
	root.add_child(jumper)
	await process_frame
	jumper.set_physics_process(false)
	jumper.set_process(false)
	for kind in KINDS:
		coverage[kind] = 0
		for difficulty in range(JumpConfig.MAX_DIFFICULTY + 1):
			if PlatformPatterns.weight_for(kind, difficulty) <= 0.0:
				continue
			for start_x in [JumpConfig.PLATFORM_MIN_CENTER_X, 540.0, JumpConfig.PLATFORM_MAX_CENTER_X]:
				for seed_value in [1, 7, 42]:
					var director := PlatformDirector.new(seed_value)
					director._last_position = Vector2(start_x, 0)
					director._pending_difficulty = difficulty
					# Waehlen ueber den ECHTEN Generator, nicht Formparameter abschreiben.
					for attempt in 1000:
						director._begin_pattern()
						if director.current_pattern() == kind:
							break
					_check(director.current_pattern() == kind, "requested pattern actually generated")
					var route: Array[Vector2] = [director._last_position]
					var widths: Array[float] = []
					for index in director.pattern_length():
						var target := director._next_position(difficulty)
						var p := JumpPlatform.new()
						p.configure_variant(director._variant_for_current())
						_check(p.variant != JumpPlatform.Variant.RISKY, "safe route is not risk branch")
						widths.append(p.platform_size.x)
						p.free()
						route.append(target)
						director._last_position = target
					for hz in [30, 60]:
						for state in [[0, false], [3, false], [3, true]]:
							var carry_x := route[0].x
							var carry_vx := 0.0
							for index in range(1, route.size()):
								var start := Vector2(carry_x, route[index - 1].y)
								var flight := _flight(start, route[index], widths[index - 1], state[0], state[1], false, hz, carry_vx)
								var label := "%s d%d x%.0f seed%d hz%d c%d perfect%s hop%d" % [PlatformPatterns.Kind.keys()[kind], difficulty, start_x, seed_value, hz, state[0], state[1], index]
								_check(flight.hit, "safe without overload: " + label)
								_check(not jumper._pending_overload, "no overload in route simulation")
								if not flight.hit:
									print("ROUTE FAILURE ", flight)
								carry_x = flight.x
								carry_vx = flight.vx
								min_vertical_margin = minf(min_vertical_margin, flight.apex - (start.y - route[index].y))
								min_horizontal_margin = minf(min_horizontal_margin, flight.margin)
								coverage[kind] += 1
		_check(coverage[kind] > 0, "nonempty coverage " + str(kind))
		print("PATTERN ", PlatformPatterns.Kind.keys()[kind], ": ", coverage[kind], " safe-route hops")
	# Gegenprobe: ein wirklich zu hohes Ziel muss scheitern.
	_check(not _flight(Vector2.ZERO, Vector2(0, -2000), 200, 0, false, false, 60, 0).hit, "unreachable control fails")
	var normal := _flight(Vector2.ZERO, Vector2(0, -300), 280, 3, true, false, 60, 0)
	var overload := _flight(Vector2.ZERO, Vector2(0, -300), 280, 0, true, true, 60, 0)
	_check(overload.apex > normal.apex * 1.3, "optional overload supplies extra height")
	print("MARGINS: min vertical=%.2f, min center-to-edge=%.2f; normal apex=%.2f, overload apex=%.2f" % [min_vertical_margin, min_horizontal_margin, normal.apex, overload.apex])
	jumper.free()
	await process_frame
	print("OVERLOAD PATTERN ROUTES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _flight(start: Vector2, target: Vector2, width: float, charges: int, perfect: bool, overload: bool, hz: int, vx: float) -> Dictionary:
	jumper.position = start
	jumper.velocity = Vector2(vx, 0)
	jumper.set_resonance_ratio(float(charges) / 3.0)
	jumper.last_landing_quality = JumpConfig.LandingQuality.PERFECT if perfect else JumpConfig.LandingQuality.NORMAL
	jumper._perfect_boost_armed = perfect
	jumper._apply_bounce(overload)
	jumper.set_horizontal_target(target.x)
	var highest := start.y
	var dt := 1.0 / float(hz)
	for tick in 240:
		var before := jumper.position
		jumper.apply_gravity(dt)
		jumper.apply_horizontal_steering(dt)
		jumper.position += jumper.velocity * dt
		highest = minf(highest, jumper.position.y)
		if jumper.velocity.y > 0.0 and before.y <= target.y and jumper.position.y >= target.y:
			var fraction := (target.y - before.y) / (jumper.position.y - before.y)
			var x := lerpf(before.x, jumper.position.x, fraction)
			var margin := width * 0.5 - absf(x - target.x)
			return {"hit": margin >= 0.0, "x": x, "vx": jumper.velocity.x, "apex": start.y - highest, "margin": margin}
		if jumper.velocity.y > 0.0 and jumper.position.y > start.y + 100.0:
			break
	return {"hit": false, "x": jumper.position.x, "vx": jumper.velocity.x, "apex": start.y - highest, "margin": -INF}

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)
