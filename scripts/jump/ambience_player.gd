extends RefCounted
## Atmosphaerisches Klangbett des Reaktorschachts.
##
## Zwei Schichten, beide 40 s lang und damit sample-genau synchron:
## `shaft_ambience` laeuft immer, `shaft_tension` liegt darueber und schwillt
## mit der Schwierigkeit an. Beide sind prozedural erzeugt
## (`tools/make_ambience.py`) und ausdruecklich auf eine NAHTLOSE Schleife
## ausgelegt — die Schleife funktioniert nur, wenn der Import auf `loop=true`
## steht. Godot legt neu importierte OGG-Dateien als `loop=false` an, deshalb
## ist das im Test verankert und nicht nur im Editor gesetzt.
##
## Warum ein eigener Knoten mit PROCESS_MODE_ALWAYS:
## Ein AudioStreamPlayer im pausierten Baum schweigt. Das Bett soll waehrend
## der Pause aber weiterlaufen, sonst reisst der Raum bei jedem Pausentipp ab.
## Die Steuerung liegt an EINER Stelle, damit Spiel und Neustart nie
## auseinanderlaufen.
##
## Kein Verstaerker-Bus: Web-Audio braucht ohnehin einen echten Treffer zum
## Entsperren, und ein eigener Bus muesste in `default_bus_layout.tres`
## gepflegt werden. Die Balance steht in den beiden Lautstaerken.

const JumpConfig = preload("res://scripts/jump/jump_config.gd")

## Fadezeiten laufen mit TWEEN_PAUSE_PROCESS gegen den pausierten Baum, sonst
## friert eine Ueberblendung ein, sobald der Spieler pausiert.
var ambience_stream: AudioStream
var tension_stream: AudioStream
var _ambience: AudioStreamPlayer
var _tension: AudioStreamPlayer
var _fade_tween: Tween
var _tension_target_db := JumpConfig.AMBIENCE_SILENCE_DB

## Startet das Bett in einem Testlauf von allein?
##
## Gemessen: Godot gibt eine abgespielte OGG-Wiedergabe erst nach rund sechs
## Bildern frei — unabhaengig davon, ob vorher `stop()` lief oder der Knoten
## entfernt wurde. Eine Testsuite, die danach sofort `quit()` ruft, hinterlaesst
## sie deshalb offen, Godot meldet beim Prozessende "resources still in use",
## und der Gate wertet jede zeilenanfaengliche ERROR-Zeile als Fehler. Betroffen
## waere JEDE Suite, die ein `Game` baut, nicht nur die des Klangbetts.
##
## Deshalb dieselbe Konvention wie bei `BestScoreStore`: in einem Skriptlauf
## (`-s`) bleibt das Bett aus, sofern es nicht ausdruecklich angefordert wird.
## Pruefungen fahren den echten Pfad ueber `game.start_ambience()`.
##
## Die Entscheidung ist absichtlich eine reine Funktion, damit beide Richtungen
## pruefbar sind, ohne die Kommandozeile nachzustellen.
static func ambience_allowed(runs_as_script: bool, opted_in: bool) -> bool:
	return (not runs_as_script) or opted_in

## Baut die beiden Spieler unter `parent`. Fehlt eine Datei, bleibt das Bett
## still statt abzustuerzen — ein fehlendes Asset darf das Spiel nicht kippen.
func attach(parent: Node) -> void:
	if ambience_stream == null:
		ambience_stream = load(JumpConfig.AMBIENCE_STREAM_PATH)
	if tension_stream == null:
		tension_stream = load(JumpConfig.AMBIENCE_TENSION_STREAM_PATH)
	if ambience_stream == null or tension_stream == null:
		push_warning("Klangbett: Audiodatei fehlt, Atmosphaere bleibt aus")
		return
	_ambience = _make_player(parent, "AmbienceAudio", ambience_stream, JumpConfig.AMBIENCE_DB)
	_tension = _make_player(parent, "TensionAudio", tension_stream, JumpConfig.AMBIENCE_SILENCE_DB)

func _make_player(parent: Node, node_name: String, stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.stream = stream
	player.volume_db = volume_db
	# Ohne ALWAYS schweigt das Bett, sobald `get_tree().paused` gesetzt ist.
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(player)
	return player

func ready() -> bool:
	return _ambience != null and _tension != null

func is_playing() -> bool:
	if not ready():
		return false
	return _ambience.playing and _tension.playing

## Startet beide Schichten. Die Spannung beginnt bei Stille und wird
## ausschliesslich ueber `set_difficulty` geoeffnet — sonst waere sie in der
## ersten Sekunde lauter als im ganzen ersten Abschnitt.
##
## `play(0.0)` setzt die Schleife an den Anfang. Das ist fuer die zweite Runde
## nach einem Neustart wichtig: die Spannung stand am Ende des letzten Laufs
## auf ihrem Hoechstwert, und ein Fortsetzen ab der alten Position klaenge in
## der neuen Runde sofort nach Endphase.
func play() -> void:
	if not ready():
		return
	_stop_tween()
	_tension_target_db = JumpConfig.AMBIENCE_SILENCE_DB
	_ambience.volume_db = JumpConfig.AMBIENCE_DB
	_ambience.play(0.0)
	_tension.volume_db = JumpConfig.AMBIENCE_SILENCE_DB
	_tension.play(0.0)

func stop() -> void:
	_stop_tween()
	if _ambience != null:
		_ambience.stop()
	if _tension != null:
		_tension.stop()

## Haelt an UND gibt die Knoten frei. `stop()` allein genuegt nicht: eine
## abgespielte OGG-Wiedergabe wird erst freigegeben, wenn der Knoten wirklich
## entfernt ist. Solange sie haengt, meldet Godot beim Prozessende
## "resources still in use" — und der Gate wertet jede zeilenanfaengliche
## ERROR-Zeile als Fehler. Beim Verlassen des Spielbaums ist das der
## Unterschied zwischen gruen und rot.
func shutdown() -> void:
	stop()
	_free_player(_ambience)
	_free_player(_tension)
	_ambience = null
	_tension = null

func _free_player(player: AudioStreamPlayer) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.stream = null
	var parent := player.get_parent()
	if parent != null:
		parent.remove_child(player)
	player.free()

## Schwierigkeit (0..MAX_DIFFICULTY) steuert die Spannungsschicht. Der Wert
## kommt aus derselben Quelle wie die Plattformgenerierung, damit Klang und
## Anspruch nicht auseinanderlaufen.
func set_difficulty(difficulty: int, fade := true) -> void:
	if not ready():
		return
	var target := JumpConfig.ambience_tension_db(difficulty)
	if is_equal_approx(target, _tension_target_db):
		return
	_tension_target_db = target
	_stop_tween()
	if not fade or JumpConfig.AMBIENCE_TENSION_FADE <= 0.0:
		_tension.volume_db = target
		return
	_fade_tween = _tension.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(_tension, "volume_db", target, JumpConfig.AMBIENCE_TENSION_FADE)

func tension_volume_db() -> float:
	if _tension == null:
		return JumpConfig.AMBIENCE_SILENCE_DB
	return _tension.volume_db

func tension_target_db() -> float:
	return _tension_target_db

func _stop_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
