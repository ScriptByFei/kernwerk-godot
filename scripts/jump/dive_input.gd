class_name DiveInput
extends RefCounted

## Erkennt einen schnellen Abwaerts-Wisch (Flick) als Dive-Ausloesung.
##
## Bewusst reine Zustandslogik ohne Node und ohne Rendering — wie
## [ResonanceSystem]: damit ist die Erkennung headless pruefbar, und es gibt
## genau eine Quelle der Wahrheit fuer "wann ist das ein Dive".
##
## Fuenf Bedingungen muessen GLEICHZEITIG erfuellt sein, und jede schuetzt gegen
## eine andere Fehlausloesung:
##
##  1. GENUG WEG NACH UNTEN (`min_distance`). Gezaehlt wird nur die tatsaechlich
##     nach unten fuehrende Strecke, mit Vorzeichen: ein Wisch nach OBEN ist kein
##     Dive.
##  2. ES MUSS UNTEN ANKOMMEN: die Bewegung muss tiefer enden, als sie begann.
##     Ohne diese Bedingung loeste ein Hin und Her (hinunter, zurueck auf die
##     Ausgangshoehe) aus: der Weg nach unten war ja da.
##  3. UND ZWAR DEUTLICH: netto mindestens `NET_FRACTION` der Mindeststrecke.
##     Bedingung 1 summiert nur abwaerts fuehrende Abschnitte und ist damit auch
##     durch senkrechtes Zittern erreichbar (60 runter, 59 zurueck, 20 runter =
##     80 px Strecke bei 21 px netto). Ein echter Flick endet weit unten.
##  4. WENIG ZEIT: nur Bewegung der letzten `max_time` Sekunden zaehlt. Ein
##     langsames Herunterziehen ist kein Wisch.
##  5. SENKRECHTER VORSPRUNG (`dominance`): der Weg nach unten muss die
##     WAAGERECHTE NETTO-Verschiebung deutlich uebersteigen. OHNE diese
##     Bedingung loeste jedes normale Ziehen schraeg nach unten einen Dive aus.
##
## WAAGERECHT WIRD DIE NETTO-VERSCHIEBUNG GEMESSEN, NICHT DER WEG.
##
## Das ist die Umkehrung einer frueheren Fassung und war noetig, nachdem beides
## nachweislich falsch war:
##
##  - Pro Abschnitt aufsummiert MIT Rauschschwelle ist ausnutzbar: ein Zickzack,
##    dessen waagerechte Stuecke einzeln unter der Schwelle liegen, traegt nichts
##    bei, waehrend seine senkrechten Stuecke sich aufaddieren. Gemessen feuerte
##    so ein Zug (93 px netto waagerecht!) als Dive.
##  - Pro Abschnitt aufsummiert OHNE Schwelle kippt echte Flicks: 120 px nach
##    unten mit ±2 px Zittern bei 120 Hz wurden abgelehnt (waagerecht 118 gegen
##    senkrecht 120).
##  - Die NETTO-Verschiebung ist nicht taeuschbar: sie ist genau die Strecke, um
##    die der Finger seitlich woanders angekommen ist. Sie braucht keine
##    Rauschschwelle, weil Zittern sich in ihr aufhebt.
##
## Fuer Diagnose und Pruefungen wird der aufsummierte Weg weiterhin mitgeliefert
## (`sideways_path`), damit nachvollziehbar bleibt, wie ein Zug verlaufen ist.
##
## Koordinatenraum: DESIGN-Pixel (Viewport 1080 breit). `InputEvent.position`
## kommt bereits in diesem Raum an — gemessen mit `qa/input_room_probe.gd`:
## 200 gesendete Fensterpixel kamen als 533,3 an. Eine Umrechnung von Fenster-
## auf Design-Pixel ist deshalb FALSCH und war ein echter Fehler: sie hat die
## 80-px-Schwelle auf einem 430 breiten Fenster auf ~29 px schrumpfen lassen,
## sodass schon ein 35-px-Zucken den Dive ausloeste.

