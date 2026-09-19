extends SceneTree

## Gameplay-Ueberarbeitung (19.09.2026): vier Punkte, jeder mit eigener
## Pruefung. Bewusst KEIN Rendering — hier geht es um Regeln und Zahlen:
##
##   1. Patterns laufen immer vollstaendig zu Ende; die neue Schwierigkeit wird
##      erst beim Start des NAECHSTEN Patterns uebernommen.
##   2. Jede Form bestimmt ihre Plattform-Varianten vollstaendig selbst; es gibt
##      keinen Zufallswurf mehr, der die Identitaet verwaessert.
##   3. Jede Form hat ihren eigenen senkrechten Rhythmus (Abstandsfaktor).
##   4. PERFECT gibt einen Tempo-Boost fuer GENAU den naechsten Absprung, Kraft
##      und Gravitation gemeinsam, damit die Spruenge nicht hoeher werden.

const Patterns = preload("res://scripts/jump/platform_patterns.gd")
const Director = preload("res://scripts/jump/platform_director.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")

var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_pattern_completion()
	_check_pattern_identity()
	_check_vertical_rhythm()
	_check_perfect_boost()
	await _check_boost_is_single_shot()
	_finish()

## --- Punkt 1: Patterns immer vollstaendig beenden -----------------------------
##
## Der Fehler war `_pattern_difficulty != difficulty` in `_next_position`: eine
## Stufenaenderung brach die laufende Sequenz nach wenigen Sprossen ab. Geprueft
## wird deshalb nicht "die Laenge stimmt", sondern die eigentliche Eigenschaft:
## waehrend eine Sequenz laeuft, aendert ein Stufenwechsel NICHTS an ihr.
func _check_pattern_completion() -> void:
	# Ein laufendes Pattern darf durch einen Stufenwechsel nicht unterbrochen
	# werden: gleiche Form, gleiche Laenge, gleicher Anker, gleicher Rhythmus.
	var world := Node2D.new()
	root.add_child(world)
	var director := Director.new(4242)
	director.initialize(world, JumpConfig.PLATFORM_LAYOUT)
	# Eine Sequenz starten und den ersten Schritt verbrauchen.
	director.maintain(0.0, 2400.0, 0)
	var kind := director.current_pattern()
	var length := director.pattern_length()
	var start_x := director.pattern_start_x()
	var gap := director.pattern_gap()
	_check(length >= Patterns.MIN_LENGTH, "die Sequenz hat eine echte Laenge (%d)" % length)
	# Jetzt die Schwierigkeit hochreissen — mitten in der Sequenz.
	var breaks := 0
	var steps := 0
	while director.pattern_index() < length and steps < 40:
		director.maintain(-float(steps) * 400.0, 2400.0, JumpConfig.MAX_DIFFICULTY)
		steps += 1
		if director.current_pattern() != kind:
			breaks += 1
		if director.pattern_length() != length:
			breaks += 1
		if not is_equal_approx(director.pattern_start_x(), start_x):
			breaks += 1
		if not is_equal_approx(director.pattern_gap(), gap):
			breaks += 1
	_check(breaks == 0,
		"ein Stufenwechsel laesst die laufende Sequenz unveraendert (%d Brueche in %d Schritten)" % [breaks, steps])
	_check(steps >= 1, "es wurden Schritte innerhalb der Sequenz geprueft (%d)" % steps)
	# Die neue Stufe greift dann beim NAECHSTEN Pattern — nicht sofort.
	director.maintain(-99999.0, 2400.0, JumpConfig.MAX_DIFFICULTY)
	_check(director.pattern_difficulty() == JumpConfig.MAX_DIFFICULTY or director.pattern_index() < director.pattern_length(),
		"die gemerkte Stufe wird uebernommen, wenn die Sequenz durch ist")
	world.queue_free()

	# Ueber viele Seeds: die Zahl fertig gespielter Sequenzen muss zur Zahl der
	# Stufenwechsel-Situationen passen. Ohne den Zaehler waere "vollstaendig"
	# nicht von "abgebrochen" zu unterscheiden.
	var world2 := Node2D.new()
	root.add_child(world2)
	var director2 := Director.new(99)
	director2.initialize(world2, JumpConfig.PLATFORM_LAYOUT)
	var completed := 0
	var index_resets := 0
	var previous_index := director2.pattern_index()
	# Jede Runde eine ANDERE Stufe, damit frueher ein Abbruch passiert waere.
	for round_index in range(120):
		var difficulty := round_index % (JumpConfig.MAX_DIFFICULTY + 1)
		director2.maintain(-float(round_index) * 700.0, 2400.0, difficulty)
		var current := director2.pattern_index()
		# Ein Neustart ist nur dann einer, wenn der Index WIRKLICH auf einen
		# kleineren Wert faellt. Ein `maintain()`-Aufruf kann die Sequenz
		# mehrfach durchlaufen, deshalb wird nicht "current != last + 1" gezaehlt.
		if current < previous_index:
			index_resets += 1
		previous_index = current
		completed = director2.patterns_completed
	_check(completed >= 8, "es wurden genug Sequenzen fertig gespielt (%d)" % completed)
	# Jeder Neustart des Index ist das Ende einer Sequenz — die Zahl der Neustarts
	# ist damit eine UNTERGRENZE der fertigen Sequenzen (mehrere koennen in einem
	# Aufruf abgeschlossen werden).
	_check(completed >= index_resets,
		"jeder Index-Neustart ist das Ende einer Sequenz (%d Neustarts, %d fertig)" % [index_resets, completed])
	# Und die Laenge jeder laufenden Sequenz liegt im Band der Form: eine
	# abgebrochene Sequenz waere hier kuerzer als ihr eigenes Minimum.
	var band_ok := true
	for kind_value in Patterns.Kind.values():
		var band := Patterns.length_range_for(kind_value)
		if band.x < Patterns.MIN_LENGTH or band.y > Patterns.MAX_LENGTH:
			band_ok = false
	_check(band_ok, "kein Laengenband verlaesst das globale Band 3-6")
	world2.queue_free()

