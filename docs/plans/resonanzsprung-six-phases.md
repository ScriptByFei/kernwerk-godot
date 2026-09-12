# Resonanzsprung – sechs sequenzielle Verbesserungen

## Taskvertrag
- Basis: HEAD `6fa0f63`, tracked Arbeitsbaum beim Start sauber; vollständiger Ausgangsstatus unter `/tmp/kernwerk-six-phases/initial-status.txt`. Untracked Nutzerdateien bleiben unangetastet.
- Einziger Code-Writer in diesem Lauf: ausführender Hermes-Agent. Pixel-builder führt Design und read-only Visual QA über CLI; keine parallelen Dateischreiber.
- Erlaubt: `scripts/jump/`, `scripts/game/game.gd`, `scripts/ui/`, `tests/`, `qa/`, dieser Plan und neue Evidence. Keine Refactors, Commits, Pushes, Deployments; WebUI :8787 bleibt unberührt.
- Referenzen: `assets/jump/approved/reactor-core/`, Produktion `assets/jump/reactor_core/` read-only. `assets/jump/approved/plush-character/` geschützt, niemals integriert. Keine neuen selbstgezeichneten Artworks.
- Nichtziele: Gegner, Waffen, Coins, Shops, Skilltrees, Online. Bestwert, Steuerung, Pause und bestehende Resonanzregeln erhalten.
- Akzeptanz je Phase: neue deterministische Tests, voller `python3 tools/verify_project.py` ohne Fehler, Logs unter `/tmp/kernwerk-six-phases/`. UI zusätzlich echtes Fenster 430x932 via xvfb und `Input.parse_input_event`. Tests dürfen den realen Bestwert nie schreiben.
- **iPhone-Abnahme bleibt OFFEN.** Alle Gates sind technisch, keine Geräteabnahme.

## Ergebnisse je Phase
1. **Plattformvarianten** – Standard 280 / schmal 200 / Resonanzfokus 280 (Resonanz 0.44). Collider und sichtbare Breite aus einer Quelle. 16.052 Checks. Logs `phase1-*`, `phase5-platform-variants-fix.log`; Bild `phase1-platforms.png`.
2. **Landing-Feedback** – drei gecachte Mono-PCM-Kontakte (Pitch steigt mit der Kette), PERFECT zusätzlich 3 Weltpixel/0.12 s Kameraimpuls nur auf `offset`; Todeslinie und Ratchet unberührt. 26 Checks. Logs `phase2-*`; Bilder `phase2-{normal,resonance,perfect}.png`.
3. **Overload** – dritter Absprung real 1960 statt 1758 (vorher unsichtbar, weil am alten Cap 1800 gedeckelt), Pitch 1,36 statt 1,24, Kernlicht 0.35 mit wachsendem Radius, warmgoldener Ring bei 120 und Aura bei 132 — **außerhalb** der 192 breiten Kernsilhouette, kein Vollkörperflash. 39 Checks. Logs `phase3-*`; Bilder `phase3-overload-{1,2,3}.png`.
4. **Höhenzonen** – fünf Stimmungen (Reaktorschacht, Kühlsektion, Hochspannung, instabil, kritisch), weich über 3500 Weltpixel, gesteuert vom sichtbaren Ausschnitt, nicht vom Score. 13 Checks + Mutationsprobe. Logs `phase4-*`; Bilder `phase4-zone-{1..5}.png`.
5. **Routenwahl** – riskante Abzweigung zwischen Vorgänger und Nachfolger, aus dem erlaubten Sprungschritt abgeleitet statt gewürfelt. Belohnung 25 einmalig je Plattform. 6.497 Checks, drei Mutationsproben erkannt. Logs `phase5-*`; Bild `phase5-platform-variants.png`.
6. **Run-Statistik** – `RunStats` (Höhe, PERFECT, RESONANCE, NORMAL, beste Kette, Overloads) getrennt vom Bestwert; Anzeige: Höhe primär, Score/Bestwert darunter, 2×2-Statistikblock. 87 Checks. Logs `phase6-*`; Bild `phase6-game-over.png`.

## Abschluss-Gate
- `PASS: import, 18 Suites, main-scene smoke, Webexport` (`final-gate.log`), PCK 3.153.980 B.
- Echte Eingabe 430x932 (Pause → Weiter → Pause → Neustart): `ALLE OK` (`final-input.log`).

## Gefundene und behobene Fehler
- **Phase-3-Kraft war unsichtbar:** `OVERLOAD_BOUNCE_SPEED` lag am `MAX_BOUNCE_SPEED`-Cap, ein Anheben der Konstante allein hätte nichts bewirkt. Über den echten Landungspfad gemessen statt angenommen.
- **Risiko-Route ohne Risiko:** Resonanzband 0.52 auf 200 px Breite = 208 px Band, also breiter als die Plattform. Jede Landung wäre RESONANCE oder PERFECT gewesen, die Kette hätte nie reißen können. Auf 0.42 gesenkt, Mindestrand 12 px je Seite, Test dafür ergänzt.
- **Doppelt belegtes Kennzeichen:** schmale und riskante Plattform zeichneten dieselbe zweiseitige Kerbe. Die riskante trägt jetzt eine einseitige Kerbe.
- **Vierte Variante brach Phase 1:** die alte Zusicherung „genau drei Varianten“ wurde auf die erwarteten drei Routenvarianten präzisiert.
- **Objekt-Leak-Warnung** in den neuen Suiten: Abbruch mitten im Abspielen kurzer Kontakte. Tests lassen sie jetzt ausklingen.

## Verbleibende Punkte
- iPhone-Abnahme offen; nichts committet, gepusht oder deployt.
- Feine Unterscheidungsmerkmale (Kerbenform, Bandbreite) sind bei 430x932 dezent; das stärkste Risikosignal ist die geringere Plattformbreite. Bewusst im Sinne des ruhigen Stils, auf dem Gerät zu prüfen.
- Der Zeitverlauf von Ringen und Kameraimpuls ist mit Standbildern nicht belegt.
- Phase 2–5 wurden zwischenzeitlich in einem konkurrierenden Arbeitsprozess mitgeschrieben; die Einzelwriter-Zuordnung ist für diesen Zeitraum nicht durchgehend belegt.
