#!/usr/bin/env bash
# test/t24_appendix_pointers.sh — T21: verify appendix pointer integrity
# For each agent core file, for each `consult <role>.appendix.md section "X"`
# reference, assert a matching `## X` or `### X` exists in the named appendix.
# Usage: bash test/t24_appendix_pointers.sh
# Exits 0 iff all checks pass.

set -u

# ---------------------------------------------------------------------------
# Locate repo root relative to this test file
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
AGENTS_DIR="$REPO_ROOT/.claude/agents/scaff"

# ---------------------------------------------------------------------------
# Sandbox / HOME isolation (sandbox-home-in-tests discipline)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t24-test)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Walk every *.md in the agents dir (non-appendix core files)
# For each `consult <appendix-file> section "X"` reference, verify the
# section exists in the named appendix file.
# ---------------------------------------------------------------------------
POINTER_FOUND=0

for core_file in "$AGENTS_DIR"/*.md; do
  # Skip appendix files themselves
  case "$core_file" in
    *.appendix.md) continue ;;
  esac

  # Read lines looking for: consult <something>.appendix.md section "X"
  while IFS= read -r line; do
    # Check if line contains a consult ... section "..." pattern
    case "$line" in
      *'consult '*.appendix.md*'section "'*'"'*)
        POINTER_FOUND=$((POINTER_FOUND + 1))

        # Extract appendix filename: word after "consult " up to space
        # e.g. "consult architect.appendix.md section "04-tech.md section outline""
        # Use awk to extract appendix filename
        appendix_name="$(printf '%s\n' "$line" | awk '{
          for(i=1;i<=NF;i++){
            if($i=="consult" && (i+1)<=NF){
              print $(i+1); exit
            }
          }
        }')"

        # Extract section name: text between section " and closing "
        # The pattern is: section "X"
        section_name="$(printf '%s\n' "$line" | sed 's/.*section "\([^"]*\)".*/\1/')"

        if [ -z "$appendix_name" ] || [ -z "$section_name" ]; then
          fail "Could not parse pointer in $(basename "$core_file"): $line"
          continue
        fi

        appendix_path="$AGENTS_DIR/$appendix_name"

        if [ ! -f "$appendix_path" ]; then
          fail "$(basename "$core_file") references $appendix_name but file does not exist"
          continue
        fi

        # Check for ## X or ### X in the appendix file
        if grep -qE "^#{2,3} ${section_name}$" "$appendix_path" 2>/dev/null; then
          pass "$(basename "$core_file") → $appendix_name section \"$section_name\" exists"
        else
          fail "$(basename "$core_file") → $appendix_name missing section \"$section_name\" (## or ###)"
        fi
        ;;
    esac
  done < "$core_file"
done

# If no pointers were found at all, that is a test design issue — warn but pass
if [ "$POINTER_FOUND" -eq 0 ]; then
  echo "NOTE: No appendix pointers found across agent core files — zero checks run."
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