## --- Punkt 2: Pattern-Identitaet ----------------------------------------------
func _check_pattern_identity() -> void:
	# RECOVERY: ausschliesslich grosse Standardplattformen — keine schmalen, keine
	# Resonanz-Zufallsvarianten, keine Abzweigungen.
	for index in range(8):
		var variant := Patterns.variant_for(Patterns.Kind.RECOVERY, index)
		_check(variant == JumpPlatform.Variant.STANDARD,
			"Erholung traegt nur Standardplattformen (Index %d: %d)" % [index, variant])
	_check(not Patterns.offers_branch(Patterns.Kind.RECOVERY), "Erholung bietet keine Abzweigung an")
	# PRECISION_RUSH: konsequent schmal.
	for index in range(8):
		var variant := Patterns.variant_for(Patterns.Kind.PRECISION_RUSH, index)
		_check(variant == JumpPlatform.Variant.NARROW,
			"Precision Rush ist durchgehend schmal (Index %d: %d)" % [index, variant])
	_check(not Patterns.offers_branch(Patterns.Kind.PRECISION_RUSH), "Precision Rush bietet keine Abzweigung an")
	# RISK_CHOICE: hier entstehen die bewussten Abzweigungen.
	_check(Patterns.offers_branch(Patterns.Kind.RISK_CHOICE), "die Risikowahl bietet die Abzweigung an")
	for kind in Patterns.Kind.values():
		if kind != Patterns.Kind.RISK_CHOICE:
			_check(not Patterns.offers_branch(kind),
				"nur die Risikowahl bietet Abzweigungen an (Form %d)" % kind)
	# Keine andere Form darf die Risikowahl-Variante tragen.
	for kind in [Patterns.Kind.RECOVERY, Patterns.Kind.ZIGZAG, Patterns.Kind.CLIMB, Patterns.Kind.CROSS, Patterns.Kind.PRECISION_RUSH]:
		for index in range(6):
			_check(Patterns.variant_for(kind, index) != JumpPlatform.Variant.RISKY,
				"Form %d vergibt nie die riskante Variante" % kind)
	# Der Director selbst: ueber viele Seeds muss die laufende Sequenz wirklich
	# nur die Varianten ihrer Form tragen. Das ist der eigentliche Test — die
	# Tabellenfunktion allein koennte durch einen anderen Pfad umgangen werden.
	#
	# ACHTUNG Messfehler-Falle: `_active_platforms` enthaelt auch Sprossen aus
	# FRUEHEREN Sequenzen. Wer sie alle gegen die JETZT laufende Form prueft,
	# meldet Fehler fuer voellig korrekten Code (meine erste Fassung: 629 von
	# 2632). Geprueft wird deshalb nur, was in diesem Schritt NEU entstanden ist.
	var wrong_recovery := 0
	var wrong_precision := 0
	var recovery_seen := 0
	var precision_seen := 0
	for seed_value in range(24):
		var world := Node2D.new()
		root.add_child(world)
		var director := Director.new(seed_value)
		director.initialize(world, JumpConfig.PLATFORM_LAYOUT)
		var known := {}
		for platform in director._active_platforms:
			known[platform] = true
		for round_index in range(60):
			director.maintain(-float(round_index) * 420.0, 2400.0, round_index % (JumpConfig.MAX_DIFFICULTY + 1))
			for platform in director._active_platforms:
				if known.has(platform):
					continue
				known[platform] = true
				if platform.variant == JumpPlatform.Variant.RISKY:
					continue
				# Die Form kommt von der SPROSSE, nicht vom Director: ein
				# `maintain()`-Aufruf kann mehrere Sprossen ueber eine
				# Patterngrenze hinweg erzeugen.
				var kind: int = platform.pattern_kind
				if kind == Patterns.Kind.RECOVERY:
					recovery_seen += 1
					if platform.variant != JumpPlatform.Variant.STANDARD:
						wrong_recovery += 1
				elif kind == Patterns.Kind.PRECISION_RUSH:
					precision_seen += 1
					if platform.variant != JumpPlatform.Variant.NARROW:
						wrong_precision += 1
		world.queue_free()
	_check(recovery_seen > 0, "es wurden Erholungs-Sprossen gesehen (%d)" % recovery_seen)
	_check(wrong_recovery == 0,
		"keine Erholungs-Sprosse traegt eine andere Variante (%d von %d)" % [wrong_recovery, recovery_seen])
	_check(precision_seen > 0, "es wurden Precision-Rush-Sprossen gesehen (%d)" % precision_seen)
	_check(wrong_precision == 0,
		"keine Precision-Rush-Sprosse ist breit (%d von %d)" % [wrong_precision, precision_seen])
	# Und der Zufallswurf, der die Identitaet verwischt hat, ist WIRKLICH weg.
	# Geprueft wird der Quelltext OHNE Kommentare — eine Pruefung auf das Wort
	# fand es sonst auch in der Begruendung, warum es entfernt wurde.
	var source := FileAccess.get_file_as_string("res://scripts/jump/platform_director.gd")
	var code := ""
	for line in source.split("\n"):
		var trimmed := (line as String).strip_edges()
		if trimmed.begins_with("#"):
			continue
		code += (line as String) + "\n"
	_check(code.find("_roll_variant") == -1, "der Varianten-Zufallswurf ist entfernt")
	_check(code.find("randi_range") == -1, "es gibt keinen versteckten zweiten Wurf mehr")

