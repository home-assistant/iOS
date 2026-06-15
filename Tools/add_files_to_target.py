#!/usr/bin/env python3
"""Add source files to a target's Sources phase in HomeAssistant.xcodeproj.

Usage: add_files_to_target.py <target-name> <repo-relative-path>...

Creates a SOURCE_ROOT-anchored PBXFileReference + PBXBuildFile per path and
appends to the target's Sources build phase. Additive-only; skips files already
in the phase. UUIDs use the FAB4 prefix with a persistent counter derived from
existing entries.
"""
import re
import sys

PBX = "HomeAssistant.xcodeproj/project.pbxproj"

target_name = sys.argv[1]
paths = sys.argv[2:]

with open(PBX) as f:
    text = f.read()

# next FAB4 counter
existing = [int(m, 16) for m in re.findall(r"\bFAB4([0-9A-F]{20})\b", text)]
counter = max(existing) if existing else 0


def uuid() -> str:
    global counter
    counter += 1
    return f"FAB4{counter:020X}"


# locate target's sources phase
tm = re.search(
    rf"/\* {re.escape(target_name)} \*/ = \{{\n\t\t\tisa = PBXNativeTarget;.*?buildPhases = \((.*?)\);",
    text,
    re.S,
)
assert tm, f"target not found: {target_name}"
sm = re.search(r"([A-F0-9]{24}) /\* Sources \*/", tm.group(1))
assert sm, "sources phase not found"
phase_uuid = sm.group(1)

phase_re = re.compile(
    rf"({phase_uuid} /\* Sources \*/ = \{{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = \d+;\n\t\t\tfiles = \(\n)"
)
assert phase_re.search(text), "sources phase block not found"

new_refs = ""
new_bfs = ""
new_phase_lines = ""
for path in paths:
    name = path.rsplit("/", 1)[-1]
    if f"path = {path};" in text or f'path = "{path}";' in text:
        # fileref exists; find its uuid
        m = re.search(rf"([A-F0-9]{{24}}) /\* [^*]+ \*/ = \{{isa = PBXFileReference;[^\n]*path = \"?{re.escape(path)}\"?;", text)
        ref = m.group(1)
    else:
        ref = uuid()
        quoted = f'"{path}"' if any(c in path for c in " +") else path
        qname = f'"{name}"' if any(c in name for c in " +") else name
        new_refs += (
            f"\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; "
            f"name = {qname}; path = {quoted}; sourceTree = SOURCE_ROOT; }};\n"
        )
    bf = uuid()
    new_bfs += f"\t\t{bf} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};\n"
    new_phase_lines += f"\t\t\t\t{bf} /* {name} in Sources */,\n"

text = text.replace("/* End PBXBuildFile section */", new_bfs + "/* End PBXBuildFile section */", 1)
if new_refs:
    text = text.replace("/* End PBXFileReference section */", new_refs + "/* End PBXFileReference section */", 1)
text = phase_re.sub(lambda m: m.group(1) + new_phase_lines, text, count=1)

with open(PBX, "w") as f:
    f.write(text)
print(f"added {len(paths)} file(s) to {target_name}")
