class_name ResonanceSystem
extends RefCounted

## Zentrale Kernmechanik von Kernwerk: Resonanzsprung.
##
## Landungen werden von [method JumpConfig.classify_landing] bewertet:
##   NORMAL     -> keine Ladung, alle Ladungen verfallen
##   RESONANCE  -> +1 Ladung
##   PERFECT    -> +1 Ladung
## Bei [constant JumpConfig.RESONANCE_MAX_CHARGES] ist OVERLOAD scharf und der
## naechste Absprung nutzt [constant JumpConfig.OVERLOAD_BOUNCE_SPEED]; danach
## steht die Resonanz wieder auf 0.
##
## Bewusst reine Zustandslogik: kein Rendering, keine Timer, keine Node- oder
## Szenenabhaengigkeit. Damit ist die Mechanik headless testbar und es gibt
## genau eine Quelle der Wahrheit fuer Ladungen und Overload.

## Ladungen haben sich geaendert (auch beim Verfallen). Fuer HUD und Feedback.
signal charges_changed(charges: int)
## OVERLOAD wurde verbraucht: der ausloesende Absprung nutzt die Overload-Kraft.
signal overload_released()

## Aktuelle Ladungen (0 .. max_charges).
var charges := 0
## Hoechste Ladung dieser Runde. Nur fuer Anzeige/Auswertung, kein Spielfluss.
var best_charges := 0
## Anzahl ausgeloester Overloads in dieser Runde.
var overload_count := 0
## Ladung, die die letzte Landung erreicht hat (0 bei NORMAL). Der Aufrufer
## braucht diesen Wert fuer die Punkte, weil [member charges] beim Overload
## bereits wieder auf 0 steht.
var last_charge := 0


func max_charges() -> int:
	return JumpConfig.RESONANCE_MAX_CHARGES


## Registriert eine Landung und meldet, ob DIESER Absprung ueberladen ist.
##
## Wird vom Jumper unmittelbar vor dem Absprung aufgerufen, damit die
## Overload-Kraft im selben Physik-Tick wirkt.
func register_landing(quality: JumpConfig.LandingQuality) -> bool:
	if quality == JumpConfig.LandingQuality.NORMAL:
		# Schlechte Landung loescht die gesamte Resonanz.
		last_charge = 0
		clear()
		return false
	charges = mini(charges + 1, max_charges())
	best_charges = maxi(best_charges, charges)
	last_charge = charges
	charges_changed.emit(charges)
	if charges < max_charges():
		return false
	# Voll aufgeladen: Overload wird vom naechsten Absprung verbraucht und die
	# Resonanz faellt danach auf 0 zurueck.
	overload_count += 1
	charges = 0
	charges_changed.emit(charges)
	overload_released.emit()
	return true


## Setzt alle Ladungen zurueck (schlechte Landung, Neustart, Rundenende).
func clear() -> void:
	if charges == 0:
		return
	charges = 0
	charges_changed.emit(charges)


## Vollstaendiger Rundenreset inklusive Bestwert und Zaehler.
func reset() -> void:
	charges = 0
	best_charges = 0
	overload_count = 0
	last_charge = 0
	charges_changed.emit(charges)


## Ladungsverhaeltnis 0.0 .. 1.0 fuer abgestuftes Feedback (Ring, HUD).
func charge_ratio() -> float:
	return float(charges) / float(max_charges())


## Punkte fuer die Ladung, die eine Landung erzeugt hat.
static func score_for_charge(charge: int) -> int:
	return JumpConfig.RESONANCE_SCORE_BY_CHARGE[clampi(charge, 0, JumpConfig.RESONANCE_MAX_CHARGES)]
