extends SceneTree

## Pausenmenue: prueft den ECHTEN Pfad (Knopf-Tap -> pause() -> SceneTree ->
## Resume/Neustart) und nicht gesetzten Zustand. Ein Test, der nur pause()
## aufruft, wuerde nicht bemerken, dass der Pausenknopf an der falschen Stelle
## sitzt oder der Pausenschirm keine Eingabe annimmt.

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")

var failures := 0

func _init() -> void:
	await _test_button_geometry()
	await _test_tap_pauses_via_real_path()
	await _test_paused_tree_really_stops()
	await _test_resume_restores_play()
	await _test_resume_rect_is_reachable()
	await _test_restart_from_pause_is_clean()
	await _test_tap_outside_does_nothing()
	await _test_button_hidden_outside_playing()
	await _test_no_lost_pointer_after_pause()
	await _test_reopen_after_resume_is_not_locked()
	await _test_restart_works_on_second_pause()
	print("PAUSENMENUE: ALLE OK" if failures == 0 else "PAUSENMENUE: %d FEHLER" % failures)
	quit(1 if failures > 0 else 0)

## Der Knopf muss im Bildschirm liegen, nicht ausserhalb und nicht unter dem
## Safe-Area-Rand. Ueber mehrere Groessen, weil er mit der Breite skaliert.
func _test_button_geometry() -> void:
	for screen: Vector2 in [Vector2(390.0, 844.0), Vector2(1080.0, 1920.0), Vector2(320.0, 568.0)]:
		var rect := PauseButton.rect_for(screen)
		_check(rect.size.x > 0.0 and rect.size.y > 0.0, "Knopf hat auf %dx%d eine Groesse" % [screen.x, screen.y])
		_check(rect.position.x >= 0.0 and rect.position.y >= 0.0, "Knopf bleibt auf %dx%d im Bild (links/oben)" % [screen.x, screen.y])
		_check(rect.end.x <= screen.x and rect.end.y <= screen.y, "Knopf bleibt auf %dx%d im Bild (rechts/unten)" % [screen.x, screen.y])
		# Rechts oben: die Mitte muss in der oberen rechten Bildhaelfte liegen.
		var center := rect.get_center()
		_check(center.x > screen.x * 0.5, "Knopf sitzt auf %dx%d in der rechten Haelfte" % [screen.x, screen.y])
		_check(center.y < screen.y * 0.5, "Knopf sitzt auf %dx%d in der oberen Haelfte" % [screen.x, screen.y])
	# Der Knopf darf den SCORE-Text des HUD nicht ueberdecken: das HUD beginnt
	# links bei RESONANCE_HUD_ORIGIN und ist rund eine Plattformbreite breit.
	var narrow := PauseButton.rect_for(Vector2(390.0, 844.0))
	_check(narrow.position.x > 390.0 * 0.6, "Knopf laesst auf einem Telefon den linken HUD-Bereich frei")

## Der echte Weg: Tap auf den Knopf, ausgewertet von _unhandled_input des Spiels.
func _test_tap_pauses_via_real_path() -> void:
	var game = await _playing_game()
	var hit: Rect2 = game._pause_button_hit_rect()
	var target: Vector2 = hit.get_center()
	# Ein unsichtbarer oder ausserhalb liegender Knopf wuerde hier trotzdem
	# "getroffen": der Test muss die Flaeche selbst prüfen, sonst ist er gruen
	# ohne etwas zu beweisen.
	_check(hit.size.x > 0.0 and hit.size.y > 0.0, "die Trefferflaeche hat eine Groesse")
	_check(hit.position.x >= 0.0 and hit.position.y >= 0.0, "die Trefferflaeche liegt im Bild")
	_check(hit.end.x <= game.pause_button.size.x and hit.end.y <= game.pause_button.size.y, "die Trefferflaeche endet vor dem Bildrand")

	# Ein Tap mitten auf ein Landerfeld darf NICHT pausieren.
	var platform: JumpPlatform = game.platform_director._active_platforms[1]
	game._unhandled_input(_tap(platform.global_position + Vector2(0.0, 700.0)))
	_check(not game._is_paused, "ein Tap im Spielfeld pausiert nicht")

	# Der Tap auf den Knopf muss ueber den echten Eingabepfad ankommen.
	game._unhandled_input(_tap(target))
	_check(game._is_paused, "ein Tap auf den Pausenknopf pausiert das Spiel")
	_check(paused, "der SceneTree steht wirklich auf pause")
	_check(game.pause_menu != null and is_instance_valid(game.pause_menu), "das Pausenmenue existiert")
	_check(game.pause_menu.visible, "das Pausenmenue ist sichtbar")
	_check(not game.pause_button.visible, "der Pausenknopf verschwindet hinter dem Menue")
	await process_frame

