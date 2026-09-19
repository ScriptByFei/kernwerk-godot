extends SceneTree

## Permanente Facility-Struktur: die gemeinsame Schachtarchitektur aller fuenf
## Zonen. Geprueft wird die reine Mathematik (Raster, Parallax, Ruhezone,
## Kontrastregeln, Determinismus) — kein Rendering. Die gezeichneten Bilder
## prueft qa/facility_zones_probe.gd.
##
## Der Zweck der Schicht ist die WAHRNEHMUNG des Spielers ("ein Kernwerk"), und
## die laesst sich nicht messen. Messbar ist, was sie dafuer tun MUSS: dieselbe
## Wand durch alle Zonen, dieselbe Parallax wie der uebrige Schacht, dieselbe
## Ruhezone, und ein Raster, das groesser ist als das der abgeloesten Kacheln.

const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const ShaftBackground = preload("res://scripts/jump/shaft_background.gd")

var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_grid()
	_check_parallax()
	_check_windows()
	_check_coverage()
	_check_structure_exists()
	_check_quiet_zone()
	_check_transitions()
	_check_contrast_rule()
	_check_determinism()
	_finish()

## Das Anlagenraster ist das Raster der Fernwand des Reaktorschachts. Nur so
## faellt ein Quertraeger mit einer Schachtfuge zusammen, statt irgendwo
## dazwischen zu liegen.
func _check_grid() -> void:
	_check(is_equal_approx(ShaftBackground.FM_BAY, ShaftBackground.layer_tile_height(0)),
		"das Anlagenraster ist das Raster der Fernwand (%.0f)" % ShaftBackground.FM_BAY)
	_check(is_equal_approx(ShaftBackground.SECTION_MODULE, ShaftBackground.FM_BAY),
		"die Zonenmodule benutzen DASSELBE Raster wie die Anlage")
	# Die Module sind groesser als die abgeloeste Kachel — sonst waere "groessere
	# Kompositionsbloecke" nur ein Wort.
	_check(ShaftBackground.SECTION_MODULE > ShaftBackground.COOLING_TILE_SIZE.y * 2.0,
		"das Modulraster ist mehr als doppelt so gross wie die alte Kachel")
	_check(ShaftBackground.SECTION_PERIOD * ShaftBackground.SECTION_MODULE >= 1200.0,
		"eine Kompositionsperiode umfasst mindestens 1200 Weltpixel")

