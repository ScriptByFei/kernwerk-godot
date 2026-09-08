extends Node2D

const START_Y := JumpConfig.PLATFORM_LAYOUT[0].y - JumpConfig.PLATFORM_SIZE.y

## Start transition state. STARTING gates all gameplay: no steering input, no
## second tap, no death checks, no camera follow until PLAYING.
enum Phase {
	START_MENU,
	STARTING,
	PLAYING,
}

var jumper: Jumper
var camera: VerticalCamera
var platform_director: PlatformDirector
var start_menu: CanvasLayer
var is_dragging := false
var score := 0
var difficulty := 0
var is_game_over := false
var _phase := Phase.START_MENU
var _restart_timer := -1.0
var _highest_y := START_Y
var _death_check_armed := false
var _start_tween: Tween
var _initial_bounce_fired := false
var _current_menu: StartMenu
var _held_pointers: Dictionary = {}
var _blocked_pointers: Dictionary = {}
var _keyboard_blocked := false

func _ready() -> void:
	platform_director = PlatformDirector.new()
	platform_director.initialize(self, JumpConfig.PLATFORM_LAYOUT)
	_create_jumper()
	_create_camera()
	_highest_y = jumper.global_position.y
	_update_score()
	# Hold the jumper and camera frozen until the player taps.
	jumper.set_physics_process(false)
	camera.set_physics_process(false)
	_create_start_menu()
	queue_redraw()

func _create_start_menu() -> void:
	_reset_controls()
	_initial_bounce_fired = false
	# Establish the intro before the first rendered menu frame, never at tap.
	camera.offset.y = JumpConfig.START_CAMERA_INTRO_OFFSET
	jumper.modulate = Color(0.72, 0.76, 0.80)
	start_menu = CanvasLayer.new()
	start_menu.name = "StartMenuLayer"
	start_menu.layer = 10
	add_child(start_menu)
	var menu := StartMenu.new()
	menu.name = "StartMenu"
	start_menu.add_child(menu)
	_current_menu = menu
	# If the overlay is removed externally, abort safely back to the menu. The
	# callback is bound to this specific instance so a superseded menu that is
	# still exiting cannot cancel a replacement start (P3).
	menu.tree_exiting.connect(_on_start_menu_exiting.bind(menu))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		queue_redraw()

func _process(delta: float) -> void:
	queue_redraw()
	if _phase == Phase.START_MENU:
		# The menu is live (its own idle tweens draw it); gameplay is frozen.
		return
	if jumper == null or camera == null:
		return
	if is_game_over:
		_restart_timer -= delta
		if _restart_timer <= 0.0:
			_restart()
		return
	# Full gameplay logic only after the start choreography finished.
	if _phase == Phase.PLAYING:
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
	_cancel_start_sequence()
	_phase = Phase.START_MENU
	if jumper != null:
		jumper.free()
		jumper = null
	if camera != null:
		camera.free()
		camera = null
	if is_instance_valid(start_menu):
		start_menu.queue_free()
		start_menu = null
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
	_phase = Phase.START_MENU
	jumper.set_physics_process(false)
	camera.set_physics_process(false)
	_create_start_menu()
	_update_score()
	queue_redraw()

## Entry point of the choreographed start. Guarded so a second tap cannot
## retrigger it (Phase 1: input lock immediately).
func _start_game() -> void:
	if _phase != Phase.START_MENU:
		return
	_reset_controls()
	_phase = Phase.STARTING
	_begin_start_sequence()

func _begin_start_sequence() -> void:
	var menu: StartMenu = _current_menu
	if menu == null or not is_instance_valid(menu):
		return
	menu.start_press_feedback()
	# Every delay is measured from tap, not from the previous tweener's end.
	_start_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_start_tween.tween_property(menu.bg, "self_modulate", Color(0.88, 0.88, 0.84), JumpConfig.START_REVEAL_BEGIN)
	_start_tween.tween_property(jumper, "modulate", Color.WHITE, JumpConfig.START_REVEAL_BEGIN)
	_start_tween.tween_property(camera, "offset:y", 0.0, JumpConfig.START_CAMERA_DURATION).set_delay(JumpConfig.START_REVEAL_BEGIN)
	_tween_menu_away(_start_tween, menu)
	_start_tween.tween_callback(_finish_start_sequence).set_delay(JumpConfig.START_BOUNCE_AT)

func _tween_menu_away(tween: Tween, menu: StartMenu) -> void:
	for node: CanvasItem in [menu.subtitle_label, menu.cta_panel]:
		tween.tween_property(node, "modulate:a", 0.0, JumpConfig.START_SECONDARY_DURATION).set_delay(JumpConfig.START_SECONDARY_BEGIN)
	tween.tween_property(menu, "secondary_drift", -24.0, JumpConfig.START_SECONDARY_DURATION).set_delay(JumpConfig.START_SECONDARY_BEGIN)
	tween.tween_property(menu.title_label, "modulate:a", 0.0, JumpConfig.START_TITLE_DURATION).set_delay(JumpConfig.START_REVEAL_BEGIN)
	tween.tween_property(menu, "title_drift", -36.0, JumpConfig.START_TITLE_DURATION).set_delay(JumpConfig.START_REVEAL_BEGIN)
	tween.tween_property(menu.bg, "modulate:a", 0.0, JumpConfig.START_CAMERA_DURATION).set_delay(JumpConfig.START_REVEAL_BEGIN)

