extends SceneTree

const Game = preload("res://scripts/game/game.gd")
var failures := 0
var checks := 0

func _init() -> void:
	_run.call_deferred()

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + description)

func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _pointer(touch: bool, pressed: bool, pos := Vector2(540, 420)) -> void:
	if touch:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.pressed = pressed
		event.position = pos
		_send(event)
	else:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = pos
		_send(event)

func _drag(touch: bool) -> void:
	if touch:
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = Vector2(850, 500)
		event.relative = Vector2(80, 0)
		_send(event)
	else:
		var event := InputEventMouseMotion.new()
		event.position = Vector2(850, 500)
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		_send(event)

func _pointer_idx(index: int, pressed: bool, pos := Vector2(540, 420)) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = pos
	_send(event)

func _drag_idx(index: int, pos := Vector2(850, 500)) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	event.relative = Vector2(80, 0)
	_send(event)

func _key(pressed: bool, echo_event := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_D
	event.pressed = pressed
	event.echo = echo_event
	_send(event)

func _new_game():
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	return game

func _run() -> void:
	for fps in [30, 60, 120]:
		for touch in [false, true]:
			await _timeline(fps, touch)
	await _restart_safety()
	await _multi_pointer_gating()
	await _superseded_menu_restart()
	await _responsive()
	print("START TRANSITION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _timeline(fps: int, touch: bool) -> void:
	var game = await _new_game()
	var menu: StartMenu = game.start_menu.get_node("StartMenu")
	var stats := {"bounces": 0, "alpha_at_removal": -1.0}
	game.jumper.bounced.connect(func(): stats.bounces += 1)
	menu.tree_exiting.connect(func(): stats.alpha_at_removal = menu.bg.modulate.a)
	_check(game._phase == game.Phase.START_MENU, "initial START_MENU")
	_check(not game.jumper.is_physics_processing() and not game.camera.is_physics_processing(), "menu freezes gameplay")
	var camera_before: Vector2 = game.camera.position + game.camera.offset
	# Actual Input singleton -> viewport GUI -> unhandled input, on the CTA.
	var cta_center := menu.cta_panel.get_global_rect().get_center()
	_key(true)
	_pointer(touch, true, cta_center)
	_check(game._phase == game.Phase.STARTING, "real %s path starts on CTA" % ("touch" if touch else "mouse"))
	if game._phase != game.Phase.STARTING:
		game.queue_free()
		await process_frame
		return
	var tween: Tween = game._start_tween
	tween.pause()
	_check(game.camera.position + game.camera.offset == camera_before, "no teleport at tap")
	_check(menu.cta_panel.scale == Vector2.ONE and menu.cta_panel.self_modulate.r > 1.0, "immediate brightness feedback without scale punch")
	_pointer(touch, true, cta_center)
	_check(game._start_tween == tween, "duplicate tap does not replace timeline")
	var time := 0.0
	var dt := 1.0 / fps
	while time + dt < JumpConfig.START_BOUNCE_AT:
		tween.custom_step(dt)
		time += dt
		_drag(touch)
		_check(game._phase == game.Phase.STARTING, "no early handoff at %.4f" % time)
		_check(not game.jumper.is_physics_processing() and not game.camera.is_physics_processing(), "STARTING gates physics/follow")
		_check(not game.jumper.has_horizontal_target and game.jumper.horizontal_intent == 0.0, "STARTING gates controls")
		_check(stats.bounces == 0, "no early bounce")
		_check(game.jumper.position.y == game.START_Y, "no movement before finale")
		if time >= 0.51 and time < 0.65:
			_check(menu.cta_panel.modulate.a == 0.0 and menu.title_label.modulate.a > 0.0, "secondary UI disappears first")
		if time >= 0.89:
			_check(menu.bg.modulate.a == 0.0, "overlay reaches zero before removal")
			_check(is_zero_approx(game.camera.offset.y), "camera settled before bounce")
	tween.custom_step(dt)
	time += dt
	_check(game._phase == game.Phase.PLAYING, "handoff within one %d FPS step of .92s (%.4f)" % [fps, time])
	_check(stats.bounces == 1, "exactly one first bounce")
	_check(game.jumper.velocity.y == -JumpConfig.BASE_BOUNCE_SPEED, "initial bounce speed unchanged")
	_check(game.jumper._reactor_visual.animation == &"jump", "initial launch has no landing animation delay")
	_check(game.jumper.is_physics_processing() and game.camera.is_physics_processing(), "physics/follow enabled after finale")
	game._fire_initial_bounce()
	game._start_game()
	_check(stats.bounces == 1, "late duplicate bounce/start guarded")
	_drag(touch)
	_key(true, true)
	_check(not game.is_dragging and not game.jumper.has_horizontal_target and game.jumper.horizontal_intent == 0.0, "held pointer/key cannot steer after handoff")
	_pointer(touch, false)
	_key(false)
	_pointer(touch, true)
	_drag(touch)
	_check(game.is_dragging and game.jumper.has_horizontal_target, "fresh pointer steers after release")
	_pointer(touch, false)
	_key(true)
	_check(game.jumper.horizontal_intent == 1.0, "fresh keyboard steers after release")
	_key(false)
	_check(game.jumper.horizontal_intent == 0.0, "key release clears steering")
	game.jumper.set_physics_process(false)
	game.camera.set_physics_process(false)
	await process_frame
	_check(stats.alpha_at_removal == 0.0, "actual tree exit sees ZERO overlay")
	game.queue_free()
	await process_frame
	print("timeline %d FPS %s: handoff %.4fs, bounces %d, exit alpha %.1f" % [fps, "touch" if touch else "mouse", time, stats.bounces, stats.alpha_at_removal])

func _restart_safety() -> void:
	for at in [0.05, 0.40, 0.89]:
		var game = await _new_game()
		_pointer(true, true)
		var old: Tween = game._start_tween
		old.pause()
		old.custom_step(at)
		game.is_dragging = true
		game.jumper.set_horizontal_target(900)
		game._restart()
		_check(not old.is_valid(), "restart kills timeline at %.2f" % at)
		_check(game._phase == game.Phase.START_MENU and not game.is_dragging, "restart restores menu and pointer state")
		_check(not game.jumper.has_horizontal_target and game.jumper.horizontal_intent == 0.0, "restart clears target and keyboard intent")
		await process_frame
		_check(game._phase == game.Phase.START_MENU and not game._initial_bounce_fired, "no stale callback after restart")
		_pointer(true, false)
		game.queue_free()
		await process_frame
	var game = await _new_game()
	_pointer(false, true)
	var old: Tween = game._start_tween
	game.start_menu.get_node("StartMenu").queue_free()
	await process_frame
	await process_frame
	_check(not old.is_valid(), "external menu removal cancels timeline")
	_check(game._phase == game.Phase.START_MENU, "external removal recovers menu")
	_pointer(false, false)
	_pointer(false, true)
	old = game._start_tween
	game.queue_free()
	await process_frame
	_check(not old.is_valid(), "game removal kills tween")
	_pointer(false, false)

## P2 regression: a held start pointer must not suppress a fresh second finger
## (or a fresh mouse gesture) from steering once gameplay is live.
func _multi_pointer_gating() -> void:
	var game = await _new_game()
	# Start with touch index 0 and keep it held through handoff.
	_pointer_idx(0, true)
	var tween: Tween = game._start_tween
	tween.pause()
	tween.custom_step(JumpConfig.START_BOUNCE_AT + 0.1)
	_check(game._phase == game.Phase.PLAYING, "P2: handoff reached with held start touch")
	_check(game._blocked_pointers.has("touch:0"), "P2: start touch is blocked")
	# A fresh second finger (index 1) must be able to steer.
	_pointer_idx(1, true, Vector2(540, 420))
	_drag_idx(1)
	_check(game.is_dragging and game.jumper.has_horizontal_target, "P2: fresh second finger steers while start touch held")
	# The held start touch itself must still be inert.
	_drag_idx(0)
	_check(game.jumper.has_horizontal_target, "P2: held start touch stays inert")
	_pointer_idx(1, false)
	_pointer_idx(0, false)
	game.queue_free()
	await process_frame

	# Mixed: start with mouse, then a fresh touch must steer while mouse held.
	game = await _new_game()
	_pointer(false, true)
	tween = game._start_tween
	tween.pause()
	tween.custom_step(JumpConfig.START_BOUNCE_AT + 0.1)
	_check(game._phase == game.Phase.PLAYING, "P2: handoff reached with held mouse start")
	_check(game._blocked_pointers.has("mouse"), "P2: start mouse is blocked")
	_pointer_idx(1, true, Vector2(540, 420))
	_drag_idx(1)
	_check(game.is_dragging and game.jumper.has_horizontal_target, "P2: fresh touch steers while start mouse held")
	_pointer_idx(1, false)
	_pointer(false, false)
	game.queue_free()
	await process_frame

## P3 regression: a superseded menu still exiting after a restart must not
## cancel a replacement start that begins in the same frame.
func _superseded_menu_restart() -> void:
	var game = await _new_game()
	var old_menu: StartMenu = game._current_menu
	_pointer(true, true)
	var old_tween: Tween = game._start_tween
	old_tween.pause()
	old_tween.custom_step(0.4)
	# Restart queues the old menu for deletion and creates a replacement.
	game._restart()
	var new_menu: StartMenu = game._current_menu
	_check(new_menu != old_menu, "P3: restart created a replacement menu")
	# Start again in the same frame, before the old menu's queued deletion is
	# flushed. The old menu's tree_exiting must not cancel the new timeline.
	_pointer(true, true)
	var new_tween: Tween = game._start_tween
	_check(new_tween != null and new_tween.is_valid(), "P3: replacement start created a timeline")
	await process_frame
	await process_frame
	_check(new_tween.is_valid(), "P3: superseded menu exit did not cancel replacement timeline")
	_check(game._phase == game.Phase.STARTING, "P3: replacement start still in STARTING")
	_pointer(true, false)
	game.queue_free()
	await process_frame

func _responsive() -> void:
	var game = await _new_game()
	var menu: StartMenu = game.start_menu.get_node("StartMenu")
	for resolution in [Vector2i(390, 844), Vector2i(360, 640), Vector2i(768, 1024), Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = resolution
		await process_frame
		await process_frame
		_check(menu.size == root.get_visible_rect().size, "viewport signal updates menu after resize %s" % resolution)
		var safe := Rect2(Vector2.ZERO, menu.size).grow(-8.0)
		for node: Control in [menu.title_label, menu.subtitle_label, menu.cta_panel]:
			_check(safe.encloses(node.get_rect()), "safe bounds %s %s" % [resolution, node.name])
			_check(absf(node.get_rect().get_center().x - menu.size.x * 0.5) < 0.1, "centered %s" % node.name)
		_check(menu.title_label.get_rect().end.y <= menu.subtitle_label.position.y + 8.0, "title/subtitle do not overlap")
		_check(menu.subtitle_label.get_rect().end.y < menu.cta_panel.position.y, "CTA separated from title block")
		_check(menu.cta_panel.pivot_offset == menu.cta_panel.size * 0.5, "breathing pivot centered")
	game._start_game()
	game._start_tween.pause()
	game._start_tween.custom_step(0.4)
	root.size = Vector2i(360, 640)
	await process_frame
	_check(menu.size == root.get_visible_rect().size, "resize during transition")
	_check(absf(menu.cta_panel.get_rect().get_center().x - menu.size.x * 0.5) < 0.1, "transition resize retains center")
	game.queue_free()
	await process_frame
