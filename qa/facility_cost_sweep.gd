extends SceneTree
const Background = preload("res://scripts/jump/shaft_background.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")

## Zeichenlast der NEUEN Facility-Struktur und der Zonenmodule auf dem
## Anlagenraster. Eigener Sweep, weil `door_cost_sweep.gd` (Zone 1/2) und
## `zone45_cost_sweep.gd` (Zone 4/5) die neuen Aufrufe gar nicht enthalten.
##
## Aufruf:
## xvfb-run -a -s "-screen 0 430x932x24" godot4 --rendering-driver opengl3 \
##   --resolution 430x932 --path . -s qa/facility_cost_sweep.gd

const POSITIONS := 40
const FRAMES := 6
const VIEW := Vector2(1080.0, 2340.0)
## Obergrenze wie in den bestehenden Sweeps.
const LIMIT := 700.0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Zone 1 bis Zone 5: die Anlage traegt ab 1.0, Zonenmodule je nach Fenster.
	var peak := 0.0
	var peak_at := 0.0
	var peak_zone := 0.0
	for i in range(POSITIONS):
		var zone := 0.0 + 4.2 * float(i) / float(POSITIONS - 1)
		var y := -JumpConfig.zone_height_for_index(zone)
		var canvas := Layered.new()
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
		canvas.queue_free()
		await process_frame
	print("SWEEP Facility  Positionen=%d  Obergrenze=%.0f" % [POSITIONS, LIMIT])
	print("  SPITZE: %.0f bei y=%.0f (Zonenindex %.2f)" % [peak, peak_at, peak_zone])
	print("  Auslastung: %.1f %%" % (peak / LIMIT * 100.0))
	# Gegenprobe 1: ALLE gestalteten Schichten aus. Muss auf 0 fallen, sonst misst
	# der Sweep etwas anderes mit als behauptet.
	Background.sections_disabled = true
	Background.zone45_disabled = true
	var off_peak: float = await _sweep(6)
	Background.sections_disabled = false
	Background.zone45_disabled = false
	print("  Gegenprobe alles aus: %.0f (muss ~0 sein)" % off_peak)
	# Gegenprobe 2: nur Anlage + Zonenmodule aus, Zone 4/5 an. Zeigt den ANTEIL
	# der neuen Schichten gegenueber dem Bestand.
	Background.sections_disabled = true
	var new_off: float = await _sweep(6)
	Background.sections_disabled = false
	print("  Gegenprobe ohne Anlage+Zonenmodule: %.0f (Anteil der neuen Schichten: %.0f = %.0f %%)" % [
		new_off, peak - new_off, (peak - new_off) / peak * 100.0])
	# Gegenprobe 3: doppelt gezeichnet. Muss den Wert klar ERHOEHEN — eine
	# Messung, die auf doppelte Arbeit nicht reagiert, ist blind.
	var double_peak: float = await _sweep_doubled(6)
	print("  Gegenprobe doppelt: %.0f (muss deutlich groesser sein)" % double_peak)
	# Urteil: Obergrenze gehalten, Alles-aus faellt auf ~0, doppelt erhoeht klar.
	var ok := peak <= LIMIT and off_peak <= 20.0 and double_peak > peak * 1.3
	print("  ERGEBNIS: ", "OK" if ok else "BRUCH")
	quit(0 if ok else 1)

func _sweep(count: int) -> float:
	var best := 0.0
	for i in range(count):
		var zone := 2.4 + 1.6 * float(i) / float(count - 1)
		var canvas := Layered.new()
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
		best = maxf(best, samples[samples.size() / 2])
		canvas.queue_free()
		await process_frame
	return best

func _sweep_doubled(count: int) -> float:
	var best := 0.0
	for i in range(count):
		var zone := 2.4 + 1.6 * float(i) / float(count - 1)
		var canvas := Doubled.new()
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
		best = maxf(best, samples[samples.size() / 2])
		canvas.queue_free()
		await process_frame
	return best

## Produktionsreihenfolge: Anlage hinter den Zonenmodulen.
class Layered extends Node2D:
	var rect := Rect2()
	var zone := 0.0
	var time := 1.0
	func _draw() -> void:
		Background.draw_facility(self, rect, zone)
		Background.draw_cooling(self, rect, zone, time)
		Background.draw_zone3(self, rect, zone)
		Background.draw_zone4(self, rect, zone, time)
		Background.draw_zone5(self, rect, zone, time)
		Background.draw_facility_transitions(self, rect, zone)

class Doubled extends Node2D:
	var rect := Rect2()
	var zone := 0.0
	var time := 1.0
	func _draw() -> void:
		for repeat in range(2):
			Background.draw_facility(self, rect, zone)
			Background.draw_cooling(self, rect, zone, time)
			Background.draw_zone3(self, rect, zone)
			Background.draw_zone4(self, rect, zone, time)
			Background.draw_zone5(self, rect, zone, time)
			Background.draw_facility_transitions(self, rect, zone)
