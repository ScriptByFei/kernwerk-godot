extends SceneTree

## DIVE: aktive Beeinflussung des Landungszeitpunkts.
##
## Geprueft werden die vier Bedingungen aus der Aufgabe, jede einzeln:
##   1. nur waehrend der FALLPHASE
##   2. hoechstens EINMAL je Sprung, nach der Landung wieder verfuegbar
##   3. keine Fehlausloesung durch normales waagerechtes Ziehen
##   4. waagerechte Steuerung bleibt waehrend des Dive erhalten
##
## Der Wisch wird ueber die ECHTE Eingabepipeline geschickt, nicht ueber einen
## direkten Methodenaufruf: eine Mechanik, die nur auf dem Papier funktioniert,
## aber nie durch den Input kommt, waere nicht abgenommen.

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const DiveInput = preload("res://scripts/jump/dive_input.gd")

var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_swipe_detection()
	_check_false_triggers()
	await _check_live_dive()
	await _check_dive_feedback_live()
	_finish()

## Baut ein Spiel und prueft die Kopplung der sichtbaren Rueckmeldung.
func _check_dive_feedback_live() -> void:
	var game := Game.new()
	get_root().add_child(game)
	await process_frame
	await process_frame
	check_dive_feedback(game)
	game.free()
	await process_frame

## --- Wisch-Erkennung: was zaehlt, was nicht --------------------------------
func _check_swipe_detection() -> void:
	var swipe := DiveInput.new()
	# Ein klarer, schneller Wisch nach unten.
	swipe.begin(Vector2(540.0, 400.0), 10.0)
	_check(swipe.update(Vector2(540.0, 500.0), 10.08), "ein schneller Wisch nach unten loest den Dive aus")
	# Zu kurz: ein Zucken ist kein Wisch.
	swipe.begin(Vector2(540.0, 400.0), 20.0)
	_check(not swipe.update(Vector2(540.0, 420.0), 20.05), "ein kurzes Zucken loest nichts aus")
	# Zu langsam: Herunterziehen zum Umzielen.
	swipe.begin(Vector2(540.0, 400.0), 30.0)
	_check(not swipe.update(Vector2(540.0, 520.0), 30.8), "ein langsames Herunterziehen loest nichts aus")
	# Gleitendes Fenster: nach dem langsamen Zug muss ein Wisch wieder gehen.
	_check(swipe.update(Vector2(540.0, 600.0), 30.9), "nach dem langsamen Zug ist ein Wisch wieder moeglich")
	# Waagerecht: kein Dive, egal wie schnell.
	swipe.begin(Vector2(200.0, 400.0), 40.0)
	_check(not swipe.update(Vector2(600.0, 400.0), 40.05), "ein waagerechter Zug loest keinen Dive aus")

