class_name LaneMarkers
extends Node2D
## Zeichnet Lane-Trennlinien relativ zur Viewport-Breite (25/50/75 %).
## Im finalen Spiel deaktivierbar über visible_lines = false.

var visible_lines := true

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not visible_lines:
		return
	var color := Color(1.0, 1.0, 1.0, 0.07)
	var w := get_viewport_rect().size.x
	var h := get_viewport_rect().size.y
	for lane in range(1, GameConfig.LANE_COUNT):
		var x := GameConfig.lane_x(lane, w)
		draw_line(Vector2(x, 0), Vector2(x, h), color, 6.0)