## Angehalten heisst angehalten: die Physik darf sich nicht weiterbewegen.
func _test_paused_tree_really_stops() -> void:
	var game = await _playing_game()
	game.jumper.set_physics_process(true)
	game.camera.set_physics_process(true)
	game._unhandled_input(_tap(game._pause_button_hit_rect().get_center()))
	_check(game._is_paused, "das Spiel ist pausiert")
	var before_y: float = game.jumper.global_position.y
	var before_vy: float = game.jumper.velocity.y
	for _frame in 12:
		await process_frame
	_check(is_equal_approx(game.jumper.global_position.y, before_y), "der Jumper bewegt sich in der Pause nicht")
	_check(is_equal_approx(game.jumper.velocity.y, before_vy), "die Fallgeschwindigkeit bleibt in der Pause stehen")
	game.queue_free()
	await process_frame
	paused = false

## WEITER muss den Baum wieder freigeben und den Knopf zurueckbringen.
func _test_resume_restores_play() -> void:
	var game = await _playing_game()
	# In der Pause steht der Baum still; fuer die Bewegung nach dem Fortsetzen
	# muss die Physik erst wieder laufen. Der Test darf das nicht dem
	# Spielzustand ueberlassen, sonst prueft er die eigene Vorsicht mit.
	game.jumper.set_physics_process(true)
	game.camera.set_physics_process(true)
	game._unhandled_input(_tap(game._pause_button_hit_rect().get_center()))
	_check(game._is_paused, "vor dem Fortsetzen ist das Spiel pausiert")
	game._on_resume_requested()
	# Der Baum laeuft erst, wenn das Ausblenden fertig ist.
	_check(game._is_paused == false, "WEITER loest die Pause")
	await _wait(JumpConfig.PAUSE_OUT_DURATION + 0.15)
	_check(not paused, "nach dem Fortsetzen laeuft der SceneTree wieder")
	_check(not game.pause_menu.visible, "das Pausenmenue ist danach ausgeblendet")
	_check(game.pause_button.visible, "der Pausenknopf ist wieder da")
	var y_before: float = game.jumper.global_position.y
	await _wait(0.25)
	_check(game.jumper.global_position.y != y_before, "nach dem Fortsetzen bewegt sich der Jumper wieder")
	game.queue_free()
	await process_frame
	paused = false

## Die WEITER-Zeile muss dort liegen, wo die Mausfilter-freie Flaeche sie
## erwartet. Zwei getrennte Rechnungen wuerden frueher oder spaeter driften und
## der sichtbare Knopf waere nicht mehr die Flaeche, die reagiert.
##
## Achtung Koordinatenraum: das Menue rechnet in VIRTUELLEN Canvas-Pixeln
## (1080 breit, per keep_width hoeher als breit skaliert). Fenstergroesse und
## Canvas-Groesse sind NICHT dasselbe — gegen die Fensterhoehe zu pruefen meldet
## hier falschen Ueberlauf.
func _test_resume_rect_is_reachable() -> void:
	var menu := PauseMenu.new()
	get_root().add_child(menu)
	await process_frame
	await process_frame
	var screen: Vector2 = menu.size
	var resume: Rect2 = menu.resume_rect()
	var restart: Rect2 = menu.restart_rect()
	_check(resume.size.x > 0.0 and resume.size.y > 0.0, "die WEITER-Zeile hat eine Flaeche")
	_check(resume.has_point(resume.get_center()), "die Mitte der WEITER-Zeile liegt in ihrem Rechteck")
	_check(restart.position.y >= resume.end.y, "NEU STARTEN liegt unter WEITER")
	_check(menu._panel.position.y >= 0.0 and menu._panel.end.y <= screen.y, "das Panel liegt ganz im Bild")
	_check(menu._panel.position.x >= 0.0 and menu._panel.end.x <= screen.x, "das Panel bleibt in der Breite im Bild")
	# Die Trefferflaechen duerfen sich nicht ueberlappen, sonst ist der Tap
	# zwischen den Zeilen mehrdeutig.
	_check(not resume.intersects(restart), "die beiden Zeilen ueberlappen sich nicht")
	# Groesse in Design-Einheiten. Der Geraetepunkt-Mindestwert haengt am
	# Stretch-Faktor, der ohne echtes Fenster (headless) nicht ermittelbar ist —
	# diese Zusage wird im Render-QA mit echtem Fenster geprueft, nicht hier.
	_check(resume.size.y >= PauseMenu.ROW_HEIGHT, "WEITER ist mindestens eine Zeilenhoehe hoch (%d)" % int(resume.size.y))
	_check(restart.size.y >= PauseMenu.ROW_HEIGHT, "NEU STARTEN ist mindestens eine Zeilenhoehe hoch (%d)" % int(restart.size.y))
	_check(menu._panel.size.x <= menu.PANEL_MAX_WIDTH * menu._unit + 0.001, "das Panel bleibt in der vorgesehenen Breite")
	_check(menu._panel.size.y < screen.y, "das Panel bleibt flacher als der Bildschirm")
	# Der echte Tap auf die untere Zeile.
	menu._handle_tap(restart.get_center())
	_check(menu._locked, "ein Tap auf NEU STARTEN verriegelt das Menue")
	menu.queue_free()
	await process_frame

