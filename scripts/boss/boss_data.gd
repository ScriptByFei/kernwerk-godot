class_name BossData
extends RefCounted
## Zentraler Balancing-Punkt für den Boss-Kampf.

const BOSS_HP := 500
const BOSS_SPEED := 90.0
const HOVER_Y_RATIO := 0.22

const PULSE_INTERVAL_P1 := 4.2
const PULSE_INTERVAL_P2 := 2.0
const PULSE_TELEGRAPH := 1.2
const PULSE_DAMAGE := 15

const SUMMON_INTERVAL_P1 := 7.0
const SUMMON_INTERVAL_P2 := 5.0
const SUMMON_COUNT_P1 := 2
const SUMMON_COUNT_P2 := 3
const SUMMON_TYPES_P1 := [EnemyArchetypeData.GRUNT]
const SUMMON_TYPES_P2 := [EnemyArchetypeData.GRUNT, EnemyArchetypeData.RUNNER]

const LANE_SWITCH_INTERVAL_P1 := 4.0
const LANE_SWITCH_INTERVAL_P2 := 2.4
const LANE_SWITCH_DURATION := 0.5
const PHASE2_THRESHOLD := 0.5

## Boss-HP skaliert mit der DPS-Ratio des Spielers (aktuelle DPS / Basis-DPS).
## Wurzel-Kurve dämpft die Explosion: 2× DPS → 1.41× HP, 4× → 2×, 9× → 3×.
## Floor = BOSS_HP: auch mit 0 Upgrades nie schwächer als die Basis.
static func scaled_hp(dps_ratio: float) -> int:
	return maxi(BOSS_HP, int(BOSS_HP * sqrt(maxf(dps_ratio, 1.0))))
