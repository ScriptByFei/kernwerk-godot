extends Node2D

const START_Y := JumpConfig.PLATFORM_LAYOUT[0].y - JumpConfig.PLATFORM_SIZE.y

var jumper: Jumper
var camera: VerticalCamera
var platform_director: PlatformDirector
var start_menu: CanvasLayer
var is_dragging := false
var score := 0
var difficulty := 0
var is_game_over := false
var is_started := false
var _restart_timer := -1.0
var _highest_y := START_Y
var _death_check_armed := false

func _ready() -> void:
	platform_director = PlatformDirector.new()
	platform_director.initialize(self, JumpConfig.PLATFORM_LAYOUT)
	_create_jumper()
	_create_camera()
	_highest_y = jumper.global_position.y
	_update_score()
	# Hold the jumper on the start platform until the player taps to begin.
	jumper.set_physics_process(false)
	camera.set_physics_process(false)
	_create_start_menu()
	queue_redraw()

func _create_start_menu() -> void:
	start_menu = CanvasLayer.new()
	start_menu.name = "StartMenuLayer"
	start_menu.layer = 10
	add_child(start_menu)
	var menu := StartMenu.new()
	menu.name = "StartMenu"
	start_menu.add_child(menu)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		queue_redraw()

func _process(delta: float) -> void:
	queue_redraw()
	if not is_started:
		return
	if jumper == null or camera == null:
		return
	if is_game_over:
		_restart_timer -= delta
		if _restart_timer <= 0.0:
			_restart()
		return
	_update_score()
	if _death_check_armed:
		_check_game_over()
	else:
		_arm_death_check()
	if is_game_over:
		return
	var visible_rect := _get_visible_world_rect()
	platform_director.maintain(visible_rect.position.y, visible_rect.end.y, difficulty)

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
	# Start the camera on the jumper so the death line sits below the play area,
	# not above it. The camera only follows upward, so a static CAMERA_START
	# leaves the jumper permanently below the death line (instant game over).
	camera.position = Vector2(jumper.global_position.x, jumper.global_position.y + JumpConfig.CAMERA_LEAD)

func _update_score() -> void:
	if jumper == null:
		return
	_highest_y = minf(_highest_y, jumper.global_position.y)
	score = maxi(0, int(floor((START_Y - _highest_y) / JumpConfig.SCORE_PER_UNIT)))
	difficulty = mini(
		JumpConfig.MAX_DIFFICULTY,
		int(floor(float(score) / JumpConfig.DIFFICULTY_STEP_SCORE))
	)

func _check_game_over() -> void:
	if is_game_over or jumper == null or camera == null:
		return
	var death_line_y := camera.global_position.y + JumpConfig.FALL_DEATH_MARGIN
	if jumper.global_position.y > death_line_y:
		is_game_over = true
		_restart_timer = JumpConfig.RESTART_DELAY

func _arm_death_check() -> void:
	if jumper == null or camera == null:
		return
	if jumper.global_position.y <= camera.global_position.y + JumpConfig.FALL_DEATH_MARGIN:
		_death_check_armed = true

func _restart() -> void:
	if jumper != null:
		jumper.free()
		jumper = null
	if camera != null:
		camera.free()
		camera = null
	if platform_director == null:
		platform_director = PlatformDirector.new()
	platform_director.initialize(self, JumpConfig.PLATFORM_LAYOUT)
	_create_jumper()
	_create_camera()
	score = 0
	difficulty = 0
	is_game_over = false
	_restart_timer = -1.0
	_highest_y = jumper.global_position.y
	_death_check_armed = false
	_update_score()
	queue_redraw()

func _start_game() -> void:
	if is_started:
		return
	is_started = true
	jumper.set_physics_process(true)
	camera.set_physics_process(true)
	# Give the jumper an initial upward bounce so it leaves the start platform.
	jumper.velocity.y = -JumpConfig.BASE_BOUNCE_SPEED
	# Hide the start menu overlay.
	if start_menu != null:
		start_menu.visible = false
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not is_started:
		if _is_start_tap(event):
			_start_game()
		return
	if jumper == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_dragging = event.pressed
		if is_dragging:
			_set_horizontal_target(event.position)
		else:
			jumper.clear_horizontal_target()
	elif event is InputEventMouseMotion and is_dragging:
		_set_horizontal_target(event.position)
	elif event is InputEventScreenTouch:
		is_dragging = event.pressed
		if is_dragging:
			_set_horizontal_target(event.position)
		else:
			jumper.clear_horizontal_target()
	elif event is InputEventScreenDrag and is_dragging:
		_set_horizontal_target(event.position)
	elif event is InputEventKey:
		_set_keyboard_intent()

func _is_start_tap(event: InputEvent) -> bool:
	return (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)

func _set_horizontal_target(pointer_position: Vector2) -> void:
	var canvas_to_world := get_viewport().get_canvas_transform().affine_inverse()
	jumper.set_horizontal_target((canvas_to_world * pointer_position).x)

func _set_keyboard_intent() -> void:
	jumper.set_horizontal_intent(Input.get_axis("move_left", "move_right"))

func _draw() -> void:
	var visible_rect := _get_visible_world_rect()
	draw_rect(visible_rect, Color(0.025, 0.035, 0.055), true)
	for shaft_x in [120.0, 540.0, 960.0]:
		draw_line(Vector2(shaft_x, visible_rect.position.y), Vector2(shaft_x, visible_rect.end.y), Color(0.08, 0.13, 0.16), 8.0)
	draw_string(
		ThemeDB.fallback_font,
		visible_rect.position + Vector2(44.0, 72.0),
		"SCORE %06d" % score,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		42,
		Color(0.72, 1.0, 0.92)
	)
	if is_game_over:
		draw_string(
			ThemeDB.fallback_font,
			visible_rect.position + Vector2(44.0, 126.0),
			"RESTARTING...",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			30,
			Color(0.72, 0.82, 0.86)
		)

func _get_visible_world_rect() -> Rect2:
	var viewport_rect := get_viewport_rect()
	var canvas_to_world := get_viewport().get_canvas_transform().affine_inverse()
	var top_left := canvas_to_world * viewport_rect.position
	var bottom_right := canvas_to_world * viewport_rect.end
	return Rect2(top_left, bottom_right - top_left)
