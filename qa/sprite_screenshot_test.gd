extends SceneTree
## Wegwerf-Screenshot-Beweis: rendert die echte Game-Szene und speichert PNG.
## Nur für QA — kein Bestandteil des Spiels. Aufruf: xvfb-run godot4 --headless -s

var fails := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ " + msg)
	else:
		fails += 1
		print("  ✗ " + msg)

func _init() -> void:
	var game_scene := load("res://scenes/game/game.tscn") as PackedScene
	var game := game_scene.instantiate() as Node2D
	get_root().add_child(game)
	# Spiel länger laufen lassen, bis Gegner + Spawns sichtbar sind (~3s bei 60fps)
	for _f in 240:
		await process_frame

	var img := get_root().get_viewport().get_texture().get_image()
	var out := "/home/masgi_bot/projects/kernwerk-godot/docs/assets/screenshots/ingame_sprites.png"
	img.save_png(out)
	_check(FileAccess.file_exists(out), "Screenshot gespeichert: " + out)

	# Sprite2D-Präsenz im echten Baum prüfen
	var sprite_count := 0
	for node in get_root().find_children("*", "Sprite2D", true, false):
		sprite_count += 1
	_check(sprite_count >= 3, "Mindestens 3 Sprite2D in der Szene (gefunden: %d)" % sprite_count)

	game.queue_free()
	await process_frame
	print("SPRITE SCREENSHOT TEST: ", "ALLE OK" if fails == 0 else "%d FEHLER" % fails)
	quit(1 if fails > 0 else 0)