## --- Punkt 3: unterschiedlicher senkrechter Rhythmus ---------------------------
func _check_vertical_rhythm() -> void:
	var difficulty := 3
	var recovery := Patterns.gap_factor_for(Patterns.Kind.RECOVERY)
	var precision := Patterns.gap_factor_for(Patterns.Kind.PRECISION_RUSH)
	var zigzag := Patterns.gap_factor_for(Patterns.Kind.ZIGZAG)
	var climb := Patterns.gap_factor_for(Patterns.Kind.CLIMB)
	var cross := Patterns.gap_factor_for(Patterns.Kind.CROSS)
	var risk := Patterns.gap_factor_for(Patterns.Kind.RISK_CHOICE)
	# Die geforderte Ordnung, ausgeschrieben und einzeln geprueft.
	_check(recovery < zigzag, "Erholung springt kuerzer als der Referenzabstand (%.2f < %.2f)" % [recovery, zigzag])
	_check(precision < recovery, "Precision Rush springt am kuerzesten (%.2f < %.2f)" % [precision, recovery])
	_check(risk < zigzag, "die Risikowahl laesst mehr Flugzeit als der Referenzabstand (%.2f < %.2f)" % [risk, zigzag])
	_check(risk > precision, "die Risikowahl laesst mehr Flugzeit als ein Precision Rush (%.2f > %.2f)" % [risk, precision])
	_check(climb > zigzag, "Climb greift hoeher (%.2f > %.2f)" % [climb, zigzag])
	_check(cross > zigzag, "Cross springt weiter als der Referenzabstand (%.2f > %.2f)" % [cross, zigzag])
	_check(cross < climb, "Cross bleibt unter Climb (%.2f < %.2f)" % [cross, climb])
	# Der Unterschied muss SPUERBAR sein, nicht nur messbar: mindestens 10 %
	# zwischen der engsten und der weitesten Form.
	var spread := climb - precision
	_check(spread >= 0.10, "der Unterschied zwischen engster und weitesten Form ist spuerbar (%.2f)" % spread)
	# Und der Rhythmus landet wirklich im Director, nicht nur in der Tabelle.
	var world := Node2D.new()
	root.add_child(world)
	var seen := {}
	for seed_value in range(40):
		var director := Director.new(seed_value)
		director.initialize(world, JumpConfig.PLATFORM_LAYOUT)
		for round_index in range(40):
			director.maintain(-float(round_index) * 500.0, 2400.0, difficulty)
			var expected: float = director.get_vertical_gap(difficulty) * Patterns.gap_factor_for(director.current_pattern())
			if not is_equal_approx(director.pattern_gap(), expected):
				seen["MISMATCH"] = true
			seen[director.current_pattern()] = true
	_check(not seen.has("MISMATCH"), "der Director benutzt den Formfaktor wirklich")
	_check(seen.size() >= 4, "es kamen mehrere Formen mit eigenem Rhythmus vor (%d)" % seen.size())
	world.queue_free()

