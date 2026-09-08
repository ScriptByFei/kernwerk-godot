#!/usr/bin/env python3
"""Measure reactor core (orange) luminance vs title text luminance in idle captures."""
from PIL import Image

def lum(c):
    r, g, b = c
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

def analyze(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    # Orange reactor core: r high, g mid, b low
    orange = []
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if r > 150 and 40 < g < 200 and b < 120 and r > g > b:
                orange.append((x, y, lum((r, g, b))))
    if orange:
        lums = [o[2] for o in orange]
        xs = [o[0] for o in orange]
        ys = [o[1] for o in orange]
        print(f"  reactor-orange: n={len(orange)} box=({min(xs)},{min(ys)})-({max(xs)},{max(ys)}) "
              f"maxLum={max(lums):.0f} avgLum={sum(lums)/len(lums):.0f}")
    else:
        print("  reactor-orange: none")

import sys
for f in sys.argv[1:]:
    print("==", f.split("/")[-1], "==")
    analyze(f)
