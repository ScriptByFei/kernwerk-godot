extends "res://qa/mobile_core_loop_probe.gd"

## Reale mobile Fahrt: Ressourcen absichtlich mehrere Landungen halten,
## dann per Up-Flick einsetzen. Keine direkte Manipulation der Spiellogik.
var checks := 0
var failures := 0
var activations := 0
var consumptions := 0
var held_landings := 0
var _arm_landing := -1
var _last_activation := 0

func _run() -> void:
	await super._run()
	# Basistreiber beendet mit 0; unsere Abnahmekriterien bestimmen den Exit-Code.
	quit(1 if failures else 0)

func _steer(now_ms: float) -> void:
	super._steer(now_ms)
	if _game == null or _jumper == null or _game.is_game_over:
		return
	if not _game.resonance.is_overload_ready() or _jumper.velocity.y >= 0.0:
		return
	if _landing_count - _last_activation < 6:
		return
	_release()
	# Designposition: ein echter Daumen im unteren Steuerbereich, nicht Welt-y=0.
	var base: Vector2 = root.get_stretch_transform() * Vector2(_target_x, 1500.0)
	var before_v: Vector2 = _jumper.velocity
	var before_g: float = _jumper.current_gravity()
	var before_count: int = _game.resonance.overload_count
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = base
	Input.parse_input_event(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = base + Vector2(0, -65)
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	_check(_game.resonance.is_overload_armed(), "real loop up arms")
	_check(_jumper.velocity == before_v and is_equal_approx(_jumper.current_gravity(), before_g), "up leaves flight unchanged")
	_check(_game.resonance.overload_count == before_count, "up does not count")
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = drag.position
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	activations += 1
	_arm_landing = _landing_count
	_last_activation = _landing_count
	_press(_target_x)

func _on_landed(platform, quality, bonus) -> void:
	super._on_landed(platform, quality, bonus)
	if _arm_landing >= 0:
		_check(_landing_count == _arm_landing + 1, "exactly next collision landing consumes")
		if quality == JumpConfig.LandingQuality.NORMAL:
			_check(not _jumper._pending_overload, "NORMAL cancels even in full loop")
		else:
			_check(_jumper._pending_overload and _game.resonance.charges == 0, "chosen collision bounce is overloaded and empty")
			consumptions += 1
		_arm_landing = -1
	else:
		_check(not _jumper._pending_overload, "unarmed collision never auto overloads")
		if _game.resonance.charges == 3:
			held_landings += 1

func _capture(_label: String) -> void:
	pass

func _write_report() -> void:
	_check(not _game.is_game_over, "loop survives")
	_check(activations >= 3 and consumptions >= 3, "nonvacuous repeated activation")
	_check(held_landings >= 6, "READY held over multiple collision jumps")
	_check(_game.resonance.overload_count == consumptions and _game.run_stats.overloads == consumptions, "actual consumption statistics exact")
	var report := {"checks": checks, "failures": failures, "activations": activations,
		"consumptions": consumptions, "held_landings": held_landings,
		"landings": _landings, "deaths": _deaths, "dives": _jumper.dive_count}
	DirAccess.make_dir_recursive_absolute("/tmp/kernwerk-overload-choice")
	var f := FileAccess.open("/tmp/kernwerk-overload-choice/active-loop.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	print("OVERLOAD ACTIVE LOOP: %d checks, %d failures; activations=%d consumed=%d held_landings=%d dives=%d" % [checks, failures, activations, consumptions, held_landings, _jumper.dive_count])

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)
