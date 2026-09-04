class_name VerticalCamera
extends Camera2D

var target: Node2D

func _ready() -> void:
	position = JumpConfig.CAMERA_START

func _physics_process(_delta: float) -> void:
	if target == null:
		return
	var next_y := target.global_position.y + JumpConfig.CAMERA_LEAD
	if next_y < global_position.y:
		global_position.y = next_y