## Weg nach unten, ab dem ein Wisch zaehlt (Design-Pixel).
##
## Bei 1080 Design-Pixeln Breite sind 80 px rund 7,4 % der Breite — auf einem
## Telefon etwa ein Zentimeter Daumenweg. Ein Zucken ist deutlich kuerzer, ein
## gewollter Flick deutlich laenger.
const MIN_DISTANCE := 80.0
## Zeitfenster in Sekunden. Nur Bewegung der letzten `max_time` Sekunden zaehlt.
const MAX_TIME := 0.30
## Wie oft der Weg nach unten den Weg nach rechts uebersteigen muss.
##
## Das ist eine WINKELGRENZE: bei 1,6 feuert ein Wisch bis rund 32 Grad
## Abweichung von der Senkrechten (gerechnet: bei 80 px Abstieg sind bis 54 px
## seitlich erlaubt, bei 150 px bis 98 px).
##
## Warum das bewusst so bleibt: ein Dive soll ein Wisch nach UNTEN sein, und ein
## Daumen, der beim Steuern schraeg nach unten-rechts zieht, soll ihn nicht
## ausloesen. In der Live-Messung (qa/mobile_core_loop_probe.gd, Modus KW_DIVE=1,
## Sichtfahrer legt gleichzeitig seitlich an) loesten 55-62 von 76 Fahrer-Wischen
## aus — die uebrigen lagen steiler als die Grenze. Wer den Dive sehr flach
## ausloesen will, muss DOMINANCE senken; dann steigt die Fehlausloesungsgefahr
## beim Steuern.
const DOMINANCE := 1.6
## Waagerechte Rauschschwelle auf die NETTO-Verschiebung (Design-Pixel).
##
## Sie wird einmal auf die gesamte waagerechte Verschiebung des Fensters
## angewandt, nicht je Abschnitt: eine Schwelle je Abschnitt war ausnutzbar
## (siehe Kopfkommentar). 4 px deckt den Tremor eines ruhenden Daumens ab, ohne
## einen echten seitlichen Anteil zu verschlucken.
const JITTER_TOLERANCE := 4.0

## Anteil der Mindeststrecke, den die Bewegung NETTO nach unten fuehren muss.
##
## Die Mindeststrecke allein reicht nicht: sie wird aus aufsummierten
## abwaerts fuehrenden Abschnitten gebildet und ist damit auch durch senkrechtes
## Zittern erreichbar. Ein echter Flick endet weit unter seinem Startpunkt, ein
## zitternder Daumen nicht. Halb so streng wie die Mindeststrecke, damit ein
## flacher, schneller Flick nicht an dieser Zusatzbedingung scheitert.
const NET_FRACTION := 0.5
## Groesse des Ringpuffers.
##
## Muss das Zeitfenster auch bei HOHER Ereignisrate abdecken. 48 waren zu wenig:
## bei 240 Hz umfasst das 0,30-s-Fenster 72 Proben, der Puffer warf also die
## aelteren weg und ein gueltiger Flick fiel je nach Geraet unterschiedlich aus
## (gemessen: derselbe Wisch loeste bei 120 Hz aus, bei 240 Hz nicht). 256 deckt
## 0,30 s bis 850 Hz ab. Der Speicherbedarf ist mit 256 * 12 Byte verschwindend.
const CAPACITY := 256

## Proben der letzten Bewegung; `z` traegt die Zeit.
var _samples: Array[Vector3] = []
var _head := 0
var _count := 0
var _active := false

## Beginnt eine neue Messung (Finger aufgesetzt / Maustaste gedrueckt).
func begin(position: Vector2, now: float) -> void:
	_active = true
	_head = 0
	_count = 0
	_push(position, now)

