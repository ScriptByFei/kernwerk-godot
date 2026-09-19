extends SceneTree

## Beleg: die naive Winkelrechnung `down / DOMINANCE` ist FALSCH.
##
## Ein Review behauptete, der Kommentar in `dive_input.gd` sei falsch, weil
## `down / 1,6` bei 80 px nur 50 px erlaubt (statt der dokumentierten 54). Der
## Reviewer hatte die Rauschschwelle uebersehen: `sideways` ist bereits
## `maxf(abs(raw) - JITTER_TOLERANCE, 0.0)`, die Grenze liegt also bei
## `down / DOMINANCE + JITTER_TOLERANCE`.
##
## Dieses Skript bestimmt die Grenze per Bisektion direkt am Detektor, damit die
## Aussage nicht auf einer Rechnung, sondern auf Messung beruht.

const DiveInput = preload("res://scripts/jump/dive_input.gd")

func _fires(down: float, sideways: float) -> bool:
	var d := DiveInput.new()
	var start := Vector2(500.0, 300.0)
	d.begin(start, 0.95)
	d.update(start, 1.0)
	d.update(start + Vector2(sideways, 0.0), 1.05)
	return d.update(start + Vector2(sideways, down), 1.10)

func _boundary(down: float) -> float:
	var lo := 0.0
	var hi := down * 2.0
	for _i in range(80):
		var mid := (lo + hi) * 0.5
		if _fires(down, mid):
			lo = mid
		else:
			hi = mid
	return lo

func _init() -> void:
	var dominance: float = 1.6
	var jitter: float = 4.0
	print("%-8s %-16s %-16s %-16s %-10s" % [
		"Abstieg", "gemessene Grenze", "naiv down/1.6", "down/1.6+4", "Doku"])
	var ok := true
	for entry in [[80.0, 54.0], [120.0, 79.0], [150.0, 97.75]]:
		var down: float = entry[0]
		var documented: float = entry[1]
		var measured := _boundary(down)
		var naive: float = down / dominance
		var corrected: float = naive + jitter
		var diff_doc: float = absf(measured - documented)
		if diff_doc > 0.5:
			ok = false
		print("%-8.1f %-16.4f %-16.4f %-16.4f %-10.2f %s" % [
			down, measured, naive, corrected, documented,
			"OK" if diff_doc <= 0.5 else "ABWEICHUNG %.3f" % diff_doc])
	print()
	print("Die naive Rechnung liegt um exakt %.1f px daneben — das ist die" % jitter)
	print("Rauschschwelle, die von der ROHEN Verschiebung abgezogen wird.")
	print("Ergebnis: %s" % ("Grenze stimmt mit der Dokumentation ueberein" if ok
		else "DOKUMENTATION WEICHT AB"))
	quit()
