class_name ShaftBackground
extends RefCounted

## Reaktorschacht-Hintergrund fuer Zone 1.
##
## Reine Mathematik plus Zeichenroutinen: dieses Skript kennt keine Nodes und
## haelt keinen Zustand, der zwischen Bildern verloren gehen koennte. Alles ist
## aus Kameraposition und Kachelnummer ableitbar, deshalb ist der Hintergrund
## reproduzierbar und headless pruefbar (siehe tests/shaft_background_test.gd).
##
## Aufbau in drei Tiefenebenen mit leichtem Parallax:
##   0 fern    — Wandpaneele, sehr dunkel, bewegt sich am wenigsten
##   1 mittel  — Rohre, Kabelkanaele, Traeger
##   2 nah     — wenige Konstruktionen am Rand, Stege, Lueftungsgitter
##
## Bewusst NICHT enthalten: Text, Animationen mit eigenem Zustand, Partikel als
## Nodes. Die wenigen Bewegungen (Lampenflackern, Dampf) sind reine Funktionen
## der Zeit und werden in _draw berechnet. Damit bleibt das Modul ein einziges
## Zeichenobjekt und kostet im Webexport keine zusaetzlichen Nodes.

## Anzahl der Tiefenebenen. Ebene 0 ist am weitesten entfernt.
const LAYER_COUNT := 3

## Parallaxanteil je Ebene: der Anteil der Kamerabewegung, den die Ebene auf dem
## Schirm mitmacht. 1.0 waere Weltinhalt (kein Parallax), 0.0 unendlich fern.
## Bewusst deutlich unter 1.0, sonst wirkt der Hintergrund wie eine zweite
## Spielebene; bewusst ueber 0.0, sonst steht er still und wirkt wie Tapete.
const LAYER_PARALLAX := [0.22, 0.40, 0.62]

## Kachelhoehe je Ebene in Weltpixeln. Der Schacht ist unendlich hoch und wird
## in wiederkehrenden Kacheln gezeichnet; die Hoehen sind teilerfremd gewaehlt,
## damit die Ebenen nicht synchron wiederkehren und das Muster nicht auffaellt.
const LAYER_TILE_HEIGHT := [760.0, 640.0, 900.0]

## Halbe Breite der ruhigen Mittelzone. In diesem Streifen wird kein Detail
## gezeichnet: dort laufen Reaktor und Plattformen. Breiter als eine Plattform,
## damit keine Technik unter dem Spielbereich hervorschaut.
const QUIET_HALF_WIDTH := 260.0

## Ab dieser Ueberdeckung der Zone wird der Hintergrund ausgeblendet. Zone 0 ist
## der Reaktorschacht; hoehere Zonen bekommen spaeter eine eigene Gestaltung und
## bleiben hier bewusst unberuehrt.
const ZONE_FADE_START := 0.55

# --- Farben ---------------------------------------------------------------
# Alle Werte deutlich dunkler als Plattformen (233b46) und Resonanzband
# (315c65), damit der Vordergrund in jedem Fall lesbar bleibt.
const FAR_WALL := Color("070c11")
const FAR_PANEL := Color("101a24")
const FAR_SEAM := Color("17242f")
const MID_PIPE := Color("1d2b38")
const MID_PIPE_EDGE := Color("2b404f")
const MID_TRUSS := Color("1a2733")
const NEAR_BEAM := Color("0c141b")
const NEAR_EDGE := Color("263644")
const VENT_SLOT := Color("04080b")
const LAMP_CORE := Color("ff9a3c")
const LAMP_GLOW := Color("c25f1c")
const STEAM := Color("8fa4ad")

## Parallaxfaktor einer Ebene.
static func layer_parallax(layer: int) -> float:
	return LAYER_PARALLAX[clampi(layer, 0, LAYER_PARALLAX.size() - 1)]

## Kachelhoehe einer Ebene in Weltpixeln.
static func layer_tile_height(layer: int) -> float:
	return LAYER_TILE_HEIGHT[clampi(layer, 0, LAYER_TILE_HEIGHT.size() - 1)]

## Versatz des Kachelrasters einer Ebene. Die Ebene bleibt hinter der Kamera
## zurueck, deshalb waechst der Versatz um den Rest der Kamerabewegung.
static func scroll_offset(layer: int, camera_y: float) -> float:
	return (1.0 - layer_parallax(layer)) * camera_y

