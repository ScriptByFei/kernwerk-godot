# Core gameplay polish — targeted fix + visual comparison (core_polish_fix)

## Scope of this iteration

Follow-up to the rendered-sequence review in `core_polish_sequence/`. Two goals, in priority order:

1. **Fix the seamless-retry rendering glitch** (grey background + missing HUD on the first retry frame).
2. **One small visual tuning variant** for landing-tier readability at mobile size.

No start choreography, camera handover, input gates, initial bounce, reactor assets, physics or bounce tuning were changed. No new art, no whole-screen flashes. All previous untracked user art/drafts untouched. No commit/push/deploy.

## 1. Root cause of the retry-frame glitch (diagnosed, not guessed)

`game._restart(true)` frees the old `VerticalCamera` and creates a new one via `_create_camera()`. The new camera's scroll/canvas transform is **not applied to the viewport until its next process** (frame 301). But `game._draw()` runs on the same frame (300) and computes its world background rect via `get_viewport().get_canvas_transform().affine_inverse()`. Because the viewport still holds the old (freed) camera's transform, the computed visible world rect is wrong, so the background `draw_rect` misses part of the viewport and the engine's default clear color (grey 77,77,77) shows through. The HUD is drawn inside that same wrong rect, so it is also missing.

This was confirmed by a real regression check on the actual captured frames, not inferred from code alone:
- `before/frame_0300.png`: 150/150 background probes grey, 0 HUD pixels.
- `before/frame_0301.png`: clean (0 grey, 365 HUD pixels).

## 2. The fix (smallest, no choreography change)

In `scripts/game/game.gd`, inside `_restart()` immediately after `_create_camera()`:

```gdscript
camera.make_current()
camera.force_update_scroll()
```

`force_update_scroll()` (verified present on Camera2D 4.6.2) pushes the new camera's scroll into the viewport canvas transform immediately, so the same-frame `_draw()` computes the correct visible world rect. `make_current()` guarantees this camera is the active one. No start functions, timings, or handover logic touched.

## 3. Regression check (real rendered frame, not headless-only)

`qa/core_polish_fix_review.py` reads the actual captured framebuffer PNGs and asserts:
- the first rendered retry frame has **no** grey background probes across the full viewport height, and
- the SCORE HUD is lit (green pixels present).

Result on the fixed capture (`after/`): frame 300 → 0 grey probes, 385 HUD pixels; frame 301 → 0 grey, 365 HUD. **PASS.** The same check on the pre-fix capture (`before/`) fails exactly as expected (150 grey, 0 HUD), proving the check detects the bug.

## 4. Visual comparison — landing tiers at mobile size

Captured the real production collision sequence (same controlled QA as baseline, `qa/core_polish_sequence.gd`, now with a parameterizable `--out=` so it never overwrites the baseline) into three variants:

| Variant | NORMAL alpha | center stem | perfect dash height |
|---|---|---|---|
| `after` (fix only) | 0.45 | 4 | 4 |
| `alpha065` | 0.65 | 4 | 4 |
| `tuned` (kept) | 0.65 | 6 | 6 |

Inspected at native 390×844 and enlarged detail crops with vision:

- **NORMAL 0.45 → 0.65:** clearly more visible edge impact light at 1×; NORMAL is no longer near-invisible. Kept.
- **Center stem 4 → 6:** the precision target reads as a real T-mark instead of a notch at mobile size. Kept.
- **Perfect dash height 4 → 6:** gold dashes more legible; PERFECT remains the most distinct tier. Kept.
- **Tier separation:** with the tuned variant, NORMAL is now a visible baseline, RESONANCE adds a faint ring/cyan edge, PERFECT is clearly the strongest (warm accent + gold dashes). Three grades are now distinguishable at a glance, though RESONANCE is still the subtlest.

The tuned variant was **not worse** than the alternatives, so it is the kept state. No physics/bounce tuning, no new art, no whole-screen flashes.

## 5. Verification

