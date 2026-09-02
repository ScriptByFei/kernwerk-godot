extends SceneTree
## QA-Screenshot: neue prozedurale Figuren (Player + alle Gegner + Boss) im Spiel.
## Ausgabe nach docs/assets/screenshots/phase11_figures.png (via Xvfb, 540x960).

func _init() -> void:
	var game_scene := load("res://scenes/game/game.tscn") as PackedScene
	var game := game_scene.instantiate() as Node2D
	get_root().add_child(game)
	await process_frame
	await process_frame

	var grunt := Enemy.new()
	grunt.configure(0, 50, 0.0)
	game.add_child(grunt)
	grunt.position = Vector2(grunt.lane_x_now(), 150.0)
	var runner := Enemy.new()
	runner.configure(1, 50, 0.0, false, EnemyArchetypeData.RUNNER)
	game.add_child(runner)
	runner.position = Vector2(runner.lane_x_now(), 300.0)
	var tank := Enemy.new()
	tank.configure(2, 50, 0.0, false, EnemyArchetypeData.TANK)
	game.add_child(tank)
	tank.position = Vector2(tank.lane_x_now(), 450.0)
	var boss := Boss.new()
	boss.configure(1, 600)
	game.add_child(boss)
	boss.position = Vector2(boss.lane_x_now(), 100.0)
	await process_frame
	await process_frame

	var image := get_root().get_viewport().get_texture().get_image()
	image.save_png("res://docs/assets/screenshots/phase11_figures.png")
	print("SCREENSHOT SAVED: docs/assets/screenshots/phase11_figures.png")
	quit(0)
