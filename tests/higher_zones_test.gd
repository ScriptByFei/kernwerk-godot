extends SceneTree

const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const ShaftBackground = preload("res://scripts/jump/shaft_background.gd")

## Hoehere Zonen 4 und 5: geprueft wird die reine Mathematik der beiden neuen
## Schichten — Fenster, Kreuzblendung, Abdeckung, Ruhezone, Determinismus und
## die Kontrastregel der Ruhezone. Kein Rendering; die gezeichneten Bilder
## prueft qa/higher_zones_probe.gd.
##
## Die Fenster sind bewusst so gelegt, dass Zone 3 (Hochspannung) spaeter in die
## Luecke [1.55, 2.55] passt, ohne dass hier etwas umgebaut wird. Der Test haelt
## diese Luecke ausdruecklich fest, damit sie nicht versehentlich zugeschoben
## wird und der Zone-3-Einbau dann kollidiert.

var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_windows()
	if failures == 0:
		_check_zone3_crossblend()
		_check_zone3_geometry()
		_check_zone4_gate()
		_check_zone5_gate()
		_check_crossblend()
		_check_zone4_geometry()
		_check_zone5_geometry()
		_check_determinism()
		_check_quiet_zone()
		_check_contrast_rule()
	_finish()

## Fenster und Luecke fuer Zone 3.
func _check_windows() -> void:
	# Zone 4: ein [2.55, 3.00], aus [3.55, 4.00].
	_check(ShaftBackground.Z4_FADE_IN_START < ShaftBackground.Z4_FADE_IN_END, "Zone 4 blendet ueber ein echtes Fenster ein")
	_check(ShaftBackground.Z4_FADE_OUT_START < ShaftBackground.Z4_FADE_OUT_END, "Zone 4 blendet ueber ein echtes Fenster aus")
	# Die Fenster SPIEGELN sich: Zone 5 blendet genau in dem Fenster ein, in dem
	# Zone 4 ausblaendet. Nur so traegt an jeder Stelle genau eine Schicht.
	_check(is_equal_approx(ShaftBackground.Z4_FADE_OUT_START, ShaftBackground.Z5_FADE_IN_START),
		"Zone 5 beginnt einzublenden, wo Zone 4 auszublenden beginnt")
	_check(is_equal_approx(ShaftBackground.Z4_FADE_OUT_END, ShaftBackground.Z5_FADE_IN_END),
		"beide Fenster enden an derselben Stelle")
	_check(is_equal_approx(ShaftBackground.Z5_FADE_IN_END, 4.0),
		"Zone 5 ist bei 4.0 voll — hoeher deckelt der Zonenindex")
	# Zone 3 schliesst die frueher freie Luecke [1.55, 2.55]. Ihre Fenster sind
	# an BEIDE Nachbarn gespiegelt: ein, wo die Kuehlsektion ausblendet; aus, wo
	# Zone 4 einblendet. Damit traegt auch hier an jeder Stelle genau eine
	# Schicht, und die flache Zonenfarbe steht nirgends allein.
	_check(is_equal_approx(ShaftBackground.Z3_FADE_IN_START, ShaftBackground.COOLING_FADE_OUT_START),
		"Zone 3 blendet ein, wo die Kuehlsektion auszublenden beginnt")
	_check(is_equal_approx(ShaftBackground.Z3_FADE_IN_END, ShaftBackground.COOLING_FADE_OUT_END),
		"Zone 3 ist voll, wenn die Kuehlsektion weg ist")
	_check(is_equal_approx(ShaftBackground.Z3_FADE_OUT_START, ShaftBackground.Z4_FADE_IN_START),
		"Zone 3 blendet aus, wo Zone 4 einblendet")
	_check(is_equal_approx(ShaftBackground.Z3_FADE_OUT_END, ShaftBackground.Z4_FADE_IN_END),
		"beide Fenster enden an derselben Stelle")
	# Die frueher freie Luecke ist jetzt von Zone 3 gefuellt.
	_check(ShaftBackground.zone3_opacity_for_zone(1.5) == 0.0,
		"vor ihrem Fenster ist Zone 3 aus")
	_check(is_equal_approx(ShaftBackground.zone3_opacity_for_zone(2.0), 1.0),
		"bei 2.0 ist Zone 3 voll — die Luecke ist geschlossen")
	_check(is_equal_approx(ShaftBackground.zone3_opacity_for_zone(2.55), 1.0),
		"sie laeuft bis 2.55 voll durch")
	_check(ShaftBackground.zone3_opacity_for_zone(3.0) == 0.0,
		"bei 3.0 ist sie aus (Zone 4 traegt)")
	# Und Zone 5 laeuft oben nicht aus: der Index erreicht 4.0 als Grenze.
	_check(ShaftBackground.zone5_opacity_for_zone(4.0) > 0.0,
		"bei 4.0 ist Zone 5 noch sichtbar (sie blendet nicht aus)")
	_check(is_equal_approx(ShaftBackground.zone5_opacity_for_zone(4.0), 1.0),
		"bei 4.0 ist Zone 5 voll sichtbar")

