# Kernwerk: shared agent contract

## Scope and sources
- Current game: Resonanzsprung, a mobile-first portrait endless jumper. Active code: `scripts/jump/`, `scripts/game/game.gd`. Legacy auto-shooter tests are archived in `tests/legacy_auto_shooter/`.
- Implement one approved feature at a time. No unsolicited refactors, UI additions, balancing changes, commits, pushes or deployments.
- Before editing, record `git status --short` and read the relevant code/tests. Existing untracked files belong to the user: never clean, reset, overwrite or bulk-stage them.
- Approved visual references: `assets/jump/approved/reactor-core/` and `assets/jump/approved/plush-character/`. Some references are untracked and therefore absent from new worktrees. Explicitly locate/read them before visual work; do not assume a clean worktree contains all references. Never modify approved references without explicit authorization.
- Production reactor assets: `assets/jump/reactor_core/`. Keep the accepted reactor live; plush jump animation is paused pending user instruction. Drafts are not approved production assets.

## Task contract and isolation
Every delegated task must specify outcome, allowed files, non-goals, references, acceptance criteria, verification commands and deliverable. Pass this file to external agents; Hermes memory is not automatically inherited.
- Concurrent writing agents MUST use separate git worktrees, not just separate conversations. Start from a known commit; explicitly provide any needed untracked references. Never copy secrets or the entire dirty working tree.
- Reviewers report findings without editing. A fresh-context reviewer must inspect material changes before commit or push. The orchestrator independently verifies the result.
- Agents may not bypass failing checks using `--no-verify`, change the checks to conceal a failure, or automatically merge conflicting work.

## Executable checks
From repository root:
- `python3 tools/verify_project.py`: project import, all current `tests/*_test.gd` suites, main-scene smoke test and Web release export to a temporary directory. Stops on timeout, nonzero exit or Godot error markers. Does not deploy.
- `python3 tools/verify_project.py --self-test`: exercise the checker's failure detection without running Godot.
- For a focused iteration: `godot4 --headless --audio-driver Dummy --path . -s tests/<name>_test.gd`; this is not a substitute for the full gate.
- A local `.git/hooks/pre-commit` invokes `python3 tools/pre_commit_gate.py`. It exports the Git index into a temporary directory and checks that staged snapshot, not the dirty working tree. Existing untracked files are excluded. Checker logic comes from the working-tree `tools/` files; this is an accident-prevention gate, not a security sandbox. Hooks are local and not automatically distributed by Git. Other clones/worktrees need the checker files and hook installation verified before use.
- Local Godot can differ from CI. The checker prints its version; CI currently pins 4.6.3 in `.github/workflows/deploy.yml`. Do not claim CI passed based on a local run.
- Rendering scripts belong in `qa/`, not the headless `tests/*_test.gd` glob.

## Acceptance and delivery
- Build/test success proves technical checks only. For visual changes, inspect actual rendered output at production size against approved references: silhouette, pivot/ground anchor, distinct frames, limbs/tail/accessories, ghosting and regression. Do not label visual quality PASS from PNG dimensions or file checks alone.
- Provide a mobile preview and leave iPhone acceptance explicitly pending until Timo tests it. No next feature before the current phase is accepted.
- Report changed files, actual commands/results, evidence paths and remaining blockers. Session resume is not file rollback; checkpoints are not backups of external deployments.
- CI already tests, exports and publishes on push to main. A push has deployment side effects and requires authorization; do not push merely to test.
