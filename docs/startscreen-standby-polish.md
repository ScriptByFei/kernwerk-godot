# KERNWERK — Startscreen Standby Polish

## Ergebnis

PROTOTYPE-READY: implementiert, real gerendert und technisch geprüft. Visuelle Freigabe durch Timo und iPhone-Abnahme stehen aus. Keine neue Artwork-Generierung, keine Änderungen an Produktions- oder Referenzbildern. Kein Commit, Push, Deployment oder Dienst-/Profil-/Projektkonfigurationswechsel.

Basis: `a19f286794b247090a3a17a0c9b74a26e5d1ce73`; HEAD blieb unverändert.

## Vorher: konkrete Schwächen aus tatsächlicher Bildinspektion

Die fünf `before_*`-Viewport-Screenshots wurden vor dem ersten Runtime-Edit mit Godot 4.6.2 / GL Compatibility / Mesa llvmpipe gerendert und mit `vision_analyze` betrachtet.

- 70 % deckende Kammerüberlagerung plus dunkler Jumper-Tint verschluckten den orangefarbenen Kern und die cyanfarbene Ringkontur. Der echte spielbare Reaktor wirkte wie ein kleines dunkles Symbol.
- Die geschlossene CTA-Platte mit Rundungen, kräftigem unteren Rand und fast opakem Hintergrund las sich als mobile App-Schaltfläche.
- Die CTA bei 82 % Bildschirmhöhe war vom Reaktor durch viel Leerraum getrennt. Der große Titelblock konkurrierte mit dem Weltmotiv; Plattformen berührten seine Umgebung.
- Das bestehende UI atmete über Button-Skalierung; Tap verkleinerte die CTA. Das passt nicht zum geforderten elektrischen Standby-Charakter.
- Querformat ist schon in der unveränderten Projektkonfiguration eine zentrierte Portrait-Spielfläche mit schwarzen Seitenbalken. Die ursprüngliche CTA-Schrift schrumpfte dort sehr klein.

Gelesen: AGENTS.md, aktiver `pixel-builder-production`-Skill, `pixel-art`, Startmenü/Game/Jumper-Code, Transition-Tests, Export-/Gate-Konfiguration und Reactor-Idle-Freigabe. Visuell geprüft: freigegebene Reactor-Basisreferenz, bestehende Kammergrafik und Start-Button-Produktionsasset. Der Button enthält fest eingebranntes `START`; seine Wiederverwendung würde die exakte CTA duplizieren bzw. verfälschen. Er blieb daher unverändert und unbenutzt wie zuvor. Die vorhandene Kammergrafik bleibt auf ihren oberen, reaktorfreien Ausschnitt beschränkt: kein zweiter gemalter Reaktor im Übergang.

## Umsetzung

- `KERNWERK` bleibt primär, aber kleiner und weiter oben; `RESONANZSPRUNG` kleiner und deutlich zurückgenommen.
- Exakte CTA `REAKTOR STARTEN`; transparenterer flacher Untergrund, keine Seitenränder/Rundungen, zwei dünne horizontale technische Linien. Linien werden anhand des tatsächlichen Stretch-Faktors auf mindestens einen physischen Pixel dimensioniert.
- CTA bei 66 % Höhe statt 82 %, mindestens 44 px hoch. Mindestschriftgrößen verhindern mikroskopische Querformat-Schrift: Titel 22 px, CTA 12 px, sekundärer Untertitel 9 px. Das ist Darstellungsgeometrie, kein neuer Button-/Inputpfad: der bestehende Ganzbild-Tap bleibt unverändert.
- Kammer-Alpha 0,70 → 0,32. Einzige Game-Änderung: anfänglicher Jumper-Tint `(0.72, 0.76, 0.80)` → `(0.92, 0.94, 0.96)`. Keine Sprite-Vergrößerung, kein Positions-/Pivotwechsel.
- Zwei laufende Standby-Effekte: vorhandene freigegebene Reaktor-Idle-Animation und vorhandener, nun ausschließlich auf Kammer-Helligkeit beschränkter langsamer Tween. Keine neuen Texturen, Shader, Partikel, Postprocessing oder Effektnodes.
- Sofortiges, dezentes CTA-Helligkeitsfeedback bei Tap, keine Scale-Punch-Animation. Bestehende Feedbackdauer bleibt erhalten.
- Kammer-Idle-Tween endet sofort bei Tap; vorhandene Start-Timeline übernimmt. Nach PLAYING ist die Menühülle entfernt und der Reaktortint weiß. Beim Restart wird Standby wiederhergestellt.
- Resize-Randfall behoben: Godot kann `size_changed` vor finalem Stretch-Transform und aktualisierten Label-Minimum-Caches melden. Ein deferred Layout-Abgleich und Label-Reset erlauben korrektes Schrumpfen nach Größenwechseln. Keine kontinuierliche Layout-Polling-Schleife.

