extends SceneTree

## Mobile-Core-Loop-Abnahme fuer Kernwerk: Resonanzsprung.
##
## Faehrt VOLLSTAENDIGE Runs in einem ECHTEN Fenster (430x932, echte
## Eingabezustellung ueber Input.parse_input_event) und schreibt je Run eine
## JSON-Datei nach /tmp/kernwerk-abnahme.
##
## Der Controller ist ein idealisierter, aber realistischer Ein-Daumen-Spieler:
## er blickt auf die naechste Sprosse voraus und zieht waehrend des Flugs. Damit
## ist jeder Absturz ein Hinweis auf die Route/Physik, nicht auf den Fahrer —
## Zielabweichung und Lenkautoritaet werden trotzdem mitgemessen.
##
## Aufruf:
##   KW_RUN_SECONDS=30 KW_MODE=forward KW_JITTER=0 xvfb-run -a -s "-screen 0 430x932x24" \
##     godot4 --rendering-driver opengl3 --resolution 430x932 --path . \
##     -s qa/mobile_core_loop_probe.gd

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")

const OUT_DIR := "/tmp/kernwerk-abnahme"
const DRAG_PERIOD_MS := 20.0
const VARIANT_NAMES := ["STANDARD", "NARROW", "RESONANCE_FOCUS", "RISKY"]

var _game
var _jumper
var _camera
var _rng := RandomNumberGenerator.new()

var _seed := JumpConfig.PLATFORM_RUN_SEED
var _mode := "forward"
var _jitter := 0.0
var _run_seconds := 30.0
var _max_shots := 12

var _held := false
var _target_x := 540.0
var _target_platform = null
var _current_platform = null
var _last_drag_ms := -1000.0
var _landing_count := 0
var _start_ms := 0
var _last_charge := -1
var _shots := 0
var _descent_shots := 0
## Dive-Fahrer: bei jedem Sprung wird in der Fallphase EIN echter Wisch nach
## unten geschickt (KW_DIVE=1). Nur so laesst sich messen, was der Dive im
## echten Spiel bewirkt — ein direkter Methodenaufruf wuerde die Eingabeebene
## ueberspringen und genau die Fehlausloesung nicht pruefen.
var _dive_enabled := false
var _dived_this_jump := false
var _dive_attempts := 0
var _pending_shot := ""
## Scheitelhoehe des laufenden Flugs: die tatsaechlich erreichte Steighoehe aus
## der echten Physik. Nur so laesst sich pruefen, ob eine Sprosse erreichbar ist
## — die Formel aus Sprungkraft und Gravitation ist eine Naeherung, die den
## Deckel MAX_BOUNCE_SPEED und den Resonanzaufschlag nicht kennt.
var _restart_after_death := false
var _apex_y := 0.0
## Fester Zielversatz des Fahrers in Weltpixeln. 0 = perfekt gezielt;
## 130 = sicher daneben (NORMAL-Landung), 200 = verfehlt die Sprosse ganz.
## Damit laesst sich die Grenze zwischen "Spielerfehler" und "unfair" messen,
## statt sie zu behaupten.
var _aim_offset := 0.0
## Kontrollfahrer: der Finger bleibt auf einer festen Bildschirmposition liegen.
var _idle_x := 540.0
## Aufnahmeintervall in Sekunden fuer die Lesbarkeitsmessung. 0 = aus.
var _capture_every := 0.0
var _last_capture_ms := 0
var _launch_y := 0.0
var _apex_rise := 0.0
var _start_height := 0.0

