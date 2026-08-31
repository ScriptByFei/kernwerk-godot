extends SceneTree
## Phase-5-Tests: PlayerStats-Upgrades + UpgradeObject + SpawnManager-Mix.
## Aufruf: godot4 --headless -s tests/phase5_test.gd

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

	# --- PlayerStats: Startwerte ---
	var s := PlayerStats.new()
	world.add_child(s)
	_check(s.damage == GameConfig.DAMAGE and s.fire_rate == GameConfig.FIRE_RATE, "Startwerte aus Config")
	_check(s.soldiers == 1, "1 Soldier am Start")

	# --- Damage-Upgrade ---
	var changed := [0]
	s.stats_changed.connect(func(): changed[0] += 1)
	s.apply_upgrade("damage")
	_check(s.damage == GameConfig.DAMAGE + WaveData.DMG_UPGRADE, "damage +15 (Balancing)")
	_check(changed[0] == 1, "stats_changed gefeuert")

	# --- FireRate-Upgrade ---
	s.apply_upgrade("firerate")
	_check(absf(s.fire_rate - GameConfig.FIRE_RATE * 1.5) < 0.01, "fire_rate x1.5")
	s.apply_upgrade("firerate")
	_check(absf(s.fire_rate - GameConfig.FIRE_RATE * 2.25) < 0.01, "FireRate kumulativ (x1.5²)")

	# --- Soldier-Upgrade ---
	var sold_events := [0]
	s.soldier_count_changed.connect(func(_c): sold_events[0] += 1)
	s.apply_upgrade("soldier")
	_check(s.soldiers == 2 and sold_events[0] == 1, "soldier +1 + Signal")
	s.apply_upgrade("soldier")
	_check(s.soldiers == 3, "soldier kumulativ")

	# --- unbekannter Typ: kein Fake-Effekt ---
	var before_dmg := s.damage
	s.apply_upgrade("nonsense")
	_check(s.damage == before_dmg and changed[0] == 5, "unbekannter Upgrade-Typ: kein Signal/kein Effekt")

	# --- reset ---
	s.reset()
	_check(s.damage == GameConfig.DAMAGE and s.soldiers == 1, "reset → Startwerte")

	# --- UpgradeObject: Konfiguration + Labeltext + collect once ---
	var u := UpgradeObject.new()
	world.add_child(u)
	u.configure_upgrade(1, "firerate", 150.0)
	_check(u.upgrade_type == "firerate" and u.lane == 1, "Upgrade konfiguriert")
	var collected := [0]
	u.upgrade_collected.connect(func(_up): collected[0] += 1)
	u.collect()
	_check(collected[0] == 1, "collect feuert upgrade_collected 1×")
	u.collect()
	_check(collected[0] == 1, "Doppel-collect verhindert (physics off + free queued)")

	# --- SpawnManager: spawnt beide Typen ---
	var sp := SpawnManager.new()
	world.add_child(sp)
	sp.setup(world)
	var enemies := [0]
	var upgrades := [0]
	sp.enemy_spawned.connect(func(_e): enemies[0] += 1)
	sp.upgrade_spawned.connect(func(_u): upgrades[0] += 1)
	sp._spawn_enemy()
	sp._spawn_upgrade()
	_check(enemies[0] == 1, "Spawner erzeugt Enemy")
	_check(upgrades[0] == 1, "Spawner erzeugt UpgradeObject")
	# Upgrade-Chance im gültigen Bereich
	_check(sp.upgrade_chance > 0.0 and sp.upgrade_chance < 1.0, "upgrade_chance als Wahrscheinlichkeit")

	# --- HitDetection trifft Upgrade ---
	var u2 := UpgradeObject.new()
	world.add_child(u2)
	u2.configure_upgrade(1, "damage", 0.0)
	u2.position = Vector2(540, 800)
	var b := Bullet.new()
	world.add_child(b)
	b.setup(10, 0.0)
	b.global_position = Vector2(540, 808)
	var hits := [0]
	u2.upgrade_collected.connect(func(_up): hits[0] += 1)
	HitDetection.process_hits([b], [], [u2])
	_check(hits[0] == 1, "Bullet trifft Upgrade → collect 1×")

	# --- WeaponController liest Stats (Soldiers = echte Feuerkraft) ---
	var wc := WeaponController.new()
	world.add_child(wc)
	var p := Node2D.new()
	p.set_script(load("res://scripts/player/player.gd"))
	world.add_child(p)
	# p._ready braucht TouchInput etc. — im Headless testen wir nur die Werte-Funktionen:
	wc.setup(null)
	_check(wc._fire_rate() == GameConfig.FIRE_RATE, "WC ohne Stats → Config-Fallback")

	if fails == 0:
		print("PHASE5 TESTS: ALLE OK")
	else:
		print("PHASE5 TESTS: %d FEHLER" % fails)
	quit(1 if fails > 0 else 0)