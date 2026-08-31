extends SceneTree
## Integrationsregressionen für den Stabilisierungsschritt vor Phase 7.

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

	# GameManager ist die einzige HP-Quelle; PlayerHealth spiegelt nur Darstellung.
	var gm := GameManager.new()
	world.add_child(gm)
	var ph := PlayerHealth.new()
	world.add_child(ph)
	ph.setup(gm)
	_check(ph.take_hit(30), "erster Treffer wird angenommen")
	_check(gm.player_hp == 70 and ph.hp == 70, "Manager und HP-Anzeige sind synchron")
	_check(not ph.take_hit(30) and gm.player_hp == 70, "i-Frames blockieren direkten Folgetreffer")
	gm.clear_iframes()
	gm.player_hp = 10
	_check(ph.take_hit(20), "lethaler Treffer wird angenommen")
	_check(gm.state == GameManager.State.GAME_OVER and ph._game_over, "Game Over ist in Manager und Anzeige konsistent")

	# Der vollständige SpawnManager-Signalweg muss Kill und Score verbuchen.
	gm.reset()
	var spawner := SpawnManager.new()
	world.add_child(spawner)
	spawner.setup(world)
	spawner.enemy_killed_from_world.connect(func(_enemy): gm.add_kill())
	var spawned := [null]
	spawner.enemy_spawned.connect(func(new_enemy): spawned[0] = new_enemy)
	spawner._spawn_enemy()
	var scored_enemy: Enemy = spawned[0]
	_check(scored_enemy != null, "Spawner liefert Gegner an die Welt")
	if scored_enemy:
		scored_enemy.take_damage(9999)
	_check(gm.kills == 1 and gm.score == 10, "Enemy-Kill läuft über SpawnManager zu Score/Kills")

	# Ein Projektil darf nicht gleichzeitig Enemy und Upgrade konsumieren.
	var enemy := Enemy.new()
	enemy.configure(1, 50, 0.0)
	world.add_child(enemy)
	enemy.position = Vector2(540, 800)
	var upgrade := UpgradeObject.new()
	upgrade.configure_upgrade(1, "damage", 0.0)
	world.add_child(upgrade)
	upgrade.position = Vector2(540, 800)
	var collected := [0]
	upgrade.upgrade_collected.connect(func(_u): collected[0] += 1)
	var bullet := Bullet.new()
	world.add_child(bullet)
	bullet.global_position = Vector2(540, 800)
	HitDetection.process_hits([bullet], [enemy], [upgrade])
	_check(enemy.current_hp == 40, "Projektil trifft zuerst den Gegner")
	_check(collected[0] == 0, "dasselbe Projektil sammelt nicht zusätzlich das Upgrade")

	# Balancing-Texte müssen die zentralen Werte zeigen.
	_check(upgrade._display_text() == "+%d DMG" % WaveData.DMG_UPGRADE, "Damage-Text folgt WaveData")
	upgrade.upgrade_type = "firerate"
	_check(upgrade._display_text() == "+%.1f RATE" % WaveData.RATE_UPGRADE, "Rate-Text zeigt lineares +0.1")

	# Feedback entfernt nur sein temporäres Label, nicht das Feedback-System selbst.
	var feedback := UpgradeFeedback.new()
	world.add_child(feedback)
	feedback.popup("TEST", Vector2(200, 200))
	await create_timer(1.0).timeout
	_check(is_instance_valid(feedback) and not feedback.is_queued_for_deletion(), "Feedback-System überlebt ein Popup")
	_check(feedback.get_child_count() == 0, "Popup-Label wird nach Tween entfernt")

	# Viewport-Polling darf den Lane-Tween nicht auf das Ziel teleportieren.
	var player := Player.new()
	var touch := TouchInput.new()
	touch.name = "TouchInput"
	player.add_child(touch)
	var weapon := WeaponController.new()
	weapon.name = "WeaponController"
	player.add_child(weapon)
	world.add_child(player)
	await process_frame
	player.move_to_lane(2)
	player._process(0.0)
	_check(not is_equal_approx(player.position.x, GameConfig.lane_x(2, player.get_viewport_rect().size.x)), "Lane-Wechsel bleibt ein Tween statt Snap")

	if fails == 0:
		print("STABILIZATION TESTS: ALLE OK")
	else:
		print("STABILIZATION TESTS: %d FEHLER" % fails)
	world.queue_free()
	await process_frame
	quit(1 if fails > 0 else 0)
