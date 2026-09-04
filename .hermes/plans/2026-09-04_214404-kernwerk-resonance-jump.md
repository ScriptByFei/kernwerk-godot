# Kernwerk: Resonanzsprung Implementation Plan

> **For Hermes:** Implement phase-by-phase with the `kernwerk-workflow` quality gates. Codex builds only from a phase spec and does **not** commit; Hermes verifies, reviews, commits, pushes, and proves the deployed web build.

**Goal:** Transform `kernwerk-godot` from the completed 3-lane auto-shooter into a mobile-first, endless vertical jump game with an original industrial-resonance identity rather than a Doodle Jump clone.

**Architecture:** Make a deliberate hard cut to one game mode. Keep only the proven Godot web project settings, responsive/safe-area utilities, lifecycle/pause behavior, audio-unlock pattern, CI, and GitHub Pages deployment. Replace lane movement, weapons, enemies, waves, upgrades, and boss code with an isolated vertical-jump architecture: `Jumper` owns motion, `PlatformDirector` owns deterministic safe platform generation, `VerticalCamera` owns the upward viewport, and `ResonanceSystem` owns the new risk/reward loop.

**Tech Stack:** Godot 4.6 / GDScript, `gl_compatibility`, `CharacterBody2D`, `StaticBody2D`, headless SceneTree tests, Xvfb screenshot QA, Web export and GitHub Pages.

---

## Product decision: the own game, not a reskin

### Working title and fantasy

**Kernwerk: Resonanzsprung**. The player is a small glowing reactor core escaping upward through a tall, dark industrial heat shaft. Platforms are maintenance ledges, rails, and fragile heat plates—not clouds or doodle-like monsters.

### One-thumb core loop

1. The core auto-bounces whenever it lands on a platform from above.
2. The player drags left/right anywhere on the lower half of the screen to steer in the air; keyboard arrows/A/D remain for desktop QA.
3. The camera only rises. Falling below its bottom boundary ends the run.
4. Height is the primary score. A short run should feel readable in portrait and typically last 45–90 seconds.
5. Every platform has a small illuminated **resonance socket**. Landing within its central 40% adds one charge; an edge landing is still safe but resets the chain.
6. At three charges the next bounce receives a visible, modest **Overload Leap** (higher bounce and a score bonus). It opens optional high platforms; the normal safe route remains reachable without it.

This changes the decision from merely “do not fall” to “take a reliable landing or line up a precise one for an optional, satisfying shortcut.” There are no lane switches, shooting, enemies, shop, ads, meta-progression, or buttons during a run.

### MVP platform vocabulary

- **Stable ledge:** always safe, forms the baseline route.
- **Drift rail:** slowly moves horizontally with bounded, deterministic motion.
- **Heat plate:** breaks 0.25 s after landing; it is never the sole reachable next step.
- **Resonance ledge:** stable or drifting ledge with a socket; this is the only platform type required for the chain mechanic.

No enemy hazards in MVP. Difficulty comes from spacing, moving ledges, camera height, and optional Overload shortcuts—not random impossible layouts.

### Explicit acceptance criteria

- Portrait web build plays with one thumb on iPhone Safari without motion-permission prompts.
- The player can always identify a safe next platform in the camera’s visible upper region.
- A new run has no automatic movement until the first user gesture/tap unlocks audio and starts the run.
- Auto-bounce, steer, camera rise, precise resonance landing, three-charge Overload Leap, falling loss, pause/resume, restart, and height score all work on device.
- The generator is seedable; a fixed seed yields the same platform sequence and never emits an unreachable mandatory platform.
- No shooter behavior, lane language, bullets, enemy HP, waves, boss, soldier art, or obsolete tests remain in the shipped game.
- New test suites are fully green locally and in GitHub Actions; Pages serves the new PCK after the final push.

---

## Migration boundaries

### Keep and adapt

- `project.godot`: portrait viewport, `canvas_items`, `keep_width`, web-compatible renderer. Replace its description and input actions.
- `scripts/game/game_manager.gd`: retain explicit run/pause/game-over state discipline, but simplify its state data to height/score/run state.
- `scripts/ui/ui_layout.gd`, `scripts/ui/pause_ui.gd`, `scripts/ui/game_over_ui.gd`: retain safe-area and modal-layer conventions, update their wording and data presentation.
- `scripts/audio/sfx.gd`: retain first-input Web-Audio unlock behavior; replace or add only jump-specific cues.
- `.github/workflows/deploy.yml`, `export_presets.cfg`, deployment script/configuration: keep the proven test → export → Pages pipeline.

