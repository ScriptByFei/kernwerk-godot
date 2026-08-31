extends Node2D

# Spike: Loop-Beweis. Gruener Punkt ping-pongt quer uebers Feld.

var _t: float = 0.0
var _frames: int = 0
var _elapsed: float = 0.0
var _fps_label: Label

func _ready() -> void:
	_fps_label = Label.new()
	_fps_label.position = Vector2(10, 10)
	_fps_label.add_theme_font_size_override("font_size", 12)
	add_child(_fps_label)

func _process(delta: float) -> void:
	_t += delta
	_elapsed += delta
	_frames += 1
	var p := get_node("Dot") as Polygon2D
	p.position.x = 50 + absf(fmod(_t * 120.0, 305.0) - 152.5) + 0.0
	p.position.y = 360 + sin(_t * 2.0) * 100.0
	if _elapsed >= 1.0:
		_fps_label.text = "FPS: %d" % int(_frames / _elapsed)
		_frames = 0
		_elapsed = 0.0