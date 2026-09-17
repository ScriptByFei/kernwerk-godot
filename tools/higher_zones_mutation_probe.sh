#!/usr/bin/env bash
# Mutationsprobe fuer die neuen Zonen 4/5.
#
# Eine gruene Suite beweist nichts, solange nicht belegt ist, dass sie auf
# Fehler reagiert. Jede Mutation hier ist ein echter Defekt, den der Test
# erkennen MUSS. Faellt eine Mutation durch, ist der Test blind.
#
# LEHRE AUS DEM ERSTEN LAUF (17.09.2026): die erste Fassung sicherte die Datei in
# EINE temporaere Datei und loeschte sie beim ersten `restore`. Ab der zweiten
# Mutation schlug jedes Zurueckschreiben still fehl (`cp: cannot stat`), die Datei
# blieb mutiert — und weil alle Mutationen dieselbe Fehlerzahl zeigten, sah das
# Ergebnis wie "9 von 9 erkannt" aus. Es war wertlos.
# Drei Gegenmittel sind jetzt eingebaut:
#   1. Sicherung in ein VERZEICHNIS, das bis zum Ende bestehen bleibt.
#   2. `set -e`-artige Pruefung: jede Mutation bricht ab, wenn die Ersetzung
#      nicht wirklich gegriffen hat (grep-Gegenprobe).
#   3. HARTE Erwartung je Mutation: nicht "irgendwie rot", sondern rot MIT einer
#      anderen Zahl als der vorigen Mutation. Mehrere Mutationen, die dieselbe
#      Zahl melden, sind ein Hinweis auf einen kaputten Aufbau, nicht auf Erfolg.
set -uo pipefail
cd "$(dirname "$0")/.."

TARGET=scripts/jump/shaft_background.gd
TEST=tests/higher_zones_test.gd
WORK=$(mktemp -d)
cp "$TARGET" "$WORK/original.gd"
restore() { cp "$WORK/original.gd" "$TARGET"; }
cleanup() { restore; rm -rf "$WORK"; }
trap cleanup EXIT

run_test() {
  timeout 180 godot4 --headless --audio-driver Dummy --path . -s "$TEST" 2>&1 | grep "HIGHER ZONES" | tail -1
}

# Wendet eine Ersetzung an und prueft, dass sie gegriffen hat.
apply_patch() {
  local before="$1" after="$2"
  python3 - "$TARGET" "$before" "$after" <<'PY'
import sys, pathlib
path, before, after = sys.argv[1], sys.argv[2], sys.argv[3]
p = pathlib.Path(path)
s = p.read_text()
if before not in s:
    print("MUSTER NICHT GEFUNDEN", file=sys.stderr)
    sys.exit(2)
p.write_text(s.replace(before, after, 1))
PY
  if [ $? -ne 0 ]; then
    echo "  ABBRUCH: Ersetzung hat nicht gegriffen — Probe waere wertlos"
    exit 2
  fi
}

echo "=== Basiszustand (muss gruen sein) ==="
base=$(run_test)
echo "  $base"
if ! echo "$base" | grep -q "0 failures"; then
  echo "ABBRUCH: Basis ist nicht gruen, die Probe kann nichts beweisen."
  exit 2
fi
baseline_checks=$(echo "$base" | sed -n 's/^HIGHER ZONES: \([0-9]*\) checks.*/\1/p')

declare -a RESULTS=()
pass=0
fail=0
declare -A SEEN

run_case() {
  local label="$1"
  local out
  out=$(run_test)
  local failures
  failures=$(echo "$out" | sed -n 's/.* \([0-9]*\) failures.*/\1/p')
  if [ "${failures:-0}" = "0" ]; then
    echo "  DURCHGELASSEN (Test blind): $label"
    fail=$((fail+1))
  else
    echo "  erkannt: $label  [$out]"
    pass=$((pass+1))
    SEEN[$failures]=1
  fi
  restore
}

# --- M1: Fensterlogik der Zone 4 entfernen -----------------------------------
apply_patch 'return layer_opacity(zone_index, Z4_FADE_IN_START, Z4_FADE_IN_END, Z4_FADE_OUT_START, Z4_FADE_OUT_END)' 'return 1.0'
run_case "M1 Zone-4-Fenster entfernt (immer voll sichtbar)"

