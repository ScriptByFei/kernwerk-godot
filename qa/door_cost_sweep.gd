extends SceneTree
const Game = preload("res://scripts/game/game.gd")
## Kamera-Sweep auf dem HINTERGRUND allein: hoechste Zeichenlast ueber viele
## Kamerapositionen. Ein Einzelbild kann zufaellig guenstig liegen, die
## Obergrenze zaehlt. Gleiche Messmethode wie shaft_background_cost_probe.gd
## (Godots eigener Primitive-Zaehler, nur der Hintergrund gezeichnet).
const POSITIONS := 60
const FRAMES := 6
## Sichtbarer Ausschnitt einer Kameraposition (Produktionsgroesse 430x932 bei
## Massstab 0.398 -> 1080 breit, 2340 hoch).
const VIEW := Vector2(1080.0, 2340.0)

func _init() -> void:
	var peak := 0.0
	var peak_at := 0.0
	var all: Array[float] = []
	for i in range(POSITIONS):
		var y := -float(i) * 137.0
		var canvas := BackgroundOnly.new()
		root.add_child(canvas)
		canvas.rect = Rect2(0.0, y, 1080.0, VIEW.y)
		canvas.position = Vector2.ZERO
		canvas.zone = JumpConfig.zone_index_at(-y)
		# Aufwaermphase wie in shaft_background_cost_probe.gd: die ersten Bilder
		# nach dem Einhaengen sind leer und wuerden den Median auf 0 druecken.
		for warmup in range(8):
			canvas.queue_redraw()
			await RenderingServer.frame_post_draw
		var samples: Array[float] = []
		for frame in range(FRAMES):
			canvas.queue_redraw()
			await RenderingServer.frame_post_draw
			samples.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		samples.sort()
		var median := samples[samples.size() / 2]
		all.append(median)
		if median > peak:
			peak = median
			peak_at = y
		canvas.queue_free()
		await process_frame
	all.sort()
	# Hinweis: nur die SPITZE ist belastbar. Minimum und Median koennen 0 zeigen,
	# weil Performance.get_monitor zwischen Einhaengen und erstem gezeichneten
	# Bild null liefert; das ist ein Messartefakt, kein leeres Bild. Deshalb wird
	# hier bewusst nur der Hoechstwert gemeldet.
	print("SWEEP Positionen=%d" % POSITIONS)
	print("  SPITZE: %.0f bei y=%.0f (belastbar)" % [peak, peak_at])
	print("  Obergrenze 700 -> Auslastung %.1f %%" % (peak / 700.0 * 100.0))
	print("  ERGEBNIS: ", "OK" if peak <= 700.0 else "BRUCH")
	quit(0)

class BackgroundOnly extends Node2D:
	var rect := Rect2()
	var zone := 0.0
	var time := 1.0
	func _draw() -> void:
		ShaftBackground.draw(self, rect, zone, time)
