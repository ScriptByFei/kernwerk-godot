extends SceneTree

## QA-Nachweis fuer das Pausenmenue. Faehrt den ECHTEN Weg: Spiel starten,
## Choreografie durchlaufen, per Tap auf den Knopf pausieren, dann aufnehmen.
## Ein Bild eines direkt gesetzten Zustands waere kein Nachweis.
## Evidence liegt in docs/assets/screenshots/pause_menu/ (.gdignore).

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")

const OUT_DIR := "docs/assets/screenshots/pause_menu"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	# Durch die echte Choreografie ins Spiel.
	game._start_game()
	game._start_tween.pause()
	game._start_tween.custom_step(JumpConfig.START_TOTAL + 0.01)
	await process_frame
	await process_frame
	var jumper = game.jumper
	var platform = game.platform_director._active_platforms[2]
	var rest_y: float = platform.global_position.y - JumpConfig.PLATFORM_SIZE.y * 0.5 - JumpConfig.JUMPER_SIZE.y * 0.5
	jumper.global_position = Vector2(platform.global_position.x - 2.0, rest_y)
	game.camera.global_position.y = jumper.global_position.y + JumpConfig.CAMERA_LEAD
	game.camera.force_update_scroll()
	game._update_score()
	await process_frame

	# 01: laufendes Spiel mit Pausenknopf oben rechts.
	_capture("01_playing_with_button.png")

	# 02: pausiert ueber den ECHTEN Tap-Pfad, Menue fertig eingeblendet.
	game._unhandled_input(_tap(game._pause_button_hit_rect().get_center()))
	await create_timer(JumpConfig.PAUSE_IN_DURATION + 0.12).timeout
	await process_frame
	_capture("02_paused.png")
	print("paused=%s tree_paused=%s score=%d" % [game._is_paused, paused, game.score])

	# 03: nach WEITER — Knopf zurueck, Welt laeuft.
	game.pause_menu._handle_tap(game.pause_menu.resume_rect().get_center())
	await create_timer(JumpConfig.PAUSE_OUT_DURATION + 0.12).timeout
	await process_frame
	_capture("03_after_resume.png")
	print("nach WEITER: paused=%s tree_paused=%s button=%s" % [
		game._is_paused, paused, game.pause_button.visible])

	paused = false
	game.queue_free()
	await process_frame
	quit(0)

func _tap(position: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	event.position = position
	return event

func _capture(file_name: String) -> void:
	var image := get_root().get_texture().get_image()
	image.save_png("res://%s/%s" % [OUT_DIR, file_name])
	print("SAVED %s/%s %dx%d" % [OUT_DIR, file_name, image.get_width(), image.get_height()])
