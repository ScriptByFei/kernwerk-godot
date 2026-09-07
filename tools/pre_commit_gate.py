#!/usr/bin/env python3
"""Validate the staged snapshot, not unrelated untracked/unstaged files."""
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    root = Path(subprocess.check_output(
        ['git', 'rev-parse', '--show-toplevel'], text=True).strip())
    checker = root / 'tools/verify_project.py'
    if not checker.is_file():
        print('FAIL: tools/verify_project.py is missing', file=sys.stderr)
        return 1
    with tempfile.TemporaryDirectory(prefix='kernwerk-staged-') as directory:
        subprocess.run(['git', 'checkout-index', '--all', '--prefix', directory + '/'],
                       cwd=root, check=True, timeout=120)
        print('Checking isolated staged snapshot; no commit or deploy is performed.', flush=True)
        return subprocess.run([sys.executable, str(checker), '--project', directory],
                              cwd=root, timeout=900).returncode


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (subprocess.SubprocessError, OSError) as exc:
        print(f'FAIL: staged-snapshot gate: {exc}', file=sys.stderr)
        sys.exit(1)
