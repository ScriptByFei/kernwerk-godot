#!/usr/bin/env python3
"""Frozen native rendering: baseline regression + discriminating HUD mutations."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
OUT = Path('/tmp/kernwerk-overload-choice/visual-proof')
PRODUCTION = ['scripts/game/game.gd', 'scripts/jump/resonance_system.gd',
              'scripts/jump/jumper.gd', 'scripts/ui/resonance_hud.gd']


def render(folder, name):
    dest = OUT / name
    dest.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, KW_OVERLOAD_VISUAL_OUT=str(dest))
    cmd = ['xvfb-run', '-a', '-s', '-screen 0 430x932x24', 'godot4',
           '--audio-driver', 'Dummy', '--rendering-driver', 'opengl3',
           '--resolution', '430x932', '--path', str(folder),
           '-s', 'qa/overload_choice_visual_probe.gd']
    r = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=90)
    text = r.stdout + r.stderr
    (dest / 'render.log').write_text(text)
    assert r.returncode == 0 and 'OVERLOAD VISUAL: rendered' in text and 'SCRIPT ERROR' not in text and '\nERROR:' not in text, text
    return dest


def delta(a, b, crop=None):
    x, y = Image.open(a).convert('RGB'), Image.open(b).convert('RGB')
    if crop:
        x, y = x.crop(crop), y.crop(crop)
    d = ImageChops.difference(x, y)
    return sum(pixel != (0, 0, 0) for pixel in d.getdata())


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    results = {}
    with tempfile.TemporaryDirectory(prefix='kw-overload-visual-') as tmp:
        snap = Path(tmp)
        tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
        extra = ['scripts/jump/overload_input.gd', 'qa/overload_choice_visual_probe.gd']
        for relative in set(filter(None, tracked)) | set(extra):
            src, dst = ROOT / relative, snap / relative
            if src.is_file():
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
        shutil.copytree(ROOT / '.godot', snap / '.godot')
        originals = {p: (snap / p).read_bytes() for p in PRODUCTION}
        after = render(snap, 'after')
        for relative in PRODUCTION:
            (snap / relative).write_bytes(subprocess.check_output(['git', 'show', 'HEAD:' + relative], cwd=ROOT))
        before = render(snap, 'before')
        for relative, content in originals.items():
            (snap / relative).write_bytes(content)
        # HUD occupies the existing top-left strip only. Entire rest must match.
        results['empty_frame_changed_pixels'] = delta(before/'empty.png', after/'empty.png')
        results['outside_hud_changed_pixels'] = delta(before/'two.png', after/'two.png', (0, 80, 430, 932))
        assert results['empty_frame_changed_pixels'] == 0, results
        assert results['outside_hud_changed_pixels'] == 0, results
        segment_box = (16, 51, 79, 62)
        results['ready_pulse_pixels'] = delta(after/'ready_high.png', after/'ready_low.png', segment_box)
        results['ready_vs_armed_segment_pixels'] = delta(after/'ready_high.png', after/'armed.png', segment_box)
        results['activation_impulse_pixels'] = delta(after/'armed_impulse.png', after/'armed.png', (12, 45, 82, 66))
        assert all(results[k] > 0 for k in ['ready_pulse_pixels', 'ready_vs_armed_segment_pixels', 'activation_impulse_pixels']), results
        hud = snap / 'scripts/ui/resonance_hud.gd'
        source = hud.read_text()
        mutations = [
            ('no_pulse', 'gold.a *= 0.86 + 0.14 * sin(_pulse_time * TAU / JumpConfig.RESONANCE_READY_PULSE_PERIOD)', 'gold.a *= 1.0', 'ready_high', 'ready_low', segment_box),
            ('no_impulse', 'if _arm_impulse > 0.0:', 'if false:', 'armed_impulse', 'armed', (12, 45, 82, 66)),
        ]
        for name, old, new, a, b, box in mutations:
            assert source.count(old) == 1
            hud.write_text(source.replace(old, new))
            mutated = render(snap, name)
            results[name + '_control_pixels'] = delta(mutated/(a+'.png'), mutated/(b+'.png'), box)
            assert results[name + '_control_pixels'] == 0, results
            hud.write_text(source)
        results['baseline_commit'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    (OUT/'results.json').write_text(json.dumps(results, indent=2))
    print(json.dumps(results, indent=2))
    print('VISUAL PROOF: baseline unchanged outside HUD; both drawing mutants detected')


if __name__ == '__main__':
    main()
