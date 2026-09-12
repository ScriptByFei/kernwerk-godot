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
	_check(game.run_stats.has_method("register"), "Run-Statistik ist verdrahtet")
	if failures:
		game.free()
		_finish()
		return
	# Kettenregel: NORMAL beendet, RESONANCE/PERFECT verlaengern, Overload nicht.
	var platform := JumpPlatform.new()
	game.add_child(platform)
	var offsets := [0.0, 90.0, 130.0]
	# Muster NORMAL/RESONANCE/PERFECT wiederholt: die Kette erreicht jedes Mal
	# die Laenge 2 und wird von jeder NORMAL-Landung wieder auf 0 gesetzt.
	var expected := [2, 2, 2]
	for run_index in range(3):
		game.run_stats.reset()
		game.resonance.reset()
		game.jumper.position = Vector2(540.0, 1042.0)
		for step in range(12):
			var quality: int = step % 3
			var distance: float = offsets[quality]
			game.jumper._resolve_landing(platform, false, platform.position.x + distance)
			_check(game.run_stats.perfect_count + game.run_stats.resonance_count + game.run_stats.normal_count == step + 1, "jede echte Landung wird genau einmal gezaehlt")
			_check(game.run_stats.height == game.score - game._landing_bonus or game.run_stats.height >= 0, "Hoehe bleibt plausibel")
		_check(game.run_stats.best_chain == expected[run_index], "beste Kette %d nach festem Muster" % run_index)
		_check(game.run_stats.perfect_count > 0 and game.run_stats.resonance_count > 0 and game.run_stats.normal_count > 0, "alle drei Qualitaeten getrennt gezaehlt")
	# Hoehe: nur der hoechste Punkt zaehlt, Rueckfall senkt sie nicht.
	game.run_stats.reset()
	game.jumper.position = Vector2(540.0, 0.0)
	game._update_score()
	var high: int = game.run_stats.height
	game.jumper.position = Vector2(540.0, 900.0)
	game._update_score()
	_check(game.run_stats.height == high and high > 0, "Hoehe faellt nicht zurueck")
	_check(game.run_stats.overloads == game.resonance.overload_count, "Overload-Zaehler folgt dem echten System")
	# Rundenreset: nur der Lauf, nie der Bestwert.
	game.run_record.best = 4242
	var previous_best := game.run_record.best
	game.run_stats.register(JumpConfig.LandingQuality.PERFECT, 100)
	game._restart(true)
	await process_frame
	_check(game.run_stats.perfect_count == 0 and game.run_stats.best_chain == 0, "Neustart setzt die Laufstatistik zurueck")
	_check(game.run_record.best == previous_best, "Neustart erhaelt den Bestwert")
	# Anzeige: die Werte kommen wirklich im Menue an.
	game.is_game_over = true
	game.run_stats.register(JumpConfig.LandingQuality.RESONANCE, 250)
	game.run_stats.register(JumpConfig.LandingQuality.PERFECT, 300)
	game._show_game_over()
	_check(game.game_over_menu.height == 300, "Ergebnisanzeige bekommt die Hoehe")
	_check(game.game_over_menu.perfect_count == 1 and game.game_over_menu.resonance_count == 1, "Ergebnisanzeige bekommt PERFECT und RESONANCE")
	_check(game.game_over_menu.best_chain > 0, "Ergebnisanzeige bekommt die beste Kette")
	_check(game.game_over_menu.overloads == game.run_stats.overloads, "Ergebnisanzeige bekommt die Overloads")
	game.free()
	await process_frame
	_finish()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures <= 20:
			print("FAIL: ", label)

func _finish() -> void:
	print("RUN STATS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
