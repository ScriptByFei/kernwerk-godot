#!/usr/bin/env python3
"""Baut eine Vergleichstafel der Dive-Rueckmeldung fuer die Abnahme.

Setzt die vier gerenderten Zustaende nebeneinander, mit Beschriftung. Die
Einzelbilder liegen in docs/assets/screenshots/dive_feedback/.

Aufruf: python3 qa/dive_feedback_tafel.py
Ergebnis: docs/assets/screenshots/dive_feedback/tafel.png
"""
from pathlib import Path

SRC = Path("docs/assets/screenshots/dive_feedback")
LABELS = [
    ("01_fall_ohne_dive.png", "ohne Dive"),
    ("02_dive_langsam.png", "Dive, langsam"),
    ("03_dive_schnell.png", "Dive, schnell"),
    ("04_nach_landung.png", "nach der Landung"),
]


def main() -> None:
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        raise SystemExit("Pillow fehlt: pip install pillow")

    shots = []
    for name, label in LABELS:
        path = SRC / name
        if not path.exists():
            raise SystemExit(f"fehlt: {path}")
        shots.append((Image.open(path).convert("RGB"), label))

    # Alle Bilder muessen dieselbe Groesse haben, sonst ist der Vergleich wertlos.
    sizes = {image.size for image, _ in shots}
    if len(sizes) != 1:
        raise SystemExit(f"ungleiche Groessen: {sizes}")
    width, height = shots[0][0].size

    # Ausschnitt um den Kern: die Rueckmeldung sitzt in der Bildmitte.
    scale = 0.5
    crop_w, crop_h = int(width * scale), int(height * scale)
    left = (width - crop_w) // 2
    top = int(height * 0.22)
    top = min(top, height - crop_h)

    bar = 34
    gap = 10
    canvas = Image.new("RGB", (crop_w * 4 + gap * 5, crop_h + bar + gap * 2), (14, 16, 20))
    draw = ImageDraw.Draw(canvas)
    for index, (image, label) in enumerate(shots):
        tile = image.crop((left, top, left + crop_w, top + crop_h))
        x = gap + index * (crop_w + gap)
        canvas.paste(tile, (x, bar + gap))
        draw.text((x + 6, 11), label, fill=(230, 230, 230))
    out = SRC / "tafel.png"
    canvas.save(out)
    print(f"GESCHRIEBEN {out} ({canvas.size[0]}x{canvas.size[1]})")


if __name__ == "__main__":
    main()