## Scheinbare Bewegung einer Ebene auf dem Schirm, wenn die Kamera um
## `travelled` Weltpixel wandert. Genau der Parallax-Anteil.
static func apparent_shift(layer: int, travelled: float) -> float:
	return layer_parallax(layer) * travelled

## Weltkoordinate der Kacheloberkante `index` einer Ebene.
static func tile_world_y(layer: int, camera_y: float, index: int) -> float:
	return float(index) * layer_tile_height(layer) + scroll_offset(layer, camera_y)

## Nummer der ersten Kachel, die den Schirm ab `screen_top` beruehrt. Kann
## negativ werden: der Schacht reicht beliebig weit nach oben und unten.
static func first_visible_tile(layer: int, camera_y: float, screen_top: float) -> int:
	var tile := layer_tile_height(layer)
	if tile <= 0.0:
		return 0
	var local := screen_top - scroll_offset(layer, camera_y)
	return int(floor(local / tile))

## Anzahl der Kacheln, die den Schirm von `screen_top` bis `screen_bottom`
## lueckenlos decken — minimal gewaehlt, damit nichts unnoetig gezeichnet wird.
static func visible_tile_count(layer: int, camera_y: float, screen_top: float, screen_bottom: float) -> int:
	var tile := layer_tile_height(layer)
	if tile <= 0.0:
		return 0
	var span := screen_bottom - screen_top
	if span <= 0.0:
		return 0
	var first := first_visible_tile(layer, camera_y, screen_top)
	var first_top := tile_world_y(layer, camera_y, first)
	# Wie viele Kacheln ab der ersten noetig sind, um screen_bottom zu erreichen.
	return int(floor((screen_bottom - first_top) / tile)) + 1

## Sichtbarkeit des Hintergrunds in Abhaengigkeit von der erreichten Zone.
## 1.0 im Reaktorschacht, 0.0 ab der Kuehlsektion, dazwischen linear geblendet.
static func opacity_for_zone(zone_index: float) -> float:
	if zone_index <= 0.0:
		return 1.0
	if zone_index >= ZONE_FADE_START:
		return 0.0
	return 1.0 - zone_index / ZONE_FADE_START

## Darf an dieser x-Position (Weltkoordinate) ein Detail gezeichnet werden?
## Die Spielmitte bleibt frei; Technik sitzt nur links und rechts.
static func detail_allowed(world_x: float, view_width: float) -> bool:
	var center := view_width * 0.5
	return absf(world_x - center) > QUIET_HALF_WIDTH

## Traegerachsen der Fernwand. Jede Achse muss ausserhalb der ruhigen Mitte
## liegen. Zuvor standen zwei davon (x=300 und x=780) mitten im Spielbereich,
## weil diese Ebene detail_allowed() gar nicht benutzte — der Riegel existierte,
## wurde hier aber umgangen. Die Positionen kommen jetzt aus dieser Funktion,
## damit Zeichnen und Pruefung dieselbe Quelle haben.
static func girder_axes(view_width: float) -> Array[float]:
	var axes: Array[float] = []
	for share: float in [0.09, 0.20, 0.80, 0.91]:
		var x: float = view_width * share
		if detail_allowed(x, view_width):
			axes.append(x)
	return axes

## Waagerechte Ausdehnung eines Fernwand-Panelfeldes als Vector2(start, ende).
## Die Felder enden an der ruhigen Mitte: dort bleibt freie Wandflaeche, damit
## keine Panelfugen unter dem Spielbereich liegen.
static func panel_field_span(view_width: float, side: float) -> Vector2:
	var edge := view_width * 0.5 - QUIET_HALF_WIDTH
	if side < 0.0:
		return Vector2(0.0, edge)
	return Vector2(view_width - edge, view_width)

## Reproduzierbarer Startwert einer Kachel. Ganzzahlig gerechnet, damit
## negative Kachelnummern (oberhalb des Nullpunkts) denselben Wertebereich
## liefern wie positive.
static func tile_seed(layer: int, index: int) -> int:
	var value := index * 1103515245 + layer * 12345 + 7919
	value ^= value >> 13
	value *= 1274126177
	return absi(value)

