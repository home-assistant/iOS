#!/usr/bin/env python3
"""
Measure how well tested the lines a pull request changes are.

Codecov calls this "patch coverage": of the executable lines a branch adds or
edits, the share the test suite actually runs. This computes the same number
from the LCOV tracefile `Tools/xccov_to_lcov.py` writes, so CI can gate on it
directly instead of depending on a third-party upload round-tripping in time.

Only lines the coverage report knows about are counted. A changed line carrying
no executable code (a comment, a brace, a type declaration) is not coverable,
and a file none of the tested targets compile has no coverage data at all;
neither is held against the pull request.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, Iterable, List, NamedTuple, Sequence, Set, Tuple

# Kept in sync with the `ignore` list in codecov.yaml: generated resources, the
# testing helpers and the tests themselves are not what the threshold is about.
DEFAULT_IGNORED_PATHS = (
    'Sources/Shared/Resources',
    'Sources/App/Resources',
    'Sources/SharedTesting',
    'Tests',
)

HUNK_HEADER = re.compile(r'^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@')


class FileResult(NamedTuple):
    """The changed lines of one file, split by whether the tests execute them."""
    path: str
    covered: List[int]
    uncovered: List[int]

    @property
    def changed(self) -> int:
        return len(self.covered) + len(self.uncovered)


def parse_lcov(tracefile: Path) -> Dict[str, Dict[int, int]]:
    """Read an LCOV tracefile as {repository-relative path: {line: execution count}}."""
    files: Dict[str, Dict[int, int]] = {}
    lines: Dict[int, int] = {}

    for record in tracefile.read_text(encoding='utf-8').splitlines():
        if record.startswith('SF:'):
            lines = files.setdefault(record[3:].strip(), {})
        elif record.startswith('DA:'):
            number, _, count = record[3:].partition(',')
            lines[int(number)] = int(count or 0)

    return files


def read_diff(base: str, repo_root: Path) -> str:
    """
    Dump the pull request's own diff against the commit it branched from.

    `base...HEAD` diffs against the merge base, so commits landing on the base
    branch after the pull request opened are not counted as its changes. Deleted
    files are excluded — they have no lines left to cover.
    """
    result = subprocess.run(
        ['git', 'diff', '--unified=0', '--diff-filter=d', f"{base}...HEAD"],
        capture_output=True,
        text=True,
        cwd=repo_root,
    )

    if result.returncode != 0:
        print(f"git diff against {base} failed:\n{result.stderr}", file=sys.stderr)
        sys.exit(1)

    return result.stdout


def parse_diff(diff: str) -> Dict[str, Set[int]]:
    """
    Collect the line numbers each file gains, keyed by its path after the change.

    With `--unified=0` every hunk header covers added lines and nothing else, so
    the header ranges are the changed lines. A `+++` line only starts a new file
    when it follows a `---` line, so an added source line that happens to begin
    with `++ ` cannot be mistaken for a file header.
    """
    files: Dict[str, Set[int]] = {}
    path = None
    previous = ''

    for line in diff.splitlines():
        if line.startswith('+++ ') and previous.startswith('--- '):
            target = line[4:].strip()
            path = None if target == '/dev/null' else re.sub(r'^b/', '', target)
        elif path is not None:
            hunk = HUNK_HEADER.match(line)

            if hunk:
                start, count = int(hunk.group(1)), int(hunk.group(2) or 1)
                files.setdefault(path, set()).update(range(start, start + count))

        previous = line

    return files


def is_ignored(path: str, ignored: Sequence[str]) -> bool:
    return any(path == prefix or path.startswith(f"{prefix}/") for prefix in ignored)


def measure(
    coverage: Dict[str, Dict[int, int]],
    changed: Dict[str, Set[int]],
    ignored: Sequence[str],
) -> List[FileResult]:
    """Split every changed, coverable line into covered and uncovered, per file."""
    results = []

    for path, lines in sorted(changed.items()):
        if is_ignored(path, ignored):
            continue

        counts = coverage.get(path)

        if not counts:
            continue

        executable = sorted(line for line in lines if line in counts)
        result = FileResult(
            path=path,
            covered=[line for line in executable if counts[line] > 0],
            uncovered=[line for line in executable if counts[line] == 0],
        )

        if result.changed:
            results.append(result)

    return results


def totals(results: Iterable[FileResult]) -> Tuple[int, int]:
    """Return (covered, changed) across all files."""
    results = list(results)
    return sum(len(result.covered) for result in results), sum(result.changed for result in results)


def percentage(covered: int, changed: int) -> float:
    """A pull request with nothing coverable to measure is treated as fully covered."""
    return covered / changed * 100 if changed else 100.0


def format_ranges(lines: Sequence[int]) -> str:
    """Collapse consecutive line numbers into `12-18, 42` so long lists stay readable."""
    ranges: List[List[int]] = []

    for line in lines:
        if ranges and line == ranges[-1][1] + 1:
            ranges[-1][1] = line
        else:
            ranges.append([line, line])

    return ', '.join(str(first) if first == last else f"{first}-{last}" for first, last in ranges)


def markdown_summary(results: List[FileResult], threshold: float) -> str:
    """Render the verdict, a per-file table, and where the uncovered lines are."""
    covered, changed = totals(results)
    ratio = percentage(covered, changed)
    passed = ratio >= threshold

    if not changed:
        headline = (
            "This pull request changes no lines the test suite can cover, "
            f"so the {threshold:g}% threshold does not apply."
        )
    else:
        verdict = "meets" if passed else "is below"
        headline = (
            f"**{ratio:.2f}%** of the {changed} changed lines that tests can cover are covered "
            f"— that {verdict} the required {threshold:g}%."
        )

    rows = [
        "| File | Coverage | Covered | Changed |",
        "| --- | --- | --- | --- |",
    ]
    rows += [
        f"| `{result.path}` | {percentage(len(result.covered), result.changed):.2f}% "
        f"| {len(result.covered)} | {result.changed} |"
        for result in sorted(results, key=lambda result: percentage(len(result.covered), result.changed))
    ]

    uncovered = [result for result in results if result.uncovered]
    details = []

    if uncovered:
        details = [
            '',
            '<details>',
            '<summary>Changed lines no test runs</summary>',
            '',
        ]
        details += [f"- `{result.path}`: {format_ranges(result.uncovered)}" for result in uncovered]
        details += ['', '</details>']

    return '\n'.join([
        "## Patch coverage",
        '',
        headline,
        '',
        *(rows if changed else []),
        *details,
        '',
    ])


def write_github_output(destination: Path, values: Dict[str, str]) -> None:
    """Append `key=value` pairs for later workflow steps to read."""
    with open(destination, 'a', encoding='utf-8') as handle:
        for key, value in values.items():
            handle.write(f"{key}={value}\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('lcov', type=Path, help="LCOV tracefile written by Tools/xccov_to_lcov.py")
    parser.add_argument('--base', default='origin/main', help="branch or commit the pull request targets")
    parser.add_argument('--threshold', type=float, default=90.0, help="required coverage of changed lines")
    parser.add_argument('--summary', type=Path, help="Markdown summary to append to")
    parser.add_argument('--github-output', type=Path, help="GitHub Actions output file to append results to")
    parser.add_argument('--ignore', nargs='*', default=list(DEFAULT_IGNORED_PATHS), help="paths to exclude")
    parser.add_argument('--repo-root', type=Path, default=Path.cwd(), help="repository the diff is taken in")
    arguments = parser.parse_args()

    if not arguments.lcov.is_file():
        print(f"No coverage tracefile at {arguments.lcov}", file=sys.stderr)
        sys.exit(1)

    results = measure(
        parse_lcov(arguments.lcov),
        parse_diff(read_diff(arguments.base, arguments.repo_root)),
        arguments.ignore,
    )

    covered, changed = totals(results)
    ratio = percentage(covered, changed)
    passed = ratio >= arguments.threshold

    summary = markdown_summary(results, arguments.threshold)
    print(summary)

    if arguments.summary:
        with open(arguments.summary, 'a', encoding='utf-8') as handle:
            handle.write(summary)

    if arguments.github_output:
        write_github_output(arguments.github_output, {
            'passed': str(passed).lower(),
            'coverage': f"{ratio:.2f}",
            'covered': str(covered),
            'changed': str(changed),
        })

    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
