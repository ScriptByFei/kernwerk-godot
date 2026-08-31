#!/usr/bin/env bash
# Kernwerk — gh-pages Deploy (Legacy-Pages, umgeht Workflow-Pages-Zicken)
# Usage: ./scripts/deploy-pages.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKTREE=/tmp/pages-gh
SRC="$REPO_DIR/build/web"

FILES=(index.html index.js index.wasm index.pck index.png index.icon.png index.apple-touch-icon.png index.audio.worklet.js index.audio.position.worklet.js)

echo "→ Prüfe Build in $SRC …"
for f in "${FILES[@]}"; do
  [ -f "$SRC/$f" ] || { echo "FEHLT: $f — erst exportieren:"; echo "  cd $REPO_DIR && mkdir -p build/web && godot4 --headless --export-release Web build/web/index.html"; exit 1; }
done

echo "→ Update Worktree $WORKTREE …"
if [ ! -d "$WORKTREE/.git" ]; then
  mkdir -p "$WORKTREE"
  cd "$WORKTREE"
  git init -q -b gh-pages
  git remote add origin https://github.com/ScriptByFei/kernwerk-godot.git
  git fetch -q origin gh-pages && git checkout -q gh-pages || true
fi
cp "${FILES[@]/#/$SRC/}" .
cd "$WORKTREE"
git config user.name "ScriptByFei"
git config user.email "55034572+ScriptByFei@users.noreply.github.com"
git add -A
git commit -q -m "deploy: build from $(cd "$REPO_DIR" && git rev-parse --short HEAD)" || echo "  (nichts neu)"
git push -q origin gh-pages

echo "→ Deploy läuft. Danach URL prüfen (CDN cache!):"
echo "   https://scriptbyfei.github.io/kernwerk-godot/index.html"
echo "   Bei 404: gh api -X POST repos/ScriptByFei/kernwerk-godot/pages/builds"