## Zufallswert einer Kachel fuer einen Detailplatz. Deterministisch: dieselbe
## Kachel liefert bei jedem Bild denselben Wert, sonst flackert das Muster.
static func tile_value(layer: int, index: int, slot: int) -> float:
	var value := tile_seed(layer, index) + slot * 2654435761
	value ^= value >> 15
	value *= 2246822519
	value ^= value >> 13
	return float(absi(value) % 100000) / 100000.0

## Ganze Zahl aus einer Kachel: fuer Entscheidungen (Detail ja/nein, Variante).
static func tile_pick(layer: int, index: int, slot: int, count: int) -> int:
	if count <= 0:
		return 0
	var value := tile_seed(layer, index) + slot * 40503
	value ^= value >> 11
	return absi(value) % count

# --- Zeichnen -------------------------------------------------------------

## Zeichnet alle drei Ebenen in den uebergebenen Ausschnitt.
## `canvas` ist das Node2D, in dessen _draw aufgerufen wird; `time` steuert die
## wenigen ruhigen Bewegungen (Lampenflimmern, Dampf).
static func draw(canvas: CanvasItem, visible_rect: Rect2, zone_index: float, time: float) -> void:
	var alpha := opacity_for_zone(zone_index)
	if alpha <= 0.0:
		return
	var width := 1080.0
	_draw_far_layer(canvas, visible_rect, width, alpha, time)
	_draw_mid_layer(canvas, visible_rect, width, alpha, time)
	_draw_near_layer(canvas, visible_rect, width, alpha, time)

## Ferme Wand: grosse Paneele mit Sicken, Nieten und vertikalen Traegern. Ruhig
## und gleichmaessig — diese Ebene traegt die Tiefe, nicht die Aufmerksamkeit.
static func _draw_far_layer(canvas: CanvasItem, visible_rect: Rect2, width: float, alpha: float, time: float) -> void:
	var layer := 0
	var cam_y := visible_rect.get_center().y
	var tint := _fade(FAR_WALL, alpha)
	canvas.draw_rect(visible_rect, tint, true)
	var panel := _fade(FAR_PANEL, alpha)
	var seam := _fade(FAR_SEAM, alpha)
	var tile := layer_tile_height(layer)
	var first := first_visible_tile(layer, cam_y, visible_rect.position.y)
	var count := visible_tile_count(layer, cam_y, visible_rect.position.y, visible_rect.end.y)
	for offset in range(count):
		var index := first + offset
		var top := tile_world_y(layer, cam_y, index)
		for side in [-1.0, 1.0]:
			# Die Felder enden an der ruhigen Mitte (siehe panel_field_span):
			# links und rechts traegt die Wand Struktur, in der Mitte bleibt sie
			# ruhig, damit Reaktor und Plattformen frei stehen.
			var span := panel_field_span(width, side)
			var field_x := span.x
			var field_w := span.y - span.x
			# Zwei Paneelfelder je Seite, versetzt: das bricht die grosse Flaeche
			# in lesbare Segmente, ohne unruhig zu werden.
			for field in range(2):
				var field_y := top + tile * (0.06 + float(field) * 0.5)
				var field_h := tile * 0.42
				if field_y + field_h < visible_rect.position.y or field_y > visible_rect.end.y:
					continue
				canvas.draw_rect(Rect2(field_x, field_y, field_w, field_h), panel, true)
				# Waagerechte Sicke an der Oberkante des Feldes.
				# Mindestens 4 Weltpixel: darunter bleibt auf einem Telefon
				# (Skalierung 0.398) kein sichtbarer Pixel uebrig, die Linie
				# kostet dann nur Zeichenzeit.
				canvas.draw_rect(Rect2(field_x, field_y, field_w, 4.0), seam, true)
				# Zwei senkrechte Sicken teilen das Feld weiter auf.
				for split in [0.34, 0.68]:
					canvas.draw_rect(Rect2(field_x + field_w * split, field_y, 4.0, field_h), seam, true)
	# Vertikale Traeger der Fernwand: feste Achsen, in JEDER Kachel dieselben.
	# Sie geben dem Schacht den ruhigen Takt. Die Achsen kommen aus
	# girder_axes(), damit sie die ruhige Mitte nicht verletzen koennen.
	for axis in girder_axes(width):
		canvas.draw_rect(Rect2(axis - 3.0, visible_rect.position.y, 6.0, visible_rect.size.y), seam, true)
	# Horizontale Bandfugen ueber die ganze Breite: sie machen aus der Flaeche
	# einen Schacht aus uebereinanderliegenden Segmenten. Bewusst VOLLE Breite —
	# eine Fuge ist keine gesetzte Einzelheit, sondern die Segmentkante der Wand;
	# endete sie an der Ruhezone, entstuende dort ein Loch.
	for offset in range(count):
		var index := first + offset
		var top := tile_world_y(layer, cam_y, index)
		canvas.draw_rect(Rect2(0.0, top, width, 4.0), seam, true)

