extends SceneTree
var B = preload("res://scripts/jump/shaft_background.gd").new()
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)
func _init() -> void:
	if not B.has_method("module_kind"):
		check(false, "module schedule missing")
	else:
		var kinds := {}
		for i in range(-2000, 2001):
			var kind: int = B.module_kind(i)
			kinds[kind] = true
			check(kind >= 0 and kind < 4, "four modules including negative indices")
			if kind == 0:
				check(B.module_kind(i + 1) != 0 and B.module_kind(i + 2) != 0, "door spacing including wrap")
			for camera in [-9999.0, 0.0, 5678.0]:
				var top: float = B.tile_world_y(0, camera, i)
				check(B.first_visible_tile(0, camera, top + 0.1) == i, "stable world index")
				check(B.module_kind(i) == kind, "camera cannot change identity")
		check(kinds.size() == 4, "all four kinds reached")
		var reached := {}
		for height in [0.0, 1800.0, 4500.0]:
			var camera: float = -height + 260.0
			var rect := Rect2(0, camera - 1170, 1080, 2340)
			check(B.opacity_for_zone(JumpConfig.zone_index_at(-rect.position.y)) == 1.0, "actual zone fully visible")
			var first: int = B.first_visible_tile(0, camera, rect.position.y)
			for i in range(first, first + B.visible_tile_count(0, camera, rect.position.y, rect.end.y)):
				reached[B.module_kind(i)] = true
		check(reached.size() == 4, "all modules reached before fade")
		var variants := {}
		for block in range(-40, 40):
			variants[B.module_kind(-(block * 12 + 9))] = true
		check(variants.size() == 2, "schedule is not a repeated twelve-bay tile")
		var active := 0
		for t in range(80):
			var events: Array = B.atmosphere_events(Rect2(0, -float(t)*211, 1080, 2340), float(t)*0.5)
			active += events.size()
			check(events.size() <= 2, "global atmosphere bound")
			for event in events:
				var r: Rect2 = event.rect
				check(r.end.x < 280 or r.position.x > 800, "whole atmosphere footprint outside quiet area")
		check(active > 0, "atmosphere is not a dead branch")
		for r in B.right_conduit_rects(Rect2(0, -100, 1080, 2340)):
			check(r.position.x > 800 and r.end.x <= 1080, "right mass outside quiet area")
			check(r.size.x >= 60 and r.size.y == 2340, "large continuous form")
		check(B.pearl_segments(0).is_empty(), "no central guide pearls")
	print("SHAFT COMPOSITION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
