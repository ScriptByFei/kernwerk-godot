#!/usr/bin/env bash
# Mutationsprobe zu den Review-Befunden (19.09.2026).
#
# Eine Pruefung, die den Fehler nicht faengt, ist keine Pruefung. Diese Probe
# baut die drei gefundenen Fehler kurz wieder ein und prueft, dass die
# Regression anschlaegt. Bleibt sie gruen, ist sie wertlos.
#
# WARUM DIE MUTATIONEN IN EINEM TEMPORAEREN ZWEIG LAUFEN:
# die erste Fassung hat das Arbeitsverzeichnis beschaedigt — zweimal. Die neuen
# Dateien sind noch nicht committet, `git checkout` kann sie nicht
# wiederherstellen, und weil die Sicherung erst NACH einer kaputten Mutation
# gelesen wurde, hat die Probe ihren eigenen Pruefstand vergiftet und danach
# "Mutation ueberlebt" gemeldet, obwohl die Mutation nie gesetzt worden war.
#
# Diese Fassung fasst das Arbeitsverzeichnis deshalb GAR NICHT an: sie kopiert
# die beteiligten Dateien in eine temporaere Kopie des Projekts und mutiert nur
# dort. Ein Fehlschlag kann nichts hinterlassen, was hinterher von Hand
# repariert werden muesste.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

SOURCE="$(pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

JUMPER=scripts/jump/jumper.gd
DIVE=scripts/jump/dive_input.gd
failures=0

echo "MUTATIONSPROBE: Review-Befunde (19.09.2026)"
echo "Arbeitsstand: $SOURCE (wird nicht angetastet)"
echo "Mutationen laufen in: $WORK"
echo

# Nur was Godot zum Laden braucht — kein vollstaendiger Klon, aber genug fuer
# die beiden Pruefungen. `.godot` wird mitgenommen, sonst importiert Godot jedes
# Asset neu und der Lauf dauert unnoetig lange.
mkdir -p "$WORK"
for entry in project.godot .godot scripts tests qa assets tools; do
	[ -e "$SOURCE/$entry" ] && cp -r "$SOURCE/$entry" "$WORK/" 2>/dev/null
done
[ -e "$WORK/project.godot" ] || { echo "ABBRUCH: Kopie unvollstaendig"; exit 1; }

# Die VOLLE Ausgabe, nicht die letzten Zeilen: bei vielen Fehlschlaegen fiel die
# gesuchte Meldung sonst aus dem Ausschnitt und die Probe meldete faelschlich
# "ueberlebt" (gemessen: Mutation 3 und 9).
run_test() {
	timeout 240 godot4 --headless --audio-driver Dummy --path "$WORK" -s "$1" 2>&1 \
		| grep -v "^Godot"
}

# Fuehrt eine Pruefung im UNVERAENDERTEN Stand aus und verlangt 0 Fehler. Damit
# ist belegt, dass die Kopie fuer sich lauffaehig ist und ein spaeteres FAIL
# wirklich von der Mutation kommt.
sanity() {
	local output
	output=$(run_test "$1")
	if echo "$output" | grep -qE " 0 failures"; then
		echo "  GRUEN (unveraendert)  $1"
		return 0
	fi
	echo "  ABBRUCH: die Kopie besteht die Pruefung schon ohne Mutation nicht"
	echo "           $(echo "$output" | grep -E "checks|failure" | head -1)"
	return 1
}

# `expected` ist der Text der Pruefung, die den Fehler fangen MUSS.
#
# WARUM NICHT NUR "irgendein Fehler": eine Pruefung, die irgendeinen
# Fehlschlag akzeptiert, meldet "erkannt", auch wenn ein voellig anderer
# Fehlschlag kommt — die Regression selbst ist dann unbewiesen. Genau das war
# die Schwaeche der vorigen Fassung (Review 3 hat sie nachgewiesen).
check_mutation() {
	local name="$1" test="$2" expected="$3"
	local output
	output=$(run_test "$test")
	if echo "$output" | grep -qF "$expected"; then
		echo "  ERKANNT   $name"
		echo "            $expected"
	else
		echo "  UEBERLEBT $name  <-- die erwartete Pruefung schlaegt NICHT an"
		echo "            erwartet: $expected"
		echo "            bekommen: $(echo "$output" | grep -E "FAIL|failures" | head -2 | tr '\n' ' ')"
		failures=$((failures + 1))
	fi
	cp "$SOURCE/$JUMPER" "$WORK/$JUMPER"
	cp "$SOURCE/$DIVE" "$WORK/$DIVE"
}

