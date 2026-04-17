---
name: Safe mutation of user-owned config files (settings.json etc.)
description: Any tool modifying user-owned config (settings.json, .gitconfig, package.json fragments, .tool-versions) must read-merge-write with atomic swap and backup. Never `cat >`, never heredoc-clobber.
type: pattern
created: 2026-04-17
updated: 2026-04-17
---

## Rule

Any tool that mutates a user-owned config file (settings.json,
.gitconfig fragments, package.json, .tool-versions, .npmrc, etc.)
MUST use read-merge-write with atomic swap and a single-slot backup.
Never `cat >`, never heredoc-clobber, never assume the file is
"ours".

## Why

User-owned config files may contain:

- Entries from other tools the user installed independently.
- User customizations not present in any tool's template.
- Hand-edited formatting the user expects to survive tool runs.

A wholesale overwrite destroys this content with no recovery path —
the user discovers it only when the other tool breaks, by which time
they've forgotten what they'd edited. The read-merge-write pattern
plus a `.bak` sidecar turns an irrecoverable clobber into a one-command
restore.

## How to apply

1. **Engine selection** — default to Python 3 one-liner
   (`python3 -c "import json, sys; ..."`). Python 3 is widely
   available (macOS / most Linux distros) and parses JSON correctly.
   Opt-in `jq` is fine if the caller explicitly requests it; node
   fallback is acceptable if Python is absent; pure-bash splice is
   last-resort and only for non-JSON config.
2. **Backup first** — copy the current file to `.bak` (single slot)
   before any write. If `.bak` already exists, overwrite it (single-
   slot convention; don't version unless the user asked for it).
3. **Read — Merge — Write-to-tmp — Atomic swap**:
   - Read existing file; if absent, start from empty object (do NOT
     assume absent means writable).
   - Merge your entry into the parsed structure; do not rebuild
     siblings from scratch.
   - Write to `<file>.tmp` then `os.replace(tmp, file)` so there
     is no partial-write window.
4. **Idempotent merge** — before appending an entry, check whether
   an equivalent entry already exists. `install` run twice must not
   produce duplicate entries.
5. **Shape as pure functions** — `add_hook(event, cmd)` /
   `remove_hook(event, cmd)` pair. Removal is the trivial inversion
   of installation; writing both together forces the shape to stay
   clean.
6. **Fail loud if engine missing** — if Python 3 is absent and no
   explicit fallback was configured, error out with a clear message.
   Never silently fall back to `cat >` or a heredoc clobber.

## Example

Feature `20260416-prompt-rules-surgery`, decision D12. The installer
`bin/specflow-install-hook` uses this exact shape:

```python
import json, os, shutil, sys

settings_path = sys.argv[1]
event, cmd    = sys.argv[2], sys.argv[3]

# 1. Read (or start empty)
try:
    with open(settings_path) as f:
        data = json.load(f)
except FileNotFoundError:
    data = {}

# 2. Back up BEFORE any write
if os.path.exists(settings_path):
    shutil.copy2(settings_path, settings_path + ".bak")

# 3. Idempotent merge
hooks = data.setdefault("hooks", {}).setdefault(event, [])
already = any(h.get("command") == cmd
              for g in hooks for h in g.get("hooks", []))
if not already:
    hooks.append({"hooks": [{"type": "command", "command": cmd}]})

# 4. Write-to-tmp + atomic swap
tmp = settings_path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, indent=2)
os.replace(tmp, settings_path)
```

Cross-reference: `.claude/rules/common/no-force-on-user-paths.md`
(the hard-rule form of this pattern, loaded at session start).
This memory is the architect-level design note; the rule enforces
the discipline session-wide.