## Der Uebergang Zone 2 -> Zone 3 -> Zone 4. Wie bei der Kreuzblendung 4/5 gilt:
## an jeder Stelle traegt mindestens eine Schicht, ihre Summe faellt nie ab, und
## der Verlauf ist stetig. Das ist der eigentliche Zweck der gespiegelten Fenster
## — ohne diese Pruefung waere ein Loch zwischen den Zonen unbemerkt geblieben.
func _check_zone3_crossblend() -> void:
	var covered := true
	var gap := 0.0
	var previous_total := -1.0
	var steps := 30
	for step in range(steps + 1):
		var index := 1.40 + 1.70 * float(step) / float(steps)   # 1.40 .. 3.10
		var total := (ShaftBackground.cooling_opacity_for_zone(index)
			+ ShaftBackground.zone3_opacity_for_zone(index)
			+ ShaftBackground.zone4_opacity_for_zone(index))
		gap = maxf(gap, 1.0 - total)
		if total < 0.99:
			covered = false
		if previous_total >= 0.0 and total < previous_total - 0.01:
			_check(false, "die Gesamtdeckkraft faellt im Uebergang nicht ab (bei %.2f)" % index)
		previous_total = total
	_check(covered, "Zone 2 -> 3 -> 4 ist lueckenlos (groesste Luecke %.3f)" % gap)
	# Stetigkeit mit HERGELEITETER Schranke, nicht geratener: Abtastschritt
	# geteilt durch die kuerzeste Rampe im betrachteten Bereich.
	var sample_step := 1.70 / float(steps)
	var shortest_ramp: float = minf(
		ShaftBackground.Z3_FADE_IN_END - ShaftBackground.Z3_FADE_IN_START,
		ShaftBackground.Z3_FADE_OUT_END - ShaftBackground.Z3_FADE_OUT_START)
	_check(shortest_ramp > 0.0, "die Zone-3-Rampen haben echte Breite")
	var allowed := sample_step / shortest_ramp * 1.05
	var max_step := 0.0
	var previous := -1.0
	for step in range(steps + 1):
		var value := ShaftBackground.zone3_opacity_for_zone(1.40 + 1.70 * float(step) / float(steps))
		if previous >= 0.0:
			max_step = maxf(max_step, absf(value - previous))
		previous = value
	_check(max_step <= allowed,
		"der Zone-3-Verlauf ist stetig (groesster Schritt %.3f, erlaubt %.3f)" % [max_step, allowed])

