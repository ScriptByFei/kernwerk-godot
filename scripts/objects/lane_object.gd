class_name LaneObject
extends Node2D
## Gemeinsame Basis für alles, was in einer Lane von oben kommt:
## Enemy, Upgrade, Obstacle, Gate, Boss. Bewegung nach unten + Lane-Zugehörigkeit.
## Unterklassen setzen Typ-Verhalten auf (speed, hp, Aussehen, Effekt beim Erreichen des Spielers).

signal reached_bottom(obj: LaneObject)

var lane := 1
var move_speed := 150.0  # design-px/s

func _ready() -> void:
	add_to_group("lane_objects")
	set_physics_process(true)

func setup_lane(p_lane: int) -> void:
	lane = clampi(p_lane, 0, GameConfig.LANE_COUNT - 1)

func _physics_process(delta: float) -> void:
	position.y += move_speed * delta
	if not _despawned and global_position.y >= _reach_y():
		_despawned = true  # einmalig — queue_free braucht einen Frame, sonst Multi-Fire
		reached_bottom.emit(self)
		queue_free()

var _despawned := false

func lane_x_now() -> float:
	return GameConfig.lane_x(lane, get_viewport_rect().size.x)

func _reach_y() -> float:
	return get_viewport_rect().size.y + 80.0
