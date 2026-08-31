class_name GameConfig
## Zentrale Spielkonstanten — single source of truth, keine Magie in Szenen.

const LANE_COUNT := 3
const LANE_X := [270.0, 540.0, 810.0]  # Referenzauflösung 1080x1920
const PLAYER_Y := 1650.0

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