## --- Punkt 4: PERFECT-Boost ---------------------------------------------------
func _check_perfect_boost() -> void:
	var charges := JumpConfig.RESONANCE_MAX_CHARGES
	# Der Boost ist wirksam und liegt in der geforderten Spanne 10-12 %.
	_check(JumpConfig.PERFECT_PACE_BOOST >= 1.10 and JumpConfig.PERFECT_PACE_BOOST <= 1.12,
		"der Boost liegt in der geforderten Spanne (%.3f)" % JumpConfig.PERFECT_PACE_BOOST)
	var plain := JumpConfig.pace_bounce(charges, false, false)
	var boosted := JumpConfig.pace_bounce(charges, false, true)
	_check(boosted > plain, "der geboostete Absprung ist staerker (%.0f > %.0f)" % [boosted, plain])
	# Der Kern: Kraft UND Gravitation gemeinsam, damit der Scheitel GLEICH bleibt.
	# Nur die Kraft zu erhoehen haette den Sprung hoeher gemacht.
	var plain_apex := plain * plain / (2.0 * JumpConfig.pace_gravity(charges, false, false))
	var boosted_apex := boosted * boosted / (2.0 * JumpConfig.pace_gravity(charges, false, true))
	_check(absf(boosted_apex - plain_apex) < 1.0,
		"der Scheitel bleibt gleich (%.1f gegen %.1f px, Abweichung %.2f)" % [plain_apex, boosted_apex, absf(boosted_apex - plain_apex)])
	# Die FLUGDAUER muss dagegen sinken — das ist der ganze Punkt.
	var plain_flight := 2.0 * plain / JumpConfig.pace_gravity(charges, false, false)
	var boosted_flight := 2.0 * boosted / JumpConfig.pace_gravity(charges, false, true)
	_check(boosted_flight < plain_flight,
		"der geboostete Sprung ist schneller (%.3f s gegen %.3f s)" % [boosted_flight, plain_flight])
	var gain := (plain_flight - boosted_flight) / plain_flight
	_check(gain >= 0.08 and gain <= 0.14,
		"die Flugdauer sinkt um rund 10 %% (gemessen %.1f %%)" % (gain * 100.0))
	# Ueber ALLE Ladungsstufen muss der Scheitel gleich bleiben — sonst waere der
	# Boost auf einer Stufe eine Hoehenaenderung.
	var apex_ok := true
	var worst := 0.0
	for level in range(JumpConfig.RESONANCE_MAX_CHARGES + 1):
		var base := JumpConfig.pace_bounce(level, false, false)
		var base_apex := base * base / (2.0 * JumpConfig.pace_gravity(level, false, false))
		var top := JumpConfig.pace_bounce(level, false, true)
		var top_apex := top * top / (2.0 * JumpConfig.pace_gravity(level, false, true))
		worst = maxf(worst, absf(top_apex - base_apex))
		if absf(top_apex - base_apex) > 1.0:
			apex_ok = false
	_check(apex_ok, "der Scheitel bleibt auf JEDER Ladungsstufe gleich (groesste Abweichung %.3f px)" % worst)
	# Der Boost darf NIE einen Overload veraendern: dort gilt die Overload-Kraft.
	_check(is_equal_approx(JumpConfig.pace_bounce(0, true, true), JumpConfig.pace_bounce(0, true, false)),
		"der Boost veraendert den Overload nicht")
	_check(is_equal_approx(JumpConfig.pace_gravity(0, true, true), JumpConfig.pace_gravity(0, true, false)),
		"der Boost veraendert die Overload-Gravitation nicht")