Die vollständige Datei `scripts/game/game.gd` wurde programmgesteuert mit HEAD verglichen: exakt die genannte Farbzeile ist anders. START_MENU → STARTING → PLAYING, Tween-Choreografie/-Dauern, Kameraübergabe, erster Bounce, Input-Gating, Physik, Plattformen, Score, Tod und Restart-Logik bleiben unverändert.

## Tatsächliche Nachher-Sichtprüfung

Alle fünf `after_verified_*_window.png` wurden in `vision_analyze` betrachtet, zusätzlich Tap, 0,40-s-Übergang und PLAYING. Der Kern ist als orange Energiequelle mit Ring/Sensor/Federfuß erkennbar, ohne veränderte Silhouette oder Doppelbild. Die CTA liest sich als ruhige technische Beschriftung zwischen Haarlinien statt als umrandeter App-Button. Keine abgeschnittenen Titel oder CTA-Texte in den geprüften Größen. Keine UI-Skalierung. Im Übergang verschwinden sekundäre Elemente zuerst, in PLAYING ist die gesamte Menühülle weg.

Bewusst erhalten: Der Reaktor bleibt in seiner genehmigten Spielgröße klein; die Welt bleibt dunkel und relativ sparsam. Es wurde kein großes Hero-Artwork vorgetäuscht. Schwarze Querformat-Seitenbalken bleiben unverändert. Das ist keine neue Full-Landscape-Komposition. Die kleine, dunkle sekundäre Beschriftung und Umgebungsdetails müssen auf einem echten Telefon bei niedriger Displayhelligkeit geprüft werden.

## Responsive-Evidenz

Dateiverzeichnis: `docs/assets/screenshots/standby_polish/`

| Angefordertes Fenster | Tatsächliches Spielraster | CTA B×H in px | Endgültiger tatsächlicher Fensterscreenshot |
|---|---|---|---|
| 320×568 | 319×568 | 171,31×44,00 | `after_verified_320x568_window.png` |
| 390×844 | 390×844 | 209,44×44,00 | `after_verified_390x844_window.png` |
| 430×932 | 430×932 | 230,93×44,59 | `after_verified_430x932_window.png` |
| 1280×720 | 405×720 | 217,50×44,00 | `after_verified_1280x720_window.png` |
| 844×390 | 219×390 | 117,61×44,00 | `after_verified_844x390_window.png` |

`after_verified_geometry.json` enthält die tatsächlichen logischen Rechtecke und Text-Minimumgrößen; `delivery_audit.json` prüft exakt fünf geforderte Fenstergrößen und die tatsächlichen PNG-Abmessungen, nicht nur angeforderte Werte. CTA-Koordinaten dort sind relativ zum Spielraster, nicht inklusive Seitenbalken. Die 319-px-Rasterbreite bei 320 px ist Godots bestehende Stretch-Rundung; der Fensterscreenshot ist tatsächlich 320×568.

Vorher: `before_320x568.png`, `before_390x844.png`, `before_430x932.png`, `before_1280x720.png`, `before_844x390.png`. Diese zeigen reale Viewport-Texturen ohne Seitenbalken, nicht künstlich rekonstruierte Fensterscreenshots.

Transition: `before_390_tap.png`, `before_390_transition040.png`, `before_390_playing.png` sowie `after_verified_390_tap.png`, `after_verified_390_transition040.png`, `after_verified_390_playing.png`.

`after_v1`, `after_v2`, `after_v3` sind bewusst erhaltene Iterationsbelege, nicht die endgültige Evidenz. Frühe X11-Fenstercaptures konnten bei 430×932 am virtuellen Desktop-Rand beschnitten werden. Der Capture-Runner positioniert das Fenster jetzt explizit bei (0,0); alle `after_verified_*_window.png` besitzen die exakten angeforderten Fenstermaße.

## Checks und echte Ergebnisse

1. `godot4 --headless --audio-driver Dummy --path . -s tests/standby_polish_test.gd`
   - 90 Checks, 0 Fehler.
   - Exakte Texte, Overlay-Alpha, unbewegte UI im Idle, begrenzte Kammerhelligkeit, alle fünf Größen, echte Text-Minimumgrößen, Mindest-CTA-Höhe/-Schrift, screen-fixed Verhalten, Effektende bei Tap/PLAYING und Wiederherstellung nach Restart.