- `python3 tools/verify_project.py` (with `HOME=/home/masgi_bot` so Godot finds the Web export templates): **PASS** — import, 8 suites (CORE POLISH 115, START TRANSITION 2184, STANDBY 90, others ALLE OK), main-scene smoke, Web release export. Log: `docs/assets/screenshots/core_polish_fix/verify_project.log`.
- Focused suites: `tests/core_polish_test.gd` 115/0, `tests/start_transition_test.gd` 2184/0.
- Protected-code comparison vs HEAD (`qa/core_polish_fix_protected.py`): all 8 start functions, `start_menu.gd`, START constants, and reactor assets **unchanged** — ALL_PROTECTED_PASS.
- Retry regression on the kept `tuned` capture: PASS (0 grey, 385 HUD on frame 300).

## 6. Evidence

Root: `docs/assets/screenshots/core_polish_fix/` (`.gdignore` created before capture; baseline `core_polish_sequence/` preserved untouched).

- `before/`, `after/`, `alpha065/`, `tuned/`: full 346-frame 390×844 sequences + `telemetry.json` (real collision signals, state transitions).
- `core_polish_fix.mp4` (fix-only) and `core_polish_fix_tuned.mp4` (kept variant): 346 frames, 60 fps, 5.767 s, verified with ffprobe.
- `retry_compare_f300.png` / `f301.png`: before/after side-by-side of the retry frame.
- `compare_normal_contact.png`, `compare_resonance_contact.png`, `compare_perfect_contact.png`, `compare_perfect_tuned.png`: detail comparisons.
- `*_tiers_contact_native.png`: native-size tier sheets per variant.
- `retry_regression.json` (per variant), `verify_project.log`, `capture_*.log`, `before_sha256.json`, `before_status.log`, `before_game.gd`, `before_jump_config.gd`.

## 7. Changed files (this iteration only)

- `scripts/game/game.gd` — added `camera.make_current()` + `camera.force_update_scroll()` in `_restart()` (the only runtime change for the fix).
- `scripts/jump/jump_config.gd` — 3 tunables: `PLATFORM_IMPACT_ALPHAS[0]` 0.45→0.65, `PLATFORM_CENTER_STEM_SIZE.x` 4→6, `PERFECT_DASH_SIZE.y` 4→6.
- `qa/core_polish_sequence.gd` — `OUT` made a `var` + `--out=` CLI arg + refuse-to-overwrite guard (parameterizable output; baseline untouched).
- New QA scripts: `qa/core_polish_fix_review.py`, `qa/core_polish_fix_compare.py`, `qa/core_polish_fix_compare_alpha.py`, `qa/core_polish_fix_compare_tuned.py`, `qa/core_polish_fix_sheets.py`, `qa/core_polish_fix_tiers.py`, `qa/core_polish_fix_protected.py`.
- `docs/core_gameplay_polish.md` — this report.

The other dirty runtime files (`jumper.gd`, `platform.gd`, `platform_director.gd`, `vertical_camera.gd`) were already modified before this session and were **not** touched by me.

## 8. Status

- **Proven visual fix:** retry frame now fully covered, HUD present, reactor visible — verified on real rendered frames (programmatic + vision).
- **Remaining subjective issues:** RESONANCE is still the subtlest tier at a glance; center marker is readable but not a strong "precision target" at 390 px. These are tuning preferences, not regressions.
- **Native vs iPhone:** verified native (Mesa llvmpipe, 390×844). **iPhone acceptance remains pending Timo's test** — not claimed here.

## 9. Reproduction

```sh
# capture a variant (parameterizable output; refuses to overwrite)
xvfb-run -a -s '-screen 0 390x844x24' godot4 --path . --rendering-driver opengl3 \
  --audio-driver Dummy --resolution 390x844 --fixed-fps 60 \
  -s qa/core_polish_sequence.gd -- --out=res://docs/assets/screenshots/core_polish_fix/tuned

# regression check on the first rendered retry frame
python3 qa/core_polish_fix_review.py --out docs/assets/screenshots/core_polish_fix/tuned

# full gate (needs real HOME for Web export templates)
HOME=/home/masgi_bot python3 tools/verify_project.py
```
