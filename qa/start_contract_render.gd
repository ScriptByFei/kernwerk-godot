extends SceneTree

const Game = preload("res://scripts/game/game.gd")
const OUT := "/home/masgi_bot/data/kernwerk-start-evidence"
var records: Array = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for resolution in [Vector2i(390, 844), Vector2i(360, 640), Vector2i(768, 1024), Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = resolution
		var game := Game.new()
		root.add_child(game)
		await process_frame
		await process_frame
		var prefix := "%dx%d" % [resolution.x, resolution.y]
		await _capture(game, prefix + "_idle")
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = root.get_visible_rect().size * 0.5
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		var started := Time.get_ticks_msec()
		await create_timer(0.44).timeout
		await _capture(game, prefix + "_mid")
		if game._phase == game.Phase.STARTING:
			await game._start_tween.finished
		print("REAL HANDOFF %s: %d ms (includes frame/capture overhead)" % [prefix, Time.get_ticks_msec() - started])
		await create_timer(0.12).timeout
		game.jumper.set_physics_process(false)
		game.camera.set_physics_process(false)
		await _capture(game, prefix + "_playing")
		event.pressed = false
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		game.queue_free()
		await process_frame
	var file := FileAccess.open(OUT + "/rendered.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	quit()

func _capture(game: Node2D, label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png(OUT + "/" + label + ".png")
	var record := {"name": label, "phase": game._phase, "image_size": str(image.get_size()), "viewport": str(root.get_visible_rect().size), "save_error": result, "camera_offset": str(game.camera.offset), "jumper_position": str(game.jumper.position)}
	if is_instance_valid(game.start_menu):
		var menu: StartMenu = game.start_menu.get_node("StartMenu")
		record["overlay_alpha"] = menu.bg.modulate.a
		record["title_rect"] = str(menu.title_label.get_rect())
		record["cta_rect"] = str(menu.cta_panel.get_rect())
	records.append(record)
	print(JSON.stringify(record))