## Beendet die Messung (Finger gehoben). Ein Dive kann nur WAEHREND eines
## zusammenhaengenden Zuges entstehen, nicht aus zwei getrennten Tipps.
func end() -> void:
	_active = false
	_head = 0
	_count = 0

func is_tracking() -> bool:
	return _active

## Ein Bewegungsereignis. Liefert true, wenn dies ein Dive-Wisch ist.
##
## Die Schwellwerte sind Parameter, damit Pruefungen sie variieren koennen; im
## Spiel kommen die Werte aus `JumpConfig`.
func update(position: Vector2, now: float, min_distance := MIN_DISTANCE, max_time := MAX_TIME, dominance := DOMINANCE) -> bool:
	if not _active:
		return false
	if now < 0.0:
		return false
	_push(position, now)
	# Nur die letzten `max_time` Sekunden zaehlen. Alles Aeltere faellt weg.
	_prune(now - max_time)
	var measurement := _measure(now - max_time, JITTER_TOLERANCE)
	# 1. Genug Strecke nach unten.
	if measurement.down < min_distance:
		return false
	# 2. Die Bewegung muss unten ankommen. Sonst loeste ein Hin und Her aus.
	if measurement.rise <= 0.0:
		return false
	# 3. Und sie muss NETTO deutlich nach unten fuehren, nicht nur aufsummiert.
	#
	# WARUM: `down` summiert nur die abwaerts fuehrenden Abschnitte. Ein Daumen,
	# der beim Steuern senkrecht zittert (60 px runter, 59 zurueck, 20 runter),
	# erreicht damit 80 px "Strecke nach unten", obwohl er nur 21 px tiefer
	# endet — und loeste einen Dive aus. Gemessen mit dem Gegenproben-Skript
	# aus Review 3: genau dieser Verlauf feuerte.
	# Ein echter Flick endet dagegen weit unter seinem Startpunkt.
	if measurement.rise < min_distance * NET_FRACTION:
		return false
	# 4. Der Weg nach unten muss den Weg nach rechts uebersteigen.
	if measurement.down < measurement.sideways * dominance:
		return false
	# Ausgeloest: Fenster leeren, damit derselbe Zug nicht mehrfach zaehlt, wenn
	# der Finger weiter nach unten gezogen wird.
	_head = 0
	_count = 0
	_push(position, now)
	return true

func reset() -> void:
	_active = false
	_head = 0
	_count = 0

## Messwerte im aktuellen Fenster. Nur fuer Pruefungen und QA: ohne diese Sicht
## waere "warum loest das nicht aus" nicht nachvollziehbar.
##
## Reine LESUNG ohne Nebenwirkung — ein Diagnoseaufruf darf das Verhalten der
## Erkennung nicht veraendern.
func travel(now := -1.0, max_time := MAX_TIME) -> Vector2:
	var result := _measure(now - max_time, JITTER_TOLERANCE) if now >= 0.0 else _measure(-INF, JITTER_TOLERANCE)
	return Vector2(result.sideways_path, result.down)

## Strecke nach unten (nur abwaerts fuehrende Abschnitte), Strecke nach rechts
## (ohne Rauschanteil) und Netto-Hoehenunterschied des Fensters.
func measure(now := -1.0, max_time := MAX_TIME, jitter_tolerance := JITTER_TOLERANCE) -> Dictionary:
	if now < 0.0:
		var full := _measure(-INF, jitter_tolerance)
		return {
			"down": full.down,
			"sideways": full.sideways,
			"sideways_path": full.sideways_path,
			"rise": _measure_rise(),
		}
	var result := _measure(now - max_time, jitter_tolerance)
	return {
		"down": result.down,
		"sideways": result.sideways,
		"sideways_path": result.sideways_path,
		"rise": result.rise,
	}

## Anzahl der Proben im Fenster. Reine LESUNG (siehe `travel`).
func sample_count() -> int:
	return _count