2. `godot4 --headless --audio-driver Dummy --path . -s tests/start_transition_test.gd`
   - 2.184 Checks, 0 Fehler.
   - Maus und Touch bei 30/60/120 FPS; Übergabe bei 0,9333 / 0,9333 / 0,9250 s, jeweils genau ein Bounce, Overlay-Alpha bei Entfernung 0,0.
   - Einzige erforderliche Änderung im bestehenden Test: alte visuelle Erwartung `scale.x < 1.0` durch stärkere Forderung `scale == Vector2.ONE` UND sofortige Helligkeit > 1 ersetzt. Keine Transition-/Gating-Assertions entfernt oder abgeschwächt. Dies ist die einzige zusätzliche bestehende Testdatei außerhalb der Runtime-Dateien.
3. Vollständiger Gate:
   `env XDG_DATA_HOME=/home/masgi_bot/.local/share python3 qa/standby_polish_verify.py evidence_excluded`
   - Runner führt tatsächlich `python3 tools/verify_project.py` aus.
   - PASS: Projektimport, 7 aktuelle Testsuiten, Main-Scene-Smoke, Web-Release-Export.
   - Log: `full_gate_standby_evidence_excluded.log`.
   - Erster Lauf ohne Prozess-Umgebungsvariable scheiterte nur beim Export, weil der isolierte CLI-HOME keine Templates enthielt; unverfälschtes Fehlerlog `full_gate_standby.log`. Passende vorhandene Templates unter `/home/masgi_bot/.local/share/godot/export_templates/4.6.2.stable/` wurden anschließend verwendet. Keine Installation und keine persistente Konfigurationsänderung.
4. Rendering:
   `xvfb-run -a -s '-screen 0 1400x1100x24' godot4 --audio-driver Dummy --path . -s qa/standby_polish_capture.gd -- after_verified`
   - Exit 0; echte Godot-Raster plus ImageMagick-X11-Fenstercaptures, native Auflösung, keine nachträgliche Bildskalierung.
5. `python3 qa/standby_polish_audit.py`
   - 1.145 vorhandene untracked/dirty Dateien per SHA-256 unverändert.
   - `game.gd` nur erlaubte initiale Farbzeile geändert.
   - Exakt fünf tatsächliche Fenstergrößen bestätigt.
   - Evidenzordner im Web-Export nicht enthalten.
6. `git diff --check`: Exit 0. HEAD unverändert. Lokaler Godot 4.6.2, kein behaupteter CI-Lauf (CI laut Vertrag 4.6.3).

Die Evidenz erhält `.gdignore`: neue Screenshots werden nicht als Spielressourcen importiert/exportiert. Das wurde anhand des Exportlogs geprüft. Keine neuen Runtime-Artwork-Ladevorgänge. Es wird kein gemessener Performancegewinn behauptet.

## Erhaltung und geänderte Dateien

Vor Arbeitsbeginn war `docs/assets/screenshots/jump_phase1.png` bereits dirty. Die ursprünglichen Bytes sind weiterhin erhalten; SHA-256 `b78624f9f5b8c6db6fd206c2f2cd568b706d28aadf9ce53401811eed1a74eba1`. Der Verify-Runner sichert/restauriert diese Datei in `finally`. Das vorhandene Git-Diff dieser PNG stammt NICHT von dieser Aufgabe. Alle vorgefundenen untracked Assets, Referenzen, QA-Dateien und Screenshots wurden über ein Anfangsmanifest geprüft und blieben bytegleich.

Bestehende Dateien geändert:
- `scripts/ui/start_menu.gd`
- `scripts/game/game.gd` — eine visuelle Farbzeile
- `tests/start_transition_test.gd` — eine visuelle Feedback-Assertion

Neue Dateien:
- `tests/standby_polish_test.gd` und Godot-UID
- `qa/standby_polish_capture.gd` und Godot-UID
- `qa/standby_polish_verify.py`
- `qa/standby_polish_audit.py`
- `docs/startscreen-standby-polish.md`
- `docs/assets/screenshots/standby_polish/`: `.gdignore`, Vorher/Nachher-/Iterations-PNGs, Geometry-JSON, Audit-JSON, Export-Hashes und echte Prüf-/Exportlogs; ggf. vor `.gdignore` erzeugte Import-Sidecars gehören nur zu diesen neuen Belegen.