### Retire after the new vertical slice passes

Delete rather than leave a dormant second mode. Git history preserves the auto-shooter implementation.

- Scene content: old `scenes/game/game.tscn` player/lane/weapon children.
- Shooter orchestration: `scripts/game/game.gd`, `game_config.gd`, `lane_markers.gd`, `hit_detection.gd`, `screen_shake.gd` unless a small neutral camera-shake helper is deliberately reused.
- Shooter domains: `scripts/player/`, `scripts/enemies/`, `scripts/objects/`, `scripts/projectiles/`, `scripts/boss/`, old spawn/wave data and managers.
- Shooter UI: wave, HP, weapon stats, score popups, upgrade feedback, level-complete language.
- Old `tests/*_test.gd` and shooter-only QA scripts only after their jump replacements are green.
- Shooter sprites/generated animation sheets and sounds only when no retained script or scene refers to them. Do not bulk-delete shared tooling until reference searches prove it unused.

---

## Target file map

### New runtime files

- `scenes/game/game.tscn` — lean scene: root, `Jumper`, `JumpInput`; runtime builds world, HUD, camera, platforms, and modals.
- `scripts/jump/jump_config.gd` — sole source of physics, camera, generator, and UI constants.
- `scripts/jump/jumper.gd` — `CharacterBody2D`; horizontal steering, gravity, descending-only platform landing, bounce and Overload impulse.
- `scripts/jump/jump_input.gd` — drag/touch/keyboard normalized horizontal intent; it must not know game physics.
- `scripts/jump/platform.gd` — platform state/type, socket geometry, breaking state, collision/visual construction, `landed` signal.
- `scripts/jump/platform_director.gd` — seedable platform sequence, safe-route validation, type selection, recycling below camera.
- `scripts/jump/vertical_camera.gd` — upward-only camera target and bottom death boundary exposed to `game.gd`.
- `scripts/jump/resonance_system.gd` — evaluates landing precision, maintains 0–3 charges, emits `overload_ready` and consumes it on the next bounce.
- `scripts/jump/jump_hud.gd` — safe-area height, best/current run score, and three-segment resonance meter.
- `scripts/jump/jump_run_ui.gd` — start card and game-over/retry copy specific to the new game.
- `scripts/jump/jump_background.gd` — procedural layered shaft/background parallax; no art dependency blocks prototype play.

### Adapted files

- `project.godot`
- `scenes/game/game.tscn`
- `scripts/game/game_manager.gd`
- `scripts/ui/pause_ui.gd`
- `scripts/ui/game_over_ui.gd`
- `scripts/audio/sfx.gd`
- `README.md`
- `docs/PROJECT-BRIEF.md`

### New tests and QA

- `tests/jump_physics_test.gd`
- `tests/resonance_test.gd`
- `tests/platform_director_test.gd`
- `tests/jump_state_test.gd`
- `tests/jump_layout_test.gd`
- `qa/jump_screenshot.gd`

---

## Execution plan

### Phase 0: lock the migration boundary and visual direction

**Objective:** Prevent an accidental hybrid of the old shooter and the new game before code is changed.

1. Create a short feature spec for the first vertical slice at `/tmp/kernwerk-jump-phase1-spec.md` from this plan. It must explicitly prohibit lanes, weapons, enemy objects, and reuse of shooter mechanics.
2. Record a clean baseline (`git status`, current SHA, full suite result) and create a recovery tag/branch before deletion, for example `archive/auto-shooter-phase12`. Do not alter `main` until this recovery point exists.
3. Update only product documentation in a dedicated commit: describe the game as the planned Resonanzsprung rebuild and mark the auto-shooter as retired after the migration lands. Do **not** claim the jump game is playable yet.
4. Define the art proof for MVP: dark graphite shaft, orange core, cyan/amber sockets, low-detail vector silhouettes. Use procedural Godot drawing at first; only commission/generate sprites after movement feels good on the iPhone.

**Verification:** Existing `19/19` shooter suites still pass at the archive point. `git diff --check` is clean. No game-code change is made in this phase.

---

### Phase 1: build the smallest playable vertical slice (TDD)

**Objective:** Prove satisfying auto-bounce and upward camera movement with static platforms before procedural content or visual polish.

**Files:**
- Create: `scripts/jump/jump_config.gd`, `scripts/jump/jumper.gd`, `scripts/jump/platform.gd`, `scripts/jump/vertical_camera.gd`, `tests/jump_physics_test.gd`
- Modify: `scenes/game/game.tscn`, `scripts/game/game.gd`, `project.godot`

