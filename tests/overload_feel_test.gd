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
	game._audio_unlocked = true
	_check(game.jumper.has_method("charge_light_strength"), "persistent charge light implemented")
	if failures:
		game.free()
		await process_frame
		_finish()
		return
	var platform := JumpPlatform.new()
	game.add_child(platform)
	for offset in [0.0, 90.0]:
		game.resonance.reset()
		var speeds := []
		var pitches := []
		var lights := []
		var radii := []
		for charge in range(3):
			game.jumper._resolve_landing(platform, false, platform.position.x + offset)
			speeds.append(-game.jumper.velocity.y)
			pitches.append(game._contact_audio.pitch_scale)
			lights.append(game.jumper.call("charge_light_alpha"))
			radii.append(game.jumper.call("charge_light_radius"))
			_check(game.resonance.last_charge == charge + 1, "callback books exactly one charge")
		_check(speeds[2] >= speeds[1] * 1.10, "third actual launch at least 10 percent faster than second")
		_check(speeds[2] <= JumpConfig.MAX_BOUNCE_SPEED, "global launch cap respected")
		_check(pitches[0] < pitches[1] and pitches[1] < pitches[2], "sound pitch rises across real charge chain")
		_check(lights[0] < lights[1] and lights[1] < lights[2], "core light strengthens across charge chain")
		_check(radii[0] < radii[1] and radii[1] < radii[2], "charged core radius grows, measurable beyond the saturated core")
		_check(JumpConfig.OVERLOAD_RING_RADIUS > 96.0, "overload ring lies clearly outside the 192 px core silhouette")
		_check(JumpConfig.OVERLOAD_AURA_RADIUS < JumpConfig.PLATFORM_SIZE.x * 0.5, "aura stays within the platform width")
		_check(JumpConfig.OVERLOAD_AURA_RADIUS > JumpConfig.OVERLOAD_RING_RADIUS, "aura extends beyond the ring")
		_check(game.resonance.charges == 0 and game.resonance.overload_count == 1, "third charge immediately discharges once")
		_check(game.jumper.is_overloaded(), "HUD and core retain visible overload flight")
		print("CHAIN offset=", offset, " speeds=", speeds, " pitches=", pitches, " lights=", lights, " radii=", radii)
		game.jumper._process(0.3)
		_check(game.jumper.call("charge_light_alpha") > 0.0 and game.jumper.is_overloaded(), "overload core remains visible beyond landing impact")
		game.jumper._resolve_landing(platform, false, platform.position.x + 130.0)
		_check(game.resonance.charges == 0 and game.resonance.last_charge == 0, "NORMAL clears charges")
		_check(game.resonance.charges == 0 and game.jumper.call("charge_light_alpha") == 0.0, "NORMAL clears charge/flight light")
		_check(game._contact_audio.pitch_scale == 1.0, "NORMAL resets audio pitch")
	# Partial chain: NORMAL must erase real charges, not an already empty state.
	game.resonance.reset()
	game.jumper._resolve_landing(platform, false, platform.position.x + 90.0)
	game.jumper._resolve_landing(platform, false, platform.position.x + 90.0)
	_check(game.jumper.call("charge_light_alpha") > 0.0, "two charges stay visibly retained")
	game.jumper._resolve_landing(platform, false, platform.position.x + 130.0)
	_check(game.resonance.charges == 0 and game.resonance.last_charge == 0, "NORMAL clears two real charges")
	_check(game.jumper.call("charge_light_alpha") == 0.0, "NORMAL clears the retained core light")
	game._restart(true)
	_check(game.jumper.call("charge_light_alpha") == 0.0 and game._overload_display == 0.0, "restart resets all overload presentation")
	# Let the short contact voices actually finish: quitting while they are
	# still playing leaves engine audio objects behind and turns a clean run
	# into a misleading leak warning.
	await create_timer(0.5).timeout
	game._contact_audio.stop()
	game.free()
	await process_frame
	await process_frame
	_finish()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _finish() -> void:
	print("OVERLOAD FEEL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
