#!/usr/bin/env bash
# Mutation probe for the jump-feel change (20.09.2026).
#
# The change alters TWO numbers that only make sense together: a softer gravity
# with a bounce force tuned to it. A green suite does not prove that pairing —
# several mutations below stay green in the suites on purpose, because they change
# the feel without breaking reachability. Those are the ones this probe must catch
# through the FEEL probe (qa/loop_feel_probe.gd), which measures the real flight.
#
# Same discipline as the other probes in this project:
#  - backup in a DIRECTORY that survives every iteration
#  - pattern counter-check per substitution (abort on anything but exactly one hit)
#  - every restore verified before the next mutation runs
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/scripts/jump/jump_config.gd"
BACKUP_DIR="$(mktemp -d)"
cp "$CONFIG" "$BACKUP_DIR/jump_config.gd"
ORIGINAL_SHA="$(sha256sum "$CONFIG" | cut -d' ' -f1)"
trap 'cp "$BACKUP_DIR/jump_config.gd" "$CONFIG"; rm -rf "$BACKUP_DIR"' EXIT

restore() { cp "$BACKUP_DIR/jump_config.gd" "$CONFIG"; }

# Flight time of the calm step (0/3) and the apex reserve, from the real probe.
feel() {
	xvfb-run -a -s "-screen 0 430x932x24" godot4 --rendering-driver opengl3 \
		--resolution 430x932 --path "$ROOT" -s qa/loop_feel_probe.gd 2>&1
}

flight_seconds() {
	feel | grep -E '^\s+0/3' | sed -E 's/.*: ([0-9.]+) s.*/\1/'
}

reserve_px() {
	feel | grep 'Reserve:' | sed -E 's/.*Reserve: ([+-][0-9]+) px.*/\1/'
}

mutate() {
	local label="$1" old="$2" new="$3" hits
	hits=$(grep -c -F -- "$old" "$CONFIG" || true)
	if [ "$hits" -ne 1 ]; then
		echo "ABORT: pattern for '$label' matched $hits times (expected 1)"
		exit 2
	fi
	python3 - "$CONFIG" "$old" "$new" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(text.replace(old, new, 1))
PY
}

BASE_FLIGHT="$(flight_seconds)"
BASE_RESERVE="$(reserve_px)"
echo "Kontrolle: 0/3 Flug ${BASE_FLIGHT}s, Reserve ${BASE_RESERVE}px"
echo
detected=0
total=0

report() {
	local label="$1" expect="$2" got="$3" ok="$4"
	total=$((total + 1))
	if [ "$ok" = "1" ]; then
		printf '%-52s %s (%s)\n' "$label" "erkannt" "$got"
		detected=$((detected + 1))
	else
		printf '%-52s NICHT ERKANNT (%s, erwartet %s)\n' "$label" "$got" "$expect"
		restore
		exit 3
	fi
	restore
	if [ "$(sha256sum "$CONFIG" | cut -d' ' -f1)" != "$ORIGINAL_SHA" ]; then
		echo "  ABORT: Wiederherstellung hat nicht gegriffen"
		exit 4
	fi
}

# M1: bounce force alone -> the jump gets LOWER, flight shorter. Reachability
# suites stay green (the apex is still above the widest step), so only the feel
# probe sees it: it must report a shorter flight than the baseline.
mutate "M1 nur die Kraft senken (-8 %)" 'const BASE_BOUNCE_SPEED := 1906.0' 'const BASE_BOUNCE_SPEED := 1754.0'
got="$(flight_seconds)"
report "M1 nur die Kraft senken (-8 %)" "<$BASE_FLIGHT" "$got s" "$(python3 -c "print(1 if float('$got') < float('$BASE_FLIGHT') else 0)")"

# M2: gravity alone -> softer, HIGHER, longer flight. The reachability suites stay
# green (the reserve even grows); the feel probe must catch that it is no longer
# the calibrated pair.
mutate "M2 nur die Gravitation senken (-12 %)" 'const GRAVITY := 3304.0' 'const GRAVITY := 2908.0'
got="$(reserve_px)"
report "M2 nur die Gravitation senken (-12 %)" ">$BASE_RESERVE" "$got px" "$(python3 -c "print(1 if int('$got') > int('$BASE_RESERVE') else 0)")"

# M3: gravity raised back to the old value but force left soft -> the apex must
# fall below what the widest step needs. Here the SUITE has to go red, so this one
# is checked through the unit test, not the feel probe.
mutate "M3 alte Gravitation, weiche Kraft" 'const GRAVITY := 3304.0' 'const GRAVITY := 3887.0'
out="$(godot4 --headless --audio-driver Dummy --path "$ROOT" -s tests/gameplay_director_test.gd 2>&1 || true)"
red="$(printf '%s' "$out" | grep -cE 'failures' || true)"
if printf '%s' "$out" | grep -qE 'GAMEPLAY DIRECTOR: [0-9]+ checks, 0 failures'; then
	report "M3 alte Gravitation, weiche Kraft" "Suite rot" "Suite blieb gruen" "0"
else
	report "M3 alte Gravitation, weiche Kraft" "Suite rot" "Suite rot" "1"
fi

echo
FINAL_SHA="$(sha256sum "$CONFIG" | cut -d' ' -f1)"
if [ "$FINAL_SHA" != "$ORIGINAL_SHA" ]; then
	echo "FAIL: Datei ist nach der Probe nicht im Originalzustand"
	exit 5
fi
echo "OK: $detected von $total Mutationen erkannt, Datei unveraendert (sha256 ${FINAL_SHA:0:12})"
exit 0