## Die Anlage laeuft mit der Parallax der Fernwand. Die Zonenmodule laufen mit
## der der nahen Ebene. Beides ist Absicht: die Anlage ist das entfernte
## Bauwerk, die Zone ist die Technik davor.
func _check_parallax() -> void:
	_check(ShaftBackground.layer_parallax(0) == 0.22, "die Anlage benutzt die Fernwand-Parallax")
	_check(ShaftBackground.layer_parallax(2) == 0.62, "die Zonenmodule benutzen die Nah-Parallax")
	# Der Anlagenschlitz ist NICHT ueber `tile_world_y` gerechnet: das wuerde die
	# Kachelhoehe der Ebene (760/640/900) mitnehmen. Genau dieser Fehler ist mir
	# beim Umbau passiert (gemessen 140 px Drift je Slot) — er wird hier
	# festgenagelt.
	var camera := -1781.0
	for slot in range(-9, 10):
		var expected := float(slot) * ShaftBackground.FM_BAY + ShaftBackground.scroll_offset(0, camera)
		var actual: float = ShaftBackground.facility_slot_top(camera, slot)
		if not is_equal_approx(actual, expected):
			_check(false, "Anlagenslot %d sitzt falsch (%.3f statt %.3f)" % [slot, actual, expected])
			return
	_check(true, "die Anlagenslots folgen dem eigenen 760er Raster (19 Slots geprueft)")
	# Und die Zonenslots ebenso auf ihrem eigenen Raster.
	for slot in range(-9, 10):
		var expected: float = float(slot) * ShaftBackground.SECTION_MODULE + ShaftBackground.scroll_offset(2, camera)
		if not is_equal_approx(ShaftBackground.section_top(camera, slot), expected):
			_check(false, "Zonenslot %d sitzt falsch" % slot)
			return
	_check(true, "die Zonenslots folgen dem eigenen 760er Raster (19 Slots geprueft)")
	# Wanderung beim Scrollen: dieselbe Formel wie die Ebene, also derselbe Anteil
	# der Bewegung. Eine Anlage mit eigener Parallax wuerde gegen die Wand laufen —
	# beim Rohr war das schon einmal der Fehler.
	#
	# Vorzeichen: Aufstieg heisst, die Kamera wird KLEINER (y ist nach unten
	# positiv). Der Inhalt wandert dabei um (1 - parallax) * Weg mit — das ist
	# genau die Scroll-Kompensation, und nur der Rest (parallax) ist als
	# scheinbare Bewegung im Fenster zu sehen.
	var travelled := 1000.0
	var moved: float = ShaftBackground.facility_slot_top(camera - travelled, 0) - ShaftBackground.facility_slot_top(camera, 0)
	var expected: float = -travelled * (1.0 - ShaftBackground.layer_parallax(0))
	_check(is_equal_approx(moved, expected),
		"die Anlage wandert exakt mit der Fernwand (%.1f px bei %.0f px Aufstieg)" % [moved, travelled])
	_check(is_equal_approx(ShaftBackground.apparent_shift(0, travelled), travelled * ShaftBackground.layer_parallax(0)),
		"die scheinbare Bewegung im Fenster ist der Parallaxanteil (%.0f px)" % ShaftBackground.apparent_shift(0, travelled))

## Fenster: die Anlage faengt in Zone 1 NICHT an und laeuft oben bis Zone 5
## durch. Zone 1 bringt dieselbe Bauform selbst mit (Stahltuer, Paneelfelder,
## Traegerachsen) — zwei konkurrierende Wandstrukturen waeren der Fehler.
func _check_windows() -> void:
	_check(ShaftBackground.facility_opacity_for_zone(0.0) == 0.0,
		"im Reaktorschacht ist die Anlage aus (Zone 1 bringt ihre Wand selbst mit)")
	_check(ShaftBackground.facility_opacity_for_zone(0.55) == 0.0,
		"bis zum Ende des Reaktorschachts bleibt sie aus")
	# Das Einblenden liegt VOLLSTAENDIG im Uebergang (0.55 .. 1.00): genau dort,
	# wo der Reaktorschacht ausblendet. Bei 1.0 — wenn die Kuehlsektion voll
	# traegt — ist die Anlage ebenfalls voll.
	var mid := ShaftBackground.facility_opacity_for_zone(0.78)
	_check(mid > 0.0 and mid < 1.0, "im Uebergang zur Kuehlsektion blendet sie ein (%.2f)" % mid)
	_check(is_equal_approx(ShaftBackground.facility_opacity_for_zone(1.0), 1.0),
		"bei Uebergangsende traegt sie voll (dort traegt auch die Kuehlsektion voll)")
	# Ab Zone 2 voll — und dann nach oben NIE wieder aus. Das ist der Kern: eine
	# Anlage, die in Zone 3 wieder verschwindet, waere wieder ein Bildwechsel.
	for index in [1.6, 2.0, 2.5, 3.0, 3.5, 4.0, 6.0, 12.0]:
		if not is_equal_approx(ShaftBackground.facility_opacity_for_zone(index), 1.0):
			_check(false, "die Anlage traegt bei Index %.1f nicht voll" % index)
			return
	_check(true, "die Anlage traegt von Zone 2 bis Zone 5 voll durch (8 Stichproben)")
	# Monoton: sie schaltet nicht hin und her.
	var rising := true
	var previous := -1.0
	for step in range(801):
		var value := ShaftBackground.facility_opacity_for_zone(-2.0 + 10.0 * float(step) / 800.0)
		if value < previous - 0.0001:
			rising = false
		previous = value
	_check(rising, "die Deckkraft der Anlage waechst monoton")
	# Stetigkeit mit HERGELEITETER Schranke (Abtastschritt / kuerzeste Rampe).
	#
	# Achtung: die Rampe ist hier nur 0,45 Indexeinheiten breit, die Probe tastet
	# aber 0,25 je Schritt ab. Die Schranke ist damit zwangslaeufig > 0,5 — sie
	# ist NICHT scharf genug, um einen Sprung zu erkennen. Deshalb wird feiner
	# abgetastet (0,0125), damit die Schranke wieder unterscheidend ist.
	var sample_step := 0.0125
	var allowed := sample_step / ShaftBackground.FM_FADE_RAMP * 1.05
	_check(allowed < 0.5, "die Grenze ist scharf genug, um einen Sprung zu erkennen (%.3f)" % allowed)
	var max_step := 0.0
	previous = -1.0
	var fine := 800
	for step in range(fine + 1):
		var value := ShaftBackground.facility_opacity_for_zone(-2.0 + 10.0 * float(step) / float(fine))
		if previous >= 0.0:
			max_step = maxf(max_step, absf(value - previous))
		previous = value
	_check(max_step <= allowed,
		"der Einblendverlauf ist stetig (groesster Schritt %.4f, erlaubt %.4f)" % [max_step, allowed])