## --- Puffer ---------------------------------------------------------------
##
## Fester Ringpuffer: kein Wachsen, kein Neuallokieren waehrend eines Zuges.
##
## Die Schreibposition ist `(_head + _count) % CAPACITY` und NICHT `append`:
## nach `begin`/`end` steht `_count` wieder auf 0, ein `append` wuerde also
## hinten an die Proben des VORIGEN Zuges anhaengen. `_measure` liest aber vom
## Kopf — und haette dann alte Proben gelesen (gemessen: der Dive loeste danach
## gar nicht mehr aus).
func _push(position: Vector2, now: float) -> void:
	var entry := Vector3(position.x, position.y, now)
	if _count < CAPACITY:
		var index := (_head + _count) % CAPACITY
		if index < _samples.size():
			_samples[index] = entry
		else:
			_samples.append(entry)
		_count += 1
		return
	_samples[_head] = entry
	_head = (_head + 1) % CAPACITY

## Verwirft Proben, die aelter als `cutoff` sind.
##
## Die LETZTE Probe vor der Grenze bleibt stehen: sie ist der Anker fuer den
## Abschnitt, der die Grenze ueberschreitet. Wird sie mitverworfen, geht die
## Bewegung dieses Abschnitts ganz verloren (gemessen: ein Abschnitt von 0,2 s
## auf 0,301 s wurde komplett verworfen, statt mit seinem Anteil zu zaehlen).
func _prune(cutoff: float) -> void:
	var anchor := -1
	for offset in range(_count):
		if _samples[_index(offset)].z < cutoff:
			anchor = offset
		else:
			break
	# Nur bis VOR den Anker verwerfen, damit er als Randprobe erhalten bleibt.
	while anchor > 0:
		_head = _head_next()
		_count -= 1
		anchor -= 1

