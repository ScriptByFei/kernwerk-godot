class_name VerticalCamera
extends Camera2D

var target: Node2D
var _ascent_headroom := 0.0

func _ready() -> void:
	position = JumpConfig.CAMERA_START

func _physics_process(delta: float) -> void:
	if target == null:
		return
	var desired_headroom := 0.0
	if target is CharacterBody2D:
		var upward_speed := -(target as CharacterBody2D).velocity.y
		desired_headroom = JumpConfig.CAMERA_ASCENT_HEADROOM * clampf((upward_speed - JumpConfig.CAMERA_APEX_SPEED) / (JumpConfig.BASE_BOUNCE_SPEED - JumpConfig.CAMERA_APEX_SPEED), 0.0, 1.0)
	_ascent_headroom = lerpf(_ascent_headroom, desired_headroom, 1.0 - exp(-JumpConfig.CAMERA_HEADROOM_RESPONSE * delta))
	var next_y := target.global_position.y + JumpConfig.CAMERA_LEAD - _ascent_headroom
	# Baseline upward-only ratchet also holds through apex and descending input.
	global_position.y = minf(global_position.y, next_y)