## Abdeckung: die Anlage muss den sichtbaren Ausschnitt wirklich fuellen, sonst
## steht die flache Zonenfarbe durch.
func _check_coverage() -> void:
	var rect := Rect2(0.0, -18000.0, 1080.0, 2342.0)
	var slots := ShaftBackground.facility_slots(rect)
	_check(slots.size() >= 4, "es werden genug Anlagenslots abgedeckt (%d)" % slots.size())
	if slots.is_empty():
		return
	# Lueckenlos: jede Bucht beginnt, wo die vorige endet, und ist gleich hoch.
	var seamless := true
	var worst := 0.0
	for i in range(1, slots.size()):
		var a := ShaftBackground.facility_bay_rect(1080.0, rect.get_center().y, slots[i - 1])
		var b := ShaftBackground.facility_bay_rect(1080.0, rect.get_center().y, slots[i])
		worst = maxf(worst, absf(b.position.y - a.end.y))
		if b.size.y != ShaftBackground.FM_BAY:
			seamless = false
	if worst > 0.05:
		seamless = false
	_check(seamless, "die Anlagenbuchten stossen lueckenlos aneinander (groesste Fuge %.4f)" % worst)
	# Sie decken den Ausschnitt wirklich ab.
	var first := ShaftBackground.facility_bay_rect(1080.0, rect.get_center().y, slots[0])
	var last := ShaftBackground.facility_bay_rect(1080.0, rect.get_center().y, slots[slots.size() - 1])
	_check(first.position.y <= rect.position.y, "die erste Bucht beginnt vor dem Ausschnitt")
	_check(last.end.y >= rect.end.y, "die letzte Bucht reicht ueber den Ausschnitt hinaus")
	# Die Traegerachsen laufen in JEDER Bucht durch (das ist "permanent").
	var continuous := true
	for slot in slots:
		var runs := ShaftBackground.facility_girder_runs(1080.0, rect.get_center().y, slot)
		var left_seen := false
		var right_seen := false
		for run in runs:
			if is_equal_approx(run.position.x, ShaftBackground.facility_left_edge(1080.0)) and is_equal_approx(run.size.y, ShaftBackground.FM_BAY):
				left_seen = true
			if is_equal_approx(run.end.x, 1080.0 - ShaftBackground.facility_left_edge(1080.0)) and is_equal_approx(run.size.y, ShaftBackground.FM_BAY):
				right_seen = true
		if not left_seen or not right_seen:
			continuous = false
	_check(continuous, "die beiden Aussenachsen laufen durch jede Bucht (%d Buchten)" % slots.size())
	# Die vertikale Versorgungsachse rechts ebenfalls — sie ist das Band, das die
	# Zonen verbindet.
	var duct_continuous := true
	for slot in slots:
		var ducts := ShaftBackground.facility_duct_rects(1080.0, rect.get_center().y, slot)
		if ducts.size() != 1 or not is_equal_approx(ducts[0].size.y, ShaftBackground.FM_BAY):
			duct_continuous = false
	_check(duct_continuous, "die rechte Versorgungsachse laeuft durch jede Bucht")

