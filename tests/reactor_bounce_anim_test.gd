extends SceneTree

const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const Jumper = preload("res://scripts/jump/jumper.gd")
const JUMP_FRAMES = preload("res://assets/jump/reactor_core/reactor_jump_frames.tres")
const LAND_FRAMES = preload("res://assets/jump/reactor_core/reactor_land_frames.tres")

const FRAME_SIZE := Vector2(96.0, 96.0)

var failures := 0

func _init() -> void:
	_check_jump_frames()
	_check_land_frames()
	await _check_bounce_sequence()
	_finish()

func _check_jump_frames() -> void:
	_check(JUMP_FRAMES.has_animation(&"jump"), "jump animation exists")
	if not JUMP_FRAMES.has_animation(&"jump"):
		return
	_check(JUMP_FRAMES.get_frame_count(&"jump") == 6, "jump animation has 6 frames")
	_check(not JUMP_FRAMES.get_animation_loop(&"jump"), "jump animation does not loop")
	for frame_index in 6:
		var texture := JUMP_FRAMES.get_frame_texture(&"jump", frame_index)
		_check(texture != null and not texture.get_size().is_zero_approx(), "jump frame %d texture is non-null and non-empty" % frame_index)
		if texture is AtlasTexture:
			_check(texture.region == Rect2(Vector2(frame_index * 96.0, 0.0), FRAME_SIZE), "jump frame %d has the exact 96x96 sheet region" % frame_index)

func _check_land_frames() -> void:
	_check(LAND_FRAMES.has_animation(&"land"), "land animation exists")
	if not LAND_FRAMES.has_animation(&"land"):
		return
	_check(LAND_FRAMES.get_frame_count(&"land") == 6, "land animation has 6 frames")
	_check(not LAND_FRAMES.get_animation_loop(&"land"), "land animation does not loop")
	for frame_index in 6:
		var texture := LAND_FRAMES.get_frame_texture(&"land", frame_index)
		_check(texture != null and not texture.get_size().is_zero_approx(), "land frame %d texture is non-null and non-empty" % frame_index)
		if texture is AtlasTexture:
			_check(texture.region == Rect2(Vector2(frame_index * 96.0, 0.0), FRAME_SIZE), "land frame %d has the exact 96x96 sheet region" % frame_index)

func _check_bounce_sequence() -> void:
	var jumper := Jumper.new()
	get_root().add_child(jumper)
	await process_frame
	var reactor_visual := jumper.get_node_or_null("ReactorVisual") as AnimatedSprite2D
	if reactor_visual == null:
		_check(false, "Jumper has a ReactorVisual AnimatedSprite2D child")
		jumper.queue_free()
		await process_frame
		return
	_check(reactor_visual.animation == &"idle", "starts on idle animation")
	# Trigger a bounce by simulating a descending landing.
	jumper.velocity = Vector2(0.0, JumpConfig.BASE_BOUNCE_SPEED)
	jumper.bounce_from(null, false)
	_check(reactor_visual.animation == &"land", "bounce immediately plays land animation")
	await _wait_for_animation(reactor_visual, &"jump")
	_check(reactor_visual.animation == &"jump", "land is followed by jump animation")
	await _wait_for_animation(reactor_visual, &"idle")
	_check(reactor_visual.animation == &"idle", "jump returns to idle animation")
	jumper.queue_free()
	await process_frame

func _wait_for_animation(reactor_visual: AnimatedSprite2D, expected: StringName) -> void:
	var guard := 0
	while reactor_visual.animation != expected and guard < 200:
		await process_frame
		guard += 1

func _finish() -> void:
	print("REACTOR BOUNCE ANIM: ALLE OK" if failures == 0 else "REACTOR BOUNCE ANIM: %d FEHLER" % failures)
	quit(1 if failures > 0 else 0)

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ✓ " + description)
		return
	failures += 1
	print("  ✗ " + description)
