class_name UpgradeObject
extends LaneObject
## Grünes Upgrade-Träger-Objekt: zerstörbar, beim Zerstören wirksamwerden.
## Text auf dem Objekt zeigt den tatsächlichen Bonus aus WaveData.

signal upgrade_collected(upgrade: UpgradeObject)

var upgrade_type := "damage"    # "damage" | "firerate" | "soldier"
# Treffer-Erkennung großzügiger: Hitbox ±100 px (X) / ±90 px (Y) — Upgrades fühlen
# sich so deutlich einsammelbarer an, ohne dass der Spieler pixelgenau zielen muss.
const HITBOX_HALF_W := 100.0
const HITBOX_HALF_H := 90.0
const UPGRADE_GREEN := Color(0.2, 0.8, 0.4)
const GLOW_GREEN := Color(0.2, 0.8, 0.4, 0.35)

func configure_upgrade(p_lane: int, p_type: String, speed: float) -> void:
	setup_lane(p_lane)
	upgrade_type = p_type
	move_speed = speed
	add_to_group("upgrades")  # HitDetection sammelt genau diese Gruppe
	_build_visual()

func _build_visual() -> void:
	# Das halbtransparente Außenquadrat bleibt als feiner Glow um den unveränderten Träger sichtbar.
	var glow := Polygon2D.new()
	glow.color = GLOW_GREEN
	glow.polygon = PackedVector2Array([Vector2(-62, -62), Vector2(62, -62), Vector2(62, 62), Vector2(-62, 62)])
	add_child(glow)
	var body := Polygon2D.new()
	body.color = UPGRADE_GREEN
	body.polygon = PackedVector2Array([Vector2(-55, -55), Vector2(55, -55), Vector2(55, 55), Vector2(-55, 55)])
	add_child(body)
	var label := Label.new()
	label.text = _display_text()
	label.position = Vector2(-70, -20)
	label.size = Vector2(140, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	label.add_theme_font_size_override("font_size", 24)
	add_child(label)

func _display_text() -> String:
	match upgrade_type:
		"damage":
			return "+%d DMG" % WaveData.DMG_UPGRADE
		"firerate":
			return "+%.1f RATE" % WaveData.RATE_UPGRADE
		"soldier":
			return "+1 SOLDIER"
	return "?"

var _collected := false  # Doppel-collect-Schutz

func collect() -> void:
	if _collected:
		return
	_collected = true
	# Sanftes Einlösen: kurzes Aufleuchten + Schrumpfen
	set_physics_process(false)
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale", Vector2(1.4, 1.4), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.chain().tween_callback(queue_free)
	upgrade_collected.emit(self)
