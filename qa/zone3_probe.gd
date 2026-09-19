extends SceneTree

## Zone 3 (Hochspannung) im ECHTEN Zeichenweg bei Geraetegroesse. Die
## headless-Suite prueft nur die Mathematik; hier wird belegt, dass die Schicht
## wirklich gezeichnet wird und wie sie auf dem Telefon aussieht.
##
## Zusaetzlich wird die Deckkraft der drei beteiligten Schichten als ZAHL
## mitgedruckt — damit ist die Messreihe im Bild UND als Wert belegt, und ein
## leeres Fenster waere nicht als "dunkle Zone" fehlzuinterpretieren.
##
## Aufruf:
## xvfb-run -a -s "-screen 0 430x932x24" godot4 --rendering-driver opengl3 \
##   --resolution 430x932 --path . -s qa/zone3_probe.gd

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const Background = preload("res://scripts/jump/shaft_background.gd")

const OUT := "/tmp/kernwerk-zone3"

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
	# Zonenindex: Ende der Kuehlsektion, Anfang des Einblendens, Mitte, voll,
	# Anfang des Ausblendens, und der Uebergang zu Zone 4.
	# Die Hoehen kommen aus der Umkehrfunktion — die Zonen sind unterschiedlich
	# hoch, feste Pixelzahlen waeren falsch.
	var shots := [[1.55, "z3-einblend-start"], [1.78, "z3-einblend-mitte"],
		[2.0, "z3-voll"], [2.28, "z3-traegt"], [2.55, "z3-ausblend-start"],
		[2.78, "z3-ausblend-mitte"]]
	for entry in shots:
		var index: float = entry[0]
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
		# Deckkraft der beteiligten Schichten an genau dieser Hoehe: damit ist
		# belegt, dass die gespiegelten Fenster greifen.
		print("%s  index=%.2f  kuehlung=%.2f  zone3=%.2f  zone4=%.2f  summe=%.2f" % [
			entry[1], index,
			Background.cooling_opacity_for_zone(index),
			Background.zone3_opacity_for_zone(index),
			Background.zone4_opacity_for_zone(index),
			Background.cooling_opacity_for_zone(index)
				+ Background.zone3_opacity_for_zone(index)
				+ Background.zone4_opacity_for_zone(index)])
	print("ZONE3 PROBE: %d Bilder in %s" % [shots.size(), OUT])
	quit(0)
