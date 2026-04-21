---
name: no-force-on-user-paths
scope: common
severity: must
created: 2026-04-16
updated: 2026-04-16
---

## Rule

Never use `--force` flags and never silently overwrite user-owned files
(config, dotfiles, state); always back up before mutating and classify
targets before touching them.

## Why

Silent clobbers destroy user work with no recovery path. A wrong auto-overwrite
costs more than one manual `rm`. The skip-and-report pattern surfaces
the conflict list so the user can act on it deliberately; `--force` hides
it behind a single flag that is easy to misuse at scale.

## How to apply

1. **No `--force` in v1.** Default behavior for any conflicting target is
   report-and-skip: emit `skipped:<reason>` per target, exit non-zero if any
   skip occurred.
2. **Classify before mutating.** Use the `classify-before-mutate` pattern
   (see `common/classify-before-mutate.md`) — enumerate every possible target
   state as a closed enum, then dispatch mutations through a table. Never
   branch on state inside the mutation path.
3. **Back up before overwriting.** When a mutation must replace an existing
   user-owned file, write the backup first (`cp file file.bak` or
   `cp settings.json settings.json.bak`) before any write. Use an atomic swap
   (`os.replace` / `mv`) so the live file is never partially written.
4. **No silent clobber.** If the backup step itself would overwrite a
   previous backup, either version the backup name or warn the user — never
   lose data silently.

## Example

The D12 `settings.json` read-merge-write discipline (implemented in
`bin/scaff-install-hook`):

```python
import json, os, shutil

settings_path = "settings.json"
backup_path   = "settings.json.bak"
tmp_path      = "settings.json.tmp"

# 1. Read (or start from empty object — never assume absent == writable)
try:
    with open(settings_path) as f:
        data = json.load(f)
except FileNotFoundError:
    data = {}

# 2. Back up existing file BEFORE mutation (no-force rule)
if os.path.exists(settings_path):
    shutil.copy2(settings_path, backup_path)

# 3. Merge idempotently — never clobber unrelated top-level keys
grp = {"hooks": [{"type": "command", "command": cmd}]}
hooks = data.setdefault("hooks", {}).setdefault(event, [])
if not any(h.get("command") == cmd for g in hooks for h in g.get("hooks", [])):
    hooks.append(grp)

# 4. Write to tmp, then atomic swap — no partial-write window
with open(tmp_path, "w") as f:
    json.dump(data, f, indent=2)
os.replace(tmp_path, settings_path)
```

Cross-references: `common/classify-before-mutate.md` (classify-before-mutate
pairing — build the full plan before executing any write).
