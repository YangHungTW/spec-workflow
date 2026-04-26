# 04-tech — fix init missing preflight files

## 1. Context & Constraints

### Existing stack
- `bin/scaff-seed` — bash 3.2 / BSD-portable, classify-before-mutate discipline
  already established. `cmd_init`, `cmd_migrate`, and `cmd_update` share the
  `plan_copy` / `classify_copy_target` machinery; the pre-commit shim is the
  only existing example of a non-tree-copy, byte-identical-template emission
  from both `cmd_init` and `cmd_migrate` (lines 733 and 1314).
- `.specaffold/preflight.md` — present in source as of feature
  `20260426-scaff-init-preflight` archive (commit 11df1f8). Authoritative copy
  the consumer must receive verbatim.
- `.specaffold/config.yml` — present in source today (`lang.chat: zh-TW`); but
  NOT what the consumer should inherit. The consumer default is `lang.chat: en`
  per the language-preferences rule (`en` is the no-op default).
- `.claude/hooks/session-start.sh` reads exactly one key from
  `.specaffold/config.yml`: `lang.chat` (via `sniff_lang_chat` at line 197).
  No other key is consumed. Source confirmed line 199-207, 287-294.
- Test harness: `test/t108`–`t111` are sandboxed integration tests using
  `mktemp -d` + `make_consumer` git init helper. The next available counter
  is `t112`.

### Hard constraints
- Bash 3.2 / BSD portable (`.claude/rules/bash/bash-32-portability.md`).
- No-force-on-user-paths (`.claude/rules/common/no-force-on-user-paths.md`):
  any pre-existing `.specaffold/config.yml` or `.specaffold/preflight.md`
  MUST NOT be overwritten by init or migrate.
- Classify-before-mutate (`.claude/rules/common/classify-before-mutate.md`):
  state classification first, mutation second; both files run through the
  same dispatcher pattern as the rest of the manifest.
- Sandbox-HOME in tests (`.claude/rules/bash/sandbox-home-in-tests.md`):
  the new integration test must adopt the same preflight as `t108`–`t111`.

### Soft preferences
- Re-use existing `plan_copy` / `classify_copy_target` machinery rather than
  introducing a parallel codepath. Every emit-site mirror that drifts is a
  partial-wiring-trace risk (qa-analyst memory
  `partial-wiring-trace-every-entry-point`).
- Ship the smallest viable config.yml default. Every shipped key is a config
  decision the consumer inherits; future additions are easier than
  retractions.

### Forward constraints (from later backlogs)
- Future config keys (e.g. `lang.code`, `tier.default`) MUST land via additive
  YAML edits at a higher layer (config-schema feature, deferred). The default
  shipped today must not block that future schema.
- Future `.specaffold/<file>.md` template files (e.g. another shared body for
  another by-construction enforcement loop) should fit the same pattern
  established here without needing further code changes — this is the R3
  "discoverable & explicit" requirement.

## 2. System Architecture

### Components touched

```
bin/scaff-seed
├── plan_copy(src, mode)              # modified: add 2 entries to prefix list
├── cmd_init                          # unchanged structure; new entries flow through
├── cmd_migrate                       # unchanged structure; new entries flow through
└── cmd_update                        # unchanged (mode=update excludes new entries)

source layout (already present)
└── .specaffold/
    ├── preflight.md                  # used as-is (source of truth)
    └── config.yml.default            # NEW — shipped default content (see D1)
                                      # source repo's own config.yml stays
                                      # `lang.chat: zh-TW` (developer preference)

consumer layout (after fix)
└── .specaffold/
    ├── config.yml                    # created from .default if absent; never overwritten
    └── preflight.md                  # copied verbatim from source if absent
```

### Sequence — `bin/scaff-seed init` happy path

