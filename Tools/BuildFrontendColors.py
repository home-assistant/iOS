#!/usr/bin/env python3
"""Generate FrontendColors.swift from the Home Assistant frontend color theme.

The frontend defines its interface colors as CSS custom properties in
``src/resources/theme/color/color.globals.ts``. This script fetches that file
(from the ``dev`` branch by default), extracts the color-valued declarations
from the light (``colorStyles``) and dark (``darkColorStyles``) blocks, and
writes a Swift enum mirroring them so the native app can reference the same
palette.

Only the data lives in the generated file. The logic that turns a raw CSS value
into a resolved color is hand written in ``FrontendColors+Color.swift``.

Usage:
    Tools/BuildFrontendColors.py                 # fetch dev + regenerate
    Tools/BuildFrontendColors.py --source PATH    # parse a local .ts file
    Tools/BuildFrontendColors.py --check          # fail if output is stale
"""

from __future__ import annotations

import argparse
import re
import sys
import urllib.request
from pathlib import Path

SOURCE_URL = (
    "https://raw.githubusercontent.com/home-assistant/frontend/dev/"
    "src/resources/theme/color/color.globals.ts"
)

REPO_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_PATH = REPO_ROOT / "Sources/HADesignSystem/Sources/Colors/FrontendColors.swift"

# Markers delimiting the two exported `css` template literals in the source.
LIGHT_MARKER = "export const colorStyles ="
DARK_MARKER = "export const darkColorStyles ="
END_MARKER = "export const DefaultPrimaryColor"

# Matches a single `--name: value;` CSS declaration.
DECLARATION_RE = re.compile(r"--([A-Za-z0-9_-]+)\s*:\s*([^;{}]+);")
BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", re.DOTALL)

HEX_RE = re.compile(r"#[0-9A-Fa-f]{3,8}$")
FUNCTION_RE = re.compile(r"(?:rgba?|var)\(.*\)$", re.IGNORECASE)

# Swift reserved and contextual keywords. A generated case name that lands on
# one of these is escaped with backticks so the output always compiles, even if
# the upstream CSS introduces a variable that maps to a keyword. Case names are
# lowercase-initial, so lowercase forms are what actually need matching.
SWIFT_KEYWORDS = {
    # Keywords used in declarations
    "associatedtype", "borrowing", "class", "consuming", "deinit", "enum",
    "extension", "fileprivate", "func", "import", "init", "inout", "internal",
    "let", "macro", "nonisolated", "open", "operator", "precedencegroup",
    "private", "protocol", "public", "rethrows", "static", "struct",
    "subscript", "typealias", "var",
    # Keywords used in statements
    "break", "case", "catch", "continue", "default", "defer", "do", "else",
    "fallthrough", "for", "guard", "if", "in", "repeat", "return", "switch",
    "throw", "where", "while",
    # Keywords used in expressions and types
    "any", "as", "async", "await", "each", "false", "is", "nil", "self",
    "some", "super", "throws", "true", "try",
    # Contextual keywords and patterns
    "actor", "isolated", "_",
}


def load_source(source: str) -> str:
    if re.match(r"^https?://", source):
        try:
            with urllib.request.urlopen(source, timeout=30) as response:  # noqa: S310 (trusted host)
                return response.read().decode("utf-8")
        except OSError as error:
            raise SystemExit(f"error: failed to fetch {source}: {error}") from error
    return Path(source).read_text(encoding="utf-8")


def slice_block(text: str, start_marker: str, end_marker: str | None) -> str:
    start = text.find(start_marker)
    if start == -1:
        raise ValueError(f"Could not find marker: {start_marker!r}")
    end = text.find(end_marker, start) if end_marker else -1
    return text[start:] if end == -1 else text[start:end]


def is_color(value: str) -> bool:
    if value == "transparent":
        return True
    if HEX_RE.match(value):
        return True
    return bool(FUNCTION_RE.match(value))


def parse_block(block: str) -> "dict[str, str]":
    """Return an ordered mapping of `--name` -> value for color declarations."""
    block = BLOCK_COMMENT_RE.sub("", block)
    colors: dict[str, str] = {}
    for name, raw_value in DECLARATION_RE.findall(block):
        value = re.sub(r"\s+", " ", raw_value).strip()
        if is_color(value):
            colors[f"--{name}"] = value
    return colors


