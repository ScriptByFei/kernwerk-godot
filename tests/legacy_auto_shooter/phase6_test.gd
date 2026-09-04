extends SceneTree
## Phase-6-Tests: WaveData + WaveManager-Ablauf + Balancing-Konstanten.
## Aufruf: godot4 --headless -s tests/phase6_test.gd

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

	# --- WaveData Struktur ---
	_check(WaveData.wave_count() == 6, "6 Wellen definiert")
	_check(WaveData.total_duration() <= 120.0,
			"Level-Dauer %.0fs im 60-125s-Fenster (Boss-Welle kann drüber liegen)" % WaveData.total_duration())
	var w1 := WaveData.get_wave(0)
	var w4 := WaveData.get_wave(3)
	var w6 := WaveData.get_wave(5)
	_check(not w1.is_empty() and bool(w6.get("boss", false)), "letzte Welle hat Boss-Flag")
	_check(float(WaveData.get_wave(4)["hp_factor"]) > float(w1["hp_factor"]), "HP-Faktor steigt über Wellen")
	_check(float(w4["spawn_interval"]) < float(w1["spawn_interval"]), "Spawns werden dichter")
	_check(WaveData.get_wave(99).is_empty(), "Index außerhalb → leer")

	# --- WaveManager: Ablauf 1→…→6→LevelComplete---
	var wm := WaveManager.new()
	world.add_child(wm)
	var sp := SpawnManager.new()
	world.add_child(sp)
	sp.setup(world)
	wm.attach(world, sp)

	var started := [0]
	var complete_fired := [0]
	var boss_fired := [0]
	wm.wave_started.connect(func(_i): started[0] += 1)
	wm.level_completed.connect(func(): complete_fired[0] += 1)
	wm.boss_appeared.connect(func(): boss_fired[0] += 1)

	wm.start_level()
	_check(wm.current_wave == 1, "Start → Welle 1")
	_check(sp.spawn_interval == 2.7 and sp.hp_factor == 1.0, "Wave-1-Params am SpawnManager")

	# Alle Wellen durchspringen (jeweils Dauer überschreiten)
	for i in 10:
		wm._physics_process(25.0)
	_check(wm.current_wave == 6, "6 Wellen erreicht")
	_check(boss_fired[0] == 1, "Boss bei Wave 6 (boss_appeared 1×)")
	_check(absf(sp.hp_factor - 2.2) < 0.01, "Boss-Welle: hp_factor 2.2 am Spawner")

	# Zeit allein beendet die Boss-Welle NICHT.
	wm._physics_process(30.0)
	_check(not wm.is_level_done and complete_fired[0] == 0, "Boss-Welle wartet auf Boss-Kill")
	var boss: Enemy = null
	for c in world.get_children():
		if c is Enemy and c.is_boss:
			boss = c
	_check(boss != null, "Boss-Instanz vorhanden")
	if boss:
		boss.take_damage(BossData.BOSS_HP)
	_check(wm.is_level_done and complete_fired[0] == 1, "Boss-Kill beendet Level genau 1×")

	# --- SpawnParams wirken: hp_factor skaliert Gegner-HP ---
	sp.hp_factor = 1.8
	sp._spawn_enemy()
	var spawned_enemy: Enemy = null
	for c in world.get_children():
		if c is Enemy:
			spawned_enemy = c
	_check(spawned_enemy != null and spawned_enemy.max_hp == int(50.0 * 1.8), "hp_factor: Enemy-HP = 50×1.8=90")

	# --- Balancing-Konstanten konsistent ---
	_check(WaveData.DMG_UPGRADE == 15, "Damage-Upgrade +15 (Balancing-Pass)")
	_check(WaveData.RATE_UPGRADE == 0.1, "Rate-Upgrade +0.1 (Balancing)")
	_check(BossData.BOSS_HP == 500, "Boss-HP 500")

	# --- UpgradeObject + WaveData-Typen deckungsgleich ---
	var u := UpgradeObject.new()
	world.add_child(u)
	u.configure_upgrade(1, "damage", 150.0)
	u.collect()
	# Damage-Effekt über PlayerStats:
	var s := PlayerStats.new()
	world.add_child(s)
	var d0 := s.damage
	s.apply_upgrade("damage")
	_check(s.damage == d0 + WaveData.DMG_UPGRADE, "PlayerStats nutzt WaveData.DMG_UPGRADE")

	if fails == 0:
		print("PHASE6 TESTS: ALLE OK")
	else:
		print("PHASE6 TESTS: %d FEHLER" % fails)
	quit(1 if fails > 0 else 0)
