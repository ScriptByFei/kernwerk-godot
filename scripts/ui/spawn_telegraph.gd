class_name SpawnTelegraph
extends Node2D
## Kurze, farbcodierte Vorwarnung am oberen Spielfeldrand. Keine Lane-Linien.

var slots: Array = []
var _last_viewport_size := Vector2.ZERO

func configure(pattern_slots: Array) -> void:
	slots = pattern_slots.duplicate()
	queue_redraw()

func _process(_delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size != _last_viewport_size:
		_last_viewport_size = viewport_size
		queue_redraw()

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	var marker_y := maxf(GameConfig.UI_SAFE_TOP + 82.0, viewport_size.y * 0.09)
	for lane in mini(slots.size(), GameConfig.LANE_COUNT):
		var token := str(slots[lane])
		if token == SpawnPatternData.EMPTY:
			continue
		var center := Vector2(GameConfig.lane_x(lane, viewport_size.x), marker_y)
		var color: Color = Color(0.2, 0.9, 0.45) if token == SpawnPatternData.UPGRADE else EnemyArchetypeData.get_definition(token)["color"]
		draw_circle(center, 30.0, Color(color, 0.20))
		draw_arc(center, 30.0, 0.0, TAU, 28, Color(color, 0.95), 5.0, true)
		draw_polyline(PackedVector2Array([
			center + Vector2(-12.0, -5.0),
			center + Vector2(0.0, 10.0),
			center + Vector2(12.0, -5.0),
		]), Color(color, 0.95), 5.0, true)