# Ersetzt genau ein Vorkommen in der KOPIE. Bricht laut ab, wenn der Anker
# fehlt — ein still wirkungsloses Ersetzen wuerde als "Mutation ueberlebt"
# fehlgedeutet.
mutate() {
	local path="$1" old="$2" new="$3"
	python3 - "$WORK/$path" "$old" "$new" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path).read()
if old not in s:
	print("ANKER FEHLT in %s" % path)
	sys.exit(3)
open(path, "w").write(s.replace(old, new, 1))
PY
	if [ $? -ne 0 ]; then
		echo "  ABBRUCH: Mutation konnte nicht gesetzt werden"
		failures=$((failures + 1))
		return 1
	fi
	return 0
}

sanity tests/gameplay_redesign_test.gd || exit 1
sanity tests/dive_test.gd || exit 1
echo

echo "Befund 1: PERFECT-Boost hebt den Scheitel statt das Tempo"
if mutate "$JUMPER" "_pending_overload, _perfect_boost_flight)" "_pending_overload, _perfect_boost_armed)"; then
	check_mutation "Gravitation liest das beim Absprung geloeschte Flag" tests/gameplay_redesign_test.gd \
		"die PERFECT-Landung aendert die Spruenge nicht in der Hoehe"
fi

echo
echo "Befund 2: die Dominanzpruefung fehlt ganz"
# Ohne sie feuert jeder breite diagonale Zug als Dive.
if mutate "$DIVE" \
	"	if measurement.down < measurement.sideways * dominance:
		return false" \
	"	if false:
		return false"; then
	check_mutation "Breite Diagonale wird nicht abgewiesen" tests/dive_test.gd \
		"ein breiter diagonaler Zug loest nicht aus"
fi

echo
echo "Befund 3: Flick ueber den Fensterwechsel geht verloren"
if mutate "$DIVE" \
	"	_prune(now - max_time)" \
	"	_head = 0
	_count = 0"; then
	check_mutation "Fenster verwirft alle vorherige Bewegung" tests/dive_test.gd \
		"ein Flick ueber die Fenstergrenze loest aus"
fi

echo
echo "Befund 6 (Review 2): senkrecht wird als BETRAG gezaehlt"
# Damit loest auch ein Wisch nach OBEN aus — der Kern fiele beim Hochziehen
# beschleunigt nach unten.
if mutate "$DIVE" \
	"down += maxf(delta.y, 0.0) * weight" \
	"down += absf(delta.y) * weight"; then
	check_mutation "Aufwaerts-Wisch loest aus" tests/dive_test.gd \
		"der Aufwaerts-Wisch hat genug Proben"
fi

echo
echo "Befund 7 (Review 2): der Puffer ist zu klein fuer hohe Ereignisraten"
# 48 Proben decken das 0,30-s-Fenster nur bis 160 Hz ab.
if mutate "$DIVE" \
	"const CAPACITY := 256" \
	"const CAPACITY := 48"; then
	check_mutation "hohe Rate wirft den halben Flick weg" tests/dive_test.gd \
		"auch ein Flick ueber das ganze Fenster wird bei jeder Rate erkannt"
fi

echo
echo "Befund 4 (Review 2): die Integration ignoriert den Boost"
# `current_gravity` meldet den Boost korrekt, aber `apply_gravity` fragt die
# Konfiguration direkt ohne Boost — der Getter stimmt, die Flugbahn nicht.
if mutate "$JUMPER" \
	"velocity.y += current_gravity() * delta" \
	"velocity.y += JumpConfig.pace_gravity(_held_charges(), _pending_overload, false) * delta"; then
	check_mutation "die Flugbahn ignoriert den Boost (Getter luegt)" tests/gameplay_redesign_test.gd \
		"der geboostete Flug ist wirklich kuerzer"
fi

echo
echo "Befund 5 (Review 2): die Landung macht den Boost nicht scharf"
if mutate "$JUMPER" \
	"	if last_landing_quality == JumpConfig.LandingQuality.PERFECT:
		_perfect_boost_armed = true" \
	"	if false:
		_perfect_boost_armed = true"; then
	check_mutation "PERFECT-Landung ohne Wirkung" tests/gameplay_redesign_test.gd \
		"der Sprung nach PERFECT ist wirklich schneller"
