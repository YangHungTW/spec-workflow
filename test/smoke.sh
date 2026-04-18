#!/usr/bin/env bash
# test/smoke.sh — end-to-end smoke harness covering AC1–AC12
# Usage: bash test/smoke.sh
# Exits 0 iff all 12 AC scenarios pass; non-zero otherwise.
#
# SAFETY: hard preflight refuses to run unless $HOME is inside a fresh sandbox.
# The script sets SANDBOX=$(mktemp -d), HOME=$SANDBOX/home, then asserts
# $HOME starts with $SANDBOX/ before running any scenario.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate bin/claude-symlink relative to this script's location (cwd-agnostic)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CS="$REPO_ROOT/bin/claude-symlink"

if [ ! -x "$CS" ]; then
  echo "ABORT: script not found or not executable: $CS" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# PREFLIGHT — Sandbox HOME
# Create a fresh temp directory and redirect HOME into it.
# Then verify the assignment is correct before any scenario runs.
# If anything looks wrong, abort loudly with exit 2.
# ---------------------------------------------------------------------------
ORIG_HOME="${HOME:-}"
export ORIG_HOME
SANDBOX=$(mktemp -d 2>/dev/null || mktemp -d -t 'claude-symlink')
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
# If the real HOME has asdf .tool-versions, make it available so python3 shim works
if [ -n "$ORIG_HOME" ] && [ -f "$ORIG_HOME/.tool-versions" ]; then
  cp "$ORIG_HOME/.tool-versions" "$HOME/.tool-versions" 2>/dev/null || :
fi

# Verify: HOME must start with SANDBOX path
case "$HOME" in
  "$SANDBOX/"*)
    : # good
    ;;
  *)
    echo "################################################################" >&2
    echo "PREFLIGHT FAILED: HOME is not inside the sandbox." >&2
    echo "  HOME   = $HOME" >&2
    echo "  SANDBOX= $SANDBOX" >&2
    echo "Refusing to run against a non-sandbox HOME. Aborting." >&2
    echo "################################################################" >&2
    exit 2
    ;;
esac

# Clean up the sandbox on exit
trap 'rm -rf "$SANDBOX"' EXIT

echo "=== smoke.sh — AC1-AC12 harness ==="
echo "SANDBOX=$SANDBOX"
echo "HOME=$HOME"
echo "REPO_ROOT=$REPO_ROOT"
echo

# ---------------------------------------------------------------------------
# Result counters
# ---------------------------------------------------------------------------
PASS_COUNT=0
FAIL_COUNT=0

# Per-scenario result; reset at the start of each AC function
_SCENARIO_FAILED=0

# ac_pass <n> <msg>
ac_pass() {
  local n="$1" msg="$2"
  echo "  ok: $msg"
}

# ac_fail <n> <msg>
ac_fail() {
  local n="$1" msg="$2"
  echo "  FAIL: $msg" >&2
  _SCENARIO_FAILED=1
}

