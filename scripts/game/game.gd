extends Node2D

const START_Y := JumpConfig.PLATFORM_LAYOUT[0].y - JumpConfig.PLATFORM_SIZE.y

## Start transition state. STARTING gates all gameplay: no steering input, no
## second tap, no death checks, no camera follow until PLAYING.
enum Phase {
	START_MENU,
	STARTING,
	PLAYING,
}

## Optional authored sounds only. Empty slots are deliberately silent.
@export var normal_landing_sound: AudioStream
@export var resonance_landing_sound: AudioStream
@export var perfect_landing_sound: AudioStream
@export var death_sound: AudioStream

var _contact_audio: AudioStreamPlayer
var _audio_unlocked := false
var _death_tween: Tween
var _landing_bonus := 0
## Restlaufzeit der OVERLOAD-Anzeige. Das Spiel springt automatisch ab, deshalb
## ist 3/3 nur einen Tick lang wahr; der ueberladene Flug haelt die Anzeige.
var _overload_display := 0.0
var resonance: ResonanceSystem
var hud: ResonanceHud
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
var _drag_pointer := ""
var _keyboard_blocked := false
var pause_button: PauseButton
var pause_menu: PauseMenu
var _pause_layer: CanvasLayer
var _pause_tween: Tween
var _is_paused := false

func _ready() -> void:
	_contact_audio = AudioStreamPlayer.new()
	_contact_audio.name = "ContactAudio"
	add_child(_contact_audio)
	resonance = ResonanceSystem.new()
	platform_director = PlatformDirector.new()
	platform_director.initialize(self, JumpConfig.PLATFORM_LAYOUT)
	_create_hud()
	_create_pause_ui()
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
	jumper.modulate = Color(0.92, 0.94, 0.96)
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
			_restart(true)
		return
	# Full gameplay logic only after the start choreography finished.
	if _phase == Phase.PLAYING:
		_update_score()
		_overload_display = maxf(0.0, _overload_display - delta)
		if _death_check_armed:
			_check_game_over()
		else:
			_arm_death_check()
		if is_game_over:
			return
		var visible_rect := _get_visible_world_rect()
		platform_director.maintain(visible_rect.position.y, visible_rect.end.y, difficulty)

func _create_hud() -> void:
	# Overlay in eigenem Layer: bleibt lesbar, egal welche Plattformen im
	# Weltraum vorbeiziehen.
	hud = ResonanceHud.new()
	hud.name = "ResonanceHud"
	hud.resonance = resonance
	var layer := CanvasLayer.new()
	layer.name = "HudLayer"
	layer.layer = 5
	add_child(layer)
	layer.add_child(hud)

func _create_pause_ui() -> void:
	# Pausenknopf und Pausenschirm liegen im selben Layer: der Knopf ist das
	# einzige, was der Spieler waehrend des Spiels sieht.
	var layer := CanvasLayer.new()
	layer.name = "PauseLayer"
	layer.layer = JumpConfig.PAUSE_LAYER
	add_child(layer)
	_pause_layer = layer
	pause_button = PauseButton.new()
	pause_button.name = "PauseButton"
	pause_button.visible = false
	layer.add_child(pause_button)

## Haelt das Spiel an. Der SceneTree stoppt Physik und _process; die Pause selbst
## bleibt bedienbar, weil ihre Knoten auf PROCESS_MODE_ALWAYS stehen.
func pause() -> void:
	if _is_paused or _phase != Phase.PLAYING or is_game_over:
		return
	_is_paused = true
	_reset_controls()
	# Waehrend der Pause steht der Baum, das Spiel sieht also keine Eingabe. Ein
	# Finger, der beim Pausieren noch lag, wuerde danach nie wieder ein Loslassen
	# melden und diesen Zeiger dauerhaft sperren. Die Pause beginnt deshalb mit
	# leerem Zeigerstand; das Startmenue ist hier laengst vorbei.
	_held_pointers.clear()
	_blocked_pointers.clear()
	_cancel_pause_tween()
	if pause_menu == null or not is_instance_valid(pause_menu):
		pause_menu = PauseMenu.new()
		pause_menu.name = "PauseMenu"
		# Ein pausierter Knoten bekommt keine Eingabe. Ohne ALWAYS waere das
		# Menue sichtbar, aber tot — kein Tap wuerde je ankommen.
		pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
		pause_menu.resume_requested.connect(_on_resume_requested)
		pause_menu.restart_requested.connect(_on_restart_requested)
		_pause_layer.add_child(pause_menu)
	pause_menu.score = score
	pause_menu.set_process_unhandled_input(true)
	# Ueber dem Pausenknopf einsortiert, damit er den Schirm nicht durchstoesst.
	_pause_layer.move_child(pause_menu, _pause_layer.get_child_count() - 1)
	pause_menu.modulate.a = 0.0
	pause_menu.visible = true
	# Erst jetzt anhalten: der Menuebaum existiert vorher, damit der Wechsel nie
	# ein Bild ohne Ueberlagerung zeigt.
	get_tree().paused = true
	_pause_tween = create_tween().set_pause_mode(JumpConfig.PAUSE_TWEEN_PROCESS_MODE)
	_pause_tween.tween_property(pause_menu, "modulate:a", 1.0, JumpConfig.PAUSE_IN_DURATION)
	pause_button.visible = false

