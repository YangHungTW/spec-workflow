# Specaffold Rename Migration Guide

This document covers the `spec-workflow` → `Specaffold` rename (R15 / AC12).
It is on the R6 allow-list and may refer to old names for migration clarity.

---

## (a) Old → New Name Mapping

| Old name | New name | Kind |
|---|---|---|
| `spec-workflow` (product) | `Specaffold` | Product name |
| `/specflow:request` | `/scaff:request` | Slash command |
| `/specflow:brainstorm` | `/scaff:brainstorm` | Slash command |
| `/specflow:prd` | `/scaff:prd` | Slash command |
| `/specflow:tech` | `/scaff:tech` | Slash command |
| `/specflow:plan` | `/scaff:plan` | Slash command |
| `/specflow:implement` | `/scaff:implement` | Slash command |
| `/specflow:review` | `/scaff:review` | Slash command |
| `/specflow:validate` | `/scaff:validate` | Slash command |
| `/specflow:archive` | `/scaff:archive` | Slash command |
| `/specflow:next` | `/scaff:next` | Slash command |
| `/specflow:update-*` | `/scaff:update-*` | Slash command family |
| `/specflow:remember` | `/scaff:remember` | Slash command |
| `/specflow:promote` | `/scaff:promote` | Slash command |
| `bin/specflow-seed` | `bin/scaff-seed` | Binary |
| `bin/specflow-lint` | `bin/scaff-lint` | Binary |
| `bin/specflow-aggregate-verdicts` | `bin/scaff-aggregate-verdicts` | Binary |
| `bin/specflow-install-hook` | `bin/scaff-install-hook` | Binary |
| `bin/specflow-tier` | `bin/scaff-tier` | Binary |
| `.spec-workflow/` | `.specaffold/` | Repo config dir |
| `.claude/specflow.manifest` | `.claude/scaff.manifest` | Manifest file |
| `specflow-pm` (and all agent prefixes) | `scaff-pm` | Agent name prefix |
| `specflow-init` | `scaff-init` | Skill name |

**RETIRED commands:** none retired in this wave; all commands above are renamed 1:1.

---

## (b) Hard-Cutover Rationale

There is no alias window. Maintaining `specflow-*` aliases alongside `scaff-*`
names would permanently double the maintenance surface: every new command,
binary, or config key would need two registrations, two tests, and two
documentation entries. The resulting ambiguity would also dilute the clarity
of the rename itself — users and tooling would have no single canonical name to
anchor on. The one-time disruption of a hard cutover is cheaper than sustaining
a dual-name surface indefinitely.

---

## (c) Recovery Step for Stale Global Installs

If your global `~/.claude/agents/` or `~/.claude/commands/` still reference the
old `specflow` agent names, re-run the symlink installer from your local clone:

```sh
bin/claude-symlink install
```

This refreshes the global `~/.claude/agents/specflow` → `scaff` symlink (and
equivalent command links) using the current repo as the source. The command is
idempotent and safe to re-run.

---

## (d) Orphan Cleanup

After re-installing, remove leftover old-name directories with:

```sh
rm -rf ~/.claude/agents/specflow ~/.claude/commands/specflow
```

**WARNING: This operation is IRREVERSIBLE.** If you have uncommitted work or
local customisations inside those directories, inspect them first:

```sh
ls -la ~/.claude/agents/specflow ~/.claude/commands/specflow
```

Only run the `rm -rf` once you have confirmed the directories contain no
unversioned work you wish to keep.

---

## (e) On-Disk Repo Directory

The rename of the on-disk checkout path (e.g., `~/Tools/spec-workflow`) is
**out of scope** for this rename. Users may rename their local clone at their
own pace. The `.spec-workflow` → `.specaffold` compatibility symlink inside the
repo handles all in-repo path references transparently; no immediate action on
the checkout directory is required.
