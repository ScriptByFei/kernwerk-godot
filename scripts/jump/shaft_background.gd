class_name ShaftBackground
extends RefCounted

const JumpConfig = preload("res://scripts/jump/jump_config.gd")
## Prototyp-Rohrmodul: GENAU EINE linke Weltinstanz aus der freigegebenen
## Materialreferenz (96x300, Flansch+Schaf). Ersetzt nur eine band-Zelle.
const PIPE_MODULE := preload("res://assets/jump/shaft_pipe/pipe_module_candidate_v2.png")
## Nahtlose Kachel aus demselben freigegebenen Material (Kappe/Verjuengung durch
## gerade Schaftzeilen ersetzt). Wird fuer ALLE linken Zellen wiederholt.
const PIPE_TILE := preload("res://assets/jump/shaft_pipe/pipe_tile_candidate_v3.png")
const PIPE_TILE_SIDE := -1.0
const PIPE_INSTANCE_INDEX := 0
const PIPE_INSTANCE_BAND := 1
const PIPE_INSTANCE_SIDE := -1.0
const PIPE_SECTION_HEIGHT := 300.0
const PIPE_SECTION_WIDTH := 96.0
## QA control restores the original procedural path, not just texture visibility.
static var pipe_module_enabled := true
## Schaltet die durchgehende linke Rohrspalte an/aus (QA-Gegenprobe).
static var pipe_tile_enabled := true
## Zone 2 (Kuehlsektion): schwere Kondensatorbank, gestapelt als durchgehende
## Wand. Erzeugt von pixel-builder (gpt-image-2), freigestellt ueber die
## Magenta-Pipeline. Die Kachel ist 250x320 und wird vertikal wiederholt.
## Gemessen: 0,00 % warme Pixel (die Zone ist kalt), mittlere Helligkeit 31/255
## (der Spieler bleibt das hellste Element), Umbruchfaktor 2.05 gegen die
## typische Nachbarzeilendifferenz.
const COOLING_TILE := preload("res://assets/jump/cooling_section/cooling_register_tile_v1.png")
const COOLING_TILE_SIZE := Vector2(250.0, 320.0)
## Die Bank sitzt links, wo der Reaktorschacht sein Rohr hatte. Rechts bleibt die
## ruhige Flaeche — dort ist die Bahn frei.
const COOLING_TILE_X := 26.0
## Zone 1: schwarze Hohlraeume, ueberlappende Maschinen, eingelassenes Warmlicht.
## Zustandslos. Alle Positionen entstehen aus Kamera und Kachelnummer.
const LAYER_COUNT := 3
const LAYER_PARALLAX := [0.22, 0.40, 0.62]
const LAYER_TILE_HEIGHT := [760.0, 640.0, 900.0]
const QUIET_HALF_WIDTH := 260.0
const ZONE_FADE_START := 0.55
## Fenster, in dem die Kuehlsektion ausblendet (oben). Sie laeuft bis 1.55 voll
## durch — das ist das Ende der Kuehlsektion — und ist bei 2.0 verschwunden,
## bevor Zone 3 beginnt. Das Einblenden liegt in [0.0, ZONE_FADE_START] und
## spiegelt damit genau das Ausblenden des Reaktorschachts.
const COOLING_FADE_OUT_START := 1.55
const COOLING_FADE_OUT_END := 2.0
const FAR_WALL := Color("070c11")
const FAR_PANEL := Color("0f1820")
const FAR_SEAM := Color("17242f")
## Massive Stahltuer in der Spielmitte. Die Tuer ist die Wand selbst — ruhige,
## grosse, dunkle Flaechen mit sehr geringem Kontrast, keine Technik. Alle Werte
## halten die harte Kontrastregel (Ruhezonen-Luma <= 0.088 => Plattform-Ratio
## >= 1.81, gerechnet auf JumpConfig.PLATFORM_BODY_COLOR get_luminance()+0.05).
const DOOR_BASE := Color("0a1216")
const DOOR_PANEL := Color("0d181c")
const DOOR_PANEL_DEEP := Color("081019")
const DOOR_FUGE := Color("0b1418")
## Lesbarkeit entsteht ueber Kontrast INNERHALB der Tuer (dunkle Ritz/Verstrebung
## gegen helles Blatt), nicht ueber absolute Helligkeit. Die Regel begrenzt nur
## das HELLE Ende (<= 0f1820, 1.904:1 gegen die Plattform). Das dunkle Ende ist
## nach unten frei: daraus entsteht der Strukturkontrast.
## Hell/Dunkel ergeben 2.002 statt der 1.021, die eine reine Helligkeitsstufung
## hergibt — deshalb sind die Verstrebungen jetzt dunkle Baender statt heller.
const DOOR_BRACE := Color("03050a")
const DOOR_GAP := 8.0
const PEARL := Color("0e1719")
const LAMP_CORE := Color("d97b2a")
const VENT_SLOT := Color("04080b")
const STEAM := Color("8fa4ad")

static func layer_parallax(layer: int) -> float:
	return LAYER_PARALLAX[clampi(layer, 0, LAYER_PARALLAX.size() - 1)]

static func layer_tile_height(layer: int) -> float:
	return LAYER_TILE_HEIGHT[clampi(layer, 0, LAYER_TILE_HEIGHT.size() - 1)]

static func scroll_offset(layer: int, camera_y: float) -> float:
	return (1.0 - layer_parallax(layer)) * camera_y

static func apparent_shift(layer: int, travelled: float) -> float:
	return layer_parallax(layer) * travelled

static func tile_world_y(layer: int, camera_y: float, index: int) -> float:
	return float(index) * layer_tile_height(layer) + scroll_offset(layer, camera_y)

static func first_visible_tile(layer: int, camera_y: float, screen_top: float) -> int:
	var tile := layer_tile_height(layer)
	if tile <= 0.0:
		return 0
	var local := screen_top - scroll_offset(layer, camera_y)
	return int(floor(local / tile))

static func visible_tile_count(layer: int, camera_y: float, screen_top: float, screen_bottom: float) -> int:
	var tile := layer_tile_height(layer)
	if tile <= 0.0:
		return 0
	var span := screen_bottom - screen_top
	if span <= 0.0:
		return 0
	var first := first_visible_tile(layer, camera_y, screen_top)
	var first_top := tile_world_y(layer, camera_y, first)
	return int(floor((screen_bottom - first_top) / tile)) + 1

## Deckkraft eines gestalteten Hintergrunds ueber dem Zonenindex.
##
## Jeder gestaltete Schacht hat ein Fenster, in dem er gilt: er blendet am Anfang
## seines Fensters ein und am Ende aus. Zone 1 liegt in [0.0, 0.55], Zone 2 in
## [1.0, 1.55]. Dazwischen ueberlappen sie sich — der Uebergang ist ein
## Kreuzblenden, kein Umschalten, sonst waere mitten im Flug ein Schnitt zu sehen.
##
## ACHTUNG bei der Umstellung: die erste Fassung war eine reine Ausblendung fuer
## Zone 1. Beim Kreuzblenden muss Zone 1 AB 1.0 ausblenden (vorher: nichts), und
## Zone 2 muss ab 1.0 EINblenden. Wer nur den Fade-Wert umbenennt, bekommt an
## genau dieser Stelle einen Sprung.
static func layer_opacity(zone_index: float, fade_in_start: float, fade_in_end: float, fade_out_start: float, fade_out_end: float) -> float:
	if zone_index <= fade_in_start or zone_index >= fade_out_end:
		return 0.0
	if zone_index < fade_in_end:
		if fade_in_end <= fade_in_start:
			return 1.0
		return (zone_index - fade_in_start) / (fade_in_end - fade_in_start)
	if zone_index <= fade_out_start:
		return 1.0
	if fade_out_end <= fade_out_start:
		return 0.0
	return 1.0 - (zone_index - fade_out_start) / (fade_out_end - fade_out_start)

## Zone 1: der Reaktorschacht. Unveraendert seit dem Einbau — er blendet von 1.0
## auf 0 zwischen Index 0.0 und ZONE_FADE_START.
static func opacity_for_zone(zone_index: float) -> float:
	if zone_index <= 0.0:
		return 1.0
	if zone_index >= ZONE_FADE_START:
		return 0.0
	return 1.0 - zone_index / ZONE_FADE_START

## Zone 2: die Kuehlsektion.
##
## Die Kreuzblendung entsteht NICHT dadurch, dass der Reaktorschacht laenger
## stehen bleibt — der blendet wie bisher aus. Sie entsteht, weil die
## Kuehlsektion GENAU IN DIESEM FENSTER einblendet: [0.0, 0.55]. Damit ist an
## jeder Stelle des Uebergangs genau eine der beiden Schichten tragend, und es
## gibt keine Luecke, in der nur die flache Zonenfarbe steht.
##
## Nach oben laeuft sie bis 1.55 voll durch (die ganze Kuehlsektion) und blendet
## dann bis 2.0 aus — Zone 3 bleibt ungestaltet.
static func cooling_opacity_for_zone(zone_index: float) -> float:
	return layer_opacity(zone_index, 0.0, ZONE_FADE_START, COOLING_FADE_OUT_START, COOLING_FADE_OUT_END)

static func detail_allowed(world_x: float, view_width: float) -> bool:
	return absf(world_x - view_width * 0.5) > QUIET_HALF_WIDTH

static func girder_axes(view_width: float) -> Array[float]:
	var axes: Array[float] = []
	for share: float in [0.09, 0.20, 0.80, 0.91]:
		var x: float = view_width * share
		if detail_allowed(x, view_width):
			axes.append(x)
	return axes

static func panel_field_span(view_width: float, side: float) -> Vector2:
	var edge := view_width * 0.5 - QUIET_HALF_WIDTH
	if side < 0.0:
		return Vector2(0.0, edge)
	return Vector2(view_width - edge, view_width)

static func tile_seed(layer: int, index: int) -> int:
	var value := index * 1103515245 + layer * 12345 + 7919
	value ^= value >> 13
	value *= 1274126177
	return absi(value)

static func tile_value(layer: int, index: int, slot: int) -> float:
	var value := tile_seed(layer, index) + slot * 2654435761
	value ^= value >> 15
	value *= 2246822519
	value ^= value >> 13
	return float(absi(value) % 100000) / 100000.0

static func tile_pick(layer: int, index: int, slot: int, count: int) -> int:
	if count <= 0:
		return 0
	var value := tile_seed(layer, index) + slot * 40503
	value ^= value >> 11
	return absi(value) % count

## ---------------------------------------------------------------------------
## Zonenmodule auf dem Anlagenraster
## ---------------------------------------------------------------------------
##
## Zone 2 und Zone 3 haben ihre Artworks bis hierher als 250x320 grosse Zellen
## ENDLOS gleichmaessig gestapelt (ein `for n in range(first, last+1)` ueber
## `tile_world_y(2, camera, 0) + n*320`). Im laufenden Spiel liest sich das als
## Tapete: die Wiederholung liegt unter einer Sekunde.
##
## Jetzt sind die Artworks MODULE in groesseren Kompositionsbloecken:
##   - Raster: dieselben 760 px wie die Facility-Struktur, gleicher Weltindex
##     (`slot`) und dieselbe Parallaxformel wie bisher (`tile_world_y(2, ...)`).
##     Damit laufen die Zonenmodule weiterhin exakt mit der uebrigen Wand, aber
##     die Wiederholung liegt bei 6 * 760 = 4560 Weltpixeln statt bei 320.
##   - Jeder Slot hat eine eigene ANORDNUNG (Kind), eigene Hoehenlage, eigene
##     Querverschiebung und rechts ein eigenes Gegenstueck. Es wird nichts
##     gespiegelt: eine Spiegelung waere sofort als solche zu erkennen.
##   - Leerflaechen sind eingeplant (Kind LEER). Eine Wand ohne Luecken wirkt
##     wieder gemustert, egal wie unregelmaessig die Module sitzen.
const SECTION_MODULE := FM_BAY
const SECTION_PERIOD := 6
## Der Registerkachel-Koerper bleibt 250x320 (unveraendert), er wird nur nicht
## mehr endlos gestapelt.
const SECTION_BAND_HEIGHT := 320.0
## Querverschiebung je Modul. Nach LINKS begrenzt, damit die rechte Kante des
## Modulfelds die Ruhezone sicher nicht erreicht (26 + 250 = 276 < 280).
static func section_offset(slot: int) -> float:
	return -tile_value(2, slot, 21) * 22.0

## Sichtbare Anlagenslots des Modulrasters. Gemeinsame Quelle fuer Zeichnung UND
## Pruefung.
static func section_slots(rect: Rect2) -> Array[int]:
	var out: Array[int] = []
	var camera := rect.get_center().y
	var first := int(floor((rect.position.y - scroll_offset(2, camera)) / SECTION_MODULE)) - 1
	var last := int(ceil((rect.end.y - scroll_offset(2, camera)) / SECTION_MODULE)) + 1
	for slot in range(first, last + 1):
		out.append(slot)
	return out

