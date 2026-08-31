class_name UpgradeFeedback
extends Node2D
## Zeigt aufgesammelte Upgrades als sanft aufsteigenden Text über dem Spieler
## ("DAMAGE +15", "FIRE RATE +0.1", "+1 SOLDIER") — kein HUD-Permanenttext.

func popup(text: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55, 0.95))
	label.position = at + Vector2(-90, -120)
	label.size = Vector2(180, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	var t := create_tween().set_parallel()
	# sanft nach oben schweben + ausblenden
	t.tween_property(label, "position:y", label.position.y - 120.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(label.queue_free)

func popup_for(upgrade: UpgradeObject, player: Player) -> void:
	var text := ""
	match upgrade.upgrade_type:
		"damage":
			text = "DAMAGE +%d" % WaveData.DMG_UPGRADE
		"firerate":
			text = "FIRE RATE +%.1f" % WaveData.RATE_UPGRADE
		"soldier":
			text = "+1 SOLDIER"
	var at := Vector2(player.global_position.x, player.global_position.y - 140.0)
	popup(text, at)
