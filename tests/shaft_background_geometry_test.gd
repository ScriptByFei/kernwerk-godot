extends SceneTree
const Background := preload("res://scripts/jump/shaft_background.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)

func _outside(rect: Rect2) -> bool:
	return rect.end.x < 280.0 or rect.position.x > 800.0

func _run() -> void:
	_check(Background.QUIET_HALF_WIDTH == 260.0, "Ruhezone exakt 260")
	_check(Background.LAYER_PARALLAX == [0.22, 0.40, 0.62], "Parallax unveraendert")
	for side in [-1.0, 1.0]:
		for top in [-9000.0, 0.0, 9000.0]:
			var body := Background.machinery_rect(1080.0, side, top)
			var light := Background.lamp_surface(1080.0, side, top)
			var deck := Background.deck_rect(1080.0, side, top)
			var pipe := Background.foreground_pipe_span(1080.0, side)
			var pipe_light := Background.pipe_light_surface(1080.0, side, top)
			_check(body.encloses(light), "Licht liegt vollstaendig auf Metall")
			_check(_outside(body), "ganzer Maschinenkoerper ausserhalb Ruhezone")
			_check(_outside(light), "ganze Lichtflaeche ausserhalb Ruhezone")
			_check(_outside(deck), "voller Wartungssteg ausserhalb Ruhezone")
			_check(_outside(Background.flange_rect(1080.0, side, top)), "auch Rohrflansch ausserhalb Ruhezone")
			var inner := Background.inner_pipe_span(1080.0, side)
			_check(_outside(Rect2(inner.x, top, inner.y - inner.x, 40.0)), "ganzer innerer Rohrkoerper ausserhalb Ruhezone")
			var valve := Background.valve_center(1080.0, side, top)
			_check(_outside(Rect2(valve - Vector2(34.0, 34.0), Vector2(68.0, 68.0))), "Ventilradius meidet Ruhezone")
			_check(pipe_light.position.x >= pipe.x and pipe_light.end.x <= pipe.y, "Rohrlicht hat eine tragende Rohrflaeche")
			_check(light.size.x >= 80.0 and light.size.y >= 140.0, "Warmlicht ist Masse statt Punkt")
			_check(body.size.x >= 120.0 and pipe.y - pipe.x >= 70.0, "breite Maschinen und Rohrkoerper")
			_check(body == Background.machinery_rect(1080.0, side, top), "Geometrie reproduzierbar")
			# Massive Stahltuer: bleibt in der Ruhezone (sie IS die Wand), deckt
			# die Plattformbreite ab, reicht aber nicht bis an die Randtechnik.
			var door := Background.door_rect(top)
			_check(door.position.x >= 280.0 and door.end.x <= 800.0, "Tuer liegt ganz in der Ruhezone")
			_check(door.size.x >= 500.0 and door.size.y >= 700.0, "Tuer ist gross und massiv")
			_check(door.position.y == top and door.end.y == top + 760.0, "Tuer folgt der Fernschicht-Kachel")
			# Struktur: zwei Blattflaechen, dazwischen die Mittelritze.
			var leaves := Background.door_leaf_rects(top)
			_check(leaves.size() == 2, "Tuer hat zwei Blattflaechen")
			_check(leaves[0].end.x < leaves[1].position.x, "zwischen den Blaettern bleibt die Ritze offen")
			var gap := leaves[1].position.x - leaves[0].end.x
			_check(gap >= 4.0 and gap <= 10.0, "Mittelritze ist schmal")
			for leaf in leaves:
				_check(leaf.position.x >= door.position.x and leaf.end.x <= door.end.x, "Blatt bleibt im Tuerfeld")
				_check(leaf.position.y == top and leaf.end.y == door.end.y, "Blatt deckt die Tuerhoehe")
			# Verstrebungen: zwei durchgehende Schraegen, bilden ein X.
			var quads := Background.door_brace_quads(top)
			var braces := Background.door_brace_bounds(top)
			_check(quads.size() == 2 and braces.size() == 2, "Tuer hat zwei Verstrebungen")
			for i in quads.size():
				var quad := quads[i]
				_check(quad.size() == 4, "Verstrebung ist ein geschlossenes Viereck")
				# Dicke quer zum Balken: Abstand der beiden Endkanten.
				var thickness := quad[1].distance_to(quad[2])
				_check(thickness >= 6.0 and thickness <= 14.0, "Verstrebung ist ein schmaler Balken")
				# Laenge entlang des Balkens deutlich groesser als die Dicke.
				_check(quad[0].distance_to(quad[1]) > thickness * 3.0, "Verstrebung ist laenger als dick")
				var b := braces[i]
				_check(b.position.x >= door.position.x and b.end.x <= door.end.x, "Verstrebung bleibt im Tuerfeld")
				_check(b.position.y >= top and b.end.y <= door.end.y, "Verstrebung bleibt in der Tuerhoehe")
			# X-Form: die beiden Schraegen laufen in ENTGEGENGESETZTE x-Richtung.
			# Ueber die Huellbox ist das nicht messbar — beide spannen dieselbe
			# Breite auf. Die Richtung steckt in den Eckpunkten des Vierecks:
			# quad[0] und quad[1] sind die beiden Enden des Balkens.
			var mid_x: float = door.position.x + door.size.x * 0.5
			var mid_y: float = top + door.size.y * 0.5
			var dir0: float = quads[0][1].x - quads[0][0].x
			var dir1: float = quads[1][1].x - quads[1][0].x
			_check(dir0 * dir1 < 0.0, "die beiden Schraegen laufen gegenlaeufig und bilden ein X")
			for quad in quads:
				_check(absf(quad[0].y - quad[1].y) > door.size.y * 0.4,
					"Schraege ueberspannt einen grossen Teil der Tuerhoehe")
				# Mittelpunkt der Balkenachse. NICHT einfach (quad[0]+quad[1])/2:
				# die Dicke verschiebt beide Enden gleich, das ergaebe einen um
				# die halbe Balkendicke verschobenen Punkt. Die Achse liegt
				# zwischen den Mitten der beiden Endkanten.
				var axis_mid: Vector2 = ((quad[0] + quad[3]) * 0.5 + (quad[1] + quad[2]) * 0.5) * 0.5
				_check(absf(axis_mid.y - mid_y) < 2.0, "Schraege kreuzt die Mitte der Tuer")
				_check(absf(axis_mid.x - mid_x) < 2.0, "Schraege kreuzt die Mittelachse der Tuer")
			# Beide Schraegen spannen die volle Tuerhoehe auf: das X traegt die
			# Lesbarkeit, ein kurzes Stueck taete es nicht.
			for b in braces:
				_check(b.size.y > door.size.y * 0.4, "Verstrebung ueberspannt einen grossen Teil der Tuer")
			_check(Background.pearl_segments(top).is_empty(), "keine Perlen-Fuehrung in der Spielmitte")
	_check(_door_contrast_ok(), "alle Tuerfarben halten den Plattformkontrast >= 1.81")
	print("SHAFT GEOMETRY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

## Die harte Ruhezonen-Regel: kein Tuer-Ton darf den Kontrast zum
## Plattformkoerper unter 1.81 senken. Gerechnet mit Godots eigener
## Luminanzfunktion, nicht nachgebaut. Genau das begrenzt, wie hell die
## Tuerstruktur werden darf — und ist damit die Grenze fuer kuenftige Arbeit.
func _door_contrast_ok() -> bool:
	var body: float = JumpConfig.PLATFORM_BODY_COLOR.get_luminance() + 0.05
	var palette := {
		"DOOR_PANEL": Background.DOOR_PANEL,
		"DOOR_PANEL_DEEP": Background.DOOR_PANEL_DEEP,
		"DOOR_BASE": Background.DOOR_BASE,
		"DOOR_FUGE": Background.DOOR_FUGE,
		"DOOR_BRACE": Background.DOOR_BRACE,
		"PEARL": Background.PEARL,
	}
	var ok := true
	for name in palette:
		var lum: float = (palette[name] as Color).get_luminance()
		var ratio: float = body / (lum + 0.05)
		if ratio < 1.81:
			ok = false
			print("FAIL: %s hat nur %.3f gegen die Plattform (Grenze 1.81)" % [name, ratio])
	return ok
