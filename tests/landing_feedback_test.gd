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
	_check(game.normal_landing_sound != null and game.resonance_landing_sound != null and game.perfect_landing_sound != null, "three audible default sounds exist")
	_check(game.camera.has_method("perfect_impact"), "perfect camera impulse exists")
	if failures:
		game.free()
		_finish()
		return
	var streams := [game.normal_landing_sound, game.resonance_landing_sound, game.perfect_landing_sound]
	for i in range(3):
		_check(streams[i] is AudioStreamWAV and streams[i].get_length() > 0.05, "cached finite contact PCM")
		_check(streams[i] != streams[(i + 1) % 3], "quality sound streams are distinct")
		_check(streams[i].data != streams[(i + 1) % 3].data, "quality waveforms really differ")
	var platform := JumpPlatform.new()
	platform.position = Vector2(540.0, 500.0)
	game.add_child(platform)
	var offsets := [130.0, 90.0, 0.0]
	for quality in range(3):
		game.camera.offset = Vector2.ZERO
		game.jumper._resolve_landing(platform, false, 540.0 + offsets[quality])
		_check(game.jumper.last_landing_quality == quality and platform.impact_quality == quality, "real contact selects matching visual tier")
		_check(not game._contact_audio.playing, "sound remains locked without input")
		_check((game.camera.offset.y != 0.0) == (quality == 2), "only PERFECT moves visual camera offset")
	game._audio_unlocked = true
	for quality in range(3):
		game.jumper._resolve_landing(platform, false, 540.0 + offsets[quality])
		_check(game._contact_audio.stream == streams[quality] and game._contact_audio.playing, "real landing dispatch plays correct sound")
	var baseline: float = game.camera.position.y
	game.camera.call("perfect_impact")
	_check(absf(game.camera.offset.y) <= 3.0, "impulse at most three world pixels")
	for tick in range(20):
		game.camera.call("advance_impact", 1.0 / 60.0)
	_check(is_zero_approx(game.camera.offset.y), "impulse settles to zero")
	_check(game.camera.position.y == baseline, "impulse never changes camera ratchet/death line")
	# Kurze Kontakte erst ausklingen lassen: ein Abbruch mitten im Abspielen
	# hinterlaesst Engine-Audioobjekte und erzeugt eine irrefuehrende Warnung.
	await create_timer(0.5).timeout
	game._contact_audio.stop()
	game.free()
	await process_frame
	_finish()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _finish() -> void:
	print("LANDING FEEDBACK: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
