#!/usr/bin/env bash
# measure-latency.sh — manual latency harness for AC14 (T16)
#
# PURPOSE
#   Measures the end-to-end latency from a disk write to the React render
#   commit in the flow-monitor Tauri dev app. Computes p95 over 20 writes
#   and asserts p95 ≤ 1000ms.
#
# PREREQUISITE
#   You MUST have `npm run tauri dev` running in a separate terminal before
#   invoking this script. The script does not auto-start the app. The dev
#   app must have imported.meta.env.DEV console.log instrumentation active
#   (added in artifactStore.ts by this T16 task).
#
# PROCEDURE (for the manual AC14 run-through)
#   1. In terminal A: cd flow-monitor && npm run tauri dev
#      Wait until the Tauri window appears and the watcher is running
#      (green pip in LiveWatchFooter).
#   2. In terminal B: CONSOLE_LOG=<path-to-tauri-dev-log> bash \
#        flow-monitor/scripts/measure-latency.sh
#      Where <path-to-tauri-dev-log> is the file you redirected tauri dev
#      stdout to, e.g.:
#        npm run tauri dev > /tmp/tauri-dev.log 2>&1
#      If CONSOLE_LOG is not set, the script prints usage and exits 0.
#   3. The script writes a fixture file 20 times (sleep 0.2 between writes),
#      tails the console log for LATENCY_MS lines emitted by artifactStore,
#      computes p95, and exits 0 if p95 ≤ 1000ms, non-zero otherwise.
#
# AC14 PASS CRITERION
#   p95 of (disk_write_ts → render_commit_ts) delta ≤ 1000ms across 20 writes.

set -euo pipefail

# ---------------------------------------------------------------------------
# Sandbox-HOME header — mandatory per .claude/rules/bash/sandbox-home-in-tests.md
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
SCRIPT_NAME="$(basename "$0")"

usage() {
  printf 'Usage: %s [--help]\n' "$SCRIPT_NAME"
  printf '\n'
  printf 'Manual latency harness for flow-monitor AC14.\n'
  printf '\n'
  printf 'Environment variables:\n'
  printf '  CONSOLE_LOG   Path to file where `npm run tauri dev` stdout is redirected.\n'
  printf '                Required for the full p95 measurement run.\n'
  printf '  FIXTURE_SLUG  Feature slug to write under .specaffold/features/.\n'
  printf '                Defaults to: latency-test-fixture\n'
  printf '  WRITE_COUNT   Number of fixture writes (default: 20)\n'
  printf '  WRITE_DELAY   Sleep between writes in seconds (default: 0.2)\n'
  printf '  P95_LIMIT_MS  p95 assertion ceiling in milliseconds (default: 1000)\n'
  printf '\n'
  printf 'Prerequisite: `npm run tauri dev` must be running in another terminal.\n'
  printf 'See script header for the full manual procedure.\n'
}

case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
CONSOLE_LOG="${CONSOLE_LOG:-}"
FIXTURE_SLUG="${FIXTURE_SLUG:-latency-test-fixture}"