var _landings := []
var _series := []
var _frames_ms := []
var _fps_window := []
var _physics_mark := 0
var _physics_mark_ms := 0
var _physics_per_second := []
var _deaths := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Input.use_accumulated_input = false
	_seed = int(OS.get_environment("KW_SEED")) if OS.get_environment("KW_SEED") != "" else JumpConfig.PLATFORM_RUN_SEED
	_mode = OS.get_environment("KW_MODE") if OS.get_environment("KW_MODE") != "" else "forward"
	_jitter = float(OS.get_environment("KW_JITTER")) if OS.get_environment("KW_JITTER") != "" else 0.0
	_run_seconds = float(OS.get_environment("KW_RUN_SECONDS")) if OS.get_environment("KW_RUN_SECONDS") != "" else 30.0
	_max_shots = int(OS.get_environment("KW_MAX_SHOTS")) if OS.get_environment("KW_MAX_SHOTS") != "" else 12
	_start_height = float(OS.get_environment("KW_START_HEIGHT")) if OS.get_environment("KW_START_HEIGHT") != "" else 0.0
	_restart_after_death = OS.get_environment("KW_RESTART_AFTER_DEATH") == "1"
	_dive_enabled = OS.get_environment("KW_DIVE") == "1"
	_aim_offset = float(OS.get_environment("KW_AIM_OFFSET")) if OS.get_environment("KW_AIM_OFFSET") != "" else 0.0
	_capture_every = float(OS.get_environment("KW_CAPTURE_EVERY")) if OS.get_environment("KW_CAPTURE_EVERY") != "" else 0.0
	_rng.seed = _seed + 7

	print("window    = ", DisplayServer.window_get_size())
	print("root.size = ", get_root().size)
	print("stretch   = ", get_root().get_stretch_transform().x.x)
	print("seed=%d mode=%s jitter=%.0f seconds=%.1f" % [_seed, _mode, _jitter, _run_seconds])

	_game = Game.new()
	_game.name = "ProbeGame"
	root.add_child(_game)
	await process_frame
	# QA-Route: der Produktions-Seed ist fest. Fuer die Fairness-Pruefung wird
	# derselbe Generator mit mehreren Seeds befahren.
	if _seed != JumpConfig.PLATFORM_RUN_SEED:
		_game.platform_director._run_seed = _seed
		_game.platform_director.initialize(_game, JumpConfig.PLATFORM_LAYOUT)
	_game._start_game()
	_game._start_tween.pause()
	_game._start_tween.custom_step(JumpConfig.START_TOTAL + 0.01)
	await process_frame
	await process_frame
	if _game._phase != Game.Phase.PLAYING:
		print("FEHLER: Spiel nicht in PLAYING (phase=%d)" % _game._phase)
		quit(2)
		return

	_jumper = _game.jumper
	_camera = _game.camera
	_jumper.landed.connect(_on_landed)
	# Die Startaufstellung: der Kern steht auf der ersten Sprosse der Layout-
	# liste, das erste Ziel ist die naechste.
	_current_platform = _game.platform_director._active_platforms[0]
	_retarget()
	if _target_platform != null:
		_target_x = _target_platform.global_position.x

	if _start_height > 0.0:
		# QA-Aufbau: die hoechste Schwierigkeitsstufe wird sonst erst nach
		# 5000 px Aufstieg erreicht. Kern und Kamera werden auf die Zielhoehe
		# gesetzt und die Route mit demselben Generator neu erzeugt — gespielt
		# wird danach eine echte, generierte Route der Stufe 5.
		_jumper.global_position.y -= _start_height
		_camera.global_position.y = _jumper.global_position.y + JumpConfig.CAMERA_LEAD
		_camera.force_update_scroll()
		await process_frame
		var rect: Rect2 = _game._get_visible_world_rect()
		_game.platform_director.maintain(rect.position.y, rect.end.y, JumpConfig.MAX_DIFFICULTY)
		# Ohne Aufsetzen faellt der Kern 340 px weit, bevor die Todeslinie greift
		# — die erzeugte Kette hat bei Stufe 5 aber 350 px Abstand. Der Kern
		# wuerde also zufaellig sterben, bevor der erste echte Sprung beginnt.
		# Deshalb wird er sauber auf die naechstgelegene Sprosse gesetzt; ab da
		# laeuft alles wieder ueber die echte Physik und den echten Generator.
		var landing_spot = null
		var best_dy := INF
		for platform in _game.platform_director._active_platforms:
			if not is_instance_valid(platform):
				continue
			var dy: float = absf(platform.global_position.y - _jumper.global_position.y)
			if dy < best_dy:
				best_dy = dy
				landing_spot = platform
		if landing_spot != null:
			_jumper.global_position = Vector2(
				landing_spot.global_position.x,
				landing_spot.global_position.y - JumpConfig.PLATFORM_SIZE.y * 0.5 - 150.0)
			_jumper.velocity.y = 300.0
			_camera.global_position.y = _jumper.global_position.y + JumpConfig.CAMERA_LEAD
			_camera.force_update_scroll()
			await process_frame
			_current_platform = landing_spot
			_retarget()
		_game._update_score()
		print("teleport: height=%d difficulty=%d spot=%s" % [_game.run_stats.height, _game.difficulty, str(landing_spot != null)])

	_launch_y = _jumper.global_position.y
	_apex_y = _launch_y
	_start_ms = Time.get_ticks_msec()
	_physics_mark = Engine.get_physics_frames()
	_physics_mark_ms = _start_ms
	var last_frame_us := Time.get_ticks_usec()
	var frame_index := 0
	var last_death := _deaths

	# Losfahren: Finger aufsetzen und auf die erste Sprosse ziehen.
	if _mode == "idle":
		# Kontrollfahrer: der Finger bleibt dort liegen, wo der Kern startet.
		# Sonst zieht schon die Startaufstellung den Kern zur ersten Sprosse und
		# die Kontrolle waere keine.
		_idle_x = _jumper.global_position.x
		_target_x = _idle_x
	_press(_target_x)

	while true:
		await process_frame
		var now_ms := Time.get_ticks_msec()
		var now_us := Time.get_ticks_usec()
		var dt_ms := float(now_us - last_frame_us) / 1000.0
		last_frame_us = now_us
		frame_index += 1
		if frame_index > 5:
			_frames_ms.append(dt_ms)
		# Physik-Ticks je Sekunde: faellt der Wert unter 60, laeuft die Engine
		# hinterher (max_physics_steps_per_frame erschoepft).
		if now_ms - _physics_mark_ms >= 1000:
			var phys := Engine.get_physics_frames() - _physics_mark
			_physics_mark = Engine.get_physics_frames()
			_physics_mark_ms = now_ms
			_physics_per_second.append(phys)

		if _game.is_game_over:
			await _capture("death")
			await process_frame
			await _capture("gameover")
			if _restart_after_death:
				await _tap_restart()
			break
		if float(now_ms - _start_ms) / 1000.0 >= _run_seconds:
			break

		_steer(now_ms)
		_dive_tick()
		if _jumper.global_position.y < _apex_y:
			_apex_y = _jumper.global_position.y
		if frame_index % 4 == 0:
			_series.append({
				"t": now_ms - _start_ms,
				"x": _jumper.global_position.x,
				"y": _jumper.global_position.y,
				"vx": _jumper.velocity.x,
				"vy": _jumper.velocity.y,
				"tx": _target_x,
			})
		_capture_descent(frame_index)
		await _capture_landing()
		if _capture_every > 0.0 and now_ms - _last_capture_ms >= int(_capture_every * 1000.0):
			_last_capture_ms = now_ms
			await _capture("t%02d" % int((now_ms - _start_ms) / 1000.0))

	_release()
	if not _game.is_game_over:
		_capture("timeout")
	_write_report()
	quit(0)

