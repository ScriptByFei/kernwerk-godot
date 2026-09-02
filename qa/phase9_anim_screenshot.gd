extends SceneTree
## QA-Screenshot: animierte Sprites (Player + Grunt + Boss) im echten Render.
## Ausgabe nach docs/assets/screenshots/phase9_anim.png (via Xvfb, 540x960).

func _init() -> void:
	var game_scene := load("res://scenes/game/game.tscn") as PackedScene
	var game := game_scene.instantiate() as Node2D
	get_root().add_child(game)
	await process_frame
	await process_frame

	# Boss + Grunt zusätzlich spawnen (sichtbar im oberen Bereich)
	var boss := Boss.new()
	boss.configure(0, 600)
	game.add_child(boss)
	boss.position = Vector2(boss.lane_x_now(), 120.0)
	var grunt := Enemy.new()
	grunt.configure(2, 50, 0.0)
	game.add_child(grunt)
	grunt.position = Vector2(grunt.lane_x_now(), 300.0)
	await process_frame
	await process_frame

	var image := get_root().get_viewport().get_texture().get_image()
	image.save_png("res://docs/assets/screenshots/phase9_anim.png")
	print("SCREENSHOT SAVED: docs/assets/screenshots/phase9_anim.png")
	quit(0)