fi

echo
echo "Befund 8 (Review 3): senkrecht wird nur AUFSUMMIERT gezaehlt"
# Ohne die Netto-Bedingung kommt ein zitternder Daumen auf 80 px Strecke nach
# unten und loest aus, obwohl er nur 21 px tiefer endet.
if mutate "$DIVE" \
	"	if measurement.rise < min_distance * NET_FRACTION:
		return false" \
	"	if false:
		return false"; then
	check_mutation "Netto-Bedingung fehlt (Zittern feuert)" tests/dive_test.gd \
		"ein senkrechtes Zittern loest nicht aus"
fi

echo
echo "Befund 9 (Review 3): waagerecht wieder MIT RAUSCHSCHWELLE je Abschnitt"
# ZWEI Ersetzungen, und beide muessen genau das nachgewiesene Loch einbauen:
# eine Schwelle JE ABSCHNITT (statt auf der Netto-Verschiebung). Nur so traegt
# ein Zickzack mit kleinen waagerechten Stuecken nichts bei, waehrend seine
# senkrechten Stuecke sich aufaddieren.
#
# Die naheliegende Einzel-Ersetzung `sideways = sideways_path` ist FALSCH: eine
# rohe Summe ist STRENGER als netto (|Summe| <= Summe der Betraege) und lehnt
# einen monotonen Diagonalzug ab, statt ihn durchzulassen. Genau daran sind
# meine ersten beiden Fassungen gescheitert — sie meldeten "ueberlebt", obwohl
# die Mutation das Loch gar nicht wieder einbaute (Review 4 hat das an einer
# Fassung nachgewiesen, die die Netto-Zuweisung auf 0 setzte und damit die
# Dominanz stilllegte).
if mutate "$DIVE" \
	"		sideways_path += absf(delta.x) * weight" \
	"		sideways_path += absf(delta.x) * weight
		sideways += maxf(absf(delta.x) - jitter_tolerance, 0.0) * weight"; then
	if mutate "$DIVE" \
		"	sideways = maxf(absf(last_x - window_start.x) - jitter_tolerance, 0.0)" \
		"	# Mutation: Netto-Zuweisung entfernt, es gilt die Abschnitts-Summe"; then
		check_mutation "Rauschschwelle je Abschnitt (breite Diagonale feuert)" tests/dive_test.gd \
			"ein breiter Diagonalzug wird auch in kleinen Stuecken abgewiesen"
	fi
fi

echo "Befund 11 (Optik): die Rueckmeldung haengt nicht am Dive"
# Ohne diese Kopplung bliebe die Aura dauerhaft sichtbar oder dauerhaft aus.
if mutate "$JUMPER" \
	"	if not _dive_active:
		return 1.0" \
	"	if false:
		return 1.0"; then
	check_mutation "Aura auch ohne Dive gestreckt" tests/dive_test.gd \
		"und die Aura ist ungestreckt"
fi

echo
echo "Befund 12 (Optik): Deckkraft ohne Dive nicht null"
if mutate "$JUMPER" \
	"func dive_glow_alpha() -> float:
	if not _dive_active:
		return 0.0" \
	"func dive_glow_alpha() -> float:
	if false:
		return 0.0"; then
	check_mutation "Aura bleibt ohne Dive sichtbar" tests/dive_test.gd \
		"nach dem Dive ist die Aura wieder weg"
fi

echo
echo "Befund 10 (Review 4): Fensterstart nicht interpoliert"
# `rise` und die waagerechte Netto-Verschiebung rechnen wieder gegen die
# abgelaufene Randprobe, obwohl die Strecken beschnitten sind.
if mutate "$DIVE" \
	"	sideways = maxf(absf(last_x - window_start.x) - jitter_tolerance, 0.0)" \
	"	sideways = maxf(absf(last_x - first_x) - jitter_tolerance, 0.0)"; then
	if mutate "$DIVE" \
		'"rise": last_y - window_start.y,' \
		'"rise": last_y - first_y,'; then
		check_mutation "Fensterstart nicht interpoliert" tests/dive_test.gd \
			"ein Zug, der ueber seinem Fensterstart endet, loest nicht aus"
	fi
fi

echo
if [ "$failures" -eq 0 ]; then
	echo "ERGEBNIS: alle 12 Mutationen erkannt"
	exit 0
fi
echo "ERGEBNIS: $failures Mutation(en) ueberlebt"
exit 1
