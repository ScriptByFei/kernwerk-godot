class_name PlayerStats
extends Node
## Laufende Spieler-Werte (Phase 5): Damage, Fire Rate, Soldier-Count.
## WeaponController liest diese Werte; Upgrades ändern sie hier (single source of truth).

signal stats_changed
signal soldier_count_changed(count: int)

var damage := GameConfig.DAMAGE
var fire_rate := GameConfig.FIRE_RATE
var soldiers := 1  # 1 = nur Basis-Soldat; jedes Upgrade +1 echte Feuerkraft

func apply_upgrade(type: String) -> void:
	match type:
		"damage":
			damage += WaveData.DMG_UPGRADE
		"firerate":
			fire_rate = fire_rate + WaveData.RATE_UPGRADE
		"soldier":
			soldiers += 1
			soldier_count_changed.emit(soldiers)
		_:
			return  # unbekannter Typ: kein Signal, kein Fake-Upgrade
	stats_changed.emit()

func reset() -> void:
	damage = GameConfig.DAMAGE
	fire_rate = GameConfig.FIRE_RATE
	soldiers = 1
	stats_changed.emit()
	soldier_count_changed.emit(soldiers)