**Step 1 — write failing physics contracts** in `tests/jump_physics_test.gd`:

- A resting `Jumper` accelerates downward by gravity.
- A platform collision while descending produces exactly one bounce with `velocity.y < 0`.
- Contact while rising never creates a second bounce.
- Horizontal steering is clamped to `MAX_HORIZONTAL_SPEED`.
- An Overload bounce is higher than the base bounce but does not exceed `MAX_BOUNCE_SPEED`.

**Step 2 — run the failing suite.**

```bash
godot4 --headless --path . -s tests/jump_physics_test.gd
```

Expected: failures for missing `Jumper`, `Platform`, and `JumpConfig` contracts.

**Step 3 — implement minimum vertical physics.**

- Use `CharacterBody2D` and `move_and_slide()` in `Jumper`; no hand-rolled pixel collision.
- A platform can only trigger a bounce when the jumper was descending and its feet cross the platform top.
- Put all gameplay numbers in `JumpConfig`: gravity, base bounce, overload bounce, horizontal acceleration/drag, platform dimensions, camera lead, and death margin.
- Keep the scene’s first slice to seven hand-authored stable platforms in a climbable zig-zag. Do not introduce randomness yet.
- `VerticalCamera` follows only when the jumper climbs above its lead point and never scrolls back down.

**Step 4 — run the new suite and a real smoke scene.**

```bash
godot4 --headless --path . -s tests/jump_physics_test.gd
godot4 --headless --path . --editor --quit
```

Expected: `JUMP PHYSICS: ALLE OK`, no parser/import errors.

**Step 5 — capture visual evidence.**

```bash
xvfb-run -a -s "-screen 0 540x960x24" godot4 --rendering-driver opengl3 --resolution 540x960 -s qa/jump_screenshot.gd
```

Save only to `docs/assets/screenshots/`; inspect the screenshot before accepting the phase.

**Hermes gate:** Inspect the diff for correct descending-only collision; run the test five times to expose timing flakiness. Commit only after all five runs and screenshot review pass.

---

### Phase 2: make steering and responsive portrait layout real

**Objective:** Replace lane/tap semantics with a dependable one-thumb air-control model and a readable, safe mobile layout.

**Files:**
- Create: `scripts/jump/jump_input.gd`, `scripts/jump/jump_hud.gd`, `tests/jump_layout_test.gd`
- Modify: `project.godot`, `scenes/game/game.tscn`, `scripts/jump/jumper.gd`, `scripts/game/game.gd`, `scripts/ui/ui_layout.gd`
- Delete after equivalent tests pass: `scripts/player/touch_input.gd`, lane input actions in `project.godot`, lane-only player scene dependencies.

**Step 1 — write failing input/layout tests.**

- A drag left/right yields normalized intent in `[-1, 1]` without a lane index.
- A second finger/cancel event clears stale intent.
- Keyboard left/right maps to the same intent for desktop QA.
- HUD bounds stay inside `UiLayout.content_rect()` for 19.5:9 iPhone, 9:16 Android, and 16:9 desktop test viewports.
- Camera coordinate conversion never places the current height label outside the safe top area.

**Step 2 — implement the minimum input and HUD.**

- `JumpInput` owns gesture parsing; `Jumper.set_horizontal_intent(value)` owns movement.
- Make horizontal movement a smooth acceleration toward intended velocity, not teleporting to pointer position.
- Use a single lower-screen drag zone so taps in the upper screen do not accidentally make the player jerk into danger.
- Show only `HEIGHT`, a three-cell resonance meter, and a small pause affordance. No old score/kills/HP/weapon rows.

**Step 3 — run tests and manual desktop interaction.**

```bash
godot4 --headless --path . -s tests/jump_physics_test.gd
godot4 --headless --path . -s tests/jump_layout_test.gd
godot4 --path .
```

Expected: both suites green; a player can cross the seven-platform route using either a drag or arrow keys.

**Hermes gate:** iPhone playtest before any procedural generator: control feels analog and forgiving, browser chrome does not hide HUD, and no tilt permission is requested.

---

### Phase 3: add the Resonanzsprung mechanic and safe deterministic generation

**Objective:** Create the distinctive decision loop while protecting fairness with a seedable platform director.