## Die Zone-3-Module folgen denselben Regeln wie die der Kuehlsektion: gleiche
## Bauform, links der Ruhezone, gleiches Raster, gleiche Parallax — aber ein
## EIGENES Muster. Bis zum 19.09.2026 pruefte dieser Abschnitt die lueckenlose
## Stapelung der 250x320-Kachel; genau die ist jetzt abgeloest.
func _check_zone3_geometry() -> void:
	var top := -14000.0
	var rect := Rect2(0.0, top, 1080.0, 2340.0)
	var bands := ShaftBackground.zone3_tile_rects(rect)
	_check(bands.size() >= 4, "Zone 3 liefert genug Baender (%d)" % bands.size())
	if bands.is_empty():
		return
	# Gleiches Raster wie die Kuehlsektion — die Zonen sitzen auf DEMSELBEN
	# Bauwerk, nicht auf zwei zufaellig aehnlichen.
	var same_grid := true
	for band in bands:
		if not is_equal_approx(band.size.y, ShaftBackground.SECTION_BAND_HEIGHT):
			same_grid = false
		if not is_equal_approx(band.position.x, 0.0):
			same_grid = false
		if not is_equal_approx(band.size.x, 1080.0):
			same_grid = false
	_check(same_grid, "alle Baender haben dieselbe Hoehe und Breite")
	_check(bands[0].position.y <= rect.position.y, "das erste Band beginnt vor dem Ausschnitt")
	_check(bands[bands.size() - 1].end.y >= rect.end.y, "das letzte Band reicht ueber den Ausschnitt hinaus")
	# Der Moduleinsatz bleibt links der Ruhezone (276 < 280) — auch mit der
	# Querverschiebung, die bewusst nur nach links laeuft.
	var worst_edge := 0.0
	var right_edge: float = ShaftBackground.Z3_TILE_X + ShaftBackground.Z3_TILE_SIZE.x
	_check(right_edge < 280.0, "die Wand bleibt links der Ruhezone (Rand bei %.0f)" % right_edge)
	for slot in range(-40, 40):
		worst_edge = maxf(worst_edge, ShaftBackground.Z3_TILE_X + ShaftBackground.section_offset(slot) + ShaftBackground.Z3_TILE_SIZE.x)
	_check(worst_edge < 280.0, "auch verschoben bleibt die Wand links der Ruhezone (Rand %.1f)" % worst_edge)
	# Der Artwork-Koerper ist unveraendert 250x320 — es wird nichts skaliert.
	_check(ShaftBackground.Z3_TILE_SIZE.is_equal_approx(Vector2(250.0, 320.0)),
		"die Zone-3-Kachel bleibt 250x320 (keine Skalierung)")
	_check(ShaftBackground.COOLING_TILE_SIZE.is_equal_approx(Vector2(250.0, 320.0)),
		"die Kuehlkachel bleibt 250x320 (keine Skalierung)")
	# Beide Zonen laufen mit DERSELBEN Parallaxformel: bei gleicher Kamera muessen
	# die Bandoberkanten uebereinstimmen, sonst laufen die Waende gegeneinander.
	_check(ShaftBackground.zone3_tile_rects(rect)[0].position.y
			== ShaftBackground.cooling_tile_rects(rect)[0].position.y,
		"Zone 3 laeuft mit derselben Parallax wie die Kuehlsektion")
	# Gegenprobe, dass das Modulraster wirklich groesser ist als die Kachel:
	# ohne diese Zahl waere "groessere Bloecke" nur eine Behauptung.
	_check(ShaftBackground.SECTION_MODULE > ShaftBackground.Z3_TILE_SIZE.y * 2.0,
		"das Modulraster ist deutlich groesser als eine Kachel (%.0f gegen %.0f)" % [ShaftBackground.SECTION_MODULE, ShaftBackground.Z3_TILE_SIZE.y])

func _check_zone4_gate() -> void:
	_check(ShaftBackground.zone4_opacity_for_zone(0.0) == 0.0, "am Boden ist Zone 4 aus")
	_check(ShaftBackground.zone4_opacity_for_zone(2.5) == 0.0, "vor ihrem Fenster ist Zone 4 aus")
	_check(is_equal_approx(ShaftBackground.zone4_opacity_for_zone(3.0), 1.0), "bei 3.0 ist Zone 4 voll")
	_check(is_equal_approx(ShaftBackground.zone4_opacity_for_zone(3.55), 1.0), "sie laeuft bis 3.55 voll durch")
	_check(ShaftBackground.zone4_opacity_for_zone(4.0) == 0.0, "bei 4.0 ist sie aus")

func _check_zone5_gate() -> void:
	_check(ShaftBackground.zone5_opacity_for_zone(0.0) == 0.0, "am Boden ist Zone 5 aus")
	_check(ShaftBackground.zone5_opacity_for_zone(3.5) == 0.0, "vor ihrem Fenster ist Zone 5 aus")
	_check(is_equal_approx(ShaftBackground.zone5_opacity_for_zone(4.0), 1.0), "bei 4.0 ist Zone 5 voll")
	_check(ShaftBackground.zone5_opacity_for_zone(4.0) > ShaftBackground.zone5_opacity_for_zone(3.7),
		"sie wird nach oben hin dichter")

