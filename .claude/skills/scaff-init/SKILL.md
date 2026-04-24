---
name: scaff-init
description: Seed a target repo with a per-project scaff install (init/update/migrate).
---

# /scaff-init

Locate the scaff source repo and invoke `<src>/bin/scaff-seed <subcmd>` with
arguments inferred from the user's task description. Subcommands: `init` /
`update` / `migrate`.

## Source-repo resolution (in order)

1. `$SCAFF_SRC` env var (explicit override).
2. `readlink ~/.claude/agents/scaff` — auto-discovery from the symlink that
   `bin/claude-symlink install` creates.

Most users don't need to set `$SCAFF_SRC`: running `bin/claude-symlink install`
once from the source clone is enough to make `/scaff-init` work in every repo
on the machine.