## Aus der Pause neu starten: die Welt muss laufen, sauber sein und das Menue
## darf nicht als Leiche zurueckbleiben.
func _test_restart_from_pause_is_clean() -> void:
	var game = await _playing_game()
	game._unhandled_input(_tap(game._pause_button_hit_rect().get_center()))
	_check(game._is_paused, "das Spiel ist vor dem Neustart pausiert")
	game._on_restart_requested()
	await process_frame
	_check(not paused, "der Neustart hebt die Pause auf")
	_check(game._is_paused == false, "der Neustart loescht den Pausenzustand")
	_check(game.pause_menu == null, "das Pausenmenue ist danach weg")
	_check(game.is_game_over == false, "der Neustart startet kein Game Over")
	_check(game.score == 0, "der Neustart setzt den Score zurueck")
	# Die neue Welt muss sofort laufen, nicht eingefroren stehen.
	_check(game.jumper.is_physics_processing(), "der neue Jumper laeuft nach dem Neustart")
	var y_before: float = game.jumper.global_position.y
	await _wait(0.2)
	_check(game.jumper.global_position.y != y_before, "die neue Runde bewegt sich wirklich")
	_check(game.pause_button.visible, "der Pausenknopf ist in der neuen Runde da")
	game.queue_free()
	await process_frame

## Ein Tap neben das Menue darf nichts ausloesen — sonst wuerde ein verrutschter
## Daumen das Spiel versehentlich fortsetzen.
func _test_tap_outside_does_nothing() -> void:
	var game = await _playing_game()
	game._unhandled_input(_tap(game._pause_button_hit_rect().get_center()))
	_check(game._is_paused, "das Spiel ist pausiert")
	var outside := Vector2(4.0, 4.0)
	_check(not game.pause_menu.resume_rect().has_point(outside), "die Testposition liegt wirklich ausserhalb")
	game.pause_menu._handle_tap(outside)
	_check(game._is_paused, "ein Tap neben das Menue setzt nicht fort")
	_check(not game.pause_menu._locked, "ein Tap neben das Menue verriegelt nichts")
	game.queue_free()
	await process_frame
	paused = false

## Der Knopf gehoert nur ins laufende Spiel: nicht im Startmenue und nicht
## waehrend des Start-Uebergangs.
func _test_button_hidden_outside_playing() -> void:
	var game := Game.new()
	get_root().add_child(game)
	await process_frame
	_check(not game.pause_button.visible, "im Startmenue ist kein Pausenknopf zu sehen")
	_check(not game.pause_button_available(), "im Startmenue ist der Pausenknopf nicht bedienbar")
	game.queue_free()
	await process_frame

