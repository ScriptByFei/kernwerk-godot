# Overload als Spielerentscheidung — Abnahmebericht

## Aenderungen
- `scripts/jump/resonance_system.gd`: 3/3 bleibt READY (kein Stacken, kein Auto-Tor), `arm_overload()`, `is_overload_ready()` / `is_overload_armed()`; Verbrauch nur ueber die vorherige Entscheidung; NORMAL loescht READY **und** ARMED ohne Verbrauch/Zaehlung.
- `scripts/jump/overload_input.gd` (neu): spiegelnder Adapter des getesteten `DiveInput` (nur Y invertiert), verriegelt den laufenden Aufwaertszug einmalig.
- `scripts/game/game.gd`: `overload_input` neben `dive_input` verdrahtet; `try_arm_overload()` sperrt START_MENU/STARTING/Pause/Tree-Pause/GameOver; erkannte Flicks verankern das Gegenfenster neu. Keine Kraftaenderung im Flug.
- `scripts/ui/resonance_hud.gd` + `scripts/jump/jump_config.gd`: bestehende Segmentzeile zeigt READY (voll, goldener Puls) und ARMED (helle Fuellung, goldene Unterkante, kurzer Impuls, Text); erst der Verbrauch nutzt die bisherige `overload_display`-Anzeige.
- `scripts/jump/jumper.gd`: gehaltene 3/3 werden physikalisch konsistent behandelt; nur die unveraenderte Lichtpalette deckelt ihren Index.

## Tests
- `tests/overload_choice_test.gd` — 72 Checks: READY haelt, kein Auto-Trigger, unter 3/3 inert, arm/consume/0, kein Doppelarm, NORMAL loescht beide Zustaende, Statistik nur beim Verbrauch, Phasensperren, Ladungs- und Gravitationsstufe im selben Absprung, ASCII-Labels.
- `tests/overload_input_test.gd` — 39 Checks: Richtung, 30-240 Hz, Schraegzug, Zeitfenster, Zittern, Mehrfachausloesung.
- `tests/overload_pattern_routes_test.gd` — 14.007 Checks: Risk Choice, Cross, Precision Rush, Recovery ueber alle Stufen/Startspuren/Seeds mit Produktionsphysik und Lenkung, ohne Overload, min. 106 px Hoehen- und 98 px Breitenreserve; Overload als Option 39 % hoeher.
- `qa/overload_choice_probe.gd` (37 Checks) und `qa/overload_choice_loop_probe.gd` (99 Checks) — echte Eingabezustellung bei 430x932. Voller Loop: 9 Aktivierungen -> 9 Verbrauch beim naechsten Kollisionsabsprung, 28 gehaltene 3/3-Landungen, 58 Dives, Divergenzen 0.
- `qa/pause_real_input_probe.gd` — unveraendert gruen.

## Beweise
- Mutationen `tools/overload_choice_mutations.py`: 13/13 erkannt (Auto-Entladung, NORMAL-Erhalt, Doppelarm, Statistik beim Armen, Teleport, Phasengate, Gravitationsdeckel, Wiederholung, Richtung, Horizontaldrift, Verdrahtung, Impuls).
- Bildnachweis `tools/verify_overload_choice_visual.py`: leeres Bild gegen HEAD **0** veraenderte Pixel, ausserhalb des HUD **0**; READY-Puls 255, READY/ARMED 306, Impuls 175 Pixel; beide Zeichenzweige mutationsgeprueft.
- Vollstaendiger Gate: `PASS: import, 32 suites, main-scene smoke, Web export` (PCK 3.821.476 B).
- Evidenz: `docs/assets/screenshots/overload_choice/`.

## Offen
- Kein Commit/Push/Deploy.
- iPhone-Abnahme steht aus (Puls, ARMED-Feedback, Flick-Gefuehl).
- Nicht lokal reproduzierbar: Remote-CI mit Godot 4.6.3.
