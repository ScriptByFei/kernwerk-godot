"""Side-by-side NORMAL contact: alpha 0.45 (after) vs 0.65 (alpha065)."""
from pathlib import Path
from PIL import Image, ImageDraw
root = Path(__file__).resolve().parents[1] / 'docs/assets/screenshots/core_polish_fix'
def panel(variant, index, label, crop=None, scale=1):
    im = Image.open(root/variant/f'frame_{index:04d}.png').convert('RGB')
    if crop: im = im.crop(crop)
    if scale != 1: im = im.resize((im.width*scale, im.height*scale), Image.Resampling.NEAREST)
    p = Image.new('RGB', (im.width, im.height+30), '#202020')
    p.paste(im, (0,30)); d=ImageDraw.Draw(p); d.text((5,6), label, fill='white')
    return p
# NORMAL contact frame 108, crop around platform edge (world-camera region)
for idx, name in [(108,'normal_contact'), (168,'resonance_contact'), (228,'perfect_contact')]:
    a = panel('after', idx, f'alpha0.45 f{idx}', (140,270,255,450), 3)
    b = panel('alpha065', idx, f'alpha0.65 f{idx}', (140,270,255,450), 3)
    c = Image.new('RGB', (a.width*2, a.height))
    c.paste(a,(0,0)); c.paste(b,(a.width,0))
    c.save(root/f'compare_{name}.png')
print('wrote compare sheets')
