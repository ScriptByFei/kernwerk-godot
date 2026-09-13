#!/usr/bin/env python3
"""Run real shaft acceptance and retain exact logs + source hashes."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'qa/artifacts/shaft-redesign'
OUT.mkdir(parents=True,exist_ok=True)

def main():
    window=['xvfb-run','-a','-s','-screen 0 430x932x24','godot4','--audio-driver','Dummy',
            '--rendering-driver','opengl3','--resolution','430x932','--path','.','-s']
    headless=['godot4','--headless','--audio-driver','Dummy','--path','.','-s']
    commands=[
        ('background',headless+['tests/shaft_background_test.gd']),
        ('geometry',headless+['tests/shaft_background_geometry_test.gd']),
        ('full-project',['python3','tools/verify_project.py']),
        ('phone',window+['qa/shaft_background_probe.gd']),
        ('cost',window+['qa/shaft_background_cost_probe.gd']),
        ('edge',window+['qa/shaft_background_edge_probe.gd']),
        ('design',window+['qa/shaft_background_design_probe.gd']),
        ('mutations',['python3','tools/shaft_background_mutations.py']),
    ]
    env=os.environ.copy()
    env['XDG_DATA_HOME']='/home/masgi_bot/.local/share'
    rows=[]
    for name,cmd in commands:
        result=subprocess.run(cmd,cwd=ROOT,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=600)
        log=OUT/(name+'.log')
        log.write_text(result.stdout)
        ok=result.returncode==0 and not re.search(r'(?:SCRIPT ERROR:|ERROR:|^FAIL:)',result.stdout,re.M)
        if name=='full-project':
            ok=ok and 'PASS' in result.stdout
        rows.append({'name':name,'command':cmd,'exit_code':result.returncode,'pass':ok,'log':str(log)})
        print(name, 'PASS' if ok else 'FAIL', 'log='+str(log),flush=True)
        if not ok:
            print(result.stdout[-5000:],flush=True)
            break
    for image in Path('/tmp/kernwerk-six-phases/shaft').glob('*.png'):
        shutil.copy2(image,OUT/image.name)
    paths=['scripts/jump/shaft_background.gd','tests/shaft_background_test.gd',
           'tests/shaft_background_geometry_test.gd','qa/shaft_background_probe.gd',
           'qa/shaft_background_cost_probe.gd','qa/shaft_background_edge_probe.gd',
           'qa/shaft_background_design_probe.gd']
    report={'technical_pass':len(rows)==len(commands) and all(r['pass'] for r in rows),
            'visual_status':'DRAFT - separate human-facing visual review required',
            'commands':rows,'sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}}
    (OUT/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print('SHAFT ACCEPTANCE', 'PASS' if report['technical_pass'] else 'FAIL',flush=True)
    raise SystemExit(0 if report['technical_pass'] else 1)

if __name__=='__main__':
    main()
