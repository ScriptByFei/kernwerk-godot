class_name GameConfig
## Zentrale Spielkonstanten — single source of truth, keine Magie in Szenen.

const LANE_COUNT := 3
const LANE_SWITCH_TIME := 0.18  # Sekunden für weichen Lane-Wechsel
const SWIPE_MIN_DRAG_PX := 60.0  # Mindestdrag (Referenz-Px) für Swiperkennung

# Waffen-Startwerte (später per Upgrade veränderbar)
const DAMAGE := 10
const FIRE_RATE := 4.0  # Schüsse/Sekunde
const BULLET_SPEED := 1200.0
const BULLET_COUNT := 1
const SPREAD := 0.0

# Spieler
const MAX_HEALTH := 100

# --- Viewport-relative Layout-Helfer ---
# Lanes sitzen bei 25% / 50% / 75% der BREITE — funktioniert auf jedem Aspect Ratio
# (19.5:9 iPhone, 9:16 Android, 16:9 Desktop-Fenster). Kein fester 1080er-Wert mehr.
static func lane_x(lane: int, viewport_width: float) -> float:
	var clamped := clampi(lane, 0, LANE_COUNT - 1)
	return viewport_width * (0.5 + (float(clamped) - 1.0) * 0.25)

static func player_y(viewport_height: float) -> float:
	return viewport_height * 0.86