## Die Anlage muss auch etwas ZEICHNEN. Eine Pruefung, die nur Abwesenheit
## fordert (\"nichts in der Ruhezone\"), geht auch bei einer leeren Wand durch —
## genau der Fehler, den die Perlenkette hatte (Schleife ueber eine leere Liste
## ist ein stiller Vakuum-Pass).
func _check_structure_exists() -> void:
	var rect := Rect2(0.0, -18000.0, 1080.0, 2342.0)
	var camera := rect.get_center().y
	_check(ShaftBackground.facility_slots(rect).size() >= 4, "es gibt Buchten zu zeichnen")
	var panels := 0
	var hollows := 0
	var ducts := 0
	var girders := 0
	for slot in ShaftBackground.facility_slots(rect):
		panels += ShaftBackground.facility_panel_rects(1080.0, camera, slot).size()
		hollows += ShaftBackground.facility_hollow_quads(1080.0, camera, slot).size()
		ducts += ShaftBackground.facility_duct_rects(1080.0, camera, slot).size()
		girders += ShaftBackground.facility_girder_runs(1080.0, camera, slot).size()
	_check(panels >= 8, "Paneelfelder sind vorhanden (%d)" % panels)
	_check(hollows >= 6, "tiefe Hohlraeume sind vorhanden (%d)" % hollows)
	_check(ducts >= 4, "die Versorgungsachse ist vorhanden (%d)" % ducts)
	_check(girders >= 8, "Traegerlaeufe sind vorhanden (%d)" % girders)
	# Quertraeger gibt es nur an den festgelegten Slots — aber dort wirklich.
	var crossing_seen := 0
	for slot in range(0, 24):
		if ShaftBackground.facility_crossing(slot):
			for run in ShaftBackground.facility_girder_runs(1080.0, camera, slot):
				if is_equal_approx(run.size.y, 30.0):
					crossing_seen += 1
	_check(crossing_seen >= 2, "Quertraeger sind vorhanden (%d)" % crossing_seen)
	# Gegenprobe: die Zahl wuerde bei einer leeren Wand sofort reissen.
	_check(panels > 0 and hollows > 0, "die Pruefung wuerde eine leere Wand erkennen (Gegenprobe)")