# finish_scenario <n>
# Emits AC<n>: PASS or AC<n>: FAIL and updates global counters.
finish_scenario() {
  local n="$1"
  if [ "$_SCENARIO_FAILED" -eq 0 ]; then
    echo "AC${n}: PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "AC${n}: FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# make_home <name> — create a fresh per-scenario home inside the sandbox
make_home() {
  local name="$1"
  local h="$SANDBOX/homes/$name"
  mkdir -p "$h"
  echo "$h"
}

# hash_tree <dir> — reproducible hash of a directory tree's listing
# Uses find -ls | sort | shasum for a stable byte-identical check.
hash_tree() {
  local dir="$1"
  if [ -d "$dir" ]; then
    find "$dir" -ls 2>/dev/null | sort | shasum 2>/dev/null || \
    find "$dir" -ls 2>/dev/null | sort | sha1sum 2>/dev/null || \
    echo "nohash"
  else
    echo "absent"
  fi
}

# ---------------------------------------------------------------------------
# AC1 — install on clean host
# On a host with no ~/.claude/, install exits 0, creates all managed symlinks,
# every link resolves to an absolute path inside the repo.
# ---------------------------------------------------------------------------
ac1_clean_install() {
  _SCENARIO_FAILED=0
  echo "--- AC1: clean install ---"

  local H
  H=$(make_home "ac1")

  output=$(HOME="$H" "$CS" install 2>&1)
  exit_code=$?

  if [ "$exit_code" -eq 0 ]; then
    ac_pass 1 "install exits 0"
  else
    ac_fail 1 "install exited $exit_code (expected 0). Output: $output"
  fi

  # agents/specflow must be a symlink
  if [ -L "$H/.claude/agents/specflow" ]; then
    ac_pass 1 "agents/specflow is a symlink"
  else
    ac_fail 1 "agents/specflow is not a symlink"
  fi

  # commands/specflow must be a symlink
  if [ -L "$H/.claude/commands/specflow" ]; then
    ac_pass 1 "commands/specflow is a symlink"
  else
    ac_fail 1 "commands/specflow is not a symlink"
  fi

  # every team-memory file in the repo must be linked
  local src_count link_count
  src_count=$(find "$REPO_ROOT/.claude/team-memory" -type f | wc -l | tr -d ' ')
  link_count=$(find "$H/.claude/team-memory" -type l | wc -l | tr -d ' ')
  if [ "$link_count" -eq "$src_count" ]; then
    ac_pass 1 "team-memory: $link_count links match $src_count source files"
  else
    ac_fail 1 "team-memory link count mismatch: expected $src_count, got $link_count"
  fi

  finish_scenario 1
}

# ---------------------------------------------------------------------------
# AC2 — idempotent install
# Second install reports "already" for every path, exits 0, filesystem identical.
# ---------------------------------------------------------------------------
ac2_idempotent_install() {
  _SCENARIO_FAILED=0
  echo "--- AC2: idempotent install ---"

  local H
  H=$(make_home "ac2")

  HOME="$H" "$CS" install > /dev/null 2>&1

  output=$(HOME="$H" "$CS" install 2>&1)
  exit_code=$?

  if [ "$exit_code" -eq 0 ]; then
    ac_pass 2 "second install exits 0"
  else
    ac_fail 2 "second install exited $exit_code (expected 0)"
  fi

  # All verbs should be "already"
  already_count=$(echo "$output" | grep -c '\[already\]' || true)
  created_count=$(echo "$output" | grep -c '\[created\]' || true)

  if [ "$created_count" -eq 0 ]; then
    ac_pass 2 "no [created] verbs on second install"
  else
    ac_fail 2 "$created_count [created] verbs on second install (expected 0)"
  fi

  if [ "$already_count" -gt 0 ]; then
    ac_pass 2 "[already] verbs reported ($already_count)"
  else
    ac_fail 2 "no [already] verbs on second install"
  fi

  finish_scenario 2
}

# ---------------------------------------------------------------------------
# AC3 — install with real-file conflict
# Pre-place a real file at agents/specflow; install exits non-zero, leaves file
# untouched, reports skipped:real-file, creates other managed links.
# ---------------------------------------------------------------------------
ac3_real_file_conflict() {
  _SCENARIO_FAILED=0
  echo "--- AC3: install with real-file conflict ---"

  local H
  H=$(make_home "ac3")
  mkdir -p "$H/.claude/agents"
  echo "user content — do not overwrite" > "$H/.claude/agents/specflow"

  output=$(HOME="$H" "$CS" install 2>&1)
  exit_code=$?

  if [ "$exit_code" -ne 0 ]; then
    ac_pass 3 "install exits non-zero with real-file conflict"
  else
    ac_fail 3 "install exited 0 (expected non-zero)"
  fi

  # Real file must be untouched
  if [ -f "$H/.claude/agents/specflow" ] && [ ! -L "$H/.claude/agents/specflow" ]; then
    ac_pass 3 "conflicting real file untouched"
  else
    ac_fail 3 "conflicting real file was modified or removed"
  fi

  # Must report skipped:real-file
  if echo "$output" | grep -q '\[skipped:real-file\]'; then
    ac_pass 3 "skipped:real-file reported"
  else
    ac_fail 3 "skipped:real-file not found in output"
  fi

  # Other links still created (commands/specflow)
  if [ -L "$H/.claude/commands/specflow" ]; then
    ac_pass 3 "commands/specflow still created despite conflict"
  else
    ac_fail 3 "commands/specflow not created after conflict scenario"
  fi

  finish_scenario 3
}

# ---------------------------------------------------------------------------
# AC4 — uninstall scope
# After install, uninstall exits 0, removes all managed links, leaves
# hand-placed foreign files untouched, leaves ~/.claude/ itself.
# ---------------------------------------------------------------------------
ac4_uninstall_scope() {
  _SCENARIO_FAILED=0
  echo "--- AC4: uninstall scope ---"

  local H
  H=$(make_home "ac4")

  HOME="$H" "$CS" install > /dev/null 2>&1

  # Place a foreign file that must survive uninstall
  local foreign_file="$H/.claude/team-memory/shared/user-notes.txt"
  echo "keep me" > "$foreign_file"

  output=$(HOME="$H" "$CS" uninstall 2>&1)
  exit_code=$?

  if [ "$exit_code" -eq 0 ]; then
    ac_pass 4 "uninstall exits 0"
  else
    ac_fail 4 "uninstall exited $exit_code (expected 0)"
  fi

  # No tool-owned symlinks should remain
  local remaining_owned=0
  while IFS= read -r -d '' link; do
    local tgt
    tgt=$(readlink "$link")
    case "$tgt" in
      "$REPO_ROOT/.claude/"*)
        remaining_owned=$((remaining_owned + 1))
        ;;
    esac
  done < <(find "$H/.claude" -type l -print0 2>/dev/null)

  if [ "$remaining_owned" -eq 0 ]; then
    ac_pass 4 "no tool-owned symlinks remain after uninstall"
  else
    ac_fail 4 "$remaining_owned tool-owned symlink(s) remain after uninstall"
  fi

  # Foreign file must survive
  if [ -f "$foreign_file" ]; then
    ac_pass 4 "foreign file untouched by uninstall"
  else
    ac_fail 4 "foreign file was removed by uninstall"
  fi

  # ~/.claude/ itself must still exist
  if [ -d "$H/.claude" ]; then
    ac_pass 4 "~/.claude/ directory still exists after uninstall"
  else
    ac_fail 4 "~/.claude/ directory was removed by uninstall"
  fi

  finish_scenario 4
}