func _on_resume_requested() -> void:
	if not _is_paused:
		return
	_resume()

func _on_restart_requested() -> void:
	if not _is_paused:
		return
	# Aus der Pause heraus denselben Neustartpfad nutzen wie nach dem Tod. Der
	# schnelle Wiedereinstieg ist hier richtig: der Spieler kennt das Spiel.
	get_tree().paused = false
	_is_paused = false
	_restart(true)

## Nimmt die Pause zurueck. Der SceneTree laeuft erst wieder, wenn das Menue
## ausgeblendet ist — sonst waere die Physik schneller als die Anzeige.
func _resume() -> void:
	_is_paused = false
	_cancel_pause_tween()
	if pause_menu != null and is_instance_valid(pause_menu):
		pause_menu.set_process_unhandled_input(false)
		_pause_tween = create_tween().set_pause_mode(JumpConfig.PAUSE_TWEEN_PROCESS_MODE)
		_pause_tween.tween_property(pause_menu, "modulate:a", 0.0, JumpConfig.PAUSE_OUT_DURATION)
		_pause_tween.tween_callback(_finish_resume)
	else:
		_finish_resume()

func _finish_resume() -> void:
	if pause_menu != null and is_instance_valid(pause_menu):
		pause_menu.visible = false
	get_tree().paused = false
	pause_button.visible = pause_button_available()

func _cancel_pause_tween() -> void:
	if _pause_tween != null and _pause_tween.is_valid():
		_pause_tween.kill()
	_pause_tween = null

## Der Pausenknopf faengt keinen Eingabe ab (mouse_filter IGNORE), die Flaeche
## wertet das Spiel aus. Damit laeuft die Pause durch denselben Eingabepfad wie
## die Steuerung und ein Finger kann nie gleichzeitig steuern und pausieren.
func pause_button_available() -> bool:
	if pause_button == null or not is_instance_valid(pause_button):
		return false
	return _phase == Phase.PLAYING and not is_game_over and not _is_paused

func _update_pause_button() -> void:
	if pause_button == null or not is_instance_valid(pause_button):
		return
	pause_button.visible = pause_button_available()

## Trefferflaeche des Knopfes: die gezeichnete Flaeche plus Daumen-Zuschlag.
func _pause_button_hit_rect() -> Rect2:
	if pause_button == null or not is_instance_valid(pause_button):
		return Rect2()
	return PauseButton.rect_for(pause_button.size).grow(JumpConfig.PAUSE_BUTTON_HIT_PADDING)

## Liefert true, wenn der Tap den Pausenknopf getroffen hat.
func _try_pause_tap(position: Vector2) -> bool:
	if _phase != Phase.PLAYING or is_game_over or _is_paused:
		return false
	if not _pause_button_hit_rect().has_point(position):
		return false
	pause()
	return true

