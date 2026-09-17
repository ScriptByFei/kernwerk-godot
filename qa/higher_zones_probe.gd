extends SceneTree

## Zonen 4 und 5 im ECHTEN Zeichenweg bei Geraetegroesse. Die headless-Suite
## prueft nur die Mathematik; hier wird belegt, dass die Schichten wirklich
## gezeichnet werden und wie sie auf dem Telefon aussehen.
##
## Aufruf:
## xvfb-run -a -s "-screen 0 430x932x24" godot4 --rendering-driver opengl3 \
##   --resolution 430x932 --path . -s qa/higher_zones_probe.gd

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const Background = preload("res://scripts/jump/shaft_background.gd")

const OUT := "/tmp/kernwerk-zone45"

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
	game.platform_director._clear_platforms()
	if game.hud != null:
		game.hud.visible = false
	game.camera.position = Vector2(540.0, 0.0)
	game.camera.force_update_scroll()
	await process_frame
	var reference: float = game._zone_height(game._get_visible_world_rect())
	# Zonenindex 2.55 (Zone 4 beginnt), 3.0 (Zone 4 voll), 3.55 (Kreuzblendung
	# beginnt), 3.78 (Mitte der Kreuzblendung), 4.0 (Zone 5 voll).
	# Die Hoehen kommen aus JumpConfig.zone_height_for_index (Umkehrfunktion) —
	# die Zonen sind unterschiedlich hoch, feste Pixelzahlen waeren falsch.
	var shots := [[2.2, "zone3-frei"], [2.55, "z4-start"], [3.0, "zone4"],
		[3.55, "kreuz-start"], [3.78, "kreuz-mitte"], [4.0, "zone5"]]
	for entry in shots:
		var index: float = entry[0]
		# Hoehe aus dem Zonenindex ABLEITEN (Umkehrfunktion), nicht mit einer
		# festen Schrittweite rechnen: die Zonen sind unterschiedlich hoch.
		var climbed: float = JumpConfig.zone_height_for_index(index)
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
		var z4 := Background.zone4_opacity_for_zone(index)
		var z5 := Background.zone5_opacity_for_zone(index)
		print("SCREENSHOT %s | index=%.2f | Zone4=%.3f | Zone5=%.3f | Summe=%.3f" % [
			path, index, z4, z5, z4 + z5])
	game.free()
	quit(0)
