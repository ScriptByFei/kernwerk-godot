extends SceneTree

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const ResonanceSystem = preload("res://scripts/jump/resonance_system.gd")

var failures := 0

func _init() -> void:
	_test_charge_rules()
	_test_score_curve()
	_test_bounce_bonus_curve()
	await _test_overload_cycle()
	await _test_normal_landing_resets()
	await _test_overload_survives_wrong_sequence()
	await _test_hud_geometry()
	_test_perfect_band_size()
	await _test_restart_resets()
	print("RESONANZ-KETTE: ALLE OK" if failures == 0 else "RESONANZ-KETTE: %d FEHLER" % failures)
	quit(1 if failures > 0 else 0)

## Reine Zustandsregeln des ResonanceSystem, ohne Szene.
func _test_charge_rules() -> void:
	var r := ResonanceSystem.new()
	_check(r.max_charges() == 3, "maximal drei Ladungen")
	_check(r.charges == 0, "startet ohne Ladung")

	_check(r.register_landing(JumpConfig.LandingQuality.RESONANCE) == false, "erste RESONANCE laedt, ohne Overload")
	_check(r.charges == 1, "RESONANCE gibt genau +1 Ladung")

	_check(r.register_landing(JumpConfig.LandingQuality.PERFECT) == false, "PERFECT laedt ebenfalls, ohne Overload")
	_check(r.charges == 2, "PERFECT gibt genau +1 Ladung")

	# Dritte Ladung: Overload scharf, wird aber erst vom naechsten Absprung
	# verbraucht — register_landing meldet das dem Aufrufer.
	_check(r.register_landing(JumpConfig.LandingQuality.PERFECT) == true, "die dritte Landung loest OVERLOAD aus")
	_check(r.charges == 0, "nach dem Overload steht die Resonanz wieder auf 0")
	_check(r.overload_count == 1, "der Overload wird gezaehlt")
	_check(r.best_charges == 3, "der Bestwert haelt die volle Ladung fest")

	# Ueberladen ist nicht stapelbar: weiter laden beginnt wieder bei 1.
	_check(r.register_landing(JumpConfig.LandingQuality.PERFECT) == false, "nach dem Entladen laedt es wieder normal")
	_check(r.charges == 1, "die Ladung startet nach dem Overload bei 1")

## Punkte folgen der gehaltenen Ladung, nicht der Landungsart.
func _test_score_curve() -> void:
	for charge in range(JumpConfig.RESONANCE_MAX_CHARGES + 1):
		_check(
			ResonanceSystem.score_for_charge(charge) == JumpConfig.RESONANCE_SCORE_BY_CHARGE[charge],
			"Ladung %d zahlt den konfigurierten Score" % charge
		)
	_check(ResonanceSystem.score_for_charge(0) == 0, "eine Ladung von 0 zahlt nichts")
	_check(ResonanceSystem.score_for_charge(9) == JumpConfig.RESONANCE_SCORE_BY_CHARGE[JumpConfig.RESONANCE_MAX_CHARGES], "zu hohe Ladung wird gedeckelt")

func _test_bounce_bonus_curve() -> void:
	_check(is_equal_approx(JumpConfig.resonance_bounce_bonus(0), 0.0), "ohne Ladung kein Kraftaufschlag")
	_check(JumpConfig.resonance_bounce_bonus(3) > JumpConfig.resonance_bounce_bonus(1), "mehr Ladung gibt mehr Kraft")
	_check(JumpConfig.resonance_bounce_bonus(99) == JumpConfig.resonance_bounce_bonus(JumpConfig.RESONANCE_MAX_CHARGES), "der Aufschlag ist gedeckelt")

