class_name PlatformPatterns
extends RefCounted

## Kurze Plattform-Sequenzen statt Einzelzufall.
##
## Warum ueberhaupt: der Director hat bisher JEDE Sprosse unabhaengig gewuerfelt.
## Das erzeugt Mittelmasse — der Spieler wiederholt denselben Sprungbogen, weil
## kein Abschnitt eine erkennbare Form hat, auf die er sich einstellen koennte.
## Ein Pattern gibt einem Abschnitt von 3-6 Spruengen eine Absicht: mal zieht es
## nach links, mal pendelt es, mal wird es eng. Erkennbar heisst entscheidbar.
##
## ZWEI SICHERUNGEN, MIT VERSCHIEDENEN AUFGABEN — nicht verwechseln:
## - Die FAIRHEIT sichert der Director: er klemmt jeden Zielpunkt in den Schacht
##   (`_next_position`). Eine Form kann deshalb gar keine unerreichbare Sprosse
##   bauen, egal was hier passiert. Die Mutationsprobe hat das bestaetigt: nimmt
##   man die Klemme hier heraus, bleibt die Fairness gruen.
## - Die Klemme HIER (`step_offset`) sichert die FORM: ohne sie legte etwa ein
##   Cross gegen die Wand alle Sprossen auf dieselbe x — die Form waere keine
##   Bewegung mehr, sondern eine gestapelte Saeule. Das ist ein Schoenheits-,
##   kein Fairnessfehler, und genau darauf wird geprueft.
## `direction_for` dreht gerichtete Formen vorher um, damit die Klemme gar nicht
## erst greifen muss.
##
## Die HOEHE gehoert bewusst NICHT hierher: der senkrechte Abstand bleibt beim
## Schwierigkeitsregler. Ein Pattern darf schnell und eng sein, aber nicht
## ploetzlich zu hoch — sonst waere der Sprung nicht mehr schaffbar.

enum Kind { RECOVERY, ZIGZAG, CLIMB, CROSS, PRECISION_RUSH, RISK_CHOICE }

## Globales Band der Sequenzlaengen. Die einzelnen Formen duerfen enger liegen
## (`length_range_for`), aber keine darf dieses Band verlassen.
const MIN_LENGTH := 3
const MAX_LENGTH := 6

## Ab dieser Stufe kommen die anspruchsvollen Formen dazu. Fruehe Runs bleiben
## lesbar: erst die ruhigen Formen, dann die engen.
const CROSS_FROM_DIFFICULTY := 2
const PRECISION_FROM_DIFFICULTY := 3

## Gewichte je Schwierigkeitsstufe. Index = Stufe, Wert = Gewicht je Kind.
## ERHOLUNG bleibt auf jeder Stufe vertreten: nach einer engen Folge braucht der
## Spieler eine ruhige, sonst wird die Schwierigkeit zur Dauerbelastung.
static func weight_for(kind: Kind, difficulty: int) -> float:
	var level := maxi(0, difficulty)
	match kind:
		Kind.RECOVERY:
			return 3.0 if level <= 1 else 2.0
		Kind.ZIGZAG:
			return 3.0
		Kind.CLIMB:
			return 2.0 if level >= 1 else 0.5
		Kind.CROSS:
			return 0.0 if level < CROSS_FROM_DIFFICULTY else 1.5 + 0.3 * float(level)
		Kind.PRECISION_RUSH:
			return 0.0 if level < PRECISION_FROM_DIFFICULTY else 1.0 + 0.3 * float(level)
		Kind.RISK_CHOICE:
			# Die Risikowahl wird mit der Hoehe HAeUFIGER angeboten (Wunsch:
			# "Risk-Routen spaeter haeufiger"). Auf Stufe 0 gibt es sie nicht.
			return 0.0 if level < 1 else 1.0 + 0.5 * float(level)
	return 0.0

static func total_weight(difficulty: int) -> float:
	var sum := 0.0
	for kind in Kind.values():
		sum += weight_for(kind, difficulty)
	return sum

## Waehlt eine Form. `roll` ist eine Zufallszahl in [0, gesamtgewicht).
static func pick_kind(roll: float, difficulty: int) -> Kind:
	var remaining := roll
	for kind in Kind.values():
		remaining -= weight_for(kind, difficulty)
		if remaining <= 0.0:
			return kind
	return Kind.ZIGZAG

