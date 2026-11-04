#!/usr/bin/env python3
"""
Check that Swift Testing suites which change process-wide state declare how they are kept apart.

Swift Testing runs tests in parallel inside one process, so a test that assigns to `Current.*`
races every other test reading it unless it either runs under the shared-state lock
(`.sharedState`) or against its own environment (`.isolatedEnvironment`). `.serialized` is not
enough: it only separates the tests of one suite from each other.

Exits 1 and lists the offending files when a `Tests/**/*.swift` file that imports `Testing` assigns
to `Current`, writes the shared database, deletes app files or wipes a defaults domain without carrying
one of the two traits. XCTest classes are not checked: XCTest runs
its classes one at a time, and the test action keeps XCTest and Swift Testing phases apart.
"""

import re
import sys
from pathlib import Path

ASSIGNMENT = re.compile(r'\bCurrent\.[A-Za-z_][\w.]*\s*(?:=(?!=)|\+=|-=)')
# Writing the shared database, deleting files the app owns, or wiping a defaults domain is the same
# hazard as assigning to `Current`: every other test in the process reads that state. An in-memory
# `DatabaseQueue()` belongs to the test alone and is not matched.
SHARED_MUTATION = re.compile(
    r'database\(\)\.write|\bappDatabase\b|DatabaseQueue\(path:|drop\(table|removeItem\(at|'
    r'removePersistentDomain|deleteAll\(|\.erase\(|createTables\('
)
TRAITS = ('.sharedState', '.isolatedEnvironment')
# Comments and string literals, removed before matching so a `// TODO: add .sharedState` or a trait name inside a
# message does not count as the trait (and a commented-out assignment does not count as a mutation).
COMMENT_OR_STRING = re.compile(
    r'//[^\n]*'
    r'|/\*.*?\*/'
    r'|(#*)"""(?:\\.|[^\\])*?"""\1'
    r'|(#*)"(?:\\.|[^"\\\n])*"\2',
    re.DOTALL,
)


def code_only(text: str) -> str:
    return COMMENT_OR_STRING.sub(' ', text)


def offenders(root: Path):
    for path in sorted((root / 'Tests').rglob('*.swift')):
        text = code_only(path.read_text(encoding='utf-8'))
        if not re.search(r'^import Testing\b', text, re.MULTILINE):
            continue
        if not ASSIGNMENT.search(text) and not SHARED_MUTATION.search(text):
            continue
        if any(trait in text for trait in TRAITS):
            continue
        yield path.relative_to(root)


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    found = list(offenders(root))
    if not found:
        return 0
    print(
        "These Swift Testing files assign to `Current`, write the database or delete app files without `.sharedState` or "
        "`.isolatedEnvironment`, so they race other tests when run in parallel:",
        file=sys.stderr,
    )
    for path in found:
        print(f"  {path}", file=sys.stderr)
    print(
        "\nAdd `@Suite(.sharedState)` (or `.isolatedEnvironment`) from SharedTesting; "
        "see .agents/skills/ha-ios-testing/SKILL.md.",
        file=sys.stderr,
    )
    return 1


if __name__ == '__main__':
    sys.exit(main())
