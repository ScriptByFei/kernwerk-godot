"""Compare tuned (stem6/dash6) vs alpha065 (stem4/dash4) at detail + native."""
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
# Perfect contact frame 228: center marker + gold dashes
a = panel('alpha065', 228, 'alpha065 stem4/dash4', (140,270,255,450), 3)
b = panel('tuned', 228, 'tuned stem6/dash6', (140,270,255,450), 3)
c = Image.new('RGB', (a.width*2, a.height))
c.paste(a,(0,0)); c.paste(b,(a.width,0))
c.save(root/'compare_perfect_tuned.png')
# Native-size tier sheet comparison: alpha065 vs tuned
def tiers(variant, name):
    samples=[]
    for i in [108,168,228]:
        s=Image.open(root/variant/f'frame_{i:04d}.png').convert('RGB')
        p=Image.new('RGB',(s.width,s.height+30),'#202020')
        p.paste(s,(0,30)); d=ImageDraw.Draw(p); d.text((5,6),f"{variant} f{i}",fill='white')
        samples.append(p)
    c=Image.new('RGB',(sum(i.width for i in samples),samples[0].height))
    x=0
    for s in samples: c.paste(s,(x,0)); x+=s.width
    c.save(root/name)
tiers('alpha065','tiers_alpha065_native.png')
tiers('tuned','tiers_tuned_native.png')
print('wrote compare_perfect_tuned.png, tiers_alpha065_native.png, tiers_tuned_native.png')
