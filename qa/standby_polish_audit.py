#!/usr/bin/env python3
"""Read-only source/preservation/geometry audit; writes uniquely named evidence."""
from pathlib import Path
import hashlib,json,subprocess
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/assets/screenshots/standby_polish'
original=json.loads(Path('/tmp/kernwerk-standby-original-manifest.json').read_text())
changed=[p for p,h in original.items() if not (ROOT/p).exists() or hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h]
assert not changed,changed
source='scripts/game/game.gd'
head=subprocess.check_output(['git','show','HEAD:'+source],cwd=ROOT).decode()
expected=head.replace('jumper.modulate = Color(0.72, 0.76, 0.80)','jumper.modulate = Color(0.92, 0.94, 0.96)')
assert (ROOT/source).read_text()==expected,'Unexpected gameplay/timeline source change'
rows=json.loads((OUT/'after_verified_geometry.json').read_text())
expected_sizes={(320,568),(390,844),(430,932),(1280,720),(844,390)}
assert {tuple(row['window']) for row in rows}==expected_sizes and len(rows)==5
summary=[]
for row in rows:
    w,h=row['window']
    file=OUT/(row['tag']+'_window.png')
    actual=Image.open(file).size
    assert actual==(w,h),(file,actual)
    viewport_file=OUT/(row['tag']+'.png')
    raster=Image.open(viewport_file).size
    scale=raster[0]/row['viewport'][0]
    panel=row['nodes']['CtaPanel']['rect']
    summary.append({'window':[w,h],'raster':list(raster),'cta_pixels':[round(v*scale,2) for v in panel], 'screenshot':str(file.relative_to(ROOT))})
log=(OUT/'full_gate_standby_evidence_excluded.log').read_text()
assert 'PASS: import, 7 suites, main-scene smoke, Web export.' in log
assert 'res://docs/assets/screenshots/standby_polish/' not in (OUT/'web_export_standby_evidence_excluded.log').read_text()
status=subprocess.check_output(['git','status','--porcelain=v1','-z'],cwd=ROOT).decode().split('\0')
initial=Path('/tmp/kernwerk-standby-initial-status.z').read_bytes().decode().split('\0')
new_status=[p for p in status if p and p not in initial]
result={'preserved_existing_files':len(original),'preservation_changes':changed,'game_gd_only_initial_visual_tint_changed':True,'all_five_real_window_sizes_verified':True,'evidence_excluded_from_export':True,'screens':summary,'task_status_entries':new_status}
file=OUT/'delivery_audit.json'
assert not file.exists(),'Refusing evidence overwrite'
file.write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
