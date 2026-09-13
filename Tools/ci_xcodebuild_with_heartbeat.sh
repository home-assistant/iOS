#!/bin/bash
# Runs xcodebuild with its output in a log file rather than on the console, printing a
# one-line heartbeat while it works. A cold build of this project takes long enough that
# a silent step is indistinguishable from a hung one, and streaming the whole log instead
# buries the errors. Exits with xcodebuild's own status, so a failure fails the step.
#
# Usage: ci_xcodebuild_with_heartbeat.sh <log-file> <xcodebuild arguments...>

set -u

log_file="$1"
shift

: > "$log_file"

heartbeat() {
  while true; do
    sleep 60
    printf '··· %s  %s lines  %s\n' \
      "$(date -u +%H:%M:%S)" "$(wc -l < "$log_file" | tr -d ' ')" "$(tail -n 1 "$log_file")"
  done
}

heartbeat &
heartbeat_pid=$!
trap 'kill "$heartbeat_pid" 2>/dev/null' EXIT

NSUnbufferedIO=YES xcodebuild "$@" >> "$log_file" 2>&1
status=$?

kill "$heartbeat_pid" 2>/dev/null
trap - EXIT

echo "=== errors, failures and the build result ==="
grep -E 'error:|error generated|BUILD FAILED|BUILD SUCCEEDED|TEST FAILED|TEST SUCCEEDED|failed$' \
  "$log_file" | head -n 100 || true

echo "=== test cases ==="
grep -E "^Test Case .*(passed|failed)|^\s+Executed [0-9]+ test" "$log_file" | head -n 60 || true

echo "=== last 60 lines ==="
tail -n 60 "$log_file"

echo "=== xcodebuild exited with $status ==="
exit "$status"
