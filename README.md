# Kernwerk

**3-Lane Auto-Shooter · Godot 4 · Web · Mobile-first**

Ein Soldat unten, drei Spuren, die Waffe feuert automatisch — der Spieler entscheidet allein durch die Lane-Wahl, welche Gegner er stoppt und welche Upgrades er abfarmt. Inspiriert vom Minispiel-Prinzip aus *Last War: Survival Game*, aber ein eigenständiges Spiel: kein Base Building, keine Stadt, keine Last-War-Kopie. Alle Assets/Namen eigenständig.

▶ **Spielen:** https://scriptbyfei.github.io/kernwerk-godot/

*(Lokaler Dev-Preview: `https://masga-server.tail1bf259.ts.net` — Tailscale-serve auf Port 8080)*

---

## Aktueller Stand (01.09.2026)

| Phase | Inhalt | Status |
|---|---|---|
| 0 | Godot-Spike: Headless-Export auf RPi5, 9,5 MB zipped, 60 FPS-Beweis | ✅ |
| 1 | 3 Lanes, Swipe + Tap-Zonen, Keyboard (A/D, 1-3), Tween-Bewegung 0.18s | ✅ |
| 2 | Auto-Fire (WeaponController), Bullet-System | ✅ |
| 3 | Gegner: LaneObject-Basis, Enemy mit HP-Anzeige, SpawnManager, Treffer/Kill-Feedback | ✅ |
| 4 | Game Loop: Spieler-HP, i-Frames, Game Over Overlay, Restart ohne Reload | ✅ |
| 5 | Upgrades (Damage +15 / Fire Rate +0.1 / Soldier +1) + HUD + Popup-Feedback | ✅ |
| 6 | WaveManager (6 datengetriebene Wellen, Level ~119s, Boss-Flag, Difficulty-Kurve) | ✅ |
| — | **Balancing-Pass:** Fire Rate 4→1.2/s, Rate-Upgrade linear +0.1, Upgrade-Hitbox ±100px | ✅ |
| S1 | **Stabilitätsfundament:** Pause/Focus-Lifecycle, Safe-Area-HUD, Modal-Schichtung, seedbare Spawns | ✅ |
| S2 | **Lane-Entscheidungen:** faire Drei-Spur-Muster, 0.6-s-Telegraph, Grunt/Runner/Tank, Rollen-Score | ✅ |
| 7 | Boss-Verhalten (2-Phasen-Kampf: Hover, Lane-Pulse mit Telegraph, Beschwörungen, Lane-Weaving, BossData-Tuning) | ✅ |
| 8 | Polish (Score-Popups, Screen Shake, Partikel, CC0-Sounds mit Web-Audio-Unlock, PNG-Sprites aus Kenney-Paket) | ✅ |
| 9 | Lebendige Einheiten: prozedurale Animations-Sheets (`tools/sprite_pipeline.py`, Pillow, deterministisch) + `AnimatedSprite2D` (Idle-Bob, Shoot-Flash, Boss-Pulse-Glow) | ✅ |
| 12 | **Drohne (neuer Gegnertyp):** GPT-generiertes Sprite (flacher Cartoon-Look, Violett-Akzente, Chroma-Key), HP 0.8×/Speed 1.2×/Score 12, Spawn ab Welle 3 (`drone_intro`, `drone_mixed`) | ✅ |

**Housekeeping (01.09.2026):** Versehentlich im Projekt-Root eingecheckte Web-Export-Artefakte (`index.html/js/wasm/pck`, Spike-Screenshots) entfernt + `.gitignore` verschärft — nur noch `build/web/` darf Build-Output enthalten. Kein Verhaltensunterschied im Deployment (`deploy-pages.sh` liest ohnehin nur aus `build/web/`).

Old TS-version als Referenz archiviert: `~/projects/kernwerk` (separate codebase, frozen).

## Spielprinzip