## Mittlere Technik: Rohre, Kabelkanaele, Streben. Nur links und rechts.
static func _draw_mid_layer(canvas: CanvasItem, visible_rect: Rect2, width: float, alpha: float, time: float) -> void:
	var layer := 1
	var cam_y := visible_rect.get_center().y
	var tile := layer_tile_height(layer)
	var first := first_visible_tile(layer, cam_y, visible_rect.position.y)
	var count := visible_tile_count(layer, cam_y, visible_rect.position.y, visible_rect.end.y)
	for offset in range(count):
		var index := first + offset
		var top := tile_world_y(layer, cam_y, index)
		for slot in range(4):
			var pick := tile_pick(layer, index, slot, 3)
			var side := -1.0 if slot % 2 == 0 else 1.0
			var x := width * 0.5 + side * (QUIET_HALF_WIDTH + 26.0 + float(pick) * 78.0 + float(slot) * 13.0)
			if not detail_allowed(x, width):
				continue
			var y := top + tile_value(layer, index, slot) * tile
			if y + 90.0 < visible_rect.position.y or y > visible_rect.end.y:
				continue
			_draw_pipe(canvas, x, y, slot, alpha)
		# Kabelkanal: eine laengere Linie mit Sicken, je Kachel eine.
		var channel_x := width * 0.5 - (QUIET_HALF_WIDTH + 150.0) if tile_pick(layer, index, 9, 2) == 0 else width * 0.5 + QUIET_HALF_WIDTH + 150.0
		if detail_allowed(channel_x, width):
			canvas.draw_rect(Rect2(channel_x - 9.0, top + 40.0, 18.0, tile * 0.30), _fade(MID_TRUSS, alpha), true)
			canvas.draw_rect(Rect2(channel_x - 9.0, top + 40.0, 2.0, tile * 0.30), _fade(MID_PIPE_EDGE, alpha), true)
		# Streben: kurze diagonale Verstrebungen an den Raendern. Nur eine je
		# Kachel — mehr waere auf dem Telefon ohnehin kaum unterscheidbar.
		for brace in range(1):
			var brace_side := -1.0 if brace == 0 else 1.0
			var bx := width * 0.5 + brace_side * (QUIET_HALF_WIDTH + 60.0 + float(tile_pick(layer, index, brace, 4)) * 46.0)
			if not detail_allowed(bx, width):
				continue
			var by := top + tile_value(layer, index, brace + 20) * tile
			if by + 70.0 < visible_rect.position.y or by > visible_rect.end.y:
				continue
			canvas.draw_line(Vector2(bx, by), Vector2(bx + brace_side * 46.0, by + 70.0), _fade(MID_TRUSS, alpha), 5.0)
		# Lueftungsgitter: kurze dunkle Schlitze in einer hellen Blende. Ohne
		# diese Details liest sich die Wand als leere Flaeche.
		if tile_pick(layer, index, 40, 2) == 0:
			var vent_side := -1.0 if tile_pick(layer, index, 41, 2) == 0 else 1.0
			var vent_x := width * 0.5 + vent_side * (QUIET_HALF_WIDTH + 96.0)
			var vent_y := top + tile_value(layer, index, 42) * tile * 0.8
			if detail_allowed(vent_x, width) and vent_y < visible_rect.end.y and vent_y + 58.0 > visible_rect.position.y:
				canvas.draw_rect(Rect2(vent_x - 26.0, vent_y, 52.0, 58.0), _fade(MID_PIPE_EDGE, alpha), true)
				for slit in range(4):
					canvas.draw_rect(Rect2(vent_x - 21.0, vent_y + 6.0 + float(slit) * 12.0, 42.0, 7.0), _fade(VENT_SLOT, alpha), true)