def swift_case(css_name: str) -> str:
    parts = [part for part in re.split(r"[-_]+", css_name.lstrip("-")) if part]
    head = parts[0].lower()
    tail = "".join(part[:1].upper() + part[1:].lower() for part in parts[1:])
    name = head + tail
    return f"`{name}`" if name in SWIFT_KEYWORDS else name


def build_cases(light: "dict[str, str]", dark: "dict[str, str]") -> "list[tuple[str, str]]":
    """Return ordered (swiftCase, cssName) pairs, light order then dark-only."""
    ordered_css = list(light.keys()) + [key for key in dark if key not in light]
    cases: list[tuple[str, str]] = []
    seen: dict[str, str] = {}
    for css_name in ordered_css:
        case = swift_case(css_name)
        if case in seen:
            raise ValueError(
                f"Swift case collision: {css_name!r} and {seen[case]!r} "
                f"both map to {case!r}"
            )
        seen[case] = css_name
        cases.append((case, css_name))
    return cases


def render(light: "dict[str, str]", dark: "dict[str, str]", source: str) -> str:
    cases = build_cases(light, dark)

    lines: list[str] = [
        "// swiftformat:disable all",
        "// Generated by Tools/BuildFrontendColors.py — DO NOT EDIT.",
        "//",
        "// Source: home-assistant/frontend",
        f"//   {source}",
        "//",
        "// Regenerate with: Tools/BuildFrontendColors.py",
        "",
        "import Foundation",
        "",
        "/// Color custom properties defined by the Home Assistant frontend theme.",
        "///",
        "/// Each case corresponds to a CSS custom property from `color.globals.ts`;",
        "/// its `rawValue` is the property name (for example `--primary-color`). Use",
        "/// ``lightValue`` / ``darkValue`` for the raw CSS strings, or the resolution",
        "/// helpers in `FrontendColors+Color.swift` for parsed colors.",
        "public enum FrontendColors: String, CaseIterable {",
    ]
    for case, css_name in cases:
        lines.append(f'    case {case} = "{css_name}"')
    lines.append("}")
    lines.append("")
    lines.append("public extension FrontendColors {")
    lines.append("    /// The raw CSS value declared in the default (light) theme, if any.")
    lines.append("    var lightValue: String? {")
    lines.append("        switch self {")
    for case, css_name in cases:
        if css_name in light:
            lines.append(f'        case .{case}: return "{light[css_name]}"')
    lines.append("        default: return nil")
    lines.append("        }")
    lines.append("    }")
    lines.append("")
    lines.append("    /// The raw CSS value declared by the dark theme override, if any.")
    lines.append("    var darkValue: String? {")
    lines.append("        switch self {")
    for case, css_name in cases:
        if css_name in dark:
            lines.append(f'        case .{case}: return "{dark[css_name]}"')
    lines.append("        default: return nil")
    lines.append("        }")
    lines.append("    }")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def main(argv: "list[str]") -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default=SOURCE_URL, help="URL or path to color.globals.ts")
    parser.add_argument("--output", default=str(OUTPUT_PATH), help="Path to the generated Swift file")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit non-zero if the generated file is out of date instead of writing it",
    )
    args = parser.parse_args(argv)

    text = load_source(args.source)
    light = parse_block(slice_block(text, LIGHT_MARKER, DARK_MARKER))
    dark = parse_block(slice_block(text, DARK_MARKER, END_MARKER))
    if not light:
        print("error: no color declarations found; source format may have changed", file=sys.stderr)
        return 1

    source_label = SOURCE_URL if args.source == SOURCE_URL else args.source
    rendered = render(light, dark, source_label)

    output = Path(args.output)
    existing = output.read_text(encoding="utf-8") if output.exists() else None

    if args.check:
        if existing == rendered:
            print(f"{output} is up to date ({len(light)} light, {len(dark)} dark)")
            return 0
        print(f"error: {output} is out of date; run Tools/BuildFrontendColors.py", file=sys.stderr)
        return 1

    if existing == rendered:
        print(f"{output} already up to date ({len(light)} light, {len(dark)} dark)")
        return 0

    output.write_text(rendered, encoding="utf-8")
    print(f"Wrote {output} ({len(light)} light, {len(dark)} dark)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
