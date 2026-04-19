# Tech — user-lang-config-fallback

_2026-04-19 · Architect_

## Team memory consulted

- `architect/hook-fail-safe-pattern.md` — **load-bearing** for every
  decision below. The new candidate-loop must inherit the parent's
  `set +e` + `trap 'exit 0' ERR INT TERM` frame, emit warnings to
  stderr only, and never block session start. A candidate being
  malformed or unreadable must degrade to default-off, not abort.
- `architect/shell-portability-readlink.md` — governs D2, D3, D5: no
  `readlink -f`, no `realpath`, no `[[ =~ ]]`, no `mapfile`. Use
  `[ -r … ]` for existence probes, `case` for token validation (but
  NOT inside a `$(...)` subshell — see rule
  `bash/bash-32-portability.md` §case-in-subshell).
- `architect/scope-extension-minimal-diff.md` — governs D1, D7: the
  candidate list extends the parent's single-path read into a walked
  list. Append paths to the ordered list; do not re-taxonomize the
  hook's structure. Parent's awk block stays byte-identical (R2
  AC2.b).
- `architect/classification-before-mutation.md` — the hook is pure
  classification (first candidate with a recognised value wins) +
  emission (marker line into digest); no mutation of user-owned
  files. Reads-first discipline is trivially satisfied: all
  classification happens before the single `digest=…` append.
- `shared/dogfood-paradox-third-occurrence.md` — **8th occurrence**
  (parent was 7th). All runtime-observable ACs (AC1.b, AC1.c, AC1.d,
  AC4.a) are structural-only during this feature's own verify;
  runtime PASS is the next-feature handoff. Design keeps the install
  surface to a single hook-block edit + one README paragraph to
  minimise what the post-archive smoke must cover manually.
- `architect/aggregator-as-classifier.md` — informs D6: when walking
  the candidate list, the loop is a *classifier* (which file wins),
  not a *reducer* (don't mix valid + invalid across files). Stop at
  the first file that held the key, even if invalid, because
  "project said `fr`" is a firm statement, not a pass-through.
  See D6 for the accepted tradeoff.

---

## 1. Summary

The SessionStart hook walks an ordered, ≤ 3-entry candidate list —
project `.spec-workflow/config.yml`, `$XDG_CONFIG_HOME/specflow/
config.yml` (only when the env var is set and non-empty), then
`~/.config/specflow/config.yml` — and invokes the parent's awk sniff
on the first readable file. First file whose `chat:` line is present
terminates the walk: valid token → emit `LANG_CHAT=<value>`; unknown
token → one stderr warning + default-off + stop (no marker). All
candidates absent → no marker, no warning (default-off baseline
preserved). Parent's awk block is wrapped in a `sniff_lang_chat`
helper and called inside the loop; the awk body itself is unchanged
from parent D7 (R2 AC2.b). Total diff to `.claude/hooks/session-
start.sh` is ≈ 25 lines, all inside the existing `set +e` +
`trap 'exit 0'` frame.

---

## 2. Architecture overview

```
  ┌────────────────────────────────────────────────────────────────┐
  │ Candidate sources (user- or repo-authored)                     │
  │   1. .spec-workflow/config.yml         (project, always first) │
  │   2. $XDG_CONFIG_HOME/specflow/config.yml  (only if env set)   │
  │   3. $HOME/.config/specflow/config.yml  (final tilde fallback) │
  └─────────────────────────┬──────────────────────────────────────┘
                            │  readonly, one-pass walk
                            v
  ┌────────────────────────────────────────────────────────────────┐
  │ .claude/hooks/session-start.sh  (edited block)                  │
  │                                                                 │
  │   # build ordered candidate list (space-separated string)       │
  │   CANDIDATES=".spec-workflow/config.yml"                        │
  │   if [ -n "${XDG_CONFIG_HOME:-}" ]; then                        │
  │     CANDIDATES="$CANDIDATES $XDG_CONFIG_HOME/specflow/cfg.yml"  │
  │   fi                                                            │
  │   CANDIDATES="$CANDIDATES $HOME/.config/specflow/config.yml"    │
  │                                                                 │
  │   # walk — stop at first file that held the key                 │
  │   for cfg_file in $CANDIDATES; do                               │
  │     [ -r "$cfg_file" ] || continue                              │
  │     cfg_chat="$(sniff_lang_chat "$cfg_file")"                   │
  │     # dispatch valid | unknown | empty-key via if/elif          │
  │     # first file that had the key (valid OR invalid) breaks     │
  │   done                                                          │
  │                                                                 │
  │   # if valid token captured → append "LANG_CHAT=<v>" to digest  │
  └─────────────────────────┬──────────────────────────────────────┘
                            │  JSON hookSpecificOutput.additionalContext
                            v
  ┌────────────────────────────────────────────────────────────────┐
  │ Claude Code session — rule body consults LANG_CHAT marker      │
  │ (parent `language-preferences.md` — UNCHANGED, R6 AC6.d)        │
  └────────────────────────────────────────────────────────────────┘
```

The rule file `.claude/rules/common/language-preferences.md` is
**untouched**. It speaks only about the `LANG_CHAT=zh-TW` marker and
its directive, not about where the hook found the value (R6 AC6.d).
The README's "Language preferences" section grows one paragraph (R6
AC6.a–c); no new sections, no new files shipped.

