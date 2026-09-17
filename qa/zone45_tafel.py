#!/usr/bin/env python3
"""Vergleichstafel der neuen Zonen 4/5 bei echter Geraetegroesse.

Timo beurteilt am Bild. Die Tafel zeigt die drei tragenden Zustaende
nebeneinander, jeweils mit der Deckkraft als Zahl — nur so ist zu sehen, ob die
Kreuzblendung wirklich traegt und ob der Hintergrund hinter dem Spieler dunkel
genug bleibt.
"""
from pathlib import Path

from PIL import Image, ImageDraw

SRC = Path("/tmp/kernwerk-zone45")
OUT = Path("/tmp/kernwerk-zone45/tafel_zone45.png")

SHOTS = [
    ("zone4.png", "Zone 4 voll (3.00): verschobene Platten"),
    ("kreuz-mitte.png", "Kreuzblendung (3.78): Zone4 0.49 / Zone5 0.51"),
    ("zone5.png", "Zone 5 voll (4.00): Gefahrenband, gluehende Naht"),
]

LABEL = 30


def main() -> None:
    images = []
    for name, caption in SHOTS:
        path = SRC / name
        if not path.exists():
            raise SystemExit(f"fehlt: {path}")
        im = Image.open(path).convert("RGB")
        images.append((im, caption))
    width = sum(im.width for im, _ in images) + 20 * (len(images) - 1)
    height = max(im.height for im, _ in images) + LABEL
    canvas = Image.new("RGB", (width, height), (16, 16, 18))
    draw = ImageDraw.Draw(canvas)
    x = 0
    for im, caption in images:
        canvas.paste(im, (x, LABEL))
        draw.text((x + 6, 9), caption, fill=(225, 232, 236))
        x += im.width + 20
    canvas.save(OUT)
    print(OUT, canvas.size)


if __name__ == "__main__":
    main()