## Ein Finger, der beim Pausieren noch lag, darf nach dem Fortsetzen nicht
## dauerhaft die Steuerung sperren.
func _test_no_lost_pointer_after_pause() -> void:
	var game = await _playing_game()
	game._blocked_pointers["mouse"] = true
	game._held_pointers["mouse"] = true
	game._unhandled_input(_tap(game._pause_button_hit_rect().get_center()))
	_check(game._is_paused, "das Spiel ist pausiert")
	_check(game._blocked_pointers.is_empty(), "die Pause verwirft den alten Zeigerstand")
	_check(game._held_pointers.is_empty(), "die Pause verwirft gehaltene Zeiger")
	game._on_resume_requested()
	await _wait(JumpConfig.PAUSE_OUT_DURATION + 0.15)
	_check(game.pause_button.visible, "der Knopf ist nach dem Fortsetzen wieder bedienbar")
	game.queue_free()
	await process_frame
	paused = false

## Wiederholtes Pausieren: das Menue wird beim Fortsetzen nur versteckt, nicht
## zerstoert. Bleibt der Eingaberiegel stehen, ist es beim zweiten Oeffnen
## sichtbar, aber taub — WEITER und NEU STARTEN reagieren dann nicht mehr.
## Genau dieser Fehler ist einmal live gegangen.
func _test_reopen_after_resume_is_not_locked() -> void:
	var game = await _playing_game()
	game._unhandled_input(_tap(game._pause_button_hit_rect().get_center()))
	_check(game._is_paused, "erste Pause ueber den echten Pfad")

	# Fortsetzen und die Ausblendung abwarten.
	game.pause_menu._handle_tap(game.pause_menu.resume_rect().get_center())
	_check(game.pause_menu._locked, "das Menue verriegelt nach der ersten Wahl")
	await _wait(JumpConfig.PAUSE_OUT_DURATION + 0.15)

	# Zweite Pause. Die Menue-Instanz ist dieselbe wie vorher.
	game._unhandled_input(_tap(game._pause_button_hit_rect().get_center()))
	_check(game._is_paused, "das Spiel laesst sich erneut pausieren")
	_check(game.pause_menu._locked == false, "das wieder geoeffnete Menue ist nicht mehr verriegelt")

	# Und die Aktionen muessen wirklich wieder ankommen.
	var resume_center: Vector2 = game.pause_menu.resume_rect().get_center()
	game.pause_menu._handle_tap(resume_center)
	_check(game.pause_menu._locked, "WEITER greift auch beim zweiten Mal")
	await _wait(JumpConfig.PAUSE_OUT_DURATION + 0.15)
	_check(not paused, "die zweite Fortsetzung gibt den Baum wirklich frei")

	game.queue_free()
	await process_frame
	paused = false

## Auch der Neustart muss beim zweiten Anlauf funktionieren — also der Weg,
## den ein Spieler wirklich nimmt: pausieren, fortsetzen, wieder pausieren,
## dann neu starten.
func _test_restart_works_on_second_pause() -> void:
	var game = await _playing_game()
	game._unhandled_input(_tap(game._pause_button_hit_rect().get_center()))
	game.pause_menu._handle_tap(game.pause_menu.resume_rect().get_center())
	await _wait(JumpConfig.PAUSE_OUT_DURATION + 0.15)

	game._unhandled_input(_tap(game._pause_button_hit_rect().get_center()))
	_check(game._is_paused, "zweite Pause steht")
	game.pause_menu._handle_tap(game.pause_menu.restart_rect().get_center())
	await process_frame
	_check(not paused, "Neustart aus der zweiten Pause gibt den Baum frei")
	_check(game._phase == Game.Phase.PLAYING, "Neustart aus der zweiten Pause startet die Runde")
	_check(game.pause_menu == null, "das Menue ist danach weg")
	var y_before: float = game.jumper.global_position.y
	await _wait(0.2)
	_check(game.jumper.global_position.y != y_before, "die neue Runde laeuft wirklich")

	game.queue_free()
	await process_frame
	paused = false

## Spiel im laufenden Zustand, ohne Choreografie. Der Jumper bewegt sich nicht
## von selbst, damit die Tests die Position kontrollieren koennen.
## Ohne Rueckgabetyp: der Aufrufer bekommt die konkrete Spielinstanz, nicht die
## Sicht eines Node — sonst sind pause_menu und pause_button nicht aufloesbar.
func _playing_game():
	var game := Game.new()
	get_root().add_child(game)
	await process_frame
	game._phase = Game.Phase.PLAYING
	game.jumper.set_physics_process(false)
	game.camera.set_physics_process(false)
	game._update_pause_button()
	await process_frame
	return game

func _tap(position: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	event.position = position
	return event

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ✓ " + description)
		return
	failures += 1
	print("  ✗ " + description)
