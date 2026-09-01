class_name EnemyArchetypeData
extends RefCounted
## Zentrale Lesbarkeit und Balance der Gegnerrollen.

const GRUNT := "grunt"
const RUNNER := "runner"
const TANK := "tank"
const BOSS := "boss"

const DEFINITIONS := {
	GRUNT: {
		"hp_multiplier": 1.0,
		"speed_multiplier": 1.0,
		"score_reward": 10,
		"color": Color(0.88, 0.24, 0.30),
	},
	RUNNER: {
		"hp_multiplier": 0.65,
		"speed_multiplier": 1.35,
		"score_reward": 15,
		"color": Color(1.0, 0.48, 0.14),
	},
	TANK: {
		"hp_multiplier": 2.0,
		"speed_multiplier": 0.72,
		"score_reward": 20,
		"color": Color(0.56, 0.18, 0.28),
	},
	BOSS: {
		"hp_multiplier": 1.0,
		"speed_multiplier": 1.0,
		"score_reward": 100,
		"color": Color(0.65, 0.15, 0.75),
	},
}

static func get_definition(enemy_type: String) -> Dictionary:
	return DEFINITIONS.get(enemy_type, DEFINITIONS[GRUNT])

static func is_regular_type(enemy_type: String) -> bool:
	return enemy_type in [GRUNT, RUNNER, TANK]
