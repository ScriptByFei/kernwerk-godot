#!/usr/bin/env bash
# Mutation probe for tools/make_splash.py.
#
# A self-test that has never failed proves nothing. Each mutation below breaks one
# real behaviour of the tool and the self-test MUST react — by flagging the named
# check, or by crashing outright (which is the same verdict, just louder).
#
# Two lessons from this project are built in on purpose:
#  - the backup lives in a DIRECTORY that survives every iteration. A single backup
#    FILE was deleted by the first restore once, after which every later write
#    failed silently and the probe reported a false "all detected".
#  - every substitution gets a pattern counter-check (grep -c -F) and aborts on
#    anything but exactly one hit; and after EVERY restore the tool must be green
#    again, which is what proves the restore actually happened.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$ROOT/tools/make_splash.py"
BACKUP_DIR="$(mktemp -d)"
cp "$TOOL" "$BACKUP_DIR/make_splash.py"
ORIGINAL_SHA="$(sha256sum "$TOOL" | cut -d' ' -f1)"
trap 'cp "$BACKUP_DIR/make_splash.py" "$TOOL"; rm -rf "$BACKUP_DIR"' EXIT

restore() { cp "$BACKUP_DIR/make_splash.py" "$TOOL"; }

selftest_output() { python3 "$TOOL" --self-test 2>&1; }

is_green() { [ "$(selftest_output | grep -c '^FAIL')" -eq 0 ] && selftest_output | grep -q 'SELFTEST: OK'; }

mutate() {
	local label="$1" old="$2" new="$3"
	local hits
	hits=$(grep -c -F -- "$old" "$TOOL" || true)
	if [ "$hits" -ne 1 ]; then
		echo "ABORT: pattern for '$label' matched $hits times (expected 1)"
		exit 2
	fi
	python3 - "$TOOL" "$old" "$new" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(text.replace(old, new, 1))
PY
}

if ! is_green; then
	echo "FAIL: Ausgangsstand ist schon rot — die Probe wuerde nichts beweisen"
	exit 1
fi
echo "Kontrolle: Ausgangsstand gruen (sha256 ${ORIGINAL_SHA:0:12})"
echo

declare -a LABELS=() SIGNALS=()
detected=0
total=0

check() {
	local label="$1" expect="$2" mode="$3"
	local output failures
	output="$(selftest_output || true)"
	failures=$(printf '%s\n' "$output" | grep -c '^FAIL' || true)
	total=$((total + 1))
	local verdict=""
	if [ "$mode" = "crash" ]; then
		if printf '%s\n' "$output" | grep -qiE 'Traceback|SELFTEST: FAILED'; then
			verdict="erkannt (Abbruch/Fehler)"
		fi
	elif printf '%s\n' "$output" | grep -qF "FAIL $expect"; then
		verdict="erkannt ('$expect', $failures FAIL-Zeilen)"
	fi
	if [ -z "$verdict" ]; then
		printf '%-44s NICHT ERKANNT (FAIL-Zeilen=%s)\n' "$label" "$failures"
		restore
		exit 3
	fi
	printf '%-44s %s\n' "$label" "$verdict"
	detected=$((detected + 1))
	LABELS+=("$label")
	SIGNALS+=("$expect")

	restore
	if ! is_green; then
		echo "  ABORT: Wiederherstellung hat nicht gegriffen — Datei ist noch mutiert"
		exit 4
	fi
}

mutate "M1 Qualitaetsschranke ausschalten" 'MIN_PSNR_DB = 30.0' 'MIN_PSNR_DB = 99.0'
check "M1 Qualitaetsschranke ausschalten" 'quality above the bound' named

mutate "M2 Groessenschranke verschaerfen" 'MAX_SIZE_RATIO = 0.65' 'MAX_SIZE_RATIO = 0.05'
check "M2 Groessenschranke verschaerfen" 'size ratio inside the bound' named

mutate "M3 Palette zu grob (8 Farben)" 'colors=colors, method=Image.Quantize.MEDIANCUT' 'colors=8, method=Image.Quantize.MEDIANCUT'
check "M3 Palette zu grob (8 Farben)" 'quality above the bound' named

mutate "M4 Paletten-Guard entfernen" 'if original.mode in ("P", "1"):' 'if False and original.mode in ("P", "1"):'
check "M4 Paletten-Guard entfernen" 'palette input is skipped' named

mutate "M5 report-only schreibt doch" 'if report_only:' 'if False:'
check "M5 report-only schreibt doch" 'report-only leaves the file untouched' named

mutate "M6 Bildabmessungen veraendern" 'quantized = rgb.quantize(' 'quantized = rgb.resize((rgb.size[0] // 2, rgb.size[1] // 2)).quantize('
check "M6 Bildabmessungen veraendern" 'dimensions unchanged' crash

echo
echo "=== Ergebnis ==="
if [ "$total" -eq 0 ]; then
	echo "FAIL: keine Mutation gelaufen"
	exit 5
fi
FINAL_SHA="$(sha256sum "$TOOL" | cut -d' ' -f1)"
if [ "$FINAL_SHA" != "$ORIGINAL_SHA" ]; then
	echo "FAIL: Datei ist nach der Probe nicht im Originalzustand ($FINAL_SHA)"
	exit 6
fi
echo "OK: $detected von $total Mutationen erkannt, Datei unveraendert (sha256 ${FINAL_SHA:0:12})"
exit 0