## --- Keine Fehlausloesung durch normales Ziehen -----------------------------
##
## Das ist die wichtigste Eigenschaft: der Spieler zieht STAENDIG waagerecht, und
## dabei fast immer auch ein Stueck nach unten. Wuerde das einen Dive ausloesen,
## waere die Steuerung unbrauchbar.
func _check_false_triggers() -> void:
	var false_triggers := 0
	var trials := 0
	# Realistische Umziel-Zuege: schnell (kurzes Zeitfenster), ueberwiegend
	# waagerecht, mit dem ueblichen Absinken der Hand.
	for dx in [-320.0, -180.0, -60.0, 60.0, 180.0, 320.0]:
		for dy in [-40.0, -10.0, 0.0, 20.0, 45.0, 60.0]:
			for elapsed in [0.03, 0.06, 0.10, 0.18]:
				var swipe := DiveInput.new()
				swipe.begin(Vector2(540.0, 500.0), 0.0)
				trials += 1
				if swipe.update(Vector2(540.0 + dx, 500.0 + dy), elapsed):
					false_triggers += 1
	_check(false_triggers == 0,
		"kein einziges normales Umzielen loest einen Dive aus (%d von %d)" % [false_triggers, trials])
	_check(trials >= 100, "es wurden genug Zuege geprueft (%d)" % trials)
	# Gegenprobe: ein echter Wisch MUSS durchkommen, sonst waere die Pruefung
	# durch ein kaputtes "nie ausloesen" erfuellbar.
	var swipe := DiveInput.new()
	swipe.begin(Vector2(540.0, 300.0), 0.0)
	_check(swipe.update(Vector2(540.0, 420.0), 0.05), "die Gegenprobe loest aus")
	# Die Dominanzregel allein reicht NICHT, um zu bestehen: ohne die
	# Mindeststrecke wuerde ein kurzer steiler Zug ausloesen.
	var shallow := DiveInput.new()
	shallow.begin(Vector2(540.0, 500.0), 0.0)
	_check(not shallow.update(Vector2(542.0, 530.0), 0.05),
		"ein kurzer steiler Zug unter der Mindeststrecke loest nicht aus")
	# ---------------------------------------------------------------------
	# REGRESSION: ein Umzielen MIT RICHTUNGSWECHSEL. Der Daumen faehrt nach
	# rechts und wieder zurueck; die Netto-Verschiebung nach rechts ist null,
	# nach unten bleibt etwas uebrig. Eine Dominanzregel auf der NETTO-
	# Verschiebung sah darin einen senkrechten Wisch und loeste aus — ein echter
	# Fehler, der im Betrieb die Steuerung unbrauchbar gemacht haette.
	#
	# Der Zug ist ausserdem ueber das GANZE Zeitfenster verteilt: auch die
	# Zeitbedingung allein darf ihn nicht durchlassen.
	# ---------------------------------------------------------------------
	var reversal := DiveInput.new()
	reversal.begin(Vector2(100.0, 400.0), 0.0)
	var reversal_fired := false
	var reversal_points := [Vector2(150.0, 406.0), Vector2(200.0, 412.0), Vector2(150.0, 418.0), Vector2(100.0, 426.0)]
	for index in reversal_points.size():
		if reversal.update(reversal_points[index], 0.05 * float(index + 1)):
			reversal_fired = true
	_check(not reversal_fired, "ein Umzielen mit Richtungswechsel loest nicht aus")
	# Gegenprobe: die waagerechte Bewegung dieses Zuges darf sich NICHT
	# wegkuerzen. Er ist 100 px nach rechts unterwegs (100 -> 200) und kehrt
	# dann zurueck. Wuerde nur die Netto-Verschiebung zaehlen, waere sie 0 —
	# und der Zug saehe rein senkrecht aus. Genau das war der Fehler.
	# Gemessen wird deshalb der aufsummierte waagerechte Weg.
	var reversal_travel: Vector2 = reversal.travel()
	_check(reversal_travel.x > reversal_travel.y * 4.0,
		"der waagerechte Weg des Umzielens bleibt erhalten (%.0f gegen %.0f px)"
			% [reversal_travel.x, reversal_travel.y])
	_check(reversal_travel.x > 80.0,
		"und er ist gross genug, um den Zug eindeutig als Umzielen zu erkennen (%.0f px)"
			% reversal_travel.x)
	# ---------------------------------------------------------------------
	# REGRESSION: ein Flick, der ZUF AELLIG UEBER DEN FENSTERWECHSEL faellt.
	#
	# Der Spieler steuert seit 0,24 s und zuckt dann nach unten. Ein
	# zurueckgesetzter Ursprung wirft beim Ablauf des Fensters die BIS DAHIN
	# aufgelaufene Wischstrecke weg — der Flick zerfaellt in zwei Teile, und
	# beide liegen unter der Mindeststrecke. Mit einem echten gleitenden Fenster
	# zaehlt der Weg der letzten 0,30 s und der Flick kommt durch.
	#
	# Die Zeitpunkte sind so gewaehlt, dass der Fensterwechsel GENAU in den
	# Flick faellt: sonst prueft der Fall nichts.
	# ---------------------------------------------------------------------
	var late := DiveInput.new()
	late.begin(Vector2(540.0, 300.0), 0.0)
	# 0,24 s ruhiges Steuern: kleine waagerechte Bewegung, kein Wisch.
	for step in range(1, 13):
		late.update(Vector2(540.0 + 2.0 * float(step), 300.0), 0.02 * float(step))
	# Dann ein Flick ueber 5 Bilder a 20 px = 100 px (ueber der Mindeststrecke),
	# verteilt von 0,26 s bis 0,34 s — also ueber die 0,30-s-Grenze hinweg.
	var late_fired := false
	for step in range(5):
		var t := 0.26 + 0.02 * float(step)
		if late.update(Vector2(540.0, 300.0 + 20.0 * float(step + 1)), t):
			late_fired = true
	_check(late_fired,
		"ein Flick ueber den Fensterwechsel hinweg wird erkannt (Weg %.0f px)"
			% late.travel(0.34).y)
	# Gegenprobe: derselbe Zug muss auf summiertem Weg eindeutig senkrecht sein.
	var late_travel: Vector2 = late.travel(0.34)
	_check(late_travel.y > late_travel.x * 1.6,
		"der Weg des Flicks ist senkrecht (%.0f gegen %.0f)" % [late_travel.y, late_travel.x])
	# Und die Gegenprobe zur Gegenprobe: wer nur langsam nach unten zieht,
	# loest auch nach dem Steuern nicht aus.
	var slow := DiveInput.new()
	slow.begin(Vector2(540.0, 300.0), 0.0)
	var slow_fired := false
	for step in range(20):
		var t := 0.05 * float(step + 1)
		if slow.update(Vector2(540.0, 300.0 + 12.0 * float(step + 1)), t):
			slow_fired = true
	_check(not slow_fired, "ein langsames Ziehen ueber eine Sekunde loest nicht aus")
	# ---------------------------------------------------------------------
	# REGRESSION (Review 4): an der FENSTERGRENZE muss auch der STARTPUNKT
	# interpoliert werden, nicht nur die Strecken.
	#
	# Die aufsummierten Strecken wurden schon beschnitten, `rise` und die
	# waagerechte Netto-Verschiebung rechneten aber weiter gegen die abgelaufene
	# Randprobe. Folge: ein Zug, der OBERHALB seines Fensterstarts endet, galt
	# als Wisch nach unten und feuerte.
	#
	# Verlauf aus dem Review: (0,0)@0 -> (200,200)@0,4 -> (0,60)@0,5. Zum
	# Zeitpunkt 0,5 liegt die Grenze bei 0,2, der wahre Startpunkt ist (100,100)
	# — die Bewegung endet also 40 px DARUEBER.
	# ---------------------------------------------------------------------
	var above_start := DiveInput.new()
	above_start.begin(Vector2(0.0, 0.0), 0.0)
	above_start.update(Vector2(200.0, 200.0), 0.4)
	var above_fired := above_start.update(Vector2(0.0, 60.0), 0.5)
	# Fuer die MESSUNG ein zweiter Detektor mit unerreichbarer Mindeststrecke:
	# der erste hat beim Ausloesen seinen Puffer geleert (richtiges Verhalten),
	# eine Messung danach waere immer null.
	var above_probe := DiveInput.new()
	above_probe.begin(Vector2(0.0, 0.0), 0.0)
	above_probe.update(Vector2(200.0, 200.0), 0.4)
	above_probe.update(Vector2(0.0, 60.0), 0.5, 100000.0)
	var above_measure: Dictionary = above_probe.measure(0.5, 0.30)
	_check(not above_fired,
		"ein Zug, der ueber seinem Fensterstart endet, loest nicht aus (rise %.0f, seitlich %.0f)"
			% [above_measure["rise"], above_measure["sideways"]])
	_check(above_measure["rise"] < 0.0,
		"und die Messung erkennt das auch (rise %.0f px gegen die abgelaufene Randprobe)"
			% above_measure["rise"])
	# ---------------------------------------------------------------------
	# REGRESSION (Review 4): die Gegenrichtung — ein echter, spaeter Haken darf
	# nicht an der unkorrigierten Randprobe scheitern.
	#
	# Verlauf aus dem Review: (0,0)@0 -> (160,0)@0,4 -> (160,100)@0,55. Zum
	# Zeitpunkt 0,55 liegt die Grenze bei 0,25 und der interpolierte Startpunkt
	# bei (100,0): 100 px nach unten, 60 px seitlich — ein gueltiger Wisch.
	# Gegen die Randprobe gerechnet waren es 156 px seitlich, und er fiel durch.
	# ---------------------------------------------------------------------
	var late_hook := DiveInput.new()
	late_hook.begin(Vector2(0.0, 0.0), 0.0)
	late_hook.update(Vector2(160.0, 0.0), 0.4)
	var hook_fired := late_hook.update(Vector2(160.0, 100.0), 0.55)
	var hook_probe := DiveInput.new()
	hook_probe.begin(Vector2(0.0, 0.0), 0.0)
	hook_probe.update(Vector2(160.0, 0.0), 0.4)
	hook_probe.update(Vector2(160.0, 100.0), 0.55, 100000.0)
	var hook_measure: Dictionary = hook_probe.measure(0.55, 0.30)
	_check(hook_measure["rise"] >= 80.0,
		"der spaete Haken kommt netto weit genug unten an (%.0f px)" % hook_measure["rise"])
	_check(hook_fired,
		"und ein spaeter Haken wird nicht mehr faelschlich abgewiesen (seitlich gegen Randprobe waere %.0f px, gegen Fensterstart %.0f px)"
			% [hook_measure["sideways_path"], hook_measure["sideways"]])
	# ---------------------------------------------------------------------
	# Die Dominanzregel muss ueberhaupt greifen: ein Zug, der genauso weit
	# seitlich wie nach unten geht, ist ein Umzielen und kein Wisch nach unten.
	# Ohne diese Pruefung faellt die Regel ersatzlos weg, ohne dass es auffaellt.
	# ---------------------------------------------------------------------
	var diagonal := DiveInput.new()
	diagonal.begin(Vector2(200.0, 400.0), 0.0)
	var diagonal_fired := false
	for step in range(1, 11):
		if diagonal.update(Vector2(200.0 + 24.0 * float(step), 400.0 + 8.0 * float(step)), 0.02 * float(step)):
			diagonal_fired = true
	var diagonal_measure: Dictionary = diagonal.measure()
	_check(not diagonal_fired,
		"ein breiter diagonaler Zug loest nicht aus (%.0f px nach unten, %.0f px seitlich)"
			% [diagonal_measure["down"], diagonal_measure["sideways"]])
	_check(diagonal_measure["down"] >= 80.0,
		"und er hat genug Strecke nach unten, um ohne Dominanzregel zu feuern (%.0f px)"
			% diagonal_measure["down"])
	# ---------------------------------------------------------------------
	# REGRESSION (Review 3): die Dominanz muss auf der NETTO-Verschiebung
	# beruhen, nicht auf der Summe der Abschnitte.
	#
	# Der Zickzack oben faellt schon durch die Netto-Bedingung nach unten auf und
	# kann diese Regel deshalb nicht isolieren. Dieser Zug dagegen ist ein echter
	# breiter Diagonalzug — weit unten angekommen —, nur in kleinen Stuecken
	# gezeichnet: waagerecht je 3 px (unter der Rauschschwelle von 4).
	#
	# Mit einer Schwelle JE ABSCHNITT traegt die waagerechte Bewegung dann NICHTS
	# bei, die Dominanz ist erfuellt, und der Zug feuert (nachgerechnet: 201 px
	# netto nach unten bei 201 px netto seitlich). Mit dem Netto-Wert wird er
	# korrekt abgewiesen.
	# ---------------------------------------------------------------------
	var fine_diagonal := DiveInput.new()
	fine_diagonal.begin(Vector2(540.0, 100.0), 0.0)
	var fine_fired := false
	for step in range(1, 68):
		var t: float = 0.005 * float(step)
		if fine_diagonal.update(Vector2(540.0 + 3.0 * float(step), 100.0 + 3.0 * float(step)), t):
			fine_fired = true
	var fine_measure: Dictionary = fine_diagonal.measure()
	_check(fine_measure["rise"] >= 150.0,
		"der fein gezeichnete Diagonalzug kommt wirklich weit unten an (%.0f px netto)"
			% fine_measure["rise"])
	_check(not fine_fired,
		"ein breiter Diagonalzug wird auch in kleinen Stuecken abgewiesen (%.0f px seitlich netto)"
			% fine_measure["sideways"])
	# ---------------------------------------------------------------------
	# REGRESSION (Review 3): ein WAAGERECHT GEZACKTER Zug loest nicht aus.
	#
	# Die Rauschschwelle je Abschnitt war ausnutzbar: liegen die waagerechten
	# Stuecke des Zickzacks einzeln unter der Schwelle, trugen sie NICHTS bei,
	# waehrend die senkrechten Stuecke sich aufaddierten. Nachgerechnet: 80 px
	# aufsummiert nach unten bei nur 21 px Netto-Abstieg — weit unter der
	# Mindeststrecke, und trotzdem feuerte es. Der Zug ist ausserdem ueber die
	# GANZE Breite unterwegs (93 px netto), also eindeutig kein Wisch nach unten.
	#
	# Deshalb zaehlt fuer die Entscheidung die NETTO-Verschiebung waagerecht.
	# ---------------------------------------------------------------------
	var sawtooth := DiveInput.new()
	sawtooth.begin(Vector2(0.0, 0.0), 0.0)
	var sawtooth_fired := false
	var zig_y := 0.0
	for index in range(1, 33):
		var zig_x: float = 3.0 * float(index)
		# 5 px nach unten, 4 px nach oben — netto 1 px je Doppelschritt.
		zig_y += 5.0 if index % 2 == 1 else -4.0
		if sawtooth.update(Vector2(zig_x, zig_y), float(index) / 120.0):
			sawtooth_fired = true
	_check(not sawtooth_fired,
		"ein waagerecht gezackter Zug loest nicht aus (Netto nur %.0f px nach unten)"
			% (zig_y_last(sawtooth)))
	# ---------------------------------------------------------------------
	# REGRESSION (Review 3): senkrechtes ZITTERN loest nicht aus.
	#
	# `down` zaehlt nur die abwaerts fuehrenden Abschnitte. Ein Daumen, der beim
	# Steuern senkrecht zittert (60 runter, 59 zurueck, 20 runter), kommt damit
	# auf 80 px "Strecke nach unten", endet aber nur 21 px tiefer. Gemessen mit
	# dem Gegenproben-Skript aus Review 3 feuerte genau dieser Verlauf.
	# Deshalb muss die Bewegung zusaetzlich NETTO deutlich nach unten fuehren.
	# ---------------------------------------------------------------------
	var wobble := DiveInput.new()
	wobble.begin(Vector2(540.0, 400.0), 0.0)
	var wobble_fired := false
	wobble_fired = wobble.update(Vector2(540.0, 460.0), 0.05) or wobble_fired
	wobble_fired = wobble.update(Vector2(540.0, 401.0), 0.10) or wobble_fired
	wobble_fired = wobble.update(Vector2(540.0, 421.0), 0.15) or wobble_fired
	var wobble_measure: Dictionary = wobble.measure()
	_check(not wobble_fired,
		"ein senkrechtes Zittern loest nicht aus (%d px Strecke, aber nur %d px netto)"
			% [int(wobble_measure["down"]), int(wobble_measure["rise"])])
	_check(wobble_measure["down"] >= 70.0 and wobble_measure["rise"] < 40.0,
		"und der Fall ist wirklich der gemeinte (Strecke %d, netto %d)"
			% [int(wobble_measure["down"]), int(wobble_measure["rise"])])
	# Gegenprobe: derselbe Ansatz, aber bis unten durchgezogen, loest aus.
	var straight := DiveInput.new()
	straight.begin(Vector2(540.0, 400.0), 0.0)
	var straight_fired := false
	straight_fired = straight.update(Vector2(540.0, 460.0), 0.05) or straight_fired
	straight_fired = straight.update(Vector2(540.0, 401.0), 0.10) or straight_fired
	for step in range(1, 6):
		straight_fired = straight.update(Vector2(540.0, 401.0 + 20.0 * float(step)), 0.10 + 0.02 * float(step)) or straight_fired
	_check(straight_fired,
		"ein Wisch, der unten ankommt, loest trotzdem aus")
	# ---------------------------------------------------------------------
	# REGRESSION (Review 2): ein Wisch nach OBEN ist kein Dive.
	#
	# Die erste Fassung zaehlte den BETRAG der senkrechten Bewegung und behandelte
	# ihn als Weg nach unten. Damit loeste auch ein Wisch nach oben aus — der
	# Kern waere beim Hochziehen beschleunigt nach unten gefallen.
	# ---------------------------------------------------------------------
	var upward := DiveInput.new()
	upward.begin(Vector2(540.0, 500.0), 0.0)
	var upward_fired := false
	for step in range(1, 6):
		if upward.update(Vector2(540.0, 500.0 - 30.0 * float(step)), 0.02 * float(step)):
			upward_fired = true
	_check(not upward_fired, "ein Wisch nach oben loest keinen Dive aus")
	# Gegenprobe: die Strecke ist gross genug, es scheitert nur an der RICHTUNG.
	_check(upward.measure().down < 1.0 and upward.sample_count() >= 5,
		"der Aufwaerts-Wisch hat genug Proben, aber keinen Weg nach unten (%.1f, %d Proben)"
			% [upward.measure().down, upward.sample_count()])
	# ---------------------------------------------------------------------
	# REGRESSION (Review 2): hinunter und zurueck auf die Ausgangshoehe.
	#
	# Der Weg nach unten war da, aber die Bewegung kommt nicht unten an. Ohne die
	# Bedingung "muss tiefer enden als sie begann" loeste das aus.
	# ---------------------------------------------------------------------
	var roundtrip := DiveInput.new()
	roundtrip.begin(Vector2(540.0, 400.0), 0.0)
	var roundtrip_fired := false
	if roundtrip.update(Vector2(540.0, 445.0), 0.05):
		roundtrip_fired = true
	if roundtrip.update(Vector2(540.0, 400.0), 0.10):
		roundtrip_fired = true
	_check(not roundtrip_fired, "hinunter und zurueck auf die Ausgangshoehe loest nicht aus")
	# ---------------------------------------------------------------------
	# REGRESSION (Review 2): ein ehrlicher Flick darf nicht an der
	# Ereignisrate scheitern.
	#
	# Zwei echte Fehler steckten hier: die Puffergroesse 48 warf bei hoher Rate
	# die aelteren Proben weg (derselbe Wisch loeste bei 120 Hz aus, bei 240 Hz
	# nicht), und seitliches Zittern wurde voll mitgezaehlt und kippte die
	# Dominanz (120 px nach unten mit ±2 px Zittern wurden abgelehnt).
	#
	# Geprueft wird deshalb DERSELBE Wisch bei mehreren realistischen Raten.
	# ---------------------------------------------------------------------
	var failing_rates: Array = []
	for rate: float in [30.0, 60.0, 120.0, 240.0, 500.0]:
		var fast := DiveInput.new()
		fast.begin(Vector2(540.0, 300.0), 0.0)
		# 200 Design-Pixel nach unten in 0,2 s — ein kraeftiger, gewollter Flick.
		var fired := false
		var frames: int = int(rate * 0.2)
		for index in range(1, frames + 1):
			var t: float = float(index) / rate
			# ±2 px seitliches Zittern, wie ein echter Daumen es erzeugt.
			var jitter := 2.0 if index % 2 == 0 else -2.0
			if fast.update(Vector2(540.0 + jitter, 300.0 + 1000.0 * t), t):
				fired = true
		if not fired:
			failing_rates.append(rate)
	_check(failing_rates.is_empty(),
		"ein Flick von 200 px in 0,2 s wird bei jeder Rate erkannt (Ausfaelle: %s)" % [str(failing_rates)])
	# ---------------------------------------------------------------------
	# Und derselbe Nachweis fuer einen Flick, der das ZEITFENSTER BRAUCHT.
	#
	# Der schnelle Flick oben deckt nur einen kleinen Teil der 0,30 s ab — ein
	# zu kleiner Puffer faellt dabei nicht auf. Genau das war ein echter Fehler:
	# mit 48 Proben warf der Puffer bei 240 Hz die aelteren Proben weg und
	# derselbe Wisch loeste je nach Geraet unterschiedlich aus. Ein Flick, der
	# fast das ganze Fenster nutzt, deckt diese Schwelle auf.
	# ---------------------------------------------------------------------
	var window_failing: Array = []
	for rate: float in [60.0, 120.0, 240.0, 500.0]:
		var window_flick := DiveInput.new()
		window_flick.begin(Vector2(540.0, 300.0), 0.0)
		# 110 Design-Pixel in 0,28 s — ueber der Mindeststrecke, aber langsam
		# genug, dass die Strecke ueber das ganze Fenster verteilt ist.
		var window_fired := false
		var window_frames: int = int(rate * 0.28)
		for index in range(1, window_frames + 1):
			var t: float = float(index) / rate
			if window_flick.update(Vector2(540.0, 300.0 + 392.857 * t), t):
				window_fired = true
		if not window_fired:
			window_failing.append(rate)
	_check(window_failing.is_empty(),
		"auch ein Flick ueber das ganze Fenster wird bei jeder Rate erkannt (Ausfaelle: %s)"
			% [str(window_failing)])
	# ---------------------------------------------------------------------
	# REGRESSION (Review 2): ein Abschnitt, der die Fenstergrenze ueberschreitet,
	# muss mit seinem Anteil zaehlen — nicht ganz oder gar nicht.
	# ---------------------------------------------------------------------
	# Zwei Detectoren mit DEMSELBEN Verlauf: der eine loest aus, der andere nicht.
	# Das ist noetig, weil ein ausgeloester Dive den Puffer leert — danach waere
	# der gemessene Weg immer null (genau daran ist meine erste Fassung dieser
	# Pruefung gescheitert: sie las "0 px" und meldete einen Fehler, obwohl der
	# Code richtig rechnete).
	var straddle := DiveInput.new()
	straddle.begin(Vector2(540.0, 400.0), 0.0)
	straddle.update(Vector2(540.0, 420.0), 0.2)
	var straddle_fired := straddle.update(Vector2(540.0, 485.0), 0.301)
	_check(straddle_fired, "ein Flick ueber die Fenstergrenze loest aus")
	var straddle_probe := DiveInput.new()
	straddle_probe.begin(Vector2(540.0, 400.0), 0.0)
	straddle_probe.update(Vector2(540.0, 420.0), 0.2)
	# Unerreichbar hohe Mindeststrecke: der Verlauf wird gemessen, ohne dass der
	# Puffer beim Ausloesen geleert wird.
	straddle_probe.update(Vector2(540.0, 485.0), 0.301, 100000.0)
	var straddle_travel: Vector2 = straddle_probe.travel()
	_check(straddle_travel.y > 70.0,
		"der ueberschreitende Abschnitt zaehlt mit seinem Anteil (%.0f px von 85)"
			% straddle_travel.y)
	# ---------------------------------------------------------------------
	# REGRESSION (Review 2): Diagnose darf das Verhalten nicht veraendern.
	#
	# Die erste Fassung liess `travel(now)` und `sample_count(now)` den Puffer
	# BESCHNEIDEN. Ein Diagnoseaufruf mit einem anderen Fenster haette damit die
	# nachfolgende Erkennung veraendert.
	# ---------------------------------------------------------------------
	var diag := DiveInput.new()
	diag.begin(Vector2(540.0, 300.0), 0.0)
	diag.update(Vector2(540.0, 400.0), 0.05)
	var count_before: int = diag.sample_count()
	var travel_before: Vector2 = diag.travel()
	# Ein Diagnoseaufruf mit einem sehr KURZEN Fenster — die alte Fassung haette
	# hier den gesamten Puffer geleert.
	diag.travel(100.0, 0.001)
	diag.measure(100.0, 0.001)
	_check(diag.sample_count() == count_before,
		"die Diagnose veraendert die Probenzahl nicht (%d gegen %d)" % [diag.sample_count(), count_before])
	_check(is_equal_approx(diag.travel().y, travel_before.y),
		"die Diagnose veraendert den gemessenen Weg nicht (%.1f gegen %.1f)"
			% [diag.travel().y, travel_before.y])
	# Und der Dive muss danach noch genauso funktionieren.
	var diag_swipe := DiveInput.new()
	diag_swipe.begin(Vector2(540.0, 300.0), 0.0)
	diag_swipe.travel(50.0, 0.001)
	_check(diag_swipe.update(Vector2(540.0, 420.0), 0.05),
		"nach einem Diagnoseaufruf loest ein Wisch weiterhin aus")

