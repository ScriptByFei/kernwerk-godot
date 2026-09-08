#!/usr/bin/env python3
"""Tight color-presence check: confirm new label colors present, old absent, in rendered PNGs."""
from PIL import Image
import sys

def count_near(px, w, h, target, tol=12):
    n = 0
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if all(abs(c[i] - target[i]) <= tol for i in range(3)):
                n += 1
    return n

colors = {
    "old_title(212,224,222)": (212, 224, 222),
    "new_title(135,148,145)": (135, 148, 145),
    "old_subtitle(110,133,140)": (110, 133, 140),
    "new_subtitle(120,140,145)": (120, 140, 145),
    "cta(224,235,227)": (224, 235, 227),
}

for path in sys.argv[1:]:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    print("==", path.split("/")[-1], f"{w}x{h}", "==")
    for name, t in colors.items():
        print(f"  {name}: {count_near(px, w, h, t)} px")
