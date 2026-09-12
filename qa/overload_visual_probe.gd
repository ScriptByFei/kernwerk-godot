extends SceneTree
const Game = preload("res://scripts/game/game.gd")

## Overload-Visualprobe: faehrt echte Landungen durch den bestehenden Pfad und
## haelt je Zustand ein Bild fest. Kein direkter UI-Handler-Aufruf.
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
	game.camera.set_physics_process(false)
	game.camera.position = Vector2(540.0, 960.0)
	game.camera.offset = Vector2.ZERO
	game.camera.force_update_scroll()
	game.platform_director._clear_platforms()
	game.platform_director._add_platform(Vector2(540.0, 1100.0))
	var platform: JumpPlatform = game.platform_director._active_platforms[0]
	var shots := []
	for charge in range(3):
		game.jumper.position = Vector2(540.0, 1042.0)
		game.jumper._resolve_landing(platform, false, game.jumper.position.x)
		platform.set_process(false)
		game.jumper._reactor_visual.pause()
		game.jumper.set_process(false)
		game.jumper._feedback_visual.queue_redraw()
		game.hud.overload_display = game._overload_display
		game.hud.score = game.score
		game.hud.queue_redraw()
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var label := "overload-%d" % (charge + 1)
		var path := "/tmp/kernwerk-six-phases/phase3-%s.png" % label
		if root.get_texture().get_image().save_png(path) != OK:
			quit(1)
			return
		print("SCREENSHOT ", path, " charges=", game.resonance.charges, " overload_display=", game._overload_display, " light=", game.jumper.charge_light_strength())
	game.free()
	quit()
