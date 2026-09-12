extends SceneTree

## Dauerhafter QA-Nachweis fuer die Ergebnisanzeige. Faehrt den ECHTEN Pfad:
## Spiel starten, sterben, pruefen dass der Lauf beendet BLEIBT, dann neu starten.
##
## Der Kern dieser Phase ist eine Abwesenheit: es darf nichts von selbst
## passieren. Genau das laesst sich nur pruefen, indem man wartet.
##
## Aufruf:
##   xvfb-run -a -s "-screen 0 430x932x24" godot4 --rendering-driver opengl3 \
##     --resolution 430x932 --path . -s qa/game_over_probe.gd

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")

const OUT := "docs/assets/screenshots/game_over"

var game
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Input.use_accumulated_input = false
	game = Game.new()
	root.add_child(game)
	await process_frame
	game._start_game()
	game._start_tween.pause()
	game._start_tween.custom_step(JumpConfig.START_TOTAL + 0.01)
	await process_frame
	await process_frame

	# Einen echten Score erzeugen, damit die Anzeige etwas zu zeigen hat.
	game.jumper.global_position.y = game.START_Y - 2000.0
	game._update_score()
	var reached: int = game.score
	print("Erreichter Score vor dem Absturz: %d" % reached)
	_capture("01_playing.png")

	# Sterben.
	game.jumper.global_position.y = game.camera.global_position.y + JumpConfig.FALL_DEATH_MARGIN + 60.0
	game._check_game_over()
	_check(game.is_game_over, "der Sturz beendet den Lauf")
	_check(game.game_over_menu.visible, "die Ergebnisanzeige wird sichtbar")
	_check(game.game_over_menu.score == reached, "die Anzeige zeigt den erreichten Score")
	_check(game.run_record.last == reached, "der Lauf wird mit seinem Score verbucht")
	_check(game.run_record.best == reached, "der erste Lauf setzt den Bestwert")
	_check(not game.game_over_menu.is_record, "der erste Lauf meldet keinen neuen Bestwert")

	await create_timer(JumpConfig.GAME_OVER_IN_DURATION + 0.15).timeout
	_capture("02_game_over.png")

	# Der Kern: es darf NICHTS von selbst passieren.
	await create_timer(1.5).timeout
	_check(game.is_game_over, "auch nach 1,5 s wartet der Lauf noch")
	# `_phase` bleibt beim Absturz bewusst PLAYING: die Sperre ist `is_game_over`,
	# und das HUD soll sichtbar bleiben. Entscheidend ist, dass wirklich nichts
	# weiterlaeuft — die Welt steht und es wurde nichts neu verbucht.
	_check(not game.jumper.is_physics_processing(), "der Reaktor bleibt eingefroren")
	_check(game.game_over_menu.visible, "die Anzeige bleibt stehen")
	_check(game.score == reached, "der Score bleibt lesbar, statt ueberschrieben zu werden")
	_check(game.run_record.best == reached, "es wurde kein zweiter Lauf verbucht")
	_capture("03_still_waiting.png")

	# Ein Tap NEBEN die Zeile darf nichts ausloesen.
	game.game_over_menu._handle_tap(Vector2(2.0, 2.0))
	await create_timer(0.2).timeout
	_check(game.is_game_over, "ein Tap daneben startet nicht neu")

	# Neustart ueber den echten Weg durch die Anzeige.
	var center: Vector2 = game.game_over_menu.restart_rect().get_center()
	game.game_over_menu._handle_tap(center)
	await process_frame
	await process_frame
	_check(not game.is_game_over, "NEU STARTEN beendet den Absturzzustand")
	_check(game._phase == Game.Phase.PLAYING, "NEU STARTEN startet eine laufende Runde")
	_check(not game.game_over_menu.visible, "die Anzeige verschwindet")
	_check(game.score < reached or reached == 0, "die neue Runde beginnt bei niedrigem Score")
	print("Score der neuen Runde: %d" % game.score)
	_capture("04_after_restart.png")

	# Zweiter Absturz: jetzt MUSS der Bestwert gemeldet werden.
	game.jumper.global_position.y = game.START_Y - 3000.0
	game._update_score()
	var second: int = game.score
	game.jumper.global_position.y = game.camera.global_position.y + JumpConfig.FALL_DEATH_MARGIN + 60.0
	game._check_game_over()
	_check(second > reached, "der zweite Lauf ist hoeher als der erste (%d > %d)" % [second, reached])
	_check(game.game_over_menu.is_record, "der zweite Lauf meldet einen neuen Bestwert")
	_check(game.run_record.best == second, "der Bestwert wandert auf den neuen Wert")
	_check(game.game_over_menu.best == second, "die Anzeige zeigt den neuen Bestwert")
	await create_timer(JumpConfig.GAME_OVER_IN_DURATION + 0.15).timeout
	_capture("05_new_record.png")

	if game != null and is_instance_valid(game):
		game.queue_free()
	await process_frame
	print("\nERGEBNIS: %s" % ("ALLE OK" if failures == 0 else "%d FEHLER" % failures))
	quit(1 if failures > 0 else 0)

func _capture(file_name: String) -> void:
	var image := get_root().get_texture().get_image()
	image.save_png("res://%s/%s" % [OUT, file_name])
	print("  SAVED %s/%s" % [OUT, file_name])

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ✓ " + description)
		return
	failures += 1
	print("  ✗ " + description)