## Ein-Daumen-Ziehen. "forward" zielt immer auf die naechste Sprosse,
## "late" laesst den Finger bis zum Beginn des Abstiegs liegen.
##
## Das Ziel wird NICHT jeden Frame neu bestimmt: ein Mensch zielt auf die
## Sprosse, die er erreichen will, und haelt daran fest. Eine Neuberechnung aus
## der Kernposition heraus kippt kurz vor der Landung auf die naechsthoehere
## Sprosse und zieht den Finger im letzten Moment weg — dann pendelt der Kern
## auf einer Sprosse fest. Das Ziel wird deshalb nur bei der Landung gewechselt.
func _steer(now_ms: float) -> void:
	if _jumper == null or not is_instance_valid(_jumper):
		return
	if now_ms - _last_drag_ms < DRAG_PERIOD_MS:
		return
	if _mode == "idle":
		# Kontrollfahrer: der Finger bleibt auf der Stelle liegen, es wird kein
		# Ziel nachgefuehrt. Damit ist der Vergleichswert "ohne Steuerung" echt.
		_target_x = _idle_x
		_drag(now_ms)
		return
	if _target_platform == null or not is_instance_valid(_target_platform):
		_retarget()
		if _target_platform == null:
			return
	if _mode == "late" and _jumper.velocity.y < 0.0:
		# Noch im Aufstieg: der Finger bleibt auf der Sprosse liegen, von der
		# gerade abgesprungen wurde. Erst der Abstieg bekommt die Korrektur.
		_drag(now_ms)
		return
	_target_x = _target_platform.global_position.x + _aim_offset + _aim_jitter()
	_drag(now_ms)

## Naechste Sprosse ueber der Sprosse, auf der der Kern steht.
func _retarget() -> void:
	_target_platform = null
	if _current_platform == null or not is_instance_valid(_current_platform):
		return
	var best_y := -INF
	for platform in _game.platform_director._active_platforms:
		if not is_instance_valid(platform):
			continue
		var y: float = platform.global_position.y
		if y < _current_platform.global_position.y - 1.0 and y > best_y:
			best_y = y
			_target_platform = platform
	if _target_platform != null:
		_target_x = _target_platform.global_position.x

