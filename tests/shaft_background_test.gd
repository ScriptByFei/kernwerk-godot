extends SceneTree

## Reaktorschacht-Hintergrund: geprueft wird die reine Mathematik des Moduls —
## Tiefenstaffelung, Kachelabdeckung, Determinismus, Ruhezone in der Mitte und
## die Beschraenkung auf die erste Hoehenzone. Kein Rendering, keine
## Node-Abhaengigkeit; das gezeichnete Bild pruefen die QA-Probes.
##
## KORREKTUR an der ersten Fassung: sie ging davon aus, dass eine langsamere
## Ebene einen GROESSEREN Ausschnitt abdeckt und dass die ferne Ebene sich
## staerker verschiebt. Beides ist falsch. Parallax ist eine reine Verschiebung,
## kein Zoom — der Ausschnitt bleibt gleich gross, und die NAHE Ebene wandert
## staerker ueber den Schirm als die ferne. Geprueft wird jetzt genau das.

var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_layers()
	if failures == 0:
		_check_coverage()
		_check_motion()
		_check_determinism()
		_check_quiet_center()
		_check_detail_placement()
		_check_zone_gate()
		_check_cooling_gate()
		_check_cooling_coverage()
	_finish()

func _check_layers() -> void:
	_check(ShaftBackground.LAYER_COUNT == 3, "drei Tiefenebenen")
	if failures:
		return
	var factors: Array[float] = []
	for layer in range(ShaftBackground.LAYER_COUNT):
		factors.append(ShaftBackground.layer_parallax(layer))
		_check(ShaftBackground.layer_tile_height(layer) > 0.0, "Kachelhoehe ist positiv (Ebene %d)" % layer)
	# Ebene 0 ist fern, Ebene 2 nah. Der Faktor ist der Anteil der Kamerabewegung,
	# den die Ebene auf dem Schirm mitmacht: 1.0 waere Weltinhalt, 0.0 unendlich
	# fern und damit still.
	_check(factors[0] < factors[1] and factors[1] < factors[2], "Parallaxfaktor steigt von fern nach nah")
	_check(factors[2] < 1.0, "auch die nahe Ebene laeuft ruhiger als die Kamera")
	_check(factors[0] >= 0.1, "die ferne Ebene steht nicht still, sondern entfernt sich sichtbar")

## Die Kacheln muessen den Schirm lueckenlos decken — ohne Luecke und ohne
## unnoetige Kacheln.
func _check_coverage() -> void:
	var top := -2400.0
	var bottom := top + 2342.0
	var cam_y := (top + bottom) * 0.5
	for layer in range(ShaftBackground.LAYER_COUNT):
		var tile := ShaftBackground.layer_tile_height(layer)
		var first := ShaftBackground.first_visible_tile(layer, cam_y, top)
		var count := ShaftBackground.visible_tile_count(layer, cam_y, top, bottom)
		_check(count >= 1, "es wird mindestens eine Kachel gezeichnet (Ebene %d)" % layer)
		if count < 1:
			continue
		var first_top := ShaftBackground.tile_world_y(layer, cam_y, first)
		var first_bottom := ShaftBackground.tile_world_y(layer, cam_y, first + 1)
		var last_bottom := ShaftBackground.tile_world_y(layer, cam_y, first + count)
		# Oberkante: die erste Kachel deckt sie ab, die Kachel davor nicht mehr.
		_check(first_top <= top + 0.001, "erste Kachel beginnt oberhalb der Oberkante (Ebene %d)" % layer)
		_check(first_bottom > top, "erste Kachel reicht ueber die Oberkante (Ebene %d)" % layer)
		_check(first_top > top - tile, "die Kachel davor ist nicht mehr sichtbar (Ebene %d)" % layer)
		# Unterkante: die letzte Kachel deckt sie ab ...
		_check(last_bottom >= bottom - 0.001, "letzte Kachel erreicht die Unterkante (Ebene %d)" % layer)
		# ... und ohne sie bliebe der Boden offen. Das ist die Minimalitaet.
		_check(ShaftBackground.tile_world_y(layer, cam_y, first + count - 1) < bottom, "keine Kachel wird unnoetig gezeichnet (Ebene %d)" % layer)
		# Abstand zwischen zwei Kacheln ist genau eine Kachelhoehe: keine Luecke.
		var gap := ShaftBackground.tile_world_y(layer, cam_y, first + 1) - first_top
		_check(absf(gap - tile) < 0.001, "Kacheln schliessen lueckenlos aneinander (Ebene %d)" % layer)

