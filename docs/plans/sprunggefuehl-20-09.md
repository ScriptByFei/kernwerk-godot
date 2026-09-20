# Sprunggefühl: weicher und länger (20.09.2026)

## Taskvertrag
- Auslöser: Timo, 20.09.2026: „es soll sich besser anfühlen wenn man springt, soll
  mehr Tempo aufbauen aber es soll nicht so starke Gravitation geben".
- Erlaubt: `scripts/jump/jump_config.gd`, `tests/gameplay_director_test.gd`,
  `tools/jump_feel_mutation_probe.sh` (neu), dieser Plan.
- Nichtziele: keine Änderung an Plattformbreiten, Patterns, Direktor-Regeln,
  Resonanzregeln, Kamera, Optik oder Klang. Kein Refactor.
- Gewählte Richtung: **B** aus vier gerechneten Varianten (Gravitation −15 %,
  Scheitel sinkt leicht).

## Der Zielkonflikt, offen benannt

„Mehr Tempo" und „weniger Gravitation" sind zwei verschiedene Hebel, und sie
widersprechen sich, solange die Flugzeit das Tempo trägt:

```
Scheitel  h = v²/(2g)     Flugzeit  t = 2v/g
```

- Schneller = kürzere Flugzeit verlangt **höhere** Gravitation (oder kürzere
  Strecke). Ein weicherer Bogen ist zwangsläufig ein längerer Bogen.
- „Tempo aufbauen" liegt deshalb **nicht** in der Grundphysik, sondern in den
  Ladungsstufen (`RESONANCE_PACE_FACTORS`) — die wachsen über einen Lauf von
  0/3 bis 2/3 und sind der Aufbau, den Timo beschreibt.

Umsetzung: die **Basis** (0/3) ist der Ruhezustand und wird weicher; die
Spreizung nach oben bleibt der Tempoaufbau.

## Änderung

| | vorher | jetzt |
|---|---|---|
| `GRAVITY` | 3887 | **3304** (−15 %) |
| `BASE_BOUNCE_SPEED` | 2054 | **1906** (−7,2 %) |

Gemeinsam gewählt, nicht einzeln: die Kraft ist so bemessen, dass der Scheitel
**sinkt** statt zu steigen (ein weicherer Bogen ohne kürzere Kraft wäre ein
höherer Sprung — und damit eine Änderung der Route).

## Gemessen am echten Springer (60 Hz, `qa/loop_feel_probe.gd`)

| Stufe | Flug vorher | Flug jetzt | Scheitel vorher | Scheitel jetzt |
|---|---|---|---|---|
| 0/3 | 0,983 s | **1,083 s** | 527,6 px | 535,9 px |
| 1/3 | 0,850 s | **0,933 s** | 525,2 px | 533,5 px |
| 2/3 | 0,700 s | **0,767 s** | 521,8 px | 530,3 px |
| Overload | 0,650 s | 0,650 s | 733,8 px | 733,8 px |

Der ruhige Sprung ist **10 % länger** und der Scheitel steigt um 8 px (1,6 %).

**Ehrlich zur eigenen Tabelle:** die vier zur Auswahl gestellten Varianten waren
aus der Formel gerechnet (`v²/2g`), nicht aus der Engine. Die Formel liegt rund
2,5 % unter der echten Bahn (550 gegen 536 px gemessen) und unterschätzt die
Flugzeit um ~12 % (0,87 gegen 0,98 s). Die **Richtung** der Wahl war damit
richtig, die Absolutwerte nicht — sie stehen hier aus der Engine, nicht aus dem
Modell.

## Prüfungen

- `tests/gameplay_director_test.gd`: **53 Checks, 0 Fehler** (vorher 51).
- Gate: **PASS: import, 29 Suiten, main-scene smoke, Webexport**, PCK 3.817.968 B.
- Echte Eingabepipeline 430×932 (`qa/pause_real_input_probe.gd`): **ALLE OK**.
- Fahrer-Probe (`qa/mobile_core_loop_probe.gd`, 430×932): `died=false`,
  40 Landungen, Höhe 1440 px, **Overloads 12** (vorher im selben Lauf 0 gemessen),
  60,6 Physik-Schritte/s, Median 24,0 ms/Frame.
- Mutationsprobe `tools/jump_feel_mutation_probe.sh`: **3 von 3 erkannt**.
  M1 nur Kraft −8 % → Flug kürzer (Suite bleibt grün, nur die Gefühlsmessung
  sieht es). M2 nur Gravitation −12 % → Reserve wächst auf +255 px (Suite bleibt
  grün). M3 alte Gravitation mit weicher Kraft → Suite rot.

## Neuer Test: Obergrenze für die Reserve

Die Suite prüfte bisher nur die **untere** Schranke (Scheitel > weiteste Sprosse).
Damit kann ein weicherer Bogen unbemerkt jeden Sprung höher machen — die Reserve
wächst mit und die Prüfung bleibt grün. Neu:

- Reserve ≤ Hälfte des weitesten Abstands (Absicht: darüber wird der Sprung
  schwebend und die Route verliert Spannung).
- Reserve ≥ 100 px (muss nutzbar bleiben, nicht nur formal positiv).

**Erste Fassung war falsch kalibriert:** der Deckel war aus dem Modellwert
abgeleitet (536 px) und schlug bei der echten Zahl (550 px) an. Eine aus dem
Ist-Wert abgeleitete Pixelzahl ist kein Kriterium — die Schranke ist jetzt ein
Verhältnis zur Absicht. Dieselbe Falle wie schon einmal beim Splash-Werkzeug.

## Eigener Fehler, festgehalten
Der Deckel-Test schlug im ersten Lauf an und ich habe ihn zunächst als
Werkzeugfehler gelesen. Er hatte recht: die echte Bahn liegt über der Formel.
Der zweite Anlauf formuliert die Schranke als Verhältnis statt als Pixelzahl.

## Offen
- **iPhone-Abnahme.** Auf dem Gerät zu beurteilen: ob der längere Bogen sich
  besser anfühlt und ob 0/3 nach einem Overload-Rückschlag noch trägt.
- Nicht committet, nicht gepusht.
