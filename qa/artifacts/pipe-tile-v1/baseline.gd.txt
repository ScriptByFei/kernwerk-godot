class_name ShaftBackground
extends RefCounted

## Zone 1: schwarze Hohlraeume, ueberlappende Maschinen, eingelassenes Warmlicht.
## Zustandslos. Alle Positionen entstehen aus Kamera und Kachelnummer.
const LAYER_COUNT := 3
const LAYER_PARALLAX := [0.22, 0.40, 0.62]
const LAYER_TILE_HEIGHT := [760.0, 640.0, 900.0]
const QUIET_HALF_WIDTH := 260.0
const ZONE_FADE_START := 0.55
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

static func opacity_for_zone(zone_index: float) -> float:
	if zone_index <= 0.0:
		return 1.0
	if zone_index >= ZONE_FADE_START:
		return 0.0
	return 1.0 - zone_index / ZONE_FADE_START

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

static func draw(canvas: CanvasItem, visible_rect: Rect2, zone_index: float, time: float) -> void:
	var alpha := opacity_for_zone(zone_index)
	if alpha <= 0.0 or visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return
	var width := 1080.0
	_draw_far_layer(canvas, visible_rect, width, alpha, time)
	_draw_mid_layer(canvas, visible_rect, width, alpha, time)
	_draw_near_layer(canvas, visible_rect, width, alpha, time)

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
	## Perlenkette vor den Fugen: kurz, diskret, in der Mittelachse, als
	## Gliederung der Tuer, nicht als durchgezogene Sprungbahn.
	for offset in range(count):
		var top := tile_world_y(0, camera, first + offset)
		_draw_door_frame(canvas, top, alpha)
		_draw_pearl_chain(canvas, top, alpha)
	for offset in range(count):
		var top := tile_world_y(0, camera, first + offset)
		canvas.draw_rect(Rect2(0.0, top, 280.0, 4.0), _fade(FAR_SEAM, alpha))
		canvas.draw_rect(Rect2(280.0, top, 520.0, 4.0), _fade(Color("0b1014"), alpha))
		canvas.draw_rect(Rect2(800.0, top, 280.0, 4.0), _fade(FAR_SEAM, alpha))

## Massive Stahltuer in der Spielmitte: ruhige, grosse, dunkle Flaechen mit
## sehr geringem Kontrast, keine Maschinen. Sie ist die Wand selbst, keine
## Technik — deshalb darf sie (wie die Fuge) in der Ruhezone liegen.
static func door_rect(top: float) -> Rect2:
	return Rect2(280.0, top, 520.0, 760.0)

static func _draw_door_frame(canvas: CanvasItem, top: float, alpha: float) -> void:
	var door := door_rect(top)
	# Ein dunkles, geschlossenes Stahlblatt; sehr geringer Kontrast zur Wand,
	# aber heller als die Hohlraeume dahinter, damit die Tuer als geschlossene
	# Flaeche erkennbar ist (nicht als dunkler Schacht).
	canvas.draw_rect(door, _fade(DOOR_PANEL, alpha))
	# Gravurlinie quer teilt das Panel — grosse flache Rechtecke, gedaempft.
	# Die durchlaufende Schachtfuge (0b1014, x 280..800) laeuft bereits durch
	# die Tuer und unterteilt sie zusaetzlich in Ebenen.
	canvas.draw_rect(Rect2(door.position.x + 18.0, door.position.y + door.size.y * 0.68, door.size.x - 36.0, 3.0), _fade(DOOR_FUGE, alpha))

## Perlenkette: kurze, diskrete helle Segmente in der Mittelachse der Tuer.
## Sie gliedern die Tuer, ohne eine durchgezogene Linie (Sprungbahn) zu bilden.
## Alle Werte bleiben unter dem Kontrast-Cap (Ruhezonen-Luma <= 0.088).
static func pearl_segments(top: float) -> Array[Rect2]:
	var tile_index := int(top / 760.0)
	var segs: Array[Rect2] = []
	# Zwei kurze Segmente je Tuerfeld, deutlich unter der Kachelhoehe verteilt.
	for slot in range(2):
		var local := tile_value(1, tile_index, slot + 40)
		var y := top + 260.0 * float(slot + 1) + local * 240.0
		var h := 14.0 + tile_value(1, tile_index, slot + 70) * 16.0
		segs.append(Rect2(536.0, y, 8.0, h))
	return segs

static func _draw_pearl_chain(canvas: CanvasItem, top: float, alpha: float) -> void:
	for seg in pearl_segments(top):
		canvas.draw_rect(seg, _fade(PEARL, alpha))