## Weltposition der Oberkante eines Zonenmoduls.
##
## Wie bei der Facility-Struktur NICHT `tile_world_y(2, ...)`: das benutzt die
## Kachelhoehe der nahen Ebene (900), waehrend das Modulraster 760 hoch ist. Die
## Parallax-ZAHL bleibt die der nahen Ebene (0.62) — die Zonenmodule sitzen im
## selben Tiefenraum wie vorher, nur auf dem groesseren Raster.
static func section_top(camera: float, slot: int) -> float:
	return float(slot) * SECTION_MODULE + scroll_offset(2, camera)

## Die Bandzeilen der Zonenmodule. Traegt weiterhin beide alten Namen, weil
## Proben darauf zeigen: Zone 2 und Zone 3 teilen sich dasselbe Raster, ihre
## ersten Baender liegen also zwangslaeufig auf derselben Hoehe.
static func section_band_rects(rect: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var camera := rect.get_center().y
	for slot in section_slots(rect):
		out.append(Rect2(0.0, section_top(camera, slot), 1080.0, SECTION_BAND_HEIGHT))
	return out

## Zone 2: Kuehlsektion als Modulfolge.
##  0 Registerband unten + zwei Kuehlleitungen
##  1 grosse Kuehlleitung mit Knie + Ventil, rechts ein Maschinengehaeuse
##  2 LEER — die Wand zeigt sich (Ruheflaeche)
##  3 Registerband hoeher gesetzt, rechts eine zweite Leitung
##  4 Wartungssteg mit Gelaender
##  5 Registerband + kurze Leitungsstichleitung, rechts ein Verteiler
static func zone2_module_kind(slot: int) -> int:
	return posmod(slot, SECTION_PERIOD)

static func zone2_register_rect(slot: int, top: float) -> Rect2:
	var kind := zone2_module_kind(slot)
	var y: float = top + (96.0 if kind != 3 else 336.0)
	return Rect2(COOLING_TILE_X + section_offset(slot), y, COOLING_TILE_SIZE.x, COOLING_TILE_SIZE.y)

## Kuehlleitungen: breite, kalte Roehren mit heller Aussenkante.
static func zone2_pipe_rect(slot: int, top: float) -> Rect2:
	var x: float = 96.0 + section_offset(slot) * 0.5
	return Rect2(x, top + 40.0, 74.0, 470.0)

static func zone2_right_machine_rect(slot: int, top: float) -> Rect2:
	return Rect2(930.0 + section_offset(slot) * 0.5, top + 130.0, 118.0, 260.0)

## Zone 3: Hochspannung als eigene Modulfolge.
##  0 Kabelkanalwand (lange Halter + Kabel)
##  1 Isolatorenstapel auf Stahlrahmen
##  2 Transformator-/Verteilermodul (grosses Gehaeuse mit Kuehlrippen)
##  3 LEER
##  4 technische Stromfuehrung (breite Sammelschienen)
##  5 Kabelkanal + kurze Schiene
static func zone3_module_kind(slot: int) -> int:
	return posmod(slot, SECTION_PERIOD)

static func zone3_frame_rect(slot: int, top: float) -> Rect2:
	return Rect2(Z3_TILE_X + section_offset(slot), top + 80.0, Z3_TILE_SIZE.x, Z3_TILE_SIZE.y)

static func zone3_machine_rect(slot: int, top: float) -> Rect2:
	return Rect2(930.0 + section_offset(slot) * 0.5, top + 150.0, 118.0, 250.0)

static func cooling_tile_rects(rect: Rect2) -> Array[Rect2]:
	return section_band_rects(rect)

static func zone3_tile_rects(rect: Rect2) -> Array[Rect2]:
	return section_band_rects(rect)

## Kalte Kondensationsschwaden der Kuehlsektion: hoechstens einer je Bild, in
## einem festen Modul, ausserhalb der Ruhezone.
static func cooling_steam_rect(rect: Rect2, time: float) -> Dictionary:
	var camera := rect.get_center().y
	var empty := {}
	for slot in section_slots(rect):
		if posmod(slot, SECTION_PERIOD) != 1:
			continue
		var phase := fposmod(time * 0.6 + float(posmod(slot, 5)) * 0.4, 1.0)
		var y: float = section_top(camera, slot) + 300.0 - phase * 90.0
		var r := Rect2(84.0, y, 210.0, 150.0)
		if not r.intersects(rect):
			continue
		return {"rect": r, "strength": sin(phase * PI) * 0.06}
	return empty

static func draw_cooling(canvas: CanvasItem, visible_rect: Rect2, zone_index: float, time: float = 0.0) -> void:
	var alpha := cooling_opacity_for_zone(zone_index)
	if alpha <= 0.0 or visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return
	if zone45_disabled or sections_disabled:
		return
	var camera := visible_rect.get_center().y
	for slot in section_slots(visible_rect):
		var top := section_top(camera, slot)
		var kind := zone2_module_kind(slot)
		# Registerkoerper (Artwork) — sitzt in den meisten, aber nicht allen Modulen.
		if kind != 4:
			var band := zone2_register_rect(slot, top)
			if band.intersects(visible_rect):
				canvas.draw_texture_rect(COOLING_TILE, band, false, Color(1.0, 1.0, 1.0, alpha))
		match kind:
			0, 5:
				_draw_zone2_pipe(canvas, zone2_pipe_rect(slot, top), visible_rect, alpha)
				_draw_zone2_valve(canvas, Vector2(COOLING_TILE_X + 96.0 + section_offset(slot), top + 560.0), alpha)
			4:
				_draw_zone2_deck(canvas, Rect2(COOLING_TILE_X, top + 250.0, SECTION_BAND_HEIGHT + 130.0, 70.0), alpha)
			1:
				_draw_zone2_pipe(canvas, zone2_pipe_rect(slot, top), visible_rect, alpha)
				_draw_zone2_elbow(canvas, slot, top, alpha)
				_draw_zone2_machine(canvas, zone2_right_machine_rect(slot, top), alpha)
			3:
				var machine := zone2_right_machine_rect(slot, top)
				_draw_zone2_machine(canvas, Rect2(machine.position + Vector2(0.0, 120.0), machine.size), alpha)
	# Kalte Kondensation: ein Schwaden, fest im Modul verankert.
	var steam := cooling_steam_rect(visible_rect, time)
	if not steam.is_empty():
		canvas.draw_rect(steam.rect, _fade(Color("8fb4bd"), alpha * float(steam.strength)))

## Flansche der Kuehlleitung. Ebenfalls gemeinsame Quelle fuer Zeichnung und
## Pruefung — sonst wiederholt sich genau dieselbe Blindheit.
static func zone2_pipe_flanges(pipe: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for flange in range(4):
		var y: float = pipe.position.y + 60.0 + float(flange) * 118.0
		out.append(Rect2(pipe.position.x - 5.0, y, pipe.size.x + 10.0, 16.0))
	return out

static func _draw_zone2_pipe(canvas: CanvasItem, pipe: Rect2, visible_rect: Rect2, alpha: float) -> void:
	if not pipe.intersects(visible_rect):
		return
	canvas.draw_rect(pipe, _fade(Color("050c10"), alpha))
	canvas.draw_rect(Rect2(pipe.position.x + 6.0, pipe.position.y, 16.0, pipe.size.y), _fade(Color("16262d"), alpha))
	canvas.draw_rect(Rect2(pipe.position.x + 58.0, pipe.position.y, 5.0, pipe.size.y), _fade(Color("3f5d68"), alpha))
	for flange in zone2_pipe_flanges(pipe):
		canvas.draw_rect(flange, _fade(Color("0d1a20"), alpha))

static func _draw_zone2_elbow(canvas: CanvasItem, slot: int, top: float, alpha: float) -> void:
	var x: float = 200.0 + section_offset(slot) * 0.5
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(x, top + 210.0), Vector2(x + 62.0, top + 210.0),
		Vector2(x + 62.0, top + 320.0), Vector2(x - 20.0, top + 320.0),
	]), _fade(Color("050c10"), alpha))
	canvas.draw_rect(Rect2(x, top + 210.0, 6.0, 110.0), _fade(Color("3f5d68"), alpha))

static func _draw_zone2_valve(canvas: CanvasItem, center: Vector2, alpha: float) -> void:
	var points := PackedVector2Array()
	for i in range(8):
		points.append(center + Vector2.from_angle(float(i) * TAU / 8.0) * 30.0)
	_draw_convex(canvas, points, _fade(Color("22333a"), alpha))
	for i in range(8):
		points[i] = center + Vector2.from_angle(float(i) * TAU / 8.0) * 21.0
	_draw_convex(canvas, points, _fade(Color("03080b"), alpha))
	canvas.draw_line(center - Vector2(18.0, 18.0), center + Vector2(18.0, 18.0), _fade(Color("46677e"), alpha), 5.0)
	canvas.draw_line(center - Vector2(18.0, -18.0), center + Vector2(18.0, -18.0), _fade(Color("46677e"), alpha), 5.0)

## Wartungssteg der Kuehlsektion: grosse Formen, kein Kleinteil.
static func _draw_zone2_deck(canvas: CanvasItem, deck: Rect2, alpha: float) -> void:
	var p := deck.position
	canvas.draw_rect(Rect2(p, Vector2(deck.size.x, 18.0)), _fade(Color("04090c"), alpha))
	canvas.draw_rect(Rect2(p, Vector2(deck.size.x, 5.0)), _fade(Color("2c4750"), alpha))
	canvas.draw_rect(Rect2(p + Vector2(0.0, 44.0), Vector2(deck.size.x, 5.0)), _fade(Color("22383f"), alpha))
	for post in range(4):
		canvas.draw_rect(Rect2(p + Vector2(18.0 + float(post) * 120.0, 5.0), Vector2(6.0, 44.0)), _fade(Color("22383f"), alpha))

