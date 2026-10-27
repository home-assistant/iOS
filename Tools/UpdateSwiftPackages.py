#!/usr/bin/env python3
"""
Find and apply updates for the Swift packages the Xcode project depends on.

Renovate keeps the gems and GitHub Actions current, but it has no manager for the
package references inside `HomeAssistant.xcodeproj/project.pbxproj`, nor for the
`Package.resolved` Xcode derives from them. This script fills that gap, and the
weekly `Update Swift Packages` workflow opens one pull request per outdated package.

Run with no arguments to list the packages that have a newer release.
Run with `--apply <name>` to update one package (or `--apply-all` for every one):
the project's requirement, the local packages that pin the same dependency, the
resolved pins Xcode writes, and the `Package.resolved` mirror at the repository root.

Only versioned requirements (`exactVersion`, `upToNextMajorVersion`,
`upToNextMinorVersion`) and `branch` requirements are considered. A package pinned
to a `revision` is pinned on purpose and is left alone.
"""

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PROJECT_DIR = REPO_ROOT / "HomeAssistant.xcodeproj"
PBXPROJ = PROJECT_DIR / "project.pbxproj"
WORKSPACE = PROJECT_DIR / "project.xcworkspace"
RESOLVED = WORKSPACE / "xcshareddata" / "swiftpm" / "Package.resolved"
ROOT_RESOLVED_GENERATOR = REPO_ROOT / "Tools" / "GenerateSPMAcknowledgmentsPackageResolved.rb"
RESOLVE_SCHEME = "Tests-Unit"

VERSIONED_KINDS = {"exactVersion", "upToNextMajorVersion", "upToNextMinorVersion"}
SEMVER_TAG = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)$")
REMOTE_REFERENCE = re.compile(
    r'(?P<id>[0-9A-F]{24}) /\* XCRemoteSwiftPackageReference "(?P<name>[^"]+)" \*/ = \{\n'
    r"(?P<body>.*?)\n\t\t\};",
    re.DOTALL,
)
LOCAL_REFERENCE = re.compile(r"isa = XCLocalSwiftPackageReference;\n\s*relativePath = (?P<path>[^;]+);")


@dataclass
class PackageReference:
    name: str
    url: str
    kind: str
    version: str = ""
    branch: str = ""
    resolved_version: str = ""
    resolved_revision: str = ""
    latest: str = ""
    latest_revision: str = ""
    manifests: list = field(default_factory=list)

    @property
    def identity(self):
        return normalize_url(self.url).rsplit("/", 1)[-1].lower()

    @property
    def current(self):
        if self.kind == "branch":
            return self.resolved_revision[:7]
        return self.resolved_version or self.version

    @property
    def target(self):
        if self.kind == "branch":
            return self.latest_revision[:7]
        return self.latest

    @property
    def is_major_update(self):
        if self.kind == "branch" or not self.is_outdated:
            return False
        return parse_version(self.latest)[0] > parse_version(self.current)[0]

    @property
    def is_outdated(self):
        if self.kind == "branch":
            return bool(self.latest_revision) and self.latest_revision != self.resolved_revision
        return bool(self.latest) and parse_version(self.latest) > parse_version(self.current)

    def describe(self):
        return {
            "name": self.name,
            "identity": self.identity,
            "url": self.url,
            "kind": self.kind,
            "current": self.current,
            "latest": self.target,
            "major": self.is_major_update,
            "manifests": [str(path.relative_to(REPO_ROOT)) for path in self.manifests],
        }


def normalize_url(url):
    url = url.strip().rstrip("/")
    if url.endswith(".git"):
        url = url[:-4]
    return url.lower()


def parse_version(text):
    match = SEMVER_TAG.match(text)
    if not match:
        return (-1, -1, -1)
    return tuple(int(part) for part in match.groups())


def read_references():
    text = PBXPROJ.read_text()
    references = []
    for match in REMOTE_REFERENCE.finditer(text):
        body = match.group("body")
        url = re.search(r'repositoryURL = "([^"]+)";', body).group(1)
        kind = re.search(r"kind = (\w+);", body).group(1)
        reference = PackageReference(name=match.group("name"), url=url, kind=kind)
        version = re.search(r"(?:version|minimumVersion) = ([^;]+);", body)
        if version:
            reference.version = version.group(1).strip()
        branch = re.search(r"branch = ([^;]+);", body)
        if branch:
            reference.branch = branch.group(1).strip().strip('"')
        references.append(reference)
    return references


def read_resolved_pins():
    pins = {}
    for pin in json.loads(RESOLVED.read_text())["pins"]:
        pins[normalize_url(pin["location"])] = pin
    return pins


def read_local_manifests():
    manifests = []
    for match in LOCAL_REFERENCE.finditer(PBXPROJ.read_text()):
        manifest = REPO_ROOT / match.group("path").strip().strip('"') / "Package.swift"
        if manifest.exists():
            manifests.append(manifest)
    return manifests


def manifest_dependency_pattern(url):
    url_pattern = re.escape(normalize_url(url)) + r"(?:\.git)?/?"
    return re.compile(
        r'(?P<head>\.package\(\s*url:\s*"' + url_pattern + r'"\s*,\s*'
        r"(?:(?:exact|from):\s*|\.(?:exact\(|upToNextMajor\(from:\s*|upToNextMinor\(from:\s*)))"
        r'"(?P<version>[^"]+)"',
        re.IGNORECASE,
    )


