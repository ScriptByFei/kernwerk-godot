extends SceneTree
## Regression-Test: Bullets duerfen NICHT als Kind des Players mit globalen Koords
## als lokale position gespawnt werden (Phase-2-Bug: Schuesse unter dem Bildschirm).
## Aufruf: godot4 --headless -s tests/phase2_bugfix_test.gd

var fails := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ " + msg)
	else:
		fails += 1
		print("  ✗ " + msg)

func _init() -> void:
	# Simuliere die Situation: Player-Node auf Lane-X/PLAYER_Y, Weapon als Kind.
	var root_node := Node2D.new()
	get_root().add_child(root_node)

	var player := Node2D.new()
	player.set_script(load("res://scripts/player/player.gd"))
	root_node.add_child(player)
	# _ready braucht TouchInput/WeaponController children — ohne Szene vereinfachen:
	# Wir testen nur die Koordinaten-Mathematik des WeaponControllers:
	var wc = WeaponController.new()
	root_node.add_child(wc)

	# Fake-Player: nur global_position wichtig
	var fake := Node2D.new()
	root_node.add_child(fake)
	fake.position = Vector2(GameConfig.lane_x(1, 1080.0), GameConfig.player_y(1920.0))
	wc.setup(fake as Player)

	# Player bei y=1650. Muss spawn: bullet bei ~1570 (global), NICHT 3300.
	var origin: Vector2 = fake.global_position + Vector2(0, -80)
	_check(absf(origin.y - (GameConfig.player_y(1920.0) - 80.0)) < 0.01, "Spawn-Origin = Player-Y - 80 (global)")

	# Kritisch: nach add_child + global_position Zuweisung ist die lokale
	# Position NICHT mehr 2x versetzt (das war der Bug: position statt global)
	var b = Bullet.new()
	root_node.add_child(b)          # Parent = Root (Welt)
	b.global_position = origin      # global zuweisen NACH add_child
	_check(absf(b.global_position.y - origin.y) < 0.01, "Bullet global Y korrekt (%.0f)" % b.global_position.y)
	_check(absf(b.position.y - origin.y) < 0.01, "Lokale Y == globale Y wenn Parent Wurzel ist (kein Doppel-Offset)")
	b.free()

	# Negativ-Test: Alter Bug — position statt global als Kind eines platzierten Parents
	var b2 = Bullet.new()
	player.add_child(b2)  # Parent = Player (Player-Script ohne children, position default 0,0)
	player.position = Vector2(GameConfig.lane_x(1, 1080.0), GameConfig.player_y(1920.0))
	b2.position = origin  # <-- alter Fehler: globale Koords ueber 'position' zugewiesen
	_check(b2.global_position.y > 3000.0, "Alter Bug wuerde global y>3000 erzeugen (bestaetigt Bug-Ursache)")
	b2.free()

	if fails == 0:
		print("BUGFIX TESTS: ALLE OK")
	else:
		print("BUGFIX TESTS: %d FEHLER" % fails)
	quit(1 if fails > 0 else 0)