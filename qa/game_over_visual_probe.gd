extends SceneTree
const Game = preload("res://scripts/game/game.gd")

## Ergebnisanzeige-Visualprobe: erzeugt einen echten Absturz samt Statistik und
## haelt den Schirm bei Mobilgroesse fest.
func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.jumper.set_physics_process(false)
	game.camera.set_physics_process(false)
	game._phase = Game.Phase.PLAYING
	game.start_menu.visible = false
	var platform: JumpPlatform = game.platform_director._active_platforms[0]
	# Echte Landungen durch den bestehenden Pfad, gemischte Qualitaeten.
	for quality in [0, 1, 2, 1, 2, 1, 2, 0, 2, 1, 2]:
		var distance: float = [130.0, 90.0, 0.0][quality]
		game.jumper._resolve_landing(platform, false, platform.position.x + distance)
	# Eine plausible Aufstiegshoehe, sonst zeigt der Schirm eine Null.
	game.jumper.position = Vector2(540.0, game.START_Y - 4200.0)
	game._update_score()
	game.jumper.shutdown()
	game.camera.position = Vector2(540.0, 960.0)
	game.camera.offset = Vector2.ZERO
	game.camera.force_update_scroll()
	game.is_game_over = true
	game._show_game_over()
	game._pause_tween = null
	game.game_over_menu.modulate.a = 1.0
	game.queue_redraw()
	await process_frame
	await create_timer(JumpConfig.GAME_OVER_IN_DURATION + 0.1).timeout
	await RenderingServer.frame_post_draw
	var path := "/tmp/kernwerk-six-phases/phase6-game-over.png"
	if root.get_texture().get_image().save_png(path) != OK:
		quit(1)
		return
	print("SCREENSHOT ", path,
		" height=", game.run_stats.height,
		" best=", game.run_record.best,
		" perfect=", game.run_stats.perfect_count,
		" resonance=", game.run_stats.resonance_count,
		" overloads=", game.run_stats.overloads,
		" chain=", game.run_stats.best_chain)
	game.free()
	quit()
