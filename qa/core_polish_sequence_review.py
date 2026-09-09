"""Build labelled review sheets from real captures, without altering source frames."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

out = Path(__file__).resolve().parents[1] / 'docs/assets/screenshots/core_polish_sequence'
data = json.loads((out / 'telemetry.json').read_text())
rows = data['frames']
assert len(rows) == len(list(out.glob('frame_*.png'))) == 346
assert all((r['width'], r['height']) == (390,844) for r in rows)

def sheet(name, indices, crop=None, scale=1):
    samples=[]
    for index in indices:
        r=rows[index]
        im=Image.open(out/f'frame_{index:04d}.png').convert('RGB')
        if crop: im=im.crop(crop)
        if scale!=1: im=im.resize((im.width*scale,im.height*scale), Image.Resampling.NEAREST)
        panel=Image.new('RGB',(im.width,im.height+44),'#202020')
        panel.paste(im,(0,44)); d=ImageDraw.Draw(panel)
        d.text((5,3),f"{r['stage']} f{index} t={r['t']:.3f}s",fill='white')
        d.text((5,19),f"phase={r['phase']} dead={r['game_over']}",fill='white')
        samples.append(panel)
    canvas=Image.new('RGB',(sum(i.width for i in samples),samples[0].height))
    x=0
    for im in samples: canvas.paste(im,(x,0)); x+=im.width
    canvas.save(out/name)

summary={'capture_frames':len(rows),'resolution':[390,844],'contacts':data['contacts'],'state_changes':[]}
last=None
for r in rows:
    state=(r['phase'],r['game_over'],r['jumper_id'])
    if state!=last:
        summary['state_changes'].append(r)
        last=state
for c in data['contacts']:
    n=c['frame']
    # Peak is contact: production light envelopes decay monotonically.
    sheet(c['stage']+'_native.png',[n-1,n,n+2,n+12])
    # fixed world-camera crop wide enough to show core ascent + ledge
    sheet(c['stage']+'_detail.png',[n-1,n,n+2,n+12],(140,270,255,450),3)
    assert c['previous_render_vy']>0 and c['bounce_vy']<0
    assert c['on_floor'] and c['slide_normals']==['(0.0, -1.0)']
    assert c['target_id']==c['platform_id']
    assert rows[n]['core_remaining']>0 and rows[n]['platform_active']
assert [c['quality'] for c in data['contacts']]==[0,1,2]
death=next(r['frame'] for r in rows if r['game_over'])
retry=next(r['frame'] for r in rows[death:] if not r['game_over'])
summary.update(death_frame=death,retry_frame=retry,retry_seconds=(retry-death)/60)
sheet('start_native.png',[29,31,54,84,90])
sheet('death_native.png',[death-1,death,death+6,death+11,retry,retry+10])
sheet('death_detail.png',[death-1,death,death+6,death+11],(300,590,365,675),4)
summary['death_samples']=[rows[i] for i in [death-1,death,death+6,death+11,retry,retry+10]]
(out/'verification.json').write_text(json.dumps(summary,indent=2))
# Read-only protected-code comparison against HEAD, not a baseline image comparison.
import subprocess, re, hashlib
project=out.parents[3]
functions=['_create_start_menu','_start_game','_begin_start_sequence','_tween_menu_away','_finish_start_sequence','_fire_initial_bounce','_enter_playing','_cancel_start_sequence']
current=(project/'scripts/game/game.gd').read_text()
baseline=subprocess.check_output(['git','show','HEAD:scripts/game/game.gd'],cwd=project,text=True)
def body(text,name):
    match=re.search(r'^func '+name+r'\(.*?(?=^func |\Z)',text,re.M|re.S)
    return match.group(0).strip() if match else None
protected={name:body(current,name)==body(baseline,name) for name in functions}
menu=(project/'scripts/ui/start_menu.gd').read_bytes()
protected['start_menu_file']=menu==subprocess.check_output(['git','show','HEAD:scripts/ui/start_menu.gd'],cwd=project)
config=(project/'scripts/jump/jump_config.gd').read_text()
baseconfig=subprocess.check_output(['git','show','HEAD:scripts/jump/jump_config.gd'],cwd=project,text=True)
protected['start_constants']=re.findall(r'^const START_.*$',config,re.M)==re.findall(r'^const START_.*$',baseconfig,re.M)
summary['protected_against_HEAD']=protected
summary['runtime_asset_sha256']={str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for folder in ['scripts/game','scripts/jump','assets/jump/reactor_core','assets/jump/approved/reactor-core'] for p in (project/folder).rglob('*') if p.is_file()}
(out/'verification.json').write_text(json.dumps(summary,indent=2))
sheet('tiers_contact_native.png',[108,168,228])
print(json.dumps({k:v for k,v in summary.items() if k not in ['state_changes','death_samples','runtime_asset_sha256']},indent=2))
