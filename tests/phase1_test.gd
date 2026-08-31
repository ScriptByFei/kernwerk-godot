extends SceneTree
## Headless-Smoke-Test Phase 1: Lane-Logik ohne Renderer.
## Aufruf: godot4 --headless -s tests/phase1_test.gd

var fails := 0

func _init() -> void:
	var player := Node2D.new()
	player.set_script(load("res://scripts/player/player.gd"))
	# Kein Baum nötig: Logik-Tests ohne _ready/TouchNode
	var p = player as Player
	p.current_lane = 1

	# clamp-Bounds: Links/Rechts limitiert
	p.move_to_lane(-5)
	_check(p.current_lane == 0, "lane clamp unten (0)")
	p.move_to_lane(99)
	_check(p.current_lane == 2, "lane clamp oben (2)")

	# bewusster Move auf gleiche Lane = kein Signal
	var sig_count := [0]
	p.lane_changed.connect(func(_l): sig_count[0] += 1)
	p.move_to_lane(2)
	_check(sig_count[0] == 0, "gleiche Lane → kein lane_changed")

	p.current_lane = 0
	p.move_to_lane(1)
	_check(sig_count[0] == 1, "echter Lane-Wechsel → 1 Signal")
	_check(p.current_lane == 1, "current_lane aktualisiert")

	# Lane-X Werte plausibel
	_check(GameConfig.LANE_X.size() == 3, "3 Lanes definiert")
	_check(GameConfig.LANE_X[0] < GameConfig.LANE_X[1] and GameConfig.LANE_X[1] < GameConfig.LANE_X[2], "Lane-X aufsteigend")

	if fails == 0:
		print("PHASE1 TESTS: ALLE OK")
	else:
		print("PHASE1 TESTS: %d FEHLER" % fails)
	quit(1 if fails > 0 else 0)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ " + msg)
	else:
		fails += 1
		print("  ✗ " + msg)