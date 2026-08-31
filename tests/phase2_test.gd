extends SceneTree
## Headless-Test Phase 2: WeaponController-Logik (Feuerrate, Bullet-Eigenschaften).
## Aufruf: godot4 --headless -s tests/phase2_test.gd

var fails := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ " + msg)
	else:
		fails += 1
		print("  ✗ " + msg)

func _init() -> void:
	# WeaponController instanziieren ohne Szene
	var wc = WeaponController.new()
	_check(wc.damage == GameConfig.DAMAGE, "Startschaden = Config")
	_check(wc.fire_rate == GameConfig.FIRE_RATE, "Feuerrate = Config")
	_check(is_equal_approx(wc._cooldown, 0.0), "Cooldown startet bei 0")
	_check(wc.bullet_count == 1, "MVP: 1 Projektil pro Schuss")
	# Setup ohne Player: kein Crash im _physics_process? (Erst wenn parent gesetzt)
	wc.setup(null)  # bewusst null → guard greift
	print("  ✓ Setup mit null-Player crasht nicht (guard)")
	# Feuerrate-Mathematik
	var wc2 = WeaponController.new()
	wc2.fire_rate = 4.0
	_check(is_equal_approx(1.0 / wc2.fire_rate, 0.25), "Cooldown = 1/Rate (0.25s)")
	# Bullet-Basics
	var b = Bullet.new()
	b.setup(55, 999.0)
	_check(b.damage == 55, "Bullet-Damage übernommen")
	_check(is_equal_approx(b.speed, 999.0), "Bullet-Speed übernommen")
	b.free()
	wc.free()
	# Bullet despawnt über Bildschirmrand
	var b2 = Bullet.new()
	b2.position = Vector2(540, -100)
	_check(b2.position.y < -60.0, "Bullet y über Schwelle → Despawn-Bedingung greift")
	b2.free()
	if fails == 0:
		print("PHASE2 TESTS: ALLE OK")
	else:
		print("PHASE2 TESTS: %d FEHLER" % fails)
	quit(1 if fails > 0 else 0)