## Der Kernpunkt: im Uebergang traegt immer eine der beiden Schichten, es gibt
## keine Luecke in der nur die flache Zonenfarbe steht.
func _check_crossblend() -> void:
	var covered := true
	var gap := 0.0
	var previous_total := -1.0
	var steps := 20
	for step in range(steps + 1):
		var index := 3.5 + 0.5 * float(step) / float(steps)   # 3.50 .. 4.00
		var total := ShaftBackground.zone4_opacity_for_zone(index) + ShaftBackground.zone5_opacity_for_zone(index)
		gap = maxf(gap, 1.0 - total)
		if total < 0.99:
			covered = false
		if previous_total >= 0.0 and total < previous_total - 0.01:
			_check(false, "die Gesamtdeckkraft faellt im Uebergang nicht ab")
		previous_total = total
	_check(covered, "im Uebergang traegt immer eine Schicht (groesste Luecke %.3f)" % gap)
	# Stetigkeit mit HERGELEITETER Schranke, nicht geratener: die groesste
	# Steigung eines stetigen Verlaufs ist Abtastschritt / kuerzeste Rampe.
	var sample_step := 0.025
	var shortest_ramp: float = minf(
		ShaftBackground.Z4_FADE_OUT_END - ShaftBackground.Z4_FADE_OUT_START,
		ShaftBackground.Z5_FADE_IN_END - ShaftBackground.Z5_FADE_IN_START)
	var allowed := sample_step / shortest_ramp * 1.05
	_check(allowed < 0.5, "die Grenze ist scharf genug, um einen Sprung zu erkennen")
	var max_step := 0.0
	var previous := -1.0
	for step in range(41):
		var value := ShaftBackground.zone5_opacity_for_zone(3.5 + 0.5 * float(step) / 40.0)
		if previous >= 0.0:
			max_step = maxf(max_step, absf(value - previous))
		previous = value
	_check(max_step <= allowed,
		"der Verlauf ist stetig (groesster Schritt %.3f, erlaubt %.3f)" % [max_step, allowed])

func _check_zone4_geometry() -> void:
	var top := -18000.0
	var rect := Rect2(0.0, top, 1080.0, 2340.0)
	var plates := ShaftBackground.zone4_plate_rects(rect)
	_check(plates.size() >= 9, "Zone 4 liefert genug Platten (%d)" % plates.size())
	if plates.is_empty():
		return
	# Lueckenlos und gleich hoch.
	var row_h: float = ShaftBackground.Z4_MODULE_HEIGHT / float(ShaftBackground.Z4_ROWS)
	var seamless := true
	for plate in plates:
		if not is_equal_approx(plate.size.y, row_h):
			seamless = false
		if not is_equal_approx(plate.position.x, ShaftBackground.Z4_FIELD_X):
			seamless = false
		if not is_equal_approx(plate.size.x, ShaftBackground.Z4_FIELD_WIDTH):
			seamless = false
	_check(seamless, "alle Platten sind gleich hoch und gleich breit")
	# Sie decken den Ausschnitt wirklich ab.
	_check(plates[0].position.y <= rect.position.y, "die erste Platte beginnt vor dem Ausschnitt")
	_check(plates[plates.size() - 1].end.y >= rect.end.y, "die letzte Platte reicht ueber den Ausschnitt hinaus")
	# Die linke Feldbreite endet vor der Ruhezone (wie die Kuehlsektion: 274 < 280).
	var right_edge: float = ShaftBackground.Z4_FIELD_X + ShaftBackground.Z4_FIELD_WIDTH
	_check(right_edge < 280.0, "die Platten bleiben links der Ruhezone (Rand bei %.0f)" % right_edge)

func _check_zone5_geometry() -> void:
	var top := -18000.0
	var rect := Rect2(0.0, top, 1080.0, 2340.0)
	var plates := ShaftBackground.zone5_plate_rects(rect)
	_check(plates.size() >= 8, "Zone 5 liefert genug Platten (%d)" % plates.size())
	if plates.is_empty():
		return
	var right_edge: float = ShaftBackground.Z5_FIELD_X + ShaftBackground.Z5_FIELD_WIDTH
	_check(right_edge < 280.0, "Zone 5 bleibt links der Ruhezone (Rand bei %.0f)" % right_edge)
	# Das Gefahrenband ist eine Schraege, kein Block: die Huellbox muss deutlich
	# hoeher sein als die Balkendicke, sonst ist aus der Schraege ein Rechteck
	# geworden. Gemessen ueber die tatsaechliche Vierecksgeometrie.
	var quads := ShaftBackground.zone5_hazard_quads(0.0, 0.0, 250.0, 100.0)
	_check(quads.size() >= 3, "das Gefahrenband besteht aus mehreren Schraegen (%d)" % quads.size())
	if not quads.is_empty():
		var quad: PackedVector2Array = quads[0]
		var thickness := quad[1].distance_to(quad[2])
		var length := quad[0].distance_to(quad[1])
		_check(thickness > 0.0 and thickness < length * 0.5,
			"der Balken ist schmal gegen seine Laenge (d=%.1f, l=%.1f)" % [thickness, length])
		var box := Rect2(quad[0], Vector2.ZERO)
		for point in quad:
			box = box.expand(point)
		_check(box.size.y > thickness * 2.0,
			"die Schraege hat echte Hoehe, sie ist kein achsenparalleler Block (h=%.1f)" % box.size.y)

