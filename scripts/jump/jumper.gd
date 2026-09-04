class_name Jumper
extends CharacterBody2D

signal bounced

var horizontal_intent := 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = JumpConfig.JUMPER_SIZE
	collision.shape = shape
	add_child(collision)
	queue_redraw()

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
	horizontal_intent = clampf(intent, -1.0, 1.0)

func apply_horizontal_steering(delta: float) -> void:
	var target_speed := horizontal_intent * JumpConfig.MAX_HORIZONTAL_SPEED
	var rate := JumpConfig.HORIZONTAL_ACCELERATION if horizontal_intent != 0.0 else JumpConfig.HORIZONTAL_DRAG
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

func _draw() -> void:
	draw_circle(Vector2.ZERO, JumpConfig.JUMPER_SIZE.x * 0.7, Color(1.0, 0.32, 0.08, 0.18))
	draw_circle(Vector2.ZERO, JumpConfig.JUMPER_SIZE.x * 0.45, Color(1.0, 0.34, 0.08))
	draw_circle(Vector2.ZERO, JumpConfig.JUMPER_SIZE.x * 0.22, Color(1.0, 0.82, 0.36))