Das Erhaltungsmanifest liegt für diese Session unter `/tmp/kernwerk-standby-original-manifest.json`, die Original-PNG-Sicherung unter `/tmp/kernwerk-standby-jump-phase1-original.png`. Der Audit-Runner benötigt dieses Anfangsmanifest; es wird nicht nachträglich aus dem Endzustand rekonstruiert.

## Unabhängige Orchestrator-Prüfung

- Vollständigen `python3 tools/verify_project.py` erneut ausgeführt: Import, 7 Suiten, 90 Standby-Checks, 2.184 Transition-Checks, Smoke und Webexport erfolgreich. Log: `/home/masgi_bot/data/tasks/kernwerk-standby-parent-gate.log`.
- Tatsächlicher Chromium-Webexport über CDP bei 320×568, 390×844, 430×932, 1280×720 und 844×390 gestartet und per Touch aktiviert. Alle fünf Canvas-Größen entsprachen dem Browserfenster, keine JavaScript-/Console-Fehler. Screenshots vor/nach Tap und Resultate: `/home/masgi_bot/data/tasks/standby-browser/`. Bildänderung allein ist kein State-Beweis; die State-/Gating-Belege liefert zusätzlich die Transition-Suite.
- 1.145 bestehende Dateien sowie alle Produktions-Reaktorassets erneut per SHA-256 geprüft: unverändert. `game.gd` entspricht HEAD exakt bis auf den initialen Farbtint.
- Private mobile Vorschau: `https://masga-server.tail1bf259.ts.net:5173/` (Tailscale erforderlich). HTTP-Server lauscht ausschließlich auf `127.0.0.1:5173`; HTTPS-Serve-Route ergänzt, vorhandene WebUI-Route :8787 unverändert. HTTPS-PCK heruntergeladen und SHA-256 gegen das geprüfte Exportartefakt bestätigt. Kein GitHub-Push/öffentlicher Deploy.
- `qa/standby_polish_audit.py` ist ein einmaliger Evidenzschreiber und verweigert einen erneuten Lauf bei vorhandenem `delivery_audit.json`; die unabhängige Wiederholungsprüfung erfolgte deshalb ohne Überschreiben dieser Evidenz.

## Web-Artefakt und Übergabe

Bereit für den Orchestrator zum lokalen Servieren: `/tmp/kernwerk-standby-web/index.html`.
Kein fremder Preview-Dienst wurde verändert, kein neuer dauerhafter Server gestartet und kein öffentlicher Deploy ausgeführt. Der geforderte Export-Fallback wurde genutzt.

Aktuelle Hauptartefakte: HTML 5.441 Bytes, JS 315.759 Bytes, WASM 37.700.666 Bytes, PCK 10.087.340 Bytes. Exakte SHA-256-Werte in `web_artifacts_evidence_excluded.json`, Exportlog `web_export_standby_evidence_excluded.log`. Der frühere Export vor Evidenzausschluss wurde separat unter `/tmp/kernwerk-standby-web-pre-evidence-exclusion/` erhalten und ist NICHT der auszuliefernde Stand.

Offen: echter iPhone/Safari-Weblauf, Touchgefühl und Erreichbarkeit mit Browserleisten/Safe Areas, Rotation und Gerätetextschärfe, OLED-/Niedrighelligkeitskontrast, Ladezeit und Hardware-Frametiming. Native llvmpipe-Renderprüfungen sind kein Telefon-Performance-Test. Ein bestehender Score-/Plattformkontakt im unmittelbar eingefrorenen PLAYING-Bild gehört zur unveränderten Spielszene und wurde nicht im Rahmen dieser Menüaufgabe umgebaut. Visuelle Endfreigabe ausdrücklich bei Timo.

## Finale Korrektur (nach unabhängigem Review)

Session `20260908_202150_5992c7` implementierte den funktionierenden Standby-Polish. Der unabhängige Review `kernwerk-standby-final-review.log` fand keine Regression, aber zwei unvollständige Designziele: Titel heller/auffälliger als der kleine echte Reaktor; Untertitel auf kleinen Screens kaum lesbar. Diese finale Korrektur adressiert nur relative Textluminanz/-kontrast und eine sehr kleine CTA-Platzierungskorrektur.

### Geänderte Werte (nur `scripts/ui/start_menu.gd`)