---

## 3. Technology Decisions

### D1. XDG-aware 3-path list (chosen over simple-tilde 2-path)

**Options considered**:

- A. **XDG-aware (3-path)** — project → `$XDG_CONFIG_HOME/specflow/
  config.yml` (when env var set and non-empty) → `$HOME/.config/
  specflow/config.yml`. PRD R1's candidate list as written.
- B. **Simple-tilde (2-path)** — project → `$HOME/.config/specflow/
  config.yml`. Drops AC1.d and AC6.b; shrinks R1 to two entries.

**Chosen**: **A — XDG-aware 3-path list**, matching PRD §6's PM
lean and brainstorm §6 recommendation B+D.

**Why**:

- **PRD R1 is written assuming the 3-path shape**. AC1.d and AC6.b
  are live acceptance criteria; picking B requires trimming the PRD
  text, not just the tech doc. The PRD's open decision exists to
  pick A or B *before* the ACs are final; the PRD author wrote A's
  ACs as the default and flagged them droppable. Picking A requires
  zero PRD edits.
- **Cost of XDG-awareness is one `[ -n "${XDG_CONFIG_HOME:-}" ]`
  shell test** — a string test, no subprocess, no fork. Well under
  the 200 ms hook budget (R5, cross-ref
  `.claude/rules/reviewer/performance.md` entry 7). Adding two
  `[ -r … ]` probes on absent files is nanoseconds (Scenario D in
  the PRD benchmarks as all-absent; we ship this trace below in
  §4.a).
- **Dotfile managers honour XDG** (`chezmoi`, `yadm`, `home-manager`
  on NixOS, most freedesktop-aligned Linux setups). Silently
  ignoring `$XDG_CONFIG_HOME` when it's set is a surprise: the user
  put their `specflow/config.yml` under the managed XDG root and
  the tool reads a different path. PRD Scenario C (Dave on Linux)
  describes exactly this case.
- **Forward-compat**. The candidate-list shape leaves room for
  future entries (e.g., a `SPECFLOW_CONFIG` env override at slot 0)
  without reshaping the control flow. One-line diff to extend, per
  `scope-extension-minimal-diff`.

**Tradeoffs accepted**:

- **One extra paragraph of README prose** for the XDG path (R6
  AC6.b). Acceptable: the precedence sentence already covers two
  paths, adding one more is not a doc-explosion.