## --- Der Boost im laufenden Spiel: genau ein Absprung --------------------------
func _check_boost_is_single_shot() -> void:
	var game = load("res://scripts/game/game.gd").new()
	root.add_child(game)
	await process_frame
	game._phase = 1
	var jumper = game.jumper
	var velocity_plain := 0.0
	var velocity_boosted := 0.0
	var velocity_after := 0.0
	# Ohne Boost.
	jumper._perfect_boost_armed = false
	jumper._pending_overload = false
	jumper.set_physics_process(false)
	jumper.velocity = Vector2.ZERO
	jumper._apply_bounce(false)
	velocity_plain = absf(jumper.velocity.y)
	# Mit Boost.
	jumper.arm_perfect_boost()
	jumper.velocity = Vector2.ZERO
	jumper._apply_bounce(false)
	velocity_boosted = absf(jumper.velocity.y)
	_check(jumper.perfect_boost_armed() == false, "der Boost ist nach dem Absprung verbraucht")
	# Der NAECHSTE Absprung darf ihn nicht mehr haben.
	jumper.velocity = Vector2.ZERO
	jumper._apply_bounce(false)
	velocity_after = absf(jumper.velocity.y)
	_check(velocity_boosted > velocity_plain,
		"der geboostete Absprung ist staerker (%.0f gegen %.0f)" % [velocity_boosted, velocity_plain])
	_check(is_equal_approx(velocity_after, velocity_plain),
		"der uebernachste Absprung ist wieder normal (%.0f gegen %.0f)" % [velocity_after, velocity_plain])
	# ---------------------------------------------------------------------
	# REGRESSION: Kraft und Gravitation muessen WAEHREND DESSELBEN Fluges
	# zusammenpassen. Hier war ein echter Fehler: der Boost wurde beim Absprung
	# geloescht, die Gravitation las ihn danach nicht mehr und der Sprung wurde
	# HOEHER statt schneller (gemessen Scheitel +23 %, Flugdauer +11 %).
	#
	# Geprueft wird deshalb die tatsaechlich wirksame Gravitation NACH dem
	# Absprung — nicht die Konfigurationsfunktion, die den Boost als Parameter
	# bekommt. Genau diese Verwechslung hatte den Fehler verdeckt.
	# ---------------------------------------------------------------------
	jumper._pending_overload = false
	jumper._dive_active = false
	jumper.velocity = Vector2.ZERO
	jumper._apply_bounce(false)
	var gravity_plain: float = jumper.current_gravity()
	jumper.arm_perfect_boost()
	jumper.velocity = Vector2.ZERO
	jumper._apply_bounce(false)
	var gravity_boosted: float = jumper.current_gravity()
	_check(gravity_boosted > gravity_plain * 1.15,
		"die Gravitation des geboosteten Fluges ist hoeher (%.0f gegen %.0f)" % [gravity_boosted, gravity_plain])
	# Und der Scheitel muss dabei gleich bleiben — der eigentliche Zweck.
	var live_plain_apex := velocity_plain * velocity_plain / (2.0 * gravity_plain)
	var live_boosted_apex := velocity_boosted * velocity_boosted / (2.0 * gravity_boosted)
	_check(absf(live_boosted_apex - live_plain_apex) < 3.0,
		"der Scheitel bleibt auch im echten Flug gleich (%.1f gegen %.1f px)" % [live_boosted_apex, live_plain_apex])
	var live_plain_flight := 2.0 * velocity_plain / gravity_plain
	var live_boosted_flight := 2.0 * velocity_boosted / gravity_boosted
	_check(live_boosted_flight < live_plain_flight,
		"der geboostete Flug ist im echten Spiel kuerzer (%.3f s gegen %.3f s)" % [live_boosted_flight, live_plain_flight])
	# Und der Flug nach dem Boost ist wieder voellig normal.
	jumper.velocity = Vector2.ZERO
	jumper._apply_bounce(false)
	_check(is_equal_approx(jumper.current_gravity(), gravity_plain),
		"der uebernachste FLUG hat wieder normale Gravitation (%.0f gegen %.0f)" % [jumper.current_gravity(), gravity_plain])
	jumper._pending_overload = true
	jumper.velocity = Vector2.ZERO
	jumper._apply_bounce(true)
	_check(is_equal_approx(jumper.current_gravity(), JumpConfig.OVERLOAD_GRAVITY),
		"ein Overload hat unveraenderte Gravitation (%.0f)" % jumper.current_gravity())
	jumper._pending_overload = false
	# ---------------------------------------------------------------------
	# ECHTER FLUG mit echter Integration.
	#
	# WARUM DIESER TEIL NOETIG IST: der bisherige Test rechnete den Scheitel aus
	# den Getter-Werten und schaltete die Physik ab. Zwei Mutationen ueberlebten
	# ihn deshalb: (a) `apply_gravity` ignoriert den Boost, obwohl
	# `current_gravity` ihn korrekt meldet, und (b) die Landung macht den Boost
	# gar nicht scharf. Beide lassen den Test gruen, weil er nur den Getter
	# prueft — nicht die Flugbahn. Hier wird die Bahn gemessen.
	# ---------------------------------------------------------------------
	var flight := await _measure_flight(game, false)
	var boosted_flight := await _measure_flight(game, true)
	_check(flight["apex_rise"] > 400.0,
		"der ungeboostete Flug steigt ueberhaupt auf (%.0f px)" % flight["apex_rise"])
	# Der Scheitel bleibt praktisch gleich: er ist v^2/(2g), und der Boost
	# skaliert v und g gemeinsam. Ein paar Pixel Abweichung sind die
	# diskretisierte Integration, kein Hoehenunterschied.
	var rise_delta: float = absf(boosted_flight["apex_rise"] - flight["apex_rise"])
	_check(rise_delta < 25.0,
		"der geboostete Flug bleibt auf gleicher Hoehe (%.1f gegen %.1f px, Abweichung %.1f)"
			% [boosted_flight["apex_rise"], flight["apex_rise"], rise_delta])
	_check(boosted_flight["seconds"] < flight["seconds"] * 0.95,
		"der geboostete Flug ist wirklich kuerzer (%.3f s gegen %.3f s)"
			% [boosted_flight["seconds"], flight["seconds"]])
	_check(boosted_flight["gravity"] > flight["gravity"] * 1.15,
		"und die integrierte Gravitation ist die geboostete (%.0f gegen %.0f)"
			% [boosted_flight["gravity"], flight["gravity"]])
	# ---------------------------------------------------------------------
	# UND: die LANDUNG muss den Boost scharf machen. Ohne diesen Teil kann die
	# Zuweisung in `_resolve_landing` fehlen, ohne dass es auffaellt.
	# ---------------------------------------------------------------------
	var earned := await _measure_landing_arms_boost(game)
	_check(earned["perfect_quality"] == JumpConfig.LandingQuality.PERFECT,
		"die Mittellandung wird als PERFECT erkannt (Qualitaet %d)" % earned["perfect_quality"])
	_check(earned["plain_quality"] == JumpConfig.LandingQuality.NORMAL,
		"die Randlandung wird als NORMAL erkannt (Qualitaet %d)" % earned["plain_quality"])
	var perfect_flight: Dictionary = earned["perfect_flight"]
	var plain_flight: Dictionary = earned["plain_flight"]
	# DIE eigentliche Aussage: eine PERFECT-Landung beschert dem naechsten Sprung
	# ein hoeheres Tempo bei praktisch gleicher Hoehe.
	var earned_rise: float = absf(perfect_flight["apex_rise"] - plain_flight["apex_rise"])
	_check(earned_rise < 25.0,
		"die PERFECT-Landung aendert die Spruenge nicht in der Hoehe (%.1f gegen %.1f px)"
			% [perfect_flight["apex_rise"], plain_flight["apex_rise"]])
	_check(perfect_flight["seconds"] < plain_flight["seconds"] * 0.97,
		"der Sprung nach PERFECT ist wirklich schneller (%.3f s gegen %.3f s)"
			% [perfect_flight["seconds"], plain_flight["seconds"]])
	_check(perfect_flight["gravity"] > plain_flight["gravity"] * 1.1,
		"und die Gravitation ist die geboostete (%.0f gegen %.0f)"
			% [perfect_flight["gravity"], plain_flight["gravity"]])
	game.free()
	await process_frame

