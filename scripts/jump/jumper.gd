class_name Jumper
extends CharacterBody2D

const REACTOR_IDLE_FRAMES := preload("res://assets/jump/reactor_core/reactor_idle_frames.tres")

signal bounced

var horizontal_intent := 0.0
var horizontal_target_x := 0.0
var has_horizontal_target := false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = JumpConfig.JUMPER_SIZE
	collision.shape = shape
	add_child(collision)
	_create_reactor_visual()

func _create_reactor_visual() -> void:
	var reactor_visual := AnimatedSprite2D.new()
	reactor_visual.name = "ReactorVisual"
	reactor_visual.sprite_frames = REACTOR_IDLE_FRAMES
	reactor_visual.animation = &"idle"
	reactor_visual.autoplay = &"idle"
	reactor_visual.centered = false
	reactor_visual.position = Vector2(-72.0, -109.0)
	reactor_visual.scale = Vector2(1.5, 1.5)
	reactor_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(reactor_visual)
	reactor_visual.play()

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	apply_horizontal_steering(delta)
	var was_descending := velocity.y > 0.0
	move_and_slide()
	if was_descending and is_on_floor():
		_apply_bounce(false)

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
		target_speed = clampf(
			(horizontal_target_x - global_position.x) / JumpConfig.HORIZONTAL_TARGET_DISTANCE * JumpConfig.MAX_HORIZONTAL_SPEED,
			-JumpConfig.MAX_HORIZONTAL_SPEED,
			JumpConfig.MAX_HORIZONTAL_SPEED
		)
	var rate := JumpConfig.HORIZONTAL_ACCELERATION if not is_zero_approx(target_speed) else JumpConfig.HORIZONTAL_DRAG
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	velocity.x = clampf(velocity.x, -JumpConfig.MAX_HORIZONTAL_SPEED, JumpConfig.MAX_HORIZONTAL_SPEED)

func bounce_from(_platform: JumpPlatform, is_overload: bool) -> bool:
	if velocity.y <= 0.0:
		return false
	_apply_bounce(is_overload)
	return true

func _apply_bounce(is_overload: bool) -> void:
	var bounce_speed := JumpConfig.OVERLOAD_BOUNCE_SPEED if is_overload else JumpConfig.BASE_BOUNCE_SPEED
	velocity.y = -minf(bounce_speed, JumpConfig.MAX_BOUNCE_SPEED)
	bounced.emit()