## Kern des Parallax: die scheinbare Bewegung auf dem Schirm.
func _check_motion() -> void:
	var cam_y := -1200.0
	var travelled := 1000.0
	for layer in range(ShaftBackground.LAYER_COUNT):
		var factor := ShaftBackground.layer_parallax(layer)
		var shift := ShaftBackground.apparent_shift(layer, travelled)
		_check(absf(shift - factor * travelled) < 0.001, "scheinbare Bewegung entspricht dem Faktor (Ebene %d)" % layer)
		_check(shift < travelled, "die Ebene laeuft langsamer als die Kamera (Ebene %d)" % layer)
		# Der Inhalt muss der Kamera ENTGEGEN versetzt werden, sonst laeuft er
		# mit und wirkt wie Weltinhalt.
		# Der Weltversatz des Kachelrasters ist der Rest der Bewegung; die
		# scheinbare Bewegung auf dem Schirm ist der Faktor-Anteil. Beide
		# ergaenzen sich zu genau einer Kamerabewegung.
		var offset_move := absf(ShaftBackground.scroll_offset(layer, cam_y - travelled) - ShaftBackground.scroll_offset(layer, cam_y))
		_check(absf(offset_move - (1.0 - factor) * travelled) < 0.001, "Weltversatz ist der Rest der Bewegung (Ebene %d)" % layer)
		_check(absf(offset_move + shift - travelled) < 0.001, "Versatz und scheinbare Bewegung ergaenzen sich (Ebene %d)" % layer)
	var near := ShaftBackground.apparent_shift(2, travelled)
	var far := ShaftBackground.apparent_shift(0, travelled)
	_check(near > far, "die nahe Ebene wandert staerker als die ferne")
	# Auch bei negativer Kamerabewegung (Abstieg) bleibt die Staffelung erhalten.
	_check(absf(ShaftBackground.apparent_shift(2, -500.0)) > absf(ShaftBackground.apparent_shift(0, -500.0)), "Staffelung gilt auch beim Abstieg")

func _check_determinism() -> void:
	# Gleiche Kachel muss immer dieselben Werte liefern, sonst flackert das
	# Muster bei jedem Bild neu.
	_check(ShaftBackground.tile_seed(0, 7) == ShaftBackground.tile_seed(0, 7), "Kachelsetzung ist reproduzierbar")
	_check(ShaftBackground.tile_seed(0, 7) != ShaftBackground.tile_seed(0, 8), "benachbarte Kacheln streuen anders")
	_check(ShaftBackground.tile_seed(0, 7) != ShaftBackground.tile_seed(1, 7), "Ebenen streuen unabhaengig")
	# Auch negative Kachelnummern sind gueltig: der Schacht reicht beliebig weit.
	_check(ShaftBackground.tile_seed(0, -3) == ShaftBackground.tile_seed(0, -3), "negative Kacheln sind reproduzierbar")
	var values: Array[float] = []
	for slot in range(12):
		values.append(ShaftBackground.tile_value(0, 3, slot))
	var repeats := 0
	for slot in range(12):
		if is_equal_approx(values[slot], ShaftBackground.tile_value(0, 3, slot)):
			repeats += 1
	_check(repeats == 12, "Werte sind reproduzierbar")
	var smallest := values[0]
	var largest := values[0]
	for value in values:
		smallest = minf(smallest, value)
		largest = maxf(largest, value)
	_check(smallest >= 0.0 and largest <= 1.0, "Werte liegen im Einheitsbereich")
	_check(largest - smallest > 0.05, "die Werte streuen tatsaechlich, statt konstant zu sein")

