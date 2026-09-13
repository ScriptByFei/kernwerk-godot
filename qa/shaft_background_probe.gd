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
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await _shot_at(0.0, "start")
	await _shot_at(1800.0, "zone1-mitte")
	var half_fade_height := JumpConfig.ZONE_HEIGHT_STEP - JumpConfig.ZONE_BLEND_RANGE + JumpConfig.ZONE_BLEND_RANGE * ShaftBackground.ZONE_FADE_START * 0.5
	await _shot_at(half_fade_height, "uebergang")
	await _contrast()
	quit(1 if failures else 0)

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
	game._background_time = 1.0
	game.camera.set_physics_process(false)
	# Kamera auf die Zielhoehe, dann die Plattformen in denselben Ausschnitt
	# setzen: ohne sie zeigt die Aufnahme nur die Wand.
	game.camera.position.y = -height + JumpConfig.CAMERA_LEAD
	game.camera.offset = Vector2.ZERO
	game.camera.force_update_scroll()
	if tag == "uebergang":
		# Spiel blendet nach SICHTBARER OBERKANTE, nicht nach Kamerazentrum.
		# Bisher zeigte diese Probe bereits den komplett verschwundenen Schacht.
		var previous_rect := game._get_visible_world_rect()
		game.camera.position.y += -height - previous_rect.position.y
		game.camera.force_update_scroll()
	game.platform_director._clear_platforms()
	var rect := game._get_visible_world_rect()
	var step := rect.size.y / 5.0
	var platforms: Array[JumpPlatform] = []
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
		platforms.append(platform)
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
	var actual_zone := JumpConfig.zone_index_at(-rect.position.y)
	print("%s zone=%.3f opacity=%.3f size=%dx%d" % [tag, actual_zone, ShaftBackground.opacity_for_zone(actual_zone), image.get_width(), image.get_height()])
	if tag == "uebergang" and not is_equal_approx(ShaftBackground.opacity_for_zone(actual_zone), 0.5):
		failures += 1
		print("FAIL: Uebergangsbild zeigt keine halbe Blendung")
	print("SCREENSHOT ", path)
	# Vergleich exakt unter sichtbaren Plattformkoerperpixeln, kein Rand-Stichpunkt.
	if tag == "zone1-mitte":
		for platform in platforms:
			platform.visible = false
		game.jumper.visible = false
		await process_frame
		await RenderingServer.frame_post_draw
		var background := root.get_texture().get_image()
		background.save_png(OUT + "/shaft-zone1-mitte-without-foreground.png")
		var ratios: Array[float] = []
		var body_hex := JumpConfig.PLATFORM_BODY_COLOR.to_html(false)
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x, y).to_html(false) == body_hex:
					ratios.append(_ratio(JumpConfig.PLATFORM_BODY_COLOR, background.get_pixel(x, y)))
		ratios.sort()
		if not ratios.is_empty():
			print("PLATFORM_FOOTPRINT pixels=%d min=%.3f p05=%.3f median=%.3f" % [ratios.size(), ratios[0], ratios[int(ratios.size() * 0.05)], ratios[ratios.size() / 2]])
			if ratios[0] < 1.81:
				failures += 1
				print("FAIL: Plattformkoerper-Kontrast unter 1.81")
		else:
			failures += 1
			print("FAIL: keine Plattformkoerperpixel gemessen")
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

## Historische Projektmetrik auf get_luminance(), kein linearisiertes WCAG.
func _ratio(a: Color, b: Color) -> float:
	var la := a.get_luminance() + 0.05
	var lb := b.get_luminance() + 0.05
	return maxf(la, lb) / minf(la, lb)
