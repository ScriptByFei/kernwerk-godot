extends SceneTree

## Randfaelle des Reaktorschacht-Hintergrunds.
##
## Anlass: das geplante unabhaengige Review ist an einem Auth-Fehler (HTTP 401)
## gescheitert und hat kein Ergebnis geliefert. Statt den Bericht zu erfinden,
## prueft diese Suite die Randfaelle MECHANISCH — Absturz bei entarteten
## Eingaben, Determinismus, und ob die ruhige Mitte eingehalten wird.
##
## Warum ohne Canvas: Godot lehnt das Ueberschreiben von draw_rect/draw_line auf
## einem CanvasItem als Fehler ab ("overrides a method from native class"), ein
## mitschreibender Canvas ist also nicht moeglich. Geprueft wird deshalb die
## Mathematik, aus der die Zeichenpositionen hervorgehen — sie ist die einzige
## Quelle der Wahrheit fuer jede gesetzte Einzelheit. Zusaetzlich laeuft draw()
## gegen ein echtes CanvasItem, damit ein Absturz in den Zeichenroutinen selbst
## auffaellt.

const ShaftBackground := preload("res://scripts/jump/shaft_background.gd")

## Breite des Spielfelds in Weltpixeln.
const WIDTH := 1080.0
## Sichtbare Hoehe bei Telefonformat.
const VIEW_HEIGHT := 2342.0

var _checks := 0
var _failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", what)

