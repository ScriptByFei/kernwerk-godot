extends SceneTree

## Fahert den ECHTEN Weg: Tipp auf das Startmenue -> Choreografie -> Spiel ->
## Klangbett. Nicht der Handler wird gerufen, sondern die Eingabe zugestellt.
##
## Warum mit echtem Fenster: der Menue-Tipp laeuft ueber den Szenenbaum und die
## Groessenumrechnung. Im 64x64-Headless-Fenster sitzt jeder synthetische Tipp
## an der falschen Stelle (dokumentierte Falle im Projekt).
##
## Aufruf:
## xvfb-run -a -s "-screen 0 430x932x24" godot4 --rendering-driver opengl3 \
##   --resolution 430x932 --path . -s qa/ambience_start_probe.gd

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")

var _game: Game
var _frames := 0

func _init() -> void:
	Input.use_accumulated_input = false
	_game = Game.new()
	_game.run_ambience_in_tests = true
	get_root().add_child(_game)
	await process_frame
	await process_frame
	print("Fenster: %s" % DisplayServer.window_get_size())
	_report("vor dem Tipp")
	# Echter Tipp in die Bildmitte, ueber die echte Eingabepipeline.
	var middle := Vector2(DisplayServer.window_get_size()) * 0.5
	_touch(middle, true)
	await process_frame
	_touch(middle, false)
	# Die Startchoreografie laeuft bis START_BOUNCE_AT, danach beginnt die Runde.
	var deadline := Time.get_ticks_msec() + 15000
	while _game._phase != Game.Phase.PLAYING and Time.get_ticks_msec() < deadline:
		await process_frame
	_frames = 0
	while _frames < 12:
		await process_frame
	print("Phase nach dem Tipp: %s" % _game._phase)
	_report("nach dem Spielstart")
	# Jetzt ein echter Steuertipp: das Bett darf dabei nicht abreissen.
	_touch(Vector2(middle.x + 60.0, middle.y), true)
	for _index in range(20):
		await process_frame
	_report("waehrend der Steuerung")
	_touch(Vector2(middle.x + 60.0, middle.y), false)
	# Spannungsschicht im echten Lauf: die Hoehe treibt die Schwierigkeit, die
	# wiederum die Spannung. Ohne das waere nur die Zuordnung im Test belegt,
	# nicht das Zusammenspiel im laufenden Spiel.
	for step in range(1, JumpConfig.MAX_DIFFICULTY + 1):
		_game._highest_y -= JumpConfig.DIFFICULTY_STEP_SCORE * JumpConfig.SCORE_PER_UNIT
		_game._update_score()
		await process_frame
		_report("Stufe %d" % step)
	# Nach einem Neustart muss die Atmosphaere wieder am Anfang stehen.
	_game._restart(true)
	_report("nach dem Neustart")
	_game.free()
	for _index in range(10):
		await process_frame
	quit(0)

func _touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _report(label: String) -> void:
	var bed := _game.get_node_or_null("AmbienceAudio") as AudioStreamPlayer
	var tension := _game.get_node_or_null("TensionAudio") as AudioStreamPlayer
	var state := "kein Knoten"
	if bed != null:
		state = "spielt=%s pegel=%.1f dB" % [bed.playing, bed.volume_db]
	var tension_state := "-"
	if tension != null:
		tension_state = "spielt=%s pegel=%.1f dB (Ziel %.1f dB, Stufe %d)" % [
			tension.playing, tension.volume_db, _game.ambience.tension_target_db(), _game.difficulty]
	print("%-24s Grundklang: %-28s Spannung: %s" % [label, state, tension_state])

func _process(_delta: float) -> bool:
	_frames += 1
	return false
