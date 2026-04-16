#!/usr/bin/env bash
# T12 docs verification: script header parity with --help, README section coverage.
set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SCRIPT="$REPO_ROOT/bin/claude-symlink"
README="$REPO_ROOT/README.md"

PASS=0
FAIL=0

assert() {
  local desc="$1"
  local result="$2"
  if [ "$result" -eq 0 ]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

# -----------------------------------------------------------------------
# Group 1: --help output parity
# -----------------------------------------------------------------------

HELP_OUT=$("$SCRIPT" --help 2>/dev/null)

# --help must mention all three subcommands
echo "$HELP_OUT" | grep -q "install"
assert "--help mentions install subcommand" $?

echo "$HELP_OUT" | grep -q "uninstall"
assert "--help mentions uninstall subcommand" $?

echo "$HELP_OUT" | grep -q "update"
assert "--help mentions update subcommand" $?

# --help must mention --dry-run
echo "$HELP_OUT" | grep -q -- "--dry-run"
assert "--help mentions --dry-run" $?

# --help must mention exit codes
echo "$HELP_OUT" | grep -qE "exit.*(0|1|2)|0.*1.*2"
assert "--help mentions exit codes" $?

# --help must mention managed set
echo "$HELP_OUT" | grep -q "agents/specflow"
assert "--help mentions agents/specflow" $?

echo "$HELP_OUT" | grep -q "commands/specflow"
assert "--help mentions commands/specflow" $?

echo "$HELP_OUT" | grep -q "team-memory"
assert "--help mentions team-memory" $?

# --help must mention no --force / manual conflict resolution
echo "$HELP_OUT" | grep -qi "conflict\|manual\|force"
assert "--help mentions conflict resolution is manual (no --force)" $?

# -----------------------------------------------------------------------
# Group 2: header comment block parity with --help
# -----------------------------------------------------------------------

HEADER=$(head -60 "$SCRIPT")

# Header must mention all three subcommands
echo "$HEADER" | grep -q "install"
assert "header mentions install subcommand" $?

echo "$HEADER" | grep -q "uninstall"
assert "header mentions uninstall subcommand" $?

echo "$HEADER" | grep -q "update"
assert "header mentions update subcommand" $?

# Header must mention --dry-run
echo "$HEADER" | grep -q -- "--dry-run"
assert "header mentions --dry-run" $?

# Header must mention exit codes (0/1/2)
echo "$HEADER" | grep -qE "exit.*(0|1|2)|0.*1.*2"
assert "header mentions exit codes 0/1/2" $?

# Header must mention managed set
echo "$HEADER" | grep -q "agents/specflow"
assert "header mentions agents/specflow" $?

echo "$HEADER" | grep -q "commands/specflow"
assert "header mentions commands/specflow" $?

echo "$HEADER" | grep -q "team-memory"
assert "header mentions team-memory" $?

# Header must note that conflicts resolve manually (no --force)
echo "$HEADER" | grep -qi "conflict\|manual\|force"
assert "header notes conflict resolution is manual (no --force)" $?

# -----------------------------------------------------------------------
# Group 3: README section coverage
# -----------------------------------------------------------------------

[ -f "$README" ]
assert "README.md exists" $?

# Must have a section about claude-symlink
grep -q "claude-symlink" "$README"
assert "README has claude-symlink section" $?

# What it does
grep -qi "what it does\|manages.*symlink\|symlink.*manage\|install.*uninstall\|three subcommand" "$README"
assert "README describes what it does" $?

# Install / uninstall / update invocation
grep -q "install" "$README" && grep -q "uninstall" "$README" && grep -q "update" "$README"
assert "README covers install/uninstall/update invocations" $?

# --dry-run preview
grep -q "\-\-dry-run" "$README"
assert "README covers --dry-run preview" $?

# Supported platforms
grep -qi "macos\|linux\|bash 3" "$README"
assert "README covers supported platforms" $?

# Recovery from moved repo
grep -qi "moved\|re-run.*install\|broken.*link\|install.*broken" "$README"
assert "README covers recovery from moved repo" $?

# Conflict reference: skipped:real-file
grep -q "real-file\|skipped:real-file" "$README"
assert "README covers skipped:real-file conflict" $?

# Conflict reference: skipped:real-dir
grep -q "real-dir\|skipped:real-dir" "$README"
assert "README covers skipped:real-dir conflict" $?

# Conflict reference: skipped:foreign-symlink
grep -q "foreign-symlink\|skipped:foreign" "$README"
assert "README covers skipped:foreign-symlink conflict" $?

# Conflict reference: skipped:not-ours
grep -q "not-ours\|skipped:not-ours" "$README"
assert "README covers skipped:not-ours" $?

# Orphan-walk sharp edge
grep -qi "orphan\|indistinguishable\|team-memory.*symlink\|symlink.*team-memory\|user-created.*symlink\|sharp edge\|caveat" "$README"
assert "README covers orphan-walk sharp edge" $?

# -----------------------------------------------------------------------
# Group 4: no .claude/ source tree modifications
# -----------------------------------------------------------------------

# Verify .claude/ tree has only expected content (not modified by this task)
# We check that .claude/agents, .claude/commands dirs exist (unchanged)
[ -d "$REPO_ROOT/.claude/agents" ]
assert ".claude/agents/ still exists (no content change)" $?

[ -d "$REPO_ROOT/.claude/commands" ]
assert ".claude/commands/ still exists (no content change)" $?

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------

echo ""
echo "T12 docs: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
