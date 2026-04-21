---
name: specflow-init
description: Seed a target repo with a per-project specflow install (init/update/migrate).
---

# /specflow-init

Locate the user's source-repo clone (env `SPECFLOW_SRC` or prompt),
invoke `<src>/bin/specflow-seed <subcmd>` with args inferred from the
user's task description. Subcommands: init / update / migrate.