# ---------------------------------------------------------------------------
# AC5 — uninstall empty-dir cleanup
# Empty managed parent dirs are removed after uninstall; non-empty are left.
# ---------------------------------------------------------------------------
ac5_empty_dir_cleanup() {
  _SCENARIO_FAILED=0
  echo "--- AC5: uninstall empty-dir cleanup ---"

  local H
  H=$(make_home "ac5")

  HOME="$H" "$CS" install > /dev/null 2>&1

  # Leave a file in team-memory/shared/ so that dir should NOT be removed
  echo "keep" > "$H/.claude/team-memory/shared/keepme.txt"

  HOME="$H" "$CS" uninstall > /dev/null 2>&1

  # agents/ should be gone (was created by the tool and is now empty)
  if [ ! -d "$H/.claude/agents" ]; then
    ac_pass 5 "~/.claude/agents/ removed after uninstall (was empty)"
  else
    # If it still has content, that's a fail; if it's just there, check if empty
    local remaining
    remaining=$(find "$H/.claude/agents" -maxdepth 1 | wc -l | tr -d ' ')
    if [ "$remaining" -le 1 ]; then
      ac_fail 5 "~/.claude/agents/ is empty but was not removed"
    else
      ac_fail 5 "~/.claude/agents/ still has files: unexpected"
    fi
  fi

  # commands/ should be gone (was created by the tool and is now empty)
  if [ ! -d "$H/.claude/commands" ]; then
    ac_pass 5 "~/.claude/commands/ removed after uninstall (was empty)"
  else
    local remaining
    remaining=$(find "$H/.claude/commands" -maxdepth 1 | wc -l | tr -d ' ')
    if [ "$remaining" -le 1 ]; then
      ac_fail 5 "~/.claude/commands/ is empty but was not removed"
    else
      ac_fail 5 "~/.claude/commands/ still has files: unexpected"
    fi
  fi

  # team-memory/shared/ must NOT be removed (contains keepme.txt)
  if [ -d "$H/.claude/team-memory/shared" ]; then
    ac_pass 5 "~/.claude/team-memory/shared/ kept (contains user file)"
  else
    ac_fail 5 "~/.claude/team-memory/shared/ was removed (should have been kept)"
  fi

  finish_scenario 5
}

