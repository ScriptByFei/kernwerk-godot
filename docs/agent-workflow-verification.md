# Agent workflow verification

Scope: local agent instructions, review profiles, and local technical Git gate. No game code/assets, model configuration, service restarts, commits, pushes or deployments.

## Added
- Repository `AGENTS.md` and `CLAUDE.md` importing the shared contract.
- Global Claude instructions and read-only `code-reviewer` / `visual-qa` profiles under `~/.claude/`.
- `tools/verify_project.py` and `tools/pre_commit_gate.py`.
- Executable local `.git/hooks/pre-commit` calling the staged-snapshot gate. This hook is local, not auto-distributed by Git. The repository workflow files are versioned separately from the local hook and global Claude/Hermes configuration.
- Hermes workflow skills aligned with the shared contract, review-before-commit order, current jumper state and explicit worktree/reference handling.

## Actual checks
- `python3 tools/verify_project.py --self-test`: six tests passed, including nonzero exit, zero-exit Godot errors, missing executable and timeout handling.
- Real `.git/hooks/pre-commit`: exit 0. Isolated Git-index snapshot imported successfully; all three current GDScript suites passed; main scene smoke test passed; Web release export passed.
- Export output: index.html 5439 bytes; index.js 315759 bytes; index.wasm 37700666 bytes; index.pck 659648 bytes. Temporary output removed after verification; existing build/live assets untouched.
- Negative integration test in a temporary Git repository: staged invalid GDScript, then repaired only the working copy. `git hook run pre-commit` returned 1 with an actual Godot parse error. This verifies the hook checks staged contents rather than the corrected working copy. No actual commit was attempted.
- Claude Code `--agent code-reviewer` smoke test: success, one turn, no tool use; recognized read-only role and imported Resonanzsprung project instructions.
- Claude Code `--agent visual-qa` smoke test: success, no tool use; recognized project and explicitly rejected visual PASS from missing images or passing builds. This is profile-loading verification, not actual visual QA.
- `git diff --exit-code` and `git diff --cached --exit-code`: no changes to existing tracked files or staging area.
- `git diff --check`: clean for tracked diff. New Python files passed syntax checks.
- Hermes gateway active; hermes-webui remained running.

## Independent review follow-up
- Initial review incorrectly treated the context-manager binding of `TemporaryDirectory` as an object. A second reviewer executed the exact `with ... as directory` pattern, confirmed `str`, and found no concrete blockers in either script. No erroneous `.name` change was applied.
- Initial review also incorrectly claimed linked worktrees use separate hooks. A disposable shared clone plus linked worktree resolved `hooks/pre-commit` to the common repository hook and returned its sentinel exit 23 via `git hook run pre-commit`. Linked worktrees share that hook by default; independent clones do not. A new worktree must include the commit containing the checker files before the shared hook can run successfully.

## Boundaries
Local Godot reports 4.6.2; CI pins 4.6.3. No remote CI run or device/visual acceptance is claimed. Existing CI remains unchanged and deploys on push to main. The gate is an accidental-regression safeguard, not a malicious-code sandbox or an immutable security boundary. It executes repository tests using current working-tree checker logic. Approved untracked references remain user-owned and untouched.
