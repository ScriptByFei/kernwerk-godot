extends SceneTree

## Klangbett: prueft die Verdrahtung, nicht nur den Zustand.
##
## Der wichtigste Check ist die PAUSEN-Gegenprobe. Eine Pruefung "waehrend der
## Pause laeuft noch Musik" waere wertlos, wenn sie nicht zeigen kann, dass es
## OHNE die Einstellung NICHT so waere. Deshalb laufen zwei Spieler gegeneinander:
## einer wie im Spiel (PROCESS_MODE_ALWAYS), einer mit der Voreinstellung.

const Ambience = preload("res://scripts/jump/ambience_player.gd")
const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")

var failures := 0

func _init() -> void:
	await _test_allow_rule()
	await _test_mapping()
	await _test_streams_are_looped()
	await _test_pause_against_control()
	await _test_restart_resets_tension()
	await _test_players_survive_restart()
	# Vor dem Beenden warten: Godot gibt eine abgespielte OGG-Wiedergabe erst
	# nach rund sechs Bildern frei (gemessen). Ohne diese Wartezeit meldet der
	# Prozess "resources still in use" und der Gate wertet das als Fehler.
	for _index in range(10):
		await process_frame
	print("KLANGBETT: ALLE OK" if failures == 0 else "KLANGBETT: %d FEHLER" % failures)
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("  FEHLER: %s" % message)

## In einem Skriptlauf darf das Bett nicht von allein starten, sonst bleibt in
## JEDER Suite, die ein Game baut, eine offene OGG-Wiedergabe zurueck. Beide
## Richtungen werden geprueft — eine Regel, die nur "aus" kann, waere auch
## erfuellt, wenn das Bett nie liefe.
func _test_allow_rule() -> void:
	_check(Ambience.ambience_allowed(false, false), "im laufenden Spiel startet das Bett")
	_check(Ambience.ambience_allowed(false, true), "im laufenden Spiel auch mit Anforderung")
	_check(not Ambience.ambience_allowed(true, false), "in einem Skriptlauf bleibt es aus")
	_check(Ambience.ambience_allowed(true, true), "in einem Skriptlauf mit Anforderung startet es")