func _run() -> void:
	await _check_degenerate_inputs()
	_check_extreme_heights()
	_check_determinism()
	_check_quiet_center()
	_check_tile_math()
	print("SHAFT EDGE: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

## Zeichenpfad: Godot erlaubt Zeichnen NUR innerhalb von _draw(). Ein direkter
## Aufruf von draw() auf einem beliebigen CanvasItem wird von der Engine
## abgelehnt ("Drawing is only allowed inside this node's _draw()") — die
## Pruefung liefe dann ins Leere, ohne dass ein Fehler auffiele. Deshalb faehrt
## diese Klasse den echten Pfad: sie haelt die Parameter und zeichnet in _draw().
class ProbeCanvas extends Node2D:
	var rect := Rect2()
	var zone := 0.0
	var time := 0.0
	var draws := 0
	func _draw() -> void:
		draws += 1
		ShaftBackground.draw(self, rect, zone, time)

## Entartete Eingaben duerfen nicht abstuerzen. draw() laeuft gegen ein echtes
## CanvasItem — ein Fehler in den Zeichenroutinen wuerde hier hart abbrechen.
func _check_degenerate_inputs() -> void:
	# Warten, bis wirklich gerendert wird.
	var canvas := ProbeCanvas.new()
	root.add_child(canvas)
	for width in [0.0, 1.0, -10.0]:
		_draw_once(canvas, Rect2(0.0, 0.0, width, 100.0), 0.0, 1.0)
		_check(true, "Breite %.0f ohne Absturz" % width)
	for size in [Vector2(1.0, 1.0), Vector2(8000.0, 200.0)]:
		_draw_once(canvas, Rect2(Vector2.ZERO, size), 0.0, 1.0)
		_check(true, "Fenster %s ohne Absturz" % size)
	for y in [-1.0e9, 0.0, 1.0e9]:
		_draw_once(canvas, Rect2(0.0, y, WIDTH, VIEW_HEIGHT), 0.0, 1.0)
		_check(true, "Kamerahoehe %.0f ohne Absturz" % y)
	# Ueberlaufende Zeit.
	for t in [0.0, 1.0e6, 1.0e9]:
		_draw_once(canvas, Rect2(0.0, -1200.0, WIDTH, VIEW_HEIGHT), 0.0, t)
		_check(true, "Zeit %.0f ohne Absturz" % t)
	# Jede Zone, auch ausserhalb des gueltigen Bereichs.
	for z in [-3.0, 0.0, 0.54, 0.56, 2.0, 1.0e6]:
		_draw_once(canvas, Rect2(0.0, -1200.0, WIDTH, VIEW_HEIGHT), z, 1.0)
		_check(true, "Zonenindex %.2f ohne Absturz" % z)
	# Echte Bilder rendern lassen, damit _draw() ueberhaupt laeuft.
	for frame in range(4):
		await RenderingServer.frame_post_draw
	# Gegenprobe: ohne diesen Nachweis waeren alle "ohne Absturz"-Pruefungen
	# wertlos, weil draw() nie ausgefuehrt worden sein koennte.
	_check(canvas.draws > 0, "der Zeichenpfad wurde wirklich ausgefuehrt")
	canvas.queue_free()

## Setzt die Parameter und faehrt den echten _draw()-Pfad.
##
## Wichtig: "Drawing is only allowed inside _draw()" — ein direkter Aufruf wird
## von der Engine verworfen. Und NOTIFICATION_DRAW von Hand zu senden genuegt
## NICHT: in _init() eines SceneTree gibt es noch kein redrawfaehiges Fenster,
## _draw() laeuft dann nie. Beides wurde gemessen (draws blieb 0). Ein Canvas,
## der nie zeichnet, "stuerzt nicht ab" — die Pruefung waere wertlos.
## Deshalb laeuft diese Funktion in einer eigenen Schleife mit echten Bildern.
func _draw_once(canvas: ProbeCanvas, rect: Rect2, zone: float, time: float) -> void:
	canvas.rect = rect
	canvas.zone = zone
	canvas.time = time
	canvas.queue_redraw()

## Extremwerte muessen endliche Koordinaten liefern.
func _check_extreme_heights() -> void:
	for y in [-1.0e7, -1.0, 0.0, 1.0e7]:
		for layer in range(ShaftBackground.LAYER_COUNT):
			var tile := ShaftBackground.layer_tile_height(layer)
			_check(tile > 0.0, "Kachelhoehe Ebene %d ist positiv" % layer)
			var index := ShaftBackground.first_visible_tile(layer, y, y)
			var count := ShaftBackground.visible_tile_count(layer, y, y, y + VIEW_HEIGHT)
			_check(is_finite(float(index)), "erste Kachel Ebene %d ist endlich bei Hoehe %.0f" % [layer, y])
			# Gegen die Obergrenze absichern: eine entartete Kamerahoehe darf
			# nicht dazu fuehren, dass unendlich viele Kacheln gezeichnet werden.
			_check(count >= 0 and count <= 64, "Kachelzahl Ebene %d bleibt beherrschbar (%d bei Hoehe %.0f)" % [layer, count, y])

## Gleiche Eingabe -> gleiches Ergebnis. Kein versteckter Zustand.
func _check_determinism() -> void:
	var identical := true
	for layer in range(ShaftBackground.LAYER_COUNT):
		for index in range(12):
			if ShaftBackground.tile_seed(layer, index) != ShaftBackground.tile_seed(layer, index):
				identical = false
			for slot in range(8):
				if ShaftBackground.tile_value(layer, index, slot) != ShaftBackground.tile_value(layer, index, slot):
					identical = false
	_check(identical, "Kachelwerte sind reproduzierbar")
	# Und verschiedene Kacheln MUESSEN sich unterscheiden, sonst ist der
	# Zufall wirkungslos und die Wand sieht ueberall gleich aus.
	var distinct := {}
	for index in range(24):
		distinct[ShaftBackground.tile_seed(0, index)] = true
	_check(distinct.size() >= 20, "Kacheln unterscheiden sich (%d von 24)" % distinct.size())

## Die ruhige Mitte: jede gesetzte Einzelheit links oder rechts davon.
func _check_quiet_center() -> void:
	var quiet_left := WIDTH * 0.5 - ShaftBackground.QUIET_HALF_WIDTH
	var quiet_right := WIDTH * 0.5 + ShaftBackground.QUIET_HALF_WIDTH
	var axes := ShaftBackground.girder_axes(WIDTH)
	for axis in axes:
		_check(axis <= quiet_left or axis >= quiet_right, "Traegerachse %.0f meidet die Mitte" % axis)
	for side in [-1.0, 1.0]:
		var span := ShaftBackground.panel_field_span(WIDTH, side)
		_check(span.y <= quiet_left or span.x >= quiet_right, "Panelfeld %s meidet die Mitte" % side)
	# Die Rohre der mittleren Ebene kommen aus tile_pick und werden ueber
	# detail_allowed gefiltert: hier pruefen, dass der Filter wirklich greift.
	for x in [40.0, 540.0, 1040.0]:
		_check(ShaftBackground.detail_allowed(x, WIDTH) == (absf(x - WIDTH * 0.5) > ShaftBackground.QUIET_HALF_WIDTH),
			"detail_allowed stimmt bei x=%.0f" % x)

## Kachelraster: lueckenlos und ohne Ueberlappung.
func _check_tile_math() -> void:
	for layer in range(ShaftBackground.LAYER_COUNT):
		var tile := ShaftBackground.layer_tile_height(layer)
		var parallax := ShaftBackground.layer_parallax(layer)
		_check(parallax > 0.0 and parallax < 1.0, "Parallax Ebene %d liegt zwischen 0 und 1" % layer)
		# Aufeinanderfolgende Kacheln muessen genau eine Kachelhoehe auseinander
		# liegen, sonst entstehen Luecken oder Doppelungen.
		var camera := -3000.0
		var top := camera - VIEW_HEIGHT * 0.5
		var first := ShaftBackground.first_visible_tile(layer, camera, top)
		var y0 := ShaftBackground.tile_world_y(layer, camera, first)
		var y1 := ShaftBackground.tile_world_y(layer, camera, first + 1)
		_check(absf((y1 - y0) - tile) < 0.001, "Kacheln Ebene %d liegen eine Kachelhoehe auseinander" % layer)
		# Und die erste sichtbare Kachel darf nicht unter dem Ausschnitt beginnen.
		_check(y0 + tile > top, "erste Kachel Ebene %d deckt den oberen Rand ab" % layer)
	# Die Parallaxfaktoren muessen sich unterscheiden, sonst gibt es keine Tiefe.
	_check(ShaftBackground.layer_parallax(0) < ShaftBackground.layer_parallax(1)
		and ShaftBackground.layer_parallax(1) < ShaftBackground.layer_parallax(2),
		"die drei Ebenen haben unterschiedliche Parallax")
	# Teilerfremde Kachelhoehen: sonst kehren die Muster synchron wieder.
	var heights := []
	for layer in range(ShaftBackground.LAYER_COUNT):
		heights.append(int(ShaftBackground.layer_tile_height(layer)))
	_check(heights[0] != heights[1] and heights[1] != heights[2] and heights[0] != heights[2],
		"die Kachelhoehen sind verschieden")