## --- Live: echte Eingabepipeline, echter Sprung ------------------------------
func _check_live_dive() -> void:
	var game := Game.new()
	game.name = "DiveGame"
	root.add_child(game)
	await process_frame
	game._start_game()
	game._start_tween.pause()
	game._start_tween.custom_step(JumpConfig.START_TOTAL + 0.01)
	await process_frame
	_check(game._phase == Game.Phase.PLAYING, "das Spiel laeuft")
	var jumper = game.jumper
	# Ein Absprung gibt den Dive frei.
	jumper._apply_bounce(false)
	_check(jumper.dive_available() == false, "im Aufstieg ist der Dive nicht verfuegbar")

	# 1. Waehrend des AUFSTIEGS darf kein Dive ausgeloest werden — auch nicht
	#    ueber einen echten Wisch.
	jumper.velocity.y = -900.0
	var before: int = jumper.dive_count
	_swipe_down(game)
	await process_frame
	_check(jumper.dive_count == before, "ein Wisch im Aufstieg loest keinen Dive aus")
	_check(not jumper.is_diving(), "der Kern ist im Aufstieg nicht im Dive")

	# 2. In der Fallphase loest derselbe Wisch aus.
	jumper.velocity.y = 600.0
	var gravity_before: float = jumper.current_gravity()
	_swipe_down(game)
	await process_frame
	_check(jumper.dive_count == before + 1, "in der Fallphase loest der Wisch den Dive aus")
	_check(jumper.is_diving(), "der Dive laeuft")
	_check(jumper.current_gravity() > gravity_before * 2.0,
		"die Gravitation ist im Dive deutlich hoeher (%.0f gegen %.0f)" % [jumper.current_gravity(), gravity_before])

	# 3. Kein ZWEITER Dive in diesem Sprung.
	_swipe_down(game)
	await process_frame
	_check(jumper.dive_count == before + 1, "ein zweiter Wisch loest keinen zweiten Dive aus")

	# 4. Waagerecht bleibt der Kern im Dive steuerbar.
	game.is_dragging = true
	jumper.clear_horizontal_target()
	jumper.set_horizontal_target(jumper.global_position.x + 300.0)
	var vx_before: float = jumper.velocity.x
	for step in range(12):
		jumper.apply_horizontal_steering(1.0 / 60.0)
	_check(absf(jumper.velocity.x) > absf(vx_before) + 50.0,
		"der Kern beschleunigt im Dive waagerecht weiter (%.0f -> %.0f)" % [vx_before, jumper.velocity.x])
	_check(jumper.is_diving(), "der Dive laeuft dabei weiter")
	jumper.clear_horizontal_target()
	game.is_dragging = false

	# 5. Nach der Landung ist er wieder verfuegbar.
	jumper._dive_active = false
	jumper._apply_bounce(false)
	_check(jumper.dive_available() == false, "direkt nach dem Absprung ist er noch nicht verfuegbar (Aufstieg)")
	jumper.velocity.y = 400.0
	_check(jumper.dive_available(), "in der Fallphase des NAECHSTEN Sprungs ist er wieder da")

	# 6. Der Deckel greift nur im Dive.
	jumper.velocity.y = JumpConfig.DIVE_MAX_FALL_SPEED + 5000.0
	jumper._dive_active = true
	jumper.apply_gravity(0.016)
	_check(jumper.velocity.y <= JumpConfig.DIVE_MAX_FALL_SPEED + 0.001,
		"die Fallgeschwindigkeit ist im Dive gedeckelt (%.0f)" % jumper.velocity.y)
	jumper._dive_active = false
	jumper.velocity.y = 2000.0
	jumper.apply_gravity(0.0)
	_check(is_equal_approx(jumper.velocity.y, 2000.0), "ohne Dive wird nichts gedeckelt")

	game.free()
	await process_frame

