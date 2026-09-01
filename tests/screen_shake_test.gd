extends SceneTree
## Phase-8.2-Tests: kurzer, driftfreier Welt-Offset.

const ScreenShakeScript = preload("res://scripts/game/screen_shake.gd")

var fails := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ " + msg)
	else:
		fails += 1
		print("  ✗ " + msg)

func _init() -> void:
	var world := Node2D.new()
	get_root().add_child(world)
	var target := Node2D.new()
	target.position = Vector2(24.0, 48.0)
	get_root().add_child(target)
	var shake := ScreenShakeScript.new()
	world.add_child(shake)
	shake.setup(target)
	var origin := target.position

	shake.shake(8.0, 0.18)
	await process_frame
	_check(target.position.distance_to(origin) > 0.01, "Shake verschiebt das Ziel direkt")
	await create_timer(0.5).timeout
	_check(target.position.distance_to(origin) < 0.01, "Shake endet exakt am Ursprung")

	shake.shake(8.0, 0.18)
	await process_frame
	shake.shake(5.0, 0.12)
	await create_timer(0.5).timeout
	_check(target.position.distance_to(origin) < 0.01, "Überlagerte Shakes addieren nicht und driften nicht")

	if fails == 0:
		print("SCREEN SHAKE TESTS: ALLE OK")
	else:
		print("SCREEN SHAKE TESTS: %d FEHLER" % fails)
	target.queue_free()
	world.queue_free()
	await process_frame
	quit(1 if fails > 0 else 0)
