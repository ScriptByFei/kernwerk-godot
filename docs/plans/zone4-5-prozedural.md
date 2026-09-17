# Zonen 4–5 prozedural (Zwischenstand)

## Taskvertrag
- Auslöser: Timo, 17.09.2026. Zonen 3–5 sollen gestaltete Hintergründe bekommen. Zone 3
  (Hochspannung) war als generierte Kachel geplant, der Bildgenerator ist aber bis
  19.09.2026 ca. 20:15 gesperrt (`Codex provider quota exhausted (429)`, Reset in
  160891 s). Entscheidung Timo: Zone 4 und 5 jetzt prozedural bauen, Zone 3 nach dem
  Reset als generierte Kachel nachziehen.
- Erlaubt: `scripts/jump/shaft_background.gd`, `scripts/game/game.gd`,
  `scripts/jump/jump_config.gd`, `tests/`, `qa/`, dieser Plan.
- Nichtziele: keine Refactors, keine Plattform-/Physik-/Resonanzänderung, keine
  Berührung von Zone 1 und 2, kein Ersatz der Zone-2-Kachel, keine Commits/Push.
- Referenz (read-only): `assets/jump/cooling_section/` als Formensprache-Vorbild.

## Fenster (Zonenindex)
Der Zonenindex ist bei 4.0 gedeckelt (`zone_index_at`), Zone 5 blendet also nie aus.
Die Fenster sind so gelegt, dass die noch fehlende Zone 3 später genau hineinpasst:

- Zone 1 Reaktorschacht: aus [0.00, 0.55]
- Zone 2 Kühlsektion: ein [0.00, 0.55], aus [1.55, 2.00]
- Zone 3 Hochspannung (offen): ein [1.55, 2.00], aus [2.55, 3.00]
- Zone 4 Instabile Zone: ein [2.55, 3.00], aus [3.55, 4.00]
- Zone 5 Kritische Zone: ein [3.55, 4.00], bleibt voll

Lücke bis zum Nachziehen von Zone 3: [1.55, 2.55] trägt nur die flache Zonenfarbe.
Das ist keine Regression (Zone 3 hatte noch keine Gestaltung), aber vor dem
Zone-3-Einbau bleibt ein sichtbarer strukturloser Abschnitt.

## Abnahmekriterien
1. Beide Schichten blenden stetig ein/aus; im Kreuzblendfenster [3.55, 4.00] ist die
   Summe der Deckkraft >= 0.99.
2. Ruhezone (Mitte ± QUIET_HALF_WIDTH) bleibt frei von gesetzter Einzelheit und
   dunkel; der Hintergrund wird nie heller als der Spieler.
3. Deterministisch: gleiche Weltkachelnummer ergibt gleiche Form, unabhängig von der
   Kamera (Modultyp aus dem Weltindex, nie aus `top`).
4. Zeichenspitze über den Kamera-Sweep bleibt unter der Obergrenze 700.
5. Mutationsprobe: Entfernen der Fenster-/Kreuzblendungslogik macht Tests rot.

## Status
- [x] Konstanten und Fenster
- [x] Zeichenroutinen
- [x] Verdrahtung in game.gd
- [x] Tests + Mutationsprobe
- [x] QA-Bilder 430x932
- [x] Gate + Kostensweep

## Ergebnis (verifiziert)
- `tests/higher_zones_test.gd`: **55 Checks, 0 Fehler**.
- Mutationsprobe `tools/higher_zones_mutation_probe.sh`: **10 von 10 erkannt**,
  0 blinde Stellen, Exit 0.
- Zeichenlast `qa/zone45_cost_sweep.gd`: Spitze **364 von 700** (52,0 %) bei
  Zonenindex 3.63; Gegenprobe abgeschaltet **0**.
  **Warum ein eigener Sweep:** `qa/door_cost_sweep.gd` zeichnet nur
  `ShaftBackground.draw` (Zone 1/2, Spitze 170). Zone 1 ist ab Index 1.0
  ausgeblendet, Zone 4 beginnt bei 2.55 — die beiden Lasten addieren sich nie,
  aber die neuen Schichten sind in der alten Messung gar nicht enthalten.
- Gate: `PASS: import, 26 Suiten, main-scene smoke, Webexport`, PCK 3.739.856 B.
- Echte Eingabepipeline bei 430×932 (`qa/pause_real_input_probe.gd`): `ALLE OK`.
- Bilder: `/tmp/kernwerk-zone45/` (Tafel: `tafel_zone45.png`).