## Ein echter Wisch nach unten durch die Eingabepipeline des Spiels.
##
## BEWUSST MEHRERE BILDER: ein Finger erzeugt bei 60 Hz rund 15 Bewegungs-
## ereignisse je Zehntelsekunde, nicht ein einziges. Ein Ausreisser-Ereignis
## ueber die ganze Strecke wuerde die Zeitbedingung ueberspringen und damit
## genau den Fall nicht pruefen, den ein echter Flick darstellt.
##
## Die Koordinaten sind DESIGN-Pixel: `InputEvent.position` kommt in diesem Raum
## an (gemessen mit `qa/input_room_probe.gd`, Faktor 1080/405). Ein in
## Fensterpixeln gedachter Wert waere um 2,667 zu klein.
func _swipe_down(game) -> void:
	var start := Vector2(540.0, 300.0)
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = start
	Input.parse_input_event(press)
	# Sechs Bewegungsereignisse ueber 120 Design-Pixel in 0,10 s — das ist ein
	# zuegiger Flick eines Daumens, kein Sprung.
	for step in range(1, 7):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = Vector2(start.x, start.y + 20.0 * float(step))
		Input.parse_input_event(drag)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = Vector2(start.x, start.y + 120.0)
	Input.parse_input_event(release)

func zig_y_last(detector) -> float:
	return detector.measure()["rise"]

