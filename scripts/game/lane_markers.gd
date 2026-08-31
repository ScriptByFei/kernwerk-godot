class_name LaneMarkers
extends Node2D
## Zeichnet Lane-Trennlinien relativ zur Viewport-Breite (25/50/75 %).
## Stil: sehr dezente Gradient-Linien (wie Last War) — oben/dunten ausblendend,
## damit die Spielfeld-Kanten nicht wie "Wände" wirken.

var visible_lines := false  # Lane-Linien aus — Timo-Entscheidung: cleaner Look ohne Linien

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not visible_lines:
		return
	var h := get_viewport_rect().size.y
	var w := get_viewport_rect().size.x
	var fade := h * 0.12  # oben + unten sanft ausblenden
	# ALLE 4 Grenzen: linker Feldrand (0%) + Interlane-Grenzen + rechter Feldrand (100%)
	# → symmetrisches Bild, kein "offener" linker Rand.
	var xs: Array[float] = [0.0]
	for lane in range(1, GameConfig.LANE_COUNT):
		xs.append(GameConfig.lane_x(lane, w))
	xs.append(w)
	for x in xs:
		# Rand-Linien 3px einrücken: bei exakt 0/w würde die halbe Strichbreite
		# geclippt und die Kante wir unsichtbar (User-Feedback: linke Linie fehlte).
		var draw_x := x
		if x < 1.0:
			draw_x = 3.0
		elif x > w - 1.0:
			draw_x = w - 3.0
		# Verlauf: oben transparent → Mitte sichtbar → unten transparent
		draw_line(Vector2(draw_x, 0), Vector2(draw_x, fade), Color(1, 1, 1, 0.02), 4.0)
		draw_line(Vector2(draw_x, fade), Vector2(draw_x, h - fade), Color(1, 1, 1, 0.07), 4.0)
		draw_line(Vector2(draw_x, h - fade), Vector2(draw_x, h), Color(1, 1, 1, 0.02), 4.0)