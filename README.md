# Kernwerk: Resonanzsprung

**Godot 4 · Web · Mobile-first Portrait**

Ein vertikaler Endless-Jumper in einem industriellen Reaktorschacht. Der
Reaktor-Kern springt beim Landen automatisch ab; ein horizontaler Drag steuert
ihn im Flug. Präzise Landungen laden Resonanz auf — drei Ladungen machen den
nächsten Absprung zum Overload.

▶ **Live:** https://scriptbyfei.github.io/kernwerk-godot/

*(Lokaler Dev-Preview: `https://masga-server.tail1bf259.ts.net`)*

Der frühere 3-Lane-Auto-Shooter ist als Git-Tag `archive/auto-shooter-phase12`
gesichert und **nicht** mehr Teil des Projekts. Sein Laufzeitcode wurde in
`20cf215` entfernt; die Git-Historie bewahrt ihn vollständig.

## Kernschleife

- **Ein Daumen.** Ziehen steuert horizontal, der Absprung passiert von selbst.
- **Kein Stillstand ohne Geste.** Vor dem ersten Tap bewegt sich nichts. Derselbe
  Tap entsperrt auch das Web-Audio — Browser erlauben Ton erst nach einer Eingabe.
- **Höhe ist der Score.** Es gibt keine Gegner: der Schacht selbst ist die
  Herausforderung, und die Fallkante unter der Kamera ist der einzige Verlust.
- **Der Lauf endet bewusst nicht von selbst.** Nach dem Absturz entscheidet der
  Spieler, ob er neu startet. Ein automatischer Neustart würde den erreichten
  Score im selben Moment überschreiben — bei einem Endless-Spiel ist „wie hoch
  bin ich gekommen?" aber genau die Frage, die den Wiedereinstieg trägt.

## Landezonen und Resonanz

Eine Plattform hat drei Zonen. Gemessen wird der Abstand vom Mittelpunkt als
Anteil der **vollen** Plattformbreite (nicht der halben):

- **PERFECT** — bis ±24 % → +1 Ladung, danach der stärkste Absprung
- **RESONANCE** — bis ±38 % → +1 Ladung
- **NORMAL** — außen → löscht alle Ladungen

Jede RESONANCE- oder PERFECT-Landung lädt eine Ladung auf, maximal drei. Bei
3/3 ist **OVERLOAD** scharf: der nächste Absprung nutzt die höhere
Absprunggeschwindigkeit, danach steht die Resonanz wieder auf 0.

Die PERFECT-Markierung auf der Plattform zeichnet exakt dieselbe Breite wie die
Trefferzone (`perfect_band_width`). Beides liest dieselbe Konstante, damit der
Spieler nicht auf eine Fläche zielt, die nicht der Belohnung entspricht.

## Steuerung

- **Touch (Produktion):** horizontaler Drag. Der Kern steuert einem Fingerziel
  nach; konstante Autorität über den gesamten Bogen, also keine verlorene
  Kontrolle im späten Sinkflug.
- **Tastatur (Dev):** A/← und D/→ für links/rechts.

Alle Werte stehen in `scripts/jump/jump_config.gd` — Schwerkraft,
Absprunggeschwindigkeiten, Landefenster, Score-Faktoren. Das ist die einzige
Quelle für Physik-, Kamera-, Generator- und UI-Konstanten.

## Bestwert

Der Bestwert überlebt ein Neuladen der Seite:

- **Web:** `localStorage` über `JavaScriptBridge`. Bewusst **nicht** `user://` —
  Godot legt das im Browser erst bei einem `FS.syncfs()` in die IndexedDB, und
  die Engine führt das nicht zuverlässig vor dem Schließen des Tabs aus. Ein
  Bestwert entsteht aber genau dann, wenn der Spieler aufhört. Beide Zugriffe
  liegen in `try/catch`: ein privater Tab kostet den Bestwert, nie das Spiel.
- **Desktop:** `ConfigFile` unter `user://`.

Ein geladener Wert zählt als vorheriger Bestwert, sonst erschiene „NEUER
BESTWERT" beim ersten Lauf jedes Besuchs.

## Architektur

Die Szene ist absichtlich leer. `scenes/game/game.tscn` enthält nur den
Wurzelknoten; Welt, Kamera, HUD, Plattformen und Menüs baut `game.gd` zur
Laufzeit auf.