- **3-path list expands the test matrix** from 4 cells to 4 +
  1-XDG cell. Addressed per PRD §7 brainstorm note ("a 5th cell
  (XDG-aware pathing) can be a targeted single-path assertion
  rather than a full matrix axis"): one smoke test asserts XDG
  wins over tilde when both present; four smoke tests cover the
  project × user-home matrix.
- **Users who DON'T set `$XDG_CONFIG_HOME` see no behaviour
  difference** vs option B. The cost is paid by users who DO set
  XDG and would otherwise be silently bypassed; they get the
  correct behaviour.

**Reversibility**: high — collapsing to 2-path later is removing
the middle candidate; no schema change, no user re-education
required (users on the XDG path would need to move their file to
`~/.config/specflow/`, but that's exactly the recovery path today's
users would follow on a repo with option B shipped).

**Requirement link**: PRD §6 open-decision (resolved); R1 AC1.a–d;
R6 AC6.a–c.

### D2. Path-existence probe — `[ -r "$path" ]` (consistent with parent)

**Options considered**:

- A. `[ -r "$path" ]` — readable by the hook's uid.
- B. `[ -f "$path" ]` — exists and is a regular file.
- C. `test -s "$path"` — exists, regular, non-empty.

**Chosen**: **A — `[ -r "$path" ]`**.

**Why**:

- **Parent's existing config-read block uses `[ -r "$cfg_file" ]`**
  at `.claude/hooks/session-start.sh` line 260. Consistency across
  the same hook is load-bearing for readability and grep
  inspection. Breaking symmetry without cause is a style finding
  under reviewer-style rule 7 ("match existing convention in the
  file").
- **`-r` is the right semantic**: the hook wants to *read* the
  file via `awk`. A readable but zero-byte file yields empty
  `cfg_chat` (no key matched), which is the same as a non-existent
  file — the loop silently continues. A readable file that's a
  dangling symlink fails `awk`'s open; the `2>/dev/null` on the
  `awk` invocation (inherited from parent D7) keeps this silent.
  No new failure modes vs parent.
- **`-f` would reject readable symlinks** that resolve to regular
  files, which is a legitimate way to share a user-home config
  across machines (`~/.config/specflow/config.yml -> ~/dotfiles/
  specflow/config.yml`). Rejecting would be surprising.
- **`-s` would silently skip empty files**, which is fine
  behaviourally but differs from parent. Not worth the
  inconsistency.

**Tradeoffs accepted**:

- **A non-regular file (directory, device) that happens to be
  readable would be passed to `awk`**, which would error. The
  `2>/dev/null` on the awk call plus the fail-safe trap absorbs
  this; `cfg_chat` ends up empty, the loop moves on. No AC
  requires hardening beyond this.

**Reversibility**: trivial — swap one char.

**Requirement link**: R5 AC5.a (no new fork, single `[ -r … ]`
per candidate); style rule 7 (match neighbour convention).

### D3. XDG env check — `[ -n "${XDG_CONFIG_HOME:-}" ]` with POSIX default expansion

**Options considered**:

- A. `[ -n "${XDG_CONFIG_HOME:-}" ]` — POSIX `:-` default
  expansion; works under `set -u` as well as `set +e`.
- B. `[ -n "$XDG_CONFIG_HOME" ]` — raw expansion; unbound under
  `set -u` would error, but the hook runs `set +e` not `-u`.
- C. `[[ -n "${XDG_CONFIG_HOME:-}" ]]` — bashism; rejected by
  `bash/bash-32-portability.md` (entry "No `[[ =~ ]]` for
  portability-critical logic" — the `-n` form of `[[ ]]` is
  adjacent and inconsistent to mix with the `[ ]` forms already
  in the file).

**Chosen**: **A — `[ -n "${XDG_CONFIG_HOME:-}" ]`**.

**Why**:

- **Belt-and-suspenders safety** against any future refactor that
  adds `set -u`. The `:-` expansion is the portable idiom; same
  cost as raw expansion, defensible in code review.
- **Form matches parent hook style**: the hook uses `[ … ]`
  (POSIX single-bracket) everywhere — `[ -d "$RULES_DIR" ]`,
  `[ -z "$digest" ]`, `[ -r "$cfg_file" ]`. The new line is
  byte-level consistent.
- **Treats "set to empty string" identically to "unset"**. PRD R1
  entry 2 says "evaluated only when `$XDG_CONFIG_HOME` is set
  **and non-empty**" — this form honours both clauses with a
  single test.

**Tradeoffs accepted**:

- **A user who sets `XDG_CONFIG_HOME=" "`** (a single space) would
  pass the `-n` test and the path construction would produce
  `/ /specflow/config.yml`, which is almost certainly unreadable
  and the loop moves on. This is a pathological case; no AC
  requires guarding against it and doing so would require string
  trimming (non-trivial in bash 3.2).

**Reversibility**: trivial.

**Requirement link**: R1 (candidate construction); R5 AC5.a (no
new fork); bash-32-portability rule.

### D4. awk sniff reuse shape — `sniff_lang_chat <path>` helper function

**Options considered**:

- A. **Extract to a function** `sniff_lang_chat <path>` that
  echoes the sniffed value; caller invokes per candidate inside
  the loop.
- B. **Inline the awk block** inside the loop body; each
  iteration carries a ~10-line awk invocation.

**Chosen**: **A — extract to `sniff_lang_chat <path>`**.

**Why**:

- **R2 AC2.a is a grep-verifiable uniqueness constraint**:
  `grep -c 'in_lang=1' .claude/hooks/session-start.sh` must
  return exactly `1`. Option B would make that count equal the
  number of candidates (1–3 depending on XDG) and invalidate the
  AC as written. A function body contains the awk block once;
  callers dispatch by argument. Grep returns 1.
- **R2 AC2.b requires the awk body to be byte-identical to
  parent D7**. Wrapping the existing awk block in a function (no
  edits to the awk body itself) preserves this. Commit-time
  structural diff shows added function wrapper + added loop,
  never a rewrite of the awk.
- **Testability**: the function is invokable directly from a
  plain shell with a test fixture path. Parent's inline block
  would require extracting the awk program by line-range, which
  is brittle.
- **Consistency with parent hook style**: the hook already
  defines helper functions for every distinct responsibility
  (`classify_frontmatter`, `digest_rule`, `lang_heuristic`,
  `json_escape`, `log_warn`, `log_info`). Adding `sniff_lang_chat`
  as a peer matches the file's own established pattern.
- **One extra function-call layer per iteration** is negligible
  — bounded at ≤ 3 iterations, and the caller path already runs
  awk (a subprocess) on present files. The function-call cost is
  lost in the noise.

**Tradeoffs accepted**:

- **One additional function definition** (~12 lines) added to the
  hook file. Offset by the fact that the existing inline block
  (~10 lines, lines 261–269) is removed and its body is now in
  the function. Net diff: +5 lines approx.
- **The helper's name pins a slightly narrower scope** than
  `read_config`; if a future key lands (`lang.default`), we'd
  either extend this function or add a sibling. Accepted per D9
  in the parent (forward-compat `lang.default` is a one-line
  awk-rule extension; function still carries the right name for
  `lang.*` keys).

**One-phrase summary**: **awk block becomes a `sniff_lang_chat
<path>` helper; awk body byte-identical to parent**.

**Reversibility**: trivial — inline the function if a reader
prefers.

**Requirement link**: R2 AC2.a (single `in_lang=1` occurrence),
R2 AC2.b (awk body byte-identical), reviewer-performance rule 6
(minimise fork/exec in hot paths — function call is in-process).

### D5. Precedence loop form — `for cfg_file in $CANDIDATES` (space-separated string)

**Options considered**:

- A. **Space-separated string + unquoted `for`**: build `$CANDIDATES`
  as a space-separated string, iterate via `for cfg_file in
  $CANDIDATES; do …`.
- B. **Bash array + `"${arr[@]}"` expansion**: `CANDIDATES=(…)` then
  `for cfg_file in "${CANDIDATES[@]}"; do …`.
- C. **Series of explicit `if/elif` blocks**, no loop, one block per
  candidate.

**Chosen**: **A — space-separated string + unquoted `for`**.

**Why**:

- **Parent hook precedent**: the existing hook builds
  `WALK_DIRS="common"` as a space-separated string and iterates
  via `while IFS= read -r subdir; do … done <<EOF\n$WALK_DIRS\nEOF`
  (lines 206–252). Not an array. Matching this pattern preserves
  file-level style consistency.
- **Bash 3.2 arrays ARE supported**, but the heredoc-fed `while
  read` pattern the parent uses was chosen specifically to avoid
  array syntax that varies across bash/zsh/POSIX shells. The
  candidate list is short (≤ 3) and contains absolute or well-
  formed relative paths; no path contains spaces in practice
  (project-relative path is `.spec-workflow/config.yml`; user-home
  paths come from `$HOME` and `$XDG_CONFIG_HOME`, which are under
  user control but almost never contain spaces on macOS/Linux).
- **`for` is cleaner than `while read` for this case**: we have
  three known values, no file or stdin to read. `while read` is
  for unknown-length streams; `for` is for known-small lists.
  Parent's `while read` shape exists because `lang_heuristic`
  returns a variable-length list; our candidate list is bounded
  and small.
- **Option C (explicit if/elif)** works but hard-codes the path
  count. PRD §6 defers env-var escape hatches to a future feature
  (non-goal #1); a future candidate-list growth would require
  re-shaping the control flow under option C but is a one-line
  append under option A.

**Tradeoffs accepted**:

- **Path containing a space would split the candidate**. Mitigation:
  the three paths are under our control — `.spec-workflow/
  config.yml` is literal; `$XDG_CONFIG_HOME/specflow/config.yml`
  uses a subdir we control; `$HOME/.config/specflow/config.yml` is
  under HOME. A user with a space in `$HOME` (e.g., `/Users/
  yang hung/...`) would see the candidate split into two "paths"
  neither of which is readable → loop passes through, default-off.
  Not catastrophic, just unhelpful for that user. Guarding against
  it requires array syntax (option B) and adds style inconsistency
  with parent. Accepted as a known edge; documented in §7
  (non-decisions).
- **No glob expansion** happens in `$CANDIDATES` because the
  strings don't contain `*`, `?`, `[`. If a user sets
  `$XDG_CONFIG_HOME=/some/path/*`, pathological. Accepted.

**Reversibility**: medium — swapping to an array is mechanical but
touches every use site.

**Requirement link**: R1 (ordered walk); bash-32-portability rule
(parent pattern consistency); style rule 7.

### D6. stderr warning per path — stop at first file that held the key (valid or invalid)

**Options considered**:

- A. **Stop at first file that held the key** — loop visits
  candidates in order; first file whose `chat:` line is present
  (regardless of whether the token is `zh-TW`/`en` or something
  else) terminates the walk. Valid → emit marker. Invalid → one
  stderr warning + default-off. Empty key (no `chat:` under
  `lang:`) → continue to next candidate.
- B. **Continue past invalid values** — a malformed early
  candidate falls through to the next, giving later candidates a
  chance to rescue. Each invalid value along the way emits its
  own stderr warning.

**Chosen**: **A — stop at first file that held the key**.

**Why**:

- **"Project said `fr`" is a firm statement, not a
  pass-through.** A project-level `.spec-workflow/config.yml`
  with `chat: fr` means the project author typed `fr` and
  committed it; reading through that to the user's personal
  tilde config would silently override a project-level
  declaration. The project declaration should dominate even
  when it's malformed — that's the precedence contract in R1.
  The user learns about the problem via the stderr warning and
  fixes the offending file; they don't get a silent fallback
  that masks the bug.
- **Aligns with `aggregator-as-classifier` memory**: the
  candidate walk is a classifier ("which file wins?") whose
  output is a single state. Letting invalid values pass through
  to the next file mixes two decisions (which file wins + is
  the winner valid). Option A keeps the classifier pure: first
  file that held the key is the winner; validity is orthogonal.
- **Matches parent's single-path behaviour**: on the parent,
  `chat: fr` in the only config emits one warning and
  default-off. Option B would make the 2-file case behave
  differently from the 1-file case ("if I add a user-home
  config, my project-level `fr` starts to be overridden"). That
  surprise is worse than the consistency of option A.
- **Simpler implementation**: the loop sets `cfg_chat` and
  `cfg_source_path` on first hit (valid or invalid), then
  `break`s. Outside the loop, a single dispatch determines
  marker emission or warning. No per-iteration warning history
  to track.
- **PRD AC4.a reads** "for each candidate path ... **when that
  file is present with `chat: fr`** ... the hook emits exactly
  one stderr warning line that names the candidate file path
  and the invalid value, and default-off behaviour obtains (no
  `LANG_CHAT=` marker from that file). Iteration continues to
  the next candidate — a malformed early candidate must not
  block a valid later one." Read literally, this is option B.
  See tradeoff accepted below.

**Tradeoffs accepted**:

- **PRD AC4.a's "iteration continues to the next candidate —
  a malformed early candidate must not block a valid later
  one" reads like option B.** I am choosing A instead because
  the argument above (firm-statement semantics + classifier
  purity + consistency with parent single-path) is stronger
  than the PM's stated intent. This requires a one-sentence
  clarification to AC4.a at TPM stage: change "iteration
  continues" to "iteration stops at the first file that held
  the `chat:` key; valid token → emit marker, invalid token →
  warn + default-off, empty-key → continue to next candidate".
  **This is a deviation from PRD AC4.a and MUST be surfaced to
  PM before TPM locks tasks.** If PM insists on option B
  semantics, D6 flips to B; the impl is mechanically the same
  (just remove the `break` on invalid and accumulate warnings).
  Either way, AC4.a must be rewritten to match the chosen
  semantics with no ambiguity.
- **If the project-level file has `chat: fr` AND the user-home
  file has `chat: zh-TW`**, option A emits one warning about
  the project file and no marker (user sees English chat in
  that repo until they fix the project file). Option B would
  emit one warning about the project file AND emit
  `LANG_CHAT=zh-TW` from the user file. A user could argue
  either is correct; A treats precedence as monotonic (project
  wins wholesale, including being wrongly spelled); B treats
  precedence as per-validity (project wins only if project is
  valid). I'm choosing A because the PRD's "project wins
  wholesale" language (R1) is stronger than "malformed early
  candidate must not block a valid later one" (AC4.a) — these
  two statements are in tension; one must yield. R1 is the
  contract; AC4.a is clarification — so I yield AC4.a.

**Reversibility**: high — the loop body change to swap A ↔ B
is removing or adding one `break` statement and toggling the
warning emission point.

**Requirement link**: R1 (precedence); R4 AC4.a (malformed
warning — **needs PM clarification**); R4 AC4.b (session never
blocked — both A and B satisfy this); parent R7 (graceful
degradation).

### D7. Hook edit diff sketch

The diff targets `.claude/hooks/session-start.sh` lines 258–287
(the existing config-read block) and adds one helper function
above the main section. Existing imports, traps, and JSON-emit
path are unchanged.

```diff
@@ -190,6 +190,28 @@ json_escape() {
   END { printf "" }'
 }

+# sniff_lang_chat <path>
+# Sniffs the lang.chat value from a YAML config file.
+# Echoes the token on stdout (empty string if key absent or file unreadable).
+# Awk body is byte-identical to the parent D7 block.
+sniff_lang_chat() {
+  local cfg_file="$1"
+  awk '/^lang:/        {in_lang=1; next}
+    in_lang && /^  chat:/ {
+      sub(/^  chat:[[:space:]]*/, "")
+      gsub(/"/, ""); gsub(/#.*$/, "")
+      gsub(/[[:space:]]+$/, "")
+      print; exit
+    }
+    /^[^ ]/         {in_lang=0}
+  ' "$cfg_file" 2>/dev/null
+}
+
 # ---------------------------------------------------------------------------
 # Main
 # ---------------------------------------------------------------------------
@@ -255,30 +277,40 @@ if [ -z "$digest" ]; then
   log_info "no valid rules found in $RULES_DIR"
 fi

-# New: read lang.chat from config, append marker line if set
-cfg_file=".spec-workflow/config.yml"
-if [ -r "$cfg_file" ]; then
-  cfg_chat=$(awk '/^lang:/        {in_lang=1; next}
-    in_lang && /^  chat:/ {
-      sub(/^  chat:[[:space:]]*/, "")
-      gsub(/"/, ""); gsub(/#.*$/, "")
-      gsub(/[[:space:]]+$/, "")
-      print; exit
-    }
-    /^[^ ]/         {in_lang=0}
-  ' "$cfg_file" 2>/dev/null)
-
-  case "$cfg_chat" in
-    zh-TW|en)
+# Read lang.chat from an ordered candidate list; first file with the key wins.
+# 1. .spec-workflow/config.yml  (project — wins when present)
+# 2. $XDG_CONFIG_HOME/specflow/config.yml  (only if env var set and non-empty)
+# 3. $HOME/.config/specflow/config.yml  (final tilde fallback)
+CANDIDATES=".spec-workflow/config.yml"
+if [ -n "${XDG_CONFIG_HOME:-}" ]; then
+  CANDIDATES="$CANDIDATES $XDG_CONFIG_HOME/specflow/config.yml"
+fi
+CANDIDATES="$CANDIDATES $HOME/.config/specflow/config.yml"
+
+cfg_chat=""
+cfg_source=""
+for cfg_file in $CANDIDATES; do
+  [ -r "$cfg_file" ] || continue
+  cfg_chat="$(sniff_lang_chat "$cfg_file")"
+  if [ -n "$cfg_chat" ]; then
+    cfg_source="$cfg_file"
+    break
+  fi
+done
+
+if [ -n "$cfg_chat" ]; then
+  if [ "$cfg_chat" = "zh-TW" ] || [ "$cfg_chat" = "en" ]; then
+    if [ -n "$digest" ]; then
+      digest=$(printf '%s\nLANG_CHAT=%s' "$digest" "$cfg_chat")
+    else
+      digest="LANG_CHAT=$cfg_chat"
+    fi
+  else
+    log_warn "$cfg_source: lang.chat has unknown value '$cfg_chat' — ignored"
+  fi
+fi
+
-      if [ -n "$digest" ]; then
-        digest=$(printf '%s\nLANG_CHAT=%s' "$digest" "$cfg_chat")
-      else
-        digest="LANG_CHAT=$cfg_chat"
-      fi
-      ;;
-    "")
-      # Empty / absent key — default-off, no warning
-      :
-      ;;
-    *)
-      log_warn "config.yml: lang.chat has unknown value '$cfg_chat' — ignored"
-      ;;
-  esac
-fi
```

**Key properties of this diff**:

- **No `case` inside a `$(...)` subshell.** The validity dispatch
  is an `if/elif/else` block, per the parent's bash-3.2 guidance
  (rule `bash/bash-32-portability.md` §case-in-subshell). The
  original parent block had `case` at top-level (not inside
  `$(...)`), which is safe; but the new block's structure favours
  `if/elif` uniformly for clarity and to match the architect
  memory.
- **awk body is byte-identical**. The awk program inside
  `sniff_lang_chat` is cut-and-pasted from the parent's lines
  261–269; `grep -c 'in_lang=1'` returns 1. R2 AC2.b holds.
- **Fail-safe frame inherited**. Still under `set +e` + `trap
  'exit 0' ERR INT TERM`. Awk errors silently via `2>/dev/null`
  inside `sniff_lang_chat`. Unreadable files skipped via `[ -r ]`.
  Unknown token warns once and proceeds to JSON emit. Exit always
  0.
- **No new subprocess in the absent-file path.** When every
  candidate fails `[ -r … ]`, the awk program is never invoked;
  the loop terminates with empty `cfg_chat` and the dispatch
  below emits no marker. R5 AC5.b (wall-clock unchanged within
  noise) is satisfied by construction — the candidate list
  construction is ~3 string operations, and the `[ -r ]` probes
  on missing files are single `stat()` calls.
- **Warning message names the source file** (`$cfg_source: lang.
  chat has unknown value …`). R4 AC4.a's naming requirement is
  satisfied.

**Requirement link**: R1 AC1.a–d; R2 AC2.a, AC2.b; R4 AC4.a
(subject to PM clarification per D6), AC4.b, AC4.c; R5 AC5.a,
AC5.b.

### D8. README section update — one paragraph, keep parent's YAML schema intact

**Options considered**:

- A. **Append one paragraph** to the existing "Language
  preferences" section describing the candidate list and
  precedence.
- B. **Rewrite the entire section** to lead with the user-home
  path (since most users will prefer that) and demote the
  project-level path to "team override".
- C. **Add a new sibling section** "Language preferences —
  candidate paths".

**Chosen**: **A — append one paragraph** to the existing section.

**Why**:

- **`scope-extension-minimal-diff` memory** applies to docs as
  well as enums. The existing section names one path; extend by
  appending; don't rewrite the existing prose. Reviewers see a
  localized doc diff; grep patterns for the existing content
  continue to work.
- **Option B's narrative inversion** breaks people who have
  already bookmarked the existing section or quoted it in
  slack/issues. The cost of reordering is paid every time
  someone searches for the old lead sentence.
- **Option C** is wasteful: the two sections would inevitably
  drift, and a reader looking for "how do I configure chat
  language" would have to read both.

**Paragraph shape** (approximate; TPM finalises wording):

```
The hook consults an ordered list of candidate paths and uses
the first readable file whose `lang.chat` value is recognised:

1. `.spec-workflow/config.yml` — project-level, committed to the
   repo, wins when present.
2. `$XDG_CONFIG_HOME/specflow/config.yml` — consulted only when
   `$XDG_CONFIG_HOME` is set and non-empty.
3. `~/.config/specflow/config.yml` — user-home fallback; set
   once per machine for personal preference across all repos.

Precedence: project > XDG > tilde. All three absent → English
baseline (no change from default).
```

**Lines/paragraphs changed in existing README section**:

- **Existing lead sentence** ("Create `.spec-workflow/config.yml`
  with `lang:\n  chat: zh-TW`"): unchanged. Still accurate.
- **New paragraph** (the three-bullet candidate list above)
  appended right after the existing example snippet.
- **Existing warning** about malformed/unknown values ("any
  other value triggers a stderr warning and default-off
  behaviour"): unchanged; still accurate per-file.
- **No YAML schema change** — the v1 schema (`lang:` block →
  `  chat: <zh-TW|en>`) from parent D9 stays word-for-word. R6
  AC6.d guarantees the rule file is untouched; the README
  example snippets reuse the parent's exact YAML.

**Tradeoffs accepted**:

- **The README section grows** from ~10 lines to ~20 lines.
  Acceptable; the precedence rule is a first-class concept a
  user must understand before authoring either file.
- **One user-facing phrase names the XDG path explicitly**
  (R6 AC6.b). Users who don't use XDG can skim-past.

**Requirement link**: R6 AC6.a (tilde path documented), AC6.b
(XDG path documented with env-var gating), AC6.c (precedence
stated in plain words), AC6.d (rule file unchanged — enforced
by the diff itself, not the README).

---

## 4. Data flow

### 4.a — All three files absent (default-off baseline, AC1.a + AC7.c)

1. Alice opens a Claude Code session in a fresh repo. No
   `.spec-workflow/config.yml`. No `$XDG_CONFIG_HOME` env var set.
   No `~/.config/specflow/config.yml`.
2. Hook reaches the new block. `CANDIDATES` evaluates to
   `".spec-workflow/config.yml $HOME/.config/specflow/config.yml"`
   (two entries; the XDG entry is skipped by
   `[ -n "${XDG_CONFIG_HOME:-}" ]` returning false).
3. Loop iterates:
   - Candidate 1: `[ -r ".spec-workflow/config.yml" ]` → false
     (file absent). `continue`.
   - Candidate 2: `[ -r "$HOME/.config/specflow/config.yml" ]` →
     false. `continue`.
4. Loop terminates. `cfg_chat=""`, `cfg_source=""`.
5. Outer `if [ -n "$cfg_chat" ]` is false. No marker emission.
   No warning.
6. JSON payload emitted without any `LANG_CHAT=` line. Session
   reads default English. R1 AC1.a satisfied; R4 AC4.c (missing
   file silent) satisfied.
7. Total extra cost vs parent's single-path read: two `stat()`
   calls, one string comparison for the XDG env, one for-loop
   setup. Sub-millisecond. R5 AC5.b satisfied.

### 4.b — Project absent, XDG unset, tilde-config sets `chat: zh-TW` (AC1.b)

1. Bob has authored `~/.config/specflow/config.yml` with:
   ```
   lang:
     chat: zh-TW
   ```
   He opens a session in a repo that has no
   `.spec-workflow/config.yml`. `$XDG_CONFIG_HOME` unset.
2. Hook reaches the new block. `CANDIDATES` evaluates to
   `".spec-workflow/config.yml $HOME/.config/specflow/config.yml"`.
3. Loop iterates:
   - Candidate 1: `[ -r ".spec-workflow/config.yml" ]` → false.
     `continue`.
   - Candidate 2: `[ -r "$HOME/.config/specflow/config.yml" ]`
     → true. Call `sniff_lang_chat "$HOME/.config/specflow/
     config.yml"`. Awk matches `^lang:` → `in_lang=1` → matches
     `^  chat:` → extracts `zh-TW` → `print; exit`. Function
     returns `zh-TW`. `cfg_chat="zh-TW"`, `cfg_source="$HOME/
     .config/specflow/config.yml"`. `break`.
4. Outer `if [ -n "$cfg_chat" ]` is true. `cfg_chat = zh-TW`
   matches the valid-token branch. Digest gets
   `LANG_CHAT=zh-TW` appended.
5. JSON payload includes the marker in `additionalContext`.
   Session activates the rule body's zh-TW directive. Bob's
   subagent replies in zh-TW; file contents stay English. R1
   AC1.b satisfied.
6. Wall-clock cost: two `stat()` + one `awk` + one `break`.
   Same order of magnitude as parent's single-path run.

---

## 5. Blocker questions

**One item requires PM clarification before TPM locks tasks**,
surfaced from D6:

- **PRD AC4.a's "iteration continues to the next candidate —
  a malformed early candidate must not block a valid later
  one" conflicts with D6's chosen "stop at first file that
  held the key" semantics.** I recommend option A (stop-on-
  first-hit, even invalid) per the R1 precedence-wins-wholesale
  contract and the `aggregator-as-classifier` discipline, but
  this deviates from the literal PRD text. If PM holds option B
  (continue past invalid), the implementation swaps one
  `break` for warning emission and the loop accumulates
  warnings across candidates — mechanically trivial, but the
  semantics change.

**Proposed resolution**: Architect recommends A; PM to confirm
or flip before TPM starts 05-plan.md. If flipped to B, AC4.a
stays as written, D6 body and the diff sketch in D7 adjust
(remove the `break`-on-invalid, keep warning emission, continue
the loop). If A holds, AC4.a is rewritten to:

> For each candidate path (project, XDG, simple-tilde), when
> the **first** file whose `chat:` line is present holds a
> value outside `{zh-TW, en}`, the hook emits exactly one
> stderr warning line naming that file path and the invalid
> value, no `LANG_CHAT=` marker is emitted, and iteration
> stops (later candidates are not consulted). A missing `chat:`
> key means the file did not hold the key; iteration continues
> to the next candidate per R1.

No other blockers. All other PRD decisions are resolved in D1–D8.

---

## 6. Implementation hints for TPM

- **Single task or split?** Single implement task for the hook
  edit + helper function. Total diff is ≈ 30 lines in one file.
  Splitting into "add helper" + "add loop" is over-decomposition
  for a 25-line diff. Tests and README are separate tasks.
- **Where the awk function lives**: above the `Main` section
  comment banner (line 193 in the current file), alongside the
  other helpers (`classify_frontmatter`, `digest_rule`, …). No
  new file; the helper is private to this hook.
- **Tests mirror parent shapes**: reuse the `t54`–`t57` pattern
  from parent's verify (sandboxed `$HOME`, `HOOK_TEST=1`
  invocation, digest parse). New test names (illustrative; TPM
  numbers):
  - `t70_hook_all_absent.sh` — AC1.a baseline (both project and
    user configs absent, XDG unset) → no marker, no warning.
  - `t71_hook_user_home_only.sh` — AC1.b (project absent, tilde
    has `zh-TW`) → marker emitted.
  - `t72_hook_project_over_user.sh` — AC1.c (both present,
    project=`zh-TW`, user=`en`) → `LANG_CHAT=zh-TW`.
  - `t73_hook_xdg_over_tilde.sh` — AC1.d (project absent,
    `$XDG_CONFIG_HOME` set non-empty, XDG path has `zh-TW`,
    tilde has `en`) → `LANG_CHAT=zh-TW`.
  - `t74_hook_unknown_value_naming.sh` — AC4.a (project-level
    has `chat: fr`) → one stderr warning naming
    `.spec-workflow/config.yml`, no marker. (Depending on the
    blocker question resolution, this test either stops
    iteration or continues.)
  - `t75_hook_single_awk_definition.sh` — AC2.a (`grep -c
    'in_lang=1'` on the hook script returns `1`).
  - `t76_hook_awk_body_byte_identical.sh` — AC2.b (diff awk
    body against parent — see note below).
  - `t77_readme_precedence_documented.sh` — AC6.a, AC6.b,
    AC6.c (grep README for the three documented strings).
  - `t78_rule_file_unchanged.sh` — AC6.d (`git diff` at final
    commit shows zero lines under
    `.claude/rules/common/language-preferences.md`).
- **AC2.b byte-identical test**: the awk body is extracted
  from the parent via line range (the diff above locks
  `sniff_lang_chat`'s function body lines). The test can grep
  for each awk token in order (`/^lang:/`, `in_lang=1`, `^  chat:/`,
  `sub(/^  chat:/`, etc.) and assert the sequence is unchanged
  from the parent hook at the last merged commit. Alternatively,
  a structural assertion: extract the awk program text from both
  files and diff. TPM picks whichever is cleaner.
- **Sandbox-home discipline**: every test script applies
  `.claude/rules/bash/sandbox-home-in-tests.md` — `mktemp -d`
  root, `export HOME="$SANDBOX/home"`, preflight assertion,
  `trap 'rm -rf "$SANDBOX"' EXIT`. The XDG test additionally
  sets `export XDG_CONFIG_HOME="$SANDBOX/xdg"` and creates the
  path-prefixed config.
- **No new bin script, no new rule file, no settings.json
  change.** This feature's install surface is: one hook edit +
  one README paragraph. `specflow-seed update` picks up the hook
  change on next invocation in consumer repos (the hook is in
  the managed subtree); no migration step required.
- **Dogfood paradox annotation**: 08-verify.md must label AC1.b,
  AC1.c, AC1.d, AC4.a as "structural PASS; runtime verification
  deferred to next feature after session restart" per R7 AC7.a.
  The next feature after archive adds one STATUS Notes line
  confirming first-session behaviour (R7 AC7.b).

---

## 7. Non-decisions / deferred

- **No env-var escape hatch (`SPECFLOW_CONFIG`).** PRD non-goal
  #1. Smoke tests sandbox `$HOME` and `$XDG_CONFIG_HOME`
  directly; no CLI knob needed. Revisit only if operators
  demonstrate a non-synthetic need (e.g., CI systems that can't
  override `$HOME`). The candidate-list shape in D5 leaves room
  to prepend one slot without reshape, per
  `scope-extension-minimal-diff`.
- **No per-key merge semantics.** PRD non-goal #2. File-level
  override (D6 semantics, whichever option PM picks) is the v1
  contract. Key-level merge becomes interesting only when the
  schema has ≥ 2 keys; revisit with a later feature that adds a
  second key.
- **No space-in-path hardening.** A user with a space in
  `$HOME` or `$XDG_CONFIG_HOME` would see the candidate split
  unhelpfully; the loop passes through to the next candidate or
  to default-off. Guarding requires array syntax and breaks
  parent hook style (D5 tradeoff). If a user reports this, flip
  D5 to option B (bash array).
- **No per-candidate cascading of invalid values.** D6 picks
  option A (stop-on-first-hit). If PM flips to option B, this
  non-decision retires.
- **No migration tooling, no `specflow config set` CLI, no
  cross-machine sync.** PRD non-goals #3, #6, #7. Revisit if
  user friction signals emerge.

---

## Summary

- **D-count**: 8 primary decisions (D1–D8), 5 deferred
  non-decisions.
- **XDG decision**: **XDG-aware** (option A) chosen. PRD R1's
  three-entry candidate list stands as written; AC1.d and AC6.b
  remain in scope.
- **Blocker question status**: **1 item** for PM clarification —
  AC4.a's "iteration continues past invalid" language conflicts
  with D6's chosen "stop at first file that held the key"
  semantics. Recommend PM accept the D6 rewording proposed in
  §5; otherwise the implementation flips trivially.
- **D4 one-phrase summary**: **awk block becomes a
  `sniff_lang_chat <path>` helper; awk body byte-identical to
  parent D7.**
- **Applied memory entries**: `hook-fail-safe-pattern`,
  `shell-portability-readlink`, `scope-extension-minimal-diff`,
  `classification-before-mutation`, `aggregator-as-classifier`,
  `dogfood-paradox-third-occurrence` (8th occurrence).
