class_name JumpConfig
extends RefCounted

const GRAVITY := 2300.0
const BASE_BOUNCE_SPEED := 1580.0
const OVERLOAD_BOUNCE_SPEED := 1740.0
const MAX_BOUNCE_SPEED := 1800.0
const MAX_HORIZONTAL_SPEED := 1100.0
const HORIZONTAL_ACCELERATION := 10500.0
const HORIZONTAL_DRAG := 12000.0
const HORIZONTAL_TARGET_DISTANCE := 76.0
const HORIZONTAL_BRAKING := 15000.0
const HORIZONTAL_REVERSAL := 18000.0
const HORIZONTAL_TARGET_DEADZONE := 1.5
# Constant authority through the whole arc: no loss of late descent control.
# Braking caps target speed to stopping distance, without snapping position.

enum LandingQuality { NORMAL, RESONANCE, PERFECT }
# Ratios use FULL platform width, not half-width. Boundaries are inclusive.
const PERFECT_CENTER_RATIO := 0.08
const RESONANCE_CENTER_RATIO := 0.22
const LANDING_BOUNCE_MULTIPLIERS := [1.0, 1.025, 1.05]
const LANDING_BONUSES_ENABLED := false
const LANDING_SCORE_BONUSES := [0, 1, 3]
const LANDING_EFFECT_DURATIONS := [0.12, 0.18, 0.22]
const LANDING_EFFECT_STRENGTHS := [0.12, 0.30, 0.46]
const LANDING_RING_RADII := [12.0, 32.0, 42.0]
const LANDING_RING_EXPANSION := 16.0
const LANDING_RING_FLATTEN := 0.25
const LANDING_RING_SEGMENTS := 24
const LANDING_RING_WIDTH := 2.0
const LANDING_GLOW_RADIUS := 40.0
const LANDING_GLOW_COLOR := Color(1.0, 0.54, 0.16)
const LANDING_CORE_LIGHT_COLOR := Color(1.0, 0.73, 0.35)
const LANDING_CORE_LIGHT_RADIUS := 13.0
const LANDING_CORE_LIGHT_GAIN := 0.35
const REACTOR_CORE_POSITION := Vector2(-3.0, -52.0)
const REACTOR_VISUAL_POSITION := Vector2(-72.0, -109.0)
const REACTOR_VISUAL_SCALE := Vector2(1.5, 1.5)
const LAND_ANIMATION_SPEED := 3.0
const JUMP_ANIMATION_SPEED := 1.0
const PLATFORM_BODY_COLOR := Color("233b46")
const PLATFORM_OUTLINE_COLOR := Color("10212a")
const PLATFORM_SHADOW_COLOR := Color("152630")
const PLATFORM_ENDCAP_COLOR := Color("314d58")
const PLATFORM_EDGE_COLOR := Color("69858d")
const PLATFORM_EDGE_HEIGHT := 4.0
const PLATFORM_SHADOW_HEIGHT := 6.0
const PLATFORM_ENDCAP_WIDTH := 12.0
const PLATFORM_OUTLINE_WIDTH := 2.0
const PLATFORM_CENTER_INSET_SIZE := Vector2(36.0, 12.0)
const PLATFORM_CENTER_INSET_COLOR := Color("10252d")
const PLATFORM_CENTER_MARK_SIZE := Vector2(24.0, 4.0)
const PLATFORM_CENTER_STEM_SIZE := Vector2(4.0, 8.0)
const PLATFORM_CENTER_MARK_COLOR := Color("4b9299")
const PLATFORM_IMPACT_DEPTH := [0.6, 1.3, 2.0]
const PLATFORM_IMPACT_COLORS := [Color("a0b8b8"), Color("72b9bc"), Color("ffd08a")]
const PLATFORM_IMPACT_ALPHAS := [0.45, 0.60, 0.75]
const PLATFORM_IMPACT_WIDTHS := [30.0, 60.0, 72.0]
const PERFECT_DASH_SIZE := Vector2(12.0, 4.0)
const PERFECT_DASH_TRAVEL := Vector2(18.0, 48.0)
const PERFECT_DASH_DURATION := 0.16
const PERFECT_DASH_COLOR := Color("e7b779")
const PERFECT_DASH_ALPHA := 0.65
const CAMERA_ASCENT_HEADROOM := 28.0
const CAMERA_HEADROOM_RESPONSE := 8.0
const CAMERA_APEX_SPEED := 180.0
const DEATH_DIM_DURATION := 0.18
const DEATH_DIM_COLOR := Color(0.20, 0.24, 0.26)
const LANDING_AUDIO_DB := [-22.0, -20.0, -18.0]
const DEATH_AUDIO_DB := -20.0

static func classify_landing(center_distance: float, full_width: float) -> LandingQuality:
	if full_width <= 0.0:
		return LandingQuality.NORMAL
	var distance := absf(center_distance)
	if distance <= full_width * PERFECT_CENTER_RATIO:
		return LandingQuality.PERFECT
	if distance <= full_width * RESONANCE_CENTER_RATIO:
		return LandingQuality.RESONANCE
	return LandingQuality.NORMAL

const JUMPER_SIZE := Vector2(58.0, 58.0)
const PLATFORM_SIZE := Vector2(240.0, 34.0)
const PLATFORM_VERTICAL_GAP := 300.0
const PLATFORM_LOOKAHEAD := 1200.0
const PLATFORM_CLEANUP_MARGIN := 1200.0
const MAX_ACTIVE_PLATFORMS := 16
const PLATFORM_RUN_SEED := 13071337
const PLATFORM_MIN_CENTER_X := PLATFORM_SIZE.x * 0.5
const PLATFORM_MAX_CENTER_X := 1080.0 - PLATFORM_SIZE.x * 0.5
const PLATFORM_MAX_HORIZONTAL_STEP := 280.0
const CAMERA_LEAD := 260.0
const CAMERA_START := Vector2(540.0, 960.0)

# Gameplay-Loop
const SCORE_PER_UNIT := 10.0
const FALL_DEATH_MARGIN := 600.0
const RESTART_DELAY := 0.28
const DIFFICULTY_STEP_SCORE := 100.0
const MAX_DIFFICULTY := 5
const DIFFICULTY_VERTICAL_BONUS := 10.0
const DIFFICULTY_HORIZONTAL_BONUS := 20.0

const PLATFORM_LAYOUT: Array[Vector2] = [
	Vector2(540.0, 1760.0),
	Vector2(320.0, 1460.0),
	Vector2(620.0, 1160.0),
	Vector2(350.0, 860.0),
	Vector2(650.0, 560.0),
	Vector2(380.0, 260.0),
	Vector2(650.0, -40.0),
]

## Start transition choreography (seconds). Deterministic on process time via
## Tween, independent of refresh rate (30/60/120 FPS).
const START_TOTAL := 0.92
const START_PRESS_FEEDBACK := 0.12
const START_REVEAL_BEGIN := 0.28
const START_SECONDARY_BEGIN := 0.18
const START_SECONDARY_DURATION := 0.32
const START_TITLE_DURATION := 0.42
const START_CAMERA_DURATION := 0.60
const START_CAMERA_INTRO_OFFSET := 32.0
const START_BOUNCE_AT := START_TOTAL
## Subtle idle breathing for the menu, driven by Tween only.
const START_IDLE_PERIOD := 3.2
