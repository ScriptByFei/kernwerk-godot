extends SceneTree

## Messung der Finger-Steuerung: Antwortzeit und Kontrolle im Abstieg.
##
## Statt "fuehlt sich gut an" wird die Sprungantwort gemessen: der Finger wird
## per echter Eingabezustellung sprungartig versetzt und die Kernposition je Bild
## mit Zeitstempel protokolliert. Der Kern faellt dabei echt (kein gestellter
## Zustand), gemessen wird also genau die Abstiegsphase.
##
## Aufruf:
##   xvfb-run -a -s "-screen 0 430x932x24" godot4 --rendering-driver opengl3 \
##     --resolution 430x932 --path . -s qa/mobile_input_response_probe.gd

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const OUT := "/tmp/kernwerk-abnahme/input_response.json"

var _game
var _jumper

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Input.use_accumulated_input = false
	_game = Game.new()
	root.add_child(_game)
	await process_frame
	_game._start_game()
	_game._start_tween.pause()
	_game._start_tween.custom_step(JumpConfig.START_TOTAL + 0.01)
	await process_frame
	_jumper = _game.jumper

	# Der Tod wird fuer diese Messung abgeschaltet, damit die Messreihe nicht
	# mitten im Abstieg abbricht. Geprueft wird die STEUERUNG, nicht das Fallen.
	_game.set_process(false)
	_jumper.set_physics_process(true)
	_game.camera.set_physics_process(false)

	var samples := []
	_jumper.global_position = Vector2(540.0, 0.0)
	_jumper.velocity = Vector2.ZERO
	await process_frame

	# Ruhephase: der Finger liegt still auf der Kernposition.
	_press(540.0)
	await _collect(samples, "still", 20, 540.0)

	# Sprung +300 px: die Antwort der Steuerung.
	var t0 := Time.get_ticks_usec()
	_drag(840.0)
	await _collect(samples, "step_right", 30, 840.0)
	var t_step := Time.get_ticks_usec() - t0

	# Halten, damit sich das Ziel einschwingt.
	await _collect(samples, "hold_right", 25, 840.0)

	# Sprung -300 px zurueck (Richtungsumkehr).
	_drag(540.0)
	await _collect(samples, "step_left", 30, 540.0)
	await _collect(samples, "hold_left", 25, 540.0)

	# Finger loslassen: der Kern muss auslaufen, nicht stehen bleiben.
	_release(540.0)
	await _collect(samples, "released", 25, 540.0)

	var report := _analyze(samples)
	report["step_event_latency_us"] = t_step
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	print("REPORT %s" % OUT)
	print("max_frame_ms=%.2f  erste Aenderung nach %.0f ms" % [
		report["max_frame_ms"], report["change_latency_ms"]])
	print("volle Geschwindigkeit nach %.0f ms, Ziel erreicht nach %.0f ms" % [
		report["full_speed_ms"], report["settle_ms"]])
	print("Restgeschwindigkeit nach dem Loslassen: %.0f px/s" % report["release_vx"])
	quit(0)

func _collect(samples: Array, phase: String, frames: int, target: float) -> void:
	for index in frames:
		await process_frame
		samples.append({
			"phase": phase,
			"t_us": Time.get_ticks_usec(),
			"x": _jumper.global_position.x,
			"vx": _jumper.velocity.x,
			"y": _jumper.global_position.y,
			"vy": _jumper.velocity.y,
			"target": target,
		})

func _analyze(samples: Array) -> Dictionary:
	var frames := []
	var change_latency_ms := -1.0
	var full_speed_ms := -1.0
	var settle_ms := -1.0
	var release_vx := 0.0
	var step_start_us := 0
	var step_base_vx := 0.0
	var target_x := 840.0
	for index in samples.size():
		var sample: Dictionary = samples[index]
		if index > 0:
			frames.append(float(sample["t_us"] - samples[index - 1]["t_us"]) / 1000.0)
		if sample["phase"] == "step_right":
			if step_start_us == 0:
				step_start_us = sample["t_us"]
				step_base_vx = sample["vx"]
			var elapsed := float(sample["t_us"] - step_start_us) / 1000.0
			if change_latency_ms < 0.0 and absf(sample["vx"] - step_base_vx) > 1.0:
				change_latency_ms = elapsed
			if full_speed_ms < 0.0 and absf(sample["vx"]) >= JumpConfig.MAX_HORIZONTAL_SPEED - 1.0:
				full_speed_ms = elapsed
			if settle_ms < 0.0 and absf(sample["x"] - target_x) <= 3.0:
				settle_ms = elapsed
		if sample["phase"] == "released":
			release_vx = sample["vx"]
	var max_frame := 0.0
	for value in frames:
		max_frame = maxf(max_frame, value)
	return {
		"max_frame_ms": snappedf(max_frame, 0.01),
		"median_frame_ms": snappedf(_median(frames), 0.01),
		"change_latency_ms": snappedf(change_latency_ms, 0.1),
		"full_speed_ms": snappedf(full_speed_ms, 0.1),
		"settle_ms": snappedf(settle_ms, 0.1),
		"release_vx": snappedf(release_vx, 1.0),
		"samples": samples,
	}

func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2])

## Fensterkoordinate: der Kern steht hier in der Bildmitte, deshalb reicht der
## Skalierungsfaktor der Stretch-Transformation fuer die X-Achse.
func _window_x(world_x: float) -> Vector2:
	var canvas_point := get_root().get_canvas_transform() * Vector2(world_x, 0.0)
	return get_root().get_stretch_transform() * canvas_point

func _press(world_x: float) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = _window_x(world_x)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _drag(world_x: float) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = _window_x(world_x)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _release(world_x: float) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = false
	event.position = _window_x(world_x)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