## Laengenband je Form. Die Erholung ist bewusst KURZ (3-4): sie ist eine
## Verschnaufpause, keine zweite Aufgabe. Die engen Formen bleiben kompakt,
## damit sie als Rhythmus und nicht als Pruefung wirken.
static func length_range_for(kind: Kind) -> Vector2i:
	match kind:
		Kind.RECOVERY:
			return Vector2i(3, 4)
		Kind.PRECISION_RUSH:
			return Vector2i(4, 5)
		Kind.RISK_CHOICE:
			return Vector2i(4, 5)
	return Vector2i(4, MAX_LENGTH)

## Laenge der Sequenz. `roll` ist eine Zufallszahl in [0, 1).
static func length_for(kind: Kind, roll: float) -> int:
	var band := length_range_for(kind)
	var span := band.y - band.x + 1
	if span <= 0:
		return band.x
	var length := band.x + int(floor(clampf(roll, 0.0, 0.999) * float(span)))
	return clampi(length, maxi(band.x, MIN_LENGTH), mini(band.y, MAX_LENGTH))

## Laufrichtung der gerichteten Formen.
##
## CLIMB zieht in EINE Richtung. Laeuft sie gegen den Schacht, wird vorher
## umgedreht — sonst klemmte die Klemme jede weitere Sprosse an dieselbe Wand
## und das Pattern waere keine Bewegung, sondern eine gestapelte Saeule.
static func direction_for(kind: Kind, start_x: float, length: int, step: float, min_x: float, max_x: float) -> float:
	if kind != Kind.CLIMB:
		return 1.0
	var travel := travel_distance(kind, length, step)
	if start_x + travel > max_x:
		return -1.0
	if start_x - travel < min_x:
		return 1.0
	return 1.0

## Gesamte Strecke, die eine gerichtete Form zuruecklegt.
static func travel_distance(kind: Kind, length: int, step: float) -> float:
	if kind != Kind.CLIMB:
		return 0.0
	return magnitude_for(kind) * step * float(maxi(0, length - 1))

## Grundweite der Form als Anteil des erlaubten Schritts. 1.0 = voller Schritt.
static func magnitude_for(kind: Kind) -> float:
	match kind:
		Kind.RECOVERY:
			return 0.25
		Kind.ZIGZAG:
			return 0.70
		Kind.CLIMB:
			return 0.55
		Kind.CROSS:
			return 1.00
		Kind.PRECISION_RUSH:
			return 0.30
		Kind.RISK_CHOICE:
			return 0.45
	return 0.5

## Senkrechter Rhythmus je Form, als Faktor auf den Schwierigkeitsabstand.
##
## Das ist der Unterschied, den man SPUERT: bisher benutzten alle Formen
## denselben Abstand, der Abschnitt war also nur waagerecht anders. Die
## Spreizung ist bewusst moderat — sie muss auf dem Telefon atembar bleiben.
##
##   RECOVERY        kleiner  — ruhige, schnelle Spruenge zum Durchatmen
##   PRECISION_RUSH  kleinste — kurze, schnelle Spruenge
##   RISK_CHOICE     kleiner  — mehr Flugzeit fuer die Routenentscheidung
##   ZIGZAG          mittel   — die Referenz
##   CROSS           mittel/gross
##   CLIMB           gross    — gerichtete Hoehenarbeit
##
## Der Faktor ist NACH OBEN gedeckelt durch die Fairness: der groesste Abstand
## mal dem groessten Faktor muss unter dem Scheitel der ruhigsten Stufe bleiben
## (geprueft in `gameplay_director_test`).
static func gap_factor_for(kind: Kind) -> float:
	match kind:
		Kind.RECOVERY:
			return 0.82
		Kind.PRECISION_RUSH:
			return 0.74
		Kind.RISK_CHOICE:
			return 0.92
		Kind.ZIGZAG:
			return 1.00
		Kind.CROSS:
			return 1.08
		Kind.CLIMB:
			return 1.12
	return 1.0

