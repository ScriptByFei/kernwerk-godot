extends SceneTree

const Game = preload("res://scripts/game/game.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.jumper.set_physics_process(false)
	game.camera.set_physics_process(false)
	game._phase = Game.Phase.PLAYING
	var p := JumpPlatform.new()
	game.add_child(p)
	var r: ResonanceSystem = game.resonance
	for i in 3:
		_land(game, p)
		var charge := i + 1
		var expected_speed := JumpConfig.pace_bounce(charge, false, true) * JumpConfig.LANDING_BOUNCE_MULTIPLIERS[2]
		_check(is_equal_approx(-game.jumper.velocity.y, expected_speed), "launch reads fresh charge in same landing %d" % charge)
		_check(is_equal_approx(game.jumper.current_gravity(), JumpConfig.pace_gravity(charge, false, true)), "gravity follows same launch tier %d" % charge)
	_check(r.charges == 3, "third landing stores 3/3")
	_check(r.overload_count == 0 and not game.jumper._pending_overload, "no automatic overload")
	# Explicit API guard makes the pre-implementation run fail behaviourally,
	# not through a parser error for the not-yet-created interface.
	_check(r.has_method("arm_overload"), "explicit arming API exists")
	if not r.has_method("arm_overload"):
		game.free()
		_finish()
		return
	_check(r.call("is_overload_ready") and not r.call("is_overload_armed"), "full charge is READY, not ARMED")
	game.hud.resonance = r
	# Nur ASCII: der Fallback-Font rastert Symbole, aber einzelne Zeichen tragen
	# in HUD-Groesse zu wenig Tinte, um als Hinweis zu tragen (gemessen).
	for text in [JumpConfig.RESONANCE_READY_LABEL, JumpConfig.RESONANCE_ARMED_LABEL]:
		for index in text.length():
			_check(text.unicode_at(index) < 128, "label is plain ASCII: " + text)
	_check(JumpConfig.RESONANCE_ARMED_LABEL != JumpConfig.RESONANCE_READY_LABEL, "ARMED is named distinctly, not only by colour")
	for i in 6:
		_land(game, p, 90.0 if i % 2 else 0.0)
		_check(r.charges == 3 and r.overload_count == 0, "full resource held without stacking %d" % i)
		_check(not game.jumper._pending_overload, "held charge never auto-fires %d" % i)
		var perfect := game.jumper.last_landing_quality == JumpConfig.LandingQuality.PERFECT
		_check(is_equal_approx(game.jumper.current_gravity(), JumpConfig.pace_gravity(3, false, perfect)), "3/3 gravity matches launch charge")
	_check(game.run_stats.overloads == 0, "holding never counts in statistics")
	var speed := game.jumper.velocity
	var pos := game.jumper.position
	var gravity := game.jumper.current_gravity()
	_check(game.call("try_arm_overload"), "player arms full overload")
	_check(r.call("is_overload_armed") and not r.call("is_overload_ready"), "READY becomes ARMED")
	_check(game.hud.status_label() == JumpConfig.RESONANCE_ARMED_LABEL, "HUD names ARMED")
	_check(r.charges == 3 and r.overload_count == 0, "arming neither consumes nor counts")
	_check(game.jumper.velocity == speed and game.jumper.position == pos and is_equal_approx(game.jumper.current_gravity(), gravity), "arming never changes airborne physics")
	_check(not game.call("try_arm_overload"), "double arm rejected")
	_land(game, p, 90.0)
	_check(game.jumper._pending_overload, "next regular bounce consumes overload")
	_check(is_equal_approx(-game.jumper.velocity.y, JumpConfig.pace_bounce(0, true) * JumpConfig.LANDING_BOUNCE_MULTIPLIERS[1]), "existing overload force reused")
	_check(is_equal_approx(game.jumper.current_gravity(), JumpConfig.OVERLOAD_GRAVITY), "consumed flight uses existing overload gravity despite zero charges")
	_check(r.charges == 0 and not r.call("is_overload_armed"), "consumption clears resource and arm")
	_check(r.overload_count == 1 and game.run_stats.overloads == 1, "actual consumption counted exactly once")
	_check(game._overload_display > 0.0 and game.jumper.is_overloaded(), "existing effects retained at consumption")
	_land(game, p)
	_check(not game.jumper._pending_overload and r.charges == 1 and r.overload_count == 1, "following bounce normal, rebuild from one")
	_check(game.jumper._perfect_boost_flight, "PERFECT tempo boost retained")
	for charge in 3:
		r.reset()
		for i in charge:
			_land(game, p)
		_check(not game.call("try_arm_overload"), "below full is inert %d" % charge)
	for armed in [false, true]:
		r.reset()
		for i in 3:
			_land(game, p)
		if armed:
			game.call("try_arm_overload")
		_land(game, p, 130.0)
		_check(r.charges == 0 and not r.call("is_overload_armed"), "NORMAL clears READY/ARMED %s" % armed)
		_check(not game.jumper._pending_overload and r.overload_count == 0, "NORMAL never spends overload %s" % armed)
		_check(is_zero_approx(game.jumper._resonance_ratio), "NORMAL clears core feedback")
	for phase in [Game.Phase.START_MENU, Game.Phase.STARTING]:
		r.reset()
		for i in 3:
			r.register_landing(JumpConfig.LandingQuality.PERFECT)
		game._phase = phase
		_check(not game.call("try_arm_overload"), "start phase rejects arming %d" % phase)
	game._phase = Game.Phase.PLAYING
	game.is_game_over = true
	_check(not game.call("try_arm_overload"), "game over rejects arming")
	game.is_game_over = false
	game._is_paused = true
	_check(not game.call("try_arm_overload"), "pause rejects arming")
	game._is_paused = false
	root.get_tree().paused = true
	_check(not game.call("try_arm_overload"), "tree pause rejects arming")
	root.get_tree().paused = false
	_check(game.call("try_arm_overload"), "resume permits fresh arming")
	game._restart(true)
	_check(r.charges == 0 and not r.call("is_overload_armed") and r.overload_count == 0, "restart clears all state")
	game.free()
	await process_frame
	_finish()

func _land(game, platform: JumpPlatform, offset := 0.0) -> void:
	game.jumper.velocity.y = 600.0
	game.jumper._resolve_landing(platform, false, platform.global_position.x + offset)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _finish() -> void:
	print("OVERLOAD CHOICE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
