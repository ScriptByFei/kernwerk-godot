extends SceneTree

## Sky Background Multi-Zone Probe: Rendert alle 5 Höhenzonen
## bei voller Produktionsgröße (430x932) mit echtem Gameplay-Aufbau.

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const SkyBackground = preload("res://scripts/jump/sky_background.gd")

const OUT := "/tmp/kernwerk-sky"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var game := Game.new()
	root.add_child(game)
	await process_frame
	
	game.set_process(false)
	game._phase = Game.Phase.PLAYING
	if game.start_menu != null:
		game.start_menu.visible = false
	game.jumper.set_physics_process(false)
	game.jumper.set_process(false)
	game.camera.set_physics_process(false)
	
	var zones := [
		{"idx": 0.0, "name": "zone1_sun_sky"},
		{"idx": 1.0, "name": "zone2_cloud_sea"},
		{"idx": 2.0, "name": "zone3_golden_hour"},
		{"idx": 3.0, "name": "zone4_twilight"},
		{"idx": 4.0, "name": "zone5_aurora"},
	]
	
	for z in zones:
		var zone_idx: float = z.idx
		var name_str: String = z.name
		
		# Canvas für diese Zone einhängen
		var sky_node := Node2D.new()
		sky_node.z_index = -50
		sky_node.draw.connect(func():
			SkyBackground.draw(sky_node, game._get_visible_world_rect(), zone_idx, 2.5)
		)
		game.add_child(sky_node)
		
		var climbed := JumpConfig.zone_height_for_index(zone_idx)
		game.camera.position = Vector2(540.0, -climbed)
		game.camera.force_update_scroll()
		game.jumper.position = Vector2(540.0, -climbed + 800.0)
		
		sky_node.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		
		var path := "%s/%s.png" % [OUT, name_str]
		var img := root.get_texture().get_image()
		if img.save_png(path) != OK:
			print("FEHLER beim Speichern von ", path)
			quit(1)
			return
		print("Gespeichert: %s (Zone %.1f)" % [path, zone_idx])
		sky_node.queue_free()
		
	print("ALLE 5 ZONEN ERFOLGREICH GERENDERT!")
	quit(0)