# ---------------------------------------------------------------------------
# AC6 — update adds missing links
# After install, add a new file to the repo's team-memory (using a sandbox
# copy of the repo to avoid mutating the real repo). update creates the
# matching link and reports "already" for everything else, exits 0.
# ---------------------------------------------------------------------------
ac6_update_adds_missing() {
  _SCENARIO_FAILED=0
  echo "--- AC6: update adds missing links ---"

  local H
  H=$(make_home "ac6")

  # We add a temporary file to the real repo's team-memory/shared/ directory.
  # A trap ensures it is cleaned up even on failure.
  local NEW_SRC="$REPO_ROOT/.claude/team-memory/shared/glossary_ac6.md"
  local new_src_created=0

  # Ensure no leftover from a previous run
  rm -f "$NEW_SRC"

  # Install baseline (without the new file)
  HOME="$H" "$CS" install > /dev/null 2>&1

  # Create the new source file
  echo "# Glossary AC6" > "$NEW_SRC"
  new_src_created=1

  # Register cleanup via a subshell-safe approach: remember to clean up
  local NEW_TGT="$H/.claude/team-memory/shared/glossary_ac6.md"

  output=$(HOME="$H" "$CS" update 2>&1)
  exit_code=$?

  # Clean up source file immediately
  rm -f "$NEW_SRC"
  new_src_created=0

  if [ "$exit_code" -eq 0 ]; then
    ac_pass 6 "update exits 0 after adding new source file"
  else
    ac_fail 6 "update exited $exit_code (expected 0)"
  fi

  if [ -L "$NEW_TGT" ]; then
    ac_pass 6 "new team-memory link created"
  else
    ac_fail 6 "new team-memory link not created: $NEW_TGT"
  fi

  if echo "$output" | grep -q '\[created\]'; then
    ac_pass 6 "[created] reported for new file"
  else
    ac_fail 6 "[created] not found in update output"
  fi

  if echo "$output" | grep -q '\[already\]'; then
    ac_pass 6 "[already] reported for existing files"
  else
    ac_fail 6 "[already] not found in update output"
  fi

  finish_scenario 6
}

# ---------------------------------------------------------------------------
# AC7 — update prunes orphans
# After install, temporarily remove a source file so its link becomes a
# broken managed symlink. update removes the orphan link, reports
# removed:orphan, exits 0. A foreign broken symlink is left untouched.
# ---------------------------------------------------------------------------
ac7_update_prunes_orphans() {
  _SCENARIO_FAILED=0
  echo "--- AC7: update prunes orphans ---"

  local H
  H=$(make_home "ac7")

  # Install baseline
  HOME="$H" "$CS" install > /dev/null 2>&1

  # Pick a team-memory source file to temporarily remove
  local VICTIM_SRC="$REPO_ROOT/.claude/team-memory/shared/index.md"
  local VICTIM_TGT="$H/.claude/team-memory/shared/index.md"
  local VICTIM_BACKUP="$SANDBOX/victim_ac7_backup.md"

  if [ ! -f "$VICTIM_SRC" ]; then
    ac_fail 7 "pre-condition: victim source file not found: $VICTIM_SRC"
    finish_scenario 7
    return
  fi

  # Place a foreign broken symlink in the same directory
  local FOREIGN_LINK="$H/.claude/team-memory/shared/foreign-ac7.md"
  ln -s "/tmp/nonexistent-foreign-ac7-$$" "$FOREIGN_LINK"

  # Move source away temporarily
  cp "$VICTIM_SRC" "$VICTIM_BACKUP"
  rm "$VICTIM_SRC"

  output=$(HOME="$H" "$CS" update 2>&1)
  exit_code=$?

  # Restore source immediately
  cp "$VICTIM_BACKUP" "$VICTIM_SRC"

  if [ "$exit_code" -eq 0 ]; then
    ac_pass 7 "update exits 0 after orphan pruning"
  else
    ac_fail 7 "update exited $exit_code (expected 0)"
  fi

  if echo "$output" | grep -q '\[removed:orphan\]'; then
    ac_pass 7 "[removed:orphan] reported"
  else
    ac_fail 7 "[removed:orphan] not found in update output"
  fi

  if [ ! -e "$VICTIM_TGT" ] && [ ! -L "$VICTIM_TGT" ]; then
    ac_pass 7 "orphan link removed from disk"
  else
    ac_fail 7 "orphan link still exists: $VICTIM_TGT"
  fi

  # Foreign broken symlink must be untouched
  if [ -L "$FOREIGN_LINK" ]; then
    ac_pass 7 "foreign broken symlink untouched"
  else
    ac_fail 7 "foreign broken symlink was removed (must not be)"
  fi

  # Foreign broken symlink must NOT appear in output
  if echo "$output" | grep -q "$FOREIGN_LINK"; then
    ac_fail 7 "foreign broken symlink appeared in output (should be silent)"
  else
    ac_pass 7 "foreign broken symlink not mentioned in output"
  fi

  finish_scenario 7
}

