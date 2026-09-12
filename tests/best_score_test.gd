extends SceneTree

## Dauerhafter Bestwert: prueft, dass der Wert ein Neuladen WIRKLICH uebersteht.
##
## Der entscheidende Test ist `_test_survives_reload()`: er legt ein zweites
## Store-Objekt auf dieselbe Datei — genau das passiert beim Neuladen der Seite
## — und prueft, dass der Wert dort ankommt. Ein Test, der nur `save` und
## `load` auf demselben Objekt faehrt, wuerde einen Fehler in der Speicherung
## nicht bemerken.
##
## Aufruf: godot4 --headless --audio-driver Dummy --path . -s tests/best_score_test.gd

const JumpConfig = preload("res://scripts/jump/jump_config.gd")

## Eigene Datei je Lauf: der echte Spielstand darf nicht angefasst werden, und
## ein Rest aus einem frueheren Lauf darf das Ergebnis nicht verfaelschen.
const TEST_PATH := "user://best_score_test.cfg"

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await _test_empty_start()
	await _test_survives_reload()
	await _test_store_is_a_dumb_writer()
	await _test_zero_is_never_stored()
	await _test_broken_file_is_survivable()
	await _test_record_survives_reload()
	await _test_reset_keeps_durable_best()
	await _test_plain_record_has_no_store()
	await _test_game_wires_the_store()
	await _test_script_run_never_touches_the_real_save()
	_remove_test_file()
	print("BESTWERT: ALLE OK" if failures == 0 else "BESTWERT: %d FEHLER" % failures)
	quit(1 if failures > 0 else 0)

## Ohne gespeicherten Wert ist der Bestwert 0 — nicht irgendein Zufallswert.
func _test_empty_start() -> void:
	_remove_test_file()
	var store := BestScoreStore.new(TEST_PATH)
	_check(store.load_best() == 0, "eine frische Datei liefert 0")

## Der Kern: ein ZWEITES Store-Objekt auf derselben Datei — das ist das
## Neuladen. Ohne diesen Test bliebe eine kaputte Speicherung unbemerkt.
func _test_survives_reload() -> void:
	_remove_test_file()
	var first := BestScoreStore.new(TEST_PATH)
	first.save_best(1234)

	var after_reload := BestScoreStore.new(TEST_PATH)
	_check(after_reload.load_best() == 1234, "der Wert ueberlebt ein neues Store-Objekt")

## Der Store ist ein reiner Schreiber: er schreibt, was ihm gesagt wird.
## Die Regel "nur ein besserer Wert ersetzt den Bestwert" gehoert zu RunRecord
## und wird dort geprueft — zwei Stellen fuer dieselbe Regel wuerden
## auseinanderdriften.
func _test_store_is_a_dumb_writer() -> void:
	_remove_test_file()
	var store := BestScoreStore.new(TEST_PATH)
	store.save_best(900)
	store.save_best(400)
	_check(BestScoreStore.new(TEST_PATH).load_best() == 400, "der Store schreibt genau den uebergebenen Wert")
	store.save_best(1500)
	_check(BestScoreStore.new(TEST_PATH).load_best() == 1500, "und ersetzt ihn beim naechsten Schreiben")

## 0 ist die Bedeutung von "nichts gespeichert". Ein solcher Eintrag waere
## Ballast und wuerde beim Laden als "kein Bestwert" gelesen.
func _test_zero_is_never_stored() -> void:
	_remove_test_file()
	var store := BestScoreStore.new(TEST_PATH)
	store.save_best(0)
	_check(not FileAccess.file_exists(TEST_PATH), "0 legt keine Datei an")
	store.save_best(700)
	store.save_best(0)
	_check(BestScoreStore.new(TEST_PATH).load_best() == 700, "0 loescht einen vorhandenen Bestwert nicht")
	store.save_best(-50)
	_check(BestScoreStore.new(TEST_PATH).load_best() == 700, "ein negativer Wert aendert nichts")

## Eine defekte oder fremde Datei darf das Spiel nicht blockieren.
func _test_broken_file_is_survivable() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	# Bewusst Muell statt eines ConfigFile: eine fremde oder halb geschriebene
	# Datei muss genauso gutmuetig behandelt werden.
	file.store_string("kein config-file\nkaputt %% [unlesbar")
	file.close()
	_check(BestScoreStore.new(TEST_PATH).load_best() == 0, "eine defekte Datei liefert 0 statt abzustuerzen")

	# Und muss danach wieder benutzbar sein.
	var store := BestScoreStore.new(TEST_PATH)
	store.save_best(555)
	_check(BestScoreStore.new(TEST_PATH).load_best() == 555, "nach der defekten Datei laesst sich wieder speichern")