1. Titel `KERNWERK`: `Color(0.83, 0.88, 0.87)` → `Color(0.53, 0.58, 0.57)` — deutlich zurückgenommen, damit der echte Reaktor nicht mehr überstrahlt wird.
2. Untertitel `RESONANZSPRUNG`: `Color(0.43, 0.52, 0.55)` → `Color(0.47, 0.55, 0.57)` — subtil heller für bessere Lesbarkeit auf kleinen Screens.
3. CTA-Vertikalposition: `size.y * 0.66` → `size.y * 0.62` — sehr kleine Anhebung, reduziert den Leerraum zwischen Reaktor und CTA. Keine Größen-/Positionsänderung des Reaktors, keine Gameplay-/Übergangsänderung, keine neuen Nodes/Artwork/Status. Schriftgrößen und responsive Minima unverändert.

### Tatsächliche Bildprüfung (Pixel-Luminanz, da das aktive Vision-Modell hier keinen Bildinput unterstützt)

Das in dieser Session aktive Modell (deepseek-v4-flash) lieferte für `vision_analyze` einen 404 (kein Bild-Endpoint). Stattdessen wurde die tatsächlich gerenderte Pixel-Luminanz der Browser-Captures und der neuen `after_final`-Renders programmatisch gemessen (Pillow, echte PNG-Pixel, keine Skalierung):

| Größe | Titel-Lum vorher | Titel-Lum nachher | Reaktor-Peak | Untertitel-Lum vorher | Untertitel-Lum nachher |
|---|---|---|---|---|---|
| 390×844 | 216 | 142 | 151 | 130 | 135 |
| 320×568 | 216 | 143 | 138 | 125 | 134 |
| 844×390 | 212 | 142 | 137 | 126 | 132 |

- Titel-Luminanz fiel von ~216 auf ~142 (≈ −34 %), liegt damit auf Höhe des Reaktor-Peaks (137–151) statt ihn zu überstrahlen. Hierarchieziel erreicht.
- Untertitel-Luminanz stieg leicht (125–130 → 132–135), bleibt aber bewusst dezent unter Titel und CTA. Lesbarkeitsziel auf kleinen Screens verbessert.
- CTA-Position in der Geometrie: 390×844 y=1388 (vorher 1481), 320×568 y=1116 (vorher 1193) — sichtbar angehoben, weiterhin ≥44 px hoch und getrennt vom Untertitel.

### Checks und echte Ergebnisse

1. `godot4 --headless --audio-driver Dummy --path . -s tests/standby_polish_test.gd` → 90 Checks, 0 Fehler (unverändert).
2. `godot4 --headless --audio-driver Dummy --path . -s tests/start_transition_test.gd` → 2.184 Checks, 0 Fehler (unverändert).
3. Vollständiger Gate `python3 qa/standby_polish_final_verify.py after_final` (mit `XDG_DATA_HOME=/home/masgi_bot/.local/share`): PASS — Import, 7 Suiten, Main-Scene-Smoke, Web-Release-Export. Log `full_gate_standby_after_final.log`.
4. Rendering `xvfb-run ... qa/standby_polish_capture.gd -- after_final` → Exit 0, echte Godot-Raster + X11-Fenstercaptures.
5. Web-Export NUR nach neuem Pfad `/tmp/kernwerk-standby-web-final/` (index.html 5.441 B, index.js 315.759 B, index.wasm 37.700.666 B, index.pck 10.087.340 B; SHA-256 in `web_artifacts_after_final.json`). Bestehender Eltern-Export `/tmp/kernwerk-standby-web/` und Browser-Captures `/home/masgi_bot/data/tasks/standby-browser/` unangetastet.
6. `git diff --check`: Exit 0. HEAD unverändert. Kein Commit/Push/Deploy/Profil-/Konfigwechsel.

### Neue Evidenz (alle in `docs/assets/screenshots/standby_polish/`)

- `after_final_320x568_window.png`, `after_final_390x844_window.png`, `after_final_844x390_window.png` (plus 430×932, 1280×720, Tap/Transition/Playing)
- `after_final_geometry.json`, `web_artifacts_after_final.json`, `full_gate_standby_after_final.log`, `web_export_standby_after_final.log`
- Analyse-Skripte `qa/standby_polish_analyze.py`, `qa/standby_polish_reactor.py`, `qa/standby_polish_compare.py`, `qa/standby_polish_colorcheck.py`, `qa/standby_polish_hierarchy.py`, `qa/standby_polish_final_verify.py`

Status: PROTOTYPE-READY. Technische Checks und Pixel-Luminanzprüfung bestanden; echte visuelle Endabnahme (Titel/Reaktor-Hierarchie, Untertitel-Lesbarkeit auf kleinem Telefon) bleibt ausdrücklich bei Timo, da das aktive Modell hier keine Bildansicht bot.