```
scenes/game/game.tscn         Wurzel (Node2D) + game.gd
scripts/
  game/game.gd                Verkabelung, Zustandsmaschine, Score, Menü-Aufbau
  jump/
    jump_config.gd            ALLE Konstanten (Tune hier!)
    jumper.gd                 CharacterBody2D: Steuerung, Gravitation, Landung,
                              Absprung und Overload-Impuls
    platform.gd               Plattformzustand, Sockelgeometrie, landed-Signal
    platform_director.gd      seedbare Plattformfolge, sichere Route, Recycling
    vertical_camera.gd        Aufwärts-Kamera und Todesgrenze
    resonance_system.gd       reine Zustandslogik: Landequalität, 0–3 Ladungen
    run_record.gd             Bestwert des Laufs (RefCounted)
    best_score_store.gd       dauerhafte Speicherung (Web/Desktop)
  ui/
    start_menu.gd             Startbildschirm
    pause_button.gd           Pausentaste im Spiel
    pause_menu.gd             WEITER / NEU STARTEN
    game_over_menu.gd         Ergebnis, Bestwert, NEUER BESTWERT
    resonance_hud.gd          Score und drei Ladungssegmente (CanvasLayer)
```

**Warum `resonance_system.gd` getrennt ist:** reine Zustandslogik, kein Node und
kein Rendering. Damit ist die Kernmechanik headless testbar, und es gibt genau
eine Verbuchungsstelle (`game._register_resonance`) statt mehrerer, die
auseinanderlaufen können.

**Warum das HUD ein `CanvasLayer` ist:** im Weltraum via `_draw()` gezeichneter
Text wird von Plattformen überdeckt — im QA-Bild schnitt eine Plattform den
Score an. Als Overlay bleibt er immer lesbar.

## Tests

```bash
python3 tools/verify_project.py                      # volles Gate
godot4 --headless --audio-driver Dummy --path . -s tests/<suite>_test.gd
```

Das Gate prüft Projektimport, alle Suiten, einen Smoke-Test der Hauptszene und
einen Web-Export in ein temporäres Verzeichnis. Es deployt nicht.

Aktuelle Suiten (12):

`best_score_test` · `core_polish_test` · `game_over_test` · `gameplay_loop_test` ·
`jump_physics_test` · `pause_menu_test` · `platform_director_test` ·
`reactor_bounce_anim_test` · `reactor_visual_test` · `resonance_chain_test` ·
`standby_polish_test` · `start_transition_test`

Der alte Shooter-Bestand liegt in `tests/legacy_auto_shooter/` und läuft bewusst
nicht im Gate mit.

**Rendering-Prüfungen gehören nach `qa/`, nicht in den headless-Suiten-Glob.**
Dort liegen unter anderem:

- `qa/pause_real_input_probe.gd` — fährt den Pausenzyklus mit **echter**
  Eingabezustellung bei 430×932. Bei jeder UI-Änderung mitlaufen lassen: die
  Headless-Suite deckt diese Fehlerklasse nicht ab.
- `qa/score_persistence_probe.gd` — dauerhafter Bestwert mit echtem Fenster.
- `qa/web_save_probe.gd` + `tools/web_save_probe.sh` — Web-Speicherzweig in
  einem echten Export und echten Browser.

### Zwei Fallen, die Zeit gekostet haben

**Eingabe-Tests müssen den echten Weg fahren.** Ereignisse per
`Input.parse_input_event()` einspeisen, nie Handler direkt aufrufen — sonst
bleiben Viewport-Traversierung, GUI-Verbrauch und Pause-Filterung ungeprüft,
und genau dort lag ein echter Fehler. Mit echtem Fenster testen: headless hat
nur ein 64×64-Fenster, dort sind synthetische Taps wertlos.

**Tests und QA dürfen den echten Spielstand nicht anfassen.** Über zwanzig
Stellen erzeugen echte `Game`-Instanzen, und QA-Proben laufen mit Fenster. Die
Unterscheidung ist der Skript-Parameter `-s`, nicht „headless" — eine
QA-Probe mit Fenster hätte den echten Bestwert sonst überschrieben.

## Deployment

Push auf `main` → Headless-Suiten + Smoke-Test → Web-Export → Publish auf
`gh-pages`. Es gibt nur diesen CI-Weg.

`export_filter="all_resources"` packt **jede** Ressource im Projekt, nicht nur
die erreichbare. `exclude_filter` hält `addons/`, `docs/`, `tests/`, `qa/` und
die Artwork-Drafts draußen; im Paket bleiben davon nur Pfad-Tabelleneinträge
ohne Daten. Immer Bytes vergleichen, nicht Strings zählen.

Aktuelles Live-PCK: 3.821.084 B.

## Entwicklung

- **Ein Feature auf einmal.** Erst stabil, dann das nächste; Geräteabnahme
  zwischen den Phasen.
- **Kein ungefragtes Refactoring**, keine UI-Ergänzungen, keine
  Balancing-Änderungen.
- **Visuelle Änderungen** werden am gerenderten Bild bei Produktionsgröße gegen
  die freigegebenen Referenzen geprüft — nicht an Dateigrößen oder einem
  erfolgreichen Build.
- Design-Regeln: Portrait, One-Thumb, saubere UI, sanftes Feedback — **keine
  Labels wie „MISS"**.
- Performance: single-threaded WASM, `gl_compatibility` (CPU-Partikel, keine
  `GPUParticles2D`), kein COOP/COEP.