## Ein Rohrsegment. Drei Varianten: blankes Rohr, Rohr mit Flansch, Rohrpaket.
static func _draw_pipe(canvas: CanvasItem, x: float, y: float, variant: int, alpha: float) -> void:
	var body := _fade(MID_PIPE, alpha)
	var edge := _fade(MID_PIPE_EDGE, alpha)
	match variant % 3:
		0:
			canvas.draw_rect(Rect2(x - 7.0, y, 14.0, 96.0), body, true)
			canvas.draw_rect(Rect2(x - 7.0, y, 4.0, 96.0), edge, true)
		1:
			canvas.draw_rect(Rect2(x - 9.0, y, 18.0, 120.0), body, true)
			canvas.draw_rect(Rect2(x - 13.0, y + 18.0, 26.0, 6.0), edge, true)
			canvas.draw_rect(Rect2(x - 13.0, y + 86.0, 26.0, 6.0), edge, true)
		_:
			canvas.draw_rect(Rect2(x - 12.0, y, 9.0, 104.0), body, true)
			canvas.draw_rect(Rect2(x + 3.0, y + 12.0, 9.0, 92.0), body, true)

## Nahe Konstruktionen: wenige, kraeftige Balken und Stege am aeussersten Rand.
## Bewusst sparsam — diese Ebene ist die staerkste und darf nicht ueberwiegen.
static func _draw_near_layer(canvas: CanvasItem, visible_rect: Rect2, width: float, alpha: float, time: float) -> void:
	var layer := 2
	var cam_y := visible_rect.get_center().y
	var tile := layer_tile_height(layer)
	var first := first_visible_tile(layer, cam_y, visible_rect.position.y)
	var count := visible_tile_count(layer, cam_y, visible_rect.position.y, visible_rect.end.y)
	var beam := _fade(NEAR_BEAM, alpha)
	var edge := _fade(NEAR_EDGE, alpha)
	for offset in range(count):
		var index := first + offset
		var top := tile_world_y(layer, cam_y, index)
		# Ein Randtraeger je Seite, nicht in jeder Kachel — sonst wird es voll.
		if tile_pick(layer, index, 0, 3) == 0:
			canvas.draw_rect(Rect2(0.0, top, 54.0, tile * 0.55), beam, true)
			canvas.draw_rect(Rect2(52.0, top, 2.0, tile * 0.55), edge, true)
		if tile_pick(layer, index, 1, 3) == 1:
			canvas.draw_rect(Rect2(width - 58.0, top + tile * 0.25, 58.0, tile * 0.5), beam, true)
			canvas.draw_rect(Rect2(width - 58.0, top + tile * 0.25, 2.0, tile * 0.5), edge, true)
		# Wartungssteg: schmale waagerechte Platte mit Gelaenderlinie.
		if tile_pick(layer, index, 2, 4) == 0:
			var side := -1.0 if tile_pick(layer, index, 3, 2) == 0 else 1.0
			var deck_x := width * 0.5 + side * (QUIET_HALF_WIDTH + 8.0)
			var deck_w := 96.0
			var deck_y := top + tile_value(layer, index, 4) * tile * 0.7
			if detail_allowed(deck_x, width) and deck_y < visible_rect.end.y and deck_y + 12.0 > visible_rect.position.y:
				canvas.draw_rect(Rect2(deck_x - deck_w * 0.5, deck_y, deck_w, 9.0), edge, true)
				canvas.draw_rect(Rect2(deck_x - deck_w * 0.5, deck_y - 18.0, deck_w, 4.0), beam, true)
				canvas.draw_rect(Rect2(deck_x - deck_w * 0.5, deck_y - 18.0, 4.0, 18.0), beam, true)
				canvas.draw_rect(Rect2(deck_x + deck_w * 0.5 - 4.0, deck_y - 18.0, 4.0, 18.0), beam, true)
		# Orange Wartungslichter: wenige, immer an den Raendern, nie in der
		# Spielmitte. Zwei je Kachel, damit sie den Schacht markieren, ohne zu
		# leuchten wie eine Anzeige.
		for lamp_slot in range(2):
			var lamp_side := -1.0 if lamp_slot == 0 else 1.0
			var lamp_x := width * 0.5 + lamp_side * (QUIET_HALF_WIDTH + 34.0)
			var lamp_y := top + tile_value(layer, index, 50 + lamp_slot) * tile * 0.9
			if not detail_allowed(lamp_x, width):
				continue
			if lamp_y < visible_rect.position.y or lamp_y > visible_rect.end.y:
				continue
			# Phase je Kachel verschieden, damit nicht alle gleichzeitig flimmern.
			var lamp_phase := float(tile_pick(layer, index, 60 + lamp_slot, 628)) * 0.01
			draw_lamp(canvas, lamp_x, lamp_y, time + lamp_phase, alpha)
		# Dampf: nur in jeder dritten Kachel und nur am Rand.
		if tile_pick(layer, index, 70, 3) == 0:
			var steam_side := -1.0 if tile_pick(layer, index, 71, 2) == 0 else 1.0
			var steam_x := width * 0.5 + steam_side * (QUIET_HALF_WIDTH + 52.0)
			var steam_y := top + tile_value(layer, index, 72) * tile
			if detail_allowed(steam_x, width) and steam_y < visible_rect.end.y and steam_y + 120.0 > visible_rect.position.y:
				draw_steam(canvas, steam_x, steam_y, time + float(tile_pick(layer, index, 73, 900)) * 0.01, alpha)

