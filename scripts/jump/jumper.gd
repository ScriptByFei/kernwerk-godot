class_name Jumper
extends CharacterBody2D

const REACTOR_IDLE_FRAMES := preload("res://assets/jump/reactor_core/reactor_idle_frames.tres")
const REACTOR_JUMP_FRAMES := preload("res://assets/jump/reactor_core/reactor_jump_frames.tres")
const REACTOR_LAND_FRAMES := preload("res://assets/jump/reactor_core/reactor_land_frames.tres")

signal bounced
signal landed(platform: JumpPlatform, quality: JumpConfig.LandingQuality, bonus: int)

var horizontal_intent := 0.0
var horizontal_target_x := 0.0
var has_horizontal_target := false

var _reactor_visual: AnimatedSprite2D
var _bounce_sequence: Array[StringName] = []
var last_landing_quality := JumpConfig.LandingQuality.NORMAL
var landing_count := 0
var _contact_latched := false
var _impact_remaining := 0.0
var _feedback_visual: Node2D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = JumpConfig.JUMPER_SIZE
	collision.shape = shape
	add_child(collision)
	_create_reactor_visual()
	_feedback_visual = Node2D.new()
	_feedback_visual.name = "CoreContactLight"
	add_child(_feedback_visual)
	_feedback_visual.draw.connect(_draw_contact_light)

func _create_reactor_visual() -> void:
	_reactor_visual = AnimatedSprite2D.new()
	_reactor_visual.name = "ReactorVisual"
	_reactor_visual.sprite_frames = REACTOR_IDLE_FRAMES
	_reactor_visual.animation = &"idle"
	_reactor_visual.autoplay = &"idle"
	_reactor_visual.centered = false
	_reactor_visual.position = JumpConfig.REACTOR_VISUAL_POSITION
	_reactor_visual.scale = JumpConfig.REACTOR_VISUAL_SCALE
	_reactor_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_reactor_visual)
	_reactor_visual.play()

func _process(delta: float) -> void:
	if _impact_remaining > 0.0:
		_impact_remaining = maxf(0.0, _impact_remaining - delta)
		_feedback_visual.queue_redraw()
	if _reactor_visual.is_playing():
		return
	_play_next_bounce_animation()

func _play_next_bounce_animation() -> void:
	if _reactor_visual == null:
		return
	if _bounce_sequence.is_empty():
		_reactor_visual.sprite_frames = REACTOR_IDLE_FRAMES
		_reactor_visual.animation = &"idle"
		_reactor_visual.speed_scale = 1.0
		_reactor_visual.play()
		return
	var anim: StringName = _bounce_sequence.pop_front()
	_reactor_visual.sprite_frames = _frames_for(anim)
	_reactor_visual.animation = anim
	_reactor_visual.speed_scale = JumpConfig.LAND_ANIMATION_SPEED if anim == &"land" else JumpConfig.JUMP_ANIMATION_SPEED
	_reactor_visual.play()

func _frames_for(anim: StringName) -> SpriteFrames:
	match anim:
		&"jump":
			return REACTOR_JUMP_FRAMES
		&"land":
			return REACTOR_LAND_FRAMES
		_:
			return REACTOR_IDLE_FRAMES

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	apply_horizontal_steering(delta)
	var was_descending := velocity.y > 0.0
	var contact_center := global_position
	move_and_slide()
	if not is_on_floor():
		_contact_latched = false
	if was_descending and is_on_floor() and not _contact_latched:
		for index in get_slide_collision_count():
			var contact := get_slide_collision(index)
			# move_and_slide can continue horizontally after impact. Reconstruct
			# the core center at each collision, not its end-of-tick position.
			contact_center += contact.get_travel()
			var platform := contact.get_collider() as JumpPlatform
			if platform != null and contact.get_normal().dot(up_direction) >= cos(floor_max_angle):
				_contact_latched = true
				_resolve_landing(platform, false, contact_center.x)
				break

func apply_gravity(delta: float) -> void:
	velocity.y += JumpConfig.GRAVITY * delta

func set_horizontal_intent(intent: float) -> void:
	has_horizontal_target = false
	horizontal_intent = clampf(intent, -1.0, 1.0)

func set_horizontal_target(target_x: float) -> void:
	horizontal_target_x = target_x
	has_horizontal_target = true

func clear_horizontal_target() -> void:
	has_horizontal_target = false
	horizontal_intent = 0.0