func _finish_start_sequence() -> void:
	if _phase != Phase.STARTING:
		return
	_fire_initial_bounce()
	_enter_playing()

func _fire_initial_bounce() -> void:
	if _phase == Phase.STARTING and not _initial_bounce_fired and is_instance_valid(jumper):
		_initial_bounce_fired = true
		jumper.start_initial_bounce()

func _enter_playing() -> void:
	if _phase != Phase.STARTING or not _initial_bounce_fired:
		return
	_reset_controls()
	jumper.set_physics_process(true)
	camera.set_physics_process(true)
	_phase = Phase.PLAYING
	if is_instance_valid(start_menu):
		start_menu.queue_free()
		start_menu = null

func _cancel_start_sequence() -> void:
	if _start_tween != null and _start_tween.is_valid():
		_start_tween.kill()
	_start_tween = null

func _exit_tree() -> void:
	_cancel_start_sequence()

func _on_start_menu_exiting(menu: StartMenu) -> void:
	# Ignore a superseded menu that is still exiting after a restart replaced
	# it: only the current menu's exit may abort the running sequence (P3).
	if menu != _current_menu:
		return
	if _phase == Phase.STARTING and is_inside_tree() and not is_queued_for_deletion():
		_cancel_start_sequence()
		_phase = Phase.START_MENU
		_restart.call_deferred()

func _reset_controls() -> void:
	is_dragging = false
	_blocked_pointers = _held_pointers.duplicate()
	_keyboard_blocked = Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")
	if is_instance_valid(jumper):
		jumper.clear_horizontal_target()
		jumper.horizontal_target_x = jumper.position.x
		jumper.velocity.x = 0.0

func _input(event: InputEvent) -> void:
	# Track releases even if a future GUI consumes them. Pointer IDs keep a
	# start finger (and emulated mouse) blocked until it is actually lifted.
	var pointer := ""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = "mouse"
	elif event is InputEventScreenTouch:
		pointer = "touch:%d" % event.index
	if not pointer.is_empty():
		if event.pressed:
			_held_pointers[pointer] = true
			if _phase != Phase.PLAYING:
				_blocked_pointers[pointer] = true
		else:
			_held_pointers.erase(pointer)
			_blocked_pointers.erase(pointer)
	if event is InputEventKey and _keyboard_blocked:
		_keyboard_blocked = Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")

func _unhandled_input(event: InputEvent) -> void:
	if _phase == Phase.START_MENU:
		if _is_start_tap(event):
			_start_game()
		return
	if _phase == Phase.STARTING:
		# No steering, no second start tap during the hand-off.
		return
	if jumper == null:
		return
	# Gate only the pointer that actually started the game (and its emulated
	# counterpart), so a fresh second finger or a fresh mouse gesture can still
	# steer while the initiating touch is held (P2). A held start touch's
	# emulated mouse motion stays inert because is_dragging is never set for it.
	var pointer_key := _pointer_key(event)
	if not pointer_key.is_empty() and _blocked_pointers.has(pointer_key):
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
		if not _keyboard_blocked:
			_set_keyboard_intent()

func _is_start_tap(event: InputEvent) -> bool:
	return (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)

## Pointer key matching the one recorded in _input, so a blocked start pointer
## (and its emulated mouse counterpart) can be gated without suppressing fresh
## pointers. Empty for keyboard events.
func _pointer_key(event: InputEvent) -> String:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return "mouse"
	if event is InputEventMouseMotion:
		return "mouse"
	if event is InputEventScreenTouch:
		return "touch:%d" % event.index
	if event is InputEventScreenDrag:
		return "touch:%d" % event.index
	return ""

func _set_horizontal_target(pointer_position: Vector2) -> void:
	var canvas_to_world := get_viewport().get_canvas_transform().affine_inverse()
	jumper.set_horizontal_target((canvas_to_world * pointer_position).x)

func _set_keyboard_intent() -> void:
	jumper.set_horizontal_intent(Input.get_axis("move_left", "move_right"))

func _draw() -> void:
	var visible_rect := _get_visible_world_rect()
	# Keep a quiet reactor floor behind the start overlay so the transition never
	# cuts to black: the world (platforms, shafts, the reactor) is already there.
	draw_rect(visible_rect, Color(0.025, 0.035, 0.055), true)
	for shaft_x in [120.0, 540.0, 960.0]:
		draw_line(Vector2(shaft_x, visible_rect.position.y), Vector2(shaft_x, visible_rect.end.y), Color(0.08, 0.13, 0.16), 8.0)
	if _phase == Phase.PLAYING:
		# Only show HUD once the world is actually in play; during STARTING the
		# reveal is still finishing.
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
