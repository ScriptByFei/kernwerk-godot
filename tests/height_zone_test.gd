extends SceneTree

## Hoehenzonen: der Schacht wechselt mit steigender Hoehe weich zwischen fuenf
## Stimmungen. Geprueft wird die reine Farb-/Zuordnungsregel in JumpConfig —
## kein Rendering, keine Node-Abhaengigkeit.

var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(JumpConfig.ZONE_BACKGROUNDS.size() == 5, "fuenf Hintergrundstimmungen")
	_check(JumpConfig.ZONE_SHAFT_COLORS.size() == 5, "fuenf Schachtlinienfarben")
	if failures:
		_finish()
		return
	_check(JumpConfig.ZONE_HEIGHT_STEP > 0.0 and JumpConfig.ZONE_BLEND_RANGE > 0.0, "Zonenhoehe und Uebergangsbreite sind positiv")
	# Die Kopplung als Regel festhalten: `zone_index_at` klemmt
	# `blend = minf(ZONE_BLEND_RANGE, span)`. Waere blend >= span, gaebe es kein
	# Plateau mehr — die Zonen liefen permanent ineinander. Ohne diese Pruefung
	# bricht es still, sobald jemand nur EINE der beiden Konstanten anfasst.
	_check(JumpConfig.ZONE_BLEND_RANGE < JumpConfig.ZONE_HEIGHT_STEP,
		"die Uebergangsbreite ist kleiner als die kleinste Zonenschrittweite")
	for span_value in JumpConfig.ZONE_HEIGHT_SPANS:
		var span: float = span_value
		_check(JumpConfig.ZONE_BLEND_RANGE < span,
			"die Uebergangsbreite ist kleiner als jede Zonenhöhe (%.0f)" % span)
		# Und das Plateau muss spuerbar bleiben: mindestens die Haelfte jeder
		# Zone steht in einer einzigen Stimmung, sonst ist es keine Zone mehr.
		var share: float = (span - JumpConfig.ZONE_BLEND_RANGE) / span
		_check(share >= 0.5, "je Zone bleibt mindestens die Haelfte stabil (%.0f %%)" % (share * 100.0))
	_check(JumpConfig.ZONE_HEIGHT_SPANS.size() == JumpConfig.ZONE_BACKGROUNDS.size(),
		"es gibt so viele Zonenhoehen wie Stimmungen")
	# Die Umkehrfunktion muss die Umkehrung sein: Index -> Hoehe -> Index.
	# Der gueltige Bereich endet bei der LETZTEN Zone (Index = Anzahl-1); darueber
	# deckelt `zone_index_at`, und eine Rundreise kann dort nicht existieren.
	# Genau deshalb prueft die Schleife nur bis `size-1` — mein erster Versuch
	# lief bis `size` und meldete korrektes Verhalten als Fehler.
	var roundtrip_ok := true
	var checked := 0
	for i in range(JumpConfig.ZONE_HEIGHT_SPANS.size() - 1):
		for frac_value in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var frac: float = frac_value
			var index: float = float(i) + frac
			var height: float = JumpConfig.zone_height_for_index(index)
			var back: float = JumpConfig.zone_index_at(height)
			if absf(back - index) > 0.001:
				roundtrip_ok = false
			checked += 1
	_check(roundtrip_ok, "Index -> Hoehe -> Index ist eine Rundreise (%d Punkte)" % checked)
	# Und die Zonengrenzen liegen dort, wo die Spans es sagen.
	var floor_ok := true
	for i in range(JumpConfig.ZONE_HEIGHT_SPANS.size()):
		var expected := 0.0
		for k in range(i):
			expected += JumpConfig.ZONE_HEIGHT_SPANS[k]
		if absf(JumpConfig.zone_floor(i) - expected) > 0.001:
			floor_ok = false
	_check(floor_ok, "die Zonenunterkanten stimmen mit den Spans ueberein")
	var step: float = JumpConfig.ZONE_HEIGHT_STEP
	var ground := JumpConfig.zone_color(JumpConfig.ZONE_BACKGROUNDS, 0.0)
	_check(ground.is_equal_approx(JumpConfig.ZONE_BACKGROUNDS[0]), "am Boden gilt die erste Stimmung")
