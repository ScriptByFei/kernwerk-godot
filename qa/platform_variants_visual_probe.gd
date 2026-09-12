extends SceneTree
const Game = preload("res://scripts/game/game.gd")

## Plattformvarianten-Visualprobe: stellt alle vier Routenvarianten untereinander
## in denselben Ausschnitt, damit Kerben und Resonanzband vergleichbar sind.
func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._phase = Game.Phase.PLAYING
	game.start_menu.visible = false
	game.hud.visible = false
	game.jumper.set_physics_process(false)
	game.jumper.set_process(false)
	game.jumper.visible = false
	game.camera.set_physics_process(false)
	game.camera.position = Vector2(540.0, 900.0)
	game.camera.offset = Vector2.ZERO
	game.camera.force_update_scroll()
	game.platform_director._clear_platforms()
	var variants := [
		JumpPlatform.Variant.STANDARD,
		JumpPlatform.Variant.NARROW,
		JumpPlatform.Variant.RESONANCE_FOCUS,
		JumpPlatform.Variant.RISKY,
	]
	var labels := ["standard", "schmal", "resonanzfokus", "riskant"]
	for index in range(variants.size()):
		var platform := JumpPlatform.new()
		platform.configure_variant(variants[index])
		platform.position = Vector2(540.0, 780.0 + float(index) * 130.0)
		game.add_child(platform)
		platform.set_process(false)
		print(labels[index], " width=", platform.platform_size.x,
			" perfect=", "%.1f" % JumpConfig.perfect_band_width(platform.platform_size.x),
			" resonance=", "%.1f" % platform.resonance_band_width(),
			" normal_rand=", "%.1f" % ((platform.platform_size.x - platform.resonance_band_width()) * 0.5))
		# Echte Landungen aller drei Qualitaeten fuer das Impact-Feedback.
		platform.trigger_impact(JumpConfig.LandingQuality.PERFECT, 540.0)
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "/tmp/kernwerk-six-phases/phase5-platform-variants.png"
	if root.get_texture().get_image().save_png(path) != OK:
		quit(1)
		return
	print("SCREENSHOT ", path)
	game.free()
	quit()
