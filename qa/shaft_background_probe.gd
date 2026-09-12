extends SceneTree
const Game = preload("res://scripts/game/game.gd")

## Visualprobe fuer den Reaktorschacht-Hintergrund bei echter Telefonbreite
## (430x932).
##
## Erste Fassung dieser Probe schaute an den Plattformen vorbei: sie setzte die
## Kamera auf eine Hoehe, auf der keine Plattform lag, und zeigte damit eine
## leere Wand. Beurteilt werden muss aber die ECHTE Spielsituation — Reaktor und
## Plattformen im Vordergrund. Deshalb laeuft das Spiel hier real an.

const OUT := "/tmp/kernwerk-six-phases/shaft"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await _shot_at(0.0, "start")
	await _shot_at(1800.0, "zone1-mitte")
	await _shot_at(float(JumpConfig.ZONE_HEIGHT_STEP) * 0.8, "uebergang")
	await _contrast()
	quit()

## Laesst das Spiel real anlaufen und setzt die Kamera danach auf die
## gewuenschte Hoehe, wobei die Plattformen mitwandern.
func _shot_at(height: float, tag: String) -> void:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	# Direkt in den Spielzustand: _enter_playing() verlangt Phase.STARTING und
	# bricht hier ab. Das Startmenue liegt in einer CanvasLayer ueber allem und
	# muss weg, sonst zeigt die Aufnahme das Menue statt des Spiels.
	game._phase = Game.Phase.PLAYING
	if is_instance_valid(game.start_menu):
		game.start_menu.visible = false
	await process_frame
	game.set_process(false)
	game.jumper.set_physics_process(false)
	game.camera.set_physics_process(false)
	# Kamera auf die Zielhoehe, dann die Plattformen in denselben Ausschnitt
	# setzen: ohne sie zeigt die Aufnahme nur die Wand.
	game.camera.position.y = -height + JumpConfig.CAMERA_LEAD
	game.camera.offset = Vector2.ZERO
	game.camera.force_update_scroll()
	game.platform_director._clear_platforms()
	var rect := game._get_visible_world_rect()
	var step := rect.size.y / 5.0
	for index in range(5):
		var platform := JumpPlatform.new()
		platform.configure_variant([
			JumpPlatform.Variant.STANDARD,
			JumpPlatform.Variant.NARROW,
			JumpPlatform.Variant.RISKY,
			JumpPlatform.Variant.STANDARD,
			JumpPlatform.Variant.NARROW,
		][index])
		platform.position = Vector2([300.0, 800.0, 420.0, 760.0, 340.0][index],
			rect.position.y + step * (float(index) + 0.5))
		game.add_child(platform)
		platform.set_process(false)
	# Reaktor in die Bildmitte, damit der Vordergrundkontrast beurteilbar ist.
	game.jumper.visible = true
	game.jumper.position = Vector2(540.0, rect.position.y + rect.size.y * 0.6)
	game.jumper.set_process(false)
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/shaft-%s.png" % [OUT, tag]
	image.save_png(path)
	print("%s zone=%.2f size=%dx%d" % [tag, JumpConfig.zone_index_at(height), image.get_width(), image.get_height()])
	print("SCREENSHOT ", path)
	game.free()
	await process_frame

## Kontrastmessung: der Vordergrund muss sich vom Hintergrund abheben.
func _contrast() -> void:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game._phase = Game.Phase.PLAYING
	if is_instance_valid(game.start_menu):
		game.start_menu.visible = false
	await process_frame
	game.set_process(false)
	game.camera.force_update_scroll()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var bg := image.get_pixel(8, int(image.get_height() * 0.5))
	print("Hintergrund Randmitte: ", bg.to_html(false))
	print("Plattformkoerper:     ", JumpConfig.PLATFORM_BODY_COLOR.to_html(false))
	print("Kontrastverhaeltnis Plattform/Hintergrund: %.2f:1" % _ratio(JumpConfig.PLATFORM_BODY_COLOR, bg))
	print("Kontrastverhaeltnis Mittelmarkierung/Hintergrund: %.2f:1" % _ratio(JumpConfig.PLATFORM_CENTER_MARK_COLOR, bg))
	game.free()

## WCAG-Kontrastverhaeltnis.
func _ratio(a: Color, b: Color) -> float:
	var la := a.get_luminance() + 0.05
	var lb := b.get_luminance() + 0.05
	return maxf(la, lb) / minf(la, lb)