func _aim_jitter() -> float:
	if _jitter <= 0.0:
		return 0.0
	return _rng.randf_range(-_jitter, _jitter)

## Naechste Sprosse ueber dem Kern. Nur fuer die Startaufstellung: im Flug
## bleibt das einmal gewaehlte Ziel stehen (siehe _retarget).
func _next_platform():
	var best = null
	var best_y := -INF
	for platform in _game.platform_director._active_platforms:
		if not is_instance_valid(platform):
			continue
		var y: float = platform.global_position.y
		if y < _jumper.global_position.y - JumpConfig.PLATFORM_SIZE.y and y > best_y:
			best_y = y
			best = platform
	return best

func _on_landed(platform, quality, bonus) -> void:
	_dived_this_jump = false
	var now_ms := Time.get_ticks_msec()
	_landing_count += 1
	if platform != null and is_instance_valid(platform):
		_current_platform = platform
		if _mode != "idle":
			_retarget()
	var quality_name: String = ["NORMAL", "RESONANCE", "PERFECT"][quality]
	if _landing_count <= _max_shots:
		var charge_state: int = _game.resonance.charges
		if _game._overload_display > 0.0:
			charge_state = 3
		_pending_shot = "land%02d_%s_c%d" % [_landing_count, quality_name.to_lower(), charge_state]
	var width := JumpConfig.PLATFORM_SIZE.x
	var variant := -1
	var px := 0.0
	if platform != null and is_instance_valid(platform):
		width = platform.platform_size.x
		variant = platform.variant
		px = platform.global_position.x
	# Scheitel und Steighoehe des abgeschlossenen Flugs. `_apex_rise` ist die
	# tatsaechlich erreichte Hoehe ueber dem Absprungpunkt (Weltpixel, y zeigt
	# nach unten) — der Maszstab fuer die Frage, ob die Sprosse erreichbar war.
	var apex_rise := _launch_y - _apex_y
	var required_rise := 0.0
	if platform != null and is_instance_valid(platform):
		required_rise = _launch_y - platform.global_position.y
	_apex_rise = apex_rise
	_launch_y = _jumper.global_position.y
	_apex_y = _launch_y
	var offset: float = _jumper.global_position.x - px
	var flight_ms := 0.0
	if not _landings.is_empty():
		flight_ms = float(now_ms - _landings.back()["t"])
	_landings.append({
		"t": now_ms - _start_ms,
		"n": _landing_count,
		"variant": VARIANT_NAMES[variant] if variant >= 0 else "?",
		"width": width,
		"px": px,
		"core_x": _jumper.global_position.x,
		"offset": offset,
		"offset_ratio": offset / width,
		"quality": ["NORMAL", "RESONANCE", "PERFECT"][quality],
		"charges": _game.resonance.charges,
		"overloads": _game.resonance.overload_count,
		"aim_x": _target_x,
		"aim_offset": _aim_offset,
		"aim_error": _jumper.global_position.x - _target_x,
		"vx": _jumper.velocity.x,
		"flight_ms": flight_ms,
		"apex_rise": apex_rise,
		"required_rise": required_rise,
		"headroom": apex_rise - required_rise,
		"difficulty": _game.difficulty,
		"score": _game.score,
		"height": _game.run_stats.height,
	})

## Beweisfotos: je Landung ein Bild, benannt nach Qualitaet und Ladungsstand.
## Damit ist die Unterscheidbarkeit von NORMAL/RESONANCE/PERFECT/OVERLOAD aus
## dem Lauf heraus belegt und nicht aus gestellten Zustaenden.
func _capture_chain(_now_ms: float) -> void:
	pass

## Ein Bild waehrend des Abstiegs. Belegt, dass die Steuerung auch in der
## Abstiegsphase greift und wie die Sprossen im Bild liegen.
func _capture_descent(frame_index: int) -> void:
	if _shots >= _max_shots or _descent_shots >= 3:
		return
	if _jumper.velocity.y <= 0.0 or frame_index % 24 != 0:
		return
	_descent_shots += 1
	_shots += 1
	await _capture("descent%d" % _descent_shots)

