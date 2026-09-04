extends Node2D

var jumper: Jumper
var camera: VerticalCamera
var drag_origin := Vector2.ZERO
var is_dragging := false

func _ready() -> void:
	queue_redraw()
	_create_platforms()
	_create_jumper()
	_create_camera()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _create_platforms() -> void:
	for platform_position in JumpConfig.PLATFORM_LAYOUT:
		var platform := JumpPlatform.new()
		platform.position = platform_position
		platform.add_to_group("platforms")
		add_child(platform)

func _create_jumper() -> void:
	jumper = Jumper.new()
	jumper.name = "Jumper"
	jumper.position = JumpConfig.PLATFORM_LAYOUT[0] - Vector2(0.0, JumpConfig.PLATFORM_SIZE.y)
	jumper.velocity.y = -JumpConfig.BASE_BOUNCE_SPEED
	add_child(jumper)

func _create_camera() -> void:
	camera = VerticalCamera.new()
	camera.name = "VerticalCamera"
	camera.target = jumper
	add_child(camera)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_dragging = event.pressed
		drag_origin = event.position
		if not is_dragging:
			jumper.set_horizontal_intent(0.0)
	elif event is InputEventMouseMotion and is_dragging:
		_set_drag_intent(event.position)
	elif event is InputEventScreenTouch:
		is_dragging = event.pressed
		drag_origin = event.position
		if not is_dragging:
			jumper.set_horizontal_intent(0.0)
	elif event is InputEventScreenDrag and is_dragging:
		_set_drag_intent(event.position)
	elif event is InputEventKey:
		_set_keyboard_intent()

func _set_drag_intent(pointer_position: Vector2) -> void:
	jumper.set_horizontal_intent((pointer_position.x - drag_origin.x) / JumpConfig.DRAG_DISTANCE)

func _set_keyboard_intent() -> void:
	jumper.set_horizontal_intent(Input.get_axis("move_left", "move_right"))

func _draw() -> void:
	var viewport_rect := get_viewport_rect()
	var canvas_to_world := get_viewport().get_canvas_transform().affine_inverse()
	var top_left := canvas_to_world * viewport_rect.position
	var bottom_right := canvas_to_world * viewport_rect.end
	var visible_rect := Rect2(top_left, bottom_right - top_left)
	draw_rect(visible_rect, Color(0.025, 0.035, 0.055), true)
	for shaft_x in [120.0, 540.0, 960.0]:
		draw_line(Vector2(shaft_x, visible_rect.position.y), Vector2(shaft_x, visible_rect.end.y), Color(0.08, 0.13, 0.16), 8.0)