# --- M2: Kreuzblendung hat eine Luecke ---------------------------------------
apply_patch 'const Z5_FADE_IN_START := 3.55' 'const Z5_FADE_IN_START := 4.00'
run_case "M2 Zone-5-Einblendung verschoben (Kreuzblendung mit Luecke)"

# --- M3: Zone 5 blendet oben aus (der Index erreicht 4.0) --------------------
apply_patch 'return layer_opacity(zone_index, Z5_FADE_IN_START, Z5_FADE_IN_END, Z5_FADE_OUT_START, Z5_FADE_OUT_END)' 'return layer_opacity(zone_index, Z5_FADE_IN_START, Z5_FADE_IN_END, 3.90, 4.00)'
run_case "M3 Zone 5 blendet oben aus"

# --- M4: Plattenverschiebung entarten ----------------------------------------
apply_patch 'return tilt if posmod(n + row, 2) == 0 else -tilt' 'return tilt'
run_case "M4 alle Platten gleich verschoben (Entartungsfall)"

# --- M5: Feld ragt in die Ruhezone -------------------------------------------
apply_patch 'const Z4_FIELD_WIDTH := 250.0' 'const Z4_FIELD_WIDTH := 420.0'
run_case "M5 Zone-4-Feld ragt in die Ruhezone"

# --- M6: Gefahrenband als Block statt Schraege -------------------------------
apply_patch 'out.append(_diagonal_quad(
			Vector2(x + offset, y + height),
			Vector2(x + offset - height, y),
			thickness))' 'out.append(PackedVector2Array([
			Vector2(x + offset, y),
			Vector2(x + offset + height, y),
			Vector2(x + offset + height, y + thickness),
			Vector2(x + offset, y + thickness)]))'
run_case "M6 Gefahrenband ist ein Block statt einer Schraege"

# --- M7: Zone 4 beginnt zu frueh (belegt die Luecke fuer Zone 3) -------------
apply_patch 'const Z4_FADE_IN_START := 2.55' 'const Z4_FADE_IN_START := 1.55'
run_case "M7 Zone 4 beginnt zu frueh"

# --- M8: Flaeche zu hell (1.81-Regel verletzt) -------------------------------
apply_patch 'const Z5_PLATE := Color("171410")' 'const Z5_PLATE := Color("4a3a1c")'
run_case "M8 Zone-5-Flaeche zu hell"

# --- M9: Akzent heller als der Spielerkern -----------------------------------
apply_patch 'const Z5_STROBE := Color("7a5a28")' 'const Z5_STROBE := Color("fff0c0")'
run_case "M9 Notlicht heller als der Spielerkern"

# --- M10: Zone 5 faellt nach oben ab (Monotonie) -----------------------------
apply_patch 'const Z5_FADE_IN_END := 4.00' 'const Z5_FADE_IN_END := 3.70'
run_case "M10 Zone 5 ist nicht voll, wenn der Index deckelt"

echo
echo "=== Ergebnis ==="
echo "  Mutationen erkannt : $pass"
echo "  blinde Stellen     : $fail"
echo "  verschiedene Fehlerzahlen: ${#SEEN[@]} (waeren ALLE Mutationen gleich,"
echo "  waere das ein Hinweis auf einen kaputten Aufbau, nicht auf Erfolg)"
# Die Bedingung war zuerst ">= 4 verschiedene Fehlerzahlen" — bei 10 Mutationen
# sind aber 3 verschiedene voellig normal, und der Lauf endete dadurch mit
# exit=1 OHNE Urteilszeile. Ein Pruefskript, das weder Erfolg noch Fehler
# meldet, ist unbrauchbar: der Aufrufer kann den Exit-Code nicht deuten.
# Verlangt wird jetzt das, was wirklich zaehlt: keine blinde Stelle UND nicht
# ueberall dieselbe Zahl (sonst misst der Aufbau etwas anderes als die Mutation).
if [ "$fail" -eq 0 ] && [ "${#SEEN[@]}" -ge 2 ]; then
  echo "ALLE MUTATIONEN ERKANNT"
  exit 0
fi
if [ "$fail" -ne 0 ]; then
  echo "BLINDE STELLEN VORHANDEN"
else
  echo "UNBRAUCHBAR: jede Mutation meldet dieselbe Fehlerzahl — der Aufbau misst"
  echo "nicht den Unterschied zwischen den Mutationen."
fi
exit 1