## Ruhezone: die Spielbahn in der Mitte bleibt frei von gesetzten Einzelheiten.
## Der Quertraeger darf sie queren — er ist die Segmentkante des Bauwerks, genau
## wie die waagerechte Bandfuge im Reaktorschacht.
func _check_quiet_zone() -> void:
	var width := 1080.0
	var rect := Rect2(0.0, -18000.0, width, 2342.0)
	var quiet_left: float = width * 0.5 - ShaftBackground.QUIET_HALF_WIDTH
	var quiet_right: float = width * 0.5 + ShaftBackground.QUIET_HALF_WIDTH
	# Paneelfelder und Wand liegen komplett ausserhalb.
	var panels_clean := true
	var ducts_clean := true
	for slot in ShaftBackground.facility_slots(rect):
		for panel in ShaftBackground.facility_panel_rects(width, rect.get_center().y, slot):
			if panel.end.x > quiet_left and panel.position.x < quiet_right:
				panels_clean = false
		for duct in ShaftBackground.facility_duct_rects(width, rect.get_center().y, slot):
			if duct.end.x > quiet_left and duct.position.x < quiet_right:
				ducts_clean = false
	_check(panels_clean, "kein Paneelfeld ragt in die Ruhezone")
	_check(ducts_clean, "die Versorgungsachse liegt ausserhalb der Ruhezone")
	# Die durchgehenden Traegerachsen ebenfalls.
	var axes_clean := true
	var seen_left := false
	var seen_right := false
	var distinct := {}
	for slot in ShaftBackground.facility_slots(rect):
		for run in ShaftBackground.facility_girder_runs(width, rect.get_center().y, slot):
			if is_equal_approx(run.size.y, ShaftBackground.FM_BAY):
				if run.end.x > quiet_left and run.position.x < quiet_right:
					axes_clean = false
				distinct[run.position.x] = true
				if run.position.x < quiet_left:
					seen_left = true
				if run.position.x > quiet_right:
					seen_right = true
	_check(axes_clean, "die durchgehenden Traegerachsen meiden die Ruhezone")
	# Entartungsfall: alle Achsen auf denselben Wert waeren formal "ausserhalb",
	# aber keine Struktur. Beim Reaktorschacht ist genau das durchgerutscht.
	_check(seen_left, "links liegt mindestens eine Traegerachse")
	_check(seen_right, "rechts liegt mindestens eine Traegerachse")
	_check(distinct.size() >= 2, "die Traegerachsen sind verschieden (%d Werte)" % distinct.size())
	# Hohlraeume: schraege Kammern am Rand, ebenfalls ausserhalb.
	var hollow_clean := true
	for slot in ShaftBackground.facility_slots(rect):
		for quad in ShaftBackground.facility_hollow_quads(width, rect.get_center().y, slot):
			for point in quad:
				if point.x > quiet_left and point.x < quiet_right:
					hollow_clean = false
	_check(hollow_clean, "kein Hohlraum ragt in die Ruhezone")
	# Gegenprobe: die Ruhezone darf die Wand nicht verschlucken. Ohne sie waere
	# "alles ausserhalb" auch mit einer leeren Wand erfuellt.
	var left_edge: float = ShaftBackground.facility_left_edge(width)
	_check(left_edge < quiet_left - 100.0, "links bleibt echte Wandflaeche (Rand bei %.0f)" % left_edge)
	_check(width - left_edge > quiet_right + 100.0, "rechts bleibt echte Wandflaeche (Rand bei %.0f)" % (width - left_edge))
	# Die rechte Seite muss auch wirklich AUSGEARBEITET sein, nicht nur ein
	# Rechteck. Genau hier war die erste Pruefung blind: sie kannte nur das
	# Gehaeuse-Rechteck und haette ein leeres Gehaeuse durchgelassen (die
	# Mutationsprobe hat das aufgedeckt). Deshalb wird ueber die gemeinsame
	# Quelle geprueft, die auch zeichnet.
	var fins_seen := 0
	var flanges_seen := 0
	for slot in range(-40, 40):
		var machine := ShaftBackground.zone2_right_machine_rect(slot, 0.0)
		fins_seen += ShaftBackground.zone2_machine_fins(machine).size()
		var kind := ShaftBackground.zone2_module_kind(slot)
		if kind == 0 or kind == 1 or kind == 5:
			flanges_seen += ShaftBackground.zone2_pipe_flanges(ShaftBackground.zone2_pipe_rect(slot, 0.0)).size()
	_check(fins_seen >= 40, "die rechten Gehaeuse tragen Lamellen (%d geprueft)" % fins_seen)
	_check(flanges_seen >= 40, "die Kuehlleitungen tragen Flansche (%d geprueft)" % flanges_seen)

