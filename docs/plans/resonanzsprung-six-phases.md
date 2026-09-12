# Resonanzsprung – sechs sequenzielle Verbesserungen

## Taskvertrag
- Basis: HEAD `6fa0f63`, tracked Arbeitsbaum beim Start sauber. Untracked Nutzerdateien bleiben unangetastet.
- Einziger Code-Writer in diesem Lauf: ausführender Hermes-Agent. Pixel-builder führt Design und read-only Visual QA über CLI; keine parallelen Dateischreiber.
- Erlaubt: `scripts/jump/`, `scripts/game/game.gd`, `scripts/ui/`, `tests/`, `qa/`, dieser Plan. Keine Refactors. Commit/Push nur auf ausdrückliche Anweisung (Push deployt via CI).
- Referenzen: `assets/jump/approved/reactor-core/` read-only. Plush-Charakter nicht integriert.
- Nichtziele: Gegner, Waffen, Coins, Shops, Skilltrees, Online. Bestwert, Steuerung, Pause und Resonanzregeln erhalten.
- **iPhone-Abnahme bleibt OFFEN.** Alle Gates sind technisch.

## Ergebnisse je Phase
1. **Plattformvarianten** – Standard 280 / schmal 200 / Resonanzfokus 280 (Band 0.44) / riskant 200 (Band 0.42). Collider und sichtbare Breite aus einer Quelle. 16.052 Checks.
2. **Landing-Feedback** – drei gecachte Mono-PCM-Kontakte, Pitch steigt mit der Kette; PERFECT zusätzlich 3 Weltpixel Kameraimpuls. 26 Checks.
3. **Overload** – spürbarer Sprung 1960 statt 1758, Pitch 1,36, Kernlicht mit wachsendem Radius, warmgoldener Ring (120) und Aura (132) außerhalb der Kernsilhouette. 39 Checks.
4. **Höhenzonen** – fünf Stimmungen, weich über 3.500 Weltpixel, am sichtbaren Ausschnitt statt am Score. 13 Checks + Mutationsprobe.
5. **Routenwahl** – riskante Abzweigung aus dem erlaubten Sprungschritt abgeleitet, Belohnung 25 einmalig. 6.497 Checks, drei Mutationsproben.
6. **Run-Statistik** – `RunStats` (Höhe, PERFECT, RESONANCE, NORMAL, Kette, Overloads) getrennt vom Bestwert; Anzeige: Höhe primär, 2×2-Block. 87 Checks.

## Nacharbeit nach dem ersten Gate (dieselbe Sitzung)
Standbilder belegen nur, DASS etwas passiert — nicht, wie es sich über die Zeit verhält. Deshalb wurden die beiden offenen Feinpunkte numerisch geprüft statt angesehen.

**Gefunden und behoben:**
- **Kameraimpuls erreichte nie ein Bild.** `perfect_impact()` setzte 3,0 Weltpixel, aber `advance_impact()` lief im selben Physik-Tick und senkte den Wert, bevor gerendert wurde. Gemessen wurden real 2,225 statt 3,0 — dieselbe Sichtbarkeitsfalle wie beim Overload. Fix: der erste `advance` nach dem Auslösen hält den vollen Ausschlag einen Tick. Messreihe jetzt `[3.0, 2.225, 1.565, 1.021, 0.593, 0.28, 0.083, 0.002, 0.0]`. Mutationsprobe: ohne Fix rot.
- **Kerbe der riskanten Route war toter Code.** Sie stand als `elif` hinter dem Zweig für Resonanzfokus/Risiko und wurde deshalb nie erreicht; RISKY war nur am breiteren Band erkennbar. Jetzt eigener `if`-Zweig. Pixelmessung: 54 statt 50 Kerbenpixel; Mutationsprobe rot.

**Eigener Fehler, festgehalten:** Die erste Fassung des Kerben-Tests zählte alle abweichenden Bildpunkte zwischen schmal und riskant. Weil sich beide ohnehin über die Bandbreite unterscheiden (258 Pixel), machte das Entfernen der Kerbe nur 1 Pixel aus — der Test blieb grün und hätte den Bug nie gefunden. Erst die gezielte Messung der Kerbenfarbe ist unterscheidend.

## Abschluss-Gate
- `PASS: import, 19 Suiten, main-scene smoke, Webexport` (`final3-gate.log`), PCK 3.154.220 B.
- Echte Eingabe 430×932 (Pause → Weiter → Pause → Neustart): `ALLE OK` (`final3-input.log`).
- Kerben-Pixelprobe: `3 checks, 0 failures` (`final3-marker.log`).
- Neuer Test `tests/imperfect_motion_test.gd` (7 Checks) belegt den Zeitverlauf statt nur Standbilder.

## Screenshots und Bewegung
`/tmp/kernwerk-six-phases/`: `phase2-{normal,resonance,perfect}.png`, `phase3-overload-{1,2,3}.png`, `phase4-zone-{1..5}.png`, `phase5-platform-variants.png`, `phase6-game-over.png`, `variants/kerbe-*.png` sowie `motion-resonanzsprung.mp4` (126 Frames, echte Landungen inklusive Overload-Entladung bei 3/3).

## Verbleibende Punkte
- **iPhone-Abnahme offen.** Auf dem Gerät zu beurteilen: Kerben-Lesbarkeit bei 430×932, Stärke des Kameraimpulses, Wirkung der Ringe in Bewegung.
- Rohnframes und überholte Entwurfsversionen wurden auf ausdrückliche Anweisung entfernt (Backup unter `~/data/kernwerk-untracked-backup-20260912.tar.gz`); freigegebene Referenzen und der pausierte Plush-Jump-Stand blieben unberührt.
