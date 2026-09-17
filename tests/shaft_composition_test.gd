extends SceneTree
var B = preload("res://scripts/jump/shaft_background.gd").new()
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)
func _init() -> void:
	if not B.has_method("module_kind"):
		check(false, "module schedule missing")
	else:
		var kinds := {}
		for i in range(-2000, 2001):
			var kind: int = B.module_kind(i)
			kinds[kind] = true
			check(kind >= 0 and kind < 4, "four modules including negative indices")
			if kind == 0:
				check(B.module_kind(i + 1) != 0 and B.module_kind(i + 2) != 0, "door spacing including wrap")
			for camera in [-9999.0, 0.0, 5678.0]:
				var top: float = B.tile_world_y(0, camera, i)
				check(B.first_visible_tile(0, camera, top + 0.1) == i, "stable world index")
				check(B.module_kind(i) == kind, "camera cannot change identity")
		check(kinds.size() == 4, "all four kinds reached")
		var reached := {}
		# Die Probehoehen aus der Konfiguration ABLEITEN, nicht als Pixelzahlen
		# hinschreiben. Der Grund, gemessen:
		#
		# `zone_index_at` liefert ueber das ganze PLATEAU einer Zone exakt 0.0 —
		# der Uebergang beginnt erst danach. Das Plateau ist `step - blend` hoch,
		# frueher 9000-3500 = 5500 px, jetzt 3000-1200 = 1800 px. Prozentual ist
		# das praktisch gleich (61 % -> 60 %), aber die fest eingetragenen Hoehen
		# 1800 und 4500 px lagen nur zufaellig im alten Plateau. Nach der Stauchung
		# lagen sie im Uebergang bzw. hinter der Zone, und die Pruefung "voll
		# sichtbar" schlug zu Recht an.
		#
		# Gesammelt wird ueber ALLE Probehoehen (gemeinsames `reached`). Ein
		# einzelner Ausschnitt zeigt nur 4 Kacheln (Typen 0/1/2) — Typ 3 (Service)
		# liegt im 12er-Takt deutlich weiter. Deshalb MEHRERE Hoehen abtasten,
		# statt die Pruefung abzuschwaechen: mit 3 Punkten auf dem gestauchten
		# Plateau wurde Typ 3 nicht mehr erreicht (gemessen), mit einer feineren
		# Abtastung ueber das ganze Fenster schon.
		# Die Hoehe der ERSTEN Zone kommt aus den Spans — nicht aus
		# ZONE_HEIGHT_STEP, das nur noch eine Nennkonstante fuer grobe
		# Rueckwaertsrechnungen ist. Sonst haengt die Probe an einem Wert, der
		# nicht die tatsaechliche Zonengroesse beschreibt.
		var first_span: float = JumpConfig.ZONE_HEIGHT_SPANS[0]
		var top_limit: float = B.ZONE_FADE_START * first_span
		var sample_offset: float = 1170.0 - 260.0
		var samples := 12
		for step_i in range(samples):
			var height: float = float(step_i) / float(samples - 1) * maxf(top_limit - sample_offset, 1.0)
			var camera: float = -height + 260.0
			var rect := Rect2(0, camera - 1170, 1080, 2340)
			var index: float = JumpConfig.zone_index_at(-rect.position.y)
			check(index < B.ZONE_FADE_START, "Probehoehe liegt im Fenster des Schachts (Index %.2f < %.2f)" % [index, B.ZONE_FADE_START])
			check(B.opacity_for_zone(index) == 1.0, "actual zone fully visible")
			var first: int = B.first_visible_tile(0, camera, rect.position.y)
			for i in range(first, first + B.visible_tile_count(0, camera, rect.position.y, rect.end.y)):
				reached[B.module_kind(i)] = true
		check(reached.size() == 4, "all modules reached before fade (erreicht: %d)" % reached.size())
		# Und die Absicht dahinter als eigene Regel festhalten: damit alle vier
		# Modultypen erscheinen, muss die ERSTE Zone hoch genug sein. Die Fernwand
		# laeuft mit Parallax 0.22 und verschiebt sich im Fenster nur um 0.22 *
		# Fensterhoehe; ein zu kurzes Fenster zeigt dauerhaft denselben Kachelsatz.
		# Gemessen: 1650 px Fenster -> 3 Typen, 4400 px Fenster -> 4 Typen.
		# Genau deshalb ist Zone 1 groesser als die uebrigen. Ohne diese Pruefung
		# blieb eine gleichmaessige Stauchung unbemerkt (Mutationsprobe M3).
		var window: float = B.ZONE_FADE_START * first_span
		var far_shift: float = B.layer_parallax(0) * window
		var tiles_spanned: float = far_shift / B.layer_tile_height(0)
		check(tiles_spanned >= 1.0,
			"die Fernwand verschiebt sich im ersten Zonenfenster um mindestens eine Kachel (%.2f)" % tiles_spanned)
		var variants := {}
		for block in range(-40, 40):
			variants[B.module_kind(-(block * 12 + 9))] = true
		check(variants.size() == 2, "schedule is not a repeated twelve-bay tile")
		var active := 0
		for t in range(80):
			var events: Array = B.atmosphere_events(Rect2(0, -float(t)*211, 1080, 2340), float(t)*0.5)
			active += events.size()
			check(events.size() <= 2, "global atmosphere bound")
			for event in events:
				var r: Rect2 = event.rect
				check(r.end.x < 280 or r.position.x > 800, "whole atmosphere footprint outside quiet area")
		check(active > 0, "atmosphere is not a dead branch")
		for r in B.right_conduit_rects(Rect2(0, -100, 1080, 2340)):
			check(r.position.x > 800 and r.end.x <= 1080, "right mass outside quiet area")
			check(r.size.x >= 60 and r.size.y == 2340, "large continuous form")
		check(B.pearl_segments(0).is_empty(), "no central guide pearls")
	print("SHAFT COMPOSITION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
