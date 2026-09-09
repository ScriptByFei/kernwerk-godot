"""Side-by-side before/after retry-frame comparison sheet (no source edits)."""
from pathlib import Path
from PIL import Image, ImageDraw
root = Path(__file__).resolve().parents[1] / 'docs/assets/screenshots/core_polish_fix'
def panel(path, label):
    im = Image.open(path).convert('RGB')
    p = Image.new('RGB', (im.width, im.height+30), '#202020')
    p.paste(im, (0,30)); d=ImageDraw.Draw(p); d.text((5,6), label, fill='white')
    return p
for n in [300, 301]:
    a = panel(root/'before'/f'frame_{n:04d}.png', f'BEFORE f{n}')
    b = panel(root/'after'/f'frame_{n:04d}.png', f'AFTER f{n}')
    canvas = Image.new('RGB', (a.width*2, a.height))
    canvas.paste(a,(0,0)); canvas.paste(b,(a.width,0))
    canvas.save(root/f'retry_compare_f{n}.png')
print('wrote', root/'retry_compare_f300.png', root/'retry_compare_f301.png')
