#!/usr/bin/env python3
"""Local technical acceptance gate. No commits, pushes or deployments."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r"SCRIPT ERROR|^ERROR:", re.MULTILINE)


def failed(returncode, output):
    return returncode != 0 or ERROR.search(output) is not None


def run(label, command, timeout=120):
    print(f"\n=== {label} ===", flush=True)
    try:
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=timeout)
    except (subprocess.TimeoutExpired, OSError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return False
    print(result.stdout, flush=True)
    if failed(result.returncode, result.stdout):
        print(f"FAIL: {label} (exit={result.returncode})", file=sys.stderr)
        return False
    return True


class GateTests(unittest.TestCase):
    def test_clean(self):
        self.assertFalse(failed(0, 'All tests passed\n'))

    def test_exit(self):
        self.assertTrue(failed(1, ''))

    def test_godot_script_error_with_zero_exit(self):
        self.assertTrue(failed(0, 'SCRIPT ERROR: Parse Error\n'))

    def test_godot_error_with_zero_exit(self):
        self.assertTrue(failed(0, 'Godot\nERROR: missing resource\n'))

    def test_timeout(self):
        from unittest.mock import patch
        with patch('subprocess.run', side_effect=subprocess.TimeoutExpired('godot', 1)):
            self.assertFalse(run('expected timeout', ['godot'], 1))

    def test_missing_executable(self):
        from unittest.mock import patch
        with patch('subprocess.run', side_effect=FileNotFoundError('expected missing executable')):
            self.assertFalse(run('expected missing executable', ['godot']))


def main():
    global ROOT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--self-test', action='store_true')
    parser.add_argument('--project', type=Path, default=ROOT,
                        help='Project root; used for isolated staged-snapshot checks')
    args = parser.parse_args()
    ROOT = args.project.resolve()
    if args.self_test:
        result = unittest.TextTestRunner(verbosity=2).run(
            unittest.defaultTestLoader.loadTestsFromTestCase(GateTests))
        return 0 if result.wasSuccessful() else 1
    godot = shutil.which('godot4')
    if not godot:
        print('FAIL: godot4 is missing', file=sys.stderr)
        return 1
    if not run('Local engine version (compare with CI)', [godot, '--version']):
        return 1
    base = [godot, '--headless', '--audio-driver', 'Dummy', '--path', str(ROOT)]
    suites = sorted(ROOT.glob('tests/*_test.gd'))
    if not suites:
        print('FAIL: no current test suites found', file=sys.stderr)
        return 1
    checks = [('Project import', base + ['--editor', '--quit'])]
    checks += [(str(p.relative_to(ROOT)), base + ['-s', str(p)]) for p in suites]
    checks += [('Main-scene smoke', base + ['--quit-after', '120'])]
    for label, command in checks:
        if not run(label, command):
            return 1
    with tempfile.TemporaryDirectory(prefix='kernwerk-verify-web-') as output:
        target = Path(output) / 'index.html'
        if not run('Web release export', base + ['--export-release', 'Web', str(target)], 180):
            return 1
        for suffix in ['.html', '.js', '.wasm', '.pck']:
            artifact = target.with_suffix(suffix)
            if not artifact.is_file() or artifact.stat().st_size == 0:
                print(f'FAIL: missing/empty {artifact.name}', file=sys.stderr)
                return 1
            print(f'Export artifact: {artifact.name} ({artifact.stat().st_size} bytes)')
    print(f'PASS: import, {len(suites)} suites, main-scene smoke, Web export. '
          'Visual quality, iPhone acceptance and remote CI are NOT covered.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