## Waagerechter Spielraum EINER Form, als Anteil der Schachtbreite.
##
## "Distanz pro Pattern klar begrenzen": ohne diese Grenze konnte ein Cross
## beliebig weit pendeln und war damit kein Abschnitt mehr, sondern der ganze
## Schacht. Die Form bleibt in ihrer eigenen Region — das macht sie lesbar und
## verhindert, dass zwei Formen an derselben Stelle enden.
static func span_limit_for(kind: Kind) -> float:
	match kind:
		Kind.RECOVERY:
			return 0.12
		Kind.PRECISION_RUSH:
			return 0.16
		Kind.RISK_CHOICE:
			return 0.30
		Kind.ZIGZAG:
			return 0.35
		Kind.CLIMB:
			return 0.55
		Kind.CROSS:
			return 0.62
	return 0.35

## Vorzeichen der Abweichung an Position `index`.
## Pendelnde Formen wechseln, gerichtete nicht.
static func sign_for(kind: Kind, index: int, direction: float) -> float:
	if kind == Kind.CLIMB:
		return direction
	return 1.0 if index % 2 == 0 else -1.0

## Der eigentliche Schritt: horizontale Abweichung in WELTPIXELN, bereits so
## geklemmt, dass der Zielpunkt im Schacht UND in der Region der Form liegt.
##
## Die Klemme sitzt hier und nicht beim Aufrufer, damit sie fuer JEDES Pattern
## gilt. Eine Absicherung, die nur ein Teil der Aufrufer benutzt, ist keine.
##
## ENTSCHEIDEND: der zurueckgegebene Schritt ist IMMER auf `wanted` begrenzt.
## Meine erste Fassung spiegelte einen zu weiten Schritt um die Regionmitte
## (`2 * start - x`) — das erzeugte Spruenge bis zum DOPPELTEN des erlaubten
## Schrittmasses (gemessen 716 px bei erlaubten 360). Die Region darf den Schritt
## nur VERKLEINERN oder die Richtung umkehren, niemals vergroessern.
##
## Die Kandidaten werden in dieser Reihenfolge probiert: Region vorwaerts, Region
## rueckwaerts, Schacht vorwaerts, Schacht rueckwaerts. Der erste echte Schritt
## gewinnt — so bleibt die Form in ihrer Region, wenn Platz ist, und stapelt
## ansonsten nicht, sondern kehrt um.
static func step_offset(kind: Kind, index: int, length: int, current_x: float, start_x: float, step: float, direction: float, min_x: float, max_x: float) -> float:
	var limit := span_limit_for(kind) * (max_x - min_x)
	var lo: float = maxf(min_x, start_x - limit)
	var hi: float = minf(max_x, start_x + limit)
	var wanted := sign_for(kind, index, direction) * magnitude_for(kind) * step
	var candidates: Array[float] = [
		clampf(current_x + wanted, lo, hi),
		clampf(current_x - wanted, lo, hi),
		clampf(current_x + wanted, min_x, max_x),
		clampf(current_x - wanted, min_x, max_x),
	]
	for target in candidates:
		var actual: float = target - current_x
		if absf(actual) > 0.5:
			return actual
	return 0.0

## Variante, die eine Form ihren Sprossen gibt.
##
## JEDE Form bestimmt ihre Variante selbst und vollstaendig. Vorher fiel der
## Rest auf einen Zufallswurf zurueck (`_roll_variant`) — genau der verwaesserte
## die Identitaet: eine "Erholung" bestand dann zur Haelfte aus schmalen oder
## Resonanz-Sprossen, und ein Precision Rush war nicht mehr durchgehend eng.
## Zufall innerhalb einer Form gibt es deshalb nicht mehr.
static func variant_for(kind: Kind, _index: int) -> JumpPlatform.Variant:
	match kind:
		Kind.PRECISION_RUSH:
			return JumpPlatform.Variant.NARROW
		Kind.RISK_CHOICE:
			return JumpPlatform.Variant.RESONANCE_FOCUS
		Kind.RECOVERY:
			# Ausdruecklich NUR grosse Standardplattformen.
			return JumpPlatform.Variant.STANDARD
	return JumpPlatform.Variant.STANDARD

## Bietet diese Form eine riskante Abzweigung an?
##
## Nur die Risikowahl tut das — dort ist die Abzweigung das Thema des
## Abschnitts. Ueberall sonst gibt es keine: eine Abzweigung mitten in einer
## Erholung oder einem Precision Rush widerspricht der Form und macht die
## Route unlesbar.
static func offers_branch(kind: Kind) -> bool:
	return kind == Kind.RISK_CHOICE
