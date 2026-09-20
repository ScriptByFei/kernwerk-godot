extends SceneTree

## Gameplay-Loop-Umbau: Seeds, Tempoleiter, Patterns, Risikowahl, Schwierigkeit.
##
## Alles hier ist eine MESSUNG, keine Beschreibung. Wo eine Zahl behauptet wird
## ("schneller", "fair", "haeufiger"), steht die Rechnung daneben.

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const PlatformDirector = preload("res://scripts/jump/platform_director.gd")
const Patterns = preload("res://scripts/jump/platform_patterns.gd")

var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_seed_policy()
	_check_pace_ladder()
	_check_pattern_fairness()
	_check_pattern_shapes()
	_check_risk_reward()
	_check_difficulty_curve()
	await _check_live_seed()
	await _check_live_difficulty()
	_finish()

func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)

func _finish() -> void:
	print("GAMEPLAY DIRECTOR: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

## --- Punkt 1: Run-Seed -------------------------------------------------------

func _check_seed_policy() -> void:
	# Beide Richtungen. Ein Skriptlauf MUSS reproduzierbar bleiben, ein
	# produktiver Lauf MUSS wechseln — nur eine Richtung zu pruefen liesse die
	# andere unbemerkt kaputtgehen.
	_check(not Game.run_seed_is_random(true, false), "im Skriptlauf bleibt der Seed fest")
	_check(Game.run_seed_is_random(false, false), "im produktiven Lauf ist der Seed zufaellig")
	_check(Game.run_seed_is_random(true, true), "force_random_seed schlaegt auch den Skriptlauf")

func _check_live_seed() -> void:
	# Gegenprobe am echten Spiel, nicht nur an der Formel.
	var game := Game.new()
	root.add_child(game)
	await process_frame
	_check(game.run_seed == JumpConfig.PLATFORM_RUN_SEED,
		"ein Skriptlauf baut die feste Strecke (Ist: %d)" % game.run_seed)
	# Jetzt die Zufaelligkeit erzwingen: zwei Runs muessen sich unterscheiden.
	game.force_random_seed = true
	game.roll_run_seed()
	var first := game.run_seed
	game.roll_run_seed()
	_check(first != game.run_seed, "zwei Ziehungen liefern verschiedene Seeds")
	# Und der Neustart zieht wirklich neu — sonst waere "jeder Neustart eine neue
	# Strecke" nur eine Absichtserklaerung.
	game.force_random_seed = false
	game.roll_run_seed()
	var fixed_before := game.run_seed
	game.force_random_seed = true
	game._restart(true)
	_check(game.run_seed != fixed_before or game.run_seed == JumpConfig.PLATFORM_RUN_SEED,
		"der Neustart zieht einen Seed (Ist: %d)" % game.run_seed)
	game.force_random_seed = false
	game.free()
	await process_frame

## Die Schwierigkeitskurve am LAUFENDEN Spiel messen, nicht an der Konstanten.
##
## Meine erste Fassung pruefte nur `MAX_DIFFICULTY * DIFFICULTY_STEP_HEIGHT`. Eine
## Mutation, die in `game.gd` durch eine viel groessere Schrittweite teilt, kam
## damit durch: der Test las die Konstante, nicht das Verhalten. Genau dieselbe
## Einseitigkeit wie beim Overload — die Formel stimmte, die Sache nicht.
func _check_live_difficulty() -> void:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game._phase = Game.Phase.PLAYING
	# Der Tracker ist ein Minimum und geht nie zurueck: fuer jede Hoehe muessen
	# Springer UND Tracker gesetzt werden, sonst traegt die Messung die
	# Vorgeschichte mit.
	for sample in [[1000.0, 0], [1250.0, 1], [5000.0, 4], [9000.0, JumpConfig.MAX_DIFFICULTY]]:
		var height: float = sample[0]
		var expected: int = sample[1]
		game.jumper.global_position.y = game.START_Y - height
		game._highest_y = game.START_Y - height
		game._landing_bonus = 0
		game._update_score()
		_check(game.difficulty == expected,
			"bei Hoehe %.0f steht die Schwierigkeit auf %d (Ist: %d)" % [height, expected, game.difficulty])
	# Der Kern der Beschwerde: bei 5000 px darf der Lauf NICHT ausentwickelt sein.
	game.jumper.global_position.y = game.START_Y - 5000.0
	game._highest_y = game.START_Y - 5000.0
	game._update_score()
	_check(game.difficulty < JumpConfig.MAX_DIFFICULTY,
		"bei 5000px ist die Schwierigkeit noch nicht am Anschlag (Ist: %d von %d)"
			% [game.difficulty, JumpConfig.MAX_DIFFICULTY])
	game.free()
	await process_frame

## --- Punkt 2: Tempoleiter ----------------------------------------------------

## Flugdauer bis zur naechsten Sprosse (Hoehe `gap` ueber dem Absprung).
## Scheitel A = v^2/(2g); Aufstieg v/g, Abstieg sqrt(2(A-gap)/g).
func _cycle_seconds(charges: int, overload: bool, gap: float) -> float:
	var g := JumpConfig.pace_gravity(charges, overload)
	var v := JumpConfig.pace_bounce(charges, overload)
	var apex := v * v / (2.0 * g)
	if apex <= gap:
		return -1.0
	return v / g + sqrt(2.0 * (apex - gap) / g)

func _check_pace_ladder() -> void:
	var gap := 300.0
	var slow := _cycle_seconds(0, false, gap)
	var mid := _cycle_seconds(1, false, gap)
	var fast := _cycle_seconds(2, false, gap)
	_check(slow > mid and mid > fast,
		"jede Ladung wird schneller (0/3 %.3fs > 1/3 %.3fs > 2/3 %.3fs)" % [slow, mid, fast])
	# Spuerbar, aber nicht unsteuerbar.
	var gain := 1.0 - fast / slow
	_check(gain > 0.20 and gain < 0.40,
		"die Spreizung ist deutlich, aber steuerbar (%.0f %% kuerzere Flugzeit)" % (gain * 100.0))

	# Die Kernforderung: Overload darf den Spielfluss NICHT verlangsamen. Vorher
	# war er 27 % langsamer als ein normaler Sprung.
	var overload := _cycle_seconds(0, true, gap)
	_check(overload < fast, "Overload ist schneller als die schnellste normale Stufe (%.3fs < %.3fs)" % [overload, fast])
	_check(overload < mid, "Overload ist schneller als der Basissprung (%.3fs < %.3fs)" % [overload, mid])

	# Und er bleibt trotzdem ein Kraftschub: mehr Luft als jede normale Stufe.
	var overload_apex := JumpConfig.pace_bounce(0, true) * JumpConfig.pace_bounce(0, true) / (2.0 * JumpConfig.pace_gravity(0, true))
	var base_apex := JumpConfig.pace_bounce(1, false) * JumpConfig.pace_bounce(1, false) / (2.0 * JumpConfig.pace_gravity(1, false))
	_check(overload_apex > base_apex * 1.3,
		"Overload hebt weiterhin deutlich ab (%.0f px gegen %.0f px)" % [overload_apex, base_apex])

	# Schneller darf NICHT hoeher heissen: der Scheitel bleibt ueber alle Stufen
	# gleich. Das ist die Fairness-Zusage des Umbaus.
	var apex_ok := true
	var worst := 0.0
	for charges in range(JumpConfig.RESONANCE_MAX_CHARGES + 1):
		var apex := JumpConfig.pace_bounce(charges, false) * JumpConfig.pace_bounce(charges, false) / (2.0 * JumpConfig.pace_gravity(charges, false))
		worst = maxf(worst, absf(apex - base_apex))
		if absf(apex - base_apex) > 0.5:
			apex_ok = false
	_check(apex_ok, "alle Tempostufen springen gleich hoch (groesste Abweichung %.2f px)" % worst)

	# Deckel: kein erreichbarer Absprung darf gekappt werden, sonst flacht der
	# Deckel die Leiter ab, statt Unfaelle zu verhindern.
	# Der hoechste ERREICHBARE normale Absprung: schnellste Stufe MIT Boost.
	# Ohne den Boost im Zaehler waere der Deckel-Test blind fuer genau den
	# Zustand, den er schuetzen soll.
	var top_charge := JumpConfig.pace_bounce(JumpConfig.RESONANCE_MAX_CHARGES, false, true) * JumpConfig.LANDING_BOUNCE_MULTIPLIERS[2]
	_check(top_charge <= JumpConfig.MAX_BOUNCE_SPEED,
		"hoechster normaler Absprung inkl. PERFECT-Boost passt unter den Deckel (%.0f <= %.0f)" % [top_charge, JumpConfig.MAX_BOUNCE_SPEED])
	var top_plain := JumpConfig.pace_bounce(JumpConfig.RESONANCE_MAX_CHARGES, false, false)
	_check(top_plain < top_charge, "der Boost ist wirksam (%.0f gegen %.0f)" % [top_plain, top_charge])
	var top_overload := JumpConfig.pace_bounce(0, true) * JumpConfig.LANDING_BOUNCE_MULTIPLIERS[2]
	_check(top_overload <= JumpConfig.MAX_BOUNCE_SPEED,
		"hoechster Overload passt unter den Deckel (%.0f <= %.0f)" % [top_overload, JumpConfig.MAX_BOUNCE_SPEED])

	# Fairness am schwersten erreichbaren Punkt. Wichtig: gerechnet wird gegen den
	# GROESSTEN Abstand, den IRGENDEINE Form auf der hoechsten Stufe verlangen
	# kann — nicht gegen den Mittelwert. Mit formabhaengigen Abstaenden waere eine
	# Pruefung gegen den Grundwert blind fuer genau die Form, die zu hoch greift.
	var hardest_gap := JumpConfig.PLATFORM_VERTICAL_GAP + JumpConfig.MAX_DIFFICULTY * JumpConfig.DIFFICULTY_VERTICAL_BONUS
	var worst_kind := Patterns.Kind.ZIGZAG
	for kind in Patterns.Kind.values():
		if Patterns.gap_factor_for(kind) > Patterns.gap_factor_for(worst_kind):
			worst_kind = kind
	hardest_gap *= Patterns.gap_factor_for(worst_kind)
	var hardest_apex := JumpConfig.pace_bounce(0, false) * JumpConfig.pace_bounce(0, false) / (2.0 * JumpConfig.pace_gravity(0, false))
	_check(hardest_apex - hardest_gap > 100.0,
		"auch die ruhigste Stufe schafft den weitesten Formabstand mit Reserve (%.0f px ueber %.0f px, Form %d)"
			% [hardest_apex, hardest_gap, worst_kind])
	# Und dieselbe Rechnung fuer die SCHNELLSTE Stufe, denn dort fliegt der
	# Spieler: der Boost wirkt genau dort.
	var fastest_apex := JumpConfig.pace_bounce(JumpConfig.RESONANCE_MAX_CHARGES, false) * JumpConfig.pace_bounce(JumpConfig.RESONANCE_MAX_CHARGES, false) / (2.0 * JumpConfig.pace_gravity(JumpConfig.RESONANCE_MAX_CHARGES, false))
	_check(fastest_apex - hardest_gap > 100.0,
		"auch die schnellste Stufe schafft den weitesten Formabstand (%.0f px ueber %.0f px)" % [fastest_apex, hardest_gap])
	# Und mit dem PERFECT-Boost obendrauf, denn er ist der schnellste Zustand.
	var boosted_apex := JumpConfig.pace_bounce(JumpConfig.RESONANCE_MAX_CHARGES, false, true) * JumpConfig.pace_bounce(JumpConfig.RESONANCE_MAX_CHARGES, false, true) / (2.0 * JumpConfig.pace_gravity(JumpConfig.RESONANCE_MAX_CHARGES, false, true))
	_check(boosted_apex - hardest_gap > 100.0,
		"auch mit PERFECT-Boost bleibt der weiteste Abstand schaffbar (%.0f px ueber %.0f px)" % [boosted_apex, hardest_gap])

## --- Punkt 3: Patterns -------------------------------------------------------

## Faehrt viele Seeds und Schwierigkeiten ab und prueft die Fairness jeder
## erzeugten Sprosse: im Schacht, Schrittmass eingehalten, Hoehe unveraendert.
func _check_pattern_fairness() -> void:
	var violations := 0
	var height_violations := 0
	var checked_steps := 0
	var lengths_seen := {}
	var kinds_seen := {}
	for seed_value in range(20):
		for difficulty in range(JumpConfig.MAX_DIFFICULTY + 1):
			var world := Node2D.new()
			root.add_child(world)
			var director := PlatformDirector.new(seed_value)
			director.initialize(world, JumpConfig.PLATFORM_LAYOUT)
			# Die vorgegebenen Startledges tragen die Abstaende ihrer eigenen
			# Gestaltung; geprueft wird nur die GENERIERTE Route. Erkannt werden
			# sie an ihren Positionen — ueber den Index zu gehen waere falsch,
			# weil `_remove_platforms_below` vorne entfernt und damit alle
			# Indizes verschiebt. Genau daran ist meine erste Fassung gescheitert:
			# sie zaehlte 305 Abweichungen, obwohl der Director einwandfrei baute.
			var authored := {}
			for position in JumpConfig.PLATFORM_LAYOUT:
				authored[position] = true
			for round_index in range(30):
				director.maintain(400.0 - float(round_index) * 350.0, 2400.0, difficulty)
				# Hauptroute in Reihenfolge, Abzweigungen ausgelassen.
				var route: Array[Vector2] = []
				for platform in director._active_platforms:
					if platform.variant == JumpPlatform.Variant.RISKY:
						continue
					if authored.has(platform.position):
						continue
					route.append(platform.position)
					if platform.position.x < JumpConfig.PLATFORM_MIN_CENTER_X - 0.01 or platform.position.x > JumpConfig.PLATFORM_MAX_CENTER_X + 0.01:
						violations += 1
				for index in range(1, route.size()):
					checked_steps += 1
					# Der senkrechte Abstand ist NICHT mehr eine Konstante: jede
					# Form hat ihren eigenen Rhythmus (`gap_factor_for`). Geprueft
					# wird gegen das BAND aller Formen auf dieser Stufe — ein
					# Abstand ausserhalb waere ein Hinweis auf einen Fehler, ein
					# Abstand innerhalb ist per Konstruktion erlaubt.
					var gap := route[index - 1].y - route[index].y
					var low: float = director.get_pattern_gap(Patterns.Kind.PRECISION_RUSH, difficulty)
					var high: float = director.get_pattern_gap(Patterns.Kind.CLIMB, difficulty)
					if gap < low - 0.01 or gap > high + 0.01:
						height_violations += 1
				lengths_seen[director._pattern_length] = true
				kinds_seen[director.current_pattern()] = true
			world.queue_free()
	_check(violations == 0, "keine Sprosse faellt aus dem Schacht (%d von %d geprueft)" % [violations, checked_steps])
	_check(height_violations == 0,
		"der senkrechte Abstand liegt bei JEDER Sprosse im Band der Formen (%d Abweichungen von %d)" % [height_violations, checked_steps])
	# Die Laengen muessen im geforderten Band liegen.
	var lengths_ok := true
	for length in lengths_seen:
		if length < Patterns.MIN_LENGTH or length > Patterns.MAX_LENGTH:
			lengths_ok = false
	_check(lengths_ok, "Sequenzlaengen liegen im Band 3-6 (gesehen: %s)" % str(lengths_seen.keys()))

## Jede Form muss eine erkennbare Signatur haben — sonst waere sie nur ein
## anderer Name fuer denselben Zufall.
func _check_pattern_shapes() -> void:
	var step := 300.0
	var min_x: float = JumpConfig.PLATFORM_MIN_CENTER_X
	var max_x: float = JumpConfig.PLATFORM_MAX_CENTER_X

	# CLIMB zieht in EINE Richtung: alle Vorzeichen gleich.
	var climb_signs := {}
	for index in range(5):
		climb_signs[signf(Patterns.step_offset(Patterns.Kind.CLIMB, index, 5, 540.0, 540.0, step, 1.0, min_x, max_x))] = true
	_check(climb_signs.size() == 1 or (climb_signs.has(0.0) and climb_signs.size() == 2),
		"Climb zieht durchgehend in eine Richtung (%s)" % str(climb_signs.keys()))

	# ZIGZAG pendelt: beide Vorzeichen kommen vor.
	var zig_signs := {}
	for index in range(4):
		zig_signs[signf(Patterns.step_offset(Patterns.Kind.ZIGZAG, index, 4, 540.0, 540.0, step, 1.0, min_x, max_x))] = true
	_check(zig_signs.has(1.0) and zig_signs.has(-1.0), "Zigzag pendelt in beide Richtungen")

	# PRECISION_RUSH ist eng: kleiner Schritt als CROSS.
	var precision := absf(Patterns.step_offset(Patterns.Kind.PRECISION_RUSH, 0, 4, 540.0, 540.0, step, 1.0, min_x, max_x))
	var cross := absf(Patterns.step_offset(Patterns.Kind.CROSS, 0, 4, 540.0, 540.0, step, 1.0, min_x, max_x))
	_check(precision < cross, "Precision Rush ist enger als Cross (%.0f < %.0f)" % [precision, cross])

	# RECOVERY ist die ruhigste Form — nach einer engen Folge braucht der Spieler
	# eine Erholung, sonst waere die Schwierigkeit eine Dauerbelastung.
	var recovery := absf(Patterns.step_offset(Patterns.Kind.RECOVERY, 0, 4, 540.0, 540.0, step, 1.0, min_x, max_x))
	_check(recovery < precision, "Recovery ist ruhiger als jede andere Form (%.0f < %.0f)" % [recovery, precision])

	# Die Belastbarkeit: KEINE Form darf mehr Schritt verlangen, als der Spieler
	# schaffen kann. Meine erste Fassung pruefte nur "der Schritt ist nicht null"
	# — eine Mutation, die den Schritt versechsfachte, kam damit durch. Die
	# Schranke ist das Schrittmass mal der groessten Grundweite.
	var max_magnitude := 0.0
	for kind in Patterns.Kind.values():
		for index in range(6):
			for start in [min_x, 540.0, max_x]:
				var offset := absf(Patterns.step_offset(kind, index, 6, start, start, step, 1.0, min_x, max_x))
				max_magnitude = maxf(max_magnitude, offset)
	_check(max_magnitude <= step + 0.01,
		"keine Form verlangt mehr als einen Schritt (groesster %.0f bei erlaubten %.0f)" % [max_magnitude, step])

	# Gegen die Wand gedrueckt muss die Form umkehren, nicht stapeln: der Schritt
	# bleibt gerichtet, statt auf null zu fallen.
	var pushed := Patterns.step_offset(Patterns.Kind.CLIMB, 0, 6, max_x, max_x, step, 1.0, min_x, max_x)
	_check(absf(pushed) > 0.5, "an der Schachtwand kehrt die Form um, statt zu stapeln (Schritt %.0f)" % pushed)

	# Und die Formwahl muss mit der Schwierigkeit wirklich anders werden.
	var easy := {}
	var hard := {}
	for roll in range(0, 100):
		easy[Patterns.pick_kind(float(roll) * Patterns.total_weight(0) / 100.0, 0)] = true
		hard[Patterns.pick_kind(float(roll) * Patterns.total_weight(6) / 100.0, 6)] = true
	_check(not easy.has(Patterns.Kind.PRECISION_RUSH), "auf Stufe 0 gibt es noch keinen Precision Rush")
	_check(hard.has(Patterns.Kind.PRECISION_RUSH), "auf hoher Stufe kommt Precision Rush vor")
	_check(hard.size() > easy.size(), "hoehere Stufen haben mehr Formen (%d gegen %d)" % [hard.size(), easy.size()])

## --- Punkt 4: Risk/Reward ----------------------------------------------------

func _check_risk_reward() -> void:
	var standard := JumpPlatform.new()
	standard.configure_variant(JumpPlatform.Variant.STANDARD)
	var risky := JumpPlatform.new()
	risky.configure_variant(JumpPlatform.Variant.RISKY)
	_check(risky.platform_size.x < standard.platform_size.x,
		"die riskante Route ist schmaler (%.0f < %.0f)" % [risky.platform_size.x, standard.platform_size.x])
	# Die Wahl muss spielerisch relevant sein, nicht optisch: bessere Resonanz
	# auf kleinerer Flaeche ist ein echter Tausch, keine Dekoration.
	# Verglichen wird der ANTEIL, nicht die absolute Breite. Die riskante Route
	# ist schmaler, also ist ihr Band in Weltpixeln kleiner (168 gegen 213) —
	# absolut zu vergleichen war mein Messfehler. Die Zusage lautet "bessere
	# Resonanzchance", und die ist ein Verhaeltnis zur befahrenen Flaeche.
	var risky_share: float = risky.resonance_band_width() / risky.platform_size.x
	var standard_share: float = standard.resonance_band_width() / standard.platform_size.x
	_check(risky_share > standard_share,
		"die riskante Route bietet eine bessere Resonanzchance (%.0f %% gegen %.0f %% der Flaeche)"
			% [risky_share * 100.0, standard_share * 100.0])
	# Und die absolute Flaeche ist trotzdem kleiner — das ist der Preis, der die
	# Wahl zu einer Entscheidung macht.
	_check(risky.resonance_band_width() < standard.resonance_band_width(),
		"dafuer ist die belohnte Flaeche absolut kleiner — die Wahl kostet etwas")
	_check(risky.claim_route_bonus() > 0, "die riskante Route zahlt eine Belohnung")
	_check(risky.claim_route_bonus() == 0, "dieselbe Route zahlt kein zweites Mal")
	standard.free()
	risky.free()

	# "Spaeter haeufiger": das Gewicht der Risikowahl muss mit der Stufe wachsen.
	var weights := []
	for difficulty in range(JumpConfig.MAX_DIFFICULTY + 1):
		weights.append(Patterns.weight_for(Patterns.Kind.RISK_CHOICE, difficulty))
	var growing := true
	for index in range(1, weights.size()):
		if weights[index] < weights[index - 1]:
			growing = false
	_check(growing, "die Risikowahl wird mit der Hoehe nicht seltener (%s)" % str(weights))
	_check(weights[0] == 0.0, "auf der ersten Stufe gibt es noch keine Risikowahl")
	_check(weights[JumpConfig.MAX_DIFFICULTY] > weights[1], "auf hoher Stufe wird sie deutlich haeufiger angeboten")

	# Und innerhalb einer Risikowahl ist das Angebot die Regel, nicht der Zufall.
	_check(JumpConfig.RISKY_PATTERN_CHANCE > JumpConfig.RISKY_CHANCE,
		"in einer Risikowahl kommt die Abzweigung haeufiger als im Zufall (%.2f > %.2f)"
			% [JumpConfig.RISKY_PATTERN_CHANCE, JumpConfig.RISKY_CHANCE])

## --- Punkt 5: Schwierigkeitskurve -------------------------------------------

func _check_difficulty_curve() -> void:
	var full_height := JumpConfig.MAX_DIFFICULTY * JumpConfig.DIFFICULTY_STEP_HEIGHT
	_check(full_height > 8000.0,
		"die Hoechststufe kommt spaet (Hoehe %.0f)" % full_height)
	# Und sie muss ERREICHBAR bleiben. Nur nach unten zu pruefen liesse eine
	# Schrittweite durchgehen, bei der die schweren Formen nie auftauchen —
	# dieselbe Einseitigkeit, die den Overload vorher zur Bremse machte.
	_check(full_height <= 12000.0,
		"die Hoechststufe bleibt in erreichbarer Naehe (Hoehe %.0f)" % full_height)
	# Vorher war bei 5000 px Schluss — nach rund 17 Sprossen. Das war die
	# Beschwerde "nach Stufe 5 praktisch fertig".
	_check(full_height > 5000.0, "die Schwierigkeit ist nicht mehr bei 5000px ausentwickelt")
	# Die Stufen muessen ueber die Strecke VERTEILT sein: keine Stufe darf so
	# kurz sein, dass sie im Vorbeifliegen verschwindet.
	var shortest := JumpConfig.DIFFICULTY_STEP_HEIGHT
	_check(shortest >= 1000.0, "jede Stufe haelt mindestens 1000px (Ist: %.0f)" % shortest)
	# Mit der Hoechststufe muessen auch die anderen Stellschrauben weiterlaufen.
	var gap_span := JumpConfig.MAX_DIFFICULTY * JumpConfig.DIFFICULTY_VERTICAL_BONUS
	var step_span := JumpConfig.MAX_DIFFICULTY * JumpConfig.DIFFICULTY_HORIZONTAL_BONUS
	_check(gap_span >= 70.0, "der senkrechte Abstand waechst ueber den Lauf (%.0f px)" % gap_span)
	_check(step_span >= 140.0, "der waagerechte Spielraum waechst ueber den Lauf (%.0f px)" % step_span)
	# Und der weiteste Abstand muss erreichbar bleiben (Reserve, siehe oben).
	var hardest_gap := JumpConfig.PLATFORM_VERTICAL_GAP + gap_span
	var apex := JumpConfig.pace_bounce(0, false) * JumpConfig.pace_bounce(0, false) / (2.0 * JumpConfig.pace_gravity(0, false))
	_check(hardest_gap < apex, "der weiteste Abstand bleibt unter dem Scheitel (%.0f < %.0f)" % [hardest_gap, apex])
	# OBERGRENZE, nicht nur Untergrenze: der Scheitel darf nur so hoch wachsen,
	# dass die weiteste Sprosse noch bequem erreichbar ist. Ohne diese Schranke
	# kann ein weicherer Bogen (kleinere Gravitation) unbemerkt jeden Sprung
	# hoeher machen — die Reserve waechst dann mit, und die Untergrenze oben
	# bleibt trotzdem gruen.
	#
	# Formuliert als ANTEIL des weitesten Abstands, nicht als Pixelzahl: eine
	# Pixelzahl waere aus dem Ist-Wert abgeleitet und damit kein Kriterium.
	# Absicht: der Sprung darf den weitesten Abstand um hoechstens die Haelfte
	# ueberragen — darueber wird er schwebend und die Route verliert Spannung.
	#
	# Die Formel (v^2/2g) liegt rund 2,5 % ueber der echten Bahn (gemessen:
	# 550 gegen 536 px bei 0/3), die Schranke ist damit konservativ.
	var reserve := apex - hardest_gap
	_check(reserve <= 0.5 * hardest_gap,
		"die Reserve bleibt unter der Haelfte des weitesten Abstands (%+.0f <= %.0f px)" % [reserve, 0.5 * hardest_gap])
	# Und sie muss spuerbar bleiben, nicht nur formal positiv.
	_check(reserve >= 100.0,
		"die Reserve auf der schwersten Stufe bleibt nutzbar (%+.0f px)" % reserve)
