extends SceneTree

## QA screenshot proof for core gameplay polish.
## Renders the industrial platform with center mark, a normal landing, a
## resonance landing, a perfect landing, and the death/shutdown dim into
## docs/assets/screenshots/core_polish/ (ignored by export via .gdignore).

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const Jumper = preload("res://scripts/jump/jumper.gd")
const Platform = preload("res://scripts/jump/platform.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# 1) Platform with center mark, no impact.
	var world := Node2D.new()
	var platform := Platform.new()
	platform.position = Vector2(540, 500)
	world.add_child(platform)
	root.add_child(world)
	await process_frame
	await process_frame
	_capture("docs/assets/screenshots/core_polish/platform_idle.png")

	# 2) Normal landing impact (edge contact).
	platform.trigger_impact(JumpConfig.LandingQuality.NORMAL, 540.0 + 90.0)
	await process_frame
	_capture("docs/assets/screenshots/core_polish/landing_normal.png")

	# 3) Resonance landing impact (near center).
	platform.trigger_impact(JumpConfig.LandingQuality.RESONANCE, 540.0 + 30.0)
	await process_frame
	_capture("docs/assets/screenshots/core_polish/landing_resonance.png")

	# 4) Perfect landing impact (center) with dashes.
	platform.trigger_impact(JumpConfig.LandingQuality.PERFECT, 540.0)
	await process_frame
	_capture("docs/assets/screenshots/core_polish/landing_perfect.png")

	world.queue_free()
	await process_frame

	# 5) Death/shutdown dim on the reactor.
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game._start_game()
	game._start_tween.pause()
	game._start_tween.custom_step(JumpConfig.START_TOTAL + 0.01)
	await process_frame
	game.jumper.position.y = game.camera.position.y + JumpConfig.FALL_DEATH_MARGIN + 1
	game._check_game_over()
	await create_timer(JumpConfig.DEATH_DIM_DURATION * 0.5).timeout
	_capture("docs/assets/screenshots/core_polish/death_dim.png")
	game.queue_free()
	await process_frame
	quit(0)

func _capture(path: String) -> void:
	var viewport := get_root()
	var image := viewport.get_texture().get_image()
	image.save_png("res://" + path)
	print("SAVED " + path)