## Voller Zyklus am echten Spiel — ueber den ECHTEN Landepfad
## (_resolve_landing), nicht durch direkten Callback-Aufruf. Damit ist auch die
## Verdrahtung jumper.overload_check -> ResonanceSystem mitgeprueft.
func _test_overload_cycle() -> void:
	var game := Game.new()
	get_root().add_child(game)
	await process_frame
	# Landungen laufen im Test ueber den direkten Pfad; der Spielzustand muss
	# dafuer auf PLAYING stehen, sonst ignoriert der Callback die Landung.
	game._phase = Game.Phase.PLAYING
	game.jumper.set_physics_process(false)

	var platform := JumpPlatform.new()
	get_root().add_child(platform)
	platform.global_position = Vector2(540.0, 900.0)

	var perfect := JumpConfig.LandingQuality.PERFECT
	# Zwei Zentrumslandungen ueber den Produktionspfad.
	_land(game.jumper, platform, 0.0)
	_check(game.resonance.charges == 1, "die erste PERFECT-Landung laedt ueber den echten Pfad")
	_land(game.jumper, platform, 0.0)
	_check(game.resonance.charges == 2, "die zweite PERFECT-Landung laedt weiter")
	_check(is_equal_approx(game.jumper._resonance_ratio, 2.0 / 3.0), "das Feedback folgt dem Ladungsstand")
	var before_overload := game.resonance.overload_count

	# Der dritte Absprung MUSS ueberladen sein und die Kraft sofort tragen.
	_land(game.jumper, platform, 0.0)
	_check(game.resonance.overload_count == before_overload + 1, "die dritte Landung loest den Overload aus")
	_check(game.resonance.charges == 0, "der Overload entlaedt die Resonanz")
	_check(game._overload_display > 0.0, "die OVERLOAD-Anzeige wird gehalten")
	var overload_speed := absf(game.jumper.velocity.y)
	_check(overload_speed > JumpConfig.BASE_BOUNCE_SPEED, "der ueberladene Absprung ist staerker als der Basisabsprung (%d)" % int(overload_speed))
	_check(overload_speed <= JumpConfig.MAX_BOUNCE_SPEED + 0.001, "der Overload hebt den Absprungdeckel nicht an")

	# Eine weitere Zentrumslandung startet wieder bei genau einer Ladung.
	_land(game.jumper, platform, 0.0)
	_check(game.resonance.charges == 1, "nach dem Overload startet die Ladung wieder bei 1")

	platform.queue_free()
	game.queue_free()
	await process_frame

## Landung durch den Produktionspfad: klassifiziert, verbucht, springt ab.
func _land(jumper: Jumper, platform: JumpPlatform, offset_x: float) -> void:
	jumper.velocity.y = 600.0
	jumper._resolve_landing(platform, false, platform.global_position.x + offset_x)

## Requirement 7: eine NORMAL-Landung loescht die Kette vollstaendig.
func _test_normal_landing_resets() -> void:
	var game := Game.new()
	get_root().add_child(game)
	await process_frame
	game._phase = Game.Phase.PLAYING
	game.jumper.set_physics_process(false)

	game._on_overload_check(JumpConfig.LandingQuality.RESONANCE)
	game._on_overload_check(JumpConfig.LandingQuality.PERFECT)
	_check(game.resonance.charges == 2, "zwei gute Landungen laden die Resonanz")

	_check(game._on_overload_check(JumpConfig.LandingQuality.NORMAL) == false, "eine normale Landung loest keinen Overload aus")
	_check(game.resonance.charges == 0, "eine normale Landung setzt die Resonanz auf 0")
	_check(is_equal_approx(game.jumper._resonance_ratio, 0.0), "das Feedback faellt bei Kettenbruch auf null")
	_check(game.resonance.best_charges == 2, "der Bestwert der Runde bleibt erhalten")

	# RESONANCE laedt danach wieder ganz normal, ohne Altlast.
	game._on_overload_check(JumpConfig.LandingQuality.RESONANCE)
	_check(game.resonance.charges == 1, "nach dem Reset laedt eine RESONANCE wieder bei 1")

	game.queue_free()
	await process_frame

## Auch eine unerwartete Landungsfolge darf keinen Overload verschenken.
func _test_overload_survives_wrong_sequence() -> void:
	var r := ResonanceSystem.new()
	# GDScript-Lambdas fangen Locals per Wert; ein Array ist ein Referenztyp und
	# traegt den Zaehler deshalb korrekt nach aussen.
	var overloads := [0]
	r.overload_released.connect(func() -> void: overloads[0] += 1)
	for quality in [JumpConfig.LandingQuality.RESONANCE, JumpConfig.LandingQuality.RESONANCE, JumpConfig.LandingQuality.RESONANCE]:
		r.register_landing(quality)
	_check(overloads[0] == 1, "drei RESONANCE-Landungen loesen genau einen Overload aus")
	_check(r.charges == 0, "und entladen die Resonanz")

	# Nach einem Bruch braucht es wieder drei volle Landungen. Die Sequenz
	# PERFECT, NORMAL, PERFECT, PERFECT ergibt 1 -> 0 -> 1 -> 2, also noch
	# keinen zweiten Overload; erst die dritte volle Landung danach entlaedt.
	r.register_landing(JumpConfig.LandingQuality.PERFECT)
	r.register_landing(JumpConfig.LandingQuality.NORMAL)
	r.register_landing(JumpConfig.LandingQuality.PERFECT)
	r.register_landing(JumpConfig.LandingQuality.PERFECT)
	_check(overloads[0] == 1, "ein Bruch verwirft die Ladung, ohne einen Overload zu schenken")
	_check(r.charges == 2, "nach dem Bruch sind erst zwei Ladungen wieder aufgebaut")

	r.register_landing(JumpConfig.LandingQuality.PERFECT)
	_check(overloads[0] == 2, "die dritte volle Landung entlaedt den naechsten Overload")
	_check(r.charges == 0, "die zweite volle Ladung entlaedt erneut")