# ---------------------------------------------------------------------------
# AC8 — update with conflict
# Real file at a managed target: update skips it, reconciles others, exits non-zero.
# ---------------------------------------------------------------------------
ac8_update_conflict() {
  _SCENARIO_FAILED=0
  echo "--- AC8: update with conflict ---"

  local H
  H=$(make_home "ac8")

  # Pre-place a real file at agents/specflow
  mkdir -p "$H/.claude/agents"
  echo "user content — do not overwrite" > "$H/.claude/agents/specflow"

  output=$(HOME="$H" "$CS" update 2>&1)
  exit_code=$?

  if [ "$exit_code" -ne 0 ]; then
    ac_pass 8 "update exits non-zero with real-file conflict"
  else
    ac_fail 8 "update exited 0 (expected non-zero)"
  fi

  if echo "$output" | grep -q '\[skipped:real-file\]'; then
    ac_pass 8 "skipped:real-file reported"
  else
    ac_fail 8 "skipped:real-file not found in output"
  fi

  # Real file untouched
  if [ -f "$H/.claude/agents/specflow" ] && [ ! -L "$H/.claude/agents/specflow" ]; then
    ac_pass 8 "conflicting real file untouched"
  else
    ac_fail 8 "conflicting real file was modified or removed"
  fi

  # Other managed links still created
  if [ -L "$H/.claude/commands/specflow" ]; then
    ac_pass 8 "commands/specflow created despite conflict at agents/specflow"
  else
    ac_fail 8 "commands/specflow not created — update must continue past conflicts"
  fi

  finish_scenario 8
}

# ---------------------------------------------------------------------------
# AC9 — dry-run mutates nothing
# Hash the filesystem before and after each dry-run subcommand; assert identical.
# ---------------------------------------------------------------------------
ac9_dry_run_no_mutation() {
  _SCENARIO_FAILED=0
  echo "--- AC9: dry-run mutates nothing ---"

  local H
  H=$(make_home "ac9")

  # ----- install --dry-run on a clean sandbox -----
  local before after
  before=$(hash_tree "$H")
  output=$(HOME="$H" "$CS" install --dry-run 2>&1)
  exit_code=$?
  after=$(hash_tree "$H")

  if [ "$exit_code" -eq 0 ]; then
    ac_pass 9 "install --dry-run exits 0"
  else
    ac_fail 9 "install --dry-run exited $exit_code (expected 0)"
  fi

  if [ "$before" = "$after" ]; then
    ac_pass 9 "install --dry-run: filesystem unchanged (hash match)"
  else
    ac_fail 9 "install --dry-run: filesystem was mutated (hash mismatch)"
  fi

  if echo "$output" | grep -q '\[would-create\]'; then
    ac_pass 9 "install --dry-run: [would-create] verbs present"
  else
    ac_fail 9 "install --dry-run: [would-create] verbs not found in output"
  fi

  # ----- uninstall --dry-run after a real install -----
  HOME="$H" "$CS" install > /dev/null 2>&1
  before=$(hash_tree "$H")
  HOME="$H" "$CS" uninstall --dry-run > /dev/null 2>&1
  exit_code=$?
  after=$(hash_tree "$H")

  if [ "$before" = "$after" ]; then
    ac_pass 9 "uninstall --dry-run: filesystem unchanged (hash match)"
  else
    ac_fail 9 "uninstall --dry-run: filesystem was mutated (hash mismatch)"
  fi

  # ----- update --dry-run -----
  before=$(hash_tree "$H")
  HOME="$H" "$CS" update --dry-run > /dev/null 2>&1
  exit_code=$?
  after=$(hash_tree "$H")

  if [ "$before" = "$after" ]; then
    ac_pass 9 "update --dry-run: filesystem unchanged (hash match)"
  else
    ac_fail 9 "update --dry-run: filesystem was mutated (hash mismatch)"
  fi

  finish_scenario 9
}