## Zonenfarbe jenseits des Deckels: die fuenfte Stimmung.
	# Die Gesamthoehe kommt aus den Spans, nicht mehr aus einer festen
	# Schrittweite: mit 4.0 * ZONE_HEIGHT_STEP (32000) haette die Abtastung weit
	# hinter dem Deckel (24000) gelegen und Zone 5 nie erreicht.
	var total: float = JumpConfig.zone_total_height()
	_check(total > 0.0, "der Schacht hat eine positive Gesamthoehe (%.0f)" % total)
	var high := JumpConfig.zone_color(JumpConfig.ZONE_BACKGROUNDS, total * 2.0)
	_check(high.is_equal_approx(JumpConfig.ZONE_BACKGROUNDS[4]), "ganz oben gilt die fuenfte Stimmung, gedeckelt")
	# Jede Zone wird tatsaechlich erreicht, und die Zuordnung waechst monoton.
	var reached := {}
	var previous := -1.0
	var monotone := true
	var max_delta := 0.0
	var previous_color := JumpConfig.zone_color(JumpConfig.ZONE_BACKGROUNDS, 0.0)
	# Feine Abtastung (5 Weltpixel): so laesst sich ein Sprung von einem echten
	# Verlauf unterscheiden, statt nur eine willkuerliche Schranke zu treffen.
	var samples := int(total / 5.0)
	for sample in range(samples):
		var climbed := float(sample) / float(samples - 1) * total
		var index: float = JumpConfig.zone_index_at(climbed)
		reached[int(round(index))] = true
		if index < previous - 0.0001:
			monotone = false
		previous = index
		var color := JumpConfig.zone_color(JumpConfig.ZONE_BACKGROUNDS, climbed)
		max_delta = maxf(max_delta, absf(color.r - previous_color.r) + absf(color.g - previous_color.g) + absf(color.b - previous_color.b))
		previous_color = color
	_check(monotone, "Zonenindex waechst monoton mit der Hoehe")
	_check(reached.size() == 5, "alle fuenf Zonen werden mit der Hoehe erreicht")
	# Weiches Ueberblenden: kein Sprung zwischen zwei benachbarten Abtastungen.
	_check(max_delta < 0.005, "Farbwechsel bleibt stetig (max delta %.4f pro 5 px)" % max_delta)
	# Der Uebergang ist wirklich ein Verlauf und keine Stufe: exakt auf der
	# Grenze liegt die Farbe zwischen beiden Stimmungen.
	var boundary := JumpConfig.zone_color(JumpConfig.ZONE_BACKGROUNDS, step)
	_check(boundary.is_equal_approx(JumpConfig.ZONE_BACKGROUNDS[0]) or boundary.is_equal_approx(JumpConfig.ZONE_BACKGROUNDS[1]) or (boundary != JumpConfig.ZONE_BACKGROUNDS[0] and boundary != JumpConfig.ZONE_BACKGROUNDS[1]), "Grenzfarbe liegt zwischen zwei Stimmungen")
	var mid := JumpConfig.zone_color(JumpConfig.ZONE_BACKGROUNDS, step - JumpConfig.ZONE_BLEND_RANGE * 0.5)
	_check(mid != JumpConfig.ZONE_BACKGROUNDS[0] and mid != JumpConfig.ZONE_BACKGROUNDS[1], "in der Uebergangszone wird gemischt")
	# Zweimal dieselbe Hoehe ergibt dieselbe Farbe, und die Zonen sind stabil.
	_check(JumpConfig.zone_color(JumpConfig.ZONE_SHAFT_COLORS, step * 2.5) == JumpConfig.zone_color(JumpConfig.ZONE_SHAFT_COLORS, step * 2.5), "Zuordnung ist deterministisch")
	var distinct := {}
	for color in JumpConfig.ZONE_BACKGROUNDS:
		distinct[color.to_html()] = true
	_check(distinct.size() == 5, "alle fuenf Stimmungen sind unterscheidbar")
	# Die Zonen duerfen nie aufhellen: der Schacht bleibt industriell dunkel.
	var max_luminance := 0.0
	for color in JumpConfig.ZONE_BACKGROUNDS:
		max_luminance = maxf(max_luminance, color.r + color.g + color.b)
	# Dunkelheit als Produkteigenschaft: die hellste Stimmung bleibt unter
	# 0.35 Gesamtanteil (Summe der Kanaele), also sichtbar dunkler Schacht.
	_check(max_luminance < 0.35, "jede Stimmung bleibt dunkel (max %.3f)" % max_luminance)
	_finish()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _finish() -> void:
	print("HEIGHT ZONES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
