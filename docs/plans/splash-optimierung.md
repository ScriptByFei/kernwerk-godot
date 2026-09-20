# Splash-Optimierung: sichtbarer Ladebildschirm (20.09.2026)

## Taskvertrag
- Auslöser: Timo, 20.09.2026. Der sichtbare Ladebildschirm ist der letzte Rest aus
  Phase 6; er liegt im kritischen Pfad jedes Besuchs.
- Erlaubt: `tools/make_splash.py` (neu), `tools/splash_mutation_probe.sh` (neu),
  `tools/verify_project.py` (Gate-Schritt), `.github/workflows/deploy.yml`
  (CI-Schritt), dieser Plan.
- Nichtziele: keine Änderung am Artwork, keine Engine-/Export-Konfiguration, kein
  HTML-Umbau (WebP-Umstieg verworfen, siehe unten), keine Commits/Push.
- Referenz: `assets/splash/boot_splash.png` (unverändert, wurde nach einem
  Fehlversuch byte-genau zurückgestellt).

## Der eigentliche Befund: die QUELLE ist der falsche Hebel

Naheliegend war, das Quellbild zu verkleinern und Godot die kleinere Datei
ausliefern zu lassen. **Das funktioniert nicht** — gemessen, nicht vermutet:

| Schritt | Ergebnis |
|---|---|
| `assets/splash/boot_splash.png` 1.511.345 → 505.815 B (−66,5 %) | — |
| Reimport (`--editor --quit`) | `.godot/imported/...ctex` 298.374 → 346.298 B |
| Export (`--export-release Web`) | `index.png` **1.579.102 B, unverändert** |

Godot importiert das Splash-Bild als VRAM-komprimierte Textur und **re-encodiert
den Splash aus der importierten Textur**. Die Quelldatei beeinflusst die
Export-Bytes damit gar nicht mehr; die Quantisierungsunruhe im Quellbild machte
den Export sogar *größer* als der Live-Stand (1,58 MB gegen 1,42 MB). Die Aktion
ist byte-genau zurückgenommen — die Quelldatei ist wieder identisch.

## Der Hebel: nach dem Export, vor dem Publish

`index.png` liegt nach dem Export als RGB-PNG vor (1.579.102 B gemessen, 810×1440).
256-Farben-Palette ohne Dithering, volle Auflösung:

- **1.579.102 → 566.743 B (−64,1 %), PSNR 35,69 dB, max. Abweichung 61/255.**
- Zum Vergleich die Live-Datei: 1.421.716 → 485.279 B (−65,9 %), PSNR 33,18 dB.
- Bei Anzeigegröße (390 px breit) mittlere Abweichung **1,43/255**; nebeneinander
  bei Gerätegröße ist kein Unterschied zu sehen (Tafel
  `/tmp/kw-splash/kandidat_vergleich.png`, Luma-p99 und -Max in beiden Fassungen
  identisch 246/255).
- **Dithering ist bewusst NICHT als Option drin:** Floyd-Steinberg und NONE
  liefern auf diesem Motiv **byte-identische** Ausgabe (Palette hat mehr Platz als
  der Verlauf braucht) — ein Schalter ohne Wirkung wäre eine Attrappe.

**Verworfen: WebP.** q90 = 193.824 B (PSNR 38,91 dB) wäre weniger als ein Drittel
des PNG, aber die Engine-HTML fordert die Datei namentlich als `index.png` an; ein
Formatwechsel hieße, generiertes HTML zu patchen, das der nächste Export
überschreibt. **Verworfen: Herunterskalieren.** 540 px = 264 KB, aber die
CSS-Box ist größer als 390 px auf einem iPhone (1170 Gerätepixel), eine kleinere
Quelle wäre auf dem Gerät weicher.

## Prüfungen

- `python3 tools/make_splash.py --self-test`: **10 Checks, 0 Fehler.** Enthält
  Known-Value-Prüfungen (Verhältnis-Schranke, PSNR-Grenze, Abmessungen,
  Idempotenz, `--report-only` schreibt nicht) **und eine Gegenprobe, dass die
  Messung ein zerstörtes Bild überhaupt erkennt** (12,12 dB → rot).
- Mutationsprobe `tools/splash_mutation_probe.sh`: **6 von 6 erkannt**, Datei per
  SHA256 unverändert. M1 Qualitätsschranke, M2 Größenschranke, M3 Palette zu grob,
  M4 Paletten-Guard entfernt, M5 `report-only` schreibt doch, M6 Abmessungen
  verändert (bricht ab → ebenfalls erkannt).
- Gate: `PASS: import, 29 Suiten, main-scene smoke, Webexport`, PCK 3.817.952 B.
  Der Gate fährt den Splash-Schritt jetzt mit (`Splash shrink (index.png)`).
- CI-Schritt 1:1 nachgefahren (Ordnerstruktur wie beim Action-Output):
  `1.579.102 → 566.743 B`, exit 0, `splash_report.json` geschrieben.

## Eigene Fehler, festgehalten

1. **Erste Fassung der Selbstprüfung war auf einer unbrauchbaren Vorlage
   kalibriert.** Ein mathematisch glatter Verlauf quantisiert zu **mehr** Bytes als
   RGB (Verhältnis 1,07) — die Prüfsuite schlug genau deshalb an und war im ersten
   Moment als Werkzeugfehler fehlgedeutet. Die Vorlage trägt jetzt feines Korn
   (Verhältnis 0,52), wie das echte Artwork.
2. **Der erste Messwert war die falsche Datei.** Ich hatte gegen das LIVE-Bild von
   GitHub Pages gemessen (PSNR 33,18 dB) statt gegen den lokalen Export
   (35,69 dB) — zwei verschiedene Dateien, 1,42 MB gegen 1,58 MB. Beide Zahlen
   stehen jetzt getrennt im Bericht.
3. **Der erste Dither-Schalter war wirkungslos** (siehe oben). Er ist raus, nicht
   dokumentiert-stehen-gelassen.
4. **Ein Traceback ist keine Fehlermeldung.** `make_splash.py datei.py` brach mit
   `PIL.UnidentifiedImageError` ab. Jetzt: `FAIL: … is not a readable image`, exit 1.

## Offen — Geräteabnahme
Die Palette-Fassung ist am Telefon zu beurteilen (Ladebildschirm beim Neuladen).
Bei 390 px ist rechnerisch kein Unterschied messbar (mittlere Abweichung
1,43/255), aber das ist technische Messung, **keine** Geräteabnahme.

## Nicht deployt
Kein Commit, kein Push, keine iPhone-Abnahme behauptet. Der CI-Schritt ist
vorbereitet und lokal nachgefahren, aber nicht ausgelöst.