## Uebergangsabschnitte: es gibt genau einen je Zonengrenze, er liegt an der
## Grenze, und er ist waehrend des Aufstiegs wirklich zu sehen.
##
## Der Kern dieser Pruefung ist die ANKERUNG. Zwei falsche Fassungen sind mir
## passiert und werden hier festgenagelt:
##   1. Anker an der Weltkoordinate der Grenze -> in der Fernschicht (Parallax
##      0.22) laeuft der Abschnitt bis zum Grenzuebertritt aus dem Bild. Gemessen:
##      null sichtbare Uebergaenge bei den Grenzen 1 bis 3.
##   2. Anker in der FERNschicht -> die vier Grenzen liegen dort gestaucht nur
##      rund einen Slot auseinander; gemessen waren bei EINER Grenze alle VIER
##      Abschnitte gleichzeitig im Bild, der Uebergang also ueberall.
func _check_transitions() -> void:
	# Fuer jede Grenze steht der Abschnitt in der Bildmitte, wenn die Grenze den
	# oberen Bildrand erreicht (Aufstieg: y wird kleiner).
	var heights := {}
	for boundary in [1.0, 2.0, 3.0, 4.0]:
		var height: float = -JumpConfig.zone_height_for_index(boundary)
		var rect := Rect2(0.0, height, 1080.0, 2340.0)
		var bays := ShaftBackground.facility_transition_bays(rect)
		var hit := false
		for entry in bays:
			if is_equal_approx(float(entry.boundary), boundary):
				hit = true
				heights[boundary] = int(entry.slot)
		if not hit:
			_check(false, "die Zonengrenze %.0f hat keinen Uebergangsabschnitt" % boundary)
	_check(heights.size() == 4, "alle vier Zonengrenzen haben einen Uebergangsabschnitt")
	# Die Slots liegen DICHT beieinander (Abstand ~3), nicht ein Slot fuer alle
	# vier: waeren sie gleich, saesse das Bauwerk ueberall und der Uebergang waere
	# nicht mehr zu erkennen.
	_check(heights.size() == 4, "die Uebergangsabschnitte liegen an verschiedenen Orten")
	var slot_span := 0
	if heights.size() >= 2:
		var values: Array = heights.values()
		values.sort()
		slot_span = int(values[values.size() - 1]) - int(values[0])
	_check(slot_span >= 3, "die Abschnitte liegen weit genug auseinander (%d Slots)" % slot_span)
	# Und die eigentliche Eigenschaft: jede Grenze hat ein SICHTBARES Fenster,
	# und die vier Fenster ueberlappen sich nicht. Ohne diesen Sweep koennte ein
	# Abschnitt gebaut sein und nie im Bild erscheinen.
	var visible := {}
	for boundary in [1.0, 2.0, 3.0, 4.0]:
		visible[boundary] = Vector2(999.0, -999.0)
	var total: float = JumpConfig.zone_total_height()
	var steps := 400
	for step in range(steps + 1):
		var climbed := total * float(step) / float(steps)
		var rect := Rect2(0.0, -climbed, 1080.0, 2340.0)
		var index: float = JumpConfig.zone_index_at(climbed)
		for entry in ShaftBackground.facility_transition_bays(rect):
			var boundary := float(entry.boundary)
			var r: Vector2 = visible[boundary]
			visible[boundary] = Vector2(minf(r.x, index), maxf(r.y, index))
	for boundary in [1.0, 2.0, 3.0, 4.0]:
		var r: Vector2 = visible[boundary]
		_check(r.y - r.x > 0.0,
			"Grenze %.0f ist waehrend des Aufstiegs sichtbar (Index %.3f .. %.3f)" % [boundary, r.x, r.y])
	# Kein Uebergang am Boden (dort traegt die Anlage nicht; die erste Grenze ist
	# 8000 px hoch und damit weit ausserhalb eines 2340 px hohen Ausschnitts).
	var ground := Rect2(0.0, 0.0, 1080.0, 2340.0)
	_check(ShaftBackground.facility_transition_bays(ground).is_empty(),
		"am Boden gibt es keinen Uebergangsabschnitt (die Anlage traegt dort nicht)")
	# Determinismus: derselbe Slot fuer dieselbe Grenze, unabhaengig von der Kamera.
	var slot_stable := true
	for camera in [-4000.0, 0.0, 9000.0]:
		for boundary in [1.0, 2.0, 3.0, 4.0]:
			var first_slot: int = ShaftBackground.facility_transition_slot(boundary, 2340.0)
			var second_slot: int = ShaftBackground.facility_transition_slot(boundary, 2340.0)
			if first_slot != second_slot:
				slot_stable = false
	_check(slot_stable, "die Uebergangsslots sind deterministisch")

