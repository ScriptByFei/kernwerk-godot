class_name RunRecord
extends RefCounted
## Merkt sich den besten Lauf der Sitzung.
##
## Bewusst reine Zustandslogik (RefCounted, kein Node, kein Rendering): damit
## ist die Regel headless pruefbar und es gibt genau eine Quelle der Wahrheit
## fuer "was ist der Bestwert".
##
## Der Bestwert gilt nur fuer die Sitzung. Ein Neuladen der Seite setzt ihn
## zurueck. Ein dauerhafter Bestwert braucht Speicherung auf dem Geraet
## (localStorage) und ist bewusst noch nicht Teil dieser Phase.

## Hoechster erreichter Score. 0 bedeutet: noch kein Lauf gespielt.
var best := 0
## Score des zuletzt beendeten Laufs.
var last := 0

## Verbucht einen beendeten Lauf und meldet, ob er einen Bestwert aufstellt.
##
## Der erste Lauf meldet bewusst KEINEN Rekord: ohne vorherigen Wert waere
## "NEUER BESTWERT" eine leere Auszeichnung. In dem Fall steigt `best` einfach
## auf den erreichten Wert, angezeigt wird er als normaler Bestwert.
func finish_run(score: int) -> bool:
	last = score
	var is_record := best > 0 and score > best
	if score > best:
		best = score
	return is_record

func reset() -> void:
	best = 0
	last = 0
