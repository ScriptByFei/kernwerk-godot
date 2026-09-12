extends SceneTree
const Game = preload("res://scripts/game/game.gd")

## Hoehenzonen-Visualprobe: stellt denselben Ausschnitt auf fuenf Hoehen und
## haelt je Stimmung ein Bild fest. Kein Eingriff in Spiellogik oder Assets.
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
	game.platform_director._clear_platforms()
	game.hud.visible = false
	var step: float = JumpConfig.ZONE_HEIGHT_STEP
	# Bezugshoehe messen statt sie zu raten: sie haengt von der Fensterhoehe ab.
	game.camera.position = Vector2(540.0, 0.0)
	game.camera.force_update_scroll()
	await process_frame
	var reference: float = game._zone_height(game._get_visible_world_rect())
	for index in range(5):
		var climbed: float = step * float(index)
		game.camera.position = Vector2(540.0, reference - climbed)
		game.camera.offset = Vector2.ZERO
		game.camera.force_update_scroll()
		game.jumper.position = Vector2(540.0, 880.0 - climbed)
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "/tmp/kernwerk-six-phases/phase4-zone-%d.png" % (index + 1)
		if root.get_texture().get_image().save_png(path) != OK:
			quit(1)
			return
		var visible_rect := game._get_visible_world_rect()
		print("SCREENSHOT ", path, " ", JumpConfig.ZONE_NAMES[index], " zone=", JumpConfig.zone_color(JumpConfig.ZONE_BACKGROUNDS, game._zone_height(visible_rect)).to_html())
	game.free()
	quit()
