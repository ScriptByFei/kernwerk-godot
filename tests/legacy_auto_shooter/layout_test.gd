extends SceneTree
## Layout-Test: Lane-X-Positionen müssen in jedem Viewport korrekt sitzen.
## Aufruf: godot4 --headless -s tests/layout_test.gd

var fails := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ " + msg)
	else:
		fails += 1
		print("  ✗ " + msg)

func _init() -> void:
	var widths := {
		"iPhone 19.5:9 (Referenzhöhe 1920)": 844.0,
		" klassisch 9:16": 1080.0,
		"schmal 4:3 (Tablet)": 1440.0,
		"sehr schmal 21:9": 823.0,
	}
	for name in widths:
		var w: float = widths[name]
		var l0 := GameConfig.lane_x(0, w)
		var l1 := GameConfig.lane_x(1, w)
		var l2 := GameConfig.lane_x(2, w)
		_check(absf(l1 - w / 2.0) < 0.01, "%s: Mitte exakt (%.0f==%.0f)" % [name, l1, w / 2.0])
		_check(absf(l0 - w * 0.25) < 0.01, "%s: links bei 25%%" % name)
		_check(absf(l2 - w * 0.75) < 0.01, "%s: rechts bei 75%%" % name)
		_check(l0 > 60.0, "%s: Lane 0 nicht an der Kante (%.0f px Abstand)" % [name, l0])
		_check(w - l2 > 60.0, "%s: Lane 2 nicht an der Kante (%.0f px Rand)" % [name, w - l2])
		_check(absf((l2 - l1) - (l1 - l0)) < 0.01, "%s: Lanes äquidistant" % name)

	# player_y auf verschiedenen Höhen
	_check(absf(GameConfig.player_y(1920.0) - 1651.2) < 0.5, "player_y(1920) = 86%%")
	_check(GameConfig.player_y(2400.0) > GameConfig.player_y(1920.0), "player_y skaliert mit Höhe")

	if fails == 0:
		print("LAYOUT TESTS: ALLE OK")
	else:
		print("LAYOUT TESTS: %d FEHLER" % fails)
	quit(1 if fails > 0 else 0)