def attach_context(references, pins, manifests):
    manifest_texts = {manifest: manifest.read_text() for manifest in manifests}
    for reference in references:
        pin = pins.get(normalize_url(reference.url))
        if pin:
            reference.resolved_version = pin["state"].get("version", "")
            reference.resolved_revision = pin["state"].get("revision", "")
        pattern = manifest_dependency_pattern(reference.url)
        for manifest, text in manifest_texts.items():
            if pattern.search(text):
                reference.manifests.append(manifest)


def git_ls_remote(url, *refs):
    result = subprocess.run(
        ["git", "ls-remote", "--refs", url, *refs],
        check=True,
        capture_output=True,
        text=True,
        env={**os.environ, "GIT_TERMINAL_PROMPT": "0"},
    )
    entries = []
    for line in result.stdout.splitlines():
        sha, _, ref = line.partition("\t")
        entries.append((sha, ref))
    return entries


def latest_tag(url):
    versions = []
    for _, ref in git_ls_remote(url, "refs/tags/*"):
        tag = ref.removeprefix("refs/tags/")
        if SEMVER_TAG.match(tag):
            versions.append((parse_version(tag), tag.lstrip("v")))
    if not versions:
        return ""
    return max(versions)[1]


def branch_head(url, branch):
    for sha, ref in git_ls_remote(url, f"refs/heads/{branch}"):
        if ref == f"refs/heads/{branch}":
            return sha
    return ""


def check_for_updates(references):
    for reference in references:
        if reference.kind in VERSIONED_KINDS:
            reference.latest = latest_tag(reference.url)
        elif reference.kind == "branch":
            reference.latest_revision = branch_head(reference.url, reference.branch)


def update_pbxproj(reference):
    text = PBXPROJ.read_text()

    def replace(match):
        if match.group("name") != reference.name:
            return match.group(0)
        body = re.sub(
            r"((?:version|minimumVersion) = )[^;]+;",
            lambda version: f"{version.group(1)}{reference.latest};",
            match.group("body"),
            count=1,
        )
        return match.group(0).replace(match.group("body"), body)

    updated = REMOTE_REFERENCE.sub(replace, text)
    if updated == text:
        raise RuntimeError(f"Could not find the requirement for {reference.name} in project.pbxproj")
    PBXPROJ.write_text(updated)


def update_manifests(reference):
    pattern = manifest_dependency_pattern(reference.url)
    for manifest in reference.manifests:
        text = manifest.read_text()
        updated = pattern.sub(lambda match: f'{match.group("head")}"{reference.latest}"', text)
        if updated != text:
            manifest.write_text(updated)
            print(f"Updated {manifest.relative_to(REPO_ROOT)}")


def drop_resolved_pin(reference):
    resolved = json.loads(RESOLVED.read_text())
    url = normalize_url(reference.url)
    resolved["pins"] = [pin for pin in resolved["pins"] if normalize_url(pin["location"]) != url]
    RESOLVED.write_text(json.dumps(resolved, indent=2) + "\n")


def resolve_packages():
    subprocess.run(
        [
            "xcodebuild",
            "-resolvePackageDependencies",
            "-project",
            str(PROJECT_DIR),
            "-scheme",
            RESOLVE_SCHEME,
        ],
        check=True,
        cwd=REPO_ROOT,
    )
    subprocess.run(
        ["ruby", str(ROOT_RESOLVED_GENERATOR)],
        check=True,
        cwd=REPO_ROOT,
        env={**os.environ, "WORKSPACE_PATH": str(WORKSPACE), "PROJECT_DIR": str(REPO_ROOT)},
    )


def verify_resolved(reference):
    pin = read_resolved_pins().get(normalize_url(reference.url))
    if not pin:
        raise RuntimeError(f"{reference.name} is missing from Package.resolved after resolving")
    state = pin["state"]
    if reference.kind == "branch":
        if state.get("revision") != reference.latest_revision:
            raise RuntimeError(
                f"{reference.name} resolved to {state.get('revision')} instead of {reference.latest_revision}"
            )
    elif state.get("version") != reference.latest:
        raise RuntimeError(f"{reference.name} resolved to {state.get('version')} instead of {reference.latest}")


def apply_update(reference):
    print(f"Updating {reference.name} from {reference.current} to {reference.target}")
    if reference.kind == "branch":
        drop_resolved_pin(reference)
    else:
        update_pbxproj(reference)
        update_manifests(reference)
    resolve_packages()
    verify_resolved(reference)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--json", action="store_true", help="print the outdated packages as JSON")
    parser.add_argument("--apply", metavar="NAME", action="append", default=[], help="update this package")
    parser.add_argument("--apply-all", action="store_true", help="update every outdated package")
    args = parser.parse_args()

    references = read_references()
    attach_context(references, read_resolved_pins(), read_local_manifests())
    check_for_updates(references)

    outdated = [reference for reference in references if reference.is_outdated]
    by_name = {reference.name: reference for reference in references}

    if args.json:
        print(json.dumps([reference.describe() for reference in outdated]))
    else:
        for reference in references:
            if reference.kind not in VERSIONED_KINDS and reference.kind != "branch":
                print(f"{reference.name}: pinned by {reference.kind}, skipped")
            elif reference.is_outdated:
                print(f"{reference.name}: {reference.current} -> {reference.target}")
            else:
                print(f"{reference.name}: {reference.current} is the latest")

    to_apply = outdated if args.apply_all else []
    for name in args.apply:
        reference = by_name.get(name)
        if reference is None:
            print(f"Unknown package {name}; known: {', '.join(sorted(by_name))}", file=sys.stderr)
            return 1
        if not reference.is_outdated:
            print(f"{name} is already up to date; nothing to do.")
            continue
        to_apply.append(reference)

    for reference in to_apply:
        apply_update(reference)
    return 0


if __name__ == "__main__":
    sys.exit(main())
