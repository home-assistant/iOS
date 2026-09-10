#!/usr/bin/env python3
"""Attach a notarized macOS build to a draft GitHub release.

Xcode Cloud has no equivalent of a workflow artifact, so a Developer ID build made there needs
somewhere for release_macos.yml to pick it up from. This stages it on a draft prerelease named
after the version it was built from; publishing stays a deliberate step in the release workflows.
"""

import json
import mimetypes
import os
import sys
import urllib.error
import urllib.request

API = "https://api.github.com"
UPLOADS = "https://uploads.github.com"


def request(method, url, token, data=None, content_type=None, length=None):
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "home-assistant-ios-xcode-cloud",
    }
    if content_type:
        headers["Content-Type"] = content_type
    if length is not None:
        headers["Content-Length"] = str(length)

    req = urllib.request.Request(url, method=method, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req) as response:
            body = response.read()
            return response.status, json.loads(body) if body else None
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", "replace")
        if error.code == 404:
            return 404, None
        raise SystemExit(f"error: {method} {url} failed with {error.code}: {body}")


def find_release(repo, tag, token):
    page = 1
    while page <= 5:
        _, releases = request("GET", f"{API}/repos/{repo}/releases?per_page=100&page={page}", token)
        if not releases:
            return None
        for release in releases:
            if release.get("tag_name") == tag:
                return release
        page += 1
    return None


def main():
    token = os.environ.get("GITHUB_RELEASE_TOKEN")
    if not token:
        raise SystemExit("error: GITHUB_RELEASE_TOKEN is not set")

    repo = os.environ.get("GITHUB_REPOSITORY", "home-assistant/iOS")
    asset_path = sys.argv[1]
    tag = sys.argv[2]
    release_name = sys.argv[3]
    asset_name = os.path.basename(asset_path)

    release = find_release(repo, tag, token)
    if release is None:
        payload = {
            "tag_name": tag,
            "name": release_name,
            "draft": True,
            "prerelease": True,
            "body": "Staged by Xcode Cloud. Publish through the macOS release workflow.",
        }
        commit = os.environ.get("CI_COMMIT")
        if commit:
            payload["target_commitish"] = commit
        _, release = request(
            "POST",
            f"{API}/repos/{repo}/releases",
            token,
            data=json.dumps(payload).encode(),
            content_type="application/json",
        )
        print(f"Created draft release {tag}")
    else:
        print(f"Reusing draft release {tag}")

    release_id = release["id"]
    _, assets = request("GET", f"{API}/repos/{repo}/releases/{release_id}/assets?per_page=100", token)
    for asset in assets or []:
        if asset["name"] == asset_name:
            request("DELETE", f"{API}/repos/{repo}/releases/assets/{asset['id']}", token)
            print(f"Replaced existing {asset_name}")

    with open(asset_path, "rb") as handle:
        payload = handle.read()

    content_type = mimetypes.guess_type(asset_name)[0] or "application/octet-stream"
    request(
        "POST",
        f"{UPLOADS}/repos/{repo}/releases/{release_id}/assets?name={asset_name}",
        token,
        data=payload,
        content_type=content_type,
        length=len(payload),
    )
    print(f"Uploaded {asset_name} ({len(payload)} bytes) to {release['html_url']}")


if __name__ == "__main__":
    main()
