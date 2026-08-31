# Godot-Spike — Ergebnisse (31.08.2026)

## Ergebnis: GO ✅

Alle drei Spike-Fragen beantwortet:

| Frage | Ergebnis | Schwelle | Status |
|---|---|---|---|
| Headless-Export auf RPi 5 (aarch64)? | `godot4 --headless --export-release` läuft | muss funktionieren | ✅ |
| Bundle-Größe gezippt? | **9,5 MB** (wasm 9,4 + js 0,08 + pck 0,002) | < 25 MB | ✅ |
| Läuft der Loop im Browser? | Spiel bootet, Canvas rendert, **FPS: 59** (headless, Software-WebGL!) | 60 FPS-Ziel | ✅ |

Beweis-Screenshot: `docs/spike-beweis.png` (grüner Dot + FPS-Label, Godot 4.6.3 stable, single-threaded WASM).

## Setup-Notizen (damit es reproduzierbar bleibt)

- Godot 4.6.2 (arm64) ist unter `/usr/local/bin/godot4` installiert.
- Export-Templates: nur Web-Release-Zips aus dem offiziellen 4.6.3-tpz entpackt nach
  `~/.local/share/godot/export_templates/4.6.2.stable/` (Godot akzeptiert 4.6.3-Templates für 4.6.2 beim Web-Export nicht offiziell, funktioniert hier aber — saubere Lösung wäre Godot auf 4.6.3 zu updaten).
- Projekt: 405×720 (9:16), stretch `canvas_items`, Renderer `gl_compatibility` (Pflicht für Web), Export-Variante **no-threads** (kein COOP/COEP-Header nötig → einfaches Hosting).
- Export-Befehl: `cd ~/projects/kernwerk-godot && godot4 --headless --export-release Web build/web/index.html` (build/web muss existieren).
- Serving: `python3 -m http.server 8080 --directory build/web` reicht (no-threads → keine Spezial-Header).

## Nächster Schritt (wenn beauftragt)

Vertical Slice M1 in Godot: Touch-Joystick + Dodge + Kamera, Portrait-Arena.
Dann M2–M5 portieren, ein Meilenstein pro Session. Balancing-Zahlen aus TS-README 1:1 übernehmen:
Split 12°, Pendel-Amp 22, Ricochet 3 Bounces, Tank-Drop 65 %.

## Offen

- iPhone-Realtest: `http://<pi-ip>:8080/index.html` im Safari öffnen (Server läuft derzeit noch).
- Godot-Binary ggf. auf 4.6.3 heben, damit Template-Version exakt passt.