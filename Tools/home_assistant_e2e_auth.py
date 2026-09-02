#!/usr/bin/env python3
"""
Authenticate against a Home Assistant instance the way the app does during onboarding.

Walks the same indieauth exchange `OnboardingAuth` performs: start a login flow, submit the
username and password, trade the resulting authorization code for an access token, then read
`/api/config` with it. Used by the E2E workflow to prove the instance it just started is usable
by the app before any UI test is pointed at it, and to fail loudly with the reason when it is not.
"""

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

POLL_INTERVAL = 5


class AuthError(Exception):
    """A step of the login exchange returned something the app would not accept."""


def request(url: str, *, data: Optional[bytes] = None, headers: Optional[Dict[str, str]] = None,
            content_type: Optional[str] = None) -> Any:
    """Perform one request and decode the JSON body, reporting the server's body on failure."""
    req = urllib.request.Request(url, data=data, headers=headers or {})
    if content_type:
        req.add_header('Content-Type', content_type)

    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            body = response.read().decode('utf-8', errors='replace')
    except urllib.error.HTTPError as error:
        detail = error.read().decode('utf-8', errors='replace').strip()
        raise AuthError(f"{req.get_method()} {url} failed: HTTP {error.code} {detail}") from error
    except urllib.error.URLError as error:
        raise AuthError(f"{req.get_method()} {url} failed: {error.reason}") from error

    try:
        return json.loads(body)
    except json.JSONDecodeError as error:
        # A proxy or a misconfigured instance can answer 2xx with an HTML error page.
        raise AuthError(f"{req.get_method()} {url} returned a non-JSON body: {body.strip()[:500]}") from error


def post_json(url: str, payload: Dict[str, Any], headers: Optional[Dict[str, str]] = None) -> Any:
    return request(url, data=json.dumps(payload).encode('utf-8'), headers=headers,
                   content_type='application/json')


def access_token(base_url: str, username: str, password: str) -> str:
    """
    Log in and return a long-lived-enough access token.

    `client_id` doubles as the redirect URI: Home Assistant skips fetching and validating the
    client when the two share a host, which is what keeps this usable without a real redirect
    target. The app passes its own `homeassistant://auth-callback` pair here instead.
    """
    client_id = f"{base_url}/"

    flow = post_json(f"{base_url}/auth/login_flow", {
        'client_id': client_id,
        'handler': ['homeassistant', None],
        'redirect_uri': client_id,
        'type': 'authorize',
    })

    flow_id = flow.get('flow_id')
    if not flow_id:
        raise AuthError(f"login flow did not start: {json.dumps(flow)}")

    step = post_json(f"{base_url}/auth/login_flow/{flow_id}", {
        'client_id': client_id,
        'username': username,
        'password': password,
    })

    if step.get('type') != 'create_entry':
        # `invalid_auth` here means the seeded `.storage/auth` no longer matches the credentials.
        raise AuthError(f"login was rejected: {json.dumps(step)}")

    code = step.get('result')
    if not code:
        raise AuthError(f"login succeeded without an authorization code: {json.dumps(step)}")

    token = request(f"{base_url}/auth/token", data=urllib.parse.urlencode({
        'client_id': client_id,
        'code': code,
        'grant_type': 'authorization_code',
    }).encode('utf-8'), content_type='application/x-www-form-urlencoded')

    if not token.get('access_token'):
        raise AuthError(f"token exchange returned no access token: {json.dumps(token)}")

    return token['access_token']


def check(base_url: str, username: str, password: str,
          required: List[str]) -> Tuple[Optional[Dict[str, Any]], Optional[str]]:
    """Log in and read `/api/config`, returning it alongside the reason it is not usable yet."""
    try:
        token = access_token(base_url, username, password)
        config = request(f"{base_url}/api/config", headers={'Authorization': f"Bearer {token}"})
    except AuthError as error:
        return None, str(error)

    # `state` is reported from 2023.4 on. Home Assistant serves the frontend and answers the API
    # while integrations are still being set up, so a component missing before then means nothing.
    state = config.get('state')
    if state and state != 'RUNNING':
        return config, f"Home Assistant is {state}, not RUNNING"

    missing = [name for name in required if name not in set(config.get('components', []))]
    if missing:
        return config, f"Home Assistant did not load: {', '.join(missing)}"

    return config, None


def write_summary(summary: Path, config: Dict[str, Any], required: List[str]) -> None:
    lines = [
        '## Home Assistant',
        '',
        f"- Version: `{config.get('version', 'unknown')}`",
        f"- Components loaded: {len(config.get('components', []))}",
        f"- Required components present: {', '.join(f'`{name}`' for name in required)}",
        '',
    ]
    with summary.open('a', encoding='utf-8') as handle:
        handle.write('\n'.join(lines))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', required=True, help="base URL of the instance, without a trailing slash")
    parser.add_argument('--username', required=True, help="username seeded into .storage/auth")
    parser.add_argument('--password', required=True, help="password seeded into .storage/auth")
    parser.add_argument('--require-component', action='append', default=[], metavar='NAME',
                        help="fail unless this component is loaded; repeatable")
    parser.add_argument('--timeout', type=int, default=0, metavar='SECONDS',
                        help="keep retrying for this long before giving up; default is one attempt")
    parser.add_argument('--output', type=Path, help="write the fetched /api/config here")
    parser.add_argument('--summary', type=Path, help="Markdown summary to append to")
    args = parser.parse_args()

    base_url = args.url.rstrip('/')
    deadline = time.monotonic() + args.timeout

    while True:
        config, failure = check(base_url, args.username, args.password, args.require_component)
        if failure is None or time.monotonic() >= deadline:
            break
        time.sleep(POLL_INTERVAL)

    if config and args.output:
        args.output.write_text(json.dumps(config, indent=2), encoding='utf-8')

    if failure:
        print(f"::error::{failure}", file=sys.stderr)
        return 1

    print(f"Authenticated as {args.username} against Home Assistant {config.get('version', 'unknown')}, "
          f"{len(config.get('components', []))} components loaded")

    if args.summary:
        write_summary(args.summary, config, args.require_component)

    return 0


if __name__ == '__main__':
    sys.exit(main())
