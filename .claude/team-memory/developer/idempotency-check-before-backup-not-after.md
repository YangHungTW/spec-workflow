---
name: Idempotency check before backup, not after
description: When a write helper has both an idempotency check and a backup-before-mutate step, the idempotency check must run first; otherwise an idempotent no-op still produces a stray .bak and breaks the contract.
type: pattern
created: 2026-04-27
updated: 2026-04-27
---

## Context

Write helpers that take user-owned config files (settings.json, dotfiles, state) typically have two safety steps:

1. **Idempotency check** — "is the requested mutation already present? if so, exit cleanly".
2. **Backup-before-mutate** — "snapshot the current file to `<path>.bak` before any write".

The natural reading order is "back up first, then mutate" because the backup discipline (`common/no-force-on-user-paths.md`) appears louder in the rules. But ordering them as backup→idempotency-check is a footgun: every idempotent no-op call produces a `.bak` that has no corresponding mutation, which both lies to the user (a `.bak` implies "we just changed something") and clobbers an earlier `.bak` written by an upstream caller in the same pipeline.

Correct order: **idempotency check → backup → mutate → atomic swap**.

## Template

```python
def add_entry(p, event, cmd):
    # 1. Read current state
    try:
        with open(p) as f:
            data = json.load(f)
    except FileNotFoundError:
        data = {}

    # 2. Idempotency check — exit BEFORE any backup
    hooks = data.setdefault("hooks", {})
    arr = hooks.setdefault(event, [])
    if any(h.get("command") == cmd for grp in arr for h in grp.get("hooks", [])):
        sys.exit(0)  # already present; no .bak, no write

    # 3. Backup ONLY when mutation is confirmed necessary
    if os.path.exists(p):
        shutil.copyfile(p, p + ".bak")

    # 4. Mutate + atomic swap
    arr.append({"hooks": [{"type": "command", "command": cmd}]})
    tmp = p + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, p)
```

## When to use

Any helper that performs read-merge-write on a user-owned file AND offers an idempotent verb (e.g. `add`, `ensure`, `register`). Common in CLI wrappers around JSON/YAML config files.

## When NOT to use

If the helper has no idempotency contract (every call is expected to mutate), the order is moot — backup-then-write is correct. Same if the helper is purely transactional (`set` with overwrite semantics).

## Source

`bin/scaff-install-hook do_add` shipped with backup→check→write order until the bug fix in `20260426-fix-install-hook-wrong-path` T1. R4 ("idempotent: invoking add when an equivalent entry already exists MUST be a no-op — no `.bak` written") forced the reorder. AC3 (idempotent second `scaff-seed init` produces no new `.bak` at the consumer root) was the verifying behaviour.

The reorder also matters in pipelines: `scaff-seed init` Step 7 writes `.claude/settings.json.bak` once via its own Python merge; if Step 10's `scaff-install-hook add Stop` were to re-back-up unconditionally, it would overwrite Step 7's `.bak` with a less-informative snapshot. Idempotency-first preserves the most-informative `.bak`.
