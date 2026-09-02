#!/usr/bin/env python3
"""
Convert Xcode code coverage from an .xcresult bundle into LCOV.

`xcrun xccov view --archive --json` reports per-line execution counts keyed by
absolute source path. Codecov cannot read that format, so this script rewrites
it as LCOV with repository-relative paths, and optionally renders a Markdown
summary for the GitHub Actions job summary.
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, NamedTuple, Tuple


class FileCoverage(NamedTuple):
    """Per-line hit counts for one source file, keyed by repository-relative path."""
    path: str
    lines: List[Tuple[int, int]]

    @property
    def executable(self) -> int:
        return len(self.lines)

    @property
    def covered(self) -> int:
        return sum(1 for _, count in self.lines if count > 0)


def read_archive(xcresult: Path) -> Dict[str, list]:
    """Dump the per-line coverage archive of an .xcresult bundle as JSON."""
    result = subprocess.run(
        ['xcrun', 'xccov', 'view', '--archive', '--json', str(xcresult)],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        print(f"xccov failed for {xcresult}:\n{result.stderr}", file=sys.stderr)
        sys.exit(1)

    return json.loads(result.stdout)


def parse_coverage(archive: Dict[str, list], repo_root: Path) -> List[FileCoverage]:
    """
    Turn the xccov archive into repository-relative per-file coverage.

    Files outside the repository (dependency checkouts inside DerivedData) are
    dropped, since Codecov can only map paths that exist in the repository.
    """
    files = []

    for absolute_path, lines in sorted(archive.items()):
        try:
            relative_path = Path(absolute_path).resolve().relative_to(repo_root)
        except ValueError:
            continue

        executable = [
            (line['line'], line.get('executionCount', 0))
            for line in lines
            if line.get('isExecutable')
        ]

        if executable:
            files.append(FileCoverage(relative_path.as_posix(), executable))

    return files


def write_lcov(files: List[FileCoverage], destination: Path) -> None:
    """Write the coverage as an LCOV tracefile."""
    records = []

    for file in files:
        record = [f"SF:{file.path}"]
        record += [f"DA:{line},{count}" for line, count in file.lines]
        record.append(f"LF:{file.executable}")
        record.append(f"LH:{file.covered}")
        record.append('end_of_record')
        records.append('\n'.join(record))

    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text('\n'.join(records) + '\n', encoding='utf-8')


def percentage(covered: int, executable: int) -> str:
    return f"{covered / executable * 100:.2f}%" if executable else "n/a"


def markdown_summary(files: List[FileCoverage], depth: int = 2) -> str:
    """
    Render a Markdown table of overall coverage plus a row per source group.

    Groups are the first `depth` path components (`Sources/Shared`,
    `Sources/App`, …), which is the same granularity the Codecov path-based
    statuses in codecov.yaml use.
    """
    groups: Dict[str, List[int]] = {}

    for file in files:
        group = '/'.join(file.path.split('/')[:depth])
        totals = groups.setdefault(group, [0, 0])
        totals[0] += file.covered
        totals[1] += file.executable

    covered = sum(file.covered for file in files)
    executable = sum(file.executable for file in files)

    rows = [
        "| Area | Coverage | Covered | Executable |",
        "| --- | --- | --- | --- |",
        f"| **Total** | **{percentage(covered, executable)}** | {covered} | {executable} |",
    ]
    rows += [
        f"| `{group}` | {percentage(*groups[group])} | {groups[group][0]} | {groups[group][1]} |"
        for group in sorted(groups)
    ]

    return '\n'.join(["## Code coverage", '', *rows, ''])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('xcresult', type=Path, help="path to the .xcresult bundle")
    parser.add_argument('--lcov', type=Path, required=True, help="LCOV tracefile to write")
    parser.add_argument('--summary', type=Path, help="Markdown summary to append to")
    parser.add_argument(
        '--repo-root',
        type=Path,
        default=Path.cwd(),
        help="repository root that coverage paths are made relative to",
    )
    arguments = parser.parse_args()

    files = parse_coverage(read_archive(arguments.xcresult), arguments.repo_root.resolve())

    if not files:
        print(f"No repository sources covered in {arguments.xcresult}", file=sys.stderr)
        sys.exit(1)

    write_lcov(files, arguments.lcov)

    summary = markdown_summary(files)
    print(summary)

    if arguments.summary:
        with open(arguments.summary, 'a', encoding='utf-8') as handle:
            handle.write(summary)


if __name__ == "__main__":
    main()
