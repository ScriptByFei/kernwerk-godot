#!/usr/bin/env python3
"""Mutation checks in an isolated minimal Godot project. Never edits live code.
Fixtures/logs remain in /tmp for inspection. Render mutations MUST produce
explicit FAIL assertions; a parse error/crash does not count as detection.
"""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def run(command, cwd, log):
    result = subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=240)
    log.write_text(result.stdout)
    return result

def main():
    source = ROOT/'scripts/jump/shaft_background.gd'
    original = source.read_text()
    fixture = Path(tempfile.mkdtemp(prefix='kernwerk-shaft-mutations-'))
    for rel in ['scripts/jump/shaft_background.gd','scripts/jump/jump_config.gd',
                'tests/shaft_background_geometry_test.gd','qa/shaft_background_design_probe.gd']:
        target = fixture/rel
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(ROOT/rel, target)
    (fixture/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Shaft mutation fixture"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    # Output goes into the fixture, never overwrites delivery screenshots.
    probe = fixture/'qa/shaft_background_design_probe.gd'
    probe.write_text(probe.read_text().replace('/tmp/kernwerk-six-phases/shaft', str(fixture/'images')))
    init = run(['godot4','--headless','--editor','--import','--path',str(fixture)], fixture, fixture/'import.log')
    if init.returncode or 'SCRIPT ERROR:' in init.stdout:
        raise RuntimeError('Fixture import failed: '+str(fixture/'import.log'))
    base = ['godot4','--audio-driver','Dummy','--path',str(fixture)]
    geometry = ['godot4','--headless','--audio-driver','Dummy','--path',str(fixture),'-s','tests/shaft_background_geometry_test.gd']
    render = ['xvfb-run','-a','-s','-screen 0 430x932x24']+base+['--rendering-driver','opengl3','--resolution','430x932','-s','qa/shaft_background_design_probe.gd']
    # Every baseline must pass before a failing mutant has meaning.
    for name,cmd in [('baseline-geometry',geometry),('baseline-render',render)]:
        result=run(cmd,fixture,fixture/(name+'.log'))
        if result.returncode or 'FAIL:' in result.stdout or 'ERROR:' in result.stdout:
            raise RuntimeError(name+' failed: '+str(fixture/(name+'.log')))
    # Positive adversarial fixture: every housing uses the most expensive fan.
    fan_anchor='tile_pick(1, index, slot + 13, 3)'
    assert original.count(fan_anchor)==1
    (fixture/'scripts/jump/shaft_background.gd').write_text(original.replace(fan_anchor,'1'))
    worst=run(render,fixture,fixture/'all-fans-stress.log')
    if worst.returncode or 'FAIL:' in worst.stdout or 'ERROR:' in worst.stdout:
        raise RuntimeError('All-fans cost stress failed: '+str(fixture/'all-fans-stress.log'))
    print('ALL-FANS STRESS PASS',str(fixture/'all-fans-stress.log'),flush=True)
    cases = [
        ('machine-in-center','var x := 72.0 if side < 0.0 else width - 212.0','var x := 400.0 if side < 0.0 else width - 212.0',geometry),
        ('light-without-metal','machine.position + Vector2(12.0 if side < 0.0 else 28.0, 12.0)','machine.position + Vector2(240.0 if side < 0.0 else 28.0, 12.0)',geometry),
        ('valve-in-center','Vector2(134.0 if side < 0.0 else width - 134.0, top + 440.0)','Vector2(540.0 if side < 0.0 else width - 134.0, top + 440.0)',geometry),
        ('light-draw-removed','\t\t\t_draw_inset_light(canvas, light, time + float(index), alpha, tile_pick(1, index, slot + 13, 3))','\t\t\tpass # injected missing light draw',render),
        ('quiet-draw-bypass','\tvar x := 214.0 if side < 0.0 else width - 270.0','\tvar x := 540.0 if side < 0.0 else width - 270.0',render),
        # Die Tuer ist jetzt die Wand in der Mitte; ihre Flaeche muss dunkel
        # bleiben, sonst bricht die Kontrastregel.
        ('door-too-bright','const DOOR_PANEL := Color("0d181c")','const DOOR_PANEL := Color("26394a")',render),
        # Nur die Tuer (schmal) oder eine durchgezogene Linie statt Perlenkette
        # muss von der Geometrie-Regel gefangen werden.
        ('pearl-continuous-line','\t\tvar h := 14.0 + tile_value(1, tile_index, slot + 70) * 16.0','\t\tvar h := 700.0 # durchgezogene Linie',geometry),
        ('door-too-narrow','static func door_rect(top: float) -> Rect2:\n\treturn Rect2(280.0, top, 520.0, 760.0)','static func door_rect(top: float) -> Rect2:\n\treturn Rect2(300.0, top, 60.0, 760.0)',geometry),
        ('primitive-overload','\tvar width := 1080.0','\tfor injected in range(400):\n\t\tcanvas.draw_rect(Rect2(20.0, visible_rect.position.y + 20.0, 20.0, 20.0), Color.WHITE)\n\tvar width := 1080.0',render),
    ]
    rows=[]
    for name,old,new,cmd in cases:
        if original.count(old)!=1:
            raise RuntimeError(f'Mutation anchor {name}: {original.count(old)} matches')
        (fixture/'scripts/jump/shaft_background.gd').write_text(original.replace(old,new))
        result=run(cmd,fixture,fixture/(name+'.log'))
        detected=result.returncode!=0 and 'FAIL:' in result.stdout and 'ERROR:' not in result.stdout
        row={'name':name,'detected_by_assertion':detected,'exit_code':result.returncode,'log':str(fixture/(name+'.log'))}
        rows.append(row)
        print(json.dumps(row),flush=True)
    unchanged=source.read_text()==original
    report={'fixture':str(fixture),'source_sha256':hashlib.sha256(original.encode()).hexdigest(),
            'live_source_unchanged':unchanged,'mutations':rows,
            'pass':unchanged and all(r['detected_by_assertion'] for r in rows)}
    out=ROOT/'qa/artifacts/shaft-redesign/mutations.json'
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(report,indent=2)+'\n')
    print('MUTATIONS', 'PASS' if report['pass'] else 'FAIL', out)
    raise SystemExit(0 if report['pass'] else 1)

if __name__=='__main__':
    main()