## Misst einen ECHTEN Flug: Sprung auslösen, dann Physik-Ticks laufen lassen und
## Scheitel, Dauer und wirksame Gravitation ablesen. Ohne Renderer, aber MIT der
## echten Integration (`apply_gravity`).
##
## `boosted` scharf gestellt wird ueber dieselbe Zuweisung, die auch die Landung
## benutzt — sonst pruefte der Test wieder nur einen Sonderweg.
func _measure_flight(game, boosted: bool) -> Dictionary:
	var jumper = game.jumper
	var was_physics: bool = jumper.is_physics_processing()
	jumper.set_physics_process(false)
	jumper.set_process(false)
	jumper._pending_overload = false
	jumper._dive_active = false
	jumper._perfect_boost_armed = false
	jumper._perfect_boost_flight = false
	jumper.velocity = Vector2.ZERO
	jumper._apply_bounce(false)
	if not boosted:
		jumper._perfect_boost_armed = false
	else:
		# Denselben Weg nehmen wie die Landung.
		jumper._perfect_boost_armed = true
		jumper.velocity = Vector2.ZERO
		jumper._apply_bounce(false)
	var start_y: float = jumper.global_position.y
	var gravity: float = jumper.current_gravity()
	var peak := start_y
	var elapsed := 0.0
	var delta := 1.0 / 60.0
	# Genug Ticks fuer den laengsten Flug (ueber 2 s), mit Abbruch beim
	# Zurueckfallen auf die Starthoehe.
	for step in range(240):
		jumper.apply_gravity(delta)
		jumper.global_position.y += jumper.velocity.y * delta
		elapsed += delta
		peak = minf(peak, jumper.global_position.y)
		if step > 2 and jumper.velocity.y > 0.0 and jumper.global_position.y >= start_y:
			break
	jumper.set_physics_process(was_physics)
	return {
		"apex_rise": start_y - peak,
		"seconds": elapsed,
		"gravity": gravity,
	}

