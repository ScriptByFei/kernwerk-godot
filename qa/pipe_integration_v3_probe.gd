extends SceneTree
const OUT := "res://qa/artifacts/pipe-integration-v3/verified/"
const Game = preload("res://scripts/game/game.gd")
var failures := 0
var results := {}
class Canvas extends Node2D:
	var rect: Rect2
	var baseline: GDScript
	var old := false
	var zone := 0.0
	func _draw() -> void:
		if old:
			baseline.draw(self, rect, zone, 1.0)
		else:
			ShaftBackground.draw(self, rect, zone, 1.0)
func _init() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1
func render(vp: Viewport, node: CanvasItem, name: String) -> Image:
	node.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	if name != "":
		if FileAccess.file_exists(OUT + name + ".png"):
			check(true, "existing evidence preserved " + name)
		else:
			check(image.save_png(OUT + name + ".png") == OK, "save " + name)
	return image
func difference(a: Image, b: Image, bounds: Rect2i) -> Dictionary:
	var inside := 0
	var outside := 0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			if a.get_pixel(x,y) != b.get_pixel(x,y):
				if bounds.has_point(Vector2i(x,y)):
					inside += 1
				else:
					outside += 1
	return {"inside": inside, "outside": outside}
func _run() -> void:
	check(DisplayServer.window_get_size() == Vector2i(430,932), "real 430x932 window")
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game._phase = Game.Phase.PLAYING
	game.start_menu.visible = false
	game.camera.offset = Vector2.ZERO
	game.camera.position_smoothing_enabled = false
	game.camera.force_update_scroll()
	game._background_time = 1.0
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	var rect: Rect2 = game._get_visible_world_rect()
	var module := ShaftBackground.pipe_module_rect(rect.get_center().y)
	var scale := 430.0 / rect.size.x
	var pixel_rect := Rect2((module.position - rect.position) * scale, module.size * scale)
	# One output pixel for floor/ceil raster coverage, no colour tolerance.
	var bounds := Rect2i(Vector2i(pixel_rect.position.floor()) - Vector2i.ONE, Vector2i(pixel_rect.size.ceil()) + Vector2i(3,3))
	results["world_rect"] = str(rect)
	results["module_rect"] = str(module)
	results["pixel_bounds"] = str(bounds)
	check(rect.encloses(module), "whole module visible at actual start camera")
	ShaftBackground.pipe_module_enabled = false
	var game_before := await render(root, game, "game-before")
	ShaftBackground.pipe_module_enabled = true
	var game_after := await render(root, game, "game-after")
	ShaftBackground.pipe_module_enabled = false
	var game_control := await render(root, game, "game-control")
	results["game_delta"] = difference(game_before, game_after, bounds)
	results["game_control"] = difference(game_before, game_control, bounds)
	check(results.game_delta.inside > 0 and results.game_delta.outside == 0, "game delta localized: " + str(results.game_delta))
	check(game_before.get_data() == game_control.get_data(), "game disabled control exact")
	game.free()
	await process_frame
	var vp := SubViewport.new()
	vp.size = Vector2i(430,932)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var canvas := Canvas.new()
	canvas.rect = rect
	canvas.scale = Vector2.ONE * scale
	canvas.position = -rect.position * scale
	var baseline_path := OUT + "baseline.gd.txt"
	if not FileAccess.file_exists(baseline_path):
		baseline_path = "res://qa/artifacts/pipe-integration-v3/verified/baseline.gd.txt"
	var baseline_source := FileAccess.get_file_as_string(baseline_path)
	check(baseline_source != "", "baseline readable: " + baseline_path)
	canvas.baseline = GDScript.new()
	canvas.baseline.source_code = baseline_source.replace("class_name ShaftBackground", "")
	check(canvas.baseline.reload() == OK, "original HEAD baseline compiles")
	vp.add_child(canvas)
	canvas.old = true
	var before := await render(vp, canvas, "background-before")
	canvas.old = false
	var control := await render(vp, canvas, "background-control")
	check(before.get_data() == control.get_data(), "disabled path exactly equals HEAD render")
	ShaftBackground.pipe_module_enabled = true
	var after := await render(vp, canvas, "background-after")
	results["background_delta"] = difference(before, after, bounds)
	check(results.background_delta.inside > 0 and results.background_delta.outside == 0, "background localized " + str(results.background_delta))
	var minimum := 100.0
	for y in range(932):
		for x in range(112,318):
			minimum = minf(minimum, (JumpConfig.PLATFORM_BODY_COLOR.get_luminance()+0.05)/(after.get_pixel(x,y).get_luminance()+0.05))
	results["quiet_min_ratio"] = minimum
	check(minimum >= 1.81, "unchanged contrast >=1.81: " + str(minimum))
	var peak := 0.0
	for top in [-9000.0,-3600.0,-1800.0,-1200.0,-1.0,0.0,640.0,900.0,2400.0]:
		canvas.rect.position.y = top
		canvas.position = -canvas.rect.position * scale
		await render(vp, canvas, "")
		var cost := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		peak = maxf(peak,cost)
		check(cost > 0 and cost <= 700, "render budget top=%s cost=%s" % [top,cost])
		var cut := ShaftBackground.pipe_module_rect(canvas.rect.get_center().y)
		for segment in ShaftBackground.pipe_body_segments(canvas.rect,-1.0):
			check(segment.x + segment.y <= cut.position.y or segment.x >= cut.end.y or not cut.intersects(canvas.rect), "old body absent from cut")
	results["peak_primitives"] = peak
	var a := ShaftBackground.pipe_module_rect(0.0)
	var b := ShaftBackground.pipe_module_rect(-100.0)
	check(is_equal_approx((b.position.y+100.0)-a.position.y,62.0), "near parallax 0.62")
	canvas.rect = rect
	canvas.position = -rect.position * scale
	canvas.zone = 0.275
	await render(vp,canvas,"background-half-fade")
	canvas.zone = 0.55
	var hidden := await render(vp,canvas,"background-hidden")
	var opaque := 0
	for y in range(hidden.get_height()):
		for x in range(hidden.get_width()):
			if hidden.get_pixel(x,y).a > 0:
				opaque += 1
	check(opaque == 0, "zone fade hides entire module and background")
	results["failures"] = failures
	var file := FileAccess.open(OUT + "probe-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	vp.free()
	print(JSON.stringify(results))
	quit(1 if failures else 0)
