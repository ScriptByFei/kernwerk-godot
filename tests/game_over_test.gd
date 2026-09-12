extends SceneTree

## Ergebnisanzeige nach dem Absturz: echter Pfad, echte Eingabe.
##
## Kern dieser Phase ist eine ABWESENHEIT — nach dem Absturz darf nichts von
## selbst passieren. Genau das laesst sich nur pruefen, indem man wartet: ein
## Test, der sofort weitermacht, wuerde den alten Auto-Neustart nicht bemerken.
##
## Aufruf: godot4 --headless --audio-driver Dummy --path . -s tests/game_over_test.gd

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await _test_record_rules()
	await _test_death_shows_result_and_waits()
	await _test_restart_from_result()
	await _test_tap_outside_does_nothing()
	await _test_second_death_reports_record()
	await _test_menu_survives_repeated_deaths()
	print("ERGEBNISANZEIGE: ALLE OK" if failures == 0 else "ERGEBNISANZEIGE: %d FEHLER" % failures)
	quit(1 if failures > 0 else 0)

## Reine Regeln des Bestwerts, ohne Spiel.
func _test_record_rules() -> void:
	var record := RunRecord.new()
	_check(record.best == 0, "ein frischer Bestwert ist 0")

	_check(not record.finish_run(50), "der erste Lauf meldet keinen neuen Bestwert")
	_check(record.best == 50, "der erste Lauf setzt trotzdem den Bestwert")
	_check(record.last == 50, "der letzte Lauf wird gemerkt")

	_check(not record.finish_run(30), "ein schwaechere Lauf meldet keinen Bestwert")
	_check(record.best == 50, "der Bestwert faellt nicht")
	_check(record.last == 30, "der letzte Lauf wird trotzdem aktualisiert")

	_check(record.finish_run(80), "ein besserer Lauf meldet einen Bestwert")
	_check(record.best == 80, "der Bestwert steigt")
	_check(not record.finish_run(80), "derselbe Wert ist kein neuer Bestwert")

	record.reset()
	_check(record.best == 0 and record.last == 0, "zuruecksetzen loescht beide Werte")

## Absturz: Anzeige erscheint, Lauf bleibt beendet.
func _test_death_shows_result_and_waits() -> void:
	var game = await _playing_game()
	game.jumper.global_position.y = game.START_Y - 2000.0
	game._update_score()
	var reached: int = game.score

	game.jumper.global_position.y = game.camera.global_position.y + JumpConfig.FALL_DEATH_MARGIN + 60.0
	game._check_game_over()

	_check(game.is_game_over, "der Sturz beendet den Lauf")
	_check(game.game_over_menu.visible, "die Ergebnisanzeige erscheint")
	_check(game.game_over_menu.score == reached, "sie zeigt den erreichten Score")
	_check(game.run_record.best == reached, "der Lauf setzt den Bestwert")

	# Der eigentliche Punkt: warten. Frueher haette hier der Auto-Neustart
	# zugeschlagen und den Score ueberschrieben.
	await _wait(1.2)
	_check(game.is_game_over, "auch nach 1,2 s wartet der Lauf noch")
	_check(game.game_over_menu.visible, "die Anzeige bleibt stehen")
	_check(game.score == reached, "der Score bleibt lesbar")
	_check(not game.jumper.is_physics_processing(), "die Welt bleibt eingefroren")
	_check(not game.pause_button.visible, "der Pausenknopf bleibt aus")

	game.queue_free()
	await process_frame

## Neustart ueber die Anzeige fuehrt in eine laufende Runde.
func _test_restart_from_result() -> void:
	var game = await _playing_game()
	await _die(game)
	game.game_over_menu._handle_tap(game.game_over_menu.restart_rect().get_center())
	await process_frame
	await process_frame

	_check(not game.is_game_over, "NEU STARTEN beendet den Absturzzustand")
	_check(game._phase == Game.Phase.PLAYING, "NEU STARTEN startet eine laufende Runde")
	_check(not game.game_over_menu.visible, "die Anzeige verschwindet")
	_check(game.jumper.is_physics_processing(), "die neue Runde laeuft")
	_check(game.score < 400, "die neue Runde beginnt bei niedrigem Score (%d)" % game.score)
	_check(not is_instance_valid(game.start_menu), "der Neustart zeigt nicht das Startmenue")

	game.queue_free()
	await process_frame

## Ein Tap neben der Zeile darf nichts ausloesen.
func _test_tap_outside_does_nothing() -> void:
	var game = await _playing_game()
	await _die(game)
	game.game_over_menu._handle_tap(Vector2(4.0, 4.0))
	await _wait(0.2)
	_check(game.is_game_over, "ein Tap daneben startet nicht neu")
	_check(game.game_over_menu.visible, "die Anzeige bleibt stehen")

	game.queue_free()
	await process_frame

## Zweiter, hoeherer Lauf meldet einen neuen Bestwert.
func _test_second_death_reports_record() -> void:
	var game = await _playing_game()
	game.jumper.global_position.y = game.START_Y - 1000.0
	game._update_score()
	var first: int = game.score
	await _die(game)
	_check(not game.game_over_menu.is_record, "der erste Lauf meldet keinen Rekord")
	game.game_over_menu._handle_tap(game.game_over_menu.restart_rect().get_center())
	await process_frame

	game.jumper.global_position.y = game.START_Y - 3000.0
	game._update_score()
	var second: int = game.score
	await _die(game)
	_check(second > first, "der zweite Lauf ist hoeher (%d > %d)" % [second, first])
	_check(game.game_over_menu.is_record, "der zweite Lauf meldet einen Rekord")
	_check(game.run_record.best == second, "der Bestwert wandert mit")
	_check(game.game_over_menu.best == second, "die Anzeige zeigt den neuen Bestwert")

	game.queue_free()
	await process_frame

## Die Anzeige wird nur versteckt, nicht zerstoert. Ohne Ruecksetzen des
## Eingaberiegels waere sie beim zweiten Absturz sichtbar, aber taub — genau
## dieser Fehler ist beim Pausenmenue schon einmal live gegangen.
func _test_menu_survives_repeated_deaths() -> void:
	var game = await _playing_game()
	for round_index in 3:
		await _die(game)
		_check(game.game_over_menu.visible, "Anzeige sichtbar in Runde %d" % (round_index + 1))
		var center: Vector2 = game.game_over_menu.restart_rect().get_center()
		game.game_over_menu._handle_tap(center)
		await process_frame
		await process_frame
		_check(not game.is_game_over, "Neustart greift in Runde %d" % (round_index + 1))

	game.queue_free()
	await process_frame

## Sterben ueber den echten Pfad und die Einblendung abwarten.
func _die(game) -> void:
	game.jumper.global_position.y = game.camera.global_position.y + JumpConfig.FALL_DEATH_MARGIN + 60.0
	game._check_game_over()
	_check(game.is_game_over, "der Sturz beendet den Lauf")
	await _wait(JumpConfig.GAME_OVER_IN_DURATION + 0.1)

## Spiel im laufenden Zustand. Ohne Rueckgabetyp: der Aufrufer bekommt die
## konkrete Spielinstanz, sonst sind run_record und game_over_menu nicht aufloesbar.
func _playing_game():
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game._start_game()
	game._start_tween.pause()
	game._start_tween.custom_step(JumpConfig.START_TOTAL + 0.01)
	await process_frame
	await process_frame
	return game

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ✓ " + description)
		return
	failures += 1
	print("  ✗ " + description)
