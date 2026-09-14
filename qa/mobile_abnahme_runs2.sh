#!/bin/bash
cd ~/projects/kernwerk-godot || exit 1
OUT=/tmp/kernwerk-abnahme
run() {
  local mode="$1" seed="$2" jitter="$3" seconds="$4" height="$5"
  local tag="${mode}_h${height}_s${seed}_j${jitter}"
  rm -f "$OUT/shots.jsonl"
  echo "=== RUN $tag (${seconds}s)"
  KW_MODE="$mode" KW_SEED="$seed" KW_JITTER="$jitter" KW_RUN_SECONDS="$seconds" KW_START_HEIGHT="$height" \
    xvfb-run -a -s "-screen 0 430x932x24" godot4 --rendering-driver opengl3 \
    --resolution 430x932 --path . -s qa/mobile_core_loop_probe.gd 2>&1 \
    | grep -E "REPORT|died=|qualities=|frame_ms=|physics/s=|teleport|SCRIPT ERROR"
  mv "$OUT/shots.jsonl" "$OUT/shots_${tag}.jsonl" 2>/dev/null
}
run forward 777001   0  30 5000
run forward 424242   40 30 5000
run forward 13071337 0  30 9000
run late    777001   0  30 5000
run idle    13071337 0  20 0
echo "=== fertig"
