#!/usr/bin/env bash
# .claude/hooks/stop.sh
# Stop hook: detect active feature (branch-name match) → append note to STATUS.md
# Fail-safe: any error → WARN to stderr + exit 0. Never blocks session Stop.

set +e
trap 'exit 0' ERR INT TERM

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log_warn() { printf 'stop.sh: WARN: %s\n' "$1" >&2; }
log_info() { printf 'stop.sh: INFO: %s\n' "$1" >&2; }

# ---------------------------------------------------------------------------
# D2. Stdin sniff — minimal shape check, no jq, no python3
# ---------------------------------------------------------------------------

raw_payload=$(cat 2>/dev/null)

if [ "${HOOK_TEST:-0}" = "1" ]; then
  log_info "test-mode raw payload: $(printf '%s' "$raw_payload" | head -c 200)"
fi

# Minimal shape sniff: a JSON object starts with '{'. Anything else is no-payload.
case "$raw_payload" in
  '{'*) ;; # plausible JSON object; proceed
  *) log_info "stdin not a valid Stop payload"; exit 0 ;;
esac

# ---------------------------------------------------------------------------
# D3. classify_env — pure classifier, stdout only, no side effects
#
# Emits EXACTLY ONE of:
#   not-git | no-specflow | no-match | ambiguous:<list> | ok:<slug>
# ---------------------------------------------------------------------------

classify_env() {
  # Git-worktree check (portable — no readlink -f, no --is-inside-work-tree)
  if [ ! -r ".git/HEAD" ] && ! git rev-parse --git-dir >/dev/null 2>&1; then
    printf 'not-git'
    return
  fi

  # specflow features dir check
  if [ ! -d ".spec-workflow/features" ]; then
    printf 'no-specflow'
    return
  fi

  # Current branch — prefer git symbolic-ref (bash 3.2 safe, no --show-current floor)
  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null)
  if [ -z "$branch" ]; then
    # Detached HEAD or other edge case — treat as no-match
    printf 'no-match'
    return
  fi

  # Walk features/, collect slugs whose name is a substring of the branch.
  # Avoid [[ =~ ]] for portability; use case-glob.
  local matches=""
  local match_count=0
  local f
  for f in .spec-workflow/features/*/; do
    [ -d "$f" ] || continue
    local slug
    slug=$(basename "$f")
    case "$branch" in
      *"$slug"*)
        matches="$matches $slug"
        match_count=$((match_count + 1))
        ;;
    esac
  done

  if [ "$match_count" -eq 0 ]; then
    printf 'no-match'
  elif [ "$match_count" -eq 1 ]; then
    printf 'ok:%s' "${matches# }"
  else
    printf 'ambiguous:%s' "${matches# }"
  fi
}

# ---------------------------------------------------------------------------
# D3. Dispatch — single case table; mutation happens here only
# ---------------------------------------------------------------------------

state=$(classify_env)

case "$state" in
  not-git)      log_info "not a git worktree"; exit 0 ;;
  no-specflow)  log_info "no specflow features in cwd"; exit 0 ;;
  no-match)     log_info "branch does not match any feature"; exit 0 ;;
  ambiguous:*)  log_warn "ambiguous: ${state#ambiguous:}"; exit 0 ;;
  ok:*)         slug="${state#ok:}" ;;  # fall through to D4 dedup + D5 append
  *)            log_warn "unknown classify_env state: $state"; exit 0 ;;
esac

# ---------------------------------------------------------------------------
# D4. to_epoch — BSD/GNU date dispatch, cached by uname -s
# ---------------------------------------------------------------------------

# to_epoch "YYYY-MM-DD HH:MM:SS" → integer seconds on stdout
# Cross-platform: BSD date on macOS (-j -f), GNU date on Linux (-d).
to_epoch() {
  local ts="$1"
  local uname_s
  uname_s=$(uname -s 2>/dev/null)
  if [ "$uname_s" = "Darwin" ] || [ "$uname_s" = "FreeBSD" ] || [ "$uname_s" = "NetBSD" ] || [ "$uname_s" = "OpenBSD" ]; then
    date -j -f "%Y-%m-%d %H:%M:%S" "$ts" +%s 2>/dev/null
  else
    date -d "$ts" +%s 2>/dev/null
  fi
}

# ---------------------------------------------------------------------------
# D4. within_60s — sentinel-based dedup check
#
# Returns 0 (skip) if a stop-hook note was appended within the last 60 seconds.
# Returns 1 (proceed) otherwise.
# ---------------------------------------------------------------------------

within_60s() {
  local sentinel="$1"
  if [ ! -r "$sentinel" ]; then
    return 1
  fi
  local prior
  prior=$(cat "$sentinel" 2>/dev/null)
  if [ -z "$prior" ]; then
    return 1
  fi
  local now_epoch
  now_epoch=$(date +%s 2>/dev/null)
  if [ -z "$now_epoch" ]; then
    return 1
  fi
  local diff
  diff=$((now_epoch - prior))
  if [ "$diff" -lt 60 ]; then
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# D5. append_note — atomic STATUS.md append + sentinel write
# D6. HOOK_TEST=1 gate: print planned line, no mutation
# ---------------------------------------------------------------------------

# append_note "<status-path>" "<slug>"
append_note() {
  local status="$1"
  local slug="$2"

  # Verify STATUS.md exists and has ## Notes heading (R16 edge case)
  if [ ! -f "$status" ]; then
    log_warn "STATUS.md not present: $status"
    return
  fi

  if ! grep -q '^## Notes' "$status" 2>/dev/null; then
    log_warn "no ## Notes heading in $status"
    return
  fi

  local today
  today=$(date +%Y-%m-%d 2>/dev/null)
  if [ -z "$today" ]; then
    log_warn "could not determine current date"
    return
  fi

  # D6: HOOK_TEST=1 gate — log what would be appended, no mutation
  if [ "${HOOK_TEST:-0}" = "1" ]; then
    log_info "test-mode would append: - $today stop-hook — stop event observed to $status"
    return
  fi

  # Atomic append: write to .tmp, then mv — no partial-write window. Never >>
  local tmp="${status}.tmp"
  {
    cat "$status"
    printf -- '- %s stop-hook \xe2\x80\x94 stop event observed\n' "$today"
  } > "$tmp" 2>/dev/null || { log_warn "tmp write failed for $status"; rm -f "$tmp"; return; }

  mv "$tmp" "$status" 2>/dev/null || { log_warn "atomic swap failed for $status"; rm -f "$tmp"; return; }

  # Record sentinel for D4 dedup (atomic write)
  local sentinel_dir
  sentinel_dir=$(dirname "$status")
  local sentinel="${sentinel_dir}/.stop-hook-last-epoch"
  local sentinel_tmp="${sentinel}.tmp"
  date +%s > "$sentinel_tmp" 2>/dev/null && mv "$sentinel_tmp" "$sentinel" 2>/dev/null
}

# ---------------------------------------------------------------------------
# D4 dedup check before appending
# ---------------------------------------------------------------------------

feature_dir=".spec-workflow/features/$slug"
status_file="$feature_dir/STATUS.md"
sentinel_file="$feature_dir/.stop-hook-last-epoch"

if within_60s "$sentinel_file"; then
  log_info "dedup: stop event within 60s window, skipping append"
  exit 0
fi

# ---------------------------------------------------------------------------
# D5. Append the note
# ---------------------------------------------------------------------------

append_note "$status_file" "$slug"

exit 0
