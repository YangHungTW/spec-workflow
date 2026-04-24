#!/usr/bin/env bash
set -u -o pipefail

# Resolve source repo, in order:
#   1. $SCAFF_SRC env var (explicit override)
#   2. readlink ~/.claude/agents/scaff → strip /.claude/agents/scaff suffix
#      (auto-discovery from the symlink created by bin/claude-symlink install)
SRC="${SCAFF_SRC:-}"

if [ -z "$SRC" ]; then
  agent_link="$HOME/.claude/agents/scaff"
  if [ -L "$agent_link" ]; then
    t="$(readlink "$agent_link")"
    case "$t" in
      /*) ;;
      *)  t="$(dirname "$agent_link")/$t" ;;
    esac
    candidate="${t%/.claude/agents/scaff}"
    if [ "$candidate" != "$t" ] && [ -x "$candidate/bin/scaff-seed" ]; then
      SRC="$candidate"
    fi
  fi
fi

if [ -z "$SRC" ] || [ ! -x "$SRC/bin/scaff-seed" ]; then
  cat >&2 <<'EOF'
scaff-init: cannot locate the scaff source repo.
  tried:
    1. $SCAFF_SRC env var
    2. readlink ~/.claude/agents/scaff (set up by bin/claude-symlink install)
  fix: from your scaff clone, run `bin/claude-symlink install`
       — or export SCAFF_SRC=/absolute/path/to/specaffold before invoking.
EOF
  exit 2
fi

exec "$SRC/bin/scaff-seed" "$@"
