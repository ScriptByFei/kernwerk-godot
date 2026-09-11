extends SceneTree

## QA-Nachweis fuer die Resonanzmechanik. Faehrt den echten Landepfad
## (_resolve_landing -> overload_check -> ResonanceSystem) und nicht gesetzten
## Zustand. Die Overload-Anzeige wird ueber den ECHTEN Tick gehalten (Physik ->
## _process -> _draw), damit das Bild beweist, was der Spieler wirklich sieht.
## Evidence liegt in docs/assets/screenshots/resonance_chain/ (.gdignore).

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")

const OUT_DIR := "docs/assets/screenshots/resonance_chain"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	# Straight into gameplay; the choreography is not what this evidence shows.
	game._start_game()
	game._start_tween.pause()
	game._start_tween.custom_step(JumpConfig.START_TOTAL + 0.01)
	await process_frame

	var jumper = game.jumper
	var camera = game.camera
	jumper.set_physics_process(false)
	camera.set_physics_process(false)

	# Frame the reactor resting ON a real platform, partway up so the score is
	# non-zero. Collider bottom must sit exactly on the platform top edge:
	# anything else renders a floating core and makes the evidence misleading.
	var platform = game.platform_director._active_platforms[2]
	var rest_y: float = platform.global_position.y - JumpConfig.PLATFORM_SIZE.y * 0.5 - JumpConfig.JUMPER_SIZE.y * 0.5
	jumper.global_position = Vector2(platform.global_position.x - 2.0, rest_y)
	camera.global_position.y = jumper.global_position.y + JumpConfig.CAMERA_LEAD
	camera.force_update_scroll()
	game._update_score()
	await process_frame
	await process_frame
	_capture("01_no_charge.png")

	# Eine Ladung: das erste Segment fuellt sich.
	_land(jumper, platform, 0.0)
	await process_frame
	await process_frame
	_capture("02_one_charge.png")

	# Zwei Ladungen: OVERLOAD ist angekuendigt.
	_land(jumper, platform, 0.0)
	await process_frame
	await process_frame
	_capture("03_two_charges_overload_ready.png")

	# Die dritte Landung entlaedt den Overload. Die Anzeige wird ueber den
	# echten Spiel-Tick gehalten, nicht kuenstlich gesetzt.
	_land(jumper, platform, 0.0)
	await process_frame
	await process_frame
	_capture("04_overload_released.png")

	# Nach dem Overload steht die Resonanz wieder auf 0.
	await create_timer(JumpConfig.RESONANCE_OVERLOAD_DISPLAY_TIME + 0.1).timeout
	await process_frame
	_capture("05_reset_after_overload.png")

	# Schlechte Landung auf der Kante: die Ladung faellt auf 0.
	_land(jumper, platform, 0.0)
	await process_frame
	_land(jumper, platform, JumpConfig.PLATFORM_SIZE.x * 0.5 - 6.0)
	await process_frame
	await process_frame
	_capture("06_normal_landing_reset.png")

	print("charges=%d best=%d overloads=%d score=%d overload_display=%.2f" % [
		game.resonance.charges,
		game.resonance.best_charges,
		game.resonance.overload_count,
		game.score,
		game._overload_display
	])
	game.queue_free()
	await process_frame
	quit(0)

## Landung durch den echten Pfad. offset_x steuert die Landequalitaet.
func _land(jumper, platform, offset_x: float) -> void:
	jumper.velocity.y = 600.0
	jumper._resolve_landing(platform, false, platform.global_position.x + offset_x)

func _capture(file_name: String) -> void:
	var viewport := get_root()
	var image := viewport.get_texture().get_image()
	image.save_png("res://%s/%s" % [OUT_DIR, file_name])
	print("SAVED %s/%s %dx%d" % [OUT_DIR, file_name, image.get_width(), image.get_height()])