## Aufnahme der Landung: Qualitaet und Ladungsstand stehen im Dateinamen.
## Wird nicht im Physik-Tick aufgenommen, sondern im naechsten Bild — erst dann
## ist das Feedback (Ring, Impact, HUD) wirklich gezeichnet.
func _capture_landing() -> void:
	if _pending_shot.is_empty() or _shots >= _max_shots:
		_pending_shot = ""
		return
	var label := _pending_shot
	_pending_shot = ""
	_shots += 1
	await _capture(label)

func _capture(label: String) -> void:
	var image := get_root().get_texture().get_image()
	var path := "%s/%s_%s_%d.png" % [OUT_DIR, _tag(), label, Time.get_ticks_msec()]
	image.save_png(path)
	_log_shot(path, label)
	print("SHOT %s" % path)

## Begleitprotokoll zu jedem Bild: exakte Bildschirmposition von Kern, naechster
## Sprosse und getroffener Sprosse plus Spielzustand. Ohne diese Koordinaten
## muss die Pixelmessung den Kern im Bild suchen — und findet stattdessen die
## warmen Lampen der linken Rohrspalte.
func _log_shot(path: String, label: String) -> void:
	var core: Vector2 = _jumper.get_global_transform_with_canvas().origin
	var entry := {
		"file": path,
		"label": label,
		"t": Time.get_ticks_msec() - _start_ms,
		"core": [snappedf(core.x, 0.1), snappedf(core.y, 0.1)],
		"core_scale": get_root().get_stretch_transform().x.x,
		"quality": ["NORMAL", "RESONANCE", "PERFECT"][_jumper.last_landing_quality],
		"charges": _game.resonance.charges,
		"overload_display": snappedf(_game._overload_display, 0.001),
		"impact_remaining": snappedf(_jumper._impact_remaining, 0.001),
		"score": _game.score,
		"height": _game.run_stats.height,
	}
	if _current_platform != null and is_instance_valid(_current_platform):
		var pp: Vector2 = _current_platform.get_global_transform_with_canvas() * Vector2(-_current_platform.platform_size.x * 0.5, -_current_platform.platform_size.y * 0.5)
		entry["platform_rect"] = [snappedf(pp.x, 0.1), snappedf(pp.y, 0.1),
			snappedf(_current_platform.platform_size.x * get_root().get_stretch_transform().x.x, 0.1),
			snappedf(_current_platform.platform_size.y * get_root().get_stretch_transform().y.y, 0.1)]
		entry["platform_variant"] = VARIANT_NAMES[_current_platform.variant]
	if _target_platform != null and is_instance_valid(_target_platform):
		var tp: Vector2 = _target_platform.get_global_transform_with_canvas().origin
		entry["target"] = [snappedf(tp.x, 0.1), snappedf(tp.y, 0.1)]
	var file := FileAccess.open("%s/shots.jsonl" % OUT_DIR, FileAccess.READ_WRITE if FileAccess.file_exists("%s/shots.jsonl" % OUT_DIR) else FileAccess.WRITE)
	if file != null:
		if file.get_length() > 0:
			file.seek_end()
		file.store_line(JSON.stringify(entry))
		file.close()

func _tag() -> String:
	return "%s_s%d_j%d" % [_mode, _seed, int(_jitter)]

func _press(world_x: float) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = _world_to_window(world_x)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	_held = true
	_last_drag_ms = Time.get_ticks_msec()

