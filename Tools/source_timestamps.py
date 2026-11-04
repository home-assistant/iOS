#!/usr/bin/env python3
"""
Keep Xcode's incremental build valid across a DerivedData cache restore.

Xcode rebuilds a source file when its modification time differs from the one recorded in the
build database, and a fresh checkout gives every file the time of the checkout. A restored
DerivedData therefore recompiles the whole project even though only a handful of files differ
from the commit it was built on; only the packages inside DerivedData, whose times the cache
preserves, are reused.

`snapshot` records next to the build products which commit was built and the modification time
of every tracked file. `restore` puts those times back on the files the current commit left
unchanged, so Xcode rebuilds only what differs from the snapshot and what depends on it. Files
the current commit changed or added keep their checkout time. Both are no-ops without a usable
snapshot, which leaves the full rebuild of a cold cache in place.

Usage:
    python3 Tools/source_timestamps.py snapshot <derived-data-dir>
    python3 Tools/source_timestamps.py restore <derived-data-dir>
"""

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SNAPSHOT = Path('SourceSnapshot/timestamps.json')


def git(*arguments, check=True):
    return subprocess.run(
        ['git', '-C', str(ROOT), *arguments], check=check, capture_output=True, text=True
    )


def tracked_files():
    return [path for path in git('ls-files', '-z').stdout.split('\0') if path]


def regular_file(path: str):
    file = ROOT / path
    return file if file.is_file() and not file.is_symlink() else None


def snapshot(derived_data: Path) -> int:
    commit = git('rev-parse', 'HEAD').stdout.strip()
    mtimes = {}
    for path in tracked_files():
        file = regular_file(path)
        if file is not None:
            mtimes[path] = file.stat().st_mtime_ns
    target = derived_data / SNAPSHOT
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps({'commit': commit, 'mtimes': mtimes}))
    print(f'Recorded the timestamps of {len(mtimes)} files built at {commit[:12]}')
    return 0


def restore(derived_data: Path) -> int:
    target = derived_data / SNAPSHOT
    if not target.is_file():
        print('No source timestamp snapshot in DerivedData, leaving the checkout as it is')
        return 0
    data = json.loads(target.read_text())
    commit = data['commit']
    if git('cat-file', '-e', f'{commit}^{{commit}}', check=False).returncode != 0:
        if git('fetch', '--depth=1', 'origin', commit, check=False).returncode != 0:
            print(f'Commit {commit[:12]} of the snapshot is not reachable, leaving the checkout as it is')
            return 0
    diff = git('diff', '--name-only', '--no-renames', '-z', commit, 'HEAD', check=False)
    if diff.returncode != 0:
        print(f'Could not diff against {commit[:12]}, leaving the checkout as it is')
        return 0
    changed = {path for path in diff.stdout.split('\0') if path}
    tracked = set(tracked_files())
    restored = 0
    for path, mtime_ns in data['mtimes'].items():
        if path in changed or path not in tracked:
            continue
        file = regular_file(path)
        if file is None:
            continue
        os.utime(file, ns=(mtime_ns, mtime_ns))
        restored += 1
    print(
        f'Restored the timestamps of {restored} files unchanged since {commit[:12]}; '
        f'{len(changed)} differ and will be rebuilt'
    )
    return 0


def main() -> int:
    if len(sys.argv) != 3 or sys.argv[1] not in ('snapshot', 'restore'):
        print(__doc__.strip(), file=sys.stderr)
        return 64
    derived_data = Path(sys.argv[2]).expanduser()
    return snapshot(derived_data) if sys.argv[1] == 'snapshot' else restore(derived_data)


if __name__ == '__main__':
    sys.exit(main())
