extends SceneTree
## Regression-Test 2: Bullet muss WIRKLICH nach oben fliegen.
## Bug: Bullet war Kind des Players → Despawn-Schwelle (position.y < -60) griff
## nach ~140px lokalem Flug → 'knapp über Charakter und weg'.
## Aufruf: godot4 --headless -s tests/phase2_flight_test.gd

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

	# Spieler-Position wie im Spiel (Mitte, unten) — neues relatives Layout
	var player := Node2D.new()
	player.position = Vector2(GameConfig.lane_x(1, 1080.0), GameConfig.player_y(1920.0))
	world.add_child(player)

	# Bullet wie im gefixten WeaponController: Kind der Welt + global spawnen
	var b = Bullet.new()
	world.add_child(b)
	b.global_position = player.global_position + Vector2(0, -80)
	var start_y: float = b.global_position.y
	_check(absf(start_y - (GameConfig.player_y(1920.0) - 80.0)) < 0.01, "Start bei y=%.0f (über Spieler)" % start_y)

	# 1 Sekunde simulieren: 60 Physics-Ticks à speed/60 px
	for i in 60:
		b._physics_process(1.0 / 60.0)
	var moved: float = start_y - b.global_position.y
	_check(absf(moved - GameConfig.BULLET_SPEED) < 1.0, "Nach 1s exakt %.0f px geflogen (ist %.0f)" % [GameConfig.BULLET_SPEED, moved])
	_check(b.global_position.y < start_y, "Fliegt nach OBEN (global y sinkt)")

	# Alter Bug: Position < -60 lokal beim Kind des Players → früher Despawn simuliert
	var b2 = Bullet.new()
	player.add_child(b2)
	b2.global_position = player.global_position + Vector2(0, -80)
	var local_start: float = b2.position.y  # ~ -80 lokal (weil Player y=1650 → global=1570, lokal=-80)
	for i in 8:  # 8 Ticks
		b2._physics_process(1.0 / 60.0)
	_check(b2.position.y < -60.0, "Alter Bug: Bullet (im Player) despawnt bereits nach 8 Ticks (lokal %.0f)" % b2.position.y)
	_check(b2.global_position.y > GameConfig.player_y(1920.0) - 300.0, "...und war global immer noch nahe beim Spieler (User-Symptom!)")
	b2.free()

	# Neue Physik: Kind der Welt → despawnt erst, wenn GLOBAL oben raus
	for i in 80:
		b._physics_process(1.0 / 60.0)
	_check(not is_instance_valid(b) or b.is_queued_for_deletion(), "Bullet despawnt erst über dem Bildschirmrand (global)")
	if fails == 0:
		print("FLIGHT TESTS: ALLE OK")
	else:
		print("FLIGHT TESTS: %d FEHLER" % fails)
	quit(1 if fails > 0 else 0)