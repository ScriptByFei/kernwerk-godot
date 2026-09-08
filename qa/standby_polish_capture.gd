extends SceneTree
## Real raster evidence with production stretch settings. No source asset writes.
const Game = preload("res://scripts/game/game.gd")
const OUT := "res://docs/assets/screenshots/standby_polish/"
var rows: Array = []

func _init() -> void:
	_run.call_deferred()

func _capture(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.save_png(OUT + tag + ".png") == OK)
	print("SAVED " + tag + " " + str(image.get_size()))
	# Capture the actual X11 window too: viewport texture omits keep_width bars.
	var native_window := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
	var result := OS.execute("import", ["-window", str(native_window), ProjectSettings.globalize_path(OUT + tag + "_window.png")])
	assert(result == 0)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if not args.is_empty() else "after"
	DirAccess.make_dir_recursive_absolute(OUT)
	for resolution in [Vector2i(320,568), Vector2i(390,844), Vector2i(430,932), Vector2i(1280,720), Vector2i(844,390)]:
		root.size = resolution
		root.position = Vector2i.ZERO
		await process_frame
		await process_frame
		var game := Game.new()
		root.add_child(game)
		await process_frame
		await create_timer(0.25).timeout
		var menu: StartMenu = game._current_menu
		var tag := "%s_%dx%d" % [prefix, resolution.x, resolution.y]
		var row := {"tag":tag, "window":[resolution.x,resolution.y], "viewport":[menu.size.x,menu.size.y], "nodes":{}}
		for node: Control in [menu.title_label,menu.subtitle_label,menu.cta_panel,menu.cta_label]:
			var rect := node.get_global_rect()
			row.nodes[node.name] = {"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y], "minimum":[node.get_combined_minimum_size().x,node.get_combined_minimum_size().y]}
		rows.append(row)
		await _capture(tag)
		if resolution == Vector2i(390,844):
			game._start_game()
			game._start_tween.pause()
			if menu._press_tween != null:
				menu._press_tween.pause()
			await _capture(prefix + "_390_tap")
			game._start_tween.custom_step(0.40)
			await _capture(prefix + "_390_transition040")
			game._start_tween.custom_step(0.53)
			game.jumper.set_physics_process(false)
			game.camera.set_physics_process(false)
			await process_frame
			await _capture(prefix + "_390_playing")
		game.queue_free()
		await process_frame
	var file := FileAccess.open(OUT + prefix + "_geometry.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	quit()