## Die Zuordnung Stufe -> Pegel. Ohne sie waere die Spannungsschicht entweder
## immer da oder nie zu hoeren.
func _test_mapping() -> void:
	_check(is_equal_approx(JumpConfig.ambience_tension_db(0), JumpConfig.AMBIENCE_SILENCE_DB),
		"Stufe 0 bedeutet Stille")
	var previous := JumpConfig.ambience_tension_db(1)
	_check(previous > JumpConfig.AMBIENCE_SILENCE_DB, "Stufe 1 ist hoerbar")
	for difficulty in range(2, JumpConfig.MAX_DIFFICULTY + 1):
		var current := JumpConfig.ambience_tension_db(difficulty)
		_check(current > previous, "Stufe %d ist lauter als Stufe %d" % [difficulty, difficulty - 1])
		previous = current
	_check(is_equal_approx(JumpConfig.ambience_tension_db(JumpConfig.MAX_DIFFICULTY), JumpConfig.AMBIENCE_TENSION_DB),
		"die hoechste Stufe erreicht genau den Hoechstpegel")
	# Ueber die hoechste Stufe hinaus darf es nicht weiter steigen.
	_check(is_equal_approx(JumpConfig.ambience_tension_db(JumpConfig.MAX_DIFFICULTY + 3), JumpConfig.AMBIENCE_TENSION_DB),
		"hoehere Werte als MAX_DIFFICULTY steigern nicht weiter")
	# Der Grundklang muss hörbar sein, aber nicht die Kontakttöne erschlagen.
	_check(JumpConfig.AMBIENCE_DB < 0.0 and JumpConfig.AMBIENCE_DB > -30.0,
		"der Grundklang liegt in einem hoerbaren Bereich")
	# Die Spannung darf das Bett NIE uebertönen. Der erste Entwurf endete 6 dB
	# darueber und war auf dem Telefon "zu penetrant und zu laut" (Timo,
	# 14.09.) — die Schicht uebernahm am Ende das Feld. Die Pruefung haelt die
	# Absicht fest, nicht nur die Zahlen: der Grundklang bleibt das Fundament.
	for difficulty in range(1, JumpConfig.MAX_DIFFICULTY + 1):
		var level := JumpConfig.ambience_tension_db(difficulty)
		_check(level < JumpConfig.AMBIENCE_DB,
			"Stufe %d bleibt unter dem Grundklang (%.1f < %.1f dB)" % [difficulty, level, JumpConfig.AMBIENCE_DB])
	# Hier stand zuerst eine Pruefung "Spannung leiser als der leiseste
	# Kontaktton". Sie war MEINE Erfindung, nicht aus Timos Rueckmeldung
	# abgeleitet, und hatte keine Grundlage: die Spannung ist ein DAUERKLANG,
	# die Kontaktoene sind kurze Impulse, die ueber ihre Flanke wahrgenommen
	# werden. Mit ihr haette die Spannung nur 4 dB Dynamik behalten. Eine
	# erfundene Regel zu erfuellen, indem man Zahlen verbiegt, belegt nichts.
	#
	# Der Aufbau muss frueh das meiste erreichen und dann ruhen. Linear baute er
	# sich ueber den GANZEN Lauf auf und klang am Ende penetrant.
	var half := JumpConfig.MAX_DIFFICULTY / 2
	var span := JumpConfig.AMBIENCE_TENSION_DB - JumpConfig.AMBIENCE_TENSION_LOW_DB
	var early := JumpConfig.ambience_tension_db(half + 1) - JumpConfig.AMBIENCE_TENSION_LOW_DB
	_check(early > span * 0.6,
		"zur Haelfte der Strecke ist der Grossteil des Anstiegs erreicht (%.1f von %.1f dB)" % [early, span])
	var late := JumpConfig.ambience_tension_db(JumpConfig.MAX_DIFFICULTY) - JumpConfig.ambience_tension_db(half + 1)
	_check(late < 3.0, "danach kommt kaum noch etwas dazu (%.1f dB)" % late)

## Beide Schichten MUESSEN schleifen. Godot importiert neue OGG-Dateien als
## loop=false; die Datei selbst ist nahtlos gebaut, aber ohne diesen Schalter
## reisst der Klang nach 40 s ab.
func _test_streams_are_looped() -> void:
	var world := Node2D.new()
	get_root().add_child(world)
	var ambience := Ambience.new()
	ambience.attach(world)
	# Erst ein Bild warten: vorher ist der Knoten nicht wirksam im Baum und
	# Godot lehnt das Abspielen mit "Playback can only happen when a node is
	# inside the scene tree" ab (gemessen).
	await process_frame
	_check(ambience.ready(), "beide Klaenge wurden geladen")
	ambience.play()
	if not ambience.ready():
		world.queue_free()
		await process_frame
		return
	_check(ambience.ambience_stream is AudioStreamOggVorbis, "der Grundklang ist ein OGG-Stream")
	_check(ambience.tension_stream is AudioStreamOggVorbis, "die Spannung ist ein OGG-Stream")
	var ambience_stream := ambience.ambience_stream as AudioStreamOggVorbis
	var tension_stream := ambience.tension_stream as AudioStreamOggVorbis
	_check(ambience_stream != null and ambience_stream.loop, "der Grundklang ist auf Schleife gestellt")
	_check(tension_stream != null and tension_stream.loop, "die Spannung ist auf Schleife gestellt")
	# Gleiche Laenge: sonst driften die Schichten mit jeder Runde auseinander.
	if ambience_stream != null and tension_stream != null:
		var difference := absf(ambience_stream.get_length() - tension_stream.get_length())
		_check(difference < 0.05, "beide Schichten sind gleich lang (Abweichung %.3f s)" % difference)
	# Gegenprobe zur Importpruefung: die Datei selbst sagt auch loop=true.
	var sidecar := FileAccess.open(JumpConfig.AMBIENCE_STREAM_PATH + ".import", FileAccess.READ)
	_check(sidecar != null, "die Importdatei ist lesbar")
	if sidecar != null:
		_check(sidecar.get_as_text().contains("loop=true"), "die Importdatei steht auf loop=true")
		sidecar.close()
	# Ressourcen ausdruecklich freigeben. Bleibt ein laufender Stream im Speicher,
	# meldet Godot beim Beenden "resources still in use" und der Gate wertet
	# jede zeilenanfaengliche ERROR-Zeile als Fehler — die Suite waere inhaltlich
	# gruen und trotzdem rot.
	ambience.stop()
	ambience.ambience_stream = null
	ambience.tension_stream = null
	world.free()
	# Zwei Bilder: ein abgespielter OGG-Stream wird erst danach freigegeben.
	# Mit nur einem Bild meldet Godot "resources still in use" (gemessen).
	for _index in range(4):
		await process_frame

