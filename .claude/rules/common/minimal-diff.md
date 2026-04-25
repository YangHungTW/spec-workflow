---
name: minimal-diff
scope: common
severity: should
created: 2026-04-26
updated: 2026-04-26
---

## Rule

Produce the smallest diff that satisfies the task; every line in the diff must
be justifiable as "this line exists because the task explicitly requires it"
or "this line exists because the rule set explicitly requires it" — anything
else is scope creep and must be deferred to a separate task.

## Why

Bug-fix PRs that grow into refactor avalanches are expensive to review, hard
to revert when the fix turns out wrong, and routinely cause regressions in
code that was never on the original ticket. The discipline of a minimum-viable
diff bounds blast radius, keeps `git blame` readable, and forces drive-by
"improvements" to surface as their own follow-up tasks where they get the
review attention they deserve. This rule extends the system-prompt guidance
("don't add features beyond what the task requires") into a checklist the
reviewer can apply line-by-line at wave-merge time.

## How to apply

1. **No drive-by refactors.** Do not edit a file the task did not name unless
   touching it is strictly required to make the task work. If a file looks
   bad but is not in scope, leave it; surface it as a follow-up task via
   `/scaff:update-task` or a STATUS Notes line, not a sneak edit.

2. **Three similar lines beats a premature abstraction.** Wait for the fourth
   occurrence before extracting a helper. Two near-duplicates are not yet a
   pattern; introducing an abstraction at that point usually predicts the
   wrong shape and locks the wrong API.

3. **No defensive code for impossible cases.** Trust internal invariants and
   framework guarantees. Validate only at system boundaries (CLI args, env
   vars, file contents from external sources, network responses) — see the
   security rule's check 3 (`reviewer/security.md`) for the boundary list.
   Adding null-checks, try/except, or fallback paths for branches the call
   tree cannot reach is a finding.

4. **No "improvements" disguised as fixes.** A bug-fix task contains only
   the bug fix. Renames, comment cleanups, type annotations, dead-code
   pruning, and lint fixes get their own task. The diff for `T7: fix the
   off-by-one in classify_target` should not also rename the function or
   add a docstring.

5. **No backwards-compatibility shims for code that has no callers.** If a
   symbol is genuinely unused, delete it cleanly. Do not leave `// removed`
   comments, `_oldName` aliases, or re-export shims; cross-references the
   developer-style entry on dead-code-orphan cleanup. Git history preserves
   the prior version.

6. **Ask before assuming the bigger interpretation.** When the task says
   "fix the login error," fix the login error — do not also redesign the
   auth flow. When the task is genuinely ambiguous, ask the user (or update
   the PRD via `/scaff:update-req`) rather than picking the larger
   interpretation unilaterally.

7. **Diff must justify itself line by line.** Before submitting, walk every
   changed line and ask: *does the task or a hard rule require this exact
   line?* If the answer is "no, but it would be nicer," delete it. If the
   line is needed for an edge case the task did not mention, the task spec
   is incomplete — surface that gap, do not paper over it with extra code.

8. **Comment discipline pairs with diff discipline.** No commented-out code
   (cross-references `reviewer/style.md` check 2). No `# TODO: maybe later`
   markers — file a follow-up task instead, where the work is tracked with
   an owner and an acceptance bar.

## Example

A task says: *T9: emit `LANG_CHAT=zh-TW` in the SessionStart additional-context
payload when `.specaffold/config.yml` sets `lang.chat: zh-TW`.*

Minimum-viable diff (illustrative — within scope):

```diff
+# Read lang.chat from config; emit marker when zh-TW
+lang_chat=$(awk '/^lang:/{f=1;next} f && /^[^ ]/{f=0} f && /chat:/{print $2; exit}' \
+              .specaffold/config.yml 2>/dev/null)
+if [ "$lang_chat" = "zh-TW" ]; then
+  printf 'LANG_CHAT=zh-TW\n'
+fi
```

Over-eager diff that violates this rule (do not submit):

```diff
+# Centralised config-reader helper for future expansion
+read_specaffold_config() {
+  # Generic key-path reader, supports nested keys and arrays
+  local key="$1" file=".specaffold/config.yml"
+  [ -f "$file" ] || return 1
+  python3 -c "import yaml,sys; ..."  # full YAML parser
+}
+
+# While here, also normalise the file's whitespace and add a header banner
+# (unrelated to T9 scope)
+...
+
+# Defensive: handle the case where awk doesn't exist (cannot happen on macOS/Linux)
+if ! command -v awk >/dev/null; then
+  echo "WARN: awk missing, skipping language detection" >&2
+  return 0
+fi
+
+lang_chat=$(read_specaffold_config "lang.chat")
+# Defensive: also accept "zh_TW", "zh-tw", "ZH-TW" (not in spec)
+case "$(printf '%s' "$lang_chat" | tr 'A-Z' 'a-z' | tr '_' '-')" in
+  zh-tw) printf 'LANG_CHAT=zh-TW\n' ;;
+esac
```

The second diff violates entries 1 (drive-by whitespace edit), 2 (premature
abstraction — `read_specaffold_config` has one caller and a hypothetical
"future expansion" justification), 3 (defensive `command -v awk` check for an
impossible case), and 6 (silently broadening the spec to accept three extra
casings the PRD did not list). Each addition is plausible in isolation; the
sum is a 30-line PR for a 4-line task, and every reviewer hour spent on the
extras is an hour not spent on the actual change.

Cross-references: `reviewer/style.md` (commented-out code, dead imports);
`reviewer/security.md` check 3 (boundary validation — the legitimate place
for input validation); system-prompt guidance ("don't add features beyond
what the task requires") which this rule operationalises for diff review.
