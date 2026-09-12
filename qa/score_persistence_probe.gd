extends SceneTree
## Beweist, dass eine QA-Probe mit ECHTEM FENSTER den echten Spielstand nicht
## anfasst. Genau hier haette die reine headless-Pruefung versagt.
##
## Aufruf:
##   xvfb-run -a -s "-screen 0 430x932x24" godot4 --rendering-driver opengl3 \
##     --resolution 430x932 --path . -s qa/score_persistence_probe.gd

const Game = preload("res://scripts/game/game.gd")
const BestScoreStore = preload("res://scripts/jump/best_score_store.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Input.use_accumulated_input = false
	print("DisplayServer: %s   Skriptlauf: %s" % [
		DisplayServer.get_name(), OS.get_cmdline_args().has("-s")])

	var real := BestScoreStore.DEFAULT_PATH
	var real_before := -1
	if FileAccess.file_exists(real):
		real_before = BestScoreStore.new(real).load_best()
	print("Echter Spielstand vorher: %s" % ("fehlt" if real_before < 0 else str(real_before)))

	# Ein echtes Spiel mit Fenster — genau der Fall, den die reine
	# headless-Pruefung NICHT abgedeckt haette.
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.score_store.save_best(4242)

	var real_after := -1
	if FileAccess.file_exists(real):
		real_after = BestScoreStore.new(real).load_best()
	print("Echter Spielstand nachher: %s" % ("fehlt" if real_after < 0 else str(real_after)))
	_check(real_after == real_before, "die QA-Probe mit Fenster laesst den echten Spielstand unberuehrt")

	# Und die Gegenprobe mit eigenem Pfad: dort MUSS gespeichert werden,
	# sonst waere die Speicherung insgesamt ungeprueft.
	var probe_path := "user://score_probe.cfg"
	_remove(probe_path)
	var probe := BestScoreStore.new(probe_path)
	probe.save_best(777)
	_check(BestScoreStore.new(probe_path).load_best() == 777, "ein eigener Pfad wird wirklich gespeichert")

	# Ein echter Lauf bis zum Absturz: der Bestwert muss ankommen.
	# Der Lauf muss HOEHER kommen als der gespeicherte Wert (777) — sonst
	# greift die Regel "nur ein besserer Wert ersetzt den Bestwert" und der
	# Test wuerde korrektes Verhalten als Fehler melden.
	var run = Game.new()
	root.add_child(run)
	await process_frame
	run.score_store = BestScoreStore.new(probe_path)
	run.run_record = RunRecord.new(run.score_store)
	_check(run.run_record.best == 777, "der gespeicherte Wert steht beim Start bereit")
	run._start_game()
	run._start_tween.pause()
	run._start_tween.custom_step(JumpConfig.START_TOTAL + 0.01)
	await process_frame
	run.jumper.global_position.y = run.START_Y - 9000.0
	run._update_score()
	var reached: int = run.score
	_check(reached > 777, "der Lauf kommt ueber den gespeicherten Wert (%d > 777)" % reached)
	run.jumper.global_position.y = run.camera.global_position.y + JumpConfig.FALL_DEATH_MARGIN + 60.0
	run._check_game_over()
	await process_frame
	_check(run.run_record.best == reached, "der Absturz setzt den Bestwert (%d)" % reached)
	print("Datei danach: %d" % BestScoreStore.new(probe_path).load_best())
	_check(BestScoreStore.new(probe_path).load_best() == reached, "der Bestwert landet sofort in der Datei")
	_check(run.game_over_menu.best == reached, "die Anzeige zeigt ihn")
	_check(run.game_over_menu.is_record, "ein Wert aus der Speicherung ist ein echter Rekord")

	# Neuladen: neues Store-Objekt auf dieselbe Datei.
	var reloaded = Game.new()
	root.add_child(reloaded)
	await process_frame
	reloaded.score_store = BestScoreStore.new(probe_path)
	reloaded.run_record = RunRecord.new(reloaded.score_store)
	_check(reloaded.run_record.best == reached, "nach dem Neuladen steht der Bestwert bereit (%d)" % reloaded.run_record.best)
	_check(not reloaded.run_record.finish_run(reached - 100), "ein schwaecheres Ergebnis ist kein Rekord, auch nach dem Neuladen")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe_path))
	game.queue_free()
	run.queue_free()
	reloaded.queue_free()
	await process_frame
	print("\nERGEBNIS: %s" % ("ALLE OK" if failures == 0 else "%d FEHLER" % failures))
	quit(1 if failures > 0 else 0)

## Entfernt eine Datei nur, wenn es sie gibt — `remove_absolute` auf einen
## fehlenden Pfad schreibt sonst eine Fehlerzeile ins Log.
func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ✓ " + description)
		return
	failures += 1
	print("  ✗ " + description)
