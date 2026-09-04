extends SceneTree

var failures := 0

func _init() -> void:
	var game_scene := load("res://scenes/game/game.tscn") as PackedScene
	var game := game_scene.instantiate() as Node2D
	get_root().add_child(game)
	for _frame in 30:
		await process_frame

	_check(game.get_node_or_null("Jumper") is Jumper, "Jumper present")
	_check(game.get_node_or_null("VerticalCamera") is VerticalCamera, "VerticalCamera present")
	var platform_count := game.get_tree().get_nodes_in_group("platforms").size()
	_check(
		platform_count >= JumpConfig.PLATFORM_LAYOUT.size() and platform_count <= JumpConfig.MAX_ACTIVE_PLATFORMS,
		"endless platform buffer is present within its active ceiling"
	)
	var screenshot_path := "res://docs/assets/screenshots/jump_phase1.png"
	var image := get_root().get_viewport().get_texture().get_image()
	var saved := image.save_png(ProjectSettings.globalize_path(screenshot_path))
	_check(saved == OK and FileAccess.file_exists(screenshot_path), "screenshot saved")

	game.queue_free()
	print("JUMP SCREENSHOT: ALLE OK" if failures == 0 else "JUMP SCREENSHOT: %d FEHLER" % failures)
	quit(1 if failures > 0 else 0)

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ✓ " + description)
		return
	failures += 1
	print("  ✗ " + description)
