extends SceneTree
const Game = preload("res://scripts/game/game.gd")

## Belegt bei TELEFONBREITE, dass die riskante Route erkennbar bleibt — und die
## entfernte Kerbe wirklich weg ist.
##
## Anlass: Die einseitige Kerbe am Rand wurde entfernt, weil sie bei 430 px
## Fensterbreite nur 1 Pixel breit war. Damit traegt RISKY kein Zeichen mehr am
## Rand; es unterscheidet sich von der gleich breiten Schmalschanze allein
## darueber, dass es ein Resonanzband zeigt und die schmale Variante nicht.
##
## Erste Fassung dieser Probe war falsch und ist es wert, festgehalten zu
## werden: sie zaehlte den Plattform-Bodensatz (PLATFORM_CENTER_INSET_COLOR),
## den ALLE Varianten zeichnen (495 Pixel bei beiden) — und sie pruefte
## "ausserhalb der Mitte" relativ zum BILD, obwohl die Plattform links neben der
## Bildmitte sitzt. Beide Fehler zusammen ergaben drei rote Pruefungen, obwohl
## der Code korrekt war. Messungen werden hier an der PLATTFORM verankert, nie
## am Bild.

const OUT := "/tmp/kernwerk-six-phases/variants"
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var narrow := await _render(JumpPlatform.Variant.NARROW, "schmal")
	var risky := await _render(JumpPlatform.Variant.RISKY, "riskant")
	var scale := float(root.get_texture().get_image().get_width()) / 1080.0

	# 1. Kennzeichen: das Resonanzband. Nur RESONANCE_FOCUS und RISKY zeichnen es.
	var band_risky := _count(risky, Color("315c65"))
	var band_narrow := _count(narrow, Color("315c65"))
	print("Resonanzband: schmal=%d riskant=%d (Telefonbreite %d px, Skalierung %.3f)" % [
		band_narrow, band_risky, root.get_texture().get_image().get_width(), scale])
	_check(band_narrow == 0, "die schmale Variante traegt kein Resonanzband")
	# Das Band ist 0.42 x 200 x 2 = 168 Weltpixel breit. Auf dem Geraet muss
	# daraus ein deutlich sichtbarer Streifen werden.
	var band_device_px := 168.0 * scale
	print("Bandbreite auf dem Geraet: %.0f Pixel" % band_device_px)
	_check(band_device_px >= 40.0, "das Band ist auf dem Geraet breit genug, um zu tragen")

	# 2. Gegenprobe zur Entfernung: Die Kerbe sass bei halbe Breite - 9, also
	# knapp AUSSERHALB des Plattformkoerpers. Dort darf die Markierungsfarbe
	# nicht mehr auftreten.
	var stray_narrow := _marker_beyond_body(narrow)
	var stray_risky := _marker_beyond_body(risky)
	print("Markierungsfarbe neben dem Plattformkoerper: schmal=%d riskant=%d" % [stray_narrow, stray_risky])
	_check(stray_risky == 0, "die entfernte Kerbe taucht bei der riskanten Route nicht mehr auf")

	# 3. Die Route bleibt trotzdem fair: NORMAL-Zone muss existieren.
	var margin := (200.0 - 200.0 * JumpConfig.RISKY_RESONANCE_RATIO) * 0.5
	print("NORMAL-Rand je Seite: %.0f Weltpixel = %.0f Geraetepixel" % [margin, margin * scale])
	_check(margin >= JumpConfig.RISKY_MIN_NORMAL_MARGIN, "es bleibt ein echter NORMAL-Rand")

	print("RISKY LESBAR: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _render(variant: JumpPlatform.Variant, tag: String) -> Image:
	var scene := Node2D.new()
	root.add_child(scene)
	var platform := JumpPlatform.new()
	platform.configure_variant(variant)
	platform.position = Vector2(200.0, 160.0)
	scene.add_child(platform)
	platform.set_process(false)
	platform.impact_active = false
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var copy := image.duplicate()
	image.save_png("%s/lesbar-%s.png" % [OUT, tag])
	scene.queue_free()
	await process_frame
	return copy

## Linke und rechte Kante des Plattformkoerpers im Bild finden, damit die
## Messung an der Plattform haengt und nicht an der Bildmitte.
func _body_span(image: Image) -> Vector2i:
	var body := Color("233b46")
	var min_x := image.get_width()
	var max_x := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if _same(image.get_pixel(x, y), body):
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
	return Vector2i(min_x, max_x)

## Zaehlt die Markierungsfarbe neben dem Plattformkoerper — dort sass die Kerbe.
func _marker_beyond_body(image: Image) -> int:
	var span := _body_span(image)
	if span.y < 0:
		return -1
	var mark := Color("4b9299")
	var n := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var outside := x > span.y + 2 or x < span.x - 2
			if outside and _same(image.get_pixel(x, y), mark):
				n += 1
	return n

func _count(image: Image, target: Color) -> int:
	var n := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if _same(image.get_pixel(x, y), target):
				n += 1
	return n

func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)