**Files:**
- Create: `scripts/jump/resonance_system.gd`, `scripts/jump/platform_director.gd`, `tests/resonance_test.gd`, `tests/platform_director_test.gd`
- Modify: `scripts/jump/platform.gd`, `scripts/jump/jumper.gd`, `scripts/jump/jump_config.gd`, `scripts/game/game.gd`, `scripts/jump/jump_hud.gd`

**Step 1 — write failing resonance tests.**

- Landing in `[-0.20, +0.20]` of a platform socket center adds exactly one charge.
- Edge landings remain valid, but clear the charge chain.
- Charge sequence `1 → 2 → 3` emits one `overload_ready` signal.
- The next landing consumes the Overload once; it cannot persist for a second bounce.
- A falling/restart run resets charge and score state.

**Step 2 — write failing generator contracts.**

- Same seed and starting viewport produce the same platform x/y/type sequence.
- Each mandatory platform’s horizontal displacement and vertical gap are within the reachable envelope derived from base bounce, maximum steering speed, and gravity.
- At least one safe stable platform is present in the visible next-screen band.
- Heat plates and drift rails never form the only route.
- Recycling a platform below the camera maintains the minimum visible-platform count without duplicate IDs or memory growth.

**Step 3 — implement the minimum systems.**

- Platform sockets expose a center and normalized landing precision; the resonance system must not inspect sprites or physics bodies.
- The director first creates a safe “spine” route. It then adds optional drift/heat/resonance platforms only after the spine is valid.
- Use `RandomNumberGenerator.seed` from an exported `run_seed`; `-1` means a fresh random seed and logged seed for reproducible bug reports.
- Begin with stable and resonance ledges. Add drift rails only after the seed tests are green; add heat plates last.
- Overload boosts a single bounce by a tuned, capped multiplier and adds height-score bonus feedback. It must not be mandatory to avoid an unfair soft lock.

**Step 4 — run deterministic tests repeatedly.**

```bash
for i in 1 2 3 4 5; do
  godot4 --headless --path . -s tests/resonance_test.gd &&
  godot4 --headless --path . -s tests/platform_director_test.gd || exit 1
done
```

Expected: ten green test invocations with no `SCRIPT ERROR` output.

**Hermes gate:** Review the route validator, generator seed path, and Overload consumption. Capture a screenshot with sockets, 3-charge meter, and at least one optional high route visibly readable.

---

### Phase 4: turn the prototype into a complete repeatable run

**Objective:** Add start/restart, failure, height scoring, pause/focus behavior, and finite-memory recycling without returning to shooter state concepts.

**Files:**
- Create: `scripts/jump/jump_run_ui.gd`, `tests/jump_state_test.gd`
- Modify: `scripts/game/game_manager.gd`, `scripts/game/game.gd`, `scripts/jump/vertical_camera.gd`, `scripts/jump/platform_director.gd`, `scripts/ui/pause_ui.gd`, `scripts/ui/game_over_ui.gd`, `scripts/audio/sfx.gd`
- Delete after replacement tests: old wave/boss/health/upgrade/level-complete manager paths and UI files.

**Step 1 — write failing state tests.**

- `START → RUNNING` occurs only after the first player input.
- Below-camera fall changes state once to `GAME_OVER`, freezes world motion, and reports final height.
- Pause/focus-out freezes jumper physics and director recycling; resume continues the same run without changing seed/order.
- Retry creates a fresh run, resets score/charge, and tears down old platform nodes.
- A long simulated run never exceeds the configured active-platform ceiling.

**Step 2 — implement and verify.**

- Make `GameManager` own `current_height`, `best_height` (session-only in MVP), and explicit run state. Remove HP, kills, enemy score, and level-complete semantics.
- `game.gd` becomes the orchestration point for jumper/platform director/camera/resonance/HUD, and nothing else.
- Start/retry UI must be short: `TAP & HOLD TO STEER`, final `HEIGHT`, `BEST`, `RETRY`.
- Preserve `Sfx.unlock()` on first input; use a subtle bounce, resonance, overload, and fall cue only after user interaction.

**Step 3 — validate.**

```bash
godot4 --headless --path . -s tests/jump_state_test.gd
godot4 --headless --path . -s tests/jump_physics_test.gd
godot4 --headless --path . -s tests/resonance_test.gd
godot4 --headless --path . -s tests/platform_director_test.gd
```

Expected: all four green; a 10-minute manual soak shows stable platform count and no stuck pause state.

---

### Phase 5: replace prototype visuals, remove shooter residue, and document the new game

**Objective:** Give the tested mechanics a coherent own look without obscuring platform collision or overbuilding asset pipelines.

