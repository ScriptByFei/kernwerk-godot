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
			# Massige Stahltuer: bleibt in der Ruhezone (sie IS die Wand), deckt
			# die Plattformbreite ab, reicht aber nicht bis an die Randtechnik.
			var door := Background.door_rect(top)
			_check(door.position.x >= 280.0 and door.end.x <= 800.0, "Tuer liegt ganz in der Ruhezone")
			_check(door.size.x >= 500.0 and door.size.y >= 700.0, "Tuer ist gross und massiv")
			_check(door.position.y == top and door.end.y == top + 760.0, "Tuer folgt der Fernschicht-Kachel")
			for seg in Background.pearl_segments(top):
				_check(seg.size.x <= 12.0 and seg.size.y >= 8.0 and seg.size.y <= 60.0, "Perlen sind kurze Striche")
				_check(seg.position.x + seg.size.x * 0.5 >= 530.0 and seg.position.x + seg.size.x * 0.5 <= 550.0, "Perlen sitzen in der Mittelachse")
				_check(seg.end.y <= door.end.y and seg.position.y >= top, "Perlen liegen im Tuerfeld")
				_check(seg.size.y < Background.layer_tile_height(0) * 0.3, "Perlen sind nie eine durchgezogene Linie")
	print("SHAFT GEOMETRY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
