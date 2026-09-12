extends SceneTree

## Der entscheidende Test: echte Eingabezustellung in einem ECHTEN Fenster.
##
## Headless hat nur ein 64x64-Fenster, dort sind synthetische Taps wertlos.
## Hier laeuft alles bei 430x932, und die Canvas-Koordinaten der Knoepfe werden
## ueber die Stretch-Transform in Fensterkoordinaten umgerechnet — genau der
## Weg, den ein echter Fingertipp nimmt.

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")

var game
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Input.use_accumulated_input = false
	print("Fenster   = ", DisplayServer.window_get_size())
	print("root.size = ", get_root().size)

	game = Game.new()
	root.add_child(game)
	await process_frame
	game._phase = Game.Phase.PLAYING
	game.jumper.set_physics_process(false)
	game.camera.set_physics_process(false)
	game._update_pause_button()
	await process_frame

	var stretch: Transform2D = get_root().get_stretch_transform()
	print("stretch   = ", stretch.x.x, " / ", stretch.y.y)
	print("control.size = ", game.pause_button.size)

	# --- 1. Pausenknopf antippen (Canvas -> Fenster) ---
	var canvas_center: Vector2 = game._pause_button_hit_rect().get_center()
	var window_center := _to_window(canvas_center)
	print("\n[1] Pausenknopf: canvas %s -> window %s" % [canvas_center, window_center])
	_tap_at(window_center)
	await create_timer(JumpConfig.PAUSE_IN_DURATION + 0.25).timeout
	print("    is_paused=%s  tree_paused=%s  menu=%s" % [
		game._is_paused, paused, game.pause_menu != null and is_instance_valid(game.pause_menu)])
	_check(game._is_paused, "Pausenknopf reagiert auf echte Eingabe")
	if not game._is_paused:
		_finish()
		return

	var menu = game.pause_menu
	menu._locked = false  # frischer Zustand fuer den naechsten Test

	# --- 2. WEITER antippen ---
	var resume_canvas: Vector2 = menu.resume_rect().get_center()
	var resume_window := _to_window(resume_canvas)
	print("\n[2] WEITER: canvas %s -> window %s" % [resume_canvas, resume_window])
	_tap_at(resume_window)
	await create_timer(JumpConfig.PAUSE_OUT_DURATION + 0.3).timeout
	print("    menu._locked=%s  is_paused=%s  tree_paused=%s  menu visible=%s" % [
		menu._locked, game._is_paused, paused, menu.visible])
	_check(menu._locked, "WEITER erreicht den Handler")
	_check(not paused, "WEITER gibt den Baum frei")

	# --- 3. erneut pausieren, dann NEU STARTEN ---
	_tap_at(window_center)
	await create_timer(JumpConfig.PAUSE_IN_DURATION + 0.25).timeout
	print("\n[3] erneut pausiert: is_paused=%s" % game._is_paused)
	_check(game._is_paused, "erneutes Pausieren funktioniert")

	var restart_canvas: Vector2 = game.pause_menu.restart_rect().get_center()
	var restart_window := _to_window(restart_canvas)
	print("    NEU STARTEN: canvas %s -> window %s" % [restart_canvas, restart_window])
	_tap_at(restart_window)
	await process_frame
	await process_frame
	await process_frame
	print("    nach dem Tap: locked=%s is_paused=%s tree_paused=%s phase=%s score=%d" % [
		game.pause_menu._locked if game.pause_menu != null else "n/a",
		game._is_paused, paused, game._phase, game.score])
	_check(not paused, "NEU STARTEN gibt den Baum frei")
	# Der Score wird neu aus der Hoehe berechnet und steigt sofort wieder an.
	# Auf 0 zu pruefen waere falsch; entscheidend ist, dass der Ladungsbonus
	# der alten Runde weg ist.
	_check(game._landing_bonus == 0, "NEU STARTEN loescht den Punktebonus der alten Runde")
	_check(game._phase == Game.Phase.PLAYING, "NEU STARTEN startet eine laufende Runde")
	var y0: float = game.jumper.global_position.y
	await create_timer(0.3).timeout
	_check(game.jumper.global_position.y != y0, "die neue Runde bewegt sich")
	print("    Bewegung: y %.1f -> %.1f" % [y0, game.jumper.global_position.y])

	_finish()

func _finish() -> void:
	paused = false
	if game != null and is_instance_valid(game):
		game.queue_free()
	await process_frame
	print("\nERGEBNIS: %s" % ("ALLE OK" if failures == 0 else "%d FEHLER" % failures))
	quit(1 if failures > 0 else 0)

## Canvas-Koordinate -> Fensterkoordinate. Die Stretch-Transform bildet genau
## so ab, wie Godot die echte Eingabe zurueckrechnet.
func _to_window(canvas_pos: Vector2) -> Vector2:
	return get_root().get_stretch_transform() * canvas_pos

## Vollstaendiger Tap (press + release) durch die echte Pipeline.
func _tap_at(position: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = position
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = position
	Input.parse_input_event(release)
	Input.flush_buffered_events()

func _check(condition: bool, description: String) -> void:
	if condition:
		print("    ✓ " + description)
		return
	failures += 1
	print("    ✗ " + description)