func _create_jumper() -> void:
	jumper = Jumper.new()
	jumper.name = "Jumper"
	jumper.position = JumpConfig.PLATFORM_LAYOUT[0] - Vector2(0.0, JumpConfig.PLATFORM_SIZE.y)
	jumper.velocity.y = -JumpConfig.BASE_BOUNCE_SPEED
	# Das ResonanceSystem entscheidet direkt beim Absprung ueber Overload, damit
	# die Kraft im selben Physik-Tick wirkt wie die ausloesende Landung.
	jumper.overload_check = _on_overload_check
	add_child(jumper)
	jumper.landed.connect(_on_landed)

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
	var height_score := maxi(0, int(floor((START_Y - _highest_y) / JumpConfig.SCORE_PER_UNIT)))
	score = height_score + _landing_bonus
	difficulty = mini(
		JumpConfig.MAX_DIFFICULTY,
		int(floor(float(height_score) / JumpConfig.DIFFICULTY_STEP_SCORE))
	)

## Einziger Verbuchungspfad fuer eine Landung. Wird sowohl vom Absprung-Callback
## des Jumpers als auch direkt (Tests, Sonderfaelle) aufgerufen. Liefert zurueck,
## ob diese Landung einen Overload ausgeloest hat.
func _register_resonance(quality: JumpConfig.LandingQuality) -> bool:
	var overload := resonance.register_landing(quality)
	# Punkte fuer die Ladung, die DIESE Landung erreicht hat. Bei Overload steht
	# der Stand schon wieder auf 0, deshalb der gemerkte Wert.
	_landing_bonus += ResonanceSystem.score_for_charge(resonance.last_charge)
	if jumper != null:
		# Beim Overload traegt die Kraft allein die Belohnung: der Ladungsbonus
		# wuerde sonst mit OVERLOAD_BOUNCE_SPEED doppelt zahlen.
		jumper.set_resonance_ratio(0.0 if overload else resonance.charge_ratio())
	if overload:
		_overload_display = JumpConfig.RESONANCE_OVERLOAD_DISPLAY_TIME
		_play_overload_sound()
	_update_score()
	return overload

## Callback des Jumpers: wird unmittelbar vor jedem Absprung aufgerufen. Erst
## hier wird die Landung verbucht, damit die Overload-Kraft noch in diesem Tick
## greift und die Ringintensitaet vor dem Zeichnen feststeht.
func _on_overload_check(quality: JumpConfig.LandingQuality) -> bool:
	if _phase != Phase.PLAYING or is_game_over:
		return false
	return _register_resonance(quality)

func _play_overload_sound() -> void:
	if resonance_landing_sound != null:
		_play_contact_sound(resonance_landing_sound, JumpConfig.LANDING_AUDIO_DB[JumpConfig.LandingQuality.RESONANCE])

func _on_landed(_platform: JumpPlatform, quality: JumpConfig.LandingQuality, bonus: int) -> void:
	if _phase != Phase.PLAYING or is_game_over:
		return
	# Die Resonanz wurde bereits im Absprung-Callback verbucht (gleicher Tick,
	# damit Overload wirkt). Hier folgen nur Punkte und Klang.
	_landing_bonus += bonus
	_update_score()
	var streams := [normal_landing_sound, resonance_landing_sound, perfect_landing_sound]
	_play_contact_sound(streams[quality], JumpConfig.LANDING_AUDIO_DB[quality])

func _play_contact_sound(stream: AudioStream, volume_db: float) -> void:
	if not _audio_unlocked or stream == null:
		return
	_contact_audio.stream = stream
	_contact_audio.volume_db = volume_db
	_contact_audio.play()

func _check_game_over() -> void:
	if is_game_over or jumper == null or camera == null:
		return
	var death_line_y := camera.global_position.y + JumpConfig.FALL_DEATH_MARGIN
	if jumper.global_position.y > death_line_y:
		is_game_over = true
		_restart_timer = JumpConfig.RESTART_DELAY
		_reset_controls()
		if pause_button != null and is_instance_valid(pause_button):
			pause_button.visible = false
		jumper.shutdown()
		camera.set_physics_process(false)
		_death_tween = create_tween()
		_death_tween.tween_property(jumper, "modulate", JumpConfig.DEATH_DIM_COLOR, JumpConfig.DEATH_DIM_DURATION)
		_play_contact_sound(death_sound, JumpConfig.DEATH_AUDIO_DB)

func _arm_death_check() -> void:
	if jumper == null or camera == null:
		return
	if jumper.global_position.y <= camera.global_position.y + JumpConfig.FALL_DEATH_MARGIN:
		_death_check_armed = true

