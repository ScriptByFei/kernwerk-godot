"""Read real framebuffer captures; fail on uncovered retry or absent HUD."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--out', type=Path, required=True)
parser.add_argument('--snapshot', action='store_true')
args = parser.parse_args()
out = args.out.resolve()
if args.snapshot:
    files = [f for base in ['scripts', 'assets/jump', 'qa', 'docs/assets/screenshots/core_polish_sequence'] for f in (PROJECT/base).rglob('*') if f.is_file()]
    (out/'before_sha256.json').write_text(json.dumps({str(f.relative_to(PROJECT)): hashlib.sha256(f.read_bytes()).hexdigest() for f in files}, indent=2))
    (out/'before_status.log').write_text(subprocess.check_output(['git','status','--short'], cwd=PROJECT, text=True))
    for name in ['game/game.gd', 'jump/jump_config.gd']:
        (out/('before_'+Path(name).name)).write_bytes((PROJECT/'scripts'/name).read_bytes())
    raise SystemExit(0)
rows = json.loads((out/'telemetry.json').read_text())['frames']
retries = [i for i in range(1,len(rows)) if rows[i-1]['game_over'] and not rows[i]['game_over']]
assert retries, 'No real death-to-retry captured'
results = []
for i in retries:
    for n in [i, i+1]:
        im = Image.open(out/f'frame_{n:04d}.png').convert('RGB')
        # Quiet margins are world background, not shafts/platform/core. Check
        # throughout viewport height, so a partial background cannot pass.
        probes = [(x,y) for x in [5, 25, 375, 385] for y in range(40, 835, 20)]
        bad = [(x,y,im.getpixel((x,y))) for x,y in probes if max(im.getpixel((x,y))) > 35]
        hud = sum(1 for r,g,b in im.crop((12,12,155,30)).getdata() if g>100 and g>r and g>b)
        results.append({'frame':n,'bad_background_probes':len(bad),'examples':bad[:8],'hud_lit_pixels':hud,'pass':not bad and hud>40})
report = {'retry_frames':retries,'render_checks':results,'pass':all(r['pass'] for r in results)}
(out/'retry_regression.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
raise SystemExit(0 if report['pass'] else 1)
