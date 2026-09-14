extends SceneTree

## Kuehlsektion im echten Fenster: rendert den Schacht auf mehreren Hoehen und
## haelt Bilder fest. Belegt, dass die neue Schicht im ECHTEN Zeichenweg
## ankommt — die headless-Suite prueft nur die Mathematik.
##
## Aufruf:
## xvfb-run -a -s "-screen 0 430x932x24" godot4 --rendering-driver opengl3 \
##   --resolution 430x932 --path . -s qa/cooling_zone_probe.gd

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const Background = preload("res://scripts/jump/shaft_background.gd")

const OUT := "/tmp/kernwerk-zone2"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
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
	game.platform_director._clear_platforms()
	if game.hud != null:
		game.hud.visible = false
	game.camera.position = Vector2(540.0, 0.0)
	game.camera.force_update_scroll()
	await process_frame
	var reference: float = game._zone_height(game._get_visible_world_rect())
	var step: float = JumpConfig.ZONE_HEIGHT_STEP
	# Hoehen als Zonenindex: Zone 1 voll, Mitte der Kreuzblendung, Zone 2 voll,
	# Ende der Kuehlsektion, Zone 3 (muss leer sein).
	for entry in [[0.0, "zone1"], [0.3, "kreuz-30"], [0.55, "kreuz-55"], [1.0, "zone2"],
			[1.55, "zone2-ende"], [2.2, "zone3"]]:
		var index: float = entry[0]
		var climbed: float = step * index
		game.camera.position = Vector2(540.0, reference - climbed)
		game.camera.offset = Vector2.ZERO
		game.camera.force_update_scroll()
		game.jumper.position = Vector2(540.0, 880.0 - climbed)
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [OUT, entry[1]]
		var image := root.get_texture().get_image()
		if image.save_png(path) != OK:
			print("FEHLER beim Schreiben von ", path)
			quit(1)
			return
		# Die Deckkraft der beiden Schichten an genau dieser Hoehe mitdrucken:
		# damit ist die Messreihe im Bild UND als Zahl belegt.
		var shaft := Background.opacity_for_zone(index)
		var cooling := Background.cooling_opacity_for_zone(index)
		print("SCREENSHOT %s | index=%.2f | Schacht=%.3f | Kuehlung=%.3f | Summe=%.3f" % [
			path, index, shaft, cooling, shaft + cooling])
	game.free()
	quit(0)
