extends SceneTree
const Background = preload("res://scripts/jump/shaft_background.gd")
class Probe extends Node2D:
	var rect := Rect2(0,0,1080,2340)
	var time := 1.0
	var copies := 1
	var draws := 0
	func _draw() -> void:
		draws += 1
		for n in range(copies):
			Background.draw(self, rect, 0.0, time)
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var probe := Probe.new()
	root.add_child(probe)
	var peak := 0.0
	var minimum := INF
	var peak_y := 0.0
	var peak_time := 0.0
	var active_samples := 0
	for i in range(300):
		var y := -float(i % 60) * 137.0
		probe.rect.position.y = y
		probe.position = -probe.rect.position
		probe.time = float(int(i / 60)) * 0.75
		if not Background.atmosphere_events(probe.rect, probe.time).is_empty():
			active_samples += 1
		var value := await _sample(probe)
		minimum = minf(minimum, value)
		if value > peak:
			peak = value
			peak_y = y
			peak_time = probe.time
	probe.rect.position.y = peak_y
	probe.position = -probe.rect.position
	probe.time = peak_time
	probe.copies = 2
	var doubled := await _sample(probe)
	probe.copies = 0
	var off := await _sample(probe)
	print("COMPOSITION_COST min=%s peak=%s y=%s double=%s off=%s draws=%s" % [minimum,peak,peak_y,doubled,off,probe.draws])
	print("ATMOSPHERE_ACTIVE_SAMPLES=", active_samples)
	var sensitive := active_samples > 0 and minimum > 0 and doubled >= peak * 1.9 and off == 0 and probe.draws > 0
	print("COMPOSITION_COST_SENSITIVE=", sensitive, " BUDGET_OK=", peak <= 700)
	quit(0 if sensitive and peak <= 700 else 1)
func _sample(probe: Probe) -> float:
	var peak := 0.0
	for i in range(10):
		probe.queue_redraw()
		await RenderingServer.frame_post_draw
		if i >= 6:
			peak = maxf(peak, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	return peak
