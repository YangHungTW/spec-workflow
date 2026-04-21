---
name: scaff-init
description: Seed a target repo with a per-project scaff install (init/update/migrate).
---

# /scaff-init

Locate the user's source-repo clone (env `SCAFF_SRC` or prompt),
invoke `<src>/bin/scaff-seed <subcmd>` with args inferred from the
user's task description. Subcommands: init / update / migrate.
