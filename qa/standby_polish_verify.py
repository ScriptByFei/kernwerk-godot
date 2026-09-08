#!/usr/bin/env python3
"""Standby evidence runner; no deployment. Run from repository root.
Preserves the pre-existing dirty jump_phase1 screenshot even on gate failure.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/assets/screenshots/standby_polish'

def run(label, command):
    path = OUT / (label + '.log')
    if path.exists():
        raise RuntimeError(f'Refusing evidence overwrite: {path}')
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=600)
    path.write_text(result.stdout)
    print(label, 'exit', result.returncode, flush=True)
    print(result.stdout[-6000:], flush=True)
    if result.returncode or 'SCRIPT ERROR' in result.stdout or '\nERROR:' in result.stdout:
        raise RuntimeError(f'{label} failed; see {path}')

if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    protected = ROOT / 'docs/assets/screenshots/jump_phase1.png'
    original = protected.read_bytes()
    suffix = sys.argv[1] if len(sys.argv) > 1 else 'run1'
    try:
        run('full_gate_standby_' + suffix, ['python3','tools/verify_project.py'])
    finally:
        if protected.read_bytes() != original:
            protected.write_bytes(original)
        assert protected.read_bytes() == original
        print('Original jump_phase1 bytes retained:', hashlib.sha256(original).hexdigest(), flush=True)
    target = Path('/tmp/kernwerk-standby-web')
    target.mkdir(exist_ok=True)
    if (target/'index.html').exists():
        raise RuntimeError('Refusing existing Web artifact overwrite')
    run('web_export_standby_' + suffix, ['godot4','--headless','--audio-driver','Dummy','--path','.', '--export-release','Web', str(target/'index.html')])
    artifacts = {}
    for ext in ['html','js','wasm','pck']:
        file = target / ('index.' + ext)
        assert file.is_file() and file.stat().st_size
        artifacts[file.name] = {'bytes':file.stat().st_size,'sha256':hashlib.sha256(file.read_bytes()).hexdigest()}
    (OUT/('web_artifacts_' + suffix + '.json')).write_text(json.dumps(artifacts,indent=2))
    print('Web export ready:',target)
