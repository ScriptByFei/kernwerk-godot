class_name RunStats
extends RefCounted
## Statistik EINES Laufs: Hoehe, Landungen nach Qualitaet, beste Kette.
##
## Bewusst reine Zustandslogik (RefCounted, kein Node, kein Rendering): headless
## pruefbar und eine Quelle der Wahrheit. Der Bestwert liegt weiterhin in
## [RunRecord] — diese Klasse kennt ihn nicht und kann ihn nicht veraendern.

## Hoechste in diesem Lauf erreichte Hoehe (Spielfeld, nicht Punkte).
var height := 0
var perfect_count := 0
var resonance_count := 0
var normal_count := 0
## Laengste ununterbrochene Folge aus RESONANCE-/PERFECT-Landungen. Eine
## NORMAL-Landung beendet sie; eine Overload-Entladung allein nicht, denn sie
## entsteht ja gerade aus einer gelungenen Kette.
var best_chain := 0
## Ausgeloeste Overloads. Wird vom Spiel aus dem ResonanceSystem gespiegelt,
## damit es fuer den Zaehler nur eine Quelle gibt.
var overloads := 0

var _current_chain := 0


## Verbucht eine echte Landung. Liefert true, wenn sie eine Resonanzkette ist.
func register(quality: JumpConfig.LandingQuality, reached_height: int) -> bool:
	raise_to(reached_height)
	if quality == JumpConfig.LandingQuality.NORMAL:
		normal_count += 1
		_current_chain = 0
		return false
	if quality == JumpConfig.LandingQuality.PERFECT:
		perfect_count += 1
	else:
		resonance_count += 1
	_current_chain += 1
	best_chain = maxi(best_chain, _current_chain)
	return true


## Hoehe waechst nur: ein Rueckfall darf die erreichte Hoehe nicht senken.
func raise_to(reached_height: int) -> void:
	height = maxi(height, reached_height)


## Setzt nur die Laufstatistik zurueck. Der Bestwert bleibt unberuehrt — er ist
## der Zweck einer eigenen, dauerhaften Speicherung.
func reset() -> void:
	height = 0
	perfect_count = 0
	resonance_count = 0
	normal_count = 0
	best_chain = 0
	overloads = 0
	_current_chain = 0


func total_landings() -> int:
	return perfect_count + resonance_count + normal_count
