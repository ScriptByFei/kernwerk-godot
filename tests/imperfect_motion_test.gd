extends SceneTree
const Game = preload("res://scripts/game/game.gd")

## Zeitverlauf-Probe fuer Landing-Feedback und Kameraimpuls.
##
## Standbilder zeigen nur, DASS etwas passiert; sie belegen nicht, wie es sich
## ueber die Zeit verhaelt. Diese Probe tastet je Frame ab und druckt die
## Messreihe. Entscheidend ist die Gegenprobe: NORMAL darf den Kamera-Offset
## NICHT bewegen, sonst waere der Impuls kein PERFECT-Signal mehr.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._phase = Game.Phase.PLAYING
	game.start_menu.visible = false
	game.jumper.set_physics_process(false)
	game.jumper.set_process(false)
	game.camera.set_physics_process(false)
	game.platform_director._clear_platforms()

	# PERFECT: Offset muss ausschlagen und monoton auf 0 zuruecklaufen.
	game.camera.offset = Vector2.ZERO
	game.camera._impact_remaining = 0.0
	game.camera.perfect_impact()
	var peak := 0.0
	var series: Array[float] = []
	var frames := 0
	while frames < 40:
		game.camera.advance_impact(1.0 / 60.0)
		peak = maxf(peak, game.camera.offset.y)
		if frames < 9:
			series.append(snappedf(game.camera.offset.y, 0.001))
		frames += 1
	var tail := game.camera.offset.y
	print("PERFECT-Kamera: peak=%.3f  rest_nach_40f=%.4f" % [peak, tail])
	print("  Messreihe (erste 9 Frames @60Hz): ", series)
	_check(absf(peak - 3.0) < 0.05, "PERFECT-Impuls erreicht 3.0 Weltpixel")
	_check(series.size() >= 2 and series[1] < series[0], "Impuls faellt sofort wieder ab")
	_check(tail < 0.05, "Impuls klingt innerhalb von 0.12s aus")

	# Gegenprobe: NORMAL darf nichts bewegen.
	game.camera.offset = Vector2.ZERO
	game.camera._impact_remaining = 0.0
	game.camera.advance_impact(1.0 / 60.0)
	_check(is_equal_approx(game.camera.offset.y, 0.0), "ohne Impuls bleibt der Offset bei 0")

	# Und der Impuls darf die Kamera NICHT dauerhaft verschieben (Ratchet).
	var before := 5.0
	game.camera.offset.y = before
	game.camera._impact_remaining = 0.0
	for i in range(120):
		game.camera.advance_impact(1.0 / 60.0)
	_check(is_equal_approx(game.camera.offset.y, before), "einmaliger Impuls bleibt nicht stehen")

	# Kameraposition (Ratchet) muss unberuehrt bleiben: nur der Offset wirkt.
	game.camera.position = Vector2(540.0, 800.0)
	game.camera.target = null
	game.camera.perfect_impact()
	var pos_before := game.camera.position
	for i in range(30):
		game.camera._physics_process(1.0 / 60.0)
	_check(game.camera.position == pos_before, "Impuls veraendert die Kameraposition nicht")

	# Wirkungsdauern: PERFECT muss laenger nachklingen als NORMAL.
	var d := JumpConfig.LANDING_EFFECT_DURATIONS
	print("Wirkungsdauern: NORMAL=%.2f RESONANCE=%.2f PERFECT=%.2f" % [d[0], d[1], d[2]])
	_check(d[2] > d[1] and d[1] > d[0], "PERFECT klingt am laengsten nach")

	print("MOTION: %d checks, %d failures" % [checks, failures])
	game.free()
	quit(1 if failures else 0)

var checks := 0
var failures := 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)
