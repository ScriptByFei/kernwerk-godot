extends SceneTree

const Game = preload("res://scripts/game/game.gd")

func _init() -> void:
	var game := Game.new()
	get_root().add_child(game)
	await process_frame
	await process_frame
	# Capture the start menu before any tap.
	var viewport := get_root()
	var image := viewport.get_texture().get_image()
	image.save_png("res://docs/assets/screenshots/start_menu.png")
	print("SAVED start_menu.png")
	game.queue_free()
	await process_frame
	quit(0)