## Zwei echte Farbfehler, per Test gefunden
- Gefahrenband der Zone 5 war als Flaeche zu hell (`4a3a1c`, Ratio **0.937**) —
  jetzt `1c160c`, Ratio 1.93.
- Zone-5-Platte `1c1a16` lag bei Ratio **1.734** — jetzt `171410`, Ratio 1.98.

## Eigene Fehler, festgehalten
1. **Erster Test behauptete eine falsche Fensterbeziehung.** Zone 5 muss
   einblenden, wo Zone 4 auszublenden BEGINNT (die Fenster spiegeln sich) — der
   Test verlangte die Endkante.
2. **Plattenverschiebung leitete ihre Identitaet aus der kameraverschoenen
   Zeichenkoordinate ab.** Genau die Falle, die im Projekt schon zweimal
   zugeschlagen hat. Auf den Weltindex `(n, row)` gezogen und als gemeinsame
   Quelle `zone4_cells()` fuer Zeichnung UND Pruefung verankert.
3. **Der Kontrast-Test war zu grob angesetzt.** Die harte 1.81-Regel schuetzt
   FLAECHEN in der Ruhezone; auf duenne Linien angewandt haette sie die seit
   jeher abgenommenen Randlaternen (d97b2a, Ratio 0.45) als Regelbruch
   gemeldet. Jetzt zwei getrennte Kategorien (`zone45_surfaces` /
   `zone45_accents`) — und die Akzentregel hat eine ausdrueckliche Gegenprobe,
   dass sie eine zu helle Farbe ueberhaupt erkennt.
4. **Die Mutationsprobe meldete zuerst falsch gruen (9 von 9).** Sie sicherte
   die Datei in EINE temporaere Datei und loeschte sie beim ersten `restore`;
   ab der zweiten Mutation schlug jedes Zurueckschreiben still fehl, die Datei
   blieb mutiert. Aufgefallen an der durchgehend identischen Fehlerzahl und an
   `cp: cannot stat` je Durchlauf. Jetzt: Sicherung in ein Verzeichnis,
   Muster-Gegenprobe je Ersetzung, und die Auswertung verlangt UNTERSCHIEDLICHE
   Fehlerzahlen statt nur "irgendwie rot".
5. **Die Probe endete trotz einwandfreiem Ergebnis mit `exit=1` ohne
   Urteilszeile**, weil sie >= 4 verschiedene Fehlerzahlen verlangte und nur 3
   auftraten. Ein Pruefskript, das weder Erfolg noch Fehler meldet, ist
   unbrauchbar; die Bedingung ist jetzt "keine blinde Stelle UND nicht ueberall
   dieselbe Zahl", und jeder Ausgang druckt ein Urteil.

## Zonenhoehen (Timo-Entscheidung, 17.09.2026)

Gemessen: ein idealisierter Ein-Daumen-Spieler kommt auf rund **50 px/s** (60 s →
2.952 px, 180 s → 8.998 px, 300 s → 15.017 px). Mit den alten 9.000 px je Zone
begann die Instabile Zone bei 22.950 px = **~7,6 min fehlerfreies Spiel** — die
Zonen 4/5 waren praktisch unerreichbar.

`ZONE_HEIGHT_SPANS = [8000, 4000, 4000, 4000, 4000]`, `ZONE_BLEND_RANGE` 3500 → 1200.

| Zone | Hoehe | erreichbar nach |
|---|---|---|
| 1 Reaktorschacht | 0 — 8.000 | 0 — 2,7 min |
| 2 Kuehlsektion | 8.000 — 12.000 | 2,7 — 4,0 min |
| 3 Hochspannung | 12.000 — 16.000 | 4,0 — 5,3 min |
| 4 Instabile Zone | 16.000 — 20.000 | 5,3 — 6,7 min |
| 5 Kritische Zone | 20.000 — 24.000 | 6,7 — 8,0 min |

**Zone 1 bleibt bewusst groesser — das ist gemessen, nicht Geschmack.** Die
Fernwand des Schachts laeuft mit Parallax 0.22, verschiebt sich im Fenster also
nur um 0.22 * Fensterhoehe. Ein 1.650 px hohes Fenster zeigt dauerhaft nur 3 der
4 Modultypen (Kachelsatz bleibt -2..1), ein 4.400 px hohes Fenster alle 4. Eine
gleichmaessige Stauchung haette eine gestaltete Wandart aus der praegendsten Zone
entfernt. Als Regel in `tests/shaft_composition_test.gd` verankert.

