extends SceneTree

## Rastert die Zeichen wirklich: Bilder gegen einen leeren Lauf DIFFERENZIEREN.
## Ein absoluter Helligkeitsschwellwert zaehlte hier das ganze Bild (16000/16000)
## und war damit blind — dieselbe Fehlerklasse wie "alle Objekte liefern denselben
## Wert". Gegenprobe: ein garantiert fehlendes Zeichen muss 0 sein.
var out := "/tmp/kernwerk-overload-choice/glyph"
var host: Control
var text := ""
var images := {}

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	host = Control.new()
	host.size = Vector2(200, 80)
	host.draw.connect(_draw_it)
	root.add_child(host)
	_measure.call_deferred()

func _draw_it() -> void:
	host.draw_string(ThemeDB.fallback_font, Vector2(10, 62), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 48, Color.WHITE)

func _measure() -> void:
	for case in [["", "absent"], ["A", "letter_A"], ["\u2191", "arrow"], ["\u25b2", "triangle"], ["READY", "ready"]]:
		text = case[0]
		host.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		images[case[1]] = root.get_texture().get_image()
		images[case[1]].save_png(out.path_join(case[1] + ".png"))
	var baseline: Image = images["absent"]
	for name in ["letter_A", "arrow", "triangle", "ready"]:
		var image: Image = images[name]
		var ink := 0
		for y in 80:
			for x in 200:
				if image.get_pixel(x, y) != baseline.get_pixel(x, y):
					ink += 1
		print(name, " ink=", ink)
	print("GLYPH RASTER DONE")
	quit()