## Der eigentliche Grund fuer PROCESS_MODE_ALWAYS: im pausierten Baum schweigt
## ein AudioStreamPlayer. Hier laufen beide Faelle gegeneinander.
func _test_pause_against_control() -> void:
	var world := Node2D.new()
	get_root().add_child(world)
	# WICHTIG: geprueft werden die Knoten, die die PRODUKTION anlegt — nicht
	# eigens im Test gebaute. Der erste Entwurf baute sich seine Spieler selbst
	# und blieb deshalb gruen, als `_make_player` die ALWAYS-Einstellung verlor.
	# Ein Test, der seine eigenen Vorgaben prueft, beweist nichts.
	var ambience := Ambience.new()
	ambience.attach(world)
	# Gegenprobe mit der VOREINSTELLUNG: das ist der Fall, der im Spiel NICHT
	# gilt. Ohne ihn koennte der Test nicht zeigen, dass er etwas misst.
	var control := AudioStreamPlayer.new()
	control.stream = load(JumpConfig.AMBIENCE_STREAM_PATH)
	world.add_child(control)
	await process_frame
	var bed := world.get_node_or_null("AmbienceAudio") as AudioStreamPlayer
	var tension := world.get_node_or_null("TensionAudio") as AudioStreamPlayer
	_check(bed != null, "der Grundklang-Knoten wird angelegt")
	_check(tension != null, "der Spannungsknoten wird angelegt")
	if bed == null or tension == null:
		world.free()
		return
	_check(bed.process_mode == Node.PROCESS_MODE_ALWAYS, "der Grundklang ist auf ALWAYS gestellt")
	_check(tension.process_mode == Node.PROCESS_MODE_ALWAYS, "die Spannung ist auf ALWAYS gestellt")
	ambience.play()
	control.play(0.0)
	await process_frame
	_check(bed.playing and control.playing, "beide spielen vor der Pause")
	get_root().get_tree().paused = true
	await process_frame
	await process_frame
	_check(bed.playing, "das Klangbett laeuft waehrend der Pause weiter")
	_check(not control.playing, "die Gegenprobe ohne ALWAYS verstummt in der Pause (sonst misst der Test nichts)")
	get_root().get_tree().paused = false
	ambience.shutdown()
	control.stop()
	control.stream = null
	world.free()
	for _index in range(4):
		await process_frame

