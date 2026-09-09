"""Confirm reactor/jumper presence + build labelled sheets for a variant dir."""
from pathlib import Path
import json, sys
from PIL import Image, ImageDraw
root = Path(__file__).resolve().parents[1] / 'docs/assets/screenshots/core_polish_fix'
variant = sys.argv[1] if len(sys.argv) > 1 else 'after'
after = root/variant
rows = json.loads((after/'telemetry.json').read_text())['frames']
im = Image.open(after/'frame_0300.png').convert('RGB')
# Reactor core is orange (r high, g mid, b low). Count orange pixels in the
# central band where the jumper sits after reset.
orange = 0
for y in range(300, 700):
    for x in range(120, 380):
        r,g,b = im.getpixel((x,y))
        if r>150 and 60<g<200 and b<120:
            orange += 1
print('orange_reactor_pixels_f300:', orange)
# Build a labelled contact sheet for the after sequence (tiers + death/retry).
def sheet(name, indices, crop=None, scale=1):
    samples=[]
    for i in indices:
        r=rows[i]
        s=Image.open(after/f'frame_{i:04d}.png').convert('RGB')
        if crop: s=s.crop(crop)
        if scale!=1: s=s.resize((s.width*scale,s.height*scale), Image.Resampling.NEAREST)
        p=Image.new('RGB',(s.width,s.height+44),'#202020')
        p.paste(s,(0,44)); d=ImageDraw.Draw(p)
        d.text((5,3),f"{r['stage']} f{i} t={r['t']:.3f}s",fill='white')
        d.text((5,19),f"phase={r['phase']} dead={r['game_over']}",fill='white')
        samples.append(p)
    c=Image.new('RGB',(sum(i.width for i in samples),samples[0].height))
    x=0
    for s in samples: c.paste(s,(x,0)); x+=s.width
    c.save(root/name)
for c in rows and []: pass
contacts=[c for c in json.loads((after/'telemetry.json').read_text())['contacts']]
for c in contacts:
    n=c['frame']
    sheet(c['stage']+'_native.png',[n-1,n,n+2,n+12])
    sheet(c['stage']+'_detail.png',[n-1,n,n+2,n+12],(140,270,255,450),3)
death=next(r['frame'] for r in rows if r['game_over'])
retry=next(r['frame'] for r in rows[death:] if not r['game_over'])
sheet('death_native.png',[death-1,death,death+6,death+11,retry,retry+10])
sheet('tiers_contact_native.png',[108,168,228])
print('sheets written; death',death,'retry',retry)
