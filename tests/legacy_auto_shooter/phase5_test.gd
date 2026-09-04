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
	await process_frame

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
	_check(absf(s.fire_rate - (GameConfig.FIRE_RATE + WaveData.RATE_UPGRADE)) < 0.01, "fire_rate +0.1")
	s.apply_upgrade("firerate")
	_check(absf(s.fire_rate - (GameConfig.FIRE_RATE + 2*WaveData.RATE_UPGRADE)) < 0.01, "FireRate kumulativ (+0.2)")

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
	# Ohne Player testen wir nur die nil-sicheren Werte-Funktionen:
	wc.setup(null)
	_check(wc._fire_rate() == GameConfig.FIRE_RATE, "WC ohne Stats → Config-Fallback")

	# --- WeaponController: Soldaten-Salven GEBÜNDELT auf Spieler-Lane (Playtest-Fix) ---
	var game_scene := load("res://scenes/game/game.tscn") as PackedScene
	var game := game_scene.instantiate() as Node2D
	get_root().add_child(game)
	await process_frame
	var player := game.get_node("Player") as Player
	game.player_stats.soldiers = 3
	player.weapon.stats = game.player_stats
	var bullets_before: Array = []
	for child in game.get_children():
		if child is Bullet:
			bullets_before.append(child)
	player.weapon._fire()
	var fired_count := 0
	var all_bundled := true
	for child in game.get_children():
		if child is Bullet and child not in bullets_before:  # nur NEUE Salve zählen
			fired_count += 1
			if child.global_position != player.global_position + Vector2(0, -80):  # origin = Spieler + (0,-80)
				all_bundled = false
	_check(fired_count == 3, "3 Soldaten → 3 Projektile pro Schuss")
	_check(all_bundled, "Salve GEBÜNDELT auf Spieler-Lane (kein ±90px-Offset mehr)")
	game.queue_free()
	await process_frame

	if fails == 0:
		print("PHASE5 TESTS: ALLE OK")
	else:
		print("PHASE5 TESTS: %d FEHLER" % fails)
	quit(1 if fails > 0 else 0)
