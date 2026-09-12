#!/bin/bash
# Fuehrt den WEB-Zweig der Bestwert-Speicherung in einem ECHTEN Web-Export aus.
#
# Warum so umstaendlich: `JavaScriptBridge` und `localStorage` existieren nur im
# Web-Export. Headless nimmt der Code immer den Datei-Zweig — der Web-Zweig
# bliebe ungeprueft. Der direkte Gameplay-Weg im Browser ist hier nicht fahrbar
# (Software-WebGL zu langsam, der Reaktor stuerzt nicht ab).
#
# Deshalb: temporaere Projektkopie, `qa/web_save_probe.gd` als Hauptszene,
# echter Export, echter Chromium. Das Projekt selbst bleibt unberuehrt.
#
# Aufruf: bash tools/web_save_probe.sh
set -eu
export XDG_DATA_HOME=/home/masgi_bot/.local/share

SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP=/tmp/web_save_probe_project
OUT=/tmp/web_save_probe_out
PORT=8795
CDP=http://127.0.0.1:9222

rm -rf "$TMP" "$OUT"
mkdir -p "$TMP" "$OUT"

echo "=== Temporaere Projektkopie ==="
rsync -a --exclude 'assets/jump/approved' --exclude 'assets/jump/reactor_core/drafts' \
      --exclude 'docs' --exclude '.git' --exclude 'build' \
      "$SRC"/ "$TMP"/
rm -rf "$TMP/.godot"   # frischer Import, keine Pfadreste aus dem Original

echo "=== Probe als Hauptszene ==="
python3 - "$TMP" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
proj = root / "project.godot"
text = proj.read_text()
text = re.sub(r'run/main_scene="[^"]*"', 'run/main_scene="res://qa/web_save_probe.tscn"', text)
proj.write_text(text)

(root / "qa" / "web_save_probe.tscn").write_text(
    '[gd_scene load_steps=2 format=3]\n\n'
    '[ext_resource type="Script" path="res://qa/web_save_probe.gd" id="1"]\n\n'
    '[node name="WebSaveProbe" type="Node"]\nscript = ExtResource("1")\n')

# `qa/` ist per exclude_filter draussen -> fuer diese Probe aufheben.
preset = root / "export_presets.cfg"
p = preset.read_text()
p = p.replace('qa/*,', '').replace(',qa/*', '').replace('qa/*', '')
preset.write_text(p)
print("  Hauptszene -> res://qa/web_save_probe.tscn")
PY

echo "=== Import + Web-Export ==="
timeout 900 godot4 --headless --path "$TMP" --import > /dev/null 2>&1 || true
timeout 900 godot4 --headless --path "$TMP" --export-release "Web" "$OUT/index.html" 2>&1 \
  | grep -iE "^ERROR|error:" | head -5 || true

if [ ! -f "$OUT/index.pck" ]; then
  echo "  FEHLER: Export fehlgeschlagen"
  exit 1
fi
ls -la "$OUT/index.pck" | awk '{print "  index.pck", $5, "B"}'

echo "=== Im echten Browser ausfuehren ==="
cd "$OUT"
python3 -m http.server "$PORT" --bind 127.0.0.1 > /tmp/web_save_probe_server.log 2>&1 &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null || true' EXIT
sleep 2

python3 - "$PORT" "$CDP" <<'PY'
import sys, time, json
from playwright.sync_api import sync_playwright
port, cdp = sys.argv[1], sys.argv[2]
url = f"http://127.0.0.1:{port}/index.html"
title = ""
with sync_playwright() as p:
    b = p.chromium.connect_over_cdp(cdp)
    ctx = b.contexts[0] if b.contexts else b.new_context()
    page = ctx.new_page()
    page.goto(url, wait_until="domcontentloaded", timeout=120000)
    deadline = time.time() + 300
    while time.time() < deadline:
        title = page.title()
        if title.startswith("PROBE:"):
            break
        time.sleep(2)
    page.close()

payload = title[len("PROBE:"):].strip() if title.startswith("PROBE:") else title
detail = payload.split(" || ")
status = detail[0] if detail else "keine Ausgabe"
failed = [d.strip() for d in (detail[1].split(";") if len(detail) > 1 and detail[1].strip() else [])]

json.dump({"status": status, "failed": failed, "raw": payload},
          open("/tmp/web_save_probe.json", "w"), indent=2)

print(f"  Status: {status}")
for line in failed:
    print(f"    FEHLGESCHLAGEN: {line}")
sys.exit(0 if status == "ALLE OK" else 1)
PY
