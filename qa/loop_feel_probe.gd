extends SceneTree

## Gefuehlsmessung des neuen Loops im ECHTEN Fenster (430x932).
##
## Beantwortet drei Fragen, die eine Formel nicht beantworten kann:
##  1. Wird der Run tatsaechlich abwechslungsreich? (verschiedene Seeds ->
##     verschiedene Strecken)
##  2. Wie lange dauert ein Sprung wirklich, gemessen an der Physik?
##  3. Bleiben die Sprossen erreichbar, wenn ein echter Fahrer spielt?
##
## Aufruf:
##   xvfb-run -a -s "-screen 0 430x932x24" godot4 --rendering-driver opengl3 \
##     --resolution 430x932 --path . -s qa/loop_feel_probe.gd

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const PlatformDirector = preload("res://scripts/jump/platform_director.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_measure_run_variety()
	_measure_cycle_from_physics()
	_measure_reachability()
	quit(0)

## 1) Abwechslung: unterscheiden sich die Strecken verschiedener Seeds wirklich?
func _measure_run_variety() -> void:
	print("\n=== STREcken je Seed (erste 14 Sprossen, nur x) ===")
	var signatures := {}
	var heights := {}
	for seed_value in range(8):
		var world := Node2D.new()
		root.add_child(world)
		var director := PlatformDirector.new(seed_value)
		director.initialize(world, JumpConfig.PLATFORM_LAYOUT)
		director.maintain(-2000.0, 2000.0, 2)
		var xs: Array[String] = []
		var highest := 1.0e9
		for platform in director._active_platforms:
			xs.append("%.0f" % platform.position.x)
			highest = minf(highest, platform.position.y)
		var signature := ",".join(xs)
		signatures[signature] = true
		var depth: float = absf(highest)
		heights[seed_value] = depth
		print("  Seed %d: %d Sprossen, Strecke bis y=%.0f" % [seed_value, xs.size(), highest])
		print("     x: %s" % signature)
		world.queue_free()
	print("  -> verschiedene Strecken: %d von 8 Seeds" % signatures.size())

## 2) Sprungdauer aus der ECHTEN Physik, nicht aus der Formel.
func _measure_cycle_from_physics() -> void:
	print("\n=== Sprungdauer (echte Physik, 60 Hz) ===")
	for entry in [[0, false, "0/3"], [1, false, "1/3"], [2, false, "2/3"], [0, true, "Overload"]]:
		var charges: int = entry[0]
		var overload: bool = entry[1]
		var label: String = entry[2]
		var gravity := JumpConfig.pace_gravity(charges, overload)
		var bounce := JumpConfig.pace_bounce(charges, overload)
		# Der Springer startet auf einer Sprosse und fliegt bis zur naechsten.
		var y := 0.0
		var v := -bounce
		var apex := y
		var frames := 0
		var landed := -1
		var gap := 300.0
		while frames < 600:
			v += gravity / 60.0
			y += v / 60.0
			frames += 1
			apex = minf(apex, y)
			if v > 0.0 and y >= -gap:
				landed = frames
				break
		var seconds := float(landed) / 60.0
		var height := -apex
		print("  %-9s: %5.3f s (%3d Bilder) | Scheitel %6.1f px | Reserve %+.0f px | Tempo %.0f px/s"
			% [label, seconds, landed, height, height - gap, gap / seconds])

## 3) Erreichbarkeit — bewusst NICHT mit einem Bot gefahren.
##
## Ein Bot ist kein Spieler: seine Abstuerze messen die Lenkautoritaet des Bots,
## nicht die Fairness der Route. Die Erreichbarkeit wird deshalb dort geprueft,
## wo sie hingehoert — in `tests/gameplay_director_test.gd`, ueber ALLE Seeds und
## Stufen hinweg und gegen die Reserve des Scheitels.
func _measure_reachability() -> void:
	print("\n=== Erreichbarkeit ===")
	var gap := JumpConfig.PLATFORM_VERTICAL_GAP + JumpConfig.MAX_DIFFICULTY * JumpConfig.DIFFICULTY_VERTICAL_BONUS
	var apex := JumpConfig.pace_bounce(0, false) * JumpConfig.pace_bounce(0, false) / (2.0 * JumpConfig.pace_gravity(0, false))
	print("  weiteste Sprosse (Stufe %d): %.0f px" % [JumpConfig.MAX_DIFFICULTY, gap])
	print("  Scheitel der RUHIGSTEN Stufe: %.0f px" % apex)
	print("  Reserve: %+.0f px -> %s" % [apex - gap, "FAIR" if apex - gap > 100.0 else "ZU KNAPP"])
	print("  (Die schwerste Stufe hat den groessten Abstand; die ruhige Stufe muss")
	print("   ihn noch schaffen, sonst waere ein Rueckfall in 0/3 eine Falle.)")