- **Portrait mobile-first** (1080×1920 Ref, `canvas_items` stretch, `keep_width`)
- Soldat bei 86 % Höhe, Lanes bei 25/50/75 % der Breite — viewport-relative auf jedem Aspect Ratio
- **Steuerung:** Swipe links/rechts = Lane · Tap = direkte Lane · Desktop: A/←, D/→, 1/2/3
- **Waffe feuert automatisch** — 1,2 Schüsse/s (bewusst langsam, „Schüsse zählen"), Damage 10 Baseline
- **Spawn-Reihen statt Lane-Roulette:** maximal zwei Gegner pro Reihe, immer mindestens eine Lane ohne Gegner; farbige Pfeil-Telegraphen warnen 0,6 s vor
- **Drei Gegnerrollen:** Grunt = Standard (10 Punkte), Runner = schnell/leicht (15), Tank = langsam/zäh (20); Runner ab Welle 2, Tank ab Welle 3
- **Drohne (ab Welle 3):** fliegender, schneller, zerbrechlicher Gegner (12 Punkte) — GPT-generiertes Sprite, Violett-Akzente passend zum Boss-Theme
- **Upgrade-Pfad:** grüne Träger (22–35 % Spawn-Chance) abschießen → `+15 DMG` / `+0.1 RATE` / `+1 SOLDIER` (Soldiers = echte Additional-Bullets ±90px-Formation)
- **HP 100**, Gegner erreicht 82%-Höhe → 10 Schaden, 0.8 s i-frames, rote Vignette sanft
- **Level = 6 Wellen ≈ 120 s**, Welle 6 = Boss-Kampf: Boss hält bei 22 % Höhe, Pulse-Angriff (0.8 s Telegraph) trifft nur in seiner Lane, Lane-Weaving, Beschwörungen (Grunt/Runner), Phase 2 ab 50 % HP, danach Level Complete
- **Boss-Tuning:** alle Zahlen in `scripts/boss/boss_data.gd` (HP 500, Pulse-Intervalle, Summons, Lane-Switch) — Tune hier!

## Architektur

```
scripts/
  game_config.gd              # Core-Konstanten (speeds, sizes, base weapon values)
  game/
    game.gd                   # Wurzel: Verkabelung aller Systeme
    lane_markers.gd           # DEAKTIVIERT (sichtbar via visible_lines flag; Timo möchte cleanes Feld)
    hit_detection.gd          # Lane-basierte Distance-Checks (keine Physics-Engine)
  player/
    player.gd                 # current_lane, Tween-Wechsel, Input
    touch_input.gd            # Swipe + Tap-Zonen
    weapon_controller.gd      # Auto-Fire, liest PlayerStats
    player_stats.gd           # damage/fire_rate/soldiers + apply_upgrade
    player_health.gd          # HP, i-frames, Vignette, Bar
  enemies/
    enemy.gd                  # Rollensilhouette, HP, Hit-Flash, Wobble, Death-Fade
    enemy_archetype_data.gd   # HP-/Speed-Faktoren, Farbe und Score je Rolle
  objects/
    lane_object.gd            # Basis: Lane + Bewegung + reached_bottom (once-guard)
    upgrade_object.gd         # grüner Träger, Text, collect()
  projectiles/bullet.gd
  managers/
    game_manager.gd           # einzige Quelle für HP/i-Frames/Score/Kills/Endzustand
    spawn_manager.gd          # seedbare Musterwahl, Telegraph und Reihen-Spawn
    spawn_pattern_data.gd     # freigeschaltete, validierbare Drei-Lane-Muster
    wave_manager.gd           # Phasen-Driver, liest WaveData, Wellen-Ende + Boss
    wave_data.gd              # ALLE Wellen- + Balancing-Konstanten (Tune hier!)
  boss/
    boss.gd                   # 2-Phasen-Boss: Hover, Lane-Pulse, Summons, Weaving
    boss_data.gd              # ALLE Boss-Tuning-Konstanten (HP, Pulse, Summons)
  effects/particle_burst.gd   # One-shot CPU-Partikel-Bursts (Kill, Upgrade, Boss)
  audio/sfx.gd                # CC0-Sounds + Web-Audio-Unlock (erster Tap)
  ui/
    hud.gd, spawn_telegraph.gd, game_over_ui.gd, level_complete_ui.gd, upgrade_feedback.gd, score_feedback.gd
  game/screen_shake.gd        # dezenter Welt-Offset-Shake (Player-Hit, Boss-Pulse)
  assets/sprites/             # CC0-Kenney-PNGs (player/grunt/runner/tank/boss/bullet/upgrade)
tests/phase{1..6}_test.gd + layout/bugfix/flight/stabilization/foundation/pattern suites
```

**State-Verkettung:** `Spawner.upgrade_collected_from_world → Game._on_upgrade_collected → PlayerStats.apply_upgrade + Feedback.popup_for`. Enemy-Kills laufen über `SpawnManager.enemy_killed_from_world → Game → GameManager.add_kill()` (10/15/20 Punkte nach Rolle). HP, i-Frames, Game Over und Level Complete gehören ausschließlich dem `GameManager`.

## Tests

```bash
godot4 --headless --path . -s tests/<suite>_test.gd
```

Suites: `phase1..6`, `layout`, `phase2_bugfix`, `phase2_flight`, `stabilization`, `foundation`, `pattern`. CI wertet zusätzlich Godot-Fehlerzeilen aus, weil Godot bei manchen Scriptfehlern trotzdem Exitcode 0 liefert.

`foundation` sichert den neuen Stabilitätsunterbau ab: explizite Pause-/Resume-Zustände, Safe-Area-Berechnung, UI-Canvas-Ebenen, einmalige Gegnerankunft und reproduzierbare Spawnfolgen per Seed.

`pattern` prüft alle Reihen auf Fairness, Rollen-Freischaltungen und -Balance, die deterministische Muster-/Lane-Folge sowie die Verkettung Telegraph → Spawn → rollenabhängiger Score.

**Playbook — Bugs, die wir bereits einmal hatten (nicht wiederholen):**
1. Bullets spawn always with `world.add_child()` + `global_position = …` AFTER `add_child` (never as Player child — double-offset → bullets below screen)
2. Despawn checks `global_position.y` not `position.y` (otherwise despawn at ~140px local)
3. Dynamic Background needs `move_child(bg, 0)` after `add_child` — otherwise it covers Player + LaneMarkers (invisible char bug!)
4. `stretch/aspect = keep_width` (NOT expand) — expand breaks iOS 19.5:9 layout
5. Player layout re-derived EVERY frame from `get_viewport_rect()` in `_process` (iOS URL-bar resizes skip notifications)
6. New LaneObject-subclasses MUST `add_to_group("upgrades")` / `("enemies")` — group queries fail silently otherwise (upgrades were unshootable)
7. Hit-wobble tweens around CURRENT `position.x` (was `0.0` → enemies teleported to left edge on hit)
8. Spawn position AFTER `add_child` (viewport rect unavailable before → lane_x returned 0)
9. WaveData = single source of Balancing truth; PlayerStats/HitDetection read from there.

## Deployment

**Produktiv:** Push auf `main` → alle Headless-Tests + Main-Scene-Smoke → Web-Export → atomarer Publish auf `gh-pages` → https://scriptbyfei.github.io/kernwerk-godot/

Es gibt nur noch diesen CI-Deployweg. Die GitHub-Pages-Quelle bleibt auf `gh-pages / (root)`; lokale Deploy-Skripte und der konkurrierende Actions-Pages-Deploy wurden entfernt.

**Lokal:** `mkdir -p build/web` + `godot4 --headless --export-release Web build/web/index.html` + `python3 -m http.server 8080 --directory build/web` + `tailscale serve --bg 8080`.

**CI** (`.github/workflows/deploy.yml`): lädt Godot 4.6.3 für Tests, führt jede Suite einzeln mit Timeout aus, startet die Main Scene headless, exportiert anschließend mit `firebelley/godot-export@v8.0.0` und veröffentlicht ausschließlich nach `gh-pages`.

## Multi-Agent-Workflow

- **Codex** buildet (Features, konventionelle Commits `feat:`/`fix:`), **Claude** reviewt/balanciert, **Hermes** QA (Headless-Chromium + Pixel-Scans als Beweis) + Deploy + Memory
- **Projekt-Kontext liegt in der geteilten Mnemosyne-DB** (Suchwort „Kernwerk"): Infrastruktur, Bugfix-Playbook, Phasen-Stand, Balancing-Entscheidungen. Dort ergänzen, nicht nur im Code-Kommentar.
- Vor Session-Start: `git pull origin main` + Mnemosyne recall „kernwerk"

## Design-Regeln (fix)

- Portrait, One-Thumb, Clean-UI, sanftes Feedback — **keine Labels wie „MISS"**
- Lane-Linien aus (Timo-Entscheidung); Lanes über Positionierung lesbar
- Performance: single-threaded WASM, 9,5 MB gezippt, kein COOP/COEP
- Ein Feature auf einmal — erst stabil, dann das nächste

## Offene Punkte

- **Playtest-Fixes v2 deployed (01.09.)** — ✅ Soldaten-Salven GEBÜNDELT auf Spieler-Lane (kein ±90px-Offset → nichts ging mehr am Gegner vorbei); ✅ **Boss-HP skaliert mit DPS** (`BossData.scaled_hp`, Wurzel-Kurve, Floor 500) → kein „Instant-Kill“ bei max. Upgrades mehr. **Nächster iPhone-Playtest: trifft die Salve zuverlässig? Fühlt sich der Boss mit Max-Build richtig zäh an?** Tuning via `boss_data.gd` / `weapon_controller.gd`
- **Phase 9 (02.09.)** — Lebendige Einheiten live: Idle-Bob, Shoot-Flash, Boss-Pulse-Glow. **Nächster iPhone-Playtest: wirken die Animationen stimmig oder zu hektisch?** (Bob-Speed 4.0, Boss-Pulse 3.0 — Tuning in `enemy.gd`/`player.gd`)
- Object Pooling für Bullets (aktuell ~15-20 Nodes/Run — noch kein Flaschenhals bei 60 FPS)
- Optional: Minimax-Kredit aufladen für eigene KI-Sprites (Katalog hat kein Bildmodell, Direkt-API ohne Guthaben)