```
caller             scaff-seed             classify_copy_target          fs
  │                    │                          │                      │
  │ init --from <src>  │                          │                      │
  ├───────────────────>│                          │                      │
  │                    │ plan_copy(src, init)     │                      │
  │                    │   emits relpaths incl.   │                      │
  │                    │   .specaffold/config.yml │                      │
  │                    │   .specaffold/preflight.md                      │
  │                    │                          │                      │
  │                    │ for each relpath:        │                      │
  │                    │   sha256 source file ◄───┼── sha256_of(src/rel) │
  │                    │   classify dst ─────────►│                      │
  │                    │                          │ stat dst; cmp shas   │
  │                    │   state ◄────────────────┤                      │
  │                    │                          │                      │
  │                    │ dispatch by state:       │                      │
  │                    │   missing  → write_atomic ──────────────────────►
  │                    │   ok       → already                             │
  │                    │   user-modified → skip                           │
  │                    │   real-file-conflict → skip                     │
  │                    │                          │                      │
  │                    │ install pre-commit shim  │                      │
  │                    │ write manifest           │                      │
  │                    │ wire SessionStart/Stop   │                      │
  │  exit MAX_CODE     │                          │                      │
  │<───────────────────┤                          │                      │
```

The crucial property is that `.specaffold/config.yml` flows through the SAME
classifier-dispatcher pipeline as every other managed file. No new code path,
no special-casing — this is what makes the fix one-line-add-to-`plan_copy`
plus a default-content source file.

### Special case — source config.yml is not the consumer default

The source repo's own `.specaffold/config.yml` is `lang.chat: zh-TW` (the
developer's preference). The consumer's first-time default is `lang.chat: en`
(language-preferences rule no-op). We therefore CANNOT just copy
`.specaffold/config.yml` verbatim from the source. Two options:

- **Option A — ship a separate template file** (`config.yml.default`): plan_copy
  emits `.specaffold/config.yml.default` for sniff/sha but the dispatcher
  rewrites the destination relpath to `.specaffold/config.yml` (skip if
  exists; create otherwise). Cost: a new emit-rename codepath in the
  dispatcher — exactly the kind of "ad hoc edit to two functions" R3 forbids.
- **Option B — emit the default heredoc inline** (mirrors the pre-commit shim
  pattern): exactly the existing precedent at lines 733 / 1314. The default
  is two lines (`lang:\n  chat: en\n`), small enough to live as a
  byte-identical heredoc emitted from a helper function called from both
  cmd_init and cmd_migrate. Cost: one more place that must stay byte-identical
  across emit sites (same partial-wiring-trace risk as the pre-commit shim).

**Chosen: Option B** — see D1. The two-line heredoc is short enough that DRY
via a helper function is mechanical, and the existing pre-commit shim sets
the precedent for "byte-identical emit from cmd_init AND cmd_migrate".

For `preflight.md`, no rename is needed — the consumer's filename matches the
source's. Goes straight through `plan_copy` via the new `.specaffold/`
prefix entry.

## 3. Technology Decisions

## D1. Default `config.yml` content & emit mechanism

- **Options considered**:
  - A. Ship `.specaffold/config.yml.default` as a new file in source; dispatcher
     special-cases the rename.
  - B. Helper function `emit_default_config_yml()` emits a byte-identical
     2-line heredoc from cmd_init AND cmd_migrate (mirrors pre-commit shim
     pattern at lines 733 / 1314).
  - C. Add `lang.chat`, `lang.code`, `tier.default`, etc. — full default
     scaffold.
- **Chosen**: B, with content exactly:
  ```
  lang:
    chat: en
  ```
  (no other keys, terminating newline).
- **Why**: (i) `lang.chat` is the only key SessionStart hook reads today
  (line 199-207 of `.claude/hooks/session-start.sh`); shipping more keys
  forces consumer migrations later. (ii) Option B mirrors the established
  pre-commit shim emission pattern and avoids a new "rename on copy" code
  path that R3 explicitly cautions against. (iii) `en` is the language-
  preferences rule no-op default — the safest first-contact behaviour.
- **Tradeoffs accepted**: the helper function must stay byte-identical between
  cmd_init and cmd_migrate emit sites — same discipline as the pre-commit
  shim. We make the discipline mechanical by routing both call sites through
  one helper (see D2).
- **Reversibility**: high. Adding keys later is additive YAML; the consumer's
  config.yml is never overwritten, so post-default-change init/migrate is a
  no-op (state = `user-modified`, skipped).
- **Requirement link**: R1, R3.
- **Wiring task**: helper function `emit_default_config_yml()` lives once in
  `bin/scaff-seed`; both `cmd_init` and `cmd_migrate` call it from a new
  classifier→dispatch arm placed AFTER the main copy loop and BEFORE the
  pre-commit shim install (same shape as the existing shim block at line
  727-748 / 1308-1329). TPM must scope BOTH call-site edits in one task.
  (architect memory `setup-hook-wired-commitment-must-be-explicit-plan-task`.)

