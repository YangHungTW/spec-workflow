## Rule

For rename / substring-migration features, budget explicit plan-gap checkpoints at every wave boundary; treat a zero-gap plan as suspicious, not reassuring.

## Why

The rename-to-specaffold feature (2026-04-21) needed two `/scaff:update-plan` cycles mid-implement:

1. T15 reviewer surfaced 88 missed `test/**/*.sh` files after W2 merge. Root cause: the plan enumerated file *classes* (`bin/`, `.claude/commands/`, etc.) but never inventoried `test/`.
2. A dry-run of `t_grep_allowlist.sh` after W3 merge surfaced 3604 more violations across 8 more files (`.gitignore`, `scripts/`, template) plus the entire `flow-monitor/` subtree (an independent co-located Tauri project).

Both gaps were invisible at initial plan time because the plan described file classes; neither ran a pre-emptive full-tree grep against the union of task scopes.

The follow-up rename-flow-monitor feature (2026-04-22) is a third datapoint: tech §6 declared "zero new allow-list entries required" (a net swap only), but T16's `bash test/t_grep_allowlist.sh` at wave-close surfaced 3 additional residual carve-outs needed: `flow-monitor/dist/**` (gitignored build artefacts on disk), `.specaffold/features/20260421-rename-flow-monitor/**` (the feature's own self-reference dir), and `.claude/team-memory/**` (historical memory directory). The architect had not dry-run the assertion against the actual disk tree at tech-authoring time — a model-inferred zero-delta prediction, not an evidence-backed one.

## How to apply

1. At plan time, run `grep -RIl "<old-name>" .` yourself and compare against the union of task `Scope:` globs; flag any residual as an early task.
2. Author the grep-allow-list assertion task early (not in the last wave) and dry-run it once per wave; the assertion should run green by the end of every wave it was authored against.
3. Include a standing "end-of-wave gap sweep" task in the wave schedule for rename features — explicit in §8, not implicit in the verify stage.
4. When a co-located independent sub-project (a sibling repo-like tree, e.g. `flow-monitor/`) exists, decide its rename policy at plan time; do not leave it as a discovery during the final assertion.
5. When a tech doc asserts "no new allow-list entries required" for a rename/substring-migration feature, the architect MUST dry-run the grep assertion against the actual working tree — including gitignored paths (`dist/`, build caches), the feature's own self-reference docs, and historical-memory directories — before committing the tech doc. A zero-delta prediction must be evidence-backed, not model-inferred.
