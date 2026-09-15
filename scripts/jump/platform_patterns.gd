class_name PlatformPatterns
extends RefCounted

## Kurze Plattform-Sequenzen statt Einzelzufall.
##
## Warum ueberhaupt: der Director hat bisher JEDE Sprosse unabhaengig gewuerfelt.
## Das erzeugt Mittelmasse — der Spieler wiederholt denselben Sprungbogen, weil
## kein Abschnitt eine erkennbare Form hat, auf die er sich einstellen koennte.
## Ein Pattern gibt einem Abschnitt von 4-6 Spruengen eine Absicht: mal zieht es
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

const MIN_LENGTH := 4
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

## Laenge der Sequenz. Engere Formen sind kuerzer — eine lange Folge schmaler
## Sprossen waere eine Pruefung, keine Abwechslung.
static func length_for(kind: Kind, roll: float) -> int:
	var span := MAX_LENGTH - MIN_LENGTH + 1
	var length := MIN_LENGTH + int(floor(roll * float(span)))
	length = clampi(length, MIN_LENGTH, MAX_LENGTH)
	if kind == Kind.PRECISION_RUSH or kind == Kind.RISK_CHOICE:
		length = mini(length, 4)
	return length

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

## Vorzeichen der Abweichung an Position `index`.
## Pendelnde Formen wechseln, gerichtete nicht.
static func sign_for(kind: Kind, index: int, direction: float) -> float:
	if kind == Kind.CLIMB:
		return direction
	return 1.0 if index % 2 == 0 else -1.0

## Der eigentliche Schritt: horizontale Abweichung in WELTPIXELN, bereits so
## geklemmt, dass der Zielpunkt im Schacht liegt.
##
## Die Klemme sitzt hier und nicht beim Aufrufer, damit sie fuer JEDES Pattern
## gilt. Eine Absicherung, die nur ein Teil der Aufrufer benutzt, ist keine.
static func step_offset(kind: Kind, index: int, length: int, current_x: float, step: float, direction: float, min_x: float, max_x: float) -> float:
	var wanted := sign_for(kind, index, direction) * magnitude_for(kind) * step
	var target := clampf(current_x + wanted, min_x, max_x)
	var actual := target - current_x
	# Wenn die Klemme den Schritt verschluckt haette, kehrt die Form um: sonst
	# entstuenden mehrere Sprossen exakt uebereinander ("gestapelte Saeule").
	if absf(actual) < 0.5 and absf(wanted) > 0.5:
		var opposite := clampf(current_x - wanted, min_x, max_x)
		actual = opposite - current_x
	return actual

## Variante, die eine Form ihren Sprossen gibt. Die enge Form traegt die Enge
## als Absicht; alle anderen mischen sparsam, damit die Form erkennbar bleibt.
static func variant_for(kind: Kind, index: int) -> JumpPlatform.Variant:
	match kind:
		Kind.PRECISION_RUSH:
			return JumpPlatform.Variant.NARROW
		Kind.RISK_CHOICE:
			return JumpPlatform.Variant.RESONANCE_FOCUS
		Kind.CROSS:
			return JumpPlatform.Variant.RESONANCE_FOCUS if index % 3 == 2 else JumpPlatform.Variant.STANDARD
		Kind.CLIMB:
			return JumpPlatform.Variant.NARROW if index % 3 == 2 else JumpPlatform.Variant.STANDARD
		Kind.RECOVERY:
			return JumpPlatform.Variant.STANDARD
	return JumpPlatform.Variant.STANDARD

## Bietet diese Form eine riskante Abzweigung an? Nur die Risikowahl tut das
## planmaessig — bei den anderen bleibt die Abzweigung dem Zufall ueberlassen.
static func offers_branch(kind: Kind) -> bool:
	return kind == Kind.RISK_CHOICE