## D2. `preflight.md` distribution & integration with `plan_copy`

- **Options considered**:
  - A. Add `.specaffold/` to the `plan_copy` prefix list and let `find -type f`
     enumerate everything under it (would match `preflight.md` AND the
     source's own `config.yml` AND `features/_template/`).
  - B. Add a non-recursive enumeration: explicitly list
     `.specaffold/preflight.md` in `plan_copy` while leaving the existing
     `.specaffold/features/_template` recursive entry intact.
  - C. Helper function emits preflight.md inline from a heredoc, mirroring
     D1's config.yml approach.
- **Chosen**: B — explicit single-path entry for `.specaffold/preflight.md`
  in `plan_copy`'s prefix list (next to the existing
  `.specaffold/features/_template` entry).
- **Why**: (i) `preflight.md` is real source content (14 lines incl. fenced
  bash block) — too long to inline as a heredoc; the source-file-of-truth
  is `.specaffold/preflight.md` itself. (ii) Option A risks copying the
  source's developer-preference `config.yml` (`lang.chat: zh-TW`) verbatim
  into the consumer — wrong default. (iii) Option B keeps the file's path
  in source identical to its path in consumer; the existing
  classify-before-mutate pipeline handles all the no-force discipline for
  free.
- **Tradeoffs accepted**: `plan_copy` gains a new code shape — a single-file
  entry alongside the existing dir-recursion entries. Minor; the iteration
  body already filters via `find -type f` so a single regular file at the
  prefix path works without code changes (verified by reading the prefix
  loop at line 365-378: `find "${src_root}/${prefix}" -type f` matches
  whether prefix is a directory or a file).
- **Reversibility**: high. The list of prefixes is a literal in `plan_copy`;
  removing the entry reverts the change.
- **Requirement link**: R2, R3.

### Implementation note for plan_copy

The existing prefix loop:

```bash
for prefix in \
  ".claude/agents/scaff" \
  ".claude/commands/scaff" \
  ".claude/hooks" \
  ".claude/rules" \
  ".specaffold/features/_template"
do
  if [ -d "${src_root}/${prefix}" ]; then
    find "${src_root}/${prefix}" -type f | while ...
```

The `[ -d ]` test guards against single-file prefixes. To add `preflight.md`
without restructuring, either:

(a) add a sibling block after the loop:
```bash
if [ -f "${src_root}/.specaffold/preflight.md" ]; then
  printf '.specaffold/preflight.md\n'
fi
```

or (b) generalise the prefix loop to handle both dir and single-file
prefixes via a `[ -d ]` / `[ -f ]` cascade.

**Chosen approach: (a)** — explicit sibling block. Reasoning: (b) re-cuts the
prefix taxonomy (memory `architect/scope-extension-minimal-diff` —
"extend a closed enum by appending one value; never re-cut the taxonomy"),
while (a) is a minimal additive emit. The `if [ -f ]` guard preserves the
"skip skeleton paths where the source file genuinely does not exist"
property already coded at lines 578-580 / 1158-1160.

## D3. Idempotency states for the two new files

- **Options considered**:
  - A. Re-use existing classifier states (`missing`, `ok`, `drifted-ours`,
     `user-modified`, `real-file-conflict`) — both files inherit the
     existing pipeline.
  - B. New custom states for config.yml (e.g. `user-edited-config`) so the
     summary can distinguish "skipped because user-edited config.yml" from
     "skipped because user-edited rule file".
- **Chosen**: A. Re-use existing states. For the config.yml emit (heredoc-
  based), the classifier path is slightly different — see implementation
  note below.
- **Why**: R3 — "fits the same pattern, not require ad-hoc edits". Adding a
  new enum state would force every `case "$state" in` arm to grow, including
  the dry-run dispatcher and the dispatcher in `cmd_update`. Re-use keeps
  the change diff to two emit sites.
- **Tradeoffs accepted**: the per-relpath log line `skipped:user-modified:
  .specaffold/config.yml` is slightly less semantically precise than a
  bespoke `skipped:user-config-yml`. Acceptable: the log line still names
  the relpath, so the user can identify it.
