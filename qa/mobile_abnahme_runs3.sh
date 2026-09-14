#!/bin/bash
# Teil 3: Fairness-Grenze und Tod/Neustart.
cd ~/projects/kernwerk-godot || exit 1
OUT=/tmp/kernwerk-abnahme
run() {
  local mode="$1" seed="$2" jitter="$3" seconds="$4" height="$5" offset="$6" restart="$7"
  local tag="${mode}_h${height}_o${offset}_s${seed}_j${jitter}"
  rm -f "$OUT/shots.jsonl"
  echo "=== RUN $tag (${seconds}s)"
  KW_MODE="$mode" KW_SEED="$seed" KW_JITTER="$jitter" KW_RUN_SECONDS="$seconds" \
    KW_START_HEIGHT="$height" KW_AIM_OFFSET="$offset" KW_RESTART_AFTER_DEATH="$restart" KW_MAX_SHOTS=4 \
    xvfb-run -a -s "-screen 0 430x932x24" godot4 --rendering-driver opengl3 \
    --resolution 430x932 --path . -s qa/mobile_core_loop_probe.gd 2>&1 \
    | grep -E "REPORT|died=|qualities=|frame_ms=|physics/s=|teleport|restart:|SCRIPT ERROR"
  mv "$OUT/shots.jsonl" "$OUT/shots_${tag}.jsonl" 2>/dev/null
  mv "$OUT/run_${mode}_s${seed}_j${jitter}.json" "$OUT/run_${tag}.json" 2>/dev/null
}
# Kontrollfahrer: keine Steuerung -> MUSS abstuerzen (Gegenprobe)
run idle    13071337 0  25 0    0  1
# Fairness-Grenze: Fahrer zielt bewusst daneben
run forward 13071337 0  25 0    90  0
run forward 13071337 0  25 0    130 0
run forward 13071337 0  25 0    200 0
# Hoechste Zone der Schachtdarstellung
run forward 13071337 0  25 18000 0 0
echo "=== fertig"
