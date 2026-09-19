extends SceneTree

## Klaert empirisch, in welchem Koordinatenraum `InputEvent.position` ankommt:
## Design-Pixel (Viewport 1080 breit) oder Fensterpixel (405 breit)?
##
## Entscheidend fuer die Wisch-Schwellwerte: 70 Einheiten bedeuten bei 1080er
## Designbreite etwas voellig anderes als bei 405 Fensterpixeln. Statt darueber
## zu argumentieren, wird gemessen.

class Sink:
	extends Node
	var received: Array[Vector2] = []
	func _ready() -> void:
		set_process_input(true)
	func _input(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			received.append(event.position)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var sink := Sink.new()
	root.add_child(sink)
	await process_frame
	var sent := Vector2(200.0, 480.0)
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = sent
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	print("gesendet (Fensterpixel) = ", sent)
	print("empfangen               = ", sink.received)
	print("root.size               = ", root.size)
	print("window size             = ", DisplayServer.window_get_size())
	print("stretch                 = ", root.get_stretch_transform().x.x)
	quit(0)
