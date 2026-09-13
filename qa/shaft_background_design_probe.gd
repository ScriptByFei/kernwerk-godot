extends SceneTree

## Fensterbasierte Bildregeln, keine headless-Zeichenattrappe.
const OUT := "/tmp/kernwerk-six-phases/shaft"
var failures := 0
var checks := 0

class BackgroundCanvas extends Node2D:
	var rect := Rect2(0.0, -1200.0, 1080.0, 2342.0)
	var layer := -1
	var zone := 0.0
	var draws := 0
	func _draw() -> void:
		draws += 1
		if layer < 0:
			ShaftBackground.draw(self, rect, zone, 1.0)
		else:
			ShaftBackground.draw_layer_for_test(self, rect, zone, 1.0, layer)

func _init() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(430, 932)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := BackgroundCanvas.new()
	viewport.add_child(canvas)
	canvas.scale = Vector2.ONE * 430.0 / 1080.0
	var peak := 0.0
	for camera_top in [-9000.0, -3600.0, -1800.0, -1200.0, -1.0, 0.0, 640.0, 900.0, 2400.0]:
		canvas.rect.position.y = camera_top
		canvas.position.y = -camera_top * canvas.scale.y
		canvas.layer = -1
		canvas.zone = 0.0
		var image := await _render(viewport, canvas)
		var cost := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		peak = maxf(peak, cost)
		_check(cost > 0.0 and cost <= 700.0, "echte Renderprimitive <=700 bei top=%s: %s" % [camera_top, cost])
		_check(_quiet_min_ratio(image) >= 1.81, "Kontrast in kompletter Ruhezone >=1.81 bei %s" % camera_top)
		_check(_quiet_warm_count(image) == 0, "kein Warmlicht in Ruhezone bei %s" % camera_top)
		var material := _material_stats(image)
		_check(material.x >= 2.0, "Warmlicht-Flaechen existieren: %.2f%%" % material.x)
		_check(material.y >= 5.0, "schwarze Zwischenraeume existieren: %.2f%%" % material.y)
		var repeat := await _render(viewport, canvas)
		_check(image.get_data() == repeat.get_data(), "identische Eingabe ergibt identische Bildpixel")
		if camera_top == -1800.0:
			image.save_png(OUT + "/shaft-background-only.png")
			print("QUIET_MIN_RATIO ", _quiet_min_ratio(image))
		for layer in [1, 2]:
			canvas.layer = layer
			var isolated := await _render(viewport, canvas)
			_check(_alpha_count(isolated) > 1000, "Technikebene zeichnet sichtbare Koerper")
			_check(_quiet_alpha_count(isolated) == 0, "Ebene %d zeichnet kein Pixel in Ruhezone, top=%s" % [layer, camera_top])
			if camera_top == -1800.0:
				isolated.save_png(OUT + "/shaft-layer-%d.png" % layer)
	# Kamera-Sweep nur fuer Kosten, ohne teure Pixelanalysen pro Sample.
	canvas.layer = -1
	for sample in range(120):
		var camera_top := -15000.0 + sample * 251.0
		canvas.rect.position.y = camera_top
		canvas.position.y = -camera_top * canvas.scale.y
		canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var cost := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		peak = maxf(peak, cost)
		_check(cost > 0.0 and cost <= 700.0, "Kosten-Sweep top=%s: %s <=700" % [camera_top, cost])
	canvas.layer = -1
	canvas.zone = 1.0
	var hidden := await _render(viewport, canvas)
	_check(_alpha_count(hidden) == 0, "hoehere Zone komplett transparent")
	print("SHAFT DESIGN: %d checks, %d failures, peak %.0f primitives" % [checks, failures, peak])
	viewport.free()
	quit(1 if failures else 0)

func _render(viewport: SubViewport, canvas: BackgroundCanvas) -> Image:
	var before := canvas.draws
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	_check(canvas.draws > before, "_draw wirklich aufgerufen")
	return viewport.get_texture().get_image()

func _quiet_min_ratio(image: Image) -> float:
	var minimum := 100.0
	var body := JumpConfig.PLATFORM_BODY_COLOR.get_luminance() + 0.05
	for y in range(image.get_height()):
		for x in range(112, 318):
			var bg := image.get_pixel(x, y).get_luminance() + 0.05
			minimum = minf(minimum, body / bg)
	return minimum

func _quiet_warm_count(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(112, 318):
			var p := image.get_pixel(x, y)
			if p.r > p.g * 1.3 and p.g > p.b * 1.2 and p.r > 0.2:
				count += 1
	return count

func _quiet_alpha_count(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(112, 318):
			if image.get_pixel(x, y).a > 0.0:
				count += 1
	return count

func _alpha_count(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.0:
				count += 1
	return count

func _material_stats(image: Image) -> Vector2:
	var warm := 0
	var black := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var p := image.get_pixel(x, y)
			if p.r > 0.2 and p.r > p.g * 1.3 and p.g > p.b * 1.2:
				warm += 1
			if p.get_luminance() <= 5.0 / 255.0:
				black += 1
	return Vector2(warm, black) * 100.0 / float(image.get_width() * image.get_height())