## Identitaet aus dem WELTindex: das Muster darf beim Scrollen nicht wandern.
func _check_determinism() -> void:
	var shifts_stable := true
	var seen_positive := false
	var seen_negative := false
	for n in range(-40, 40):
		for row in range(ShaftBackground.Z4_ROWS):
			var a := ShaftBackground.zone4_plate_shift(n, row, 200.0)
			var b := ShaftBackground.zone4_plate_shift(n, row, 200.0)
			if not is_equal_approx(a, b):
				shifts_stable = false
			if a > 0.0:
				seen_positive = true
			if a < 0.0:
				seen_negative = true
	_check(shifts_stable, "die Verschiebung ist deterministisch")
	# Entartungsfall: nicht alle Platten in dieselbe Richtung.
	_check(seen_positive and seen_negative, "die Platten sind abwechselnd verschoben, nicht alle gleich")
	# Gegenprobe zum Entartungsfall: eine Konstante waere hier nicht unterscheidbar.
	var distinct := {ShaftBackground.zone4_plate_shift(0, 0, 200.0): true,
		ShaftBackground.zone4_plate_shift(1, 0, 200.0): true}
	_check(distinct.size() == 2, "benachbarte Module sind unterschiedlich verschoben")

func _check_quiet_zone() -> void:
	var width := 1080.0
	var rect := Rect2(0.0, -18000.0, width, 2340.0)
	var quiet_left: float = width * 0.5 - ShaftBackground.QUIET_HALF_WIDTH
	var quiet_right: float = width * 0.5 + ShaftBackground.QUIET_HALF_WIDTH
	var clean := true
	for plate in ShaftBackground.zone4_plate_rects(rect):
		if plate.end.x > quiet_left and plate.position.x < quiet_right:
			clean = false
	for plate in ShaftBackground.zone5_plate_rects(rect):
		if plate.end.x > quiet_left and plate.position.x < quiet_right:
			clean = false
	_check(clean, "kein Plattenfeld ragt in die Ruhezone")
	# Der rechte Kanal muss ebenfalls draussen liegen.
	var rail := ShaftBackground.zone4_rail_span(width)
	_check(rail.x > quiet_right, "der rechte Kanal liegt ausserhalb der Ruhezone (x=%.0f)" % rail.x)

## Zwei Regeln, weil zwei Arten von Farbe. Siehe `zone45_surfaces`/`zone45_accents`
## im Zeichencode: die Klassifikation kommt von dort, damit Zeichnung und Pruefung
## nicht auseinanderlaufen koennen.
func _check_contrast_rule() -> void:
	var body: float = JumpConfig.PLATFORM_BODY_COLOR.get_luminance()
	var core := ShaftBackground.player_core_luminance()
	# FLAECHEN: muessen den Plattformkoerper lesbar lassen.
	var surfaces := ShaftBackground.zone45_surfaces()
	_check(surfaces.size() > 0, "es gibt Flaechenfarben zu pruefen")
	for name in surfaces:
		var color: Color = surfaces[name]
		var ratio := (body + 0.05) / (color.get_luminance() + 0.05)
		_check(ratio >= 1.81, "%s haelt die Plattform-Ratio (%.3f >= 1.81)" % [name, ratio])
	# AKZENTE: duenne Linien. Sie muessen dunkler als der Spielerkern bleiben —
	# der Hintergrund leuchtet nie heller als der Spieler.
	var accents := ShaftBackground.zone45_accents()
	_check(accents.size() > 0, "es gibt Akzentfarben zu pruefen")
	for name in accents:
		var color: Color = accents[name]
		_check(color.get_luminance() <= core,
			"%s bleibt dunkler als der Spielerkern (%.3f <= %.3f)" % [name, color.get_luminance(), core])
	# Gegenprobe, dass die Akzentregel ueberhaupt etwas misst: eine bekannte
	# helle Farbe muss sie reissen. Ohne diese Gegenprobe waere eine Regel, die
	# alles durchlaesst, nicht von einer wirksamen zu unterscheiden.
	_check(Color(1.0, 1.0, 1.0).get_luminance() > core,
		"die Akzentregel wuerde eine zu helle Farbe erkennen (Gegenprobe)")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _finish() -> void:
	print("HIGHER ZONES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
