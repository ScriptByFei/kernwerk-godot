class_name JumpPlatform
extends StaticBody2D

var platform_size := JumpConfig.PLATFORM_SIZE

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = platform_size
	collision.shape = shape
	add_child(collision)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(-platform_size * 0.5, platform_size)
	draw_rect(rect.grow(7.0), Color(0.04, 0.18, 0.22, 0.65), true)
	draw_rect(rect, Color(0.16, 0.52, 0.58), true)
	draw_line(Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y), Color(0.72, 1.0, 0.92), 4.0)
