# Kernwerk

**3-Lane Auto-Shooter · Godot 4 · Web · Mobile-first**

Ein Soldat unten, drei Spuren, die Waffe feuert automatisch — der Spieler entscheidet allein durch die Lane-Wahl, welche Gegner und Upgrades er angreift. Inspiriert vom Minispiel-Prinzip aus *Last War: Survival Game*, aber ein eigenständiges Spiel ohne Base Building oder Strategie-Layer.

▶ **Spielen:** https://scriptbyfei.github.io/kernwerk-godot/

---

## Aktueller Stand (31.08.2026)

| Phase | Inhalt | Status |
|---|---|---|
| 0 | Godot-Spike: Headless-Export, Bundle-Größe, Browser-Loop | ✅ |
| 1 | 3 Lanes, Swipe- + Tap-Zonen-Steuerung, Keyboard (A/D, 1–3), weiche Tween-Bewegung | ✅ |
| 2 | Auto-Fire (WeaponController), Bullet-System, Erweiterungsbasis für Multi-Projektil | ✅ |
| — | Custom Boot-Splash, responsives Layout, 2 Bullet-Bugs + Z-Order-Bug gefixt | ✅ |
| 3 | Gegner: SpawnManager, HP-Anzeige, Treffer/Kill | **nächste** |
| 4 | Game Loop: Spieler-HP, Game Over, Restart | offene Phase |
| 5 | Upgrades (Damage / Fire Rate / Soldier / Coins / Heal) | offene Phase |
| 6 | WaveManager (datengetrieben, steigende Difficulty) | offene Phase |
| 7 | Boss | offene Phase |
| 8 | Polish (Partikel, Sounds, Screen Shake, bessere Sprites) | offene Phase |

Die alte TypeScript-Version liegt unverändert als Referenz in `~/projects/kernwerk` (separate Codebase, nicht Teil dieses Repos).

## Spielprinzip

- **Portrait, mobile-first** (1080×1920 Referenz, `canvas_items`-Stretch mit `keep_width`)
- Soldier sitzt bei 86 % Höhe, Lanes bei 25 % / 50 % / 75 % der Breite — funktioniert auf jedem Aspect Ratio (iPhone 19.5:9 bis Desktop)
- **Steuerung:** Swipe links/rechts = Lane-Wechsel · kurzer Tap = direkte Lane · Desktop: A/D bzw. ←/→, 1/2/3
- Lane-Wechsel weich (~0,18 s Tween), kein Teleport; Werte zentral in `scripts/game_config.gd`
- **Waffe feuert automatisch** (4 Schüsse/s, Damage 10, Bullet-Speed 1200) — keine Feuertaste
- Lane-Grenzen geclampt; Lane-Position folgt dem Viewport jeden Frame (iOS-URL-Bar-Resizes)

## Architektur

```
scenes/game/game.tscn          # Wurzel: Background (code), LaneMarkers, Player
scenes/projectiles/bullet.tscn
scripts/game_config.gd         # ALLE Konstanten + lane_x()/player_y() (viewport-relativ)
scripts/game/game.gd           # Wurzel, Background-Handling
scripts/game/lane_markers.gd   # Lane-Trennlinien (dezent, deaktivierbar)
scripts/player/player.gd       # current_lane, Tween-Move, Input-Routing
scripts/player/touch_input.gd  # Swipe + Tap-Zonen (austauschbar gegen reine Swipe-Variante)
scripts/player/weapon_controller.gd  # Auto-Fire, fire_rate/damage/bullet_count/spread
scripts/projectiles/bullet.gd  # fliegt nach oben, Despawn am oberen Rand
assets/splash/boot_splash.png  # eigener Ladebildschirm (1080×1920)
tests/phase*_test.gd           # Headless-Regressionen (laufen ohne Renderer)
```

Grundsätze: typisiertes GDScript, kleine Klassen, Signale (`lane_changed`, `bullet_fired`), Werte niemals in Szenen hardcoden — alles über `GameConfig`. Bullet-Despawn und Spawn immer mit `global_position` (Parent-Trap: siehe Playbook unten).

## Tests

Alle Regressionen laufen headless ohne Renderer:

