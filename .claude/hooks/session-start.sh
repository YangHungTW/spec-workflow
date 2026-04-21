#!/usr/bin/env bash
# .claude/hooks/session-start.sh
# SessionStart hook: walks .claude/rules/, builds a digest, emits JSON on stdout.
# Fail-safe: any error → WARN to stderr + exit 0. Never blocks session startup.

set +e
trap 'exit 0' ERR INT TERM

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log_warn() {
  printf 'session-start.sh: WARN: %s\n' "$1" >&2
}

log_info() {
  printf 'session-start.sh: INFO: %s\n' "$1" >&2
}

# classify_frontmatter <file>
# Pure classifier. Returns one of:
#   valid | no-frontmatter | missing-name | missing-scope | missing-severity |
#   missing-created | missing-updated | empty
classify_frontmatter() {
  local file="$1"

  # Must be a non-empty regular file
  if [ ! -s "$file" ]; then
    printf 'empty'
    return
  fi

  # Check for opening --- fence on line 1
  local first_line
  first_line=$(head -1 "$file" 2>/dev/null)
  if [ "$first_line" != "---" ]; then
    printf 'no-frontmatter'
    return
  fi

  # Extract frontmatter block (content between first and second ---)
  local fm
  fm=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$file" 2>/dev/null)

  if [ -z "$fm" ]; then
    printf 'no-frontmatter'
    return
  fi

  # Per-key sniffs — each key must be present as "key: <value>"
  local has_name has_scope has_severity has_created has_updated
  has_name=$(printf '%s\n' "$fm" | awk '/^name:[[:space:]]*.+/{print "yes"; exit}')
  has_scope=$(printf '%s\n' "$fm" | awk '/^scope:[[:space:]]*.+/{print "yes"; exit}')
  has_severity=$(printf '%s\n' "$fm" | awk '/^severity:[[:space:]]*.+/{print "yes"; exit}')
  has_created=$(printf '%s\n' "$fm" | awk '/^created:[[:space:]]*.+/{print "yes"; exit}')
  has_updated=$(printf '%s\n' "$fm" | awk '/^updated:[[:space:]]*.+/{print "yes"; exit}')

  if [ "$has_name" != "yes" ]; then
    printf 'missing-name'
    return
  fi
  if [ "$has_scope" != "yes" ]; then
    printf 'missing-scope'
    return
  fi
  if [ "$has_severity" != "yes" ]; then
    printf 'missing-severity'
    return
  fi
  if [ "$has_created" != "yes" ]; then
    printf 'missing-created'
    return
  fi
  if [ "$has_updated" != "yes" ]; then
    printf 'missing-updated'
    return
  fi

  printf 'valid'
}

# digest_rule <file>
# Extracts name, severity, and first non-empty line under ## Rule.
# Emits: • [<severity>] <name> — <rule-line>
digest_rule() {
  local file="$1"

  # Extract frontmatter block for name + severity
  local fm
  fm=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$file" 2>/dev/null)

  local name severity rule_line

  name=$(printf '%s\n' "$fm" | awk '/^name:[[:space:]]/{
    sub(/^name:[[:space:]]*/, ""); print; exit
  }')

  severity=$(printf '%s\n' "$fm" | awk '/^severity:[[:space:]]/{
    sub(/^severity:[[:space:]]*/, ""); print; exit
  }')

  # First non-empty line under ## Rule section
  rule_line=$(awk '
    /^## Rule/{in_rule=1; next}
    in_rule && /^##/{exit}
    in_rule && /[^[:space:]]/{print; exit}
  ' "$file" 2>/dev/null)

  printf '• [%s] %s — %s\n' "$severity" "$name" "$rule_line"
}

# lang_heuristic
# Emits matched subdir names (bash, markdown, git) one per line, deduplicated.
lang_heuristic() {
  # Collect recent file paths from git diff + git status
  local file_list
  file_list=$(
    git diff --name-only HEAD~10..HEAD 2>/dev/null
    git status --short 2>/dev/null | awk '{print $NF}'
  )

  # Fallback to find if git signals empty
  if [ -z "$file_list" ]; then
    file_list=$(find . -type f -mtime -1 -maxdepth 3 2>/dev/null)
  fi

  if [ -z "$file_list" ]; then
    return
  fi

  # Map extensions / patterns to subdir names
  local bash_hit md_hit git_hit
  bash_hit=""
  md_hit=""
  git_hit=""

  while IFS= read -r fpath; do
    # Strip leading ./ if present
    fpath="${fpath#./}"
    local base ext
    base=$(basename "$fpath" 2>/dev/null)
    # Get extension — everything after last dot
    case "$base" in
      *.sh|*.bash)
        bash_hit="yes"
        ;;
      *.md)
        md_hit="yes"
        ;;
    esac
    # git-related: files under .git/ or .gitignore / .gitattributes
    case "$fpath" in
      .git/*|.gitignore|.gitattributes)
        git_hit="yes"
        ;;
    esac
    case "$base" in
      .gitignore|.gitattributes)
        git_hit="yes"
        ;;
    esac
  done <<EOF
$file_list
EOF

  if [ "$bash_hit" = "yes" ]; then
    printf 'bash\n'
  fi
  if [ "$md_hit" = "yes" ]; then
    printf 'markdown\n'
  fi
  if [ "$git_hit" = "yes" ]; then
    printf 'git\n'
  fi
}

# json_escape <string>
# Backslash-escapes " \ and newlines for JSON string embedding.
# Uses awk for newline handling (BSD sed doesn't support multi-line patterns).
json_escape() {
  local s="$1"
  # Use awk to escape backslashes, double-quotes, and newlines in one pass
  printf '%s' "$s" | awk '{
    gsub(/\\/, "\\\\")
    gsub(/"/, "\\\"")
    if (NR > 1) printf "\\n"
    printf "%s", $0
  }
  END { printf "" }'
}

# sniff_lang_chat <path>
# Sniffs the lang.chat value from a YAML config file.
# Echoes the token on stdout (empty string if key absent or file unreadable).
# Awk body is byte-identical to the parent D7 block.
sniff_lang_chat() {
  local cfg_file="$1"
  awk '/^lang:/        {in_lang=1; next}
    in_lang && /^  chat:/ {
      sub(/^  chat:[[:space:]]*/, "")
      gsub(/"/, ""); gsub(/#.*$/, "")
      gsub(/[[:space:]]+$/, "")
      print; exit
    }
    /^[^ ]/         {in_lang=0}
  ' "$cfg_file" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