## Die Spielmitte muss ruhig bleiben: Details nur links und rechts.
func _check_quiet_center() -> void:
	var width := 1080.0
	_check(not ShaftBackground.detail_allowed(width * 0.5, width), "die Bildmitte traegt kein Detail")
	_check(not ShaftBackground.detail_allowed(width * 0.5 - 120.0, width), "auch knapp neben der Mitte bleibt es ruhig")
	_check(not ShaftBackground.detail_allowed(width * 0.5 + 120.0, width), "die Ruhezone ist symmetrisch")
	_check(ShaftBackground.detail_allowed(60.0, width), "weit links sind Details erlaubt")
	_check(ShaftBackground.detail_allowed(width - 60.0, width), "weit rechts sind Details erlaubt")
	# Die Ruhezone muss eine Plattform abdecken, sonst ragt Technik unter den
	# Spielbereich.
	_check(ShaftBackground.QUIET_HALF_WIDTH >= JumpConfig.PLATFORM_SIZE.x * 0.5, "Ruhezone deckt mindestens eine halbe Plattformbreite ab")
	# Und sie darf nicht die ganze Breite schlucken, sonst gibt es keine Details.
	_check(ShaftBackground.QUIET_HALF_WIDTH < width * 0.5 - 100.0, "es bleibt Platz fuer Details an den Raendern")

## Jedes GESETZTE Detail muss ausserhalb der ruhigen Mitte liegen.
##
## Diese Regel galt bisher nur fuer die mittlere und die nahe Ebene — beide rufen
## detail_allowed() auf. Die Fernwand setzte ihre Traegerachsen (x=300 und x=780)
## und ihre Panelfelder daran vorbei und ragte damit in den Spielbereich, genau
## dort, wo Reaktor und Plattformen laufen. Der Fehler war unsichtbar, weil nur
## die Positionen geprueft wurden, die den Riegel auch benutzen.
func _check_detail_placement() -> void:
	var width := 1080.0
	var quiet_left := width * 0.5 - ShaftBackground.QUIET_HALF_WIDTH
	var quiet_right := width * 0.5 + ShaftBackground.QUIET_HALF_WIDTH
	var axes := ShaftBackground.girder_axes(width)
	_check(axes.size() >= 2, "die Fernwand traegt ueberhaupt Traeger")
	for axis in axes:
		_check(ShaftBackground.detail_allowed(axis, width), "Traegerachse %.0f liegt ausserhalb der Ruhezone" % axis)
	# "ausserhalb der Ruhezone" allein genuegt NICHT: vier Achsen auf x=0 waeren
	# formal zulaessig, aber die Wand haette links und rechts keine Struktur
	# mehr. Deshalb muss JEDE Seite eigene Traeger tragen.
	var left_axes := 0
	var right_axes := 0
	for axis in axes:
		if axis < width * 0.5:
			left_axes += 1
		else:
			right_axes += 1
	_check(left_axes >= 1, "links traegt die Fernwand mindestens einen Traeger")
	_check(right_axes >= 1, "rechts traegt die Fernwand mindestens einen Traeger")
	# Und die Traeger muessen sich unterscheiden, sonst liegen sie uebereinander.
	var distinct := {}
	for axis in axes:
		distinct[int(round(axis))] = true
	_check(distinct.size() == axes.size(), "die Traegerachsen sind verschieden")
	for side in [-1.0, 1.0]:
		var span := ShaftBackground.panel_field_span(width, side)
		_check(span.y > span.x, "Panelfeld hat eine positive Breite (Seite %.0f)" % side)
		var outside := span.y <= quiet_left + 0.01 or span.x >= quiet_right - 0.01
		_check(outside, "Panelfeld %.0f..%.0f ueberdeckt die Ruhezone nicht" % [span.x, span.y])
	# Gegenprobe: die Ruhezone darf nicht die ganze Wand schlucken, sonst gibt
	# es links und rechts keine Paneele mehr.
	var left := ShaftBackground.panel_field_span(width, -1.0)
	var right := ShaftBackground.panel_field_span(width, 1.0)
	_check(left.y - left.x > 100.0 and right.y - right.x > 100.0, "links und rechts bleibt echte Panelflaeche")