## Strecken und Netto-Hoehen des Fensters.
##
## Der die Grenze ueberschreitende Abschnitt zaehlt mit seinem ANTEIL, der im
## Fenster liegt — zeitlich interpoliert. Ohne diese Interpolation wurde die
## Bewegung eines solchen Abschnitts pauschal verworfen oder pauschal voll
## gezaehlt; beides ist an der Fenstergrenze falsch.
##
## WICHTIG: Der Startpunkt des Fensters wird EBENFALLS interpoliert. Sonst
## rechnen `rise` und die waagerechte Netto-Verschiebung mit der abgelaufenen
## Randprobe, obwohl die aufsummierten Strecken schon beschnitten sind — und
## beide Kennzahlen werden widerspruechlich.
##
## Gemessen (Review 4): (0,0)@0 -> (200,200)@0,4 -> (0,60)@0,5. Zum Zeitpunkt
## 0,5 liegt die Fenstergrenze bei 0,2; der wahre Startpunkt ist also (100,100)
## und die Bewegung endet mit rise = -40 OBERHALB davon. Mit der unkorrigierten
## Randprobe meldete dieselbe Messung rise = 60 und loeste aus — der Kern waere
## nach oben steigend beschleunigt nach unten.
func _measure(cutoff: float, jitter_tolerance: float) -> Dictionary:
	var down := 0.0
	var sideways := 0.0
	var sideways_path := 0.0
	var first := _count > 0
	var last_y := 0.0
	var first_y := 0.0
	var last_x := 0.0
	var first_x := 0.0
	if _count > 0:
		first_y = _samples[_index(0)].y
		last_y = _samples[_index(_count - 1)].y
		first_x = _samples[_index(0)].x
		last_x = _samples[_index(_count - 1)].x
	if _count < 2:
		return {"down": down, "sideways": sideways, "sideways_path": sideways_path, "rise": 0.0}
	# Der Startpunkt des Fensters: die erste Probe, die den Schnitt NOCH
	# schneidet, zeitanteilig interpoliert. Liegt die erste Probe schon hinter
	# dem Schnitt, ist sie selbst der Startpunkt.
	var window_start := Vector2(first_x, first_y)
	var anchor_x := first_x
	var anchor_y := first_y
	if _samples[_index(0)].z < cutoff:
		for offset in range(1, _count):
			var later := _samples[_index(offset)]
			if later.z < cutoff:
				continue
			var before := _samples[_index(offset - 1)]
			var span := later.z - before.z
			var part := 0.0 if span <= 0.0 else clampf((cutoff - before.z) / span, 0.0, 1.0)
			anchor_x = lerpf(before.x, later.x, part)
			anchor_y = lerpf(before.y, later.y, part)
			break
		window_start = Vector2(anchor_x, anchor_y)
	var previous := _samples[_head]
	for offset in range(1, _count):
		var current := _samples[_index(offset)]
		var weight := 1.0
		if current.z <= cutoff:
			previous = current
			continue
		if previous.z < cutoff:
			var span := current.z - previous.z
			weight = 0.0 if span <= 0.0 else clampf((current.z - cutoff) / span, 0.0, 1.0)
		var delta := current - previous
		# Bildschirmkoordinaten: +y zeigt nach UNTEN. "Nach unten" ist also
		# delta.y > 0. Nur dieser Anteil zaehlt, und er zaehlt voll — eine
		# Rueckkehr nach oben hebt ihn nicht auf.
		down += maxf(delta.y, 0.0) * weight
		# Aufsummierter waagerechter Weg — NUR fuer Diagnose und Pruefungen.
		# Fuer die Entscheidung zaehlt der Netto-Wert unten.
		sideways_path += absf(delta.x) * weight
		previous = current
	if first:
		last_y = _samples[_index(_count - 1)].y
	# `rise` > 0 heisst: das Fenster endet TIEFER als es begann.
	#
	# WAAGERECHT: die NETTO-Verschiebung des ganzen Fensters, nicht die Summe der
	# Abschnitte.
	#
	# WARUM NICHT PRO ABSCHNITT: eine Rauschschwelle je Abschnitt ist
	# ausnutzbar. Ein Zickzack, dessen waagerechte Stuecke einzeln unter der
	# Schwelle liegen, traegt NICHTS zur Summe bei, waehrend seine senkrechten
	# Stuecke sich aufaddieren — ein waagerecht gezackter Zug feuerte dann als
	# Dive (nachgerechnet: 80 px aufsummiert bei nur 21 px Netto-Abstieg, und
	# gemessen: eine Zickzack-Geste mit 93 px Netto-Breite loeste aus).
	# Die Netto-Verschiebung laesst sich so nicht taeuschen: sie ist genau die
	# Strecke, um die der Finger seitlich wirklich woanders angekommen ist.
	# Die Netto-Kennzahlen rechnen gegen den INTERPOLIERTEN Fensterstart
	# (`window_start`), nicht gegen die abgelaufene Randprobe. Siehe Kopf von
	# `_measure`: mit der unkorrigierten Randprobe widersprachen sich die
	# aufsummierten Strecken und die Netto-Werte, und ein Zug, der OBERHALB
	# seines Fensterstarts endet, konnte ausloesen.
	sideways = maxf(absf(last_x - window_start.x) - jitter_tolerance, 0.0)
	return {
		"down": down,
		"sideways": sideways,
		"sideways_path": sideways_path,
		"rise": last_y - window_start.y,
	}

func _measure_down() -> float:
	return _measure(-INF, 0.0).down

func _measure_sideways(jitter_tolerance: float) -> float:
	return _measure(-INF, jitter_tolerance).sideways

func _measure_rise() -> float:
	if _count < 2:
		return 0.0
	# Positiv = tiefer als am Anfang (siehe `_measure`).
	return _samples[_index(_count - 1)].y - _samples[_index(0)].y

func _index(offset: int) -> int:
	return (_head + offset) % CAPACITY

func _head_next() -> int:
	return (_head + 1) % CAPACITY
