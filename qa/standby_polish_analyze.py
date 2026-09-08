#!/usr/bin/env python3
"""Analyze actual rendered standby screenshots for text luminance/contrast.
Read-only. Prints per-image text-region stats. No writes to repo evidence."""
import sys
from PIL import Image

def lum(c):
    r, g, b = c
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

def analyze(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    # Known label colors from start_menu.gd (pre-composite intent).
    # We search the whole image for pixels near these hues to locate text rows.
    targets = {
        "title":   (212, 224, 222),   # Color(0.83,0.88,0.87)
        "subtitle":(110, 133, 140),   # Color(0.43,0.52,0.55)
        "cta":     (224, 235, 227),   # Color(0.88,0.92,0.89)
    }
    tol = 40
    rows = {k: [] for k in targets}
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            for k, t in targets.items():
                if all(abs(c[i] - t[i]) <= tol for i in range(3)):
                    rows[k].append((x, y))
    print(f"== {path} {w}x{h} ==")
    for k, pts in rows.items():
        if not pts:
            print(f"  {k}: NO pixels found")
            continue
        ys = [p[1] for p in pts]
        xs = [p[0] for p in pts]
        y0, y1 = min(ys), max(ys)
        x0, x1 = min(xs), max(xs)
        # sample luminance of text pixels vs local background
        text_lums = [lum(px[x, y]) for (x, y) in pts]
        # background: sample a horizontal band just above the text block
        bg_lums = []
        band_y = max(0, y0 - 6)
        for x in range(x0, x1 + 1):
            bg_lums.append(lum(px[x, band_y]))
        bg_avg = sum(bg_lums) / len(bg_lums) if bg_lums else 0
        text_avg = sum(text_lums) / len(text_lums)
        contrast = (text_avg - bg_avg) / (bg_avg + 1e-6)
        print(f"  {k}: box=({x0},{y0})-({x1},{y1}) n={len(pts)} "
              f"textLum={text_avg:.1f} bgLum={bg_avg:.1f} relContrast={contrast:+.2f}")

for f in ["390x844-idle.png", "320x568-idle.png", "844x390-idle.png"]:
    analyze("/home/masgi_bot/data/tasks/standby-browser/" + f)