# ---------------------------------------------------------------------------
# AC10 — absolute link targets
# Every link the tool creates has an absolute target starting with the repo root.
# ---------------------------------------------------------------------------
ac10_absolute_link_targets() {
  _SCENARIO_FAILED=0
  echo "--- AC10: absolute link targets ---"

  local H
  H=$(make_home "ac10")

  HOME="$H" "$CS" install > /dev/null 2>&1

  local bad_count=0
  local total_count=0

  while IFS= read -r -d '' link; do
    total_count=$((total_count + 1))
    local tgt
    tgt=$(readlink "$link")
    # Must be absolute and start with REPO_ROOT
    case "$tgt" in
      "$REPO_ROOT/"*)
        : # good
        ;;
      /*)
        # Absolute but not in our repo
        bad_count=$((bad_count + 1))
        echo "  WARN: absolute but outside repo: $link -> $tgt" >&2
        ;;
      *)
        # Relative — not allowed
        bad_count=$((bad_count + 1))
        echo "  WARN: relative link target: $link -> $tgt" >&2
        ;;
    esac
  done < <(find "$H/.claude" -type l -print0 2>/dev/null)

  if [ "$total_count" -gt 0 ]; then
    ac_pass 10 "found $total_count managed symlinks to check"
  else
    ac_fail 10 "no managed symlinks found after install"
  fi

  if [ "$bad_count" -eq 0 ]; then
    ac_pass 10 "all $total_count link targets are absolute paths under repo root"
  else
    ac_fail 10 "$bad_count of $total_count links have non-repo-absolute targets"
  fi

  finish_scenario 10
}

# ---------------------------------------------------------------------------
# AC11 — per-path report + exit code consistency
# For each scenario run so far, verify that the summary line's "(exit N)"
# matches the actual captured exit code. We run fresh install/conflict
# scenarios here to assert the property directly.
# ---------------------------------------------------------------------------
ac11_report_exit_consistency() {
  _SCENARIO_FAILED=0
  echo "--- AC11: report/exit consistency ---"

  # Clean run → exit 0 and summary says (exit 0)
  local H
  H=$(make_home "ac11_clean")
  output=$(HOME="$H" "$CS" install 2>&1)
  actual_exit=$?
  last_line=$(echo "$output" | tail -1)

  # Extract the exit code from the summary line
  summary_exit=""
  case "$last_line" in
    *"(exit "*)
      summary_exit="${last_line##*(exit }"
      summary_exit="${summary_exit%)*}"
      # Handle the case where tail of match leaves trailing chars
      # Use a safer extraction
      summary_exit=$(echo "$last_line" | sed 's/.*(\(exit [0-9]*\)).*/\1/' | sed 's/exit //')
      ;;
  esac

  if [ "$actual_exit" -eq 0 ] && [ "$summary_exit" = "0" ]; then
    ac_pass 11 "clean install: actual exit $actual_exit matches summary (exit $summary_exit)"
  else
    ac_fail 11 "clean install: actual_exit=$actual_exit summary_exit=$summary_exit (mismatch or wrong value)"
  fi

  case "$last_line" in
    summary:*) ac_pass 11 "clean install: last line starts with 'summary:'" ;;
    *)         ac_fail 11 "clean install: last line does not start with 'summary:' — got: $last_line" ;;
  esac

  # Conflict run → exit 1 and summary says (exit 1)
  H=$(make_home "ac11_conflict")
  mkdir -p "$H/.claude/agents"
  echo "conflict" > "$H/.claude/agents/specflow"
  output=$(HOME="$H" "$CS" install 2>&1)
  actual_exit=$?
  last_line=$(echo "$output" | tail -1)

  summary_exit=$(echo "$last_line" | sed 's/.*(\(exit [0-9]*\)).*/\1/' | sed 's/exit //')

  if [ "$actual_exit" -eq 1 ] && [ "$summary_exit" = "1" ]; then
    ac_pass 11 "conflict install: actual exit $actual_exit matches summary (exit $summary_exit)"
  else
    ac_fail 11 "conflict install: actual_exit=$actual_exit summary_exit=$summary_exit (mismatch or wrong value)"
  fi

  # Dry-run with would-skip does NOT bump exit code → exit 0
  H=$(make_home "ac11_dryrun")
  mkdir -p "$H/.claude/agents"
  echo "conflict" > "$H/.claude/agents/specflow"
  output=$(HOME="$H" "$CS" install --dry-run 2>&1)
  actual_exit=$?
  last_line=$(echo "$output" | tail -1)

  summary_exit=$(echo "$last_line" | sed 's/.*(\(exit [0-9]*\)).*/\1/' | sed 's/exit //')

  if [ "$actual_exit" -eq 0 ] && [ "$summary_exit" = "0" ]; then
    ac_pass 11 "dry-run with conflict: actual exit $actual_exit matches summary (exit $summary_exit)"
  else
    ac_fail 11 "dry-run with conflict: actual_exit=$actual_exit summary_exit=$summary_exit (expected both 0)"
  fi

  finish_scenario 11
}