## Kuehlsektion: eigenes Fenster, Kreuzblendung mit dem Reaktorschacht, und nach
## oben hin sauber aus, bevor Zone 3 beginnt.
func _check_cooling_gate() -> void:
	# Am Boden ist sie aus — dort gilt der Reaktorschacht.
	_check(ShaftBackground.cooling_opacity_for_zone(0.0) == 0.0, "am Boden ist die Kuehlsektion aus")
	# Der Kernpunkt: im Fenster, in dem der Reaktorschacht ausblendet, blendet
	# die Kuehlsektion ein. Sonst staende dort nur die flache Zonenfarbe.
	var covered := true
	var gap := 0.0
	for step in range(1, 12):
		var index := float(step) / 20.0  # 0.05 bis 0.55
		var total := ShaftBackground.opacity_for_zone(index) + ShaftBackground.cooling_opacity_for_zone(index)
		gap = maxf(gap, 1.0 - total)
		if total < 0.99:
			covered = false
	_check(covered, "im Uebergang traegt immer eine der beiden Schichten (groesste Luecke %.3f)" % gap)
	# In der Kuehlsektion selbst laeuft sie voll.
	_check(is_equal_approx(ShaftBackground.cooling_opacity_for_zone(1.0), 1.0), "in der Kuehlsektion ist sie voll sichtbar")
	_check(is_equal_approx(ShaftBackground.cooling_opacity_for_zone(1.55), 1.0), "sie laeuft bis 1.55 voll durch")
	# Und nach oben aus, bevor die naechste Stimmung beginnt.
	_check(ShaftBackground.cooling_opacity_for_zone(2.0) == 0.0, "bei 2.0 ist sie aus")
	_check(ShaftBackground.cooling_opacity_for_zone(3.2) == 0.0, "in den hoeheren Zonen bleibt sie aus")
	# Stetig: kein Sprung zwischen zwei feinen Abtastungen.
	#
	# Die Grenze wird HERGELEITET, nicht geraten. Mein erster Versuch nahm 0.1
	# fest an und schlug bei 0.111 an — das war die Steigung der Ausblendrampe
	# selbst, also genau das erwuenschte Verhalten. Eine geratene Schranke kann
	# einen korrekten Verlauf nicht von einem Sprung unterscheiden. Die
	# Schrittweite der Abtastung geteilt durch die kuerzeste Rampe ist die
	# groesste Steigung, die ein STETIGER Verlauf hier haben darf.
	var sample_step := 0.05
	var shortest_ramp: float = minf(ShaftBackground.ZONE_FADE_START,
		ShaftBackground.COOLING_FADE_OUT_END - ShaftBackground.COOLING_FADE_OUT_START)
	var allowed := sample_step / shortest_ramp * 1.05  # 5 % Toleranz fuer Rundung
	var previous := -1.0
	var max_step := 0.0
	for step in range(41):
		var value := ShaftBackground.cooling_opacity_for_zone(float(step) / 20.0)
		if previous >= 0.0:
			max_step = maxf(max_step, absf(value - previous))
		previous = value
	_check(max_step <= allowed,
		"der Verlauf ist stetig (groesster Schritt %.3f, erlaubt %.3f bei Abtastung %.2f)"
			% [max_step, allowed, sample_step])
	# Gegenprobe, dass die Pruefung ueberhaupt etwas messen KANN: ein echter
	# Sprung muss auffallen. Waere `allowed` so gross wie der ganze Wertebereich,
	# ginge jede Rampe durch.
	_check(allowed < 0.5, "die Grenze ist scharf genug, um einen Sprung zu erkennen")

