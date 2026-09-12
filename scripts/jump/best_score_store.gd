class_name BestScoreStore
extends RefCounted
## Dauerhafter Bestwert, der ein Neuladen der Seite uebersteht.
##
## Zwei Wege, weil die Plattformen sich grundlegend unterscheiden:
##
## - **Web:** `localStorage`. Bewusst NICHT `user://`. Godot legt `user://` im
##   Browser erst bei einem `FS.syncfs()` in die IndexedDB — ein Vorgang, den
##   die Engine nicht zuverlaessig vor dem Schliessen des Tabs ausfuehrt. Ein
##   Bestwert, der genau dann entsteht, wenn der Spieler aufhoert, wuerde also
##   ausgerechnet im haeufigsten Fall verloren gehen. `localStorage.setItem()`
##   ist synchron und sofort dauerhaft. Preis: ein privater Tab oder
##   blockierte Cookies lassen das Schreiben scheitern — deshalb sind beide
##   Zugriffe in `try/catch` gefasst, ein Fehler kostet nur den Bestwert.
## - **Ueberall sonst:** `ConfigFile` unter `user://`.
##
## Der Pfad ist ein Parameter, damit Tests und QA in eine eigene Datei
## schreiben und nicht in den echten Spielstand. Auf Web ist er ohne Wirkung.

## Schluessel im localStorage und gleichzeitig Namensraum des Spiels.
const KEY := "kernwerk.best_score"
const DEFAULT_PATH := "user://progress.cfg"
const SECTION := "progress"
const FIELD := "best_score"

var _path: String

func _init(path := DEFAULT_PATH) -> void:
	_path = path

## Laeuft dieses Programm als Test- oder QA-Skript statt als echtes Spiel?
##
## Tests und QA erzeugen echte `Game`-Instanzen (ueber 20 Stellen). Ohne diese
## Unterscheidung schriebe jeder Testlauf in den ECHTEN Spielstand, und das
## Ergebnis haenge davon ab, welche Suite vorher lief.
##
## Das Merkmal ist der Skript-Parameter: `godot4 -s tests/x.gd` bzw.
## `--script`. Das echte Spiel startet seine Hauptszene ohne ihn — belegt per
## Probe, dass `-s` unabhaengig vom DisplayServer in der Kommandozeile steht.
## Eine Pruefung auf `headless` allein genuegt NICHT: QA-Skripte laufen mit
## echtem Fenster (430x932) und wuerden den Spielstand sonst ueberschreiben.
##
## Nur der Standardpfad ist betroffen. Tests und QA, die bewusst einen eigenen
## Pfad uebergeben, laufen normal und pruefen damit die echte Speicherung.
func _is_detached_run() -> bool:
	if _path != DEFAULT_PATH:
		return false
	var args := OS.get_cmdline_args()
	return args.has("-s") or args.has("--script")

## Liest den gespeicherten Bestwert. 0 heisst: nichts gespeichert, unlesbar
## oder unbrauchbar. Ein kaputter Eintrag darf das Spiel nie blockieren.
func load_best() -> int:
	if _is_web():
		return _load_web()
	if _is_detached_run():
		return 0
	return _load_file()

## Schreibt den Bestwert. Werte <= 0 werden ignoriert: 0 ist die Bedeutung von
## "noch nichts gespeichert", ein solcher Eintrag waere nur Ballast.
func save_best(value: int) -> void:
	if value <= 0:
		return
	if _is_web():
		_save_web(value)
		return
	if _is_detached_run():
		return
	_save_file(value)

func _is_web() -> bool:
	return OS.has_feature("web")

func _load_web() -> int:
	# Der Ausnahmefall wird in JavaScript abgefangen: ein privater Tab oder
	# blockierte Cookies lassen den Zugriff scheitern, ohne das Spiel zu stoeren.
	var raw = JavaScriptBridge.eval(
		"(function(){try{return window.localStorage.getItem('%s');}catch(e){return null;}})()" % KEY,
		true)
	if raw == null:
		return 0
	var text := str(raw).strip_edges()
	if not text.is_valid_int():
		return 0
	var value := int(text)
	return value if value > 0 else 0

func _save_web(value: int) -> void:
	JavaScriptBridge.eval(
		"(function(){try{window.localStorage.setItem('%s','%d');}catch(e){}})()" % [KEY, value],
		true)

func _load_file() -> int:
	var config := ConfigFile.new()
	if config.load(_path) != OK:
		return 0
	var value := int(config.get_value(SECTION, FIELD, 0))
	return value if value > 0 else 0

func _save_file(value: int) -> void:
	var config := ConfigFile.new()
	# Ein Ladefehler ist der Normalfall beim ersten Start und wird bewusst
	# ignoriert: die Datei wird gleich neu geschrieben. Eine defekte Datei
	# wird damit ebenfalls ersetzt statt sie zu blockieren.
	config.load(_path)
	config.set_value(SECTION, FIELD, value)
	config.save(_path)