## Lamellen des rechten Maschinengehaeuses. GEMEINSAME QUELLE fuer Zeichnung UND
## Pruefung: die Pruefung, die nur das Gehaeuse-Rechteck kannte, war blind gegen
## ein leeres Gehaeuse — die Mutationsprobe hat genau das aufgedeckt.
static func zone2_machine_fins(body: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for fin in range(5):
		out.append(Rect2(body.position + Vector2(10.0, 26.0 + float(fin) * 42.0), Vector2(body.size.x - 20.0, 14.0)))
	return out

## Rechtes Gegenstueck: ein Maschinengehaeuse mit kalten Lamellen. KEINE
## Spiegelung des linken Moduls — andere Bauform, andere Hoehe, andere Teilung.
static func _draw_zone2_machine(canvas: CanvasItem, body: Rect2, alpha: float) -> void:
	canvas.draw_rect(body.grow(6.0), _fade(Color("020508"), alpha))
	canvas.draw_rect(body, _fade(Color("0a1319"), alpha))
	for fin in zone2_machine_fins(body):
		canvas.draw_rect(fin, _fade(Color("04090c"), alpha))
	canvas.draw_rect(Rect2(body.position.x, body.position.y, body.size.x, 5.0), _fade(Color("46677e"), alpha))
	canvas.draw_rect(Rect2(body.position.x + 12.0, body.end.y - 44.0, 40.0, 30.0), _fade(Color("2c4750"), alpha))

## Zone 3 (Hochspannung) auf demselben Raster, eigene Modulfolge.
static func draw_zone3(canvas: CanvasItem, visible_rect: Rect2, zone_index: float) -> void:
	var alpha := zone3_opacity_for_zone(zone_index)
	if alpha <= 0.0 or visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return
	if zone45_disabled or sections_disabled:
		return
	var camera := visible_rect.get_center().y
	for slot in section_slots(visible_rect):
		var top := section_top(camera, slot)
		var kind := zone3_module_kind(slot)
		var frame := zone3_frame_rect(slot, top)
		if kind != 3 and frame.intersects(visible_rect):
			canvas.draw_texture_rect(Z3_TILE, frame, false, Color(1.0, 1.0, 1.0, alpha))
		match kind:
			0, 5:
				_draw_zone3_cable_run(canvas, frame, alpha)
			1:
				_draw_zone3_insulators(canvas, slot, top, alpha)
				_draw_zone3_machine(canvas, zone3_machine_rect(slot, top), alpha)
			2:
				_draw_zone3_machine(canvas, Rect2(Z3_TILE_X + section_offset(slot), top + 130.0, Z3_TILE_SIZE.x, Z3_TILE_SIZE.y), alpha)
				_draw_zone3_busbar(canvas, slot, top, alpha)
			4:
				_draw_zone3_busbar(canvas, slot, top, alpha)

static func _draw_zone3_cable_run(canvas: CanvasItem, frame: Rect2, alpha: float) -> void:
	for tray in range(3):
		var y: float = frame.position.y + 60.0 + float(tray) * 96.0
		canvas.draw_rect(Rect2(frame.position.x - 10.0, y, frame.size.x + 20.0, 20.0), _fade(Color("03060c"), alpha))
		canvas.draw_rect(Rect2(frame.position.x - 10.0, y, frame.size.x + 20.0, 4.0), _fade(Color("2a3a52"), alpha))
		for clamp in range(4):
			canvas.draw_rect(Rect2(frame.position.x + 4.0 + float(clamp) * 62.0, y - 6.0, 10.0, 32.0), _fade(Color("0b141f"), alpha))

## Isolatorenstapel: dunkle Keramikscheiben auf einem Stahlrahmen. Bewusst
## dunkel — helles Porzellan waere heller als der Spielerkern.
static func _draw_zone3_insulators(canvas: CanvasItem, slot: int, top: float, alpha: float) -> void:
	var x: float = 150.0 + section_offset(slot) * 0.5
	canvas.draw_rect(Rect2(x - 8.0, top + 90.0, 26.0, 460.0), _fade(Color("0b141f"), alpha))
	canvas.draw_rect(Rect2(x - 8.0, top + 90.0, 5.0, 460.0), _fade(Color("2a3a52"), alpha))
	for disc in range(6):
		var y: float = top + 130.0 + float(disc) * 66.0
		canvas.draw_rect(Rect2(x - 26.0, y, 62.0, 12.0), _fade(Color("141d2b"), alpha))
		canvas.draw_rect(Rect2(x - 18.0, y + 12.0, 46.0, 8.0), _fade(Color("070d16"), alpha))

static func _draw_zone3_machine(canvas: CanvasItem, body: Rect2, alpha: float) -> void:
	canvas.draw_rect(body.grow(6.0), _fade(Color("02040a"), alpha))
	canvas.draw_rect(body, _fade(Color("0a101c"), alpha))
	canvas.draw_rect(Rect2(body.position.x, body.position.y, body.size.x, 5.0), _fade(Color("2a3a52"), alpha))
	for rib in range(4):
		canvas.draw_rect(Rect2(body.position + Vector2(12.0, 30.0 + float(rib) * 50.0), Vector2(body.size.x - 24.0, 16.0)), _fade(Color("03060c"), alpha))
	canvas.draw_rect(Rect2(body.position + Vector2(14.0, body.size.y - 56.0), Vector2(34.0, 40.0)), _fade(Color("141d2b"), alpha))

static func _draw_zone3_busbar(canvas: CanvasItem, slot: int, top: float, alpha: float) -> void:
	var x: float = 120.0 + section_offset(slot) * 0.5
	for bar in range(3):
		var y: float = top + 180.0 + float(bar) * 120.0
		canvas.draw_rect(Rect2(x, y, 180.0, 26.0), _fade(Color("0b141f"), alpha))
		canvas.draw_rect(Rect2(x, y, 180.0, 5.0), _fade(Color("2a3a52"), alpha))
		canvas.draw_rect(Rect2(x + 40.0, y + 26.0, 14.0, 60.0), _fade(Color("03060c"), alpha))

## ---------------------------------------------------------------------------
## Zone 3: Hochspannung
##
## Die Kachel ist dieselbe Bauform wie die Kuehlsektion (250x320, links bei
## x=26, rechte Kante 276 < 280 — die Ruhezone bleibt frei) und wird vertikal
## wiederholt. Erzeugt mit der Higgsfield-API (Recraft V4.1) und ueber die
## Magenta-Pipeline freigestellt; die Kanten sind WEICH gekeyt, weil eine harte
## Maske halbdurchsichtige Randpixel stehenlaesst und sich beim Stapeln genau an
## der Naht als Magenta-Rest sammelt (gemessen: 775 px hart gegen 0 px weich).
##
## Die Fenster sind GESPIEGELT an die Nachbarn gekoppelt — das ist der ganze
## Punkt dieser Zone:
##   ein  [1.55, 2.00] = genau das Fenster, in dem die Kuehlsektion ausblendet
##   aus  [2.55, 3.00] = genau das Fenster, in dem Zone 4 einblendet
## Damit traegt an jeder Stelle des Uebergangs genau eine Schicht, und die Luecke
## [1.55, 2.55], die im Code bewusst freigehalten war, ist geschlossen.
##
## Gemessen gegen die Regeln des Projekts (Kachel, Produktionsgroesse):
##   Luminanz 0.017 gegen LAMP_CORE 0.291 -> Kontrast 6.13:1 (Zone 2: 4.53:1)
##   0,0 % der Motivpixel heller als der Kern (Zone 2: 1,1 %)
##   0,0 % warme Pixel — die Zone ist kalt wie die Kuehlsektion
##   Umbruchfaktor 0,55 gegen die typische Nachbarzeilendifferenz
## Die Isolatoren sind bewusst dunkel bestellt: der erste Entwurf hatte blasses
## Porzellan (RGB 246,214,166, Luminanz 0.741) und damit fuenf Flaechen heller
## als der Spielerkern, die groesste 2886 px. Das verletzt die Regel, dass der
## Hintergrund nie heller leuchtet als der Kern.
## ---------------------------------------------------------------------------
const Z3_TILE := preload("res://assets/jump/high_voltage/zone3_high_voltage_tile_v1.png")
const Z3_TILE_SIZE := Vector2(250.0, 320.0)
const Z3_TILE_X := 26.0
const Z3_FADE_IN_START := COOLING_FADE_OUT_START
const Z3_FADE_IN_END := COOLING_FADE_OUT_END

## ---------------------------------------------------------------------------
## Hoehere Zonen: Instabile Zone (4) und Kritische Zone (5)
##
## Beide prozedural — kein Artwork, kein Generator. Die Formensprache bleibt die
## des Bauwerks, damit der Schacht als EIN Ort liest und nicht als Sammlung.
##
## Fenster im Zonenindex (`zone_index_at` deckelt bei 4.0):
##   Zone 4: ein [2.55, 3.00], aus [3.55, 4.00]
##   Zone 5: ein [3.55, 4.00], bleibt voll
## Der Abschnitt [1.55, 2.55] ist bewusst frei: dort kommt spaeter Zone 3
## (Hochspannung) als eigene Schicht hinein, ohne dass hier etwas umgebaut wird.
##
## Beide Schichten liegen in derselben linken Feldbreite wie die Kuehlsektion
## (rechte Kante 274 < 280) — die Spielbahn in der Mitte bleibt in jeder Zone
## frei von gesetzter Einzelheit.
## ---------------------------------------------------------------------------
const Z4_MODULE_HEIGHT := 640.0
const Z4_FIELD_X := 24.0
const Z4_FIELD_WIDTH := 250.0
const Z4_ROWS := 3
## Schraegstellung der verschobenen Platten. Sie ist der ganze Ausdruck von
## "instabil": eine gerade Wand mit Rissen liest sich als Schaden, eine
## verschobene Wand als Versagen.
const Z4_TILT := 0.18
const Z4_FADE_IN_START := 2.55
const Z4_FADE_IN_END := 3.00
const Z4_FADE_OUT_START := 3.55
const Z4_FADE_OUT_END := 4.00
## Kalter Stahl mit Violettstich — die Zone ist instabil, nicht warm.
const Z4_PLATE := Color("1a1620")
const Z4_PLATE_DEEP := Color("120f18")
const Z4_SEAM := Color("09070e")
## Kalte Kante der verschobenen Platte. Sie ist eine duenne LINIE (4 Weltpixel)
## und keine Flaeche — die harte 1.81-Regel des Projekts gilt fuer Flaechen in
## der Ruhezone. Gemessen liegt sie mit 1.34 gegen den Plattformkoerper und
## bleibt damit als Kante lesbar, ohne die Ruhezone zu beruehren.
const Z4_EDGE := Color("2a2334")
const Z4_CABLE := Color("06050b")
const Z4_CABLE_LIT := Color("2a2334")
## Vereinzelt ein Kurzschluss. Gedaempft: der Hintergrund darf nie heller
## leuchten als der Kern (LAMP_CORE).
const Z4_SPARK := Color("7a4e22")
const Z4_RAIL := Color("0d0b12")
const Z4_RAIL_EDGE := Color("2f2839")

const Z5_MODULE_HEIGHT := 580.0
const Z5_FIELD_X := 24.0
const Z5_FIELD_WIDTH := 250.0
const Z5_FADE_IN_START := 3.55
const Z5_FADE_IN_END := 4.00
## Die letzte Zone blendet nicht aus: der Zonenindex erreicht 4.0 als Grenze.
## Ein Fenster mit fade_out_start == fade_out_end wuerde bei genau 4.0 auf 0
## springen — deshalb liegt das Ende jenseits des erreichbaren Bereichs.
const Z5_FADE_OUT_START := 4.00
const Z5_FADE_OUT_END := 99.0
const Z5_PLATE := Color("171410")
const Z5_PLATE_DEEP := Color("131210")
## Gluehende Naht: schmal, nicht flaechig. Sie ist das Signal, nicht die Flaeche.
const Z5_SEAM_GLOW := Color("6b4620")
## Gefahrenband: trotz Warnfarbe eine grosse Flaeche, deshalb im dunklen Bereich
## gehalten. Gemessen 1.85 gegen den Plattformkoerper.
const Z5_HAZARD := Color("1c160c")
const Z5_STROBE := Color("7a5a28")
const Z5_HOUSING := Color("0b0a08")
const Z5_RAIL_EDGE := Color("3a332a")

## Zone 3 (Hochspannung) blendet AUS, wo Zone 4 einblendet. Die Grenzen sind
## NICHT frei gewaehlt, sondern zeigen auf `Z4_FADE_IN_*` — deshalb stehen sie
## hier und nicht oben bei den uebrigen Z3-Konstanten (dort waere Zone 4 noch
## nicht deklariert). Verschiebt jemand das Zone-4-Fenster, wandert Zone 3 mit.
## Genau diese Kopplung haelt `higher_zones_test` fest.
const Z3_FADE_OUT_START := Z4_FADE_IN_START
const Z3_FADE_OUT_END := Z4_FADE_IN_END

static func zone3_opacity_for_zone(zone_index: float) -> float:
	return layer_opacity(zone_index, Z3_FADE_IN_START, Z3_FADE_IN_END, Z3_FADE_OUT_START, Z3_FADE_OUT_END)

static func zone4_opacity_for_zone(zone_index: float) -> float:
	return layer_opacity(zone_index, Z4_FADE_IN_START, Z4_FADE_IN_END, Z4_FADE_OUT_START, Z4_FADE_OUT_END)

static func zone5_opacity_for_zone(zone_index: float) -> float:
	return layer_opacity(zone_index, Z5_FADE_IN_START, Z5_FADE_IN_END, Z5_FADE_OUT_START, Z5_FADE_OUT_END)

## Gemeinsame Quelle fuer Zeichnung UND Pruefung: die Plattenfelder der Zone 4.
## Jede Zelle traegt ihren WELTindex (Modulnummer n, Zeile row) mit. Die
## Verschieberichtung wird ausschliesslich daraus abgeleitet, niemals aus der
## kameraverschoenen Zeichenkoordinate — sonst wandert das Muster beim Scrollen.
static func zone4_cells(rect: Rect2) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	var module := Z4_MODULE_HEIGHT
	if module <= 0.0 or Z4_ROWS <= 0:
		return cells
	var camera := rect.get_center().y
	var base := tile_world_y(2, camera, 0)
	var row_h := module / float(Z4_ROWS)
	var first := int(floor((rect.position.y - base) / module))
	var last := int(ceil((rect.end.y - base) / module))
	for n in range(first, last + 1):
		for row in range(Z4_ROWS):
			var y: float = base + float(n) * module + float(row) * row_h
			cells.append({"rect": Rect2(Z4_FIELD_X, y, Z4_FIELD_WIDTH, row_h), "n": n, "row": row})
	return cells

## Nur die Geometrie, fuer Abdeckungs- und Ruhezonenpruefungen.
static func zone4_plate_rects(rect: Rect2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for cell in zone4_cells(rect):
		rects.append(cell.rect)
	return rects

## Verschiebung einer Platte: Vorzeichen aus Modulnummer und Zeile.
static func zone4_plate_shift(n: int, row: int, row_height: float) -> float:
	var tilt: float = Z4_TILT * row_height
	return tilt if posmod(n + row, 2) == 0 else -tilt

## Kabelstrang rechts: eine gesetzte Einzelheit, deshalb ausserhalb der Ruhezone
## und mit fester Achse.
static func zone4_rail_span(view_width: float) -> Vector2:
	return Vector2(view_width - 96.0, view_width - 58.0)

## Farbklassifikation als GEMEINSAME QUELLE fuer Zeichnung und Pruefung.
##
## Die harte 1.81-Regel des Projekts schuetzt FLAECHEN in der Ruhezone: eine
## grosse Flaeche darf den Plattformkoerper nicht verschlucken. Sie gilt NICHT
## fuer duenne Linien und Leuchtakzente — sonst waeren die Randlaternen des
## Schachts (d97b2a, Ratio 0.45) seit jeher ein Regelbruch, obwohl sie
## abgenommen sind. Deshalb zwei Kategorien mit zwei verschiedenen Regeln:
##
##   surfaces: grosse Flaechen, muessen gegen den Plattformkoerper >= 1.81 halten
##   accents:  duenne Linien und Leuchtpunkte, muessen DUNKLER als der Spielerkern
##             bleiben (der Hintergrund leuchtet nie heller als der Spieler),
##             und sie duerfen nur schmal vorkommen
##
## Wer eine Farbe von `accents` nach `surfaces` verschiebt, muss sie abdunkeln —
## genau das war bei Z5_HAZARD noetig (Band ist eine Flaeche, nicht eine Linie).
static func zone45_surfaces() -> Dictionary:
	return {
		"Z4_PLATE": Z4_PLATE,
		"Z4_PLATE_DEEP": Z4_PLATE_DEEP,
		"Z4_SEAM": Z4_SEAM,
		"Z4_RAIL": Z4_RAIL,
		"Z5_PLATE": Z5_PLATE,
		"Z5_PLATE_DEEP": Z5_PLATE_DEEP,
		"Z5_HAZARD": Z5_HAZARD,
		"Z5_HOUSING": Z5_HOUSING,
	}

static func zone45_accents() -> Dictionary:
	return {
		"Z4_EDGE": Z4_EDGE,
		"Z4_CABLE_LIT": Z4_CABLE_LIT,
		"Z4_SPARK": Z4_SPARK,
		"Z4_RAIL_EDGE": Z4_RAIL_EDGE,
		"Z5_SEAM_GLOW": Z5_SEAM_GLOW,
		"Z5_STROBE": Z5_STROBE,
		"Z5_RAIL_EDGE": Z5_RAIL_EDGE,
	}

## Farbklassen der PERMANENTEN Anlage, gleiche Aufteilung wie bei Zone 4/5 und
## aus demselben Grund: die harte 1.81-Regel schuetzt FLAECHEN in der Ruhezone,
## nicht duenne Kanten und Lichtakzente. Waeren die Lichtkanten des Traegers als
## Flaeche eingeordnet, muessten sie auf einen Wert abgedunkelt werden, der die
## Kante unsichtbar macht — genau der Fehler, der die Randlaternen des Schachts
## seit jeher als "Regelbruch" gemeldet haette.
static func facility_surfaces() -> Dictionary:
	return {
		"FM_FAR_BLACK": FM_FAR_BLACK,
		"FM_WALL": FM_WALL,
		"FM_PANEL": FM_PANEL,
		"FM_SEAM": FM_SEAM,
		"FM_GIRDER": FM_GIRDER,
		"FM_HOLLOW": FM_HOLLOW,
		"FM_DUCT": FM_DUCT,
	}

static func facility_accents() -> Dictionary:
	return {
		"FM_GIRDER_LIT": FM_GIRDER_LIT,
		"FM_DUCT_LIT": FM_DUCT_LIT,
	}

## QA-Gegenprobe: schaltet Zeichnung UND Deckkraft der neuen Zonen ab. Wird nur
## von qa/zone45_cost_sweep.gd gesetzt — die Produktion liest es nie.
static var zone45_disabled := false
## Eigener Schalter fuer die Zonenmodule auf dem Anlagenraster (Zone 2/3), damit
## eine Kostenmessung ihre Wirkung von der der Zone-4/5-Schichten trennen kann.
## Eine Messung, die nur EINEN gemeinsamen Schalter kennt, kann nicht sagen,
## welche Schicht die Last verursacht.
static var sections_disabled := false

## Der Spielerkern als Messlatte fuer Akzente. `LAMP_CORE` wurde eigens auf
## d97b2a abgesenkt, weil die Randlaternen vorher heller waren als der Kern.
static func player_core_luminance() -> float:
	return LAMP_CORE.get_luminance()

static func draw_zone4(canvas: CanvasItem, visible_rect: Rect2, zone_index: float, time: float) -> void:
	if zone45_disabled:
		return
	var alpha := zone4_opacity_for_zone(zone_index)
	if alpha <= 0.0 or visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return
	var row_h := Z4_MODULE_HEIGHT / float(Z4_ROWS)
	for cell in zone4_cells(visible_rect):
		var plate: Rect2 = cell.rect
		if not plate.intersects(visible_rect):
			continue
		var shift := zone4_plate_shift(cell.n, cell.row, row_h)
		# Verschobene Platte: als Viereck mit gekippter Kante, nicht als Rechteck.
		canvas.draw_colored_polygon(
			PackedVector2Array([
				Vector2(plate.position.x + shift, plate.position.y),
				Vector2(plate.end.x + shift, plate.position.y),
				Vector2(plate.end.x - shift, plate.end.y),
				Vector2(plate.position.x - shift, plate.end.y),
			]), _fade(Z4_PLATE if shift > 0.0 else Z4_PLATE_DEEP, alpha))
		# Fuge zwischen zwei Platten: dunkel und durchgehend, sie ist die Naht.
		canvas.draw_rect(Rect2(Z4_FIELD_X, plate.end.y - 6.0, Z4_FIELD_WIDTH, 6.0), _fade(Z4_SEAM, alpha))
		# Kalte Kante auf der Hochseite: traegt die Lesbarkeit der Verschiebung.
		canvas.draw_rect(Rect2(Z4_FIELD_X, plate.position.y, Z4_FIELD_WIDTH, 4.0), _fade(Z4_EDGE, alpha))
		# Freiliegender Kabelstrang in der Fuge.
		for c in range(2):
			var cy: float = plate.end.y - 6.0 + float(c) * 3.0
			canvas.draw_line(Vector2(Z4_FIELD_X + 12.0, cy), Vector2(Z4_FIELD_X + Z4_FIELD_WIDTH - 12.0, cy), _fade(Z4_CABLE, alpha), 2.0)
	# Ein Kurzschluss je Modul, und nur an einem Platz ausserhalb der Ruhezone.
	var camera := visible_rect.get_center().y
	var base := tile_world_y(2, camera, 0)
	var first := int(floor((visible_rect.position.y - base) / Z4_MODULE_HEIGHT))
	var last := int(ceil((visible_rect.end.y - base) / Z4_MODULE_HEIGHT))
	for n in range(first, last + 1):
		if tile_pick(2, n, 41, 3) != 0:
			continue
		var sx: float = Z4_FIELD_X + 40.0 + tile_value(2, n, 42) * (Z4_FIELD_WIDTH - 90.0)
		var sy: float = base + float(n) * Z4_MODULE_HEIGHT + 60.0 + tile_value(2, n, 43) * (Z4_MODULE_HEIGHT - 130.0)
		if sy < visible_rect.position.y - 20.0 or sy > visible_rect.end.y + 20.0:
			continue
		var pulse := 0.55 + 0.45 * sin(time * 5.0 + float(n))
		canvas.draw_rect(Rect2(sx, sy, 26.0, 6.0), _fade(Z4_SPARK, alpha * pulse))
		canvas.draw_rect(Rect2(sx + 8.0, sy + 6.0, 10.0, 4.0), _fade(Z4_SPARK, alpha * pulse * 0.6))
	# Rechter Kabelkanal: ruhig, aber nicht leer.
	var rail := zone4_rail_span(visible_rect.size.x)
	canvas.draw_rect(Rect2(rail.x, visible_rect.position.y, rail.y - rail.x, visible_rect.size.y), _fade(Z4_RAIL, alpha))
	canvas.draw_rect(Rect2(rail.x, visible_rect.position.y, 4.0, visible_rect.size.y), _fade(Z4_RAIL_EDGE, alpha))
	for bracket in range(first, last + 1):
		var by: float = base + float(bracket) * Z4_MODULE_HEIGHT + 210.0
		if by + 26.0 < visible_rect.position.y or by > visible_rect.end.y:
			continue
		canvas.draw_rect(Rect2(rail.x - 16.0, by, rail.y - rail.x + 16.0, 26.0), _fade(Z4_PLATE_DEEP, alpha))

## Gefahrenband der Zone 5: zwei Schraegen als Vierecke. Dieselbe Bauart wie die
## Tuerverstrebungen — kein Huellbox-Rechteck, sonst wird aus der Schraege ein
## Block.
static func zone5_hazard_quads(x: float, y: float, width: float, height: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var step := 56.0
	var thickness := 16.0
	var travel := width + height
	var offset := 0.0
	while offset < travel:
		out.append(_diagonal_quad(
			Vector2(x + offset, y + height),
			Vector2(x + offset - height, y),
			thickness))
		offset += step
	return out

static func zone5_plate_rects(rect: Rect2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var module := Z5_MODULE_HEIGHT
	if module <= 0.0:
		return rects
	var camera := rect.get_center().y
	var base := tile_world_y(2, camera, 0)
	var first := int(floor((rect.position.y - base) / module))
	var last := int(ceil((rect.end.y - base) / module))
	for n in range(first, last + 1):
		rects.append(Rect2(Z5_FIELD_X, base + float(n) * module, Z5_FIELD_WIDTH, module * 0.5))
		rects.append(Rect2(Z5_FIELD_X, base + float(n) * module + module * 0.5, Z5_FIELD_WIDTH, module * 0.44))
	return rects

static func draw_zone5(canvas: CanvasItem, visible_rect: Rect2, zone_index: float, time: float) -> void:
	if zone45_disabled:
		return
	var alpha := zone5_opacity_for_zone(zone_index)
	if alpha <= 0.0 or visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return
	var plates := zone5_plate_rects(visible_rect)
	for plate in plates:
		if not plate.intersects(visible_rect):
			continue
		canvas.draw_rect(plate, _fade(Z5_PLATE, alpha))
		canvas.draw_rect(Rect2(plate.position.x, plate.position.y, plate.size.x, 5.0), _fade(Z5_RAIL_EDGE, alpha))
		for quad in zone5_hazard_quads(plate.position.x - 20.0, plate.position.y + 8.0, plate.size.x, plate.size.y * 0.34):
			canvas.draw_colored_polygon(quad, _fade(Z5_HAZARD, alpha))
		# Gluehende Naht am unteren Rand: schmal, mit ruhigem Puls.
		var seam_y: float = plate.end.y - 7.0
		var pulse := 0.78 + 0.22 * sin(time * 1.6 + plate.position.y * 0.004)
		canvas.draw_rect(Rect2(plate.position.x, seam_y, plate.size.x, 7.0), _fade(Z5_SEAM_GLOW, alpha * pulse))
		canvas.draw_rect(Rect2(plate.position.x, plate.end.y, plate.size.x, 8.0), _fade(Z5_PLATE_DEEP, alpha))
	# Notlichtgehaeuse: das Licht sitzt IM Kasten, nicht im leeren Schacht.
	var camera := visible_rect.get_center().y
	var base := tile_world_y(2, camera, 0)
	var first := int(floor((visible_rect.position.y - base) / Z5_MODULE_HEIGHT))
	var last := int(ceil((visible_rect.end.y - base) / Z5_MODULE_HEIGHT))
	for n in range(first, last + 1):
		if posmod(n, 2) != 0:
			continue
		var hy: float = base + float(n) * Z5_MODULE_HEIGHT + 96.0
		if hy + 120.0 < visible_rect.position.y or hy > visible_rect.end.y:
			continue
		var housing := Rect2(Z5_FIELD_X + 34.0, hy, 96.0, 112.0)
		canvas.draw_rect(housing, _fade(Z5_HOUSING, alpha))
		canvas.draw_rect(Rect2(housing.position.x + 8.0, housing.position.y + 10.0, 80.0, 5.0), _fade(Z5_RAIL_EDGE, alpha))
		canvas.draw_rect(Rect2(housing.position.x + 8.0, housing.end.y - 15.0, 80.0, 5.0), _fade(Z5_RAIL_EDGE, alpha))
		var blink := 0.35 + 0.65 * maxf(0.0, sin(time * 2.2 + float(n) * 1.7))
		canvas.draw_rect(Rect2(housing.position.x + 22.0, housing.position.y + 38.0, 52.0, 36.0), _fade(Z5_STROBE, alpha * blink))
	# Rechter Kanal, gleiche Bauart wie in Zone 4.
	var rail := zone4_rail_span(visible_rect.size.x)
	canvas.draw_rect(Rect2(rail.x, visible_rect.position.y, rail.y - rail.x, visible_rect.size.y), _fade(Z5_PLATE_DEEP, alpha))
	canvas.draw_rect(Rect2(rail.x, visible_rect.position.y, 4.0, visible_rect.size.y), _fade(Z5_RAIL_EDGE, alpha))

## ---------------------------------------------------------------------------
## Permanente Facility-Struktur — die gemeinsame Schachtarchitektur ALLER Zonen
## ---------------------------------------------------------------------------
##
## Bis hierher hatte jede Zone ihre eigene gestaltete Wand (Zone 1 Schacht, Zone 2
## Kuehlregister, Zone 3 Hochspannung, Zone 4/5 eigene Plattenfelder). Fuer sich
## genommen war jede richtig — zusammen las sich der Aufstieg aber wie ein Wechsel
## des Hintergrundbilds, nicht wie ein Weg durch EIN Bauwerk.
##
## Diese Schicht liegt deshalb GANZ HINTEN (vor der Zonenfarbe, hinter allen
## Zonenmodulen) und laeuft ueber alle fuenf Zonen durch. Sie liefert nur die
## Architektur: aeussere Stahlkonstruktion, dunkle Wandfelder, tiefe schwarze
## Hohlraeume, vertikale Versorgungsachse, wiederkehrende Wandfugen und
## gelegentliche Quertraeger. Die Zonen setzen ihre Technik darauf.
##
## Raster: 760 px, EXAKT das Raster der Fernwand des Reaktorschachts
## (`layer_tile_height(0) == 760`), und Slot s == Weltindex des Moduls. Ein
## Quertraeger der Anlage faellt damit mit einer Schachtfuge zusammen, statt
## irgendwo dazwischen zu liegen.
##
## Parallax: DIESELBE Formel wie die Fernwand (`tile_world_y(0, ...)`), damit die
## Anlage beim Scrollen exakt mit dem uebrigen Bauwerk laeuft. Ein eigenes Raster
## mit eigener Parallax waere genau der Fehler, den die Zone-2/3-Kacheln schon
## haben (siehe unten).
const FM_BAY := 760.0
const FM_FAR_BLACK := Color("010204")
const FM_WALL := Color("0a1016")
const FM_PANEL := Color("0b1218")
const FM_SEAM := Color("05090d")
const FM_GIRDER := Color("101820")
const FM_GIRDER_LIT := Color("39434b")
const FM_HOLLOW := Color("03050a")
const FM_DUCT := Color("020507")
const FM_DUCT_LIT := Color("46525c")
## Quertraeger: nur an diesen Slots, an denselben Stellen in jeder Zone.
const FM_CROSSING_SLOTS := [4, 11]
## Service-Sektion: Halter, Kabelpaket und eine schmale Maschinenachse links.
const FM_SERVICE_SLOTS := [2, 9]
## Einblendfenster. Es liegt VOLLSTAENDIG im Uebergang Zone 1 -> Zone 2
## (Index 0.55 .. 1.0): der Reaktorschacht der Zone 1 bleibt damit unveraendert,
## und wenn die Kuehlsektion voll traegt, traegt die Anlage ebenfalls voll.
## Die Anlage faengt bei der Ankunft in Zone 2 an zu tragen. Der Reaktorschacht
## der Zone 1 bringt dieselbe Bauform selbst mit (Stahltuer, Paneelfelder,
## Traegerachsen 0.09/0.20/0.80/0.91) — deshalb ist der Boden bewusst NICHT
## ueberzogen, sonst gaebe es dort zwei konkurrierende Wandstrukturen.
## Kein Ausblenden nach oben: die Anlage laeuft bis Zone 5 durch.
const FM_FADE_RAMP := 0.45

static func facility_opacity_for_zone(zone_index: float) -> float:
	if zone_index <= ZONE_FADE_START:
		return 0.0
	if zone_index >= ZONE_FADE_START + FM_FADE_RAMP:
		return 1.0
	return (zone_index - ZONE_FADE_START) / FM_FADE_RAMP

## Linke Kante des Wandfelds: halbe Randzone, damit die Traeger in GERAETEPIXELN
## dick genug bleiben (430 px Fenster -> Faktor 0,398; 16 Weltpixel = 6,4 px).
static func facility_left_edge(width: float) -> float:
	return (width * 0.5 - QUIET_HALF_WIDTH) * 0.5

## Aussenkante der Anlage (0 .. Breite mit Symmetrie).
static func facility_outer_span(width: float) -> Vector2:
	var left := facility_left_edge(width)
	return Vector2(left, width - left)

## Wandfeld zwischen den Traegern.
static func facility_wall_span(width: float) -> Vector2:
	var left := facility_left_edge(width)
	return Vector2(left + 26.0, width - left - 26.0)

## Vertikale Versorgungsachse rechts. Sie liegt AUSSERHALB der Ruhezone
## (linke Kante 852 > 800) und laeuft durch alle fuenf Zonen. Sie ist das
## rechteseitige Gegenstueck zur linken Wand: keine Spiegelung, sondern eine
## eigene Bauform (Kanal mit Lichtkante und Fuge).
static func facility_right_axis(width: float) -> float:
	return width - 228.0

static func facility_right_duct(width: float) -> Rect2:
	var x := facility_right_axis(width)
	return Rect2(x, 0.0, 56.0, FM_BAY)

## Rechtes Wandfeld: zwischen Ruhezone und Aussenachse. Es traegt die Paneelfelder
## und die rechten Hohlraeume — ohne dieses Feld waere die rechte Seite eine
## leere Flaeche (im Bild nachgemessen: dort war nichts als Schwarz).
static func facility_right_field(width: float) -> Vector2:
	var left := facility_left_edge(width)
	return Vector2(width * 0.5 + QUIET_HALF_WIDTH + 6.0, width - left - 26.0)

## Maschinenachse der Service-Sektion. Muss ausserhalb der Ruhezone liegen —
## x=300 lag mit 150 Breite bis 450 und damit IN der Spielbahn (gemessen beim
## ersten Testlauf).
static func facility_service_axis() -> float:
	return 34.0

## Weltposition der Oberkante eines Anlagenslots.
##
## NICHT `tile_world_y(0, ...)` benutzen: das rechnet mit der KACHELHOEHE der
## jeweiligen Ebene (760/640/900). Das Anlagenraster ist aber 760 hoch, mit
## eigener Parallaxformel — sonst laufen Raster und Zeichnung um 140 px je Slot
## auseinander (gemessen), und die Baender liegen nicht mehr auf den Slots.
static func facility_slot_top(camera: float, slot: int) -> float:
	return float(slot) * FM_BAY + scroll_offset(0, camera)

static func facility_crossing(slot: int) -> bool:
	return FM_CROSSING_SLOTS.has(posmod(slot, 12))

static func facility_service(slot: int) -> bool:
	return FM_SERVICE_SLOTS.has(posmod(slot, 12))

static func facility_bay_rect(width: float, camera: float, slot: int) -> Rect2:
	return Rect2(0.0, facility_slot_top(camera, slot), width, FM_BAY)

## Sichtbare Slots des Anlagenrasters. Gemeinsame Quelle fuer Zeichnung UND
## Pruefung — beim Rohr hatte ich zwei Stellen, von denen eine den Riegel umging.
static func facility_slots(rect: Rect2) -> Array[int]:
	var out: Array[int] = []
	var camera := rect.get_center().y
	var first := int(floor((rect.position.y - scroll_offset(0, camera)) / FM_BAY)) - 1
	var last := int(ceil((rect.end.y - scroll_offset(0, camera)) / FM_BAY)) + 1
	for slot in range(first, last + 1):
		out.append(slot)
	return out

## Tiefe schwarze Hohlraeume: schraege Kammern am Rand, zwischen den Traegern.
## Sie sind die senkrechte Gliederung der Anlage und in jeder Zone dieselben.
static func facility_hollow_quads(width: float, camera: float, slot: int) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var left := facility_left_edge(width)
	var top := facility_slot_top(camera, slot)
	var lean: float = 26.0 if posmod(slot, 2) == 0 else -26.0
	var right_field := facility_right_field(width)
	for side in [0, 1]:
		var dir_in: float = 1.0 if side == 0 else -1.0
		var x_outer: float = left + 34.0 if side == 0 else right_field.y - 14.0
		for row in range(3):
			# Der Riegel ist die EINZIGE Absicherung, und er ist LIVE: die Tiefe
			# ist mit 90..230 px so gewaehlt, dass die rechte Kammer ohne ihn bis
			# x=676 liefe — also quer durch die Spielbahn. Die erste Fassung hatte
			# nur 20..52 px Tiefe und erreichte die Ruhezone ohnehin nie; der
			# Riegel war toter Code, die Mutationsprobe hat ihn entlarvt.
			var t: float = 90.0 + float(row) * 70.0
			var x_in: float = x_outer + t * dir_in
			if minf(x_in, x_outer) <= width * 0.5 + QUIET_HALF_WIDTH:
				continue
			var y_top: float = top + 60.0 + float(row) * 230.0
			var y_bottom: float = y_top + 150.0
			out.append(PackedVector2Array([
				Vector2(x_outer, y_top),
				Vector2(x_in, y_top + lean),
				Vector2(x_in, y_bottom + lean),
				Vector2(x_outer, y_bottom),
			]))
	return out

## Paneelfelder der Wand. Gleiche Lage und Breite wie im Reaktorschacht
## (`panel_field_span`/`_draw_far_layer`), damit die Zonen auf DERSELBEN Wand
## sitzen. Drei Felder je Bucht, 210 hoch: keine Mini-Details.
static func facility_panel_rects(width: float, camera: float, slot: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var top := facility_slot_top(camera, slot)
	var left := facility_left_edge(width)
	var right_field := facility_right_field(width)
	# Zwei Wandfelder, je zwei Spalten mit dunkler Fuge dazwischen und drei
	# Platten uebereinander. Die Fugen sind die Gliederung: die Platten selbst
	# sind fast so dunkel wie die Wand, gelesen wird die Rasterung.
	var fields := [Vector2(left + 26.0, left + 134.0), right_field]
	for field in fields:
		for col in range(2):
			var x: float = field.x + float(col) * 58.0
			var w: float = field.y - field.x if col == 0 else field.y - (field.x + 58.0)
			w = minf(w, 50.0)
			if w <= 8.0:
				continue
			for row in range(3):
				out.append(Rect2(x, top + 8.0 + float(row) * 250.0, w, 236.0))
	return out

## Traegerlaeufe einer Bucht: die zwei durchgehenden Aussenachsen, dazu je nach
## Slot ein Quertraeger ueber die volle Breite oder eine schmale Maschinenachse.
## Der Quertraeger darf die Ruhezone queren — er ist die Segmentkante des
## Bauwerks, keine gesetzte Einzelheit. Genau wie die waagerechte Bandfuge im
## Reaktorschacht, die aus demselben Grund ueber die volle Breite laeuft.
static func facility_girder_runs(width: float, camera: float, slot: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var left := facility_left_edge(width)
	var top := facility_slot_top(camera, slot)
	out.append(Rect2(left, top, 16.0, FM_BAY))
	out.append(Rect2(width - left - 16.0, top, 16.0, FM_BAY))
	# Querfuge auf halber Bucht: die waagerechte Gliederung der Wand.
	out.append(Rect2(left, top + 380.0, width - 2.0 * left, 8.0))
	if facility_crossing(slot):
		out.append(Rect2(left, top + FM_BAY - 30.0, width - 2.0 * left, 30.0))
	if facility_service(slot):
		out.append(Rect2(facility_service_axis(), top, 120.0, FM_BAY))
	return out

static func facility_duct_rects(width: float, camera: float, slot: int) -> Array[Rect2]:
	return [Rect2(facility_right_axis(width), facility_slot_top(camera, slot), 64.0, FM_BAY)]

## Sichtbare Uebergangsabschnitte: die Bucht, in der eine Zonengrenze liegt.
##
## Die Ankerung ist der subtile Teil. Inhalt der Fernschicht wandert nur mit dem
## Anteil p der Kamerabewegung (`layer_parallax(0) = 0.22`). Wird der Abschnitt
## einfach an die Weltkoordinate der Grenze gesetzt, ist er beim Grenzuebertritt
## laengst aus dem Bild gelaufen — gemessen: null sichtbare Uebergaenge bei den
## Grenzen 1 bis 3 (nur die letzte lag zufaellig im Ausschnitt). Die Lage wird
## deshalb aus dem Anteil p hergeleitet, so dass der Abschnitt genau dann in der
## Bildmitte steht, wenn die Grenze den oberen Bildrand erreicht — also beim
## Eintritt in die neue Zone.
##
## Der Slot ist damit eine reine Funktion der Grenze (kein Kamera-Einfluss): er
## springt beim Scrollen nicht zwischen zwei Zellen hin und her.
##
## Ebene: die NAHE (0.62), nicht die Fernwand. In der Fernwand liegen alle vier
## Grenzen wegen der Stauchung nur rund einen Slot auseinander — gemessen waren
## bei einer Grenze alle VIER Uebergaenge gleichzeitig im Bild, der Uebergang
## also ueberall. In der nahen Ebene liegen sie ~3 Slots auseinander, und der
## Abschnitt steht genau dann im Bild, wenn die Grenze ueberschritten wird.
static func facility_transition_slot(boundary: float, view_height: float) -> int:
	var center := -JumpConfig.zone_height_for_index(boundary) + view_height * 0.5
	return int(round(layer_parallax(2) * center / FM_BAY))

## Weltoberkante der Bucht, in der ein Uebergang liegt. Nutzt dasselbe Raster wie
## die Zonenmodule (nahe Ebene), damit Uebergangsbauwerk und Technik nicht
## gegeneinander laufen.
static func facility_transition_bay_rect(width: float, rect: Rect2, boundary: float) -> Rect2:
	return Rect2(0.0, section_top(rect.get_center().y, facility_transition_slot(boundary, rect.size.y)), width, FM_BAY)

static func facility_transition_bays(rect: Rect2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var camera := rect.get_center().y
	for boundary in [1.0, 2.0, 3.0, 4.0]:
		var slot := facility_transition_slot(boundary, rect.size.y)
		var bay := facility_transition_bay_rect(rect.size.x, rect, boundary)
		if not bay.intersects(rect):
			continue
		out.append({"slot": slot, "boundary": boundary, "bay": bay})
	return out

## Zeichnet den Uebergangsabschnitt: Quertraeger, Wartungsschleuse, technisches
## Schild und ein beginnendes Kabelbuendel. Damit ist der Zonenwechsel ein Ort,
## den man passiert — nicht nur ein Alpha-Verlauf.
static func draw_facility_transitions(canvas: CanvasItem, visible_rect: Rect2, zone_index: float) -> void:
	if zone45_disabled or sections_disabled:
		return
	var alpha := facility_opacity_for_zone(zone_index)
	if alpha <= 0.0 or visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return
	var width := 1080.0
	for entry in facility_transition_bays(visible_rect):
		var bay: Rect2 = entry.bay
		var boundary: float = entry.boundary
		var span := facility_outer_span(width)
		# Grosser Quertraeger ueber die volle Breite.
		canvas.draw_rect(Rect2(span.x, bay.position.y, span.y - span.x, 34.0), _fade(FM_GIRDER, alpha))
		canvas.draw_rect(Rect2(span.x, bay.position.y, span.y - span.x, 5.0), _fade(FM_GIRDER_LIT, alpha))
		# Wartungsschleuse links, im Wandfeld — ausserhalb der Ruhezone.
		var door := Rect2(span.x + 24.0, bay.position.y + 70.0, 210.0, 520.0)
		canvas.draw_rect(door, _fade(DOOR_PANEL, alpha))
		canvas.draw_rect(Rect2(door.position.x + door.size.x * 0.5 - 4.0, door.position.y, 8.0, door.size.y), _fade(DOOR_PANEL_DEEP, alpha))
		for dir in [-1.0, 1.0]:
			var x_from: float = door.position.x + door.size.x * 0.5 + dir * (door.size.x * 0.5 - 24.0)
			canvas.draw_colored_polygon(_diagonal_quad(
				Vector2(x_from, door.position.y + 60.0),
				Vector2(x_from - dir * (door.size.x - 48.0), door.end.y - 60.0),
				8.0), _fade(DOOR_BRACE, alpha))
		# Technisches Schild: die Farbe des NEUEN Bereichs, sehr dunkel.
		var next_zone := clampi(int(boundary), 0, JumpConfig.ZONE_SHAFT_COLORS.size() - 1)
		var sign_color: Color = JumpConfig.ZONE_SHAFT_COLORS[next_zone]
		var sign := Rect2(door.position.x + 34.0, door.end.y + 26.0, 142.0, 30.0)
		canvas.draw_rect(sign, _fade(DOOR_PANEL_DEEP, alpha))
		canvas.draw_rect(Rect2(sign.position.x + 6.0, sign.position.y + 8.0, sign.size.x - 12.0, 14.0), _fade(sign_color, alpha))
		# Kabelbuendel beginnt: drei Straenge ueber die Buchtbreite.
		for cable in range(3):
			var cy: float = bay.end.y - 96.0 + float(cable) * 14.0
			canvas.draw_line(Vector2(span.x + 18.0, cy), Vector2(span.y - 18.0, cy), _fade(FM_SEAM, alpha), 6.0)

## Die Anlage selbst: eine sehr dunkle Grundflaeche, Wandfelder, Traeger,
## Hohlraeume, die vertikale Versorgungsachse und die Wandfugen. Sie liefert
## NUR Architektur — kein warmes Licht, keine zonenspezifische Technik.
static func draw_facility(canvas: CanvasItem, visible_rect: Rect2, zone_index: float) -> void:
	if zone45_disabled or sections_disabled:
		return
	var alpha := facility_opacity_for_zone(zone_index)
	if alpha <= 0.0 or visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return
	var width := 1080.0
	var camera := visible_rect.get_center().y
	for slot in facility_slots(visible_rect):
		var bay := facility_bay_rect(width, camera, slot)
		if not bay.intersects(visible_rect):
			continue
		var top := bay.position.y
		var span := facility_outer_span(width)
		var wall := facility_wall_span(width)
		# Grund: tiefes Schwarz aussen, geschlossene Wand innen.
		canvas.draw_rect(Rect2(0.0, top, width, FM_BAY), _fade(FM_FAR_BLACK, alpha))
		canvas.draw_rect(Rect2(wall.x, top, wall.y - wall.x, FM_BAY), _fade(FM_WALL, alpha))
		for panel in facility_panel_rects(width, camera, slot):
			canvas.draw_rect(panel, _fade(FM_PANEL, alpha))
		# Vertikale Versorgungsachse rechts — laeuft durch alle fuenf Zonen.
		for duct in facility_duct_rects(width, camera, slot):
			canvas.draw_rect(duct.grow(6.0), _fade(FM_SEAM, alpha))
			canvas.draw_rect(duct, _fade(FM_DUCT, alpha))
			canvas.draw_rect(Rect2(duct.position.x + 8.0, duct.position.y, 19.0, duct.size.y), _fade(FM_DUCT_LIT, alpha))
			canvas.draw_rect(Rect2(duct.position.x + 36.0, duct.position.y, 7.0, duct.size.y), _fade(FM_SEAM, alpha))
		# Traeger. Die Aussenachsen bekommen eine Lichtkante nach innen — das ist
		# der Unterschied zwischen "Balken" und "Farbflaeche".
		for run in facility_girder_runs(width, camera, slot):
			canvas.draw_rect(run, _fade(FM_GIRDER, alpha))
		canvas.draw_rect(Rect2(span.x + 16.0, top, 5.0, FM_BAY), _fade(FM_GIRDER_LIT, alpha))
		canvas.draw_rect(Rect2(span.y - 21.0, top, 5.0, FM_BAY), _fade(FM_GIRDER_LIT, alpha))
		# Hohlraeume zuletzt: sie sind die Tiefe, nicht die Flaeche.
		for quad in facility_hollow_quads(width, camera, slot):
			canvas.draw_colored_polygon(quad, _fade(FM_HOLLOW, alpha))
		if facility_service(slot):
			var axis := facility_service_axis()
			canvas.draw_rect(Rect2(axis, top + 150.0, 130.0, 18.0), _fade(FM_GIRDER, alpha))
			canvas.draw_rect(Rect2(axis, top + 150.0, 130.0, 4.0), _fade(FM_GIRDER_LIT, alpha))
			canvas.draw_rect(Rect2(axis + 30.0, top + 300.0, 74.0, 92.0), _fade(FM_SEAM, alpha))

static func draw(canvas: CanvasItem, visible_rect: Rect2, zone_index: float, time: float) -> void:
	var alpha := opacity_for_zone(zone_index)
	if alpha <= 0.0 or visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return
	var width := 1080.0
	_draw_far_layer(canvas, visible_rect, width, alpha, time)
	_draw_mid_layer(canvas, visible_rect, width, alpha, time)
	_draw_near_layer(canvas, visible_rect, width, alpha, time)
	_draw_atmosphere(canvas, visible_rect, time, alpha)

## Gemeinsame Geometrie fuer Zeichnung UND Tests. Vollstaendige Umrisse,
## nicht nur Mittelpunkte: kein Flansch darf in die Ruhezone hineinragen.
static func machinery_rect(width: float, side: float, top: float) -> Rect2:
	var x := 72.0 if side < 0.0 else width - 212.0
	return Rect2(x, top, 140.0, 252.0)

static func lamp_surface(width: float, side: float, top: float) -> Rect2:
	var machine := machinery_rect(width, side, top)
	return Rect2(machine.position + Vector2(12.0 if side < 0.0 else 28.0, 12.0), Vector2(100.0, 184.0))

static func foreground_pipe_span(width: float, side: float) -> Vector2:
	return Vector2(18.0, 90.0) if side < 0.0 else Vector2(width - 90.0, width - 18.0)

static func deck_rect(width: float, side: float, top: float) -> Rect2:
	return Rect2(82.0 if side < 0.0 else width - 264.0, top, 182.0, 72.0)

static func pipe_light_surface(width: float, side: float, top: float) -> Rect2:
	var span := foreground_pipe_span(width, side)
	return Rect2(span.x + (32.0 if side < 0.0 else 8.0), top - 160.0, 40.0, 178.0)

static func inner_pipe_span(width: float, side: float) -> Vector2:
	return Vector2(206.0, 276.0) if side < 0.0 else Vector2(width - 276.0, width - 206.0)

static func flange_rect(width: float, side: float, top: float) -> Rect2:
	return Rect2(foreground_pipe_span(width, side).x - 8.0, top, 96.0, 40.0)

## Schwarze Hohlraeume hinter der Technik, geschlossene dunkle Stahlwand.
## Keine warmen Pixel oder technischen Einzelheiten in der Spielbahn.
static func _draw_far_layer(canvas: CanvasItem, visible_rect: Rect2, width: float, alpha: float, _time: float) -> void:
	canvas.draw_rect(visible_rect, _fade(Color("010101"), alpha))
	canvas.draw_rect(Rect2(324.0, visible_rect.position.y, width - 648.0, visible_rect.size.y), _fade(FAR_WALL, alpha))
	for side in [-1.0, 1.0]:
		var span := panel_field_span(width, side)
		canvas.draw_rect(Rect2(span.x + (86.0 if side < 0.0 else 20.0), visible_rect.position.y, span.y - span.x - 106.0, visible_rect.size.y), _fade(FAR_PANEL, alpha))
	for axis in girder_axes(width):
		canvas.draw_rect(Rect2(axis - 8.0, visible_rect.position.y, 16.0, visible_rect.size.y), _fade(Color("141b20"), alpha))
	var camera := visible_rect.get_center().y
	var first := first_visible_tile(0, camera, visible_rect.position.y)
	var count := visible_tile_count(0, camera, visible_rect.position.y, visible_rect.end.y)
	for offset in range(count):
		var index := first + offset
		var top := tile_world_y(0, camera, index)
		_draw_facility_module(canvas, index, top, alpha)

## Upward order at the playable entry: A B C D B. Longer blocks vary C/D
## placement, while doors have at least three solid bays between them.
## Identity is ONLY a world index, never the camera-shifted drawing coordinate.
static func module_kind(index: int) -> int:
	var upward := -index
	var slot := posmod(upward, 12)
	if slot == 0 or slot == 7:
		return 0 # A: door
	if slot == 2:
		return 2 # C: maintenance
	if slot == 3:
		return 3 # D: service, reachable before zone fade
	if slot == 9:
		return 2 + tile_pick(0, int(floor(float(upward) / 12.0)), 91, 2)
	return 1 # B: quiet closed panel

static func _draw_facility_module(canvas: CanvasItem, index: int, top: float, alpha: float) -> void:
	var kind := module_kind(index)
	var bay := door_rect(top)
	if kind == 0:
		_draw_door_frame(canvas, top, alpha)
		return
	canvas.draw_rect(bay, _fade(DOOR_BASE if kind == 1 else DOOR_PANEL_DEEP, alpha))
	# Closed panels have no centre seam, repeated X, or luminous centre marks.
	var joint := top + 180.0 + tile_value(0, index, 88) * 380.0
	canvas.draw_rect(Rect2(280.0, joint, 520.0, 8.0), _fade(DOOR_BRACE, alpha))
	if kind == 2:
		# Wartungsstruktur: eine lange Schraege plus ein breiter Laufsteg-Rost.
		# Große Formen statt Kleinteile — der Rost ist in Geraetepixeln ~18 hoch.
		canvas.draw_colored_polygon(_diagonal_quad(Vector2(296, top + 120), Vector2(782, top + 400), 22), _fade(DOOR_BRACE, alpha))
		canvas.draw_rect(Rect2(280, top + 470, 520, 46), _fade(DOOR_PANEL, alpha))
		canvas.draw_rect(Rect2(280, top + 470, 520, 8), _fade(DOOR_BRACE, alpha))
		canvas.draw_rect(Rect2(280, top + 508, 520, 8), _fade(DOOR_BRACE, alpha))
		for slot in range(3):
			canvas.draw_rect(Rect2(300 + slot * 160, top + 488, 120, 12), _fade(DOOR_BRACE, alpha))
	elif kind == 3:
		# Technische Wartungssektion: eingelassenes Servicefeld mit zwei breiten
		# Schienen und dunkler Mittelnaht — deutlich anders als das ruhige Panel B.
		canvas.draw_rect(Rect2(314, top + 100, 452, 520), _fade(DOOR_PANEL, alpha))
		canvas.draw_rect(Rect2(332, top + 124, 416, 472), _fade(DOOR_BASE, alpha))
		for rail in range(2):
			var rail_y: float = top + 200.0 + float(rail) * 250.0
			canvas.draw_rect(Rect2(332, rail_y, 416, 48), _fade(DOOR_PANEL, alpha))
			canvas.draw_rect(Rect2(332, rail_y + 42.0, 416, 24), _fade(DOOR_BRACE, alpha))
		canvas.draw_rect(Rect2(524, top + 124, 20, 472), _fade(DOOR_BRACE, alpha))

## Massive Stahltuer in der Spielmitte: ruhige, grosse, dunkle Flaechen mit
## sehr geringem Kontrast, keine Maschinen. Sie ist die Wand selbst, keine
## Technik — deshalb darf sie (wie die Fuge) in der Ruhezone liegen.
static func door_rect(top: float) -> Rect2:
	return Rect2(280.0, top, 520.0, 760.0)

## Zwei Blattflaechen links und rechts neben der Mittelritze. Zwischen ihnen
## bleibt die (bereits gezeichnete) Schachtfuge sichtbar: die Ritze selbst.
static func door_leaf_rects(top: float) -> Array[Rect2]:
	var door := door_rect(top)
	var half := door.size.x * 0.5
	return [
		Rect2(door.position.x, top, half - DOOR_GAP * 0.5, door.size.y),
		Rect2(door.position.x + half + DOOR_GAP * 0.5, top, half - DOOR_GAP * 0.5, door.size.y),
	]

## Zwei durchgehende Verstrebungen als X: von der oberen Aussenecke diagonal
## zur gegenueberliegenden unteren. Kanten statt Flaechen, dunkel auf dem hellen
## Blatt — das traegt die Tuerlesbarkeit (2.0 statt 1.0 Kontrast). Zwei lange
## Vierecke statt vier kurzer: gleiche Lesbarkeit, halbe Zeichenlast.
static func door_brace_quads(top: float) -> Array[PackedVector2Array]:
	var door := door_rect(top)
	var half := door.size.x * 0.5
	var cx := door.position.x + half
	var y_top := top + door.size.y * 0.24
	var y_bottom := top + door.size.y * 0.76
	var inset := 30.0
	var out: Array[PackedVector2Array] = []
	for dir in [-1.0, 1.0]:
		out.append(_diagonal_quad(
			Vector2(cx + dir * (half - inset), y_top),
			Vector2(cx - dir * (half - inset), y_bottom),
			9.0))
	return out

## Huellboxen der Verstrebungen, nur fuer Geometriepruefungen.
static func door_brace_bounds(top: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for quad in door_brace_quads(top):
		var r := Rect2(quad[0], Vector2.ZERO)
		for p in quad:
			r = r.expand(p)
		out.append(r)
	return out

## Schraeges Balkenstueck als geschlossenes Viereck (dick in der Normalen).
static func _diagonal_quad(a: Vector2, b: Vector2, thickness: float) -> PackedVector2Array:
	var n := (b - a).orthogonal().normalized() * (thickness * 0.5)
	return PackedVector2Array([a + n, b + n, b - n, a - n])

static func _draw_door_frame(canvas: CanvasItem, top: float, alpha: float) -> void:
	var door := door_rect(top)
	# Grundlage: hellstes Blatt (Obergrenze der Regel). Es bestimmt die Lesbarkeit
	# gegen den dunklen Reaktorraum. Die beiden Blatthaaelften sind dieselbe
	# Flaeche in derselben Farbe und werden deshalb NICHT einzeln gezeichnet.
	canvas.draw_rect(door, _fade(DOOR_PANEL, alpha))
	var cx := door.position.x + door.size.x * 0.5
	# Mittelritze: dunkle Naht, trennt die beiden Blatthaaelften.
	canvas.draw_rect(Rect2(cx - DOOR_GAP * 0.5, top, DOOR_GAP, door.size.y), _fade(DOOR_PANEL_DEEP, alpha))
	# Eine Querfuge je Blattseite teilt die Blatter in Ebenen und betont den
	# Querriegel des Zielbilds. Zwei Waagerechte (statt vier): halbe Last.
	var y_fuge := top + door.size.y * 0.5
	for dir in [-1.0, 1.0]:
		var x_start: float = cx + dir * (DOOR_GAP * 0.5 + 6.0) if dir > 0.0 else door.position.x + 18.0
		var x_end: float = door.end.x - 18.0 if dir > 0.0 else cx - DOOR_GAP * 0.5 - 6.0
		canvas.draw_rect(Rect2(x_start, y_fuge, x_end - x_start, 5.0), _fade(DOOR_PANEL_DEEP, alpha))
	# Verstrebungen als X — die eigentliche Tuerlesbarkeit. Dunkle Baender gegen
	# das helle Blatt (2.0) statt heller Baender gegen dunkles Blatt (1.0).
	for quad in door_brace_quads(top):
		canvas.draw_colored_polygon(quad, _fade(DOOR_BRACE, alpha))

## Compatibility for earlier geometry probes. Central pearls were removed;
## the replacement assertion is in shaft_composition_test.gd.
static func pearl_segments(_top: float) -> Array[Rect2]:
	return []

## Breite Zylinder hinter den Einbaugeraeten. Schwarze Luecken bleiben offen.
static func _draw_mid_layer(canvas: CanvasItem, visible_rect: Rect2, width: float, alpha: float, time: float) -> void:
	# One continuous cable duct on the left; the right gets two large cylinders.
	_shaded_rect(canvas, Rect2(132, visible_rect.position.y, 128, visible_rect.size.y), Color("030609"), Color("182129"), alpha)
	for body in right_conduit_rects(visible_rect):
		canvas.draw_rect(body, _fade(Color("020405"), alpha))
		var lit_w: float = body.size.x * 0.30
		_shaded_rect(canvas, Rect2(body.position.x + 10.0, body.position.y, lit_w, body.size.y), Color("080d12"), Color("5c7178"), alpha)
		_shaded_rect(canvas, Rect2(body.position.x + lit_w + 14.0, body.position.y, 7.0, body.size.y), Color("4a5f68"), Color("4a5f68"), alpha)
		_shaded_rect(canvas, Rect2(body.position.x + lit_w + 21.0, body.position.y, body.size.x - lit_w - 21.0, body.size.y), Color("03070a"), Color("03070a"), alpha)
	var camera := visible_rect.get_center().y
	var first := first_visible_tile(1, camera, visible_rect.position.y)
	var count := visible_tile_count(1, camera, visible_rect.position.y, visible_rect.end.y)
	for offset in range(count):
		var index := first + offset
		var top := tile_world_y(1, camera, index)
		if posmod(index, 2) == 0:
			# Widely spaced heavy mounting saddles interrupt the clean cylinders.
			var collar := Rect2(906, top + 390, 162, 88)
			if collar.intersects(visible_rect):
				canvas.draw_rect(collar.grow(8), _fade(Color("020405"), alpha))
				_shaded_rect(canvas, collar, Color("293640"), Color("080c10"), alpha)
				canvas.draw_rect(Rect2(914, top + 394, 138, 10), _fade(Color("4b514d"), alpha))
				canvas.draw_rect(Rect2(962, top + 418, 100, 46), _fade(Color("10181e"), alpha))
		if posmod(index, 4) != 0:
			continue
		var side := -1.0 if posmod(index, 8) == 0 else 1.0
		var body := machinery_rect(width, side, top + 110)
		if body.intersects(visible_rect):
			canvas.draw_rect(body.grow(6), _fade(Color("020405"), alpha))
			_draw_inset_light(canvas, lamp_surface(width, side, top + 110), time + float(index), alpha, 0)

static func right_conduit_rects(rect: Rect2) -> Array[Rect2]:
	return [Rect2(912, rect.position.y, 64, rect.size.y), Rect2(990, rect.position.y, 72, rect.size.y)]

## At most one steam plume and one metal reflection, globally (not per bay).
## Candidate ownership is fixed to mid-layer indices; time only changes opacity.
static func atmosphere_events(rect: Rect2, time: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var camera := rect.get_center().y
	var first := first_visible_tile(1, camera, rect.position.y)
	var count := visible_tile_count(1, camera, rect.position.y, rect.end.y)
	for offset in range(count):
		var index := first + offset
		if posmod(index, 3) != 0:
			continue
		var top := tile_world_y(1, camera, index)
		var phase := fposmod(time + float(posmod(index, 5)), 18.0)
		if phase < 5.0:
			var r := Rect2(142, top + 150 - phase * 12, 110, 100)
			if r.intersects(rect):
				events.append({"rect": r, "strength": sin(phase / 5.0 * PI) * 0.035, "warm": false})
				break
	for offset in range(count):
		var index := first + offset
		var phase := fposmod(time + float(posmod(index, 7)), 23.0)
		if posmod(index, 4) == 0 and phase < 4.0:
			var r := Rect2(996, tile_world_y(1, camera, index) + 250, 52, 210)
			if r.intersects(rect):
				events.append({"rect": r, "strength": sin(phase / 4.0 * PI) * 0.12, "warm": true})
				break
	return events

static func _draw_atmosphere(canvas: CanvasItem, rect: Rect2, time: float, alpha: float) -> void:
	for event in atmosphere_events(rect, time):
		var r: Rect2 = event.rect
		var color := Color("9d612b") if event.warm else STEAM
		# Three nested translucent sheets, fixed primitive count and bounded footprint.
		for inset in range(3):
			_shaded_rect(canvas, r.grow(-float(inset) * 10), Color(color, 0), color, alpha * float(event.strength) / 3.0)

## Licht sitzt IM Metallkasten. Breite warme Reflexflaechen, dunkle Fassung,
## zwei eingelassene Leuchtfenster; kein Schein im leeren Schacht.
static func _draw_inset_light(canvas: CanvasItem, surface: Rect2, phase: float, alpha: float, variant: int = 0) -> void:
	var p := surface.position
	var flicker := 0.96 + 0.04 * sin(phase * 0.7)
	# Lichtgradienten bleiben innerhalb der existierenden Metallflaeche.
	_shaded_rect(canvas, surface, Color("503018"), Color("0d1011"), alpha)
	_shaded_rect(canvas, Rect2(p + Vector2(6.0, 8.0), Vector2(32.0, 154.0)), Color("62401f"), Color("ad6b28"), alpha * flicker)
	_shaded_rect(canvas, Rect2(p + Vector2(38.0, 8.0), Vector2(48.0, 154.0)), Color("ad6b28"), Color("030609"), alpha * flicker)
	if variant == 1:
		# Rueckbeleuchteter Luefter: grosses warmes Volumen, schwarze Rotorarme
		# als schlanke Rechtecke statt teurem Polygon (Primitive-Budget).
		var center := p + Vector2(46.0, 80.0)
		canvas.draw_rect(Rect2(center - Vector2(26.0, 26.0), Vector2(52.0, 5.0)), _fade(Color("080a09"), alpha))
		canvas.draw_rect(Rect2(center - Vector2(26.0, 21.0), Vector2(52.0, 5.0)), _fade(Color("131513"), alpha))
		canvas.draw_rect(Rect2(center - Vector2(2.0, 26.0), Vector2(5.0, 52.0)), _fade(Color("080a09"), alpha))
		canvas.draw_rect(Rect2(center - Vector2(10.0, 10.0), Vector2(20.0, 20.0)), _fade(Color("443820"), alpha))
	elif variant == 2:
		canvas.draw_rect(Rect2(p + Vector2(16.0, 38.0), Vector2(60.0, 70.0)), _fade(Color("110e09"), alpha))
		for slit in range(3):
			canvas.draw_rect(Rect2(p + Vector2(22.0, 44.0 + slit * 20.0), Vector2(48.0, 10.0)), _fade(LAMP_CORE, alpha * flicker))
	else:
		canvas.draw_rect(Rect2(p + Vector2(26.0, 29.0), Vector2(38.0, 106.0)), _fade(Color("140f09"), alpha))
		canvas.draw_rect(Rect2(p + Vector2(32.0, 35.0), Vector2(24.0, 40.0)), _fade(LAMP_CORE, alpha * flicker))
		canvas.draw_rect(Rect2(p + Vector2(32.0, 83.0), Vector2(24.0, 42.0)), _fade(LAMP_CORE, alpha * flicker))
	canvas.draw_rect(Rect2(p + Vector2(9.0, 22.0), Vector2(5.0, 110.0)), _fade(Color("af7031"), alpha))

## Zwei Dreiecke mit Vertexfarben: Materiallicht ohne Textur/Shader/Node.
static func _shaded_rect(canvas: CanvasItem, rect: Rect2, left: Color, right: Color, alpha: float) -> void:
	var p := rect.position
	var e := rect.end
	canvas.draw_primitive(PackedVector2Array([p, Vector2(e.x, p.y), e, Vector2(p.x, e.y)]), PackedColorArray([_fade(left, alpha), _fade(right, alpha), _fade(right, alpha), _fade(left, alpha)]), PackedVector2Array())

## Vorderste Rohrmasse dunkler und schaerfer als hintere Gehaeuse.
static func _draw_near_layer(canvas: CanvasItem, visible_rect: Rect2, width: float, alpha: float, _time: float) -> void:
	var camera := visible_rect.get_center().y
	var module := pipe_module_rect(camera)
	for side in [-1.0, 1.0]:
		var span := foreground_pipe_span(width, side)
		if side > 0.0:
			continue # Right mass belongs to the continuous double conduit.
		# Nahe Ebene: die LINKE Rohrspalte wird vollstaendig aus der nahtlosen
		# Kachel aufgebaut (durchgehendes Rohr, eigener Flansch in der Textur).
		# Die rechte Spalte ist KEIN Spiegel: dort laufen zwei große Kabelkanaele
		# der mittleren Ebene durch, hier nur ihre dunkle Randmaske.
		if pipe_tile_enabled and side == PIPE_TILE_SIDE:
			_draw_pipe_tiles(canvas, visible_rect, alpha)
			continue
		for segment in pipe_body_segments(visible_rect, side):
			canvas.draw_rect(Rect2(span.x, segment.x, span.y - span.x, segment.y), _fade(Color("030507"), alpha))
			_shaded_rect(canvas, Rect2(span.x + 10.0, segment.x, 34.0, segment.y), Color("06090c"), Color("1a2024"), alpha)
			_shaded_rect(canvas, Rect2(span.x + 44.0, segment.x, 28.0, segment.y), Color("1a2024"), Color("070a0c"), alpha)
			canvas.draw_rect(Rect2(span.x + (64.0 if side < 0.0 else 10.0), segment.x, 6.0, segment.y), _fade(Color("32312b"), alpha))
	# Einzelmodul-Prototyp (QA-Referenz) liegt vor Stegen, Ventilen und Randmaske.
	if pipe_module_enabled and module.intersects(visible_rect):
		_draw_pipe_module(canvas, module.position.y, alpha)
	var first := first_visible_tile(2, camera, visible_rect.position.y)
	var count := visible_tile_count(2, camera, visible_rect.position.y, visible_rect.end.y)
	for offset in range(count):
		var index := first + offset
		var top := tile_world_y(2, camera, index)
		for side in [-1.0, 1.0]:
			if posmod(index, 4) != 1 or side > 0.0:
				continue
			var span := foreground_pipe_span(width, side)
			for band in range(3):
				if pipe_tile_enabled and side == PIPE_TILE_SIDE:
					continue
				if pipe_module_enabled and index == PIPE_INSTANCE_INDEX and band == PIPE_INSTANCE_BAND and side == PIPE_INSTANCE_SIDE:
					continue
				var y := top + band * 300.0 + (90.0 if side > 0.0 else 0.0)
				if y + 40.0 < visible_rect.position.y or y > visible_rect.end.y:
					continue
				canvas.draw_rect(flange_rect(width, side, y), _fade(Color("020304"), alpha))
				canvas.draw_rect(Rect2(span.x - 4.0, y + 4.0, 88.0, 23.0), _fade(Color("1c2329"), alpha))
				canvas.draw_rect(Rect2(span.x + 8.0, y + 5.0, 68.0, 4.0), _fade(Color("4b4434"), alpha))
			var deck := deck_rect(width, side, top + (230.0 if side < 0.0 else 610.0))
			var lit := pipe_light_surface(width, side, deck.position.y)
			if lit.intersects(visible_rect):
				_shaded_rect(canvas, lit, Color("272016"), Color("90541f"), alpha)
				canvas.draw_rect(Rect2(lit.position + Vector2(8.0, 50.0), Vector2(18.0, 52.0)), _fade(Color("0a0b08"), alpha))
				canvas.draw_rect(Rect2(lit.position + Vector2(12.0, 56.0), Vector2(10.0, 40.0)), _fade(LAMP_CORE, alpha))
			if deck.grow(48.0).intersects(visible_rect):
				_draw_deck(canvas, deck, alpha)
		var side := -1.0 if tile_pick(2, index, 8, 2) == 0 else 1.0
		var center := valve_center(width, side, top)
		if posmod(index, 7) == 3 and center.y - 36.0 < visible_rect.end.y and center.y + 36.0 > visible_rect.position.y:
			_draw_valve(canvas, center, alpha)
	# Dunkle innere Rohrkoerper schirmen Licht von Plattformauslegern ab.
	# Sie ueberdecken auch die inneren Enden der Stege: echte Ueberlappung.
	for side in [-1.0, 1.0]:
		var inner := inner_pipe_span(width, side)
		_shaded_rect(canvas, Rect2(inner.x, visible_rect.position.y, 48.0, visible_rect.size.y), Color("030608"), Color("11191f"), alpha)
		_shaded_rect(canvas, Rect2(inner.x + 48.0, visible_rect.position.y, inner.y - inner.x - 48.0, visible_rect.size.y), Color("11191f"), Color("020304"), alpha)
	for x in [0.0, width - 26.0]:
		canvas.draw_rect(Rect2(x, visible_rect.position.y, 26.0, visible_rect.size.y), _fade(Color("010101"), alpha))

static func pipe_module_rect(camera: float) -> Rect2:
	return Rect2(10.0, tile_world_y(2, camera, PIPE_INSTANCE_INDEX) + PIPE_INSTANCE_BAND * 300.0, PIPE_SECTION_WIDTH, PIPE_SECTION_HEIGHT)

## Omit the entire old body in this cell, including pixels under transparent
## texture margins. Clipped intervals also work when the owning tile is offscreen.
static func pipe_body_segments(rect: Rect2, side: float) -> Array[Vector2]:
	var segments: Array[Vector2] = []
	var cut := pipe_module_rect(rect.get_center().y)
	if not pipe_module_enabled or side != PIPE_INSTANCE_SIDE or not cut.intersects(rect):
		segments.append(Vector2(rect.position.y, rect.size.y))
		return segments
	if cut.position.y > rect.position.y:
		segments.append(Vector2(rect.position.y, cut.position.y - rect.position.y))
	if cut.end.y < rect.end.y:
		segments.append(Vector2(cut.end.y, rect.end.y - cut.end.y))
	return segments

static func _draw_pipe_module(canvas: CanvasItem, top: float, alpha: float) -> void:
	canvas.draw_texture_rect(PIPE_MODULE, Rect2(10.0, top, PIPE_SECTION_WIDTH, PIPE_SECTION_HEIGHT), false, Color(1.0, 1.0, 1.0, alpha))

## Durchgehende linke Rohrspalte: die nahtlose Kachel wird ueber den sichtbaren
## Bereich gestapelt. Gleiches Parallax wie die nahe Ebene (tile_world_y ueber
## dieselbe Kamerahoehe) und gleicher Zonen-Alpha. Kein eigenes Raster, damit
## das Rohr beim Scrollen exakt mit der uebrigen nahen Ebene laeuft.
static func pipe_tiles_rects(rect: Rect2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var camera := rect.get_center().y
	var base := tile_world_y(2, camera, 0)
	var first := int(floor((rect.position.y - base) / PIPE_SECTION_HEIGHT))
	var last := int(ceil((rect.end.y - base) / PIPE_SECTION_HEIGHT))
	for n in range(first, last + 1):
		rects.append(Rect2(10.0, base + n * PIPE_SECTION_HEIGHT, PIPE_SECTION_WIDTH, PIPE_SECTION_HEIGHT))
	return rects

static func _draw_pipe_tiles(canvas: CanvasItem, visible_rect: Rect2, alpha: float) -> void:
	for r in pipe_tiles_rects(visible_rect):
		if r.intersects(visible_rect):
			canvas.draw_texture_rect(PIPE_TILE, r, false, Color(1.0, 1.0, 1.0, alpha))

static func _draw_deck(canvas: CanvasItem, deck: Rect2, alpha: float) -> void:
	var p := deck.position
	canvas.draw_line(p + Vector2(10.0, 68.0), p + Vector2(90.0, 112.0), _fade(Color("040608"), alpha), 16.0)
	canvas.draw_rect(Rect2(p + Vector2(0.0, 54.0), Vector2(182.0, 18.0)), _fade(Color("040608"), alpha))
	canvas.draw_rect(Rect2(p + Vector2(0.0, 54.0), Vector2(182.0, 5.0)), _fade(Color("141a1d"), alpha))
	canvas.draw_rect(Rect2(p, Vector2(182.0, 5.0)), _fade(Color("141a1d"), alpha))
	canvas.draw_rect(Rect2(p + Vector2(0.0, 28.0), Vector2(182.0, 4.0)), _fade(Color("141a1d"), alpha))
	for post in [0.0, 86.0, 177.0]:
		canvas.draw_rect(Rect2(p + Vector2(post, 0.0), Vector2(5.0, 54.0)), _fade(Color("141a1d"), alpha))

static func valve_center(width: float, side: float, top: float) -> Vector2:
	return Vector2(134.0 if side < 0.0 else width - 134.0, top + 440.0)

static func _draw_valve(canvas: CanvasItem, center: Vector2, alpha: float) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		points.append(center + Vector2.from_angle(float(i) * TAU / 10.0) * 34.0)
	_draw_convex(canvas, points, _fade(Color("37372e"), alpha))
	for i in range(10):
		points[i] = center + Vector2.from_angle(float(i) * TAU / 10.0) * 26.0
	_draw_convex(canvas, points, _fade(Color("020304"), alpha))
	canvas.draw_line(center - Vector2(20.0, 20.0), center + Vector2(20.0, 20.0), _fade(Color("303129"), alpha), 6.0)
	canvas.draw_line(center - Vector2(20.0, -20.0), center + Vector2(20.0, -20.0), _fade(Color("303129"), alpha), 6.0)
	canvas.draw_rect(Rect2(center - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), _fade(Color("71502b"), alpha))

## Expliziter Dreieckfaecher: keine instabile Polygontriangulation bei +/-1e9.
static func _draw_convex(canvas: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	for i in range(1, points.size() - 1):
		canvas.draw_primitive(PackedVector2Array([points[0], points[i], points[i + 1]]), PackedColorArray([color]), PackedVector2Array())

static func draw_layer_for_test(canvas: CanvasItem, visible_rect: Rect2, zone_index: float, time: float, layer: int) -> void:
	var alpha := opacity_for_zone(zone_index)
	if alpha <= 0.0 or layer < 0 or layer >= LAYER_COUNT or visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return
	match layer:
		0:
			_draw_far_layer(canvas, visible_rect, 1080.0, alpha, time)
		1:
			_draw_mid_layer(canvas, visible_rect, 1080.0, alpha, time)
		2:
			_draw_near_layer(canvas, visible_rect, 1080.0, alpha, time)

## Kompatibler Einzellicht-Einstieg fuer bestehende QA-Probes.
static func draw_lamp(canvas: CanvasItem, x: float, y: float, phase: float, alpha: float) -> void:
	if alpha > 0.0:
		_draw_inset_light(canvas, Rect2(x - 50.0, y - 89.0, 100.0, 178.0), phase, alpha)

static func draw_steam(canvas: CanvasItem, x: float, y: float, phase: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	for puff in range(3):
		var local := phase + float(puff) * 1.7
		var rise := fmod(local, 6.0) / 6.0
		var radius := 10.0 + rise * 16.0
		var puff_alpha := (1.0 - rise) * 0.055 * alpha
		if puff_alpha > 0.0:
			canvas.draw_circle(Vector2(x + sin(local * 1.3) * 12.0, y - rise * 96.0), radius, _fade(STEAM, puff_alpha))

static func _fade(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)
