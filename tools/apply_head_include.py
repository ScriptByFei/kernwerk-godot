#!/usr/bin/env python3
"""Uebertraegt den iOS-Tonblock in die Exportkonfiguration.

Warum es dieses Werkzeug gibt:
`html/head_include` erwartet in Godot 4.6 den WOERTLICHEN HTML-Text, keinen
Dateipfad. Ein Pfad wird unveraendert ins HTML geschrieben, statt eingebettet zu
werden — gemessen am 14.09.2026. Ein mehrzeiliger Block in einer Zeile der
`.cfg` ist aber nicht lesbar und nicht zu pflegen. Deshalb bleibt
`tools/web/ios_audio_head_include.html` die lesbare Quelle, und dieses Skript
schreibt sie als maskierten Text in `export_presets.cfg`.

`tests/web_head_include_test.gd` prueft, dass beide uebereinstimmen. Ohne diese
Pruefung koennte jemand den Block aendern und der Export fiele still auf den
alten Stand zurueck — genau die Fehlerklasse, die hier schon mehrfach Zeit
gekostet hat.

Aufruf: python3 tools/apply_head_include.py
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tools/web/ios_audio_head_include.html"
PRESETS = ROOT / "export_presets.cfg"
TOKEN = 'html/head_include='


def encoded_block() -> str:
    """Der Block so, wie ConfigFile ihn in einer Zeile erwartet.

    Zeilenumbrueche werden zu `\\n`, Anfuehrungszeichen maskiert. Ein
    Zusammenziehen auf eine Zeile waere falsch: der Block enthaelt
    `//`-Kommentare, die dann den Rest der Datei auskommentieren wuerden.
    """
    text = SOURCE.read_text(encoding="utf-8").rstrip("\n")
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def main() -> int:
    if not SOURCE.is_file():
        print(f"FEHLER: {SOURCE} fehlt", file=sys.stderr)
        return 1
    block = encoded_block()
    lines = PRESETS.read_text(encoding="utf-8").splitlines(keepends=True)
    replaced = False
    for index, line in enumerate(lines):
        if line.startswith(TOKEN):
            newline = "\n" if line.endswith("\n") else ""
            lines[index] = f'{TOKEN}"{block}"{newline}'
            replaced = True
            break
    if not replaced:
        print(f"FEHLER: {TOKEN} nicht in {PRESETS} gefunden", file=sys.stderr)
        return 1
    PRESETS.write_text("".join(lines), encoding="utf-8")
    print(f"head_include gesetzt ({len(block)} Zeichen aus {SOURCE.name})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