```bash
godot4 --headless -s tests/phase1_test.gd        # Lanes, Clamp, Signale
godot4 --headless -s tests/phase2_test.gd        # Waffe, Cooldown-Mathematik
godot4 --headless -s tests/phase2_bugfix_test.gd # Bullet-Spawn-Koordinaten (alter Bug als Negativ-Test)
godot4 --headless -s tests/phase2_flight_test.gd # Bullet-Flugbahn (1200 px/s, alter Despawn-Bug als Negativ-Test)
godot4 --headless -s tests/layout_test.gd        # Lane-X auf 4 Aspect Ratios
```

## Deployment

**Lokal (Pi-Preview):**
```bash
godot4 --headless --export-release Web build/web/index.html   # build/web muss existieren
python3 -m http.server 8080 --directory build/web
# → https://masga-server.tail1bf259.ts.net (tailscale serve --bg 8080)
```

**Produktiv (GitHub Pages):**
```bash
git push origin main     # CI baut via Godot-Action (deploy.yml)
./scripts/deploy-pages.sh  # gh-pages-Branch mit neuem build aktualisieren
```

⚠ **Deploy-Gotchas** (alle selbst erlebt):
- Pages-CDN cached 404s hart — nach Deploy URL prüfen, ggf. `POST /pages/builds` erneut triggern
- Pages läuft auf `gh-pages` (Legacy-Build), **nicht** auf dem Workflow-Pfad — der Repo-Branch-Remix master→main hatte Pages intern auf `master` fixiert
- GitHub Action verwendet den Output `build_directory` der Godot-Action, nicht `build/web`

## Bugfix-Playbook (für künftige Agenten)

1. **Bullets als Welt-Kinder, nicht Player-Kinder:** `world.add_child(b)` + `b.global_position = …` *nach* `add_child`. Sonst Doppel-Offset → Schüsse unter dem Bildschirm.
2. **Despawn immer global prüfen:** `global_position.y < -60`, niemals `position.y` (lokal wäre bei Parent-Player nur 140 px Flug).
3. **Dynamischer Background braucht `move_child(bg, 0)`:** sonst liegt der per-Code-erzeugte ColorRect über Player & LaneMarkers → Charakter unsichtbar. (Bullets blieben sichtbar, weil sie später inserted werden.)
4. **`stretch/aspect="keep_width"`** statt `expand` — `expand` verschiebt auf 19,5:9-Displays die Spiellogik aus dem sichtbaren Bereich.
5. **Player-Layout jeden Frame** aus `get_viewport_rect()` ableiten — `WM_SIZE_CHANGED` feuert bei iOS unzuverlässig (URL-Bar).
6. **Boot-Splash referenziert `assets/splash/boot_splash.png`** — fehlt die Datei im Deploy, zeigt Safari ein „?"-Icon.
7. **Viewport-relative Lanes** via `GameConfig.lane_x(lane, viewport_width)` = 25/50/75 % — niemals fixe X-Werte.

## Multi-Agent-Workflow

- **Codex** baut (Feature-Implementation, konventionelle Commits wie `feat: add three lane movement`)
- **Claude** reviewt und balanciert (Werte, Kombos, Feel)
- **Hermes** macht QA (Headless-Chromium + Pixel-Scans als Beweis), Deployments und Memory
- Projekt-Kontext liegt in der geteilten Mnemosyne-DB (Suche nach „Kernwerk"), sodass jeder Agent den aktuellen Stand, die Bugfixes und die Design-Regeln sofort hat
- Vor Session-Ende: Fortschritt hier und in Mnemosyne dokumentieren

## Design-Regeln (fix)

- Portrait, One-Thumb, eine Steuerzone, keine HUD-Verschmutzung
- Sanftes visuelles Feedback — keine harten Labels wie „MISS"
- Performance first: single-threaded WASM (kein COOP/COEP nötig), 9,5 MB gezippt, 60 FPS-Ziel
- Ein Feature auf einmal: erst stabil, dann das nächste

## Roadmap 

Der vollständige Projektauftrag (Phasen 1–8, MVP-Kriterien, UI-Spezifikation) liegt in `docs/PROJECT-BRIEF.md`.