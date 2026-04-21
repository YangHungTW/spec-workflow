---
name: cd into $CONSUMER before invoking scaff-seed (init/update/migrate)
description: Any test or caller of `bin/scaff-seed init|update|migrate` must change working directory into the consumer tree first — otherwise `repo_root()` resolves via `git rev-parse --show-toplevel` from the caller's cwd and writes into the wrong repo.
type: feedback
created: 2026-04-18
updated: 2026-04-18
source: 20260418-per-project-install
---

## Rule

Every test script (and every manual invocation) that calls
`bin/scaff-seed init|update|migrate` must first `cd "$CONSUMER"`
(or wrap the call in `(cd "$CONSUMER" && "$SEED" <subcmd> …)`). If
the caller is already in the specaffold source tree (`$PWD` is
inside the repo that ships `scaff-seed`), the CLI will resolve
`repo_root()` to the source tree via `git rev-parse --show-toplevel`
and write the managed subtree + manifest there — silently corrupting
the source repo you're developing against.

## Why

`scaff-seed` derives the consumer root from `$PWD` by calling
`git rev-parse --show-toplevel`. There is no way for the CLI to
disambiguate between two adjacent git repos (source vs consumer)
when the caller's cwd happens to sit inside one of them. The test
harness in this feature uses `SANDBOX=$(mktemp -d); CONSUMER=$SANDBOX/consumer`,
but if a test forgets to enter `$CONSUMER` before invoking the CLI,
the call still "succeeds" — just against the wrong tree.

The failure mode is especially pernicious because:

- The CLI exits 0 — there is no error.
- The sandbox `$CONSUMER` looks untouched, so post-run assertions
  that check `$CONSUMER` find nothing out of place.
- The source repo gains a `.claude/` subtree and a
  `.claude/scaff.manifest` that the developer didn't author.
- Git status surfaces the mutation, but only if the developer
  happens to run `git status` before the next commit.

Root cause of the W2 "source-leak" false-alarm in this feature:
misdiagnosed as a `cmd_init` design bug and the developer's first
hotfix attempt redefined `--to <ref>` (update's target ref) as
`--to <path>` (init's consumer path). Caught by orchestrator review
before commit; reverted. The real fix (commit 11cc416) was the
one-line `cd $CONSUMER` addition to the missing test fixture.

## How to apply

For every new `t*_*.sh` that invokes `scaff-seed`:

```bash
# GOOD — subshell makes cwd change local to this invocation.
(cd "$CONSUMER" && "$SEED" init --from "$SRC" --ref "$REF")

# ALSO GOOD — explicit cd before the call, followed by cd back.
cd "$CONSUMER"
"$SEED" init --from "$SRC" --ref "$REF"
cd "$OLDPWD"

# BAD — invoking from test harness cwd.
"$SEED" init --from "$SRC" --ref "$REF"     # writes into source repo!
```

Preferred form is the subshell wrapper — it scopes the cwd change
to the one line that needs it and needs no cleanup.

## Example

Exemplar: `test/t40_init_idempotent.sh` in feature
`20260418-per-project-install`. Every invocation of `"$SEED"` is
wrapped in `(cd "$CONSUMER" && …)`. This is the pattern all new
scaff-seed tests should mirror.

Cross-ref: `developer/python-heredoc-exit-code-propagation.md` (the
other half of the W2 hotfix — explicit pipeline-exit checks — which
is what stopped the source-leak symptoms from being silent once they
did occur).