## Das HUD zeigt genau RESONANCE_MAX_CHARGES Segmente in einer Zeile.
func _test_hud_geometry() -> void:
	var segment: Vector2 = JumpConfig.RESONANCE_HUD_SEGMENT_SIZE
	var gap: float = JumpConfig.RESONANCE_HUD_SEGMENT_GAP
	var expected := JumpConfig.RESONANCE_MAX_CHARGES * segment.x + (JumpConfig.RESONANCE_MAX_CHARGES - 1) * gap
	_check(is_equal_approx(JumpConfig.resonance_hud_width(), expected), "die HUD-Breite passt zu drei Segmenten")
	_check(JumpConfig.RESONANCE_HUD_SEGMENT_SIZE.x > 0.0 and JumpConfig.RESONANCE_HUD_SEGMENT_SIZE.y > 0.0, "die Segmente haben eine sichtbare Groesse")
	_check(JumpConfig.resonance_hud_width() < JumpConfig.PLATFORM_SIZE.x, "das HUD bleibt schmaler als eine Plattform")

## Die sichtbare Sockelmarkierung und die Trefferzone muessen dieselbe Groesse
## haben: der Spieler zielt auf das, was er sieht.
func _test_perfect_band_size() -> void:
	var width: float = JumpConfig.PLATFORM_SIZE.x
	var band: float = JumpConfig.perfect_band_width(width)
	_check(is_equal_approx(band, width * JumpConfig.PERFECT_CENTER_RATIO * 2.0), "Bandbreite folgt der Konfiguration")
	# Drei Baender muessen gleichzeitig nutzbar bleiben. Die Anforderungen sind
	# gegeneinander abgewogen, nicht willkuerlich (Werte fuer die 280px-Plattform):
	#   PERFECT   >= 128 px  (~46 Punkte auf 390pt: Daumen-Untergrenze)
	#   RESONANCE >= PERFECT + 48 px (der Mittelring darf keine Haarlinie sein)
	#   NORMAL    >= 60 px gesamt (der "unsauber"-Bereich an den Kanten)
	_check(band >= 128.0, "PERFECT-Zone ist mindestens 128 Weltpixel breit (%d)" % int(band))
	_check(band > JumpConfig.PLATFORM_CENTER_MARK_SIZE.x, "Trefferzone ist breiter als die alte Zier-Markierung")
	_check(JumpConfig.resonance_band_width(width) < width, "RESONANCE-Zone bleibt schmaler als die Plattform")
	_check(JumpConfig.resonance_band_width(width) >= band + 48.0, "Mittelring ist breit genug zum Anspielen (%d px)" % int(JumpConfig.resonance_band_width(width)))
	_check(width - JumpConfig.resonance_band_width(width) >= 60.0, "aussen bleibt ein nutzbarer NORMAL-Bereich (%d px)" % int(width - JumpConfig.resonance_band_width(width)))
	# Genau an der Kante noch PERFECT, einen Schritt daneben nicht mehr.
	_check(JumpConfig.classify_landing(band * 0.5, width) == JumpConfig.LandingQuality.PERFECT, "Kante der Zone zaehlt noch als PERFECT")
	_check(JumpConfig.classify_landing(band * 0.5 + 0.5, width) == JumpConfig.LandingQuality.RESONANCE, "knapp ausserhalb ist RESONANCE")
	_check(JumpConfig.resonance_band_width(width) > band, "RESONANCE-Zone ist breiter als PERFECT")

func _test_restart_resets() -> void:
	var game := Game.new()
	get_root().add_child(game)
	await process_frame
	game._phase = Game.Phase.PLAYING
	game.jumper.set_physics_process(false)
	game._on_overload_check(JumpConfig.LandingQuality.PERFECT)
	game._on_overload_check(JumpConfig.LandingQuality.PERFECT)
	_check(game.resonance.charges == 2, "vor dem Neustart sind Ladungen vorhanden")

	game._restart()
	game.set_process(false)
	game.jumper.set_physics_process(false)
	game.camera.set_physics_process(false)
	await process_frame
	_check(
		game.resonance.charges == 0 and game.resonance.best_charges == 0 and game.resonance.overload_count == 0,
		"Neustart setzt Ladungen, Bestwert und Overload-Zaehler zurueck"
	)
	_check(is_equal_approx(game._overload_display, 0.0), "Neustart loescht die OVERLOAD-Anzeige")

	game.queue_free()
	await process_frame

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ✓ " + description)
		return
	failures += 1
	print("  ✗ " + description)
