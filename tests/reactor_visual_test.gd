extends SceneTree

const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const Jumper = preload("res://scripts/jump/jumper.gd")

const FRAME_DURATIONS_MS := [520.0, 130.0, 130.0, 420.0, 150.0, 150.0, 320.0, 150.0, 300.0, 150.0]
const FRAME_SIZE := Vector2(96.0, 96.0)
const FOOT_ANCHOR := Vector2(48.0, 92.0)
const TOTAL_DURATION_MS := 2420.0

var failures := 0

func _init() -> void:
	var jumper := Jumper.new()
	get_root().add_child(jumper)
	await process_frame
	var reactor_visual := jumper.get_node_or_null("ReactorVisual") as AnimatedSprite2D
	if reactor_visual == null:
		_check(false, "Jumper has a ReactorVisual AnimatedSprite2D child")
		_finish(jumper)
		return
	_check(true, "Jumper has a ReactorVisual AnimatedSprite2D child")
	_check_reactor_frames(reactor_visual)
	_check_visual_alignment(jumper, reactor_visual)
	await _check_animation_advances_while_physics_is_frozen(jumper, reactor_visual)
	_finish(jumper)

func _check_reactor_frames(reactor_visual: AnimatedSprite2D) -> void:
	var frames := reactor_visual.sprite_frames
	if frames == null:
		_check(false, "ReactorVisual has SpriteFrames")
		return
	_check(true, "ReactorVisual has SpriteFrames")
	_check(frames.has_animation(&"idle"), "idle animation exists")
	if not frames.has_animation(&"idle"):
		return
	_check(frames.get_frame_count(&"idle") == 10, "idle animation has 10 frames")
	_check(frames.get_animation_loop(&"idle"), "idle animation loops")
	var animation_speed := frames.get_animation_speed(&"idle")
	var total_duration_ms := 0.0
	for frame_index in FRAME_DURATIONS_MS.size():
		var texture := frames.get_frame_texture(&"idle", frame_index)
		_check(texture != null and not texture.get_size().is_zero_approx(), "frame %d texture is non-null and non-empty" % frame_index)
		if texture is AtlasTexture:
			_check(texture.region == Rect2(Vector2(frame_index * 96.0, 0.0), FRAME_SIZE), "frame %d has the exact 96x96 sheet region" % frame_index)
		else:
			_check(false, "frame %d uses an AtlasTexture region" % frame_index)
		var duration_ms := frames.get_frame_duration(&"idle", frame_index) / animation_speed * 1000.0
		total_duration_ms += duration_ms
		_check(is_equal_approx(duration_ms, FRAME_DURATIONS_MS[frame_index]), "frame %d has its approved duration" % frame_index)
	_check(is_equal_approx(total_duration_ms, TOTAL_DURATION_MS), "idle loop totals 2.42 seconds")
	_check(reactor_visual.is_playing(), "idle animation is playing")
	_check(reactor_visual.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "ReactorVisual uses nearest pixel filtering")
	_check(reactor_visual.scale == Vector2(1.5, 1.5), "ReactorVisual uses the approved 1.5 scale")

func _check_visual_alignment(jumper: Jumper, reactor_visual: AnimatedSprite2D) -> void:
	var collision := jumper.get_children().filter(func(child: Node): return child is CollisionShape2D).front() as CollisionShape2D
	if collision == null or not collision.shape is RectangleShape2D:
		_check(false, "Jumper keeps its centered 58x58 collision shape")
		return
	var collision_shape := collision.shape as RectangleShape2D
	_check(collision_shape.size == JumpConfig.JUMPER_SIZE and collision.position == Vector2.ZERO, "Jumper keeps its centered 58x58 collision shape")
	_check(jumper.collision_layer == 1 and jumper.collision_mask == 1, "Jumper keeps its collision layer and mask")
	var foot_position := reactor_visual.position + FOOT_ANCHOR * reactor_visual.scale
	var collider_bottom := collision.position.y + collision_shape.size.y * 0.5
	_check(foot_position.y == collider_bottom, "reactor foot exactly aligns to the collider bottom")
	jumper.position = Vector2(250.0, 400.0)
	_check(reactor_visual.global_position == jumper.global_position + reactor_visual.position, "ReactorVisual follows Jumper movement")

func _check_animation_advances_while_physics_is_frozen(jumper: Jumper, reactor_visual: AnimatedSprite2D) -> void:
	jumper.set_physics_process(false)
	var starting_frame := reactor_visual.frame
	var start_time_ms := Time.get_ticks_msec()
	await create_timer(0.7).timeout
	var elapsed_ms := Time.get_ticks_msec() - start_time_ms
	_check(elapsed_ms >= 600, "animation advancement waits for bounded process time")
	_check(reactor_visual.frame != starting_frame, "animation advances while Jumper physics is frozen")

func _finish(jumper: Jumper) -> void:
	print("REACTOR VISUAL: ALLE OK" if failures == 0 else "REACTOR VISUAL: %d FEHLER" % failures)
	jumper.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ✓ " + description)
		return
	failures += 1
	print("  ✗ " + description)