# Validate FIXTURE_SLUG: must not contain '/' or '..' (path traversal guard).
case "$FIXTURE_SLUG" in
  */*|*..*) printf 'FAIL: FIXTURE_SLUG must not contain "/" or "..": %s\n' "$FIXTURE_SLUG" >&2; exit 2 ;;
esac

WRITE_COUNT="${WRITE_COUNT:-20}"
WRITE_DELAY="${WRITE_DELAY:-0.2}"
P95_LIMIT_MS="${P95_LIMIT_MS:-1000}"

if [ -z "$CONSOLE_LOG" ]; then
  printf 'INFO: CONSOLE_LOG is not set — skipping live measurement.\n'
  printf 'Set CONSOLE_LOG to the path of your tauri dev stdout log and re-run.\n'
  printf 'Example:\n'
  printf '  npm run tauri dev > /tmp/tauri-dev.log 2>&1 &\n'
  printf '  CONSOLE_LOG=/tmp/tauri-dev.log bash %s\n' "$SCRIPT_NAME"
  exit 0
fi

if [ ! -f "$CONSOLE_LOG" ]; then
  printf 'ERROR: CONSOLE_LOG file not found: %s\n' "$CONSOLE_LOG" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Build fixture path under sandbox (not real HOME — sandbox is isolated)
# ---------------------------------------------------------------------------
FIXTURE_DIR="$SANDBOX/repo/.specaffold/features/$FIXTURE_SLUG"
FIXTURE_FILE="$FIXTURE_DIR/03-prd.md"
mkdir -p "$FIXTURE_DIR"

printf 'INFO: writing fixture to %s (%s times, %ss delay)\n' \
  "$FIXTURE_FILE" "$WRITE_COUNT" "$WRITE_DELAY"

# ---------------------------------------------------------------------------
# Collect baseline log line count before writes begin (batch read — no fork in loop)
# ---------------------------------------------------------------------------
BASELINE_LINES="$(wc -l < "$CONSOLE_LOG" | tr -d ' ')"

# ---------------------------------------------------------------------------
# Write fixture WRITE_COUNT times.  The script-side timestamp is not needed:
# latency is computed from the [artifactStore] LATENCY_MS= log line emitted
# by artifactStore.ts at render-commit time, so the file's OS mtime alone
# triggers the watcher.  No per-iteration shell-out.
# ---------------------------------------------------------------------------
i=1
while [ "$i" -le "$WRITE_COUNT" ]; do
  printf 'iteration %d\n' "$i" > "$FIXTURE_FILE"
  i=$((i + 1))
  if [ "$i" -le "$WRITE_COUNT" ]; then
    sleep "$WRITE_DELAY"
  fi
done

printf 'INFO: all writes complete; waiting 3s for events to flush\n'
sleep 3

# ---------------------------------------------------------------------------
# Extract LATENCY_MS values from log lines emitted after baseline.
# artifactStore.ts logs lines in the form:
#   [artifactStore] LATENCY_MS=<number>
# Use awk for in-process extraction (no python3 spawn per performance rule).
# ---------------------------------------------------------------------------
DELTAS_FILE="$SANDBOX/deltas.txt"

awk -v baseline="$BASELINE_LINES" \
    'NR > baseline && /\[artifactStore\] LATENCY_MS=/ {
       split($0, parts, "LATENCY_MS=")
       val = parts[2] + 0
       if (val > 0) print val
     }' "$CONSOLE_LOG" > "$DELTAS_FILE"

DELTA_COUNT="$(wc -l < "$DELTAS_FILE" | tr -d ' ')"

if [ "$DELTA_COUNT" -eq 0 ]; then
  printf 'WARN: no LATENCY_MS lines captured in log after writes.\n'
  printf 'Ensure the Tauri dev app is running with DEV mode active.\n'
  exit 1
fi

printf 'INFO: captured %s delta samples\n' "$DELTA_COUNT"

# ---------------------------------------------------------------------------
# Compute p95 using awk sort (no python3 — awk is always available on macOS).
# Sort numerically, pick the value at the 95th-percentile index.
# ---------------------------------------------------------------------------
P95="$(sort -n "$DELTAS_FILE" | awk -v count="$DELTA_COUNT" '
  BEGIN { idx = int(count * 0.95 + 0.5) }
  NR == idx { print; exit }
')"

printf 'INFO: p95 latency = %sms (limit: %sms)\n' "$P95" "$P95_LIMIT_MS"

if [ "$P95" -le "$P95_LIMIT_MS" ]; then
  printf 'PASS: p95 %sms ≤ %sms\n' "$P95" "$P95_LIMIT_MS"
  exit 0
else
  printf 'FAIL: p95 %sms > %sms\n' "$P95" "$P95_LIMIT_MS" >&2
  exit 1
fi