## Breite Zylinder hinter den Einbaugeraeten. Schwarze Luecken bleiben offen.
static func _draw_mid_layer(canvas: CanvasItem, visible_rect: Rect2, width: float, alpha: float, time: float) -> void:
	for side in [-1.0, 1.0]:
		var x := 214.0 if side < 0.0 else width - 270.0
		canvas.draw_rect(Rect2(x, visible_rect.position.y, 56.0, visible_rect.size.y), _fade(Color("0e1419"), alpha))
		canvas.draw_rect(Rect2(x + 10.0, visible_rect.position.y, 24.0, visible_rect.size.y), _fade(Color("11191f"), alpha))
	var camera := visible_rect.get_center().y
	var first := first_visible_tile(1, camera, visible_rect.position.y)
	var count := visible_tile_count(1, camera, visible_rect.position.y, visible_rect.end.y)
	for offset in range(count):
		var index := first + offset
		var top := tile_world_y(1, camera, index)
		for side in [-1.0, 1.0]:
			var slot := 0 if side < 0.0 else 1
			var y := top + 70.0 + float(slot) * 190.0 + tile_value(1, index, slot) * 64.0
			var body := machinery_rect(width, side, y)
			if not body.intersects(visible_rect):
				continue
			canvas.draw_rect(body, _fade(Color("030405"), alpha))
			canvas.draw_rect(Rect2(body.position + Vector2(4.0, 4.0), body.size - Vector2(12.0, 16.0)), _fade(Color("11191f"), alpha))
			var light := lamp_surface(width, side, y)
			_draw_inset_light(canvas, light, time + float(index), alpha, tile_pick(1, index, slot + 13, 3))
			canvas.draw_rect(Rect2(body.position + Vector2(12.0, 198.0), Vector2(112.0, 36.0)), _fade(Color("1e160f"), alpha))
			for slit in range(3):
				canvas.draw_rect(Rect2(body.position + Vector2(18.0, 202.0 + slit * 10.0), Vector2(100.0, 5.0)), _fade(VENT_SLOT, alpha))
			canvas.draw_rect(Rect2(212.0 if side < 0.0 else width - 272.0, y + 252.0, 60.0, 16.0), _fade(Color("10171c"), alpha))

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
	for side in [-1.0, 1.0]:
		var span := foreground_pipe_span(width, side)
		canvas.draw_rect(Rect2(span.x, visible_rect.position.y, span.y - span.x, visible_rect.size.y), _fade(Color("030507"), alpha))
		_shaded_rect(canvas, Rect2(span.x + 10.0, visible_rect.position.y, 34.0, visible_rect.size.y), Color("06090c"), Color("1a2024"), alpha)
		_shaded_rect(canvas, Rect2(span.x + 44.0, visible_rect.position.y, 28.0, visible_rect.size.y), Color("1a2024"), Color("070a0c"), alpha)
		canvas.draw_rect(Rect2(span.x + (64.0 if side < 0.0 else 10.0), visible_rect.position.y, 6.0, visible_rect.size.y), _fade(Color("32312b"), alpha))
	var camera := visible_rect.get_center().y
	var first := first_visible_tile(2, camera, visible_rect.position.y)
	var count := visible_tile_count(2, camera, visible_rect.position.y, visible_rect.end.y)
	for offset in range(count):
		var index := first + offset
		var top := tile_world_y(2, camera, index)
		for side in [-1.0, 1.0]:
			var span := foreground_pipe_span(width, side)
			for band in range(3):
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
		if center.y - 36.0 < visible_rect.end.y and center.y + 36.0 > visible_rect.position.y:
			_draw_valve(canvas, center, alpha)
	# Dunkle innere Rohrkoerper schirmen Licht von Plattformauslegern ab.
	# Sie ueberdecken auch die inneren Enden der Stege: echte Ueberlappung.
	for side in [-1.0, 1.0]:
		var inner := inner_pipe_span(width, side)
		_shaded_rect(canvas, Rect2(inner.x, visible_rect.position.y, 48.0, visible_rect.size.y), Color("030608"), Color("11191f"), alpha)
		_shaded_rect(canvas, Rect2(inner.x + 48.0, visible_rect.position.y, inner.y - inner.x - 48.0, visible_rect.size.y), Color("11191f"), Color("020304"), alpha)
	for x in [0.0, width - 26.0]:
		canvas.draw_rect(Rect2(x, visible_rect.position.y, 26.0, visible_rect.size.y), _fade(Color("010101"), alpha))

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