## Ein echter Wisch nach unten ueber die Eingabepipeline: Aufsetzen, Ziehen nach
## unten, Loslassen. Die y-Position wird in FENSTERpixeln nach unten versetzt —
## genau das erzeugt ein Daumen auf dem Telefon.
##
## Danach wird der Finger wieder aufgesetzt, damit die waagerechte Steuerung
## weiterlaeuft: der Spieler laesst den Daumen nach einem Dive nicht los.
func _dive_swipe() -> void:
	var base := _world_to_window(_target_x)
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = base
	Input.parse_input_event(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(base.x, base.y + 140.0)
	Input.parse_input_event(drag)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = Vector2(base.x, base.y + 140.0)
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	# Finger zurueck auf die Steuerung.
	_held = false
	_press(_target_x)

## In der Fallphase einmal je Sprung einen Dive versuchen.
func _dive_tick() -> void:
	if not _dive_enabled or _jumper == null or not is_instance_valid(_jumper):
		return
	if _dived_this_jump or _jumper.velocity.y <= 0.0:
		return
	_dived_this_jump = true
	_dive_attempts += 1
	_dive_swipe()

func _drag(now_ms: float) -> void:
	if not _held:
		return
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = _world_to_window(_target_x)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	_last_drag_ms = now_ms

## Tap auf NEU STARTEN der Ergebnisanzeige — ueber die echte Eingabepipeline,
## mit Umrechnung von Design- auf Fensterkoordinaten wie bei einem echten Finger.
func _tap_restart() -> void:
	var menu = _game.game_over_menu
	if menu == null or not is_instance_valid(menu):
		print("restart: kein Menue")
		return
	var rect: Rect2 = menu.restart_rect()
	var center: Vector2 = get_root().get_stretch_transform() * rect.get_center()
	print("restart: rect=%s -> window %s" % [str(rect), str(center)])
	var before: Vector2 = _game.jumper.global_position
	_tap_at(center)
	for index in 5:
		await process_frame
	await _capture("after_restart")
	print("restart: is_game_over=%s phase=%s bewegt=%s" % [
		_game.is_game_over, _game._phase, str(_game.jumper.global_position != before)])
	await create_timer(0.4).timeout
	await _capture("restart_running")
	print("restart: laufender Kern y %.1f -> %.1f" % [before.y, _game.jumper.global_position.y])

func _tap_at(position: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = position
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = position
	Input.parse_input_event(release)
	Input.flush_buffered_events()

func _release() -> void:
	if not _held:
		return
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = false
	event.position = _world_to_window(_target_x)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	_held = false

## Weltkoordinate -> Fensterkoordinate. Die Eingabe kommt in Fensterpixeln an,
## das Spiel rechnet in Design-Pixeln: erst Kameratransform, dann Stretch.
func _world_to_window(world_x: float) -> Vector2:
	var canvas_point := get_root().get_canvas_transform() * Vector2(world_x, 0.0)
	return get_root().get_stretch_transform() * canvas_point

func _stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += float(value)
	var count := sorted.size()
	return {
		"n": count,
		"min": snappedf(float(sorted[0]), 0.01),
		"median": snappedf(float(sorted[count / 2]), 0.01),
		"p95": snappedf(float(sorted[mini(count - 1, int(count * 0.95))]), 0.01),
		"p99": snappedf(float(sorted[mini(count - 1, int(count * 0.99))]), 0.01),
		"max": snappedf(float(sorted[count - 1]), 0.01),
		"mean": snappedf(total / float(count), 0.01),
	}

func _write_report() -> void:
	var qualities := {"NORMAL": 0, "RESONANCE": 0, "PERFECT": 0}
	var normals := []
	var aims := []
	var flights := []
	var headrooms := []
	for entry in _landings:
		qualities[entry["quality"]] += 1
		normals.append(absf(entry["offset_ratio"]))
		aims.append(absf(entry["aim_error"]))
		flights.append(entry["flight_ms"])
		headrooms.append(float(entry["headroom"]))
	var report := {
		"seed": _seed,
		"mode": _mode,
		"jitter": _jitter,
		"run_seconds": _run_seconds,
		"start_height": _start_height,
		"died": _game.is_game_over,
		"landings": _landings.size(),
		"score": _game.score,
		"height": _game.run_stats.height,
		"best_chain": _game.run_stats.best_chain,
		"overloads": _game.resonance.overload_count,
		"qualities": qualities,
		"frame_ms": _stats(_frames_ms),
		"physics_per_second": _stats(_physics_per_second),
		"|offset_ratio|": _stats(normals),
		"|aim_error|": _stats(aims),
		"flight_ms": _stats(flights),
		"headroom": _stats(headrooms),
		"difficulty": _game.difficulty,
		"landing_events": _landings,
		"series": _series,
	}
	var name := "run_%s_h%d_o%d.json" % [_tag(), int(_start_height), int(_aim_offset)]
	var file := FileAccess.open("%s/%s" % [OUT_DIR, name], FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report))
		file.close()
	print("REPORT %s/%s" % [OUT_DIR, name])
	print("died=%s landings=%d score=%d height=%d overloads=%d" % [
		_game.is_game_over, _landings.size(), _game.score, _game.run_stats.height, _game.resonance.overload_count])
	print("qualities=%s" % [qualities])
	print("dive_attempts=%d dives_triggered=%d" % [_dive_attempts, _jumper.dive_count if _jumper != null else -1])
	print("frame_ms=%s" % [_stats(_frames_ms)])
	print("physics/s=%s" % [_stats(_physics_per_second)])