## ---------------------------------------------------------------------------
## SICHTBARE RUECKMELDUNG
## ---------------------------------------------------------------------------
## Die Zeichnung selbst ist headless nicht pruefbar — die KOPPLUNG an den
## Dive-Zustand schon. Ohne diese Pruefungen koennte die Rueckmeldung vom Dive
## abfallen, ohne dass es auffaellt: Bilder prueft niemand automatisch.
func check_dive_feedback(game) -> void:
	var jumper = game.jumper
	jumper.set_physics_process(false)
	jumper.set_process(false)

	# 1. Kein Dive -> keine Rueckmeldung.
	jumper._dive_active = false
	jumper.velocity = Vector2(0.0, 900.0)
	_check(is_equal_approx(jumper.dive_glow_alpha(), 0.0),
		"ohne Dive gibt es keine Aura (%.3f)" % jumper.dive_glow_alpha())
	_check(is_equal_approx(jumper.dive_glow_stretch(), 1.0),
		"und die Aura ist ungestreckt (%.2f)" % jumper.dive_glow_stretch())

	# 2. Dive langsam -> sichtbar, aber schwach und kaum gestreckt.
	jumper._dive_active = true
	jumper.velocity = Vector2(0.0, JumpConfig.DIVE_MIN_FALL_SPEED * 4.0)
	var slow_alpha: float = jumper.dive_glow_alpha()
	var slow_stretch: float = jumper.dive_glow_stretch()
	_check(slow_alpha > 0.0, "ein Dive zeigt eine Aura (%.3f)" % slow_alpha)
	_check(slow_stretch > 1.0, "und streckt sie nach oben (%.2f)" % slow_stretch)

	# 3. Dive schnell -> deutlich staerker und laenger.
	jumper.velocity = Vector2(0.0, JumpConfig.DIVE_MAX_FALL_SPEED)
	var fast_alpha: float = jumper.dive_glow_alpha()
	var fast_stretch: float = jumper.dive_glow_stretch()
	_check(fast_stretch > slow_stretch,
		"mit dem Tempo waechst die Streckung (%.2f gegen %.2f)" % [fast_stretch, slow_stretch])
	_check(fast_alpha > slow_alpha,
		"und die Deckkraft (%.3f gegen %.3f)" % [fast_alpha, slow_alpha])
	_check(is_equal_approx(fast_stretch, JumpConfig.DIVE_GLOW_STRETCH),
		"bei Hoechsttempo ist die Streckung genau der eingestellte Wert (%.2f)" % fast_stretch)

	# 4. Nach der Landung wieder aus.
	jumper._dive_active = false
	jumper.velocity = Vector2(0.0, 900.0)
	_check(is_equal_approx(jumper.dive_glow_alpha(), 0.0),
		"nach dem Dive ist die Aura wieder weg (%.3f)" % jumper.dive_glow_alpha())

	# 5. Der Zustand darf NICHT an der Richtung haengen: die Aura gehoert zum
	#    laufenden Dive, nicht zum Vorzeichen der Geschwindigkeit.
	jumper._dive_active = true
	jumper.velocity = Vector2(0.0, -JumpConfig.DIVE_MAX_FALL_SPEED)
	_check(jumper.dive_glow_alpha() > 0.0,
		"die Aura haengt am Dive-Zustand, nicht am Vorzeichen (%.3f)"
			% jumper.dive_glow_alpha())
	jumper._dive_active = false
	jumper.velocity = Vector2.ZERO

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _finish() -> void:
	print("DIVE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
