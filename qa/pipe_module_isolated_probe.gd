extends SceneTree
## Debug: verify PIPE_MODULE loads and _draw_pipe_module paints non-empty pixels.
## Draws the module at cut=0 (top) then counts non-transparent pixels in 18..114,0..300.
class Canvas extends Node2D:
	func _draw() -> void:
		ShaftBackground._draw_pipe_module(self, 0.0, 1.0)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var tex: Texture2D = ShaftBackground.PIPE_MODULE
	if tex == null or not tex.get_rid().is_valid():
		push_error("PIPE_MODULE texture is null/empty")
		quit(1)
		return
	print("PIPE_MODULE size=", tex.get_size())
	var path := "res://qa/artifacts/pipe-integration-v3/module_isolated.png"
	if FileAccess.file_exists(path):
		push_error("Refusing overwrite: " + path)
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(430, 300)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(Canvas.new())
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var result := image.save_png(path)
	var samples := 0
	for xx in range(10, 106):
		for yy in range(0, 300):
			if image.get_pixel(xx, yy).a > 0.01:
				samples += 1
	print("sample_nonempty_px=", samples, " expected_approx=", int(96 * 300 * 0.77))
	print("Capture ", path, " save_error=", result)
	viewport.queue_free()
	await process_frame
	quit(0 if (result == OK and samples > 1000) else 1)
