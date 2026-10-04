#!/usr/bin/env python3
"""Temporary, CI only: makes the watch app open straight on the Assist recording screen.

Adds `WatchAssistSnapshotRoot`, shows it as the app's root, and skips the notification permission
prompt that would otherwise cover the first screenshot.
"""

import pathlib
import shutil

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
WATCH_APP = ROOT / "Sources" / "WatchApp"


def replace_once(path: pathlib.Path, old: str, new: str) -> None:
    text = path.read_text()
    if text.count(old) != 1:
        raise SystemExit(f"Expected exactly one {old!r} in {path}")
    path.write_text(text.replace(old, new))


shutil.copy(HERE / "WatchAssistSnapshotRoot.swift.txt", WATCH_APP / "WatchAssistSnapshotRoot.swift")

replace_once(
    WATCH_APP / "HomeAssistantWatchApp.swift",
    "            WatchHomeView()\n",
    "            WatchAssistSnapshotRoot()\n",
)

# Dropped outright rather than skipped for snapshot launches: installing the app also launches it in
# the background, without the snapshot argument, and that launch would put the prompt up.
delegate = WATCH_APP / "ExtensionDelegate.swift"
lines = delegate.read_text().splitlines(keepends=True)
start = next(i for i, line in enumerate(lines) if "requestAuthorization(options: options)" in line)
del lines[start:start + 3]
delegate.write_text("".join(lines))

print("Prepared the watch app for Assist snapshots")
