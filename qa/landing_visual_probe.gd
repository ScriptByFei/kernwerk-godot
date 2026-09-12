extends SceneTree
const Game = preload("res://scripts/game/game.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._phase = Game.Phase.PLAYING
	game.start_menu.visible = false
	game.jumper.set_physics_process(false)
	game.jumper.set_process(false)
	game.camera.set_physics_process(false)
	game.camera.position = Vector2(540.0, 960.0)
	game.camera.offset = Vector2.ZERO
	game.camera.force_update_scroll()
	game.platform_director._clear_platforms()
	game.platform_director._add_platform(Vector2(540.0, 1100.0))
	var platform: JumpPlatform = game.platform_director._active_platforms[0]
	var offsets := [130.0, 90.0, 0.0]
	var labels := ["normal", "resonance", "perfect"]
	for i in range(3):
		game.resonance.reset()
		game.jumper.position = Vector2(540.0 + offsets[i], 1042.0)
		game.jumper._resolve_landing(platform, false, game.jumper.position.x)
		platform.set_process(false)
		game.jumper._reactor_visual.pause()
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "/tmp/kernwerk-six-phases/phase2-%s.png" % labels[i]
		if root.get_texture().get_image().save_png(path) != OK:
			quit(1)
			return
		print("SCREENSHOT ", path)
	game.free()
	quit()
