class_name WaveData
extends RefCounted
## Datengetriebene Wellen-Definition (Phase 6).
## Eine Welle = Dauer, Spawn-Intervall, Gegner-Stats-Faktoren, Upgrade-Chance, optional Boss.
## Als Dictionary: lesbar, mergebar, später aus JSON ladbar.

# Level = 6 Wellen à ~18-22s → ~120s total (Auftrag: 60-120s)
const WAVES := [
	{  # Wave 1: warm up
		"duration": 16.0,
		"spawn_interval": 1.8,
		"hp_factor": 1.0,
		"speed_factor": 1.0,
		"upgrade_chance": 0.20,
	},
	{  # Wave 2: mehr Gegner
		"duration": 18.0,
		"spawn_interval": 1.5,
		"hp_factor": 1.3,
		"speed_factor": 1.05,
		"upgrade_chance": 0.22,
	},
	{  # Wave 3: dichter + erste zähere
		"duration": 20.0,
		"spawn_interval": 1.3,
		"hp_factor": 1.6,
		"speed_factor": 1.1,
		"upgrade_chance": 0.30,
	},
	{  # Wave 4: stärker + schneller
		"duration": 20.0,
		"spawn_interval": 1.2,
		"hp_factor": 1.8,
		"speed_factor": 1.2,
		"upgrade_chance": 0.28,
	},
	{  # Wave 5: Finale vor Boss
		"duration": 22.0,
		"spawn_interval": 1.0,
		"hp_factor": 2.1,
		"speed_factor": 1.15,
		"upgrade_chance": 0.25,
	},
	{  # Wave 6: Boss
		"duration": 20.0,
		"spawn_interval": 2.2,
		"hp_factor": 2.2,
		"speed_factor": 1.1,
		"upgrade_chance": 0.35,
		"boss": true,
	},
]

# --- Balancing (Phase 5/6, zentral) ---
const DMG_UPGRADE := 15        # pro Damage-Upgrade (Gegner-HP wächst ~30%/Welle)
const RATE_MULTIPLIER := 1.5
const SOLDIER_OFFSET_X := 90.0
const BOSS_HP := 600
const BOSS_SPEED := 90.0

static func wave_count() -> int:
	return WAVES.size()

static func get_wave(index: int) -> Dictionary:
	if index < 0 or WAVES.size() <= index:
		return {}
	return WAVES[index]

static func total_duration() -> float:
	var t := 0.0
	for w in WAVES:
		t += float(w["duration"])
	return t