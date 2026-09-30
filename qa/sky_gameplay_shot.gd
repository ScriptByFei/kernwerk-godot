extends SceneTree

## Live Gameplay Screenshot im reinen Spielmodus (ohne Startmenü).

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://scenes/game/game.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	
	# Startmenü ausblenden und direkt in Spielphase wechseln
	if game.start_menu != null:
		game.start_menu.visible = false
	game._phase = 2 # PLAYING
	game._audio_unlocked = true
	game.jumper.velocity.y = -600.0 # Mitten im Sprung nach oben
	
	for i in range(15):
		await process_frame
	await RenderingServer.frame_post_draw
	
	var path := "/tmp/kernwerk-sky/live_gameplay_playing.png"
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("Live Gameplay Playing Shot gespeichert unter: ", path)
	quit(0)