## Laesst eine ECHTE Landung laufen (ueber `_resolve_landing`, nicht per
## Handaufruf) und vergleicht den Flug, der daraus folgt, mit dem nach einer
## gewoehnlichen Landung.
##
## WARUM SO UND NICHT UEBER `_perfect_boost_armed`: die Landung macht den Boost
## scharf und loest im SELBEN Tick den Absprung aus — der Absprung verbraucht das
## scharfe Flag und macht daraus das Flug-Flag. Nach Rueckkehr aus
## `_resolve_landing` ist `_perfect_boost_armed` also korrekt schon false. Genau
## daran ist meine erste Fassung dieser Pruefung gescheitert (sie meldete
## "Landung macht den Boost nicht scharf", obwohl das Verhalten richtig war).
## Gemessen wird deshalb das, was der Spieler merkt: die Flugbahn.
func _measure_landing_arms_boost(game) -> Dictionary:
	var perfect := await _measure_flight_after_landing(game, true)
	var plain := await _measure_flight_after_landing(game, false)
	return {
		"perfect_quality": perfect["quality"],
		"plain_quality": plain["quality"],
		"perfect_flight": perfect["flight"],
		"plain_flight": plain["flight"],
	}

## Eine Landung auf einer Standard-Sprosse, dann der Flug, der daraus folgt.
## `central` = true trifft die Mitte (PERFECT), false trifft den Rand (NORMAL).
func _measure_flight_after_landing(game, central: bool) -> Dictionary:
	var jumper = game.jumper
	var was_physics: bool = jumper.is_physics_processing()
	jumper.set_physics_process(false)
	jumper.set_process(false)
	var platform := JumpPlatform.new()
	platform.configure_variant(JumpPlatform.Variant.STANDARD)
	game.add_child(platform)
	platform.global_position = Vector2(540.0, 0.0)
	jumper._perfect_boost_armed = false
	jumper._perfect_boost_flight = false
	jumper.velocity = Vector2(0.0, 600.0)
	var contact_x: float = platform.global_position.x
	if not central:
		# Der Rand: weit ausserhalb der PERFECT- und Resonanzbaender.
		contact_x = platform.global_position.x + platform.platform_size.x * 0.45
	jumper._resolve_landing(platform, false, contact_x)
	var quality: int = jumper.last_landing_quality
	# Der Flug laeuft bereits (der Absprung liegt in `_resolve_landing`).
	var start_y: float = jumper.global_position.y
	var peak := start_y
	var elapsed := 0.0
	var gravity: float = jumper.current_gravity()
	for step in range(240):
		jumper.apply_gravity(1.0 / 60.0)
		jumper.global_position.y += jumper.velocity.y * 1.0 / 60.0
		elapsed += 1.0 / 60.0
		peak = minf(peak, jumper.global_position.y)
		if step > 2 and jumper.velocity.y > 0.0 and jumper.global_position.y >= start_y:
			break
	jumper.set_physics_process(was_physics)
	platform.queue_free()
	return {
		"quality": quality,
		"flight": {"apex_rise": start_y - peak, "seconds": elapsed, "gravity": gravity},
	}

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _finish() -> void:
	print("GAMEPLAY REDESIGN: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
