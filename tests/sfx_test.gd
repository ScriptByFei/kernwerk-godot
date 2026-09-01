extends SceneTree

const SfxScript = preload("res://scripts/audio/sfx.gd")

var fails := 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ✓ " + message)
	else:
		fails += 1
		print("  ✗ " + message)

func _count_sound_players(sfx: Node, sound_name: String) -> int:
	var count := 0
	for child in sfx.get_children():
		if child.name == "Sfx_%s" % sound_name:
			count += 1
	return count

func _init() -> void:
	var sfx := SfxScript.new()
	get_root().add_child(sfx)
	await process_frame

	sfx.play("kill")
	_check(_count_sound_players(sfx, "kill") == 0, "Vor Unlock wird kein Player erzeugt")
	sfx.unlock()
	await process_frame
	_check(_count_sound_players(sfx, "kill") == 1, "Gepufferter Sound wird nach Unlock gespielt")

	var pending := SfxScript.new()
	get_root().add_child(pending)
	await process_frame
	pending.play("upgrade")
	pending.unlock()
	await process_frame
	_check(_count_sound_players(pending, "upgrade") == 1, "Pending spielt genau einmal")

	sfx.play("shoot")
	await process_frame
	var shoot_player := sfx.get_node_or_null("Sfx_shoot") as AudioStreamPlayer
	_check(shoot_player != null and shoot_player.stream != null, "Shoot erzeugt Player mit Stream")
	_check(shoot_player != null and is_equal_approx(shoot_player.volume_db, -18.0), "Shoot nutzt konfigurierte Lautstärke")
	sfx.play("gibtsnicht")
	_check(_count_sound_players(sfx, "gibtsnicht") == 0, "Unbekannter Sound wird ignoriert")

	await create_timer(1.7).timeout
	_check(_count_sound_players(sfx, "kill") == 0 and _count_sound_players(sfx, "shoot") == 0 and _count_sound_players(pending, "upgrade") == 0, "Fertige Player werden freigegeben")

	if fails == 0:
		print("SFX TESTS: ALLE OK")
	else:
		print("SFX TESTS: %d FEHLER" % fails)
	sfx.queue_free()
	pending.queue_free()
	await process_frame
	quit(1 if fails > 0 else 0)
