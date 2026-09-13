extends SceneTree
## Reine Geometriepruefung: deckt die Kachelreihe den sichtbaren Bereich
## luecklos und ohne Ueberlappungssprung ab, und bleibt die Kachelhoehe exakt?
func _init() -> void:
	var failures := 0
	for top in [-9000.0, -3600.0, -1800.0, -1200.0, -1.0, 0.0, 137.0, 640.0, 900.0, 2400.0]:
		for h in [932.0, 2340.0, 4000.0]:
			var rect := Rect2(0.0, top, 1080.0, h)
			var rects := ShaftBackground.pipe_tiles_rects(rect)
			var ok := rects.size() > 0
			if ok and rects[0].position.y > rect.position.y:
				ok = false
			if ok and rects[rects.size() - 1].end.y < rect.end.y:
				ok = false
			for i in range(rects.size()):
				if not is_equal_approx(rects[i].size.y, ShaftBackground.PIPE_SECTION_HEIGHT):
					ok = false
				if not is_equal_approx(rects[i].position.x, 10.0):
					ok = false
				if i > 0 and not is_equal_approx(rects[i].position.y, rects[i - 1].end.y):
					ok = false
			if not ok:
				failures += 1
				print("FAIL coverage top=", top, " h=", h, " rects=", rects.size())
	print("TILE COVERAGE: ", "OK" if failures == 0 else str(failures) + " failures")
	quit(0 if failures == 0 else 1)
