extends SceneTree
## Phase-3-Tests: Enemy HP/Damage/Kill, LaneObject-Movement, HitDetection.
## Aufruf: godot4 --headless -s tests/phase3_test.gd

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

	# --- Enemy: HP, Damage, Kill ---
	var e := Enemy.new()
	world.add_child(e)
	e.configure(1, 100, 150.0)
	_check(e.current_hp == 100, "HP 100 gesetzt")
	_check(e.lane == 1, "Lane gesetzt")

	var kills := [0]
	e.enemy_killed.connect(func(_en): kills[0] += 1)

	e.take_damage(30)
	_check(e.current_hp == 70, "Damage 30 → HP 70")
	e.take_damage(30)
	_check(e.current_hp == 40, "Zweiter Schuss: 70-30 = 40")
	_check(kills[0] == 0, "Noch nicht tot bei HP 40")
	e.take_damage(100)
	_check(e.current_hp <= 0, "Lethal Damage → HP ≤ 0")
	_check(kills[0] == 1, "enemy_killed genau 1× gefeuert")
	_check(e._hp_label == null or e._hp_label.visible == false, "HP-Label bei Tod versteckt (oder im Headless nicht vorhanden)")

	# Kill-Loop: nach Tod nehmen weitere take_damage-Aufrufe NICHT erneut ab
	e.take_damage(50)
	_check(kills[0] == 1, "Doppel-Kill verhindert")

	# --- LaneObject Movement: bewegt sich nach unten, despawnt unten ---
	var f := Enemy.new()
	world.add_child(f)
	f.configure(2, 10, 200.0)
	f.position = Vector2(810, 1800)
	var reached := [0]
	f.reached_bottom.connect(func(_o): reached[0] += 1)
	var y0 := f.global_position.y
	f._physics_process(1.0 / 60.0)
	_check(f.global_position.y > y0, "Enemy bewegt sich nach UNTEN")
	for i in 400:
		if is_instance_valid(f):
			f._physics_process(1.0 / 60.0)
		else:
			break
	_check(not is_instance_valid(f) or f.is_queued_for_deletion(), "Enemy despawnt unter dem Rand")
	_check(reached[0] == 1, "reached_bottom 1× gefeuert")

	# --- HitDetection: Bullet trifft Enemy in gleicher Lane ---
	var e2 := Enemy.new()
	world.add_child(e2)
	e2.configure(1, 50, 0.0)  # steht still
	e2.position = Vector2(540, 800)  # Mitte, Mitte
	var b := Bullet.new()
	world.add_child(b)
	b.setup(10, 0.0)
	b.global_position = Vector2(540, 800 + 10)  # überlappt vertikal
	HitDetection.process_hits([b], [e2])
	_check(e2.current_hp == 40, "Treffer: Damage 10 → HP 40")
	var hp_after_kill = [50]
	e2.health_changed.connect(func(_e, hp): hp_after_kill[0] = hp)
	var b2 = Bullet.new(); world.add_child(b2); b2.setup(999, 0.0)
	b2.global_position = Vector2(540, 810)
	HitDetection.process_hits([b2], [e2])
	_check(e2.current_hp <= 0, "Kill-Treffer: HP ≤ 0")
	_check(hp_after_kill[0] <= 0, "health_changed bis 0 dokumentiert")
	# Bullet konsumiert (freed):
	await create_timer(0.1).timeout
	_check(not is_instance_valid(b2), "Bullet beim Treffer entfernt")
	# Fehlschuss: falsche Lane → kein Treffer
	var e3 := Enemy.new(); world.add_child(e3); e3.configure(0, 30, 0.0)
	e3.position = Vector2(270, 500)
	var b3 = Bullet.new(); world.add_child(b3); b3.setup(10, 0.0)
	b3.global_position = Vector2(540, 501)  # Mitte, Gegner links
	HitDetection.process_hits([b3], [e3])
	_check(e3.current_hp == 30, "Falsche Lane → kein Damage")

	if fails == 0:
		print("PHASE3 TESTS: ALLE OK")
	else:
		print("PHASE3 TESTS: %d FEHLER" % fails)
	quit(1 if fails > 0 else 0)