## RunRecord mit Store: der Bestwert steht schon beim Start bereit.
func _test_record_survives_reload() -> void:
	_remove_test_file()
	var first := RunRecord.new(BestScoreStore.new(TEST_PATH))
	_check(not first.finish_run(800), "der erste Lauf meldet keinen Rekord")
	_check(first.best == 800, "der erste Lauf setzt den Bestwert")

	# Neuladen: neuer Store, neuer Datensatz — der Bestwert muss da sein.
	var after_reload := RunRecord.new(BestScoreStore.new(TEST_PATH))
	_check(after_reload.best == 800, "der Bestwert steht nach dem Neuladen bereit")
	_check(after_reload.last == 0, "der letzte Lauf ist NICHT dauerhaft (nur die Sitzung)")
	_check(not after_reload.finish_run(500), "ein schwaecheres Ergebnis ist kein Rekord")
	_check(after_reload.finish_run(900), "ein hoeheres Ergebnis ist ein Rekord, auch gegen den gespeicherten Wert")
	_check(BestScoreStore.new(TEST_PATH).load_best() == 900, "der Rekord wird sofort gespeichert")

## `reset()` setzt nur den Sitzungszustand zurueck. Wuerde es den Bestwert
## loeschen, waere die ganze Speicherung sinnlos.
func _test_reset_keeps_durable_best() -> void:
	_remove_test_file()
	var record := RunRecord.new(BestScoreStore.new(TEST_PATH))
	record.finish_run(650)
	record.reset()
	_check(record.last == 0, "reset loescht den letzten Lauf")
	_check(record.best == 650, "reset behaelt den Bestwert im Speicher")
	_check(BestScoreStore.new(TEST_PATH).load_best() == 650, "reset loescht ihn auch nicht aus der Speicherung")

## Ohne Store arbeitet RunRecord rein im Speicher — das ist der Standard fuer
## Tests und darf keinen Seiteneffekt haben.
func _test_plain_record_has_no_store() -> void:
	_remove_test_file()
	var plain := RunRecord.new()
	plain.finish_run(321)
	_check(plain.best == 321, "ohne Store arbeitet der Datensatz im Speicher")
	_check(not FileAccess.file_exists(TEST_PATH), "ohne Store entsteht keine Datei")

## Das Spiel muss einen echten Store verdrahtet haben, sonst ist die ganze
## Phase wirkungslos — der Bestwert waere wieder nur fuer die Sitzung.
func _test_game_wires_the_store() -> void:
	var Game = load("res://scripts/game/game.gd")
	var game = Game.new()
	root.add_child(game)
	await process_frame
	_check(game.score_store != null and game.score_store is BestScoreStore, "das Spiel haelt einen BestScoreStore")
	_check(game.run_record != null, "das Spiel haelt einen RunRecord")
	_check(game.run_record._store == game.score_store, "der Datensatz nutzt genau diesen Store")
	_check(game.score_store._path == BestScoreStore.DEFAULT_PATH, "das Spiel speichert am Standardpfad")
	game.queue_free()
	await process_frame

func _remove_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

## Tests und QA erzeugen echte `Game`-Instanzen (ueber 20 Stellen). Ohne diese
## Absicherung schriebe jeder Testlauf in den echten Spielstand, und das
## Ergebnis haenge davon ab, welche Suite vorher lief. Geprueft wird hier der
## STANDARDPFAD, nicht die Testdatei: nur er ist betroffen.
##
## Das Merkmal ist der Skript-Parameter `-s`, NICHT "headless": QA-Proben
## laufen mit echtem Fenster. Genau dieser Fall ist in
## `qa/score_persistence_probe.gd` separat abgedeckt.
func _test_script_run_never_touches_the_real_save() -> void:
	_check(OS.get_cmdline_args().has("-s"), "dieser Lauf ist ein Skriptlauf (sonst prueft der Test nichts)")

	var real_path := BestScoreStore.DEFAULT_PATH
	var had_file := FileAccess.file_exists(real_path)
	var preexisting := -1
	if had_file:
		preexisting = BestScoreStore.new(real_path).load_best()

	var store := BestScoreStore.new()
	_check(store._is_detached_run(), "der Standardpfad gilt im Skriptlauf als abgekoppelt")
	_check(store.load_best() == 0, "der Skriptlauf liest den echten Spielstand nicht")
	store.save_best(9999)

	if had_file:
		_check(BestScoreStore.new(real_path).load_best() == preexisting,
			"der vorhandene echte Spielstand bleibt unveraendert")
	else:
		_check(not FileAccess.file_exists(real_path), "der Skriptlauf legt den echten Spielstand nicht an")

	# Und die Gegenprobe: ein ausdruecklich uebergebener Pfad schreibt sehr wohl.
	_check(not BestScoreStore.new(TEST_PATH)._is_detached_run(),
		"ein eigener Pfad ist NICHT abgekoppelt, die echte Speicherung wird weiter geprueft")

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ✓ " + description)
		return
	failures += 1
	print("  ✗ " + description)
