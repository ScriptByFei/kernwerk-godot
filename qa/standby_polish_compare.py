#!/usr/bin/env python3
"""Compare text luminance/contrast between before (browser) and after_final (rendered).
Read-only analysis of evidence PNGs."""
from PIL import Image

def lum(c):
    r, g, b = c
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

def analyze(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    targets = {
        "title":   (212, 224, 222),
        "subtitle":(110, 133, 140),
        "cta":     (224, 235, 227),
    }
    tol = 40
    rows = {k: [] for k in targets}
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            for k, t in targets.items():
                if all(abs(c[i] - t[i]) <= tol for i in range(3)):
                    rows[k].append((x, y))
    out = {}
    for k, pts in rows.items():
        if not pts:
            out[k] = None
            continue
        ys = [p[1] for p in pts]
        xs = [p[0] for p in pts]
        y0, y1 = min(ys), max(ys)
        x0, x1 = min(xs), max(xs)
        text_lums = [lum(px[x, y]) for (x, y) in pts]
        bg_lums = []
        band_y = max(0, y0 - 6)
        for x in range(x0, x1 + 1):
            bg_lums.append(lum(px[x, band_y]))
        bg_avg = sum(bg_lums) / len(bg_lums) if bg_lums else 0
        text_avg = sum(text_lums) / len(text_lums)
        contrast = (text_avg - bg_avg) / (bg_avg + 1e-6)
        out[k] = {"textLum": round(text_avg, 1), "bgLum": round(bg_avg, 1),
                  "relContrast": round(contrast, 2), "box": (x0, y0, x1, y1)}
    return out

import sys
for f in sys.argv[1:]:
    print("==", f, "==")
    r = analyze(f)
    for k, v in r.items():
        print(f"  {k}: {v}")
