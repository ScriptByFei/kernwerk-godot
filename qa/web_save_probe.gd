extends Node
## Faehrt den ECHTEN BestScoreStore-Code im ECHTEN Web-Export.
##
## Warum das noetig ist: `JavaScriptBridge` und `localStorage` existieren NUR im
## Web-Export. Ein headless Lauf nimmt immer den Datei-Zweig, der Web-Zweig
## bliebe also ungeprueft. Der Gameplay-Weg im Browser ist hier zudem nicht
## fahrbar — Software-WebGL ist zu langsam, der Reaktor stuerzt nicht ab.
##
## Wird von `tools/web_save_probe.sh` als Hauptszene in eine temporaere
## Projektkopie gesetzt, dort exportiert und im echten Chromium ausgefuehrt.
## Das Ergebnis landet im Seitentitel, weil die Konsolenausgabe des Web-Exports
## ueber CDP nicht zuverlaessig greifbar ist.

var failures := 0
var failed_lines := []

func _ready() -> void:
	var store := BestScoreStore.new()

	_check(store._is_web(), "der Web-Export erkennt sich als Web")
	_check(store._is_detached_run() == false,
		"im echten Spiel gilt der Standardpfad NICHT als abgekoppelt")

	_clear()

	_check(store.load_best() == 0, "ohne Eintrag liefert der Web-Zweig 0")

	store.save_best(4321)
	_check(store.load_best() == 4321, "der Web-Zweig speichert und liest")

	# Neuladen: neues Store-Objekt auf denselben localStorage.
	_check(BestScoreStore.new().load_best() == 4321,
		"ein neues Store-Objekt liest denselben Wert (Neuladen)")

	# Die Regel liegt in RunRecord, nicht im Store.
	var record := RunRecord.new(BestScoreStore.new())
	_check(record.best == 4321, "RunRecord uebernimmt den gespeicherten Wert")
	_check(not record.finish_run(100), "ein schwacher Lauf ist kein Rekord")
	_check(BestScoreStore.new().load_best() == 4321, "und ueberschreibt den Wert nicht")
	_check(record.finish_run(9999), "ein besserer Lauf ist ein Rekord")
	_check(BestScoreStore.new().load_best() == 9999, "der Rekord landet im localStorage")

	# Der eigentliche Zweck: ein ECHTER Spielabsturz muss denselben Weg nehmen.
	var game = load("res://scripts/game/game.gd").new()
	add_child(game)
	await get_tree().process_frame
	_check(game.score_store._is_web(), "das Spiel nutzt im Web den Web-Zweig")

	_clear()
	game.run_record = RunRecord.new(BestScoreStore.new())
	game._start_game()
	game._start_tween.custom_step(JumpConfig.START_TOTAL + 0.01)
	await get_tree().process_frame
	# Erst Hoehe aufbauen: ohne Score waere 0 der Bestwert und "nichts
	# gespeichert" das korrekte Verhalten — der Test pruefte dann nichts.
	game.jumper.global_position.y = game.START_Y - 5000.0
	game._update_score()
	await get_tree().process_frame
	game.jumper.global_position.y = game.camera.global_position.y + JumpConfig.FALL_DEATH_MARGIN + 60.0
	game._check_game_over()
	await get_tree().process_frame

	_check(game.is_game_over, "der Absturz hat den Lauf beendet")
	var written := BestScoreStore.new().load_best()
	_check(written > 0, "ein echter Absturz schreibt in den localStorage (score=%d)" % game.score)
	_check(game.run_record.best == written, "Spiel und Speicher stimmen ueberein")

	# Der Spielstand des Testers darf nicht verfaelscht bleiben.
	_clear()

	var text := "ALLE OK" if failures == 0 else ("%d FEHLER" % failures)
	print("ERGEBNIS: ", text)
	var detail := "%s || %s" % [text, "; ".join(failed_lines)]
	JavaScriptBridge.eval("document.title = 'PROBE:' + %s" % JSON.stringify(detail), true)

func _clear() -> void:
	JavaScriptBridge.eval(
		"try{window.localStorage.removeItem('%s')}catch(e){}" % BestScoreStore.KEY, true)

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  OK   ", description)
		return
	failures += 1
	failed_lines.append(description)
	print("  FAIL ", description)
