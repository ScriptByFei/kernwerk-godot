#!/usr/bin/env bash
# Mutationsprobe fuer die ungleichen Zonenhoehen (ZONE_HEIGHT_SPANS).
#
# Sicherung in ein VERZEICHNIS (nicht eine Einzeldatei) und Muster-Gegenprobe je
# Ersetzung — die erste Fassung dieser Probe hatte sich selbst zerstört und
# danach falsch gruen gemeldet. Siehe tools/higher_zones_mutation_probe.sh.
set -uo pipefail
cd "$(dirname "$0")/.."

TARGET=scripts/jump/jump_config.gd
TESTS="tests/height_zone_test.gd tests/higher_zones_test.gd tests/shaft_background_test.gd tests/shaft_composition_test.gd"
WORK=$(mktemp -d)
cp "$TARGET" "$WORK/original.gd"
restore() { cp "$WORK/original.gd" "$TARGET"; }
cleanup() { restore; rm -rf "$WORK"; }
trap cleanup EXIT

run_all() {
  local out=""
  for t in $TESTS; do
    local one
    one=$(timeout 180 godot4 --headless --audio-driver Dummy --path . -s "$t" 2>&1 | grep -E "checks, .* failures" | tail -1)
    out="$out$one; "
  done
  echo "$out"
}

apply_patch() {
  python3 - "$TARGET" "$1" "$2" <<'PY'
import sys, pathlib
path, before, after = sys.argv[1], sys.argv[2], sys.argv[3]
p = pathlib.Path(path); s = p.read_text()
if before not in s:
    print("MUSTER NICHT GEFUNDEN", file=sys.stderr); sys.exit(2)
p.write_text(s.replace(before, after, 1))
PY
  if [ $? -ne 0 ]; then echo "  ABBRUCH: Ersetzung hat nicht gegriffen"; exit 2; fi
}

echo "=== Basiszustand ==="
base=$(run_all); echo "  $base"
echo "$base" | grep -q "failures" || { echo "ABBRUCH: keine Messwerte"; exit 2; }
if echo "$base" | grep -qvE "0 failures; $|0 failures; 0 failures; 0 failures; $"; then
  if echo "$base" | grep -qE "[1-9][0-9]* failures"; then
    echo "ABBRUCH: Basis ist nicht gruen"; exit 2
  fi
fi

pass=0; fail=0; declare -A SEEN
run_case() {
  local label="$1" out failures
  out=$(run_all)
  failures=$(echo "$out" | grep -oE "[0-9]+ failures" | sort -u | tr '\n' ' ')
  if ! echo "$out" | grep -qE "[1-9][0-9]* failures"; then
    echo "  DURCHGELASSEN (Test blind): $label"; fail=$((fail+1))
  else
    echo "  erkannt: $label  [$failures]"; pass=$((pass+1)); SEEN["$failures"]=1
  fi
  restore
}

# M1: letzte Zone bekommt wieder einen Uebergang (Index laeuft rueckwaerts)
apply_patch '		if i == count - 1:
			return float(i)' '		if i == count - 1 and false:
			return float(i)'
run_case "M1 letzte Zone rechnet einen Uebergang (Index laeuft zurueck)"

# M2: blend >= span (kein Plateau mehr)
apply_patch 'const ZONE_BLEND_RANGE := 1200.0' 'const ZONE_BLEND_RANGE := 9000.0'
run_case "M2 Uebergangsbreite groesser als eine Zonenhöhe"

# M3: Zone 1 auf die Groesse der anderen gestaucht (verliert einen Modultyp)
apply_patch 'const ZONE_HEIGHT_SPANS := [8000.0, 4000.0, 4000.0, 4000.0, 4000.0]' 'const ZONE_HEIGHT_SPANS := [4000.0, 4000.0, 4000.0, 4000.0, 4000.0]'
run_case "M3 Zone 1 gleich gross wie die uebrigen"

# M4: zone_floor liefert falsche Unterkanten
apply_patch '	for i in range(clampi(zone, 0, ZONE_HEIGHT_SPANS.size())):
		total += ZONE_HEIGHT_SPANS[i]
	return total' '	return float(zone) * ZONE_HEIGHT_SPANS[0]'
run_case "M4 Zonenunterkanten falsch gerechnet"

# M5: Uebergang auch in der LETZTEN Zone rechnen (Index laeuft ueber den Deckel
# und faellt danach zurueck). Der frueher hier stehende Deckel-Check ist entfallen,
# weil er verhaltensneutral war — die Mutation, die ihn verschob, blieb zu Recht
# gruen. Geprueft wird jetzt das Verhalten, das wirklich zaehlt.
apply_patch '		if i == count - 1:
			return float(i)' '		if i == count - 1 and count < 0:
			return float(i)'
run_case "M5 letzte Zone rechnet einen Uebergang ueber den Deckel hinaus"

echo
echo "=== Ergebnis ==="
echo "  erkannt: $pass   blind: $fail   verschiedene Fehlerbilder: ${#SEEN[@]}"
if [ "$fail" -eq 0 ] && [ "${#SEEN[@]}" -ge 2 ]; then
  echo "ALLE MUTATIONEN ERKANNT"; exit 0
fi
[ "$fail" -ne 0 ] && echo "BLINDE STELLEN VORHANDEN" || echo "UNBRAUCHBAR: ueberall dasselbe Fehlerbild"
exit 1
