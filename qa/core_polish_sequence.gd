extends SceneTree

# Controlled QA placement, NOT an ordinary player run. No impact/bounce injection.
# Run with --fixed-fps 60 --audio-driver Dummy under Xvfb.
var OUT := "res://docs/assets/screenshots/core_polish_sequence/"
var game: Node2D
var rows: Array = []
var contacts: Array = []
var frame := 0
var stage := "menu"
var target: JumpPlatform
var previous_vy := 0.0

func _init() -> void:
	_run.call_deferred()

func _on_landed(platform: JumpPlatform, quality: int, bonus: int) -> void:
	var normals: Array = []
	for i in game.jumper.get_slide_collision_count():
		normals.append(str(game.jumper.get_slide_collision(i).get_normal()))
	contacts.append({"frame": frame, "stage": stage, "quality": quality, "previous_render_vy": previous_vy, "bounce_vy": game.jumper.velocity.y, "platform_id": platform.get_instance_id(), "target_id": target.get_instance_id() if is_instance_valid(target) else 0, "slide_normals": normals, "on_floor": game.jumper.is_on_floor(), "platform_impact_count": platform.impact_count, "bonus": bonus})

func _frames(count: int) -> void:
	for i in count:
		await RenderingServer.frame_post_draw
		var j: Jumper = game.jumper
		var p := j.get_global_transform_with_canvas().origin
		var image := root.get_texture().get_image()
		var result := image.save_png(OUT + "frame_%04d.png" % frame)
		if result != OK:
			push_error("Capture failed")
			quit(2)
		rows.append({"frame": frame, "t": frame / 60.0, "stage": stage, "phase": game._phase, "game_over": game.is_game_over, "jumper_id": j.get_instance_id(), "x": j.position.x, "y": j.position.y, "vy": j.velocity.y, "canvas_x": p.x, "canvas_y": p.y, "camera_y": game.camera.position.y, "camera_offset": game.camera.offset.y, "physics": j.is_physics_processing(), "process": j.is_processing(), "animation": str(j._reactor_visual.animation), "animation_frame": j._reactor_visual.frame, "animation_playing": j._reactor_visual.is_playing(), "modulate": [j.modulate.r,j.modulate.g,j.modulate.b,j.modulate.a], "world_modulate": str(game.modulate), "score": game.score, "landing_count": j.landing_count, "core_remaining": j._impact_remaining, "platform_elapsed": target.impact_elapsed if is_instance_valid(target) else -1, "platform_active": target.impact_active if is_instance_valid(target) else false, "initial_bounce": game._initial_bounce_fired, "menu_present": is_instance_valid(game.start_menu), "width": image.get_width(), "height": image.get_height()})
		previous_vy = j.velocity.y
		frame += 1

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			OUT = arg.trim_prefix("--out=").trim_suffix("/") + "/"
	if FileAccess.file_exists(OUT + "telemetry.json"):
		push_error("Refusing to overwrite existing sequence: " + OUT)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ignore := FileAccess.open(OUT + ".gdignore", FileAccess.WRITE)
	ignore.close()
	root.size = Vector2i(390, 844)
	game = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.jumper.landed.connect(_on_landed)
	await _frames(30)
	stage = "start_transition"
	var tap := InputEventScreenTouch.new()
	tap.index = 0
	tap.pressed = true
	tap.position = Vector2(195, 650)
	Input.parse_input_event(tap)
	await _frames(1)
	tap = InputEventScreenTouch.new()
	tap.index = 0
	tap.pressed = false
	tap.position = Vector2(195, 650)
	Input.parse_input_event(tap)
	await _frames(65)
	for quality in 3:
		stage = ["normal", "resonance", "perfect"][quality]
		target = game.platform_director._active_platforms[0]
		# Place above existing starting ledge; all subsequent movement is production physics.
		game.jumper.position = target.position + Vector2([90.0,30.0,0.0][quality], -190.0)
		game.jumper.velocity = Vector2(0, 450)
		game.jumper.clear_horizontal_target()
		game.camera.position = Vector2(540, target.position.y + 70)
		game.camera.reset_smoothing()
		await _frames(60)
	stage = "death_controlled_fall"
	# A real descent across the production death line, with core on screen.
	game.jumper.position = Vector2(920, game.camera.position.y + JumpConfig.FALL_DEATH_MARGIN - 100)
	game.jumper.velocity = Vector2(0, 600)
	game.jumper.clear_horizontal_target()
	await _frames(70)
	var file := FileAccess.open(OUT + "telemetry.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"setup": "Controlled QA repositioning above real production ledge at offsets 90/30/0. Actual move_and_slide; no direct impact, bounce, death, restart or tween stepping. Fixed 60 fps; captures after frame_post_draw. Death positioned 100 world units above live death line at x920.", "fps": 60, "frames": rows, "contacts": contacts}, "\t"))
	file.close()
	print("CORE_SEQUENCE_DONE frames=", frame, " contacts=", JSON.stringify(contacts))
	quit()
