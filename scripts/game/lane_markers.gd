class_name LaneMarkers
extends Node2D
## Zeichnet Lane-Trennlinien relativ zur Viewport-Breite (25/50/75 %).
## Stil: sehr dezente Gradient-Linien (wie Last War) — oben/dunten ausblendend,
## damit die Spielfeld-Kanten nicht wie "Wände" wirken.

var visible_lines := true

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not visible_lines:
		return
	var h := get_viewport_rect().size.y
	var w := get_viewport_rect().size.x
	var fade := h * 0.12  # oben + unten sanft ausblenden
	for lane in range(1, GameConfig.LANE_COUNT):
		var x := GameConfig.lane_x(lane, w)
		# Verlauf: oben transparent → Mitte sichtbar → unten transparent (7% Alpha)
		draw_line(Vector2(x, 0), Vector2(x, fade), Color(1, 1, 1, 0.02), 4.0)
		draw_line(Vector2(x, fade), Vector2(x, h - fade), Color(1, 1, 1, 0.07), 4.0)
		draw_line(Vector2(x, h - fade), Vector2(x, h), Color(1, 1, 1, 0.02), 4.0)