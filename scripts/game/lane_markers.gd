class_name LaneMarkers
extends Node2D
## Zeichnet dezente Lane-Trennlinien (Debug/Hilfe, im finalen Spiel deaktivierbar).

var visible_lines := true

func _draw() -> void:
	if not visible_lines:
		return
	var color := Color(1.0, 1.0, 1.0, 0.07)
	for x in [540.0]:
		draw_line(Vector2(x, 0), Vector2(x, 1920), color, 6.0)