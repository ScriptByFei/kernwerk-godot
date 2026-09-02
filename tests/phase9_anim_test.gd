extends SceneTree

var fails := 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ✓ " + message)
	else:
		fails += 1
		print("  ✗ " + message)

func _init() -> void:
	var world := Node2D.new()
	get_root().add_child(world)
	var grunt := Enemy.new()
	grunt.configure(1, 50, 0.0)
	world.add_child(grunt)
	await process_frame
	var grunt_sprite := grunt.get_node_or_null("Sprite") as AnimatedSprite2D
	_check(grunt_sprite != null and grunt_sprite.sprite_frames.get_frame_count("idle") == 2 and grunt_sprite.is_playing(), "Grunt nutzt spielende Idle-Animation")
	grunt._hit_feedback()
	_check(grunt._wobble_tween != null and grunt._wobble_tween.is_valid(), "Hit-Feedback = Wackeln (kein Flash)")

	var boss := Enemy.new()
	boss.configure(1, 600, 0.0, true, EnemyArchetypeData.BOSS)
	world.add_child(boss)
	await process_frame
	var boss_sprite := boss.get_node_or_null("Sprite") as AnimatedSprite2D
	_check(boss_sprite != null and boss_sprite.sprite_frames.get_frame_count("pulse") == 4, "Boss nutzt vier Pulse-Frames")

	var fallback := Enemy.new()
	fallback.animation_sheet_path = "res://missing_sheet.png"
	fallback.configure(1, 50, 0.0)
	world.add_child(fallback)
	await process_frame
	_check(fallback.get_node_or_null("Sprite") is Sprite2D, "Fehlendes Sheet nutzt statischen Fallback")

	var player := Player.new()
	var touch := TouchInput.new()
	touch.name = "TouchInput"
	var weapon := WeaponController.new()
	weapon.name = "WeaponController"
	player.add_child(touch)
	player.add_child(weapon)
	world.add_child(player)
	await process_frame
	var player_sprite := player.get_node_or_null("Soldier") as AnimatedSprite2D
	_check(player_sprite != null and player_sprite.sprite_frames.get_frame_count("idle") == 2 and player_sprite.sprite_frames.get_frame_count("shoot") == 1, "Player besitzt Idle- und Shoot-Frames")

	world.queue_free()
	await process_frame
	print("PHASE 9 ANIMATION TESTS: " + ("ALLE OK" if fails == 0 else "%d FEHLER" % fails))
	quit(1 if fails > 0 else 0)
