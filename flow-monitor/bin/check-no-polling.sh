#!/usr/bin/env bash
# check-no-polling.sh — static grep gate for AC13
# Exits 0 if no prohibited polling patterns are present; exits 1 printing
# file:line for each hit.  Read-only static grep; no sandbox-HOME (D10).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUST_SRC="$FM_ROOT/src-tauri/src"
FE_SRC="$FM_ROOT/src"

FOUND=0

# check_hits HITS — print non-empty lines and set FOUND=1.
check_hits() {
  local hits="$1"
  if [ -n "$hits" ]; then
    printf '%s\n' "$hits"
    FOUND=1
  fi
}

# --- Rust patterns ---
# Comment-only lines in grep output have content (after "file:N:") starting
# with optional spaces then "//".  Strip them with grep -Ev.

# 1. tokio::time::interval (polling timer — prohibited everywhere in src)
hits=$(grep -rn --include="*.rs" --exclude-dir=target --exclude-dir=.bak \
  -E 'tokio::time::interval' "$RUST_SRC" 2>/dev/null \
  | grep -Ev ':[0-9]+:[[:space:]]*//' || true)
check_hits "$hits"

# 2. tokio::time::sleep with seconds-scale duration.
#    Excludes lock.rs: that file contains an intentional 60s crash-recovery
#    watchdog (AC7.b) which is not a polling sleep.
hits=$(grep -rn --include="*.rs" --exclude-dir=target --exclude-dir=.bak \
  -E 'tokio::time::sleep\(Duration::from_secs' "$RUST_SRC" 2>/dev/null \
  | grep -v '/lock\.rs:' \
  | grep -Ev ':[0-9]+:[[:space:]]*//' || true)
check_hits "$hits"

# 3. polling_cycle_complete (function deleted by T11; no references should remain)
hits=$(grep -rn --include="*.rs" --exclude-dir=target --exclude-dir=.bak \
  -E 'polling_cycle_complete' "$RUST_SRC" 2>/dev/null \
  | grep -Ev ':[0-9]+:[[:space:]]*//' || true)
check_hits "$hits"

# 4. run_session_polling (function deleted by T11; comments are archived refs — OK)
hits=$(grep -rn --include="*.rs" --exclude-dir=target --exclude-dir=.bak \
  -E 'run_session_polling' "$RUST_SRC" 2>/dev/null \
  | grep -Ev ':[0-9]+:[[:space:]]*//' || true)
check_hits "$hits"

# --- Frontend patterns ---
# JSX comment lines have content starting with optional spaces then "{/*".

# 5. PollingFooter component (removed by T11)
hits=$(grep -rn --include="*.tsx" --include="*.ts" --exclude-dir=node_modules \
  -E 'PollingFooter' "$FE_SRC" 2>/dev/null \
  | grep -Ev ':[0-9]+:[[:space:]]*\{/\*' || true)
check_hits "$hits"

# 6. StageChecklist component (removed by T11)
hits=$(grep -rn --include="*.tsx" --include="*.ts" --exclude-dir=node_modules \
  -E 'StageChecklist' "$FE_SRC" 2>/dev/null \
  | grep -Ev ':[0-9]+:[[:space:]]*\{/\*' || true)
check_hits "$hits"

if [ "$FOUND" -eq 0 ]; then
  printf 'PASS: no prohibited polling patterns found\n'
  exit 0
fi
exit 1
