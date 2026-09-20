# Overload: Spielerentscheidung

## Vertrag
- 3/3 speichert genau einen READY-Overload. Weitere gute Landungen halten 3/3.
- Up-Flick nur im laufenden Spiel und bei READY -> ARMED; keine unmittelbare Physikaenderung.
- Naechste RESONANCE/PERFECT-Landung verbraucht ARMED beim regulaeren Absprung, zaehlt einmal und setzt 0/3.
- NORMAL hat Vorrang: loescht READY **und ARMED** ohne Verbrauch/Statistik.
- Down-Flick/Dive unveraendert; spiegelnde Wiederverwendung des getesteten Dive-Detektors fuer Up. Gegenlaeufige Messfenster beim erkannten Flick neu verankern.
- Bestehendes HUD: drei volle goldene Segmente, dezenter READY-Puls; ARMED mit kurzer Aktivierungswelle und unterscheidbarer Kontur/kleinem Status. Kein neuer Button.
- 3/3 verwendet die bestehende Ladungs-Physik konsistent fuer Kraft UND Gravitation; Overload-Physik unveraendert.

## Erlaubter Umfang
ResonanceSystem, neuer OverloadInput-Adapter, Input-Verdrahtung in game.gd, ResonanceHud und minimale Jumper-Korrektur fuer bislang unerreichbare gehaltene 3/3. Zugehoerige Tests, QA und Dokumentation.

## Nichtziele
Keine Aenderungen an Hintergrund, Artwork, Plattform-Patterns, Difficulty, Physik-Konstanten, Score-Regeln, Sound-Assets, Bestwertspeicherung. Kein Commit/Push/Deploy ohne Freigabe. Vorhandene untracked Nutzerdateien unberuehrt.

## Abnahme
Headless: kein Auto-Trigger; halten ueber mehrere Spruenge; NORMAL-Reset; unter 3/3 inert; arm/consume/0; kein Doppeltrigger; PERFECT erhalten; Statistik nur beim Verbrauch; Phasensperren.
Reales Fenster 430x932: Input.parse_input_event/flush -> Viewport -> Spiel fuer beide Flicks, horizontale Steuerung, Pause/Start/GameOver und echte HUD-Bilder.
Patterns: Risk Choice, Cross, Precision Rush, Recovery mit normaler Physik ohne Overload erreichbar; Director unveraendert.
Mutationsproben fuer automatischen Verbrauch, NORMAL-Verlust, Entladung, Input-Gate und HUD.
Vollstaendiger `python3 tools/verify_project.py`, frisches read-only Review, gerenderte Vorschau. iPhone-Abnahme bleibt offen.
