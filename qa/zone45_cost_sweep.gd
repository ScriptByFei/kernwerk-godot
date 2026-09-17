extends SceneTree
const Background = preload("res://scripts/jump/shaft_background.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")

## Zeichenlast der NEUEN Zonen 4 und 5, gleiche Messmethode wie
## qa/door_cost_sweep.gd: Godots eigener Primitive-Zaehler, Kamera-Sweep ueber
## den Bereich, in dem die Schichten wirklich tragen.
##
## Warum ein eigener Sweep: door_cost_sweep.gd zeichnet nur ShaftBackground.draw
## (Zone 1/2). Die neuen Schichten sind eigene Aufrufe — sie waeren in der alten
## Messung gar nicht enthalten.
##
## Aufruf:
## xvfb-run -a -s "-screen 0 430x932x24" godot4 --rendering-driver opengl3 \
##   --resolution 430x932 --path . -s qa/zone45_cost_sweep.gd

const POSITIONS := 40
const FRAMES := 6
const VIEW := Vector2(1080.0, 2340.0)
const LIMIT := 700.0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Zonenindex 2.4 bis 4.0 in Schritten -> beide Schichten in allen Zustaenden.
	var peak := 0.0
	var peak_at := 0.0
	var peak_zone := 0.0
	var z4_peak := 0.0
	var z5_peak := 0.0
	for i in range(POSITIONS):
		var zone := 2.4 + 1.6 * float(i) / float(POSITIONS - 1)
		var y := -JumpConfig.zone_height_for_index(zone)
		var canvas := BothZones.new()
		root.add_child(canvas)
		canvas.rect = Rect2(0.0, y, 1080.0, VIEW.y)
		canvas.position = -canvas.rect.position
		canvas.zone = zone
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
		if median > peak:
			peak = median
			peak_at = y
			peak_zone = zone
		z4_peak = maxf(z4_peak, median)
		canvas.queue_free()
		await process_frame
	print("SWEEP Zone4/5  Positionen=%d  Obergrenze=%.0f" % [POSITIONS, LIMIT])
	print("  SPITZE: %.0f bei y=%.0f (Zonenindex %.2f)" % [peak, peak_at, peak_zone])
	print("  Auslastung: %.1f %%" % (peak / LIMIT * 100.0))
	push_warning("")
	# Gegenprobe: abschalten muss den Wert deutlich senken. Sonst misst die
	# Probe den Spielinhalt mit und die Zahl ist wertlos.
	Background.zone45_disabled = true
	var off_peak := 0.0
	for i in range(6):
		var zone := 3.2 + 0.8 * float(i) / 5.0
		var canvas := BothZones.new()
		root.add_child(canvas)
		canvas.rect = Rect2(0.0, -JumpConfig.zone_height_for_index(zone), 1080.0, VIEW.y)
		canvas.position = -canvas.rect.position
		canvas.zone = zone
		for warmup in range(8):
			canvas.queue_redraw()
			await RenderingServer.frame_post_draw
		var samples: Array[float] = []
		for frame in range(FRAMES):
			canvas.queue_redraw()
			await RenderingServer.frame_post_draw
			samples.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		samples.sort()
		off_peak = maxf(off_peak, samples[samples.size() / 2])
		canvas.queue_free()
		await process_frame
	Background.zone45_disabled = false
	print("  Gegenprobe abgeschaltet: %.0f (muss deutlich kleiner sein)" % off_peak)
	print("  ERGEBNIS: ", "OK" if peak <= LIMIT else "BRUCH")
	quit(0)

class BothZones extends Node2D:
	var rect := Rect2()
	var zone := 0.0
	var time := 1.0
	func _draw() -> void:
		Background.draw_zone4(self, rect, zone, time)
		Background.draw_zone5(self, rect, zone, time)