- **Reversibility**: high.
- **Requirement link**: R3, AC4, AC5.

### Implementation note for the config.yml emit

`preflight.md` flows through the existing `plan_copy → classify_copy_target →
dispatcher` pipeline unchanged.

`config.yml` does NOT flow through `plan_copy` because the source's own
`config.yml` is `lang.chat: zh-TW` and we do NOT want to copy that. Instead,
the helper `emit_default_config_yml()` runs as a separate classify-and-
dispatch block (mirroring the pre-commit shim block at lines 727-748 /
1308-1329). The classifier:

```bash
# Pure classifier — emits one of: missing | ok | user-modified
classify_default_config_yml() {
  local consumer_root="$1"
  local cfg="${consumer_root}/.specaffold/config.yml"
  if [ ! -e "$cfg" ] && [ ! -L "$cfg" ]; then
    echo "missing"; return
  fi
  # If exists with byte-identical content to our default → ok; else user-modified.
  # Use the same heredoc bytes as the writer for the comparison.
  local expected actual
  expected="$(printf 'lang:\n  chat: en\n')"
  actual="$(cat "$cfg" 2>/dev/null || true)"
  if [ "$expected" = "$actual" ]; then
    echo "ok"; return
  fi
  echo "user-modified"
}
```

Dispatcher (called once from cmd_init and once from cmd_migrate):

```bash
emit_default_config_yml() {
  local consumer_root="$1"
  local state
  state=$(classify_default_config_yml "$consumer_root")
  local dst="${consumer_root}/.specaffold/config.yml"
  case "$state" in
    missing)
      printf 'lang:\n  chat: en\n' | write_atomic "$dst"
      echo "created: .specaffold/config.yml"
      _CNT_CREATED=$((_CNT_CREATED + 1)) ;;
    ok)
      echo "already: .specaffold/config.yml"
      _CNT_ALREADY=$((_CNT_ALREADY + 1)) ;;
    user-modified)
      echo "skipped:user-modified: .specaffold/config.yml"
      _CNT_SKIPPED=$((_CNT_SKIPPED + 1))
      if [ "$MAX_CODE" -lt 1 ]; then MAX_CODE=1; fi ;;
  esac
}
```

The states emitted at log line are byte-compatible with the existing
`already:` / `created:` / `skipped:user-modified:` log shape used by the
copy-loop dispatcher; no test assertion outside the new t112 needs to be
updated.

**Note on `skipped:user-modified` exit code**: a pre-existing
`config.yml` with custom content marks the run non-zero (MAX_CODE >= 1),
matching the existing copy-loop discipline for user-modified files. AC5
asserts content unchanged, NOT exit code 0. Idempotent re-run with the
default content present yields state=`ok` and exit 0 (AC4).

## D4. `cmd_migrate` parity with `cmd_init`

- **Options considered**:
  - A. Both `cmd_init` and `cmd_migrate` call `emit_default_config_yml()` from
     a new block placed right next to the existing pre-commit shim block.
  - B. Only `cmd_init` emits the default; `cmd_migrate` skips (existing
     consumers run init not migrate). Migrate-only consumers would miss
     the file.
