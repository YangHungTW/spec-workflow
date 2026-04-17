---
name: classify-before-mutate
scope: common
severity: must
created: 2026-04-16
updated: 2026-04-16
---

## Rule

Classify every target into a closed enum of named states before dispatching any
mutation; never mutate inside the classifier.

## Why

Mixed classification-and-mutation code is unreviable: you cannot tell at a
glance which states lead to which writes. Separating the two phases makes
dry-run trivial (early-return before the mutation loop), makes the classifier
fuzz-testable as a pure function, and confines every write to one dispatch arm
per state.

## How to apply

1. **Name every possible state as an explicit enum string.** For a filesystem
   tool: `missing`, `ok`, `wrong-link-ours`, `broken-ours`, `real-file`,
   `real-dir`, `foreign-link`, `broken-foreign`. Closed set — no "other".
2. **Write a pure classifier.** One function, one input, one output (state
   string on stdout or return value). No side effects — not even a conditional
   log line that fires on state.
3. **Dispatch via a table.** The caller reads the classifier's output and routes
   through a `case "$state" in …` (or equivalent map) that is the **only**
   place mutation happens. One arm per state. No fall-through.
4. **Separate ownership gate.** Whether a path is "ours" to touch is a distinct
   predicate (`owned_by_us`), not baked into the classifier. Classifier reports
   what the path **is**; ownership reports whether we **may** touch it.
5. **Reads first, writes second.** Do all classification calls up front (build a
   plan), then execute mutations. This lets `--dry-run` be a trivial early-return
   before the mutation loop.

## Example

```bash
# Pure classifier — stdout only, no side effects
classify_target() {
  local path="$1"
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    echo "missing"; return
  fi
  if [ -L "$path" ]; then
    local dest
    dest=$(readlink "$path")
    if [ ! -e "$path" ]; then
      echo "broken-foreign"; return   # ownership gate is separate
    fi
    echo "ok"; return
  fi
  [ -f "$path" ] && echo "real-file" && return
  [ -d "$path" ] && echo "real-dir"  && return
  echo "unknown"
}

# Dispatch — mutation lives here, not in the classifier
install_link() {
  local src="$1" tgt="$2"
  local state
  state=$(classify_target "$tgt")
  case "$state" in
    missing)      ln -s "$src" "$tgt" ;;
    ok)           : ;;   # already correct
    real-file)    echo "WARN: real file at $tgt — skipping" >&2 ;;
    broken-foreign) rm "$tgt" && ln -s "$src" "$tgt" ;;
    *)            echo "WARN: unhandled state $state for $tgt" >&2 ;;
  esac
}
```

Real-world instance: `classify_target` in `bin/claude-symlink` (feature
`symlink-operation`, T6). Eight-state enum, pure stdout emission, dispatched by
`cmd_install` / `cmd_uninstall` / `cmd_update` via their own `case` tables.
