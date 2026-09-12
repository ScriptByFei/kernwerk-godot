extends SceneTree
const Game = preload("res://scripts/game/game.gd")

## Bewegungsaufnahme fuer Landing-Feedback, Kameraimpuls und Overload-Ring.
##
## Standbilder belegen nur, DASS etwas passiert. Diese Probe faehrt echte
## Landungen im laufenden Spiel und schreibt eine Bildfolge, aus der ein Video
## entsteht. Jeder Frame wird mit dem realen Kamerazustand aufgenommen, damit
## der Impuls im Verlauf sichtbar ist.

const OUT_DIR := "/tmp/kernwerk-six-phases/motion"
var _frame := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._phase = Game.Phase.PLAYING
	game.start_menu.visible = false
	game.jumper.set_physics_process(false)
	game.jumper.set_process(false)
	game.camera.set_physics_process(false)
	game.platform_director._clear_platforms()
	game.jumper.position = Vector2(540.0, 1042.0)
	game.camera.position = Vector2(540.0, 980.0)
	# Der Startmenue-Intro verschiebt den Offset auf 32; ohne Ruecksetzen waere
	# jede Messung um diesen Betrag verfaelscht.
	game.camera.offset = Vector2.ZERO
	game.camera._impact_remaining = 0.0
	game.camera._impact_fresh = false
	game.camera.force_update_scroll()

	var offsets := [130.0, 90.0, 0.0]
	var labels := ["normal", "resonance", "perfect"]
	# Drei volle Zyklen, damit auch die dritte Ladung und der Overload sichtbar
	# werden. Der Ring lebt 0.6 s, also braucht jeder Treffer viele Frames.
	for cycle in range(3):
		for i in range(3):
			var platform: JumpPlatform = _spawn(game, cycle * 3 + i)
			if cycle == 0 and i == 0:
				game.resonance.reset()
			# Ab Zyklus 2 nur noch RESONANCE-Landungen: erst damit laeuft die
			# Kette wirklich auf 3/3 und der Overload feuert.
			var quality_index := i if cycle == 0 else 1
			var tag: String = labels[quality_index]
			game.jumper.position = Vector2(platform.position.x + offsets[quality_index], platform.position.y - 58.0)
			game.camera.offset = Vector2.ZERO
			game.camera._impact_remaining = 0.0
			game.camera._impact_fresh = false
			game.jumper._resolve_landing(platform, false, game.jumper.position.x)
			var peak := 0.0
			for step in range(14):
				game.camera.advance_impact(1.0 / 60.0)
				peak = maxf(peak, game.camera.offset.y)
				game.jumper._process(1.0 / 60.0)
				game.queue_redraw()
				await RenderingServer.frame_post_draw
				_capture("%s-c%d-%d" % [tag, cycle, step])
			print("%s Ladungen=%d over=%d kamera_peak=%.2f" % [
				tag, game.resonance.charges, game.resonance.overload_count, peak])
	print("FRAMES ", _frame)
	game.free()
	quit()

## Eine frische Plattform je Treffer, damit die Kerbe der Landung nicht doppelt
## aufleuchtet und jede Landung real verbucht wird.
func _spawn(game: Node, index: int) -> JumpPlatform:
	var platform := JumpPlatform.new()
	platform.configure_variant(JumpPlatform.Variant.STANDARD)
	platform.position = Vector2(540.0, 1100.0)
	game.add_child(platform)
	platform.set_process(false)
	return platform

func _capture(tag: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		print("KEIN BILD bei ", tag)
		return
	image.save_png("%s/%03d-%s.png" % [OUT_DIR, _frame, tag])
	_frame += 1
