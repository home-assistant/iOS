#!/usr/bin/env bash
# Starts or stops the nginx mTLS proxy in front of the E2E Home Assistant.
#
# Usage: proxy.sh start <cert-dir> [<upstream>]
#        proxy.sh stop <cert-dir>
#
#   cert-dir  the directory generate-certs.sh wrote; the rendered config, the pid file and the
#             logs go there too
#   upstream  host:port of Home Assistant (default 127.0.0.1:8123)
set -euo pipefail

ACTION="${1:?usage: proxy.sh start|stop <cert-dir> [<upstream>]}"
CERT_DIR="$(cd "${2:?usage: proxy.sh start|stop <cert-dir> [<upstream>]}" && pwd)"
UPSTREAM="${3:-127.0.0.1:8123}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$CERT_DIR/nginx.conf"

case "$ACTION" in
  start)
    mkdir -p "$CERT_DIR/tmp"
    sed -e "s|\${E2E_MTLS_DIR}|$CERT_DIR|g" -e "s|\${E2E_MTLS_UPSTREAM}|$UPSTREAM|g" \
      "$SCRIPT_DIR/nginx.conf.template" > "$CONF"
    nginx -t -c "$CONF" -p "$CERT_DIR"
    nginx -c "$CONF" -p "$CERT_DIR"
    echo "mTLS proxy listening on https://localhost:8443, forwarding to $UPSTREAM"
    ;;
  stop)
    if [ -f "$CERT_DIR/nginx.pid" ]; then
      nginx -s quit -c "$CONF" -p "$CERT_DIR" || kill "$(cat "$CERT_DIR/nginx.pid")" || true
    fi
    ;;
  *)
    echo "unknown action: $ACTION" >&2
    exit 1
    ;;
esac