- **Chosen**: A — both call sites emit. This is precisely what PRD D4 requires
  ("MUST backfill these files for repos that were init'd before this fix
  landed").
- **Why**: existing consumer repos init'd before this fix are broken; the only
  recovery path the user has is `bin/scaff-seed migrate`. Without the
  emitter in `cmd_migrate`, the recovery path is itself broken.
- **Tradeoffs accepted**: byte-identical emit-site discipline — see D5.
- **Reversibility**: high.
- **Requirement link**: R1, R2 (both subcommands), AC1, AC4 (idempotent on
  migrate-twice).

## D5. Byte-identical mirror enforcement (cmd_init / cmd_migrate)

- **Options considered**:
  - A. Inline the heredoc at both emit sites (same shape as pre-commit shim
     today at lines 733 and 1314).
  - B. Extract to a helper function `emit_default_config_yml()` called from
     both subcommands; helper is the single source of truth for the default
     content.
- **Chosen**: B. The default content lives in exactly one `printf` statement
  inside `emit_default_config_yml`; cmd_init and cmd_migrate both call the
  helper. Same for `classify_default_config_yml`.
- **Why**: the pre-commit shim mirror in W2 of `20260426-scaff-init-preflight`
  showed that two inlined heredocs WILL drift on the next refactor (the
  reviewer caught it; the analyst memorialised the gap). Extracting to a
  helper makes the byte-identity property structural rather than a code-
  review burden.
- **Tradeoffs accepted**: one more named function in the file. Minor.
- **Reversibility**: high.
- **Requirement link**: R3 (discoverable & explicit pattern).

This decision applies to `config.yml` only — `preflight.md` flows through
`plan_copy` and is byte-identical to the source by construction (same
sha256 expected/actual check as every other managed file).

## D6. Source enumeration of `.specaffold/preflight.md` in `plan_copy`

- **Options considered**:
  - A. Append the explicit relpath in a sibling block to the existing prefix
     loop.
  - B. Add `.specaffold/preflight.md` to the prefix list and rely on the
     existing `[ -d ]` guard to fall through (it would, because preflight.md
     is a regular file, not a directory — the existing guard skips it
     silently → BUG).
- **Chosen**: A. New explicit-emit block AFTER the prefix loop, BEFORE the
  team-memory case block:
  ```bash
  if [ -f "${src_root}/.specaffold/preflight.md" ]; then
    printf '.specaffold/preflight.md\n'
  fi
  ```
- **Why**: B is silently broken (the `[ -d ]` check excludes regular files).
  A keeps the prefix loop's invariant (every prefix is a directory) intact
  and adds the file emission as a separate, named block.
- **Tradeoffs accepted**: `plan_copy` grows by 3 lines.
- **Reversibility**: high.
- **Requirement link**: R2, R3.

## D7. Test shape & filename

- **Options considered**:
  - A. Extend `t108_precommit_preflight_wiring.sh` with new assertions.
  - B. New standalone test `t112_init_seeds_preflight_files.sh`.
- **Chosen**: B — new test `t112_init_seeds_preflight_files.sh`.
- **Why**: t108's scope is the pre-commit shim wiring (the four-layer
  enforcement loop's hook layer). Bolting AC1–AC7 of THIS feature onto t108
  conflates two concerns. Separate test file keeps the failure-mode signal
  clean: "t108 fails → shim regression"; "t112 fails → init-seed regression".
- **Tradeoffs accepted**: one more test file in the harness. The test runner
  is filename-glob-based (no central registry to update); a new tNNN file
  is automatically picked up.
- **Reversibility**: high.
- **Requirement link**: R5, AC7.

### Test specification — `test/t112_init_seeds_preflight_files.sh`

Following t108's structure (sandbox HOME, mktemp, `make_consumer` helper,
sequential A1…An assertions, exit on first failure):

| ID | AC | Assertion |
|----|----|-----------|
| A1 | AC1 | After `scaff-seed init` in fresh consumer: both `.specaffold/config.yml` AND `.specaffold/preflight.md` exist as regular files. |
| A2 | AC2 | `cmp $SRC/.specaffold/preflight.md $CONSUMER/.specaffold/preflight.md` exits 0 (byte-identical). |
| A3 | AC3 | `grep -E '^lang:' $CONSUMER/.specaffold/config.yml` AND `grep -E '^[[:space:]]+chat:' $CONSUMER/.specaffold/config.yml` both succeed. Plus `grep -F 'chat: en'` confirms the default value. |
| A4 | AC4 | Second `scaff-seed init`: output contains `already: .specaffold/config.yml` AND `already: .specaffold/preflight.md`; shasum-before == shasum-after for both files. |
| A5 | AC5 | Pre-existing user-edited `.specaffold/config.yml` (with content `lang:\n  chat: zh-TW\nuser_added: true\n`) is unchanged after init runs; output contains `skipped:user-modified: .specaffold/config.yml`. |
| A6 | AC6 | Extract the SCAFF PREFLIGHT block from `$CONSUMER/.specaffold/preflight.md` (same awk pattern as t110), run from `$CONSUMER` CWD, assert exit 0 and empty stdout. |
| A7 | AC7 / R3 | Migrate path parity: `scaff-seed migrate` on a fresh consumer also produces both files (and same shasum as init would). |