## Die Zonenmodule duerfen NICHT mehr als Tapete gelesen werden.
##
## Bis zum 19.09.2026 pruefte dieser Abschnitt, dass die 250x320-Kacheln
## lueckenlos UNTEREINANDER gestapelt sind — also genau die Wiederholung, die
## Timo jetzt abgelehnt hat. Die Pruefung ist deshalb umgedreht: sie haelt fest,
## dass das Raster gross ist, dass es einen echten Leerraum gibt und dass
## benachbarte Module sich unterscheiden. Eine lueckenlose Stapelung waere jetzt
## ein FEHLER, kein Beweis.
func _check_cooling_coverage() -> void:
	var top := -12000.0
	var rect := Rect2(0.0, top, 1080.0, 2342.0)
	var slots := ShaftBackground.section_slots(rect)
	_check(slots.size() >= 4, "es werden genug Anlagenslots abgedeckt (%d)" % slots.size())
	if slots.is_empty():
		return
	# Das Raster ist gross: 760 Weltpixel je Modul, sechs Module je Periode.
	_check(is_equal_approx(ShaftBackground.SECTION_MODULE, 760.0), "das Modulraster ist 760 hoch")
	_check(ShaftBackground.SECTION_PERIOD >= 5, "die Kompositionsperiode umfasst mindestens 5 Module")
	# Der alte Fehler in Zahlen: 320er Raster gegen 760er Raster.
	var old_period: float = ShaftBackground.COOLING_TILE_SIZE.y
	_check(ShaftBackground.SECTION_MODULE * ShaftBackground.SECTION_PERIOD > old_period * 10.0,
		"die Wiederholung liegt mindestens zehnmal weiter auseinander als die alte Kachel (%.0f px)" % (ShaftBackground.SECTION_MODULE * ShaftBackground.SECTION_PERIOD))
	# Das BANDRASTER folgt dem Modulraster: gleiche Hoehe, gleicher Abstand,
	# gleiche Breite. Die Baender selbst duerfen Luecken haben (die Leerflaeche
	# ist eingeplant) — nur der Takt muss stimmen.
	var bands := ShaftBackground.section_band_rects(rect)
	var uniform := true
	for band in bands:
		if not is_equal_approx(band.size.y, ShaftBackground.SECTION_BAND_HEIGHT):
			uniform = false
		if not is_equal_approx(band.size.x, 1080.0):
			uniform = false
	# Toleranz statt exakter Gleichheit: Rect2 speichert float32, und bei
	# Weltkoordinaten um -12000 liegt die Aufloesung ueber der Standardtoleranz
	# von `is_equal_approx`. Die Abweichung wird daher ausdruecklich mitgedruckt.
	var worst_gap := 0.0
	for i in range(1, bands.size()):
		worst_gap = maxf(worst_gap, absf((bands[i].position.y - bands[i - 1].position.y) - ShaftBackground.SECTION_MODULE))
	if worst_gap > 0.05:
		uniform = false
	_check(uniform, "das Bandraster folgt dem Modultakt (760 px, 320 hoch; groesste Abweichung %.4f)" % worst_gap)
	_check(bands[0].position.y <= top, "das erste Band beginnt vor dem Ausschnitt")
	_check(bands[bands.size() - 1].end.y >= rect.end.y, "das letzte Band reicht ueber den Ausschnitt hinaus")
	# Es gibt echten Leerraum: mindestens ein Modul je Periode traegt kein
	# Register. Ohne Leerflaeche wirkt die Wand wieder gemustert.
	var empty_seen := false
	var kinds := {}
	for slot in range(ShaftBackground.SECTION_PERIOD):
		kinds[ShaftBackground.zone2_module_kind(slot)] = true
		if ShaftBackground.zone2_module_kind(slot) == 2 or ShaftBackground.zone2_module_kind(slot) == 3:
			pass
		if ShaftBackground.zone2_module_kind(slot) == 4:
			empty_seen = true
	_check(empty_seen, "es gibt ein Modul ohne Registerkoerper (Leerflaeche)")
	_check(kinds.size() == ShaftBackground.SECTION_PERIOD, "die Module sind innerhalb einer Periode alle verschieden")
	# Und die Modulfolge wiederholt sich erst nach der vollen Periode.
	var repeats_early := false
	for slot in range(-30, 30):
		if ShaftBackground.zone2_module_kind(slot) != ShaftBackground.zone2_module_kind(slot + ShaftBackground.SECTION_PERIOD):
			repeats_early = true
	_check(not repeats_early, "die Modulfolge wiederholt sich exakt nach der Periode")
	# Zone 3 hat eine EIGENE Folge, nicht dieselbe wie Zone 2: gleiche Bauform
	# (dieselbe Zahl Module, dieselben Leerstellen), anderer Inhalt.
	_check(ShaftBackground.zone3_module_kind(0) == ShaftBackground.zone2_module_kind(0),
		"beide Zonen folgen derselben Taktung (dasselbe Bauwerk)")
	# Gleiche Taktung, ANDERER Inhalt: die Module sitzen an denselben Stellen,
	# aber nicht an denselben Hoehen. Eine Kopie waere keine eigene Zone.
	var differing := false
	for slot in range(ShaftBackground.SECTION_PERIOD):
		var a := ShaftBackground.zone2_register_rect(slot, 0.0)
		var b := ShaftBackground.zone3_frame_rect(slot, 0.0)
		if not is_equal_approx(a.position.y, b.position.y) or not is_equal_approx(a.position.x, b.position.x):
			differing = true
	_check(differing, "Zone 3 sitzt an anderen Stellen als Zone 2 (eigene Module, keine Kopie)")
	# Die Register bleiben links der Ruhezone — auch mit der neuen
	# Querverschiebung, die bewusst nur nach LINKS laeuft.
	var max_shift := 0.0
	var min_shift := 0.0
	for slot in range(-40, 40):
		var shift := ShaftBackground.section_offset(slot)
		max_shift = maxf(max_shift, shift)
		min_shift = minf(min_shift, shift)
		var edge: float = ShaftBackground.COOLING_TILE_X + shift + ShaftBackground.COOLING_TILE_SIZE.x
		if edge > 280.0:
			_check(false, "Registerkachel ragt in die Ruhezone (Rand %.1f bei Slot %d)" % [edge, slot])
	_check(max_shift <= 0.0, "die Querverschiebung laeuft nur nach links (max %.1f)" % max_shift)
	_check(min_shift < -1.0, "die Querverschiebung ist wirksam, nicht null (min %.1f)" % min_shift)
	# Die rechten Gegenstuecke liegen alle ausserhalb der Ruhezone.
	var width := 1080.0
	var quiet_right: float = width * 0.5 + ShaftBackground.QUIET_HALF_WIDTH
	for slot in range(-40, 40):
		var machine := ShaftBackground.zone2_right_machine_rect(slot, 0.0)
		if machine.position.x < quiet_right:
			_check(false, "rechtes Zonengegenstueck ragt in die Ruhezone (x %.1f bei Slot %d)" % [machine.position.x, slot])
	_check(true, "die rechten Gegenstuecke liegen ausserhalb der Ruhezone")

