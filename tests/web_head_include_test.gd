extends SceneTree

## Haelt den iOS-Tonblock und die Exportkonfiguration zusammen.
##
## Warum das noetig ist: `html/head_include` erwartet den WOERTLICHEN HTML-Text,
## keinen Dateipfad. Die lesbare Quelle liegt in
## `tools/web/ios_audio_head_include.html`, in der Konfiguration steht sie
## maskiert in einer Zeile. Ohne diese Pruefung koennte jemand den Block
## aendern, `tools/apply_head_include.py` vergessen — und der Export fiele still
## auf den alten Stand zurueck. Das ist genau die Fehlerklasse, die hier schon
## mehrfach Zeit gekostet hat.

const SOURCE_PATH := "res://tools/web/ios_audio_head_include.html"
const PRESETS_PATH := "res://export_presets.cfg"
const TOKEN := "html/head_include="

var failures := 0

func _init() -> void:
	_test_source_exists()
	_test_presets_match_source()
	_test_block_has_the_essential_parts()
	_test_not_a_file_path()
	print("IOS-TONBLOCK: ALLE OK" if failures == 0 else "IOS-TONBLOCK: %d FEHLER" % failures)
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("  FEHLER: %s" % message)

func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text

## Dieselbe Maskierung wie in `tools/apply_head_include.py`. Beide Stellen
## muessen uebereinstimmen; laufen sie auseinander, meldet der Test das.
func _encode(text: String) -> String:
	return text.strip_edges(false, true).replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")

func _test_source_exists() -> void:
	var source := _read(SOURCE_PATH)
	_check(not source.is_empty(), "die lesbare Quelle existiert und ist nicht leer")

func _test_presets_match_source() -> void:
	var source := _read(SOURCE_PATH)
	var presets := _read(PRESETS_PATH)
	_check(not presets.is_empty(), "export_presets.cfg ist lesbar")
	if source.is_empty() or presets.is_empty():
		return
	var expected := TOKEN + "\"" + _encode(source) + "\""
	var lines := presets.split("\n")
	var found := ""
	for line in lines:
		if line.begins_with(TOKEN):
			found = line.replace("\r", "")
			break
	_check(not found.is_empty(), "die Konfiguration hat eine head_include-Zeile")
	if found.is_empty():
		return
	_check(found == expected,
		"die Konfiguration entspricht der Quelle — sonst 'python3 tools/apply_head_include.py' laufen lassen")

## Die entscheidenden Teile des Blocks. Eine leere oder verstuemmelte Datei
## waere sonst formal "gleich" und trotzdem wirkungslos.
## Kommentare entfernen. Ohne das findet eine Pruefung auf "playback" auch das
## Wort im erklaerenden Kommentar — die Mutation "Kategorie wird nicht gesetzt"
## blieb damit gruen (gemessen).
func _code_only(source: String) -> String:
	var without_block := ""
	var index := 0
	while true:
		var start := source.find("/*", index)
		if start < 0:
			without_block += source.substr(index)
			break
		without_block += source.substr(index, start - index)
		var end := source.find("*/", start)
		if end < 0:
			break
		index = end + 2
	var lines := without_block.split("\n")
	var kept: Array[String] = []
	for line in lines:
		var comment := line.find("//")
		kept.append(line if comment < 0 else line.substr(0, comment))
	return "\n".join(kept)

## Geprueft wird der CODE, nicht der Text. Beide Richtungen: erst ohne
## Kommentare, dann muss wenigstens eine Zeile die Kategorie wirklich setzt.
func _test_block_has_the_essential_parts() -> void:
	var source := _read(SOURCE_PATH)
	var code := _code_only(source)
	_check(code.contains("navigator.audioSession"), "der Block nutzt die Audio-Session-Schnittstelle")
	_check(code.contains("audioSession.type") and code.contains("playback"),
		"der Block SETZT die Medien-Kategorie (sonst bleibt der Stummschalter wirksam)")
	_check(not code.contains("ambient"), "der Block setzt nicht die stummschalterabhaengige Kategorie")
	_check(code.contains("isIOS"), "der Block greift nur auf iOS ein")
	_check(code.contains("iPad|iPhone|iPod"), "die iOS-Erkennung prueft die Kennung")
	_check(code.contains("maxTouchPoints"), "iPadOS wird ueber die Touchpunkte erkannt")
	_check(code.contains("createElement"), "fuer aeltere iOS-Versionen gibt es den Umweg ueber ein stilles Element")
	_check(code.contains("data:audio/wav;base64,"), "das stille Element hat eine eingebettete Quelle")
	_check(code.contains(".play()"), "das stille Element wird gestartet")
	_check(code.contains("catch"), "das Abspielen ist abgesichert")
	_check(code.contains("addEventListener"), "der Nachzieh-Pfad haengt an einer Beruehrung")

## Eine Pfadangabe waere die Falle: Godot schreibt sie woertlich ins HTML,
## statt die Datei einzubetten (gemessen am 14.09.2026).
func _test_not_a_file_path() -> void:
	var presets := _read(PRESETS_PATH)
	var lines := presets.split("\n")
	for line in lines:
		if line.begins_with(TOKEN):
			var value := line.substr(TOKEN.length())
			_check(not value.contains(".html\""),
				"die Konfiguration enthaelt den Block selbst, keinen Dateipfad")
			_check(value.contains("<script>"), "der Block ist HTML")
			return
