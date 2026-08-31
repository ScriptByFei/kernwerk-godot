# Kernwerk — Projektauftrag (Kurzfassung)

> Vollständiger Auftrag vom 31.08.2026 (Timo/fei89). Ziel: 3-Lane Auto-Shooter in Godot als HTML5/Web-Spiel.
> Orientiert am Werbe-Minispiel-Prinzip von Last War: Survival Game — aber eigenständig: kein Base Building, keine Stadt, keine Last-War-Kopie.

## Kernspiel

- Soldat unten auf dem Bildschirm, **exakt 3 vertikale Spuren** (links/mitte/rechts)
- Spieler wechselt nur zwischen diesen drei X-Positionen (`current_lane` 0/1/2)
- **Waffe feuert automatisch permanent** — keine Feuertaste
- Von oben kommen Gegner, Hindernisse, Bonusobjekte; Lane-Wahl entscheidet über Ziel

## Steuerung

- **Touch:** Swipe links/rechts (eine Lane pro Geste, Grenzen geclampt) · optional dritt-Tap-Zonen
- **Desktop (Dev):** A/←, D/→, optional 1/2/3 für direkte Lane

## Waffen-/Projektilsystem

- Startwerte: damage 10 · fire_rate 4/s · bullet_speed 1200 · bullet_count 1 · spread 0
- Projektile fliegen straight nach oben, Despawn außerhalb,消失 bei Treffer
- Architektur vorbereitet für: Multi-Projektil, Durchschuss, Explosiv, Raketen, Shotgun, Laser, Crits, verschiedene Waffen

## Gegner & Belohnungen

- Gegner von oben, je einer Lane zugeordnet; Basiswerte: max_hp, current_hp, movement_speed, reward, enemy_type
- **HP-Zahl sichtbar über jedem Gegner** (50/100/250/500-Staffelung)
- Boni: +10 Damage, +10 % Fire Rate, +1 Soldier, +50 Coins, +20 HP (MVP: nicht alle komplett, Architektur vorsehen)
- Upgrade-Objekte wie Gegner von oben — Spieler muss sie durch Beschuss aktivieren (= zentrale Lane-Entscheidung)

## Zieltypen (gemeinsame Basis `LaneObject`)

Enemy · Upgrade · Obstacle · Reward · Gate · Boss — nicht 6 getrennte Systeme.

## Spielerwerte & Kollision

- max_health 100; Gegner am unteren Rand → Schaden; ≤0 → Game Over
- Mehrere Soldaten (= Formation in einer Lane, echte Feuerkraft, nicht visuell)

## Ablauf

Start → Gameplay → Wellen → Upgrades → stärkere Gegner → Boss → Level Complete
Level: 60–120 s. Wave-System **datengetrieben** (Resource/JSON/Dictionary), nicht hardcodiert.
Schwierigkeit steigt (HP, Speed, Spawnrate, Anzahl) — aber nie unlesbar.

## UI (minimalistisch)

Oben: Level · Score · Coins (+ optional Boss-Progressbar) — Unten: HP · Damage · Fire Rate · Soldiers
Game Over: Overlay mit Score/Enemies/Coins + Restart (ohne Neuladen). Level Complete: Score/Coins/Kills + Continue/Retry.

## Spawn- & GameManager

- **SpawnManager** zentral: Lane, Spawnzeit, Gegnerart, Abstände, Waves (Gegner spawnt sich nicht selbst)
- **GameManager**: State, Level, Score, Coins, Pause, Game/Victory, Restart — keine God-Class
- Kamera statisch, keine Rotation, keine horizontale Welt

## Performance (Web!)

Keine unnötigen `_process`, keine tausenden Nodes, wenige Partikel, kleine Texturen, kein unnötiges Physics; Object Pooling für Bullets/Enemies/Partikel vorsehen, erst implementieren wenn nötig. Regelmäßig Web-Export testen (Touch, Audio, Viewport-Scale, Mobile Safari, Pause/Resume, Browser Focus).

## Smartphone-UX

Safe Areas, Dynamic Island, Browserleisten, verschiedene Aspect Ratios — UI nicht an den Rand.

## Artstyle (MVP)

Platzhalter: Player=blauer Soldier, Gegner=rot, Upgrade=grün, Bullet=kleines Rechteck. Gameplay zuerst, Art Style später.

## Entwicklungsreihenfolge (strikt iterativ)

1. Bewegung (Lanes, Player, Touch, Tastatur) ✅
2. Shooting (WeaponController, Bullet) ✅
3. Gegner (Spawn, Lane, Bewegung, HP, Treffer, Tod) ← **aktuell**
4. Game Loop (HP, Damage, Game Over, Restart)
5. Upgrades (Damage, Fire Rate, Soldier + UI-Feedback)
6. Waves (WaveManager, Muster, Progression)
7. Boss (einfach, viel HP)
8. Polish (Animationen, Partikel, Sounds, Screen Shake)

**Kern-Test:** Macht es Spaß, per Lane-Wahl Ziele/Upgrades zu wählen? Wenn nicht → kein weiteres System bauen.

## Codequalität & Signale

Typisierung, sprechende Namen, kleine Klassen, keine Duplikate. Signale: `health_changed`, `enemy_killed`, `upgrade_collected`, `player_died`, `level_completed`.

**Noch NICHT bauen:** Accounts, Multiplayer, Shop, Echtgeld, Werbung, Login, Cloud Save, Supabase, Skilltrees, Story, Inventar, Gacha, Leaderboards.

## MVP-Kriterien (18 Punkte)

1. Spiel startet · 2. Spieler unten · 3. drei Spuren · 4. Swipe-Wchsel · 5. Auto-Shoot · 6. Gegner von oben · 7. Gegner-HP · 8. Bullets Schaden · 9. Gegner sterben · 10. Upgrades appear · 11. Damage/FireRate-Upgrades greifen · 12. Gegner stärker über Zeit · 13. Spieler nimmt Schaden · 14. Game Over · 15. Restart · 16. einfacher Boss · 17. Level abschließbar · 18. läuft im Godot-Webexport.

## Agenten-Rollen

- **Codex** buildet (Feature-Implementation, konventionelle Commits)
- **Claude** reviewt & balanciert
- **Hermes** QA (Headless-Chromium-Pixel-Beweise), Deployment, Memory (Mnemosyne shared DB: Projekt-Kontext für alle Agenten)
- Nach jeder funktionierenden Phase: Git-Commit (klein, z.B. `feat: add automatic shooting`), Fortschritt in README + Mnemosyne