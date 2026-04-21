# TPM Appendix — extended reference

## Task format and wave schedule rules

### Task format

Each task in `06-tasks.md` must follow this structure:

```
## T<n> — <verb-led title>
- **Milestone**: M<n>
- **Requirements**: R<n>[, R<m>]
- **Decisions**: D<n>[, D<m>]
- **Scope**: <what this task does, bullet or prose>
- **Deliverables**: <exact files created or modified>
- **Verify**: <runnable test command(s) — one per AC>
- **Depends on**: — (or T<n>, T<m>)
- **Parallel-safe-with**: (other tasks in same wave that won't collide)
- [ ]
```

Rules:
- `Files:` / `Deliverables:` must be precise — overlap between same-wave tasks is a planning bug.
- Every task maps to ≥1 PRD Requirement ID. No orphan tasks.
- Each task ≤ ~1 hour of focused Developer work.
- `Acceptance` / `Verify` MUST be runnable test commands. For genuinely non-testable tasks (config, docs), say so and justify.
- No vague "refactor" / "cleanup" tasks without a concrete trigger.
- Maximize wave width. If you can split a big task into 2–3 parallel-safe ones, do it.

### Wave schedule format

```
## Wave schedule

- **Wave 1**: T1                          (scaffold — blocks everything)
- **Wave 2**: T2, T3, T4                  (parallel — different files)
- **Wave 3**: T5                          (serial — touches shared config)
```

For each wave, include a **Parallel-safety analysis**:
- File overlap check: no two tasks in the same wave write to the same file.
- Test isolation: DB state, fixtures, ports, /tmp paths — can tests run concurrently?
- Shared infrastructure: migrations, schema changes, config files — must be serialized.
- If a wave has size 1, say why.

Key constraint (from `tpm/parallel-safe-requires-different-files.md`): tasks are parallel-safe only if they edit **different files**. Logical independence is necessary but not sufficient — git's textual merge can't reason about it. Dispatcher/registry edits (case arms, route tables, enum variants) collide textually even when logically disjoint.

### STATUS notes convention

Every task completion appends a line in `06-tasks.md` under `## STATUS Notes`:

```
- YYYY-MM-DD <Role> — T<n> done: <brief summary of what was committed>
```

Blocked tasks use:
```
- YYYY-MM-DD <Role> — T<n> blocked: <observed behavior or missing info>
```

The orchestrator checks off `[x]` in the task entry after each wave's commits are merged. TPM checks off tasks only in post-wave merge commits — never inside a Developer's per-task worktree commit (that would make `06-tasks.md` a shared-file hazard in parallel waves).

## Retrospective protocol

During `/scaff:archive`:

1. List all roles that appear in STATUS Notes.
2. For each role, read their recent STATUS entries and ask: "Any reusable lesson from this feature?"
3. Do not invent lessons. User approves each. Each entry gets: scope (local/global), type (feedback/pattern/decision/convention).
4. Write approved entries per `.claude/team-memory/README.md` protocol.
5. Common memory candidates to probe: architectural decisions validated in the wild, planning bugs found by gap-check, test patterns that caught regressions.
