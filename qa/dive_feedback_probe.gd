extends SceneTree

## Sichtnachweis fuer die Dive-Rueckmeldung.
##
## Rendert vier Zustaende in Produktionsgroesse (430x932) nach
## docs/assets/screenshots/dive_feedback/:
##  1. ruhiger Fall OHNE Dive  — die Gegenprobe: hier darf nichts zu sehen sein
##  2. Dive direkt nach dem Ausloesen (noch langsam)
##  3. Dive bei hoher Fallgeschwindigkeit (Spur lang)
##  4. nach der Landung        — die Rueckmeldung muss weg sein
##
## Ohne Bild 1 waere nicht belegt, dass die Rueckmeldung wirklich am Dive haengt
## und nicht am Fliegen ueberhaupt.
##
## Die Physik des Jumpers wird stillgelegt und der Zustand von Hand gesetzt.
## Sonst ueberschreibt die laufende Simulation den Zustand zwischen Setzen und
## Aufnahme (gemessen: der als "Dive" gedachte Zustand 3 war beim Aufnehmen
## schon wieder ein Absprung mit -2264 px/s).

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const DIR := "docs/assets/screenshots/dive_feedback/"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://" + DIR)
	var game := Game.new()
	get_root().add_child(game)
	await process_frame
	await process_frame
	game._start_game()
	await create_timer(JumpConfig.START_TOTAL + 0.4).timeout

	var jumper = game.jumper
	# Simulation anhalten: der Zustand wird von Hand gesetzt.
	jumper.set_physics_process(false)
	jumper.set_process(false)

	# --- 1. Ruhiger Fall ohne Dive -------------------------------------------
	_set_state(jumper, false, 900.0)
	await _hold_and_capture(jumper, DIR + "01_fall_ohne_dive.png")
	print("ZUSTAND 1: aktiv=%s tempo=%.0f" % [jumper.is_diving(), jumper.velocity.y])

	# --- 2. Dive, gerade ausgeloest (noch langsam) ---------------------------
	_set_state(jumper, false, JumpConfig.DIVE_MIN_FALL_SPEED * 1.5)
	jumper._dive_available = true
	var started: bool = jumper.try_dive()
	await _hold_and_capture(jumper, DIR + "02_dive_langsam.png")
	print("ZUSTAND 2: ausgeloest=%s aktiv=%s tempo=%.0f"
		% [started, jumper.is_diving(), jumper.velocity.y])

	# --- 3. Dive bei hoher Geschwindigkeit -----------------------------------
	_set_state(jumper, true, JumpConfig.DIVE_MAX_FALL_SPEED * 0.92)
	await _hold_and_capture(jumper, DIR + "03_dive_schnell.png")
	print("ZUSTAND 3: aktiv=%s tempo=%.0f" % [jumper.is_diving(), jumper.velocity.y])

	# --- 4. nach der Landung -------------------------------------------------
	_set_state(jumper, false, 900.0)
	await _hold_and_capture(jumper, DIR + "04_nach_landung.png")
	print("ZUSTAND 4: aktiv=%s" % jumper.is_diving())

	game.queue_free()
	await process_frame
	quit(0)

## Setzt den Dive-Zustand und die Fallgeschwindigkeit gemeinsam.
func _set_state(jumper, diving: bool, fall_speed: float) -> void:
	jumper._dive_active = diving
	jumper.velocity = Vector2(0.0, fall_speed)

## Zeichnet neu und nimmt auf. Mehrere Frames, weil die Neuzeichnung erst im
## naechsten Frame im Renderziel landet.
func _hold_and_capture(jumper, path: String) -> void:
	jumper._feedback_visual.queue_redraw()
	await process_frame
	await process_frame
	await process_frame
	_capture(path)

func _capture(path: String) -> void:
	var image := get_root().get_texture().get_image()
	image.save_png("res://" + path)
	print("SAVED " + path)