# --- Licht und Dampf ------------------------------------------------------

## Dezentes Wartungslicht. Sehr ruhiges Flimmern ueber die Zeit, kein Blinken.
## Zeichnet genau EINE Ebene. Nur fuer Pruefungen: damit laesst sich feststellen,
## welche Ebene eine Regel verletzt, statt nur dass die Summe es tut.
static func draw_layer_for_test(canvas: CanvasItem, visible_rect: Rect2, zone_index: float, time: float, layer: int) -> void:
	var alpha := opacity_for_zone(zone_index)
	if alpha <= 0.0:
		return
	if layer < 0 or layer >= LAYER_COUNT:
		return
	var width := 1080.0
	match layer:
		0:
			_draw_far_layer(canvas, visible_rect, width, alpha, time)
		1:
			_draw_mid_layer(canvas, visible_rect, width, alpha, time)
		2:
			_draw_near_layer(canvas, visible_rect, width, alpha, time)

static func draw_lamp(canvas: CanvasItem, x: float, y: float, phase: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	# Flimmern zwischen 88 % und 100 % Helligkeit, sehr langsam.
	var flicker := 0.88 + 0.12 * sin(phase * 0.7)
	var core := _fade(LAMP_CORE, alpha * flicker)
	var glow := _fade(LAMP_GLOW, alpha * 0.20 * flicker)
	# Glut ZUERST, Kern danach: sonst deckt die Glut den hellen Kern zu und die
	# Lampe wirkt wie ein matschiger Fleck statt wie eine Lichtquelle.
	canvas.draw_rect(Rect2(x - 14.0, y - 9.0, 28.0, 18.0), glow, true)
	canvas.draw_rect(Rect2(x - 9.0, y - 5.0, 18.0, 10.0), core, true)

## Dampfschwade: wenige, weiche Kreise. Reine Funktion der Zeit, kein Zustand.
static func draw_steam(canvas: CanvasItem, x: float, y: float, phase: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	for puff in range(3):
		var local := phase + float(puff) * 1.7
		var rise := fmod(local, 6.0) / 6.0
		var radius := 10.0 + rise * 16.0
		var puff_alpha := (1.0 - rise) * 0.055 * alpha
		if puff_alpha <= 0.0:
			continue
		canvas.draw_circle(Vector2(x + sin(local * 1.3) * 12.0, y - rise * 96.0), radius, _fade(STEAM, puff_alpha))

## Farbe mit der Zonensichtbarkeit verrechnet. Der Hintergrund verschwindet
## ueber die Deckkraft, nicht ueber einen harten Schnitt.
static func _fade(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)