## Ein Neustart darf die Atmosphaere nicht auf dem Stand der alten Runde
## stehen lassen.
func _test_restart_resets_tension() -> void:
	var game := Game.new()
	# Ohne diese Anforderung startet das Bett in einem Skriptlauf nicht — die
	# Pruefung soll aber den echten Startpfad fahren.
	game.run_ambience_in_tests = true
	get_root().add_child(game)
	await process_frame
	_check(game.ambience != null and game.ambience.ready(), "das Spiel legt das Klangbett an")
	# Der Start haengt im Spiel am ersten Spielzug (`_enter_playing`). Hier wird
	# derselbe oeffentliche Pfad gerufen, den das Spiel dort benutzt.
	_check(not game.ambience.is_playing(), "vor dem ersten Spielzug ist das Bett still (Web-Audio braucht eine Beruehrung)")
	game.start_ambience()
	if game.ambience == null or not game.ambience.ready():
		game.free()
		await process_frame
		return
	_check(game.ambience.is_playing(), "das Klangbett laeuft ab dem Start")
	_check(game.ambience.tension_target_db() == JumpConfig.AMBIENCE_SILENCE_DB,
		"die Spannung startet still (Zielpegel)")
	# Auch der TATSAECHLICHE Pegel muss still sein. Das Ziel allein zu pruefen
	# genuegt nicht: eine Aenderung an `play()` bliebe damit unsichtbar.
	_check(game.ambience.tension_volume_db() == JumpConfig.AMBIENCE_SILENCE_DB,
		"die Spannung ist zu Beginn auch tatsaechlich nicht zu hoeren")
	# Eine Weile spielen: die Spannung muss mit der Stufe steigen.
	# ACHTUNG: `score` ist abgeleitet. `_update_score` rechnet ihn aus `_highest_y`
	# neu, ein direkt gesetztes `score` wird sofort ueberschrieben. Die Hoehe ist
	# deshalb die Stellschraube — 3 * DIFFICULTY_STEP_HEIGHT.
	game._phase = Game.Phase.PLAYING
	# Die Schwierigkeit haengt seit dem Tempoumbau an der HOEHE
	# (DIFFICULTY_STEP_HEIGHT), nicht mehr am Punktestand.
	game._highest_y -= 3.0 * JumpConfig.DIFFICULTY_STEP_HEIGHT
	game._update_score()
	_check(game.difficulty == 3, "die Schwierigkeit steht auf 3 (Ist: %d)" % game.difficulty)
	_check(game.ambience.tension_target_db() > JumpConfig.AMBIENCE_SILENCE_DB,
		"mit steigender Schwierigkeit wird die Spannung angesteuert")
	var raised: float = game.ambience.tension_target_db()
	game._restart(true)
	# OHNE await: der Rueckfall muss Teil des Neustarts sein, nicht erst beim
	# naechsten `_process` nachkommen. Mit einem Bild dazwischen waere die
	# Pruefung blind — `_process` setzt den Wert naemlich von selbst zurueck.
	_check(game.ambience.tension_target_db() == JumpConfig.AMBIENCE_SILENCE_DB,
		"der Neustart setzt die Atmosphaere sofort zurueck (war vorher %.1f dB)" % raised)
	await process_frame
	_check(game.difficulty == 0, "der Neustart setzt die Schwierigkeit zurueck")
	_check(game.ambience.is_playing(), "nach dem Neustart laeuft das Klangbett wieder")
	game.ambience.stop()
	game.free()
	await process_frame
	await process_frame

## Die beiden Spieler haengen am SPIEL, nicht am Springer oder an der Kamera.
## Ein Neustart zerstoert Springer und Kamera (`jumper.free()`); haenge das Bett
## dort, waere die Atmosphaere nach dem ersten Absturz dauerhaft weg. Das ist
## ein echter Regressionspfad, kein Selbstzweck.
func _test_players_survive_restart() -> void:
	var game := Game.new()
	game.run_ambience_in_tests = true
	get_root().add_child(game)
	await process_frame
	game.start_ambience()
	await process_frame
	var ambience_node := game.get_node_or_null("AmbienceAudio")
	var tension_node := game.get_node_or_null("TensionAudio")
	_check(ambience_node != null, "der Grundklang haengt am Spiel")
	_check(tension_node != null, "die Spannung haengt am Spiel")
	# Gegenprobe: sie haengen NICHT unter dem Springer, der beim Neustart faellt.
	if ambience_node != null and game.jumper != null:
		_check(not game.jumper.is_ancestor_of(ambience_node),
			"das Klangbett haengt nicht unter dem Springer (der beim Neustart zerstoert wird)")
	game._restart(true)
	await process_frame
	_check(is_instance_valid(ambience_node) and ambience_node.is_inside_tree(),
		"nach dem Neustart existieren die Klangknoten noch")
	var playing := is_instance_valid(ambience_node) and (ambience_node as AudioStreamPlayer).playing
	_check(playing, "und der Grundklang laeuft weiter")
	game.free()
	for _index in range(4):
		await process_frame
