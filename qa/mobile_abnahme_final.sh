#!/bin/bash
# Abnahme-Serie: identische Fahrten mit eindeutigen Dateinamen.
cd ~/projects/kernwerk-godot || exit 1
OUT=/tmp/kernwerk-abnahme
run() {
  local mode="$1" seed="$2" jitter="$3" seconds="$4" height="$5" offset="$6" restart="$7"
  local tag="${mode}_h${height}_o${offset}_s${seed}_j${jitter}"
  echo "=== RUN $tag (${seconds}s)"
  KW_MODE="$mode" KW_SEED="$seed" KW_JITTER="$jitter" KW_RUN_SECONDS="$seconds" \
    KW_START_HEIGHT="$height" KW_AIM_OFFSET="$offset" KW_RESTART_AFTER_DEATH="$restart" KW_MAX_SHOTS=6 \
    xvfb-run -a -s "-screen 0 430x932x24" godot4 --rendering-driver opengl3 \
    --resolution 430x932 --path . -s qa/mobile_core_loop_probe.gd 2>&1 \
    | grep -E "REPORT|died=|qualities=|frame_ms=|physics/s=|teleport|restart:|SCRIPT ERROR"
  mv "$OUT/shots.jsonl" "$OUT/shots_${tag}.jsonl" 2>/dev/null
}
run forward 13071337 0  30 0     0   0
run forward 13071337 0  30 5000  0   0
run forward 777001   0  30 5000  0   0
run forward 424242   0  30 9000  0   0
run forward 13071337 0  25 0     90  0
run forward 13071337 0  25 0     130 0
run forward 13071337 0  25 0     200 1
run idle    13071337 0  25 0     0   1
echo "=== fertig"