## Umbau von `zone_index_at` (ungleiche Zonen)

Die Zonen sind nicht mehr gleich hoch, deshalb rechnet die Funktion nicht mehr mit
einer festen Schrittweite, sondern sucht die Zone und rechnet INNERHALB ihrer
eigenen Hoehe. Neu dazu:

- `zone_floor(zone)` / `zone_total_height()` — Unterkanten und Gesamthoehe, aus
  den Spans abgeleitet, damit beide Darstellungen nicht auseinanderlaufen.
- `zone_extent_at(height)` — Unterkante + Hoehe der Zone an dieser Hoehe.
- `zone_height_for_index(index)` — die **Umkehrfunktion**. Proben fahren damit eine
  gewuenschte Zone exakt an, statt Pixelzahlen zu raten, die nur zufaellig stimmen.

**Echter Fehler, per Test gefunden:** Die letzte Zone rechnete einen Uebergang,
obwohl sie keinen Nachfolger hat. Der Index lief auf **4,13** hoch (bei 22.957 px)
und fiel bei 24.000 px auf 4,0 zurueck — also rueckwaerts. Behoben: in der letzten
Zone gibt es keinen Uebergang.

## Verifiziert

- Fuenf Zonen-Suiten gruen: `height_zone_test` 28/0, `higher_zones_test` 55/0,
  `shaft_background_test` 89/0, `shaft_composition_test` 28.833/0,
  `shaft_background_geometry_test` 255/0.
- Gate: **exit=0, 26 Suiten**, PCK 3.741.072 B.
- Zeichenlast `qa/zone45_cost_sweep.gd`: Spitze **362 von 700** (51,7 %),
  Gegenprobe abgeschaltet 0.
- Echte Eingabepipeline 430×932: `ALLE OK`.
- Echter Lauf erreicht 15.016 px in 5 min → Zone 4 bei ~5,3 min (wie zugesagt).
- Mutationsprobe `tools/zone_spans_mutation_probe.sh`: **5 von 5 erkannt**, 0 blind,
  Datei per SHA256 unveraendert.

## Zwei blinde Stellen der Mutationsprobe (wertvoll)

1. **Sie fuhr `shaft_composition_test` gar nicht mit.** Dadurch blieb die
   gleichmaessige Stauchung von Zone 1 unbemerkt — genau der Gestaltungsverlust.
   Suite ergaenzt UND die Fernwand-Regel als eigener Test verankert, damit sie
   nicht nur als Nebenprodukt einer Pixelabtastung auffaellt.
2. **Eine Mutation war verhaltensneutral:** der Deckel-Check, den sie verschob,
   existierte nach dem Umbau nicht mehr und war ohnehin wirkungslos (die letzte
   Zone bildet selbst den Deckel). Toten Code entfernt, M5 prueft jetzt echtes
   Verhalten.

Beides waere ohne die Probe durchgegangen: eine gruene Suite haette den Verlust
einer Wandart und einen rueckwaerts laufenden Zonenindex nicht gemeldet.

## Tests und Proben aus der Konfiguration ableiten

Wiederholt aufgetretene Fehlerklasse in dieser Sitzung: **fest eingetragene
Pixelzahlen**. `tests/shaft_composition_test.gd` hatte `0/1800/4500` px, abgeleitet
aus der Zeit mit 9.000er Zonen; nach der Stauchung lagen zwei davon ausserhalb des
Fensters. `tests/height_zone_test.gd` sampelte ueber `4.0 * ZONE_HEIGHT_STEP`
(32.000) bei 24.000 px Gesamthoehe und erreichte Zone 5 nicht mehr. Beide rechnen
jetzt gegen `zone_total_height()` bzw. die Spans.

- **iPhone-Abnahme offen.** Auf dem Geraet zu beurteilen: Lesbarkeit der
  Plattenverschiebung, Wirkung des Gefahrenbands und des Notlichts in Bewegung.
- **Zone 3 (Hochspannung) fehlt.** Auftrag liegt fertig in
  `/tmp/kernwerk-zone3/auftrag_zone3_hochspannung.txt`; der Bildgenerator ist
  bis 19.09.2026 ca. 20:15 gesperrt (`Codex provider quota exhausted (429)`).
  Die Luecke `[1.55, 2.55]` ist freigehalten und im Test festgehalten, damit der
  Einbau nichts umbauen muss.
- Nicht deployt: kein Commit, kein Push, keine iPhone-Abnahme behauptet.
