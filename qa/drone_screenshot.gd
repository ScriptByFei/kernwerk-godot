extends SceneTree
## QA-Screenshot: Drohne in der echten Game-Szene rendern.
## Deterministisch: Drohne wird direkt über den SpawnManager gespawnt (kein Warten auf Welle 3).
## Aufruf: xvfb-run godot4 --headless -s qa/drone_screenshot.gd

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
	# Kurz laufen lassen, bis die Szene aufgebaut ist
	for _f in 60:
		await process_frame

	# Drohne deterministisch in Lane 1 spawnen
	var spawner := game.get_node_or_null("SpawnManager")
	_check(spawner != null, "SpawnManager gefunden")
	if spawner:
		spawner._spawn_enemy(1, EnemyArchetypeData.DRONE)
	# Ein paar Frames rendern, damit das Sprite sichtbar ist
	for _f in 30:
		await process_frame

	var img := get_root().get_viewport().get_texture().get_image()
	var out := "/home/masgi_bot/projects/kernwerk-godot/docs/assets/screenshots/drone_ingame.png"
	img.save_png(out)
	_check(FileAccess.file_exists(out), "Screenshot gespeichert: " + out)

	# Drohnen-Präsenz im echten Baum prüfen
	var drone_count := 0
	for node in get_root().find_children("*", "Enemy", true, false):
		if node.enemy_type == EnemyArchetypeData.DRONE:
			drone_count += 1
	_check(drone_count >= 1, "Mindestens 1 Drohne in der Szene (gefunden: %d)" % drone_count)

	game.queue_free()
	await process_frame
	print("DRONE SCREENSHOT: ", "ALLE OK" if fails == 0 else "%d FEHLER" % fails)
	quit(1 if fails > 0 else 0)
