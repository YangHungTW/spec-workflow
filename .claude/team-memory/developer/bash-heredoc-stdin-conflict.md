---
name: Bash heredoc-python3 inside a function consumes caller's stdin
description: A bash function that runs `python3 - args <<'PYEOF'` cannot also receive piped stdin from its caller — the heredoc wins and the pipe payload is silently dropped.
type: feedback
created: 2026-04-18
updated: 2026-04-18
source: 20260418-per-project-install
---

## Rule

If a bash function invokes `python3 - args <<'PYEOF' … PYEOF` (or any
heredoc-backed interpreter), that heredoc binds the function's stdin.
Any caller that pipes data into the function via `producer | this_fn`
will lose the piped data — the heredoc is what `python3` reads, not
the pipe. Fix: inside the function, capture caller stdin to a
`mktemp` file first, then pass the temp path to `python3` as argv.

## Why

Bash attaches a single stdin channel per command. When a function
body contains `python3 - <<'PYEOF' … PYEOF`, bash wires the heredoc
to `python3`'s stdin. If the function was invoked through a pipe
(`cat src | this_fn`), the upstream pipe is still present on the
function's own stdin, but **the heredoc form overrides `python3`'s
stdin with the heredoc contents**. Result: the `python3` process
reads the heredoc (the script body) but never sees the upstream pipe
data. The bug is silent — `python3` runs, the heredoc script
executes — the pipe's payload simply never arrives.

## How to apply

For any helper function that uses `python3 - args <<'PYEOF'` and may
be invoked through a pipe, capture stdin at the function's entry:

```bash
manifest_write() {
  local out="$1"
  local tmp
  tmp=$(mktemp)
  cat > "$tmp"                  # drain caller's stdin to a real file
  python3 - "$out" "$tmp" <<'PYEOF'
import sys, json
out_path, in_path = sys.argv[1], sys.argv[2]
with open(in_path) as f:
    data = json.load(f)
# … write data to out_path atomically …
PYEOF
  rm -f "$tmp"
}
```

Callers can now pipe freely: `build_data | manifest_write out.json`.

## Example

`bin/scaff-seed` helpers `manifest_write` and `write_atomic` both
use this pattern. Initial versions used a direct heredoc inside the
function body and silently dropped piped input when callers did
`classify_plan | manifest_write …`. The tmp-file capture made the
pipe semantics honest and unblocked W1/W2 of the
`20260418-per-project-install` feature.