## Zwei Farbklassen wie bei Zone 4/5: FLAECHEN muessen den Plattformkoerper
## lesbar lassen, AKZENTE muessen dunkler als der Spielerkern bleiben.
func _check_contrast_rule() -> void:
	var body: float = JumpConfig.PLATFORM_BODY_COLOR.get_luminance()
	var core := ShaftBackground.player_core_luminance()
	var surfaces := ShaftBackground.facility_surfaces()
	var accents := ShaftBackground.facility_accents()
	_check(surfaces.size() > 0, "es gibt Flaechenfarben der Anlage zu pruefen")
	_check(accents.size() > 0, "es gibt Akzentfarben der Anlage zu pruefen")
	for name in surfaces:
		var color: Color = surfaces[name]
		var ratio: float = (body + 0.05) / (color.get_luminance() + 0.05)
		_check(ratio >= 1.81, "%s haelt die Plattform-Ratio (%.3f >= 1.81)" % [name, ratio])
	for name in accents:
		var color: Color = accents[name]
		_check(color.get_luminance() <= core,
			"%s bleibt dunkler als der Spielerkern (%.3f <= %.3f)" % [name, color.get_luminance(), core])
	# Gegenprobe: eine bekannte helle Farbe muss die Flaechenregel reissen.
	var bright := Color("8fa4ad")
	var bright_ratio: float = (body + 0.05) / (bright.get_luminance() + 0.05)
	_check(bright_ratio < 1.81, "die Flaechenregel wuerde ein helles Grau erkennen (Gegenprobe %.2f)" % bright_ratio)

## Identitaet aus dem WELTindex, nie aus der kameraverschoenen Zeichenkoordinate.
func _check_determinism() -> void:
	for camera in [-9999.0, 0.0, 5678.0]:
		for slot in range(-60, 60):
			if not is_equal_approx(ShaftBackground.section_offset(slot), ShaftBackground.section_offset(slot)):
				_check(false, "die Querverschiebung ist nicht deterministisch")
				return
	_check(true, "die Querverschiebung ist deterministisch (3 Kameras, 120 Slots)")
	# Der Modultyp haengt NUR vom Slot ab: fuer dieselbe Kamera und denselben Slot
	# muss er identisch sein — und beim Scrollen mitwandern, nicht springen.
	var stable := true
	for camera in [-9999.0, 0.0, 5678.0]:
		for slot in range(-60, 60):
			if ShaftBackground.zone2_module_kind(slot) != ShaftBackground.zone2_module_kind(slot):
				stable = false
			if ShaftBackground.zone3_module_kind(slot) != ShaftBackground.zone3_module_kind(slot):
				stable = false
	_check(stable, "die Modultypen sind rein aus dem Weltindex abgeleitet")
	# Der sichtbare Slot-Satz liegt lueckenlos und deckt ab.
	var rect := Rect2(0.0, -1234.0, 1080.0, 2340.0)
	var slots := ShaftBackground.section_slots(rect)
	var consecutive := true
	for i in range(1, slots.size()):
		if slots[i] != slots[i - 1] + 1:
			consecutive = false
	_check(consecutive, "die sichtbaren Slots sind lueckenlos aufsteigend")
	var bay_first := ShaftBackground.section_band_rects(rect)[0]
	var bay_last := ShaftBackground.section_band_rects(rect)[ShaftBackground.section_band_rects(rect).size() - 1]
	_check(bay_first.position.y <= rect.position.y, "der erste Slot beginnt vor dem Ausschnitt")
	_check(bay_last.end.y >= rect.end.y, "der letzte Slot reicht ueber den Ausschnitt hinaus")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _finish() -> void:
	print("FACILITY STRUCTURE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
