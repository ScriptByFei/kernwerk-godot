"""Native-size tier sheet for a variant dir (does not overwrite other variants)."""
from pathlib import Path
import json, sys
from PIL import Image, ImageDraw
root = Path(__file__).resolve().parents[1] / 'docs/assets/screenshots/core_polish_fix'
variant = sys.argv[1]
after = root/variant
rows = json.loads((after/'telemetry.json').read_text())['frames']
def sheet(name, indices):
    samples=[]
    for i in indices:
        r=rows[i]
        s=Image.open(after/f'frame_{i:04d}.png').convert('RGB')
        p=Image.new('RGB',(s.width,s.height+44),'#202020')
        p.paste(s,(0,44)); d=ImageDraw.Draw(p)
        d.text((5,3),f"{r['stage']} f{i} t={r['t']:.3f}s",fill='white')
        d.text((5,19),f"phase={r['phase']} dead={r['game_over']}",fill='white')
        samples.append(p)
    c=Image.new('RGB',(sum(i.width for i in samples),samples[0].height))
    x=0
    for s in samples: c.paste(s,(x,0)); x+=s.width
    c.save(root/f'{variant}_{name}')
sheet('tiers_contact_native.png',[108,168,228])
print('wrote', root/f'{variant}_tiers_contact_native.png')
