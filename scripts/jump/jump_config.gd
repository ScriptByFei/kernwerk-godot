class_name JumpConfig
extends RefCounted

const GRAVITY := 2300.0
const BASE_BOUNCE_SPEED := 1580.0
const OVERLOAD_BOUNCE_SPEED := 1740.0
const MAX_BOUNCE_SPEED := 1800.0
const MAX_HORIZONTAL_SPEED := 1100.0
const HORIZONTAL_ACCELERATION := 9000.0
const HORIZONTAL_DRAG := 10000.0
const HORIZONTAL_TARGET_DISTANCE := 90.0

const JUMPER_SIZE := Vector2(58.0, 58.0)
const PLATFORM_SIZE := Vector2(240.0, 34.0)
const CAMERA_LEAD := 260.0
const CAMERA_START := Vector2(540.0, 960.0)
const PLATFORM_LAYOUT := [
	Vector2(540.0, 1760.0),
	Vector2(320.0, 1460.0),
	Vector2(620.0, 1160.0),
	Vector2(350.0, 860.0),
	Vector2(650.0, 560.0),
	Vector2(380.0, 260.0),
	Vector2(650.0, -40.0),
]
