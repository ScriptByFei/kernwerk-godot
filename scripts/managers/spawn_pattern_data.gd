class_name SpawnPatternData
extends RefCounted
## Faire Drei-Lane-Reihen. Jede Reihe lässt mindestens eine Lane ohne Gegner.

const EMPTY := ""
const UPGRADE := "upgrade"

const PATTERNS := [
	{
		"id": "opening_grunt",
		"min_wave": 1,
		"weight": 5.0,
		"slots": [EnemyArchetypeData.GRUNT, EMPTY, EMPTY],
	},
	{
		"id": "opening_choice",
		"min_wave": 1,
		"weight": 3.0,
		"slots": [EnemyArchetypeData.GRUNT, UPGRADE, EMPTY],
	},
	{
		"id": "runner_intro",
		"min_wave": 2,
		"weight": 3.0,
		"slots": [EnemyArchetypeData.RUNNER, EMPTY, EMPTY],
	},
	{
		"id": "split_grunts",
		"min_wave": 2,
		"weight": 2.0,
		"slots": [EnemyArchetypeData.GRUNT, EnemyArchetypeData.GRUNT, EMPTY],
	},
	{
		"id": "runner_choice",
		"min_wave": 2,
		"weight": 2.5,
		"slots": [EnemyArchetypeData.RUNNER, UPGRADE, EMPTY],
	},
	{
		"id": "tank_intro",
		"min_wave": 3,
		"weight": 3.0,
		"slots": [EnemyArchetypeData.TANK, EMPTY, EMPTY],
	},
	{
		"id": "mixed_gap",
		"min_wave": 3,
		"weight": 2.0,
		"slots": [EnemyArchetypeData.RUNNER, EnemyArchetypeData.TANK, EMPTY],
	},
	{
		"id": "tank_choice",
		"min_wave": 3,
		"weight": 2.5,
		"slots": [EnemyArchetypeData.TANK, UPGRADE, EMPTY],
	},
	{
		"id": "drone_intro",
		"min_wave": 3,
		"weight": 2.5,
		"slots": [EnemyArchetypeData.DRONE, EMPTY, EMPTY],
	},
	{
		"id": "drone_mixed",
		"min_wave": 4,
		"weight": 2.0,
		"slots": [EnemyArchetypeData.DRONE, EnemyArchetypeData.GRUNT, EMPTY],
	},
	{
		"id": "pressure_upgrade",
		"min_wave": 4,
		"weight": 2.0,
		"slots": [EnemyArchetypeData.GRUNT, EnemyArchetypeData.TANK, UPGRADE],
	},
	{
		"id": "late_mixed",
		"min_wave": 4,
		"weight": 2.0,
		"slots": [EnemyArchetypeData.RUNNER, EnemyArchetypeData.GRUNT, EMPTY],
	},
]

static func patterns_for_wave(wave: int) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for pattern in PATTERNS:
		if int(pattern["min_wave"]) <= wave:
			available.append(pattern.duplicate(true))
	return available

static func enemy_count(slots: Array) -> int:
	var count := 0
	for token in slots:
		if EnemyArchetypeData.is_regular_type(str(token)):
			count += 1
	return count

static func has_upgrade(slots: Array) -> bool:
	return UPGRADE in slots

static func is_fair(pattern: Dictionary) -> bool:
	if not pattern.has("slots"):
		return false
	var slots: Array = pattern["slots"]
	return slots.size() == GameConfig.LANE_COUNT and enemy_count(slots) <= 2