**Files:**
- Create/modify only after gameplay approval: `scripts/jump/jump_background.gd`, jump-specific asset files under `assets/jump/`, `qa/jump_screenshot.gd`
- Modify: `README.md`, `docs/PROJECT-BRIEF.md`, `project.godot`
- Delete: proven-unused shooter sources, scenes, assets, tests, and QA scripts named in the migration boundary.

**Steps:**

1. Produce vector/procedural visual pass first: layered shaft parallax, core glow, platform silhouettes, socket pulse, restrained particle burst, and an Overload ring. Retain `CPUParticles2D` only; never introduce `GPUParticles2D` under `gl_compatibility`.
2. Verify collision readability with a screenshot at 540×960 and a real iPhone: the landing surface and socket must remain distinguishable over the background.
3. Use reference search before any generated sprite work. If assets are generated, have an explicit approved visual reference and inspect frames directly in chat before integrating.
4. Search all `res://` references before deleting legacy sources/assets. Delete only files with no references in scene/script/test/export paths.
5. Rewrite README and PROJECT-BRIEF around the new controls, core loop, test list, and deployment URL. Do not preserve auto-shooter gameplay claims.

**Verification:** Godot import scan has no missing resource warnings; `git diff --check` passes; old identifiers such as `WeaponController`, `SpawnManager`, `WaveManager`, `Boss`, `lane_left`, `enemy_killed`, and `bullet_fired` have zero shipped runtime references.

---

### Phase 6: release-quality validation and deployment

**Objective:** Prove the rebuilt game works locally, in CI, on Pages, and on the iPhone before calling the migration complete.

1. Run every replacement suite one by one; fail if an exit code is nonzero, `SCRIPT ERROR` appears, or the suite does not print its explicit success marker.

```bash
python3 -c "import glob, subprocess, sys
files=sorted(glob.glob('tests/*_test.gd'))
for path in files:
    r=subprocess.run(['godot4','--headless','--path','.','--audio-driver','Dummy','-s',path], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    bad=r.returncode != 0 or 'SCRIPT ERROR' in r.stdout
    print(path, 'FAIL' if bad else 'PASS')
    if bad: print(r.stdout[-3000:]); sys.exit(1)
print('ALL JUMP SUITES PASS')"
```

2. Run a main-scene smoke and export locally.

```bash
godot4 --headless --path . --editor --quit
mkdir -p build/web
godot4 --headless --path . --export-release Web build/web/index.html
python3 -m http.server 8080 --directory build/web
```

3. Inspect the local browser build on mobile via the existing Tailscale preview. Test: start gesture, drag steering, socket precision, Overload, falling loss, retry, pause after Safari background/foreground, sound after first input, 19.5:9 layout.
4. After Hermes accepts the final diff, commit with a clear migration message, push `main`, and watch the actual `Test, Build & Deploy (GitHub Pages)` run—not the separate Pages deployment record.
5. Require CI test and build success. Poll Pages until `built`, then download the deployed `index.pck`; record size and HTTP 200.
6. Final iPhone playtest is the release gate. Capture one gameplay screenshot and report only observed behavior/remaining tuning issues.

---

## Risks and mitigations

- **Physics/camera feel is wrong despite correct tests.** Treat the Phase 1 iPhone feel test as a hard gate before adding content or art. Tune only constants in `JumpConfig`, with before/after values documented.
- **Procedural route creates impossible jumps.** Build the safe-spine route first and test reachability from physical bounds; optional platforms never gate progression.
- **Exact socket landings feel punitive on touch.** Start with a generous 40% width window and only tighten after device playtests. Edge landings must always remain valid.
- **Old shooter deletion breaks unseen export/resource dependencies.** Tag the baseline, search all references, and delete only after replacement tests and import scan pass.
- **Web/iOS regressions.** Keep `keep_width`, dynamic viewport/safe-area calculations, `gl_compatibility`, `CPUParticles2D`, and first-input audio unlock; test Safari foreground/background explicitly.
- **Scope creep.** No enemies, combat, currency, unlock tree, ads, analytics, accounts, online leaderboard, tilt input, or generated asset pipeline before the vertical slice feels good.

## Decisions to confirm before Phase 1 implementation

This plan assumes: industrial reactor-shaft art direction; horizontal drag steering rather than tilt; endless high-score runs; auto-bounce; and the three-charge Resonance/Overload mechanic. If any of those five foundations is wrong, revise this plan before code is started. Everything else can be tuned during the phased iPhone playtests.
