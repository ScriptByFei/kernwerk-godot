extends SceneTree

## Deterministische Vergleichsbilder: identische Szene, nur HUD-Zustand variiert.
const Game = preload("res://scripts/game/game.gd")
var game
var out: String

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	out = OS.get_environment("KW_OVERLOAD_VISUAL_OUT")
	if out.is_empty():
		out = "/tmp/kernwerk-overload-choice/visual"
	DirAccess.make_dir_recursive_absolute(out)
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._phase = Game.Phase.PLAYING
	game.start_menu.free()
	game.jumper.set_process(false)
	game.jumper.set_physics_process(false)
	game.jumper._reactor_visual.pause()
	game.jumper._reactor_visual.frame = 0
	game.camera.set_physics_process(false)
	game.camera.offset = Vector2.ZERO
	game.camera.force_update_scroll()
	game._background_time = 0.0
	game.hud.set_process(false)
	game.hud.score = 123
	game.resonance.charges = 0
	await _shot("empty")
	game.resonance.charges = 2
	await _shot("two")
	game.resonance.charges = 3
	if game.hud.get("_pulse_time") != null:
		game.hud.set("_pulse_time", 0.4)
	await _shot("ready_high")
	if game.hud.get("_pulse_time") != null:
		game.hud.set("_pulse_time", 1.2)
	await _shot("ready_low")
	if game.resonance.has_method("arm_overload"):
		game.resonance.call("arm_overload")
		await _shot("armed_impulse")
		game.hud._process(0.31)
		await _shot("armed")
	game.free()
	await process_frame
	print("OVERLOAD VISUAL: rendered to ", out)
	quit()

func _shot(label: String) -> void:
	game.queue_redraw()
	game.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(430, 932, Image.INTERPOLATE_LANCZOS)
	if image.save_png(out.path_join(label + ".png")) != OK:
		quit(1)
