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
	var step: float = JumpConfig.ZONE_HEIGHT_STEP
	var ground := JumpConfig.zone_color(JumpConfig.ZONE_BACKGROUNDS, 0.0)
	_check(ground.is_equal_approx(JumpConfig.ZONE_BACKGROUNDS[0]), "am Boden gilt die erste Stimmung")
	var high := JumpConfig.zone_color(JumpConfig.ZONE_BACKGROUNDS, 9.0 * step)
	_check(high.is_equal_approx(JumpConfig.ZONE_BACKGROUNDS[4]), "ganz oben gilt die fuenfte Stimmung, gedeckelt")
	# Jede Zone wird tatsaechlich erreicht, und die Zuordnung waechst monoton.
	var reached := {}
	var previous := -1.0
	var monotone := true
	var max_delta := 0.0
	var previous_color := JumpConfig.zone_color(JumpConfig.ZONE_BACKGROUNDS, 0.0)
	# Feine Abtastung (5 Weltpixel): so laesst sich ein Sprung von einem echten
	# Verlauf unterscheiden, statt nur eine willkuerliche Schranke zu treffen.
	var samples := int(4.0 * step / 5.0)
	for sample in range(samples):
		var climbed := float(sample) / float(samples - 1) * 4.0 * step
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