## Nur der Reaktorschacht wird gestaltet; die hoeheren Zonen bleiben unberuehrt.
func _check_zone_gate() -> void:
	_check(is_equal_approx(ShaftBackground.opacity_for_zone(0.0), 1.0), "im Reaktorschacht ist der Hintergrund voll sichtbar")
	_check(ShaftBackground.opacity_for_zone(1.0) <= 0.0, "ab der Kuehlsektion ist er vollstaendig ausgeblendet")
	var mid := ShaftBackground.opacity_for_zone(0.5)
	_check(mid > 0.0 and mid < 1.0, "im Uebergang wird geblendet statt gesprungen")
	# Der Reaktorschacht blendet unveraendert aus; die Kreuzblendung leistet die
	# Kuehlsektion, die im GLEICHEN Fenster einblendet (siehe _check_cooling_gate).
	_check(is_equal_approx(ShaftBackground.opacity_for_zone(1.0), 0.0), "ab der Kuehlsektion ist er vollstaendig ausgeblendet")
	_check(is_equal_approx(ShaftBackground.opacity_for_zone(-1.0), 1.0), "unterhalb der Zone bleibt er sichtbar")
	_check(ShaftBackground.opacity_for_zone(3.2) == 0.0, "in den hoeheren Zonen bleibt er aus")
	var decreasing := true
	var previous := 2.0
	for step in range(11):
		var value := ShaftBackground.opacity_for_zone(float(step) / 10.0)
		if value > previous + 0.0001:
			decreasing = false
		previous = value
	_check(decreasing, "die Sichtbarkeit nimmt mit der Hoehe monoton ab")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _finish() -> void:
	print("SHAFT BACKGROUND: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
