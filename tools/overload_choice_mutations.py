#!/usr/bin/env python3
"""Mutations in an isolated tracked snapshot; never mutate the working tree."""
from pathlib import Path
import json
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUT = Path('/tmp/kernwerk-overload-choice/mutations')
FILES = [
    'scripts/jump/resonance_system.gd', 'scripts/jump/jumper.gd',
    'scripts/jump/overload_input.gd', 'scripts/game/game.gd',
    'scripts/ui/resonance_hud.gd', 'tests/overload_choice_test.gd',
    'tests/overload_input_test.gd', 'tests/overload_pattern_routes_test.gd',
    'qa/overload_choice_probe.gd',
]
R = 'scripts/jump/resonance_system.gd'
G = 'scripts/game/game.gd'
I = 'scripts/jump/overload_input.gd'
J = 'scripts/jump/jumper.gd'
MUTATIONS = [
    ('automatic_discharge', R, 'if not _overload_armed:', 'if charges < max_charges():', 'choice'),
    ('normal_keeps_resource', R, '\t\tclear()\n\t\treturn false', '\t\treturn false', 'choice'),
    ('consume_keeps_charge', R, 'overload_count += 1\n\tcharges = 0', 'overload_count += 1\n\tcharges = max_charges()', 'choice'),
    ('double_arm', R, 'and not _overload_armed', '', 'choice'),
    ('stats_on_arm', R, '\t_overload_armed = true', '\toverload_count += 1\n\t_overload_armed = true', 'choice'),
    ('midair_force', G, '\treturn resonance.arm_overload()', '\tjumper.velocity.y = -4000.0\n\treturn resonance.arm_overload()', 'choice'),
    ('phase_gate_missing', G, 'func try_arm_overload() -> bool:\n\tif _phase != Phase.PLAYING or is_game_over or _is_paused or get_tree().paused or jumper == null:', 'func try_arm_overload() -> bool:\n\tif jumper == null:', 'choice'),
    ('gravity_clamped_two', J, 'roundi(_resonance_ratio * float(maximum)), 0, maximum)', 'roundi(_resonance_ratio * float(maximum)), 0, maximum - 1)', 'choice'),
    ('repeated_up', I, '\tif _fired:\n\t\treturn false\n', '', 'input'),
    ('wrong_direction', I, 'Vector2(position.x, -position.y)', 'Vector2(position.x, position.y)', 'input'),
    ('horizontal_arms', I, 'JumpConfig.DIVE_SWIPE_DOMINANCE', '0.0', 'input'),
    ('input_disconnected', G, '\t\ttry_arm_overload()\n', '\t\tpass\n', 'real'),
    ('arm_feedback_disconnected', 'scripts/ui/resonance_hud.gd', '_arm_impulse = JumpConfig.RESONANCE_ARM_IMPULSE_TIME', '_arm_impulse = 0.0', 'real'),
]


def run_test(snapshot, suite, name):
    cmd = ['godot4', '--audio-driver', 'Dummy', '--path', str(snapshot)]
    if suite == 'real':
        cmd = ['xvfb-run', '-a', '-s', '-screen 0 430x932x24'] + cmd + [
            '--rendering-driver', 'opengl3', '--resolution', '430x932',
            '-s', 'qa/overload_choice_probe.gd']
    else:
        cmd += ['--headless', '-s', f'tests/overload_{suite}_test.gd']
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=90)
    text = result.stdout + result.stderr
    (OUT / f'{name}.log').write_text(text)
    marker = re.search(r'OVERLOAD (?:CHOICE|INPUT|REAL INPUT): (\d+) checks, (\d+) failures', text)
    if not marker or 'SCRIPT ERROR' in text or re.search(r'^ERROR:', text, re.M):
        raise RuntimeError(f'{name}: invalid test execution; see log')
    return int(marker[2])


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    results = []
    with tempfile.TemporaryDirectory(prefix='kw-overload-mutations-') as folder:
        snapshot = Path(folder)
        tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
        for relative in set(filter(None, tracked)) | set(FILES):
            src, dst = ROOT / relative, snapshot / relative
            if src.is_file():
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
        shutil.copytree(ROOT / '.godot', snapshot / '.godot')
        probe = snapshot / 'qa/overload_choice_probe.gd'
        probe_text = probe.read_text()
        assert '"/tmp/kernwerk-overload-choice"' in probe_text
        probe.write_text(probe_text.replace('"/tmp/kernwerk-overload-choice"',
                                            '"/tmp/kernwerk-overload-choice/mutations/render"'))
        for suite in ['choice', 'input', 'real']:
            failures = run_test(snapshot, suite, 'control_' + suite)
            assert failures == 0, (suite, failures)
        for name, relative, old, new, suite in MUTATIONS:
            path = snapshot / relative
            original = path.read_text()
            assert old in original, (name, 'mutation matched nothing')
            if name != 'wrong_direction':
                assert original.count(old) == 1, (name, 'ambiguous mutation')
            try:
                path.write_text(original.replace(old, new))
                failures = run_test(snapshot, suite, name)
                assert failures > 0, (name, 'undetected')
                results.append({'mutation': name, 'failures': failures, 'detected': True})
                print(f'{name}: detected, {failures} failures', flush=True)
            finally:
                path.write_text(original)
        assert run_test(snapshot, 'choice', 'restored_control') == 0
    (OUT / 'results.json').write_text(json.dumps(results, indent=2))
    print(f'MUTATIONS: {len(results)}/{len(MUTATIONS)} detected; restored control green')


if __name__ == '__main__':
    main()
