extends SceneTree

const Game = preload("res://scripts/game/game.gd")
var game

func _init() -> void:
	_run.call_deferred()

func _tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = root.get_stretch_transform() * pos
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func _run() -> void:
	Input.use_accumulated_input = false
	game = Game.new()
	root.add_child(game)
	await process_frame
	_tap(Vector2(540.0, 1600.0))
	await create_timer(1.2).timeout
	if game._phase != Game.Phase.PLAYING:
		push_error("real start input did not enter PLAYING")
		quit(1)
		return
	game.set_process(false)
	game.jumper.set_physics_process(false)
	game.camera.set_physics_process(false)
	game.camera.position = Vector2(540.0, 960.0)
	game.camera.offset = Vector2.ZERO
	game.camera.force_update_scroll()
	game.platform_director._clear_platforms()
	for index in range(3):
		game.platform_director._add_platform(Vector2(540.0, 740.0 + index * 350.0), index)
	game.jumper.position = Vector2(540.0, 680.0)
	game.jumper._reactor_visual.sprite_frames = Jumper.REACTOR_IDLE_FRAMES
	game.jumper._reactor_visual.play("idle")
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "/tmp/kernwerk-six-phases/phase1-platforms.png"
	var error := root.get_texture().get_image().save_png(path)
	print("SCREENSHOT ", path, " save_error=", error)
	game.free()
	quit(0 if error == OK else 1)
