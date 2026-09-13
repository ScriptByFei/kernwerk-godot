#!/usr/bin/env python3
"""Reproducible image metrics. Same pixel rules for reference/before/after.

Encoded RGB luminance, NOT linear WCAG. Warm: R>51,R>1.3G,G>1.2B.
Vignette: mean Y(8..25%,75..92%) - mean Y(0..8%,92..100%).
Detail: mean absolute first differences in both axes in the architecture bands,
resampled to 430px width first (LANCZOS, measurement only).
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image


def measure(path):
    image = Image.open(path).convert('RGB')
    a = np.asarray(image, dtype=np.float64)
    r, g, b = a.transpose(2, 0, 1)
    y = a @ np.array([0.2126, 0.7152, 0.0722])
    w = image.width
    warm = (r > 51) & (r > 1.3*g) & (g > 1.2*b)
    outer = np.concatenate([y[:, :round(w*.08)], y[:, round(w*.92):]], axis=1)
    inner = np.concatenate([y[:, round(w*.08):round(w*.25)], y[:, round(w*.75):round(w*.92)]], axis=1)
    small = image.resize((430, round(image.height * 430 / image.width)), Image.Resampling.LANCZOS)
    sy = np.asarray(small, dtype=float) @ np.array([.2126,.7152,.0722])
    details = []
    for band in [sy[:, 34:108], sy[:, 322:396]]:
        details.append((np.abs(np.diff(band, axis=0)).mean()+np.abs(np.diff(band, axis=1)).mean())/2)
    # 4-connected warm components, without morphology/artificial bridging.
    seen = np.zeros(warm.shape, dtype=bool)
    components = []
    for yy, xx in zip(*np.nonzero(warm)):
        if seen[yy, xx]:
            continue
        stack = [(int(yy), int(xx))]
        seen[yy, xx] = True
        xmin = xmax = int(xx)
        ymin = ymax = int(yy)
        count = 0
        while stack:
            cy, cx = stack.pop()
            count += 1
            xmin, xmax = min(xmin,cx), max(xmax,cx)
            ymin, ymax = min(ymin,cy), max(ymax,cy)
            for ny,nx in [(cy-1,cx),(cy+1,cx),(cy,cx-1),(cy,cx+1)]:
                if 0<=ny<warm.shape[0] and 0<=nx<w and warm[ny,nx] and not seen[ny,nx]:
                    seen[ny,nx]=True
                    stack.append((ny,nx))
        if count >= 30 * (w/430)**2:
            components.append({'pixels':count,'box':[xmin,ymin,xmax-xmin+1,ymax-ymin+1]})
    return {'path':str(Path(path).resolve()), 'sha256':hashlib.sha256(Path(path).read_bytes()).hexdigest(),
            'size':list(image.size),'warm_percent':float(warm.mean()*100),
            'luma_p05':float(np.percentile(y,5)), 'luma_mean':float(y.mean()),
            'outer_luma':float(outer.mean()),'architecture_luma':float(inner.mean()),
            'vignette_inner_minus_outer':float(inner.mean()-outer.mean()),
            'edge_detail_430':float(np.mean(details)), 'warm_components':components}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('images',nargs='+')
    parser.add_argument('--out', required=True)
    args=parser.parse_args()
    report={'method':__doc__, 'images':[measure(p) for p in args.images]}
    dest=Path(args.out)
    dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_text(json.dumps(report,indent=2)+'\n')
    for item in report['images']:
        print(Path(item['path']).name, json.dumps({k:v for k,v in item.items() if k not in ['path','sha256','warm_components']}))
        print('large warm components:',len(item['warm_components']))
    print('REPORT',dest)

if __name__=='__main__':
    main()