The migrate parity assertion (A7) is the partial-wiring-trace discipline
applied: every emit site (cmd_init AND cmd_migrate) gets a test path. This
prevents the regression class captured in qa-analyst memory
`partial-wiring-trace-every-entry-point` (the original W2 fixup of the
sibling feature lacked exactly this kind of mirror-test coverage).

## 4. Cross-cutting Concerns

### Error handling
- All file existence / classifier failures route through the existing
  `MAX_CODE >= 1` discipline — no new exit code semantics.
- Classifier `classify_default_config_yml` returns one of three states; the
  dispatcher has one arm per state (closed enum, no fall-through —
  `classify-before-mutate` rule).

### Logging
- Per-file log lines reuse the existing `created: <path>` / `already: <path>`
  / `skipped:user-modified: <path>` shape. The `emit_summary` counter
  outputs are unchanged.

### Security posture
- No new external inputs. config.yml content is a literal in the script
  (no string concatenation with untrusted data). preflight.md path is
  resolved relative to `$src_root` which is already validated by the
  existing `cd … && pwd -P` resolution.
- No-force-on-user-paths is satisfied: every state with a pre-existing
  non-matching file routes to `skipped:user-modified` with no write.

### Testing strategy
- Structural test t112 (sandboxed end-to-end): covers AC1–AC7 (see D7).
- No unit-level test added (the helpers are 5–10 lines each; the integration
  test catches every failure mode).
- The existing `__probe` subcommand could expose `classify_default_config_yml`
  if needed, but t112's dispatcher-level coverage is sufficient at v1; defer
  probe-level exposure unless a future regression motivates it.

### Performance
- New `plan_copy` block adds one `[ -f ]` test on the source. O(1).
- New emitter dispatch in cmd_init and cmd_migrate runs once per invocation.
  No loop, no shell-out per iteration. Performance reviewer-axis clean.

## 5. Open Questions

None — D1–D7 fully resolve PRD D1–D4 plus the additional decisions PM
deferred to architect (D5 mirror enforcement, D6 plan_copy entry shape, D7
test shape).

## 6. Non-decisions (deferred)

- **config.yml schema validation** (PRD out-of-scope §4). Trigger: a future
  feature adds keys with non-trivial value semantics (e.g. enum constraints,
  cross-key invariants). At that point, a `bin/scaff-lint config-yml` or
  similar will be needed.
- **Auto-update of consumer config.yml when source default changes**. Today
  the default is `lang.chat: en`; if it ever changes, existing consumers
  will keep their old content (state = `user-modified` → skipped). Trigger:
  a default change that is not backward-compatible. Mitigation: the default
  is intentionally minimal so backward-incompatible changes are unlikely.
- **`bin/scaff-seed update`'s relation to these files**. `cmd_update` does
  NOT emit config.yml or preflight.md (mode-gated by `plan_copy`'s `init|migrate`
  case). Trigger: if a future feature wants update to refresh preflight.md
  on source-changed-the-gate-body, that feature will need to extend
  `plan_copy`'s update mode to include `.specaffold/preflight.md`. Out of
  scope here.

## Team memory

Applied entries (relevance to this tech doc):

- `architect/setup-hook-wired-commitment-must-be-explicit-plan-task` — D1
  carries an explicit `Wiring task` line so the TPM scopes the cmd_init AND
  cmd_migrate call-site edits in one task.
- `architect/by-construction-coverage-via-lint-anchor` (lesson 4 — mirror
  emit sites must update together) — drove D5 (extract to helper rather than
  inline the heredoc twice) and D7 A7 (test the migrate path explicitly).
- `architect/scope-extension-minimal-diff` — drove D6 (additive sibling block
  in `plan_copy` rather than re-cutting the prefix-list taxonomy to support
  single-file entries).
- `qa-analyst/partial-wiring-trace-every-entry-point` — drove D5 helper-
  extraction discipline AND D7 A7 (migrate-path test). Every emit site of
  the byte-identical default content gets a test.
- `shared/dogfood-paradox-third-occurrence` — informs why this bug exists at
  all: the parent feature could only be structurally verified during its
  own bootstrap; live integration with `bin/scaff-seed init` is the next-
  feature exercise (this bug). Re-confirmed for the second time today.

Proposed new memory (post-archive): none yet — D1's "default config helper
mirrors pre-commit shim emit pattern" is already covered by the existing
`partial-wiring-trace` and `by-construction-coverage` entries.