RULES_DIR=".claude/rules"

# Fail-safe: missing rules dir → WARN + exit 0
if [ ! -d "$RULES_DIR" ]; then
  log_warn "rules directory not found: $RULES_DIR — no digest emitted"
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":""},"context":""}\n'
  exit 0
fi

# Collect subdirs to walk: always common + lang-heuristic matches
WALK_DIRS="common"
lang_dirs=$(lang_heuristic)

if [ -n "$lang_dirs" ]; then
  WALK_DIRS=$(printf '%s\n%s' "$WALK_DIRS" "$lang_dirs")
fi

# Subdirs that must never be session-loaded (space-separated list for easy extension)
SKIP_SUBDIRS="reviewer"

# Build digest
digest=""

while IFS= read -r subdir; do
  [ -z "$subdir" ] && continue
  # Skip any subdir in the SKIP_SUBDIRS list (whole-word match via space-padding)
  case " $SKIP_SUBDIRS " in
    *" $subdir "*) continue ;;
  esac
  dir_path="$RULES_DIR/$subdir"
  if [ ! -d "$dir_path" ]; then
    # Not every lang subdir may exist; silently skip
    continue
  fi

  # Walk *.md files in the subdir
  for rule_file in "$dir_path"/*.md; do
    # Skip if glob didn't match anything
    [ -f "$rule_file" ] || continue

    classification=$(classify_frontmatter "$rule_file")

    if [ "$classification" = "valid" ]; then
      line=$(digest_rule "$rule_file")
      if [ -n "$digest" ]; then
        digest=$(printf '%s\n%s' "$digest" "$line")
      else
        digest="$line"
      fi
    else
      log_warn "skipping $rule_file: $classification"
    fi
  done
done <<EOF
$WALK_DIRS
EOF

if [ -z "$digest" ]; then
  log_info "no valid rules found in $RULES_DIR"
fi

# Read lang.chat from an ordered candidate list; first file with the key wins.
# 1. .specaffold/config.yml  (project — wins when present)
# 2. $XDG_CONFIG_HOME/specaffold/config.yml  (only if env var set and non-empty)
# 3. $HOME/.config/specaffold/config.yml  (final tilde fallback)
CANDIDATES=".specaffold/config.yml"
if [ -n "${XDG_CONFIG_HOME:-}" ]; then
  CANDIDATES="$CANDIDATES $XDG_CONFIG_HOME/specaffold/config.yml"
fi
CANDIDATES="$CANDIDATES $HOME/.config/specaffold/config.yml"

cfg_chat=""
cfg_source=""
for cfg_file in $CANDIDATES; do
  [ -r "$cfg_file" ] || continue
  cfg_chat="$(sniff_lang_chat "$cfg_file")"
  if [ -n "$cfg_chat" ]; then
    cfg_source="$cfg_file"
    break
  fi
done

if [ -n "$cfg_chat" ]; then
  if [ "$cfg_chat" = "zh-TW" ] || [ "$cfg_chat" = "en" ]; then
    if [ -n "$digest" ]; then
      digest=$(printf '%s\nLANG_CHAT=%s' "$digest" "$cfg_chat")
    else
      digest="LANG_CHAT=$cfg_chat"
    fi
  else
    log_warn "$cfg_source: lang.chat has unknown value '$cfg_chat' — ignored"
  fi
fi

# JSON-escape the digest
escaped=$(json_escape "$digest")

# Emit JSON with both keys per D7 (fallback pattern)
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"},"context":"%s"}\n' \
  "$escaped" "$escaped"

exit 0
