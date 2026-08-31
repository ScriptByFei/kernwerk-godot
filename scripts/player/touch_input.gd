class_name TouchInput
extends Node
## Swipe + Tap-Zonen Erkennung (Touch). Emittiert Signale an Owner (Player).
## Architektur: austauschbar — Swipe-only oder Tap-only später per Flag.

signal swiped(direction: int)  # -1 links, +1 rechts
signal tapped_lane(lane: int)  # 0/1/2

var _touch_start := Vector2.ZERO
var _touch_active := false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_touch_active = true
		elif _touch_active:
			_touch_active = false
			_handle_release(event.position)
	elif event is InputEventScreenDrag:
		# Sofort-Swipe ab Schwelle: responsiver als Warten auf Loslassen
		if _touch_active:
			var drag: Vector2 = event.position - _touch_start
			if absf(drag.x) > _drag_threshold_px():
				swiped.emit(1 if drag.x > 0.0 else -1)
				_touch_active = false  # Ein Swipe pro Geste

func _handle_release(end_pos: Vector2) -> void:
	var drag: Vector2 = end_pos - _touch_start
	if absf(drag.x) > _drag_threshold_px() or absf(drag.y) > _drag_threshold_px():
		return  # War ein Swipe — horizontal ggf. schon per Drag gefeuert
	# Kurzer Tap → Tap-Zone: Drittel
	var vp_x := get_viewport().get_visible_rect().size.x
	var lane := int(end_pos.x / (vp_x / 3.0))
	tapped_lane.emit(clampi(lane, 0, GameConfig.LANE_COUNT - 1))

func _drag_threshold_px() -> float:
	var px_per_ref := get_viewport().get_visible_rect().size.x / 1080.0
	return GameConfig.SWIPE_MIN_DRAG_PX * px_per_ref