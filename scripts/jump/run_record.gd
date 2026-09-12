class_name RunRecord
extends RefCounted
## Merkt sich den besten Lauf — und ueberlebt ein Neuladen der Seite.
##
## Bewusst reine Zustandslogik (RefCounted, kein Node, kein Rendering): damit
## ist die Regel headless pruefbar und es gibt genau eine Quelle der Wahrheit
## fuer "was ist der Bestwert".
##
## Die Speicherung liegt in `BestScoreStore`, nicht hier. Dieses Objekt kennt
## nur die Regel, wann gespeichert wird.

## Hoechster erreichter Score. 0 bedeutet: noch kein Lauf gespielt.
var best := 0
## Score des zuletzt beendeten Laufs. Bewusst NICHT dauerhaft: er beschreibt
## nur die eben beendete Runde.
var last := 0

var _store: BestScoreStore

## Ohne Store arbeitet der Datensatz rein im Speicher.
##
## Das ist der Standard fuer Tests: sie bleiben damit ohne Seiteneffekt auf den
## echten Spielstand und koennen nicht von einem frueheren Lauf verfaelscht
## werden. `game.gd` uebergibt den dauerhaften Store.
func _init(store: BestScoreStore = null) -> void:
	_store = store
	if _store != null:
		best = _store.load_best()

## Verbucht einen beendeten Lauf und meldet, ob er einen Bestwert aufstellt.
##
## Der erste Lauf meldet bewusst KEINEN Rekord: ohne vorherigen Wert waere
## "NEUER BESTWERT" eine leere Auszeichnung. In dem Fall steigt `best` einfach
## auf den erreichten Wert, angezeigt wird er als normaler Bestwert.
func finish_run(score: int) -> bool:
	last = score
	# Ein geladener Bestwert ist der vorherige Wert, auch wenn er aus einem
	# frueheren Besuch stammt — genau dann ist "NEUER BESTWERT" verdient.
	var is_record := best > 0 and score > best
	if score > best:
		best = score
		if _store != null:
			_store.save_best(best)
	return is_record

## Setzt nur den Sitzungszustand zurueck. Der dauerhafte Bestwert bleibt
## absichtlich erhalten — er ist der Zweck dieser Speicherung.
func reset() -> void:
	last = 0