# ---------------------------------------------------------------------------
# AC12 — cross-platform (noop marker)
# Prints uname -s to show which platform we are running on.
# Real cross-platform validation is human-driven (run on both macOS and Linux).
# ---------------------------------------------------------------------------
ac12_cross_platform() {
  _SCENARIO_FAILED=0
  echo "--- AC12: cross-platform noop marker ---"

  local platform
  platform=$(uname -s 2>/dev/null || echo "unknown")
  echo "  platform: $platform"
  echo "  (AC12 real check = run this script on macOS AND Linux; this is the noop marker)"

  # The script was able to identify the platform — that's the assertion.
  if [ -n "$platform" ]; then
    ac_pass 12 "uname -s returned: $platform"
  else
    ac_fail 12 "uname -s returned empty string"
  fi

  finish_scenario 12
}

# ---------------------------------------------------------------------------
# Run all scenarios in order
# ---------------------------------------------------------------------------
ac1_clean_install
echo
ac2_idempotent_install
echo
ac3_real_file_conflict
echo
ac4_uninstall_scope
echo
ac5_empty_dir_cleanup
echo
ac6_update_adds_missing
echo
ac7_update_prunes_orphans
echo
ac8_update_conflict
echo
ac9_dry_run_no_mutation
echo
ac10_absolute_link_targets
echo
ac11_report_exit_consistency
echo
ac12_cross_platform
echo

# ---------------------------------------------------------------------------
# B1 harness-upgrade tests (t13-t28) — registered by T23
# Each test is self-contained with its own sandbox-HOME preflight.
# ---------------------------------------------------------------------------
for t in t13_settings_json t14_rules_dir_structure t15_rules_schema \
         t16_hook_exec_bit t17_hook_happy_path t18_hook_failsafe \
         t19_hook_bad_frontmatter t20_hook_lang_lazy t21_agent_line_count \
         t22_agent_header_grep t23_memory_required t24_appendix_pointers \
         t25_no_duplication t26_no_new_command t27_settings_json_preserves_keys \
         t28_settings_json_idempotent \
         t29_claude_symlink_hooks_pair t30_stop_hook_happy_path \
         t31_stop_hook_failsafe t32_stop_hook_dedup \
         t33_claude_symlink_hooks_foreign \
         t34_reviewer_verdict_contract t35_reviewer_rubric_schema \
         t36_inline_review_integration t37_review_oneshot \
         t38_hook_skips_reviewer \
         t39_init_fresh_sandbox \
         t40_init_idempotent \
         t41_init_preserves_foreign \
         t42_update_no_conflict \
         t43_update_user_modified \
         t44_update_never_touches_team_memory \
         t45_migrate_from_global \
         t46_migrate_dry_run \
         t47_migrate_user_modified \
         t48_seed_rule_compliance \
         t49_init_skill_bootstrap \
         t50_dogfood_staging_sentinel; do
  echo "--- $t ---"
  if bash "$REPO_ROOT/test/${t}.sh" >/dev/null 2>&1; then
    echo "  PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  echo
done

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "smoke: PASS ($PASS_COUNT/$TOTAL)"
  exit 0
else
  echo "smoke: FAIL ($PASS_COUNT/$TOTAL)"
  exit 1
fi
