#!/usr/bin/env bash
# Mutationsprobe fuer die Facility-Struktur.
#
# Warum als Skript: die Probe muss die Datei mutieren, die Suite fahren und
# zurueckschreiben. Zwei Fallen sind hier schon passiert und werden vermieden:
#   1. Sicherung in EINE temporaere Datei, die beim ersten restore geloescht wird
#      -> ab der zweiten Mutation schlaegt jedes Zurueckschreiben still fehl und
#      alle Mutationen melden dieselbe Fehlerzahl ("9 von 9 erkannt", obwohl die
#      Datei mutiert liegen blieb). Deshalb: ein VERZEICHNIS, das bis zum Ende
#      besteht.
#   2. Eine Mutation, die das Muster nicht trifft, "besteht" die Probe, ohne etwas
#      zu aendern. Deshalb: Muster-Gegenprobe je Ersetzung, Abbruch bei Null-Treffern.
# Und die Auswertung verlangt UNTERSCHIEDLICHE Fehlerzahlen, nicht nur "irgendwie rot".
set -u
cd "$(dirname "$0")/.."
TARGET="scripts/jump/shaft_background.gd"
SUITE="tests/facility_structure_test.gd"
WORK="$(mktemp -d)"
cp "$TARGET" "$WORK/orig.gd"
trap 'cp "$WORK/orig.gd" "$TARGET"; rm -rf "$WORK"' EXIT

run_suite() {
  timeout 200 godot4 --headless --audio-driver Dummy --path . -s "$SUITE" 2>&1 \
    | grep -oE "FACILITY STRUCTURE: [0-9]+ checks, [0-9]+ failures" \
    | grep -oE "[0-9]+ failures" | grep -oE "[0-9]+"
}

fail() { echo "ABBRUCH: $1"; cp "$WORK/orig.gd" "$TARGET"; exit 2; }

apply() {  # $1=label $2=from $3=to
  cp "$WORK/orig.gd" "$TARGET"
  local hits
  hits=$(python3 - "$TARGET" "$2" "$3" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path).read()
n = s.count(old)
if n == 1:
    open(path, "w").write(s.replace(old, new))
print(n)
PY
)
  [ "$hits" = "1" ] || fail "$1: Muster traf $hits mal (nicht 1)"
}

echo "=== Kontrolle (unmutiert) ==="
BASE=$(run_suite)
[ "$BASE" = "0" ] || fail "Kontrolle ist nicht gruen ($BASE failures)"
echo "Kontrolle: $BASE failures"

declare -a LABELS=() COUNTS=()
probe() {  # $1=label $2=from $3=to
  apply "$1" "$2" "$3"
  local c
  c=$(run_suite)
  LABELS+=("$1"); COUNTS+=("$c")
  echo "  $1 -> $c failures"
}

echo "=== Mutationen ==="
probe "Anlage ueberall aus" \
  'static func facility_opacity_for_zone(zone_index: float) -> float:
	if zone_index <= ZONE_FADE_START:
		return 0.0' \
  'static func facility_opacity_for_zone(zone_index: float) -> float:
	if true:
		return 0.0'
probe "Anlage blendet in Zone 3 wieder aus" \
  '	if zone_index >= ZONE_FADE_START + FM_FADE_RAMP:
		return 1.0' \
  '	if zone_index >= ZONE_FADE_START + FM_FADE_RAMP:
		return 0.0 if zone_index > 2.2 else 1.0'
probe "Traegerachsen in die Ruhezone geschoben" \
  '	out.append(Rect2(left, top, 16.0, FM_BAY))
	out.append(Rect2(width - left - 16.0, top, 16.0, FM_BAY))' \
  '	out.append(Rect2(width * 0.5 - 40.0, top, 16.0, FM_BAY))
	out.append(Rect2(width * 0.5 + 24.0, top, 16.0, FM_BAY))'
probe "Paneelfelder in die Ruhezone gezogen" \
  '	var fields := [Vector2(left + 26.0, left + 134.0), right_field]' \
  '	var fields := [Vector2(width * 0.5 - 120.0, width * 0.5 + 120.0), right_field]'
probe "Hohlraeume in die Ruhezone gezogen" \
  '		if minf(x_in, x_outer) <= width * 0.5 + QUIET_HALF_WIDTH:
				continue' \
  '		pass'
probe "Uebergaenge an die Weltkoordinate (alter Fehler)" \
  '	var center := -JumpConfig.zone_height_for_index(boundary) + view_height * 0.5
	return int(round(layer_parallax(2) * center / FM_BAY))' \
  '	return int(round(-JumpConfig.zone_height_for_index(boundary) + view_height * 0.5) / FM_BAY)'
probe "Uebergangsslots alle gleich (Entartung)" \
  '	return int(round(layer_parallax(2) * center / FM_BAY))' \
  '	return 0'
probe "Zonenmodule als Tapete (alter Zustand)" \
  'const SECTION_MODULE := FM_BAY' \
  'const SECTION_MODULE := 320.0'
probe "Aktive Flaeche wird heller als der Spielerkern" \
  'const FM_GIRDER_LIT := Color("39434b")' \
  'const FM_GIRDER_LIT := Color("8fa4ad")'
probe "Anlagenraster verkleinert (Kontinuitaet weg)" \
  'const FM_BAY := 760.0' \
  'const FM_BAY := 190.0'
probe "rechte Seite leer (Lamellen entfernt)" \
  '	var out: Array[Rect2] = []
	for fin in range(5):
		out.append(Rect2(body.position + Vector2(10.0, 26.0 + float(fin) * 42.0), Vector2(body.size.x - 20.0, 14.0)))
	return out' \
  '	var out: Array[Rect2] = []
	pass
	return out'

echo "=== Auswertung ==="
DISTINCT=$(printf '%s\n' "${COUNTS[@]}" | sort -u | wc -l)
MISSED=0
for i in "${!LABELS[@]}"; do
  if [ "${COUNTS[$i]}" = "0" ]; then
    echo "NICHT ERKANNT: ${LABELS[$i]}"; MISSED=$((MISSED+1))
  fi
done
echo "Mutationen: ${#LABELS[@]}   nicht erkannt: $MISSED   verschiedene Fehlerzahlen: $DISTINCT"
if [ "$MISSED" -gt 0 ]; then echo "URTEIL: DURCHGEFALLEN"; exit 1; fi
if [ "$DISTINCT" -lt 3 ]; then echo "URTEIL: VERDAECHTIG (alle Mutationen melden dasselbe)"; exit 1; fi
echo "URTEIL: BESTANDEN"