func apply_horizontal_steering(delta: float) -> void:
	var target_speed := horizontal_intent * JumpConfig.MAX_HORIZONTAL_SPEED
	if has_horizontal_target:
		var distance := horizontal_target_x - global_position.x
		if absf(distance) <= JumpConfig.HORIZONTAL_TARGET_DEADZONE:
			target_speed = 0.0
		else:
			var proportional_speed := absf(distance) / JumpConfig.HORIZONTAL_TARGET_DISTANCE * JumpConfig.MAX_HORIZONTAL_SPEED
			var stopping_speed := sqrt(2.0 * JumpConfig.HORIZONTAL_BRAKING * absf(distance))
			target_speed = signf(distance) * minf(JumpConfig.MAX_HORIZONTAL_SPEED, minf(proportional_speed, stopping_speed))
	var rate := JumpConfig.HORIZONTAL_ACCELERATION
	if is_zero_approx(target_speed):
		rate = JumpConfig.HORIZONTAL_DRAG
	elif velocity.x * target_speed < 0.0:
		rate = JumpConfig.HORIZONTAL_REVERSAL
	elif absf(target_speed) < absf(velocity.x):
		rate = JumpConfig.HORIZONTAL_BRAKING
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	velocity.x = clampf(velocity.x, -JumpConfig.MAX_HORIZONTAL_SPEED, JumpConfig.MAX_HORIZONTAL_SPEED)

func bounce_from(platform: JumpPlatform, is_overload: bool) -> bool:
	if velocity.y <= 0.0:
		return false
	_resolve_landing(platform, is_overload, global_position.x)
	return true

func _resolve_landing(platform: JumpPlatform, is_overload: bool, contact_center_x: float) -> void:
	last_landing_quality = JumpConfig.LandingQuality.NORMAL
	var bonus := 0
	if platform != null:
		last_landing_quality = JumpConfig.classify_landing(contact_center_x - platform.global_position.x, platform.platform_size.x * absf(platform.global_scale.x))
		platform.trigger_impact(last_landing_quality, contact_center_x)
		bonus = platform.claim_landing_bonus(last_landing_quality)
	landing_count += 1
	_impact_remaining = JumpConfig.LANDING_EFFECT_DURATIONS[last_landing_quality]
	if _feedback_visual != null:
		_feedback_visual.queue_redraw()
	_apply_bounce(is_overload)
	landed.emit(platform, last_landing_quality, bonus)

## The first launch has no preceding landing. Normal landing bounces retain
## their existing land -> jump sequence and physics.
func start_initial_bounce() -> void:
	velocity.y = -JumpConfig.BASE_BOUNCE_SPEED
	_bounce_sequence = [&"jump"]
	_play_next_bounce_animation()
	bounced.emit()

func _apply_bounce(is_overload: bool) -> void:
	var bounce_speed := JumpConfig.OVERLOAD_BOUNCE_SPEED if is_overload else JumpConfig.BASE_BOUNCE_SPEED
	velocity.y = -minf(bounce_speed * JumpConfig.LANDING_BOUNCE_MULTIPLIERS[last_landing_quality], JumpConfig.MAX_BOUNCE_SPEED)
	_bounce_sequence = [&"land", &"jump"]
	_play_next_bounce_animation()
	bounced.emit()

# One reused, local CanvasItem over the existing core. No whole-body flash,
# transforms, particles, shaders or per-contact allocations.
func shutdown() -> void:
	set_physics_process(false)
	set_process(false)
	clear_horizontal_target()
	_impact_remaining = 0.0
	if _feedback_visual != null:
		_feedback_visual.queue_redraw()
	if _reactor_visual != null:
		_reactor_visual.pause()

func _draw_contact_light() -> void:
	if _impact_remaining <= 0.0:
		return
	var duration: float = JumpConfig.LANDING_EFFECT_DURATIONS[last_landing_quality]
	var fade := _impact_remaining / duration
	var strength: float = JumpConfig.LANDING_EFFECT_STRENGTHS[last_landing_quality] * fade
	var light := JumpConfig.LANDING_CORE_LIGHT_COLOR
	light.a = strength * JumpConfig.LANDING_CORE_LIGHT_GAIN
	_feedback_visual.draw_circle(JumpConfig.REACTOR_CORE_POSITION, JumpConfig.LANDING_CORE_LIGHT_RADIUS, light)
	if last_landing_quality != JumpConfig.LandingQuality.NORMAL:
		var ring := JumpConfig.LANDING_GLOW_COLOR
		ring.a = strength
		var radius: float = JumpConfig.LANDING_RING_RADII[last_landing_quality] + (1.0 - fade) * JumpConfig.LANDING_RING_EXPANSION
		_feedback_visual.draw_set_transform(Vector2(0.0, JumpConfig.JUMPER_SIZE.y * 0.5), 0.0, Vector2(1.0, JumpConfig.LANDING_RING_FLATTEN))
		_feedback_visual.draw_arc(Vector2.ZERO, radius, 0.0, TAU, JumpConfig.LANDING_RING_SEGMENTS, ring, JumpConfig.LANDING_RING_WIDTH)
		_feedback_visual.draw_set_transform(Vector2.ZERO)
