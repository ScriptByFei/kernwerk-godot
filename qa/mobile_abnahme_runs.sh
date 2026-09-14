#!/bin/bash
# Faehrt die Abnahme-Runs durch. Jeder Run ist ein vollstaendiger Spielabschnitt
# in einem echten 430x932-Fenster mit echter Eingabezustellung.
cd ~/projects/kernwerk-godot || exit 1
OUT=/tmp/kernwerk-abnahme
mkdir -p "$OUT"

run() {
  local mode="$1" seed="$2" jitter="$3" seconds="$4"
  local tag="${mode}_s${seed}_j${jitter}"
  rm -f "$OUT/shots.jsonl"
  echo "=== RUN $tag (${seconds}s)"
  KW_MODE="$mode" KW_SEED="$seed" KW_JITTER="$jitter" KW_RUN_SECONDS="$seconds" \
    xvfb-run -a -s "-screen 0 430x932x24" godot4 --rendering-driver opengl3 \
    --resolution 430x932 --path . -s qa/mobile_core_loop_probe.gd 2>&1 \
    | grep -E "REPORT|died=|qualities=|frame_ms=|physics/s=|SCRIPT ERROR|window|stretch"
  mv "$OUT/shots.jsonl" "$OUT/shots_${tag}.jsonl" 2>/dev/null
}

run forward 13071337 0  30
run forward 13071337 40 30
run forward 13071337 80 30
run forward 777001   0  30
run forward 424242   0  30
run late    13071337 0  30
echo "=== fertig"
