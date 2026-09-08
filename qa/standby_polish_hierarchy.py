#!/usr/bin/env python3
"""Measure actual rendered luminance of title text vs reactor core in after_final renders.
Confirms title no longer outshines the reactor."""
from PIL import Image
import sys

def lum(c):
    r, g, b = c
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

def measure(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    # Title text: new color (135,148,145) tol 20
    title = []
    tgt = (135, 148, 145)
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if all(abs(c[i] - tgt[i]) <= 20 for i in range(3)):
                title.append(lum(c))
    # Reactor orange
    orange = []
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if r > 150 and 40 < g < 200 and b < 120 and r > g > b:
                orange.append(lum((r, g, b)))
    t_avg = sum(title) / len(title) if title else 0
    t_max = max(title) if title else 0
    o_avg = sum(orange) / len(orange) if orange else 0
    o_max = max(orange) if orange else 0
    print(f"{path.split('/')[-1]}: title n={len(title)} avgLum={t_avg:.0f} maxLum={t_max:.0f} | "
          f"reactor n={len(orange)} avgLum={o_avg:.0f} maxLum={o_max:.0f} | "
          f"titleMax<=reactorMax: {t_max <= o_max}")

for p in sys.argv[1:]:
    measure(p)