func _restart(fast_retry := false) -> void:
	_cancel_start_sequence()
	_cancel_pause_tween()
	# Ein Neustart darf nie in einer angehaltenen Welt landen. Aus der Pause
	# heraus wird der Baum hier zuerst wieder freigegeben, sonst friert die
	# frisch angelegte Szene sofort ein.
	get_tree().paused = false
	_is_paused = false
	if pause_menu != null and is_instance_valid(pause_menu):
		pause_menu.queue_free()
		pause_menu = null
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = null
	_contact_audio.stop()
	_current_menu = null
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
	# The new camera's scroll/canvas transform is not applied to the viewport
	# until its next process. Force it now so the same-frame _draw() computes the
	# correct visible world rect (otherwise the retry frame exposes the clear
	# color where the background rect misses the viewport).
	camera.make_current()
	camera.force_update_scroll()
	score = 0
	_landing_bonus = 0
	_overload_display = 0.0
	resonance.reset()
	difficulty = 0
	is_game_over = false
	_restart_timer = -1.0
	_highest_y = jumper.global_position.y
	_death_check_armed = false
	_phase = Phase.START_MENU
	jumper.set_physics_process(false)
	camera.set_physics_process(false)
	if fast_retry:
		# The initial menu choreography is not replayed on death. A clean world
		# starts at the same platform/camera baseline and immediately launches.
		_reset_controls()
		# Ein Neustart aus der Pause darf keinen Zeiger aus der alten Runde
		# mitschleppen: der zugehoerige Finger ist laengst weg.
		_held_pointers.clear()
		_blocked_pointers.clear()
		_initial_bounce_fired = true
		_phase = Phase.PLAYING
		jumper.start_initial_bounce()
		jumper.set_physics_process(true)
		camera.set_physics_process(true)
		_update_pause_button()
	else:
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
	_update_pause_button()

func _cancel_start_sequence() -> void:
	if _start_tween != null and _start_tween.is_valid():
		_start_tween.kill()
	_start_tween = null

func _exit_tree() -> void:
	_cancel_start_sequence()
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()

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
	_drag_pointer = ""
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
			_audio_unlocked = true
			_held_pointers[pointer] = true
			if _phase != Phase.PLAYING or is_game_over:
				_blocked_pointers[pointer] = true
		else:
			_held_pointers.erase(pointer)
			_blocked_pointers.erase(pointer)
	if event is InputEventKey and _keyboard_blocked:
		_keyboard_blocked = Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		return
	if _phase == Phase.PLAYING:
		# Der Pausenknopf wird VOR der Steuerung ausgewertet. Sonst wuerde ein
		# Tap auf den Knopf den Jumper zusaetzlich in die obere Ecke ziehen.
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _try_pause_tap(event.position):
				return
		elif event is InputEventScreenTouch and event.pressed:
			if _try_pause_tap(event.position):
				return
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
		if event.pressed:
			_drag_pointer = "mouse"
			is_dragging = true
			_set_horizontal_target(event.position)
		elif _drag_pointer == "mouse":
			_drag_pointer = ""
			is_dragging = false
			jumper.clear_horizontal_target()
	elif event is InputEventMouseMotion and is_dragging and _drag_pointer == "mouse":
		_set_horizontal_target(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_drag_pointer = "touch:%d" % event.index
			is_dragging = true
			_set_horizontal_target(event.position)
		elif _drag_pointer == "touch:%d" % event.index:
			_drag_pointer = ""
			is_dragging = false
			jumper.clear_horizontal_target()
	elif event is InputEventScreenDrag and is_dragging and _drag_pointer == "touch:%d" % event.index:
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
		# HUD liegt in einer eigenen CanvasLayer (ResonanceHud), damit
		# vorbeiziehende Plattformen den Text nicht ueberdecken.
		if hud != null:
			hud.visible = true
			hud.score = score
			hud.overload_display = _overload_display
	elif hud != null:
		# Im Startmenue und waehrend der Choreografie bleibt die Anzeige aus.
		hud.visible = false

func _get_visible_world_rect() -> Rect2:
	var viewport_rect := get_viewport_rect()
	var canvas_to_world := get_viewport().get_canvas_transform().affine_inverse()
	var top_left := canvas_to_world * viewport_rect.position
	var bottom_right := canvas_to_world * viewport_rect.end
	return Rect2(top_left, bottom_right - top_left)
