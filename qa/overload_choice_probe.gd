extends SceneTree

## Echte Viewport-Zustellung, nicht direkter Aufruf von Input-Handlern.
## xvfb-run -a godot4 --rendering-driver opengl3 --resolution 430x932 --path . -s qa/overload_choice_probe.gd
const Game = preload("res://scripts/game/game.gd")
const OUT := "/tmp/kernwerk-overload-choice"
var checks := 0
var failures := 0
var game
var platform: JumpPlatform
var origin := Vector2(540, 1500)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	Input.use_accumulated_input = false
	game = Game.new()
	root.add_child(game)
	await process_frame
	_check(DisplayServer.window_get_size() == Vector2i(430, 932), "real phone-size window")
	# Full resource in start scene: a start gesture must not leak into ARMED.
	game.resonance.charges = 3
	_touch(true, origin)
	_drag(origin + Vector2(0, -140))
	_check(not game.resonance.is_overload_armed(), "start tap/flick does not arm")
	_check(game._phase == Game.Phase.STARTING, "real tap starts transition")
	game._start_tween.pause()
	game._start_tween.custom_step(JumpConfig.START_TOTAL + 0.01)
	await process_frame
	_drag(origin + Vector2(0, -300))
	_check(not game.resonance.is_overload_armed(), "held start finger blocked after transition")
	_touch(false, origin + Vector2(0, -300))
	_check(game._phase == Game.Phase.PLAYING, "playing reached")
	game.set_process(false)
	game.jumper.set_physics_process(false)
	game.jumper.set_process(false)
	game.camera.set_physics_process(false)
	platform = JumpPlatform.new()
	game.add_child(platform)
	platform.global_position = Vector2(540, 900)
	game.resonance.reset()
	for charge in 3:
		if charge > 0:
			_land()
		_flick(Vector2(0, -140))
		_check(not game.resonance.is_overload_armed(), "real up below 3 inert %d" % charge)
	await _shot("01_two")
	_land()
	_check(game.resonance.is_overload_ready(), "third real landing READY")
	await _shot("02_ready")
	var v: Vector2 = game.jumper.velocity
	_flick(Vector2(350, -70))
	_check(not game.resonance.is_overload_armed(), "horizontal drag with vertical drift is safe")
	_flick(Vector2(0, -35))
	_check(not game.resonance.is_overload_armed(), "tiny upward twitch is safe")
	game.jumper.velocity.y = 300
	var dives: int = game.jumper.dive_count
	_flick(Vector2(0, 140))
	_check(game.jumper.dive_count == dives + 1 and game.jumper.is_diving(), "down swipe still dives")
	_check(not game.resonance.is_overload_armed(), "down does not arm")
	v = game.jumper.velocity
	var g: float = game.jumper.current_gravity()
	_touch(true, origin)
	_drag(origin + Vector2(0, -140))
	_check(game.resonance.is_overload_armed(), "real up swipe arms")
	_check(game.jumper.velocity == v and game.jumper.current_gravity() == g, "arming leaves running dive/flight unchanged")
	_check(game.jumper.dive_count == dives + 1, "up never triggers dive")
	_check(game.hud.status_label() == "ARMED" and game.hud._arm_impulse > 0, "immediate HUD activation feedback")
	game.hud.set_process(false)
	await _shot("03_armed_impulse")
	game.hud._process(0.31)
	await _shot("04_armed")
	_land()
	_check(game.resonance.charges == 0 and game.run_stats.overloads == 1, "next bounce consumes/counts once")
	_check(game.jumper._pending_overload, "next bounce carries existing overload")
	await _shot("05_consumed")
	for i in 3:
		_land()
	_drag(origin + Vector2(0, -350))
	_check(game.resonance.is_overload_ready(), "same ongoing stroke cannot rearm recharged overload")
	_touch(false, origin + Vector2(0, -350))
	# Reverse direction within same contact: both actions stay distinct.
	game.jumper.velocity.y = 300
	dives = game.jumper.dive_count
	_touch(true, origin)
	_drag(origin + Vector2(0, 140))
	_check(game.jumper.dive_count == dives + 1 and not game.resonance.is_overload_armed(), "down first in combined gesture")
	_drag(origin + Vector2(0, -20))
	_check(game.resonance.is_overload_armed() and game.jumper.dive_count == dives + 1, "then distinct up arms without second dive")
	_touch(false, origin + Vector2(0, -20))
	_land(130.0)
	_check(game.resonance.charges == 0 and not game.jumper._pending_overload, "NORMAL cancels armed resource through landing")
	for i in 3:
		_land()
	for cycle in 2:
		_touch(true, game._pause_button_hit_rect().get_center())
		_touch(false, game._pause_button_hit_rect().get_center())
		_check(game._is_paused and paused, "real pause tap %d" % cycle)
		_flick(Vector2(0, -140), Vector2(100, 500))
		_check(not game.resonance.is_overload_armed(), "pause ignores swipe %d" % cycle)
		game._resume()
		game._pause_tween.pause()
		game._pause_tween.custom_step(JumpConfig.PAUSE_OUT_DURATION + 0.01)
		await process_frame
		_drag(origin + Vector2(0, -200))
		_check(not game.resonance.is_overload_armed(), "stale movement after pause ignored")
	# Mouse path uses the same gesture decision.
	_mouse_flick()
	_check(game.resonance.is_overload_armed(), "mouse up-flick supported")
	_land(130.0)
	for i in 3:
		_land()
	game.jumper.global_position.y = game.camera.global_position.y + JumpConfig.FALL_DEATH_MARGIN + 10.0
	game._check_game_over()
	_check(game.is_game_over, "real game over path")
	_flick(Vector2(0, -140), Vector2(100, 500))
	_check(not game.resonance.is_overload_armed(), "game over ignores swipe")
	game.free()
	await process_frame
	await create_timer(0.5).timeout
	print("OVERLOAD REAL INPUT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _land(offset := 0.0) -> void:
	game.jumper.velocity.y = 500
	game.jumper._resolve_landing(platform, false, platform.global_position.x + offset)

func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _touch(pressed: bool, pos: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = root.get_stretch_transform() * pos
	_send(e)

func _drag(pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = root.get_stretch_transform() * pos
	_send(e)

func _flick(delta: Vector2, start := Vector2(540, 1500)) -> void:
	_touch(true, start)
	_drag(start + delta)
	_touch(false, start + delta)

func _mouse_flick() -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = root.get_stretch_transform() * origin
	_send(e)
	var m := InputEventMouseMotion.new()
	m.button_mask = MOUSE_BUTTON_MASK_LEFT
	m.position = root.get_stretch_transform() * (origin + Vector2(0, -140))
	_send(m)
	e = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = m.position
	_send(e)

func _shot(label: String) -> void:
	game.queue_redraw()
	game.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(430, 932, Image.INTERPOLATE_LANCZOS)
	_check(image.save_png(OUT.path_join(label + ".png")) == OK, "screenshot " + label)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)
