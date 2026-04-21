# Brainstorm — language-preferences

_2026-04-19 · PM_

## Problem restatement

The user wants one opt-in knob so that every specflow subagent (PM, Architect, TPM, Developer, QA-analyst, QA-tester, Designer) replies to them in zh-TW while continuing to write all committed artifacts (PRDs, plans, tasks, code, commit messages, `.spec-workflow/features/**`, `.claude/**`) in English. Default behavior must be unchanged for contributors who have not opted in.

## Approaches considered

### Approach A — SessionStart hook injects a language directive into every session

**Sketch.** Extend `.claude/hooks/session-start.sh` to read a `lang.chat` key from a config file. If `lang.chat == "zh-TW"`, the hook emits (as part of its JSON additional-context payload) a short system-level directive: "Reply to the user in zh-TW; write all file content, tool arguments, and commit messages in English." Single injection point; no per-agent edits.

**Pros.**
- Single knob at the hook level; easy to toggle by editing config.
- No per-agent sprawl — all seven subagents inherit from the same session context.
- Reuses the existing SessionStart hook pathway we built for rules digest.

**Cons.**
- The hook payload is session-global, so the directive competes with agent-specific system prompts for priority. Under long context, a subagent may drift and start writing zh-TW into a PRD.
- SessionStart additional context is a non-frontmatter surface — it is additive prose that the model treats advisorily, not as a hard rule.
- The specflow hook payload format has to grow a new field; currently it carries rules digest only.

**Risks.**
- Drift failure mode is silent until caught at review time. Needs a guardrail (see D).

### Approach B — Per-agent frontmatter directive in each `.claude/agents/specflow/*.md`

**Sketch.** Add an identical "reply in user-language, write in English" block to each of the seven agent definition files. Optionally gated via a `{{lang.chat}}` template token the agents interpret at load.

**Pros.**
- Explicit and discoverable — each agent file declares its own language posture.
- No runtime config-read needed at hook time.

**Cons.**
- Seven places to edit — directly violates the request's "single knob" constraint.
- Cannot be toggled at runtime without editing seven files and restarting.
- No obvious gate on default-off: either the directive is present (always zh-TW) or not (always English); there is no third state without duplicating content into two branches.
- Drift-prone: adding an eighth agent later means remembering to carry the block.

**Risks.**
- Fails the "opt-in, default-off" constraint outright.

### Approach C — Rule file in `.claude/rules/common/` that declares the language split, gated on config

**Sketch.** Add `.claude/rules/common/language-preferences.md` to the existing rules tree. Content: "If the user has set `lang.chat`, reply to the user in that language. File writes, tool arguments, code, comments, and commit messages remain English." The rule is loaded by the existing SessionStart digest at every session; the config read (`lang.chat`) happens once at hook time and is injected as a small `LANG_CHAT=<value>` line the rule can reference. Default-off is natural: if the config key is unset or the file doesn't exist, the hook injects nothing and the rule's conditional collapses to a no-op.

**Pros.**
- Matches the established `.claude/rules/` pattern — same authoring shape, same discovery surface, same severity semantics.
- Single file to edit, single config key to toggle; the "single knob" constraint is met at the config level.
- Default-off is free: absent config → no injection → rule's conditional body does nothing.
- Self-documenting: a reviewer looking at `.claude/rules/index.md` sees the language-preferences rule listed alongside every other session guardrail.
- Composes cleanly with the existing rule digest emission — no new hook surface, just a new rule entry and a tiny hook-side config read.

**Cons.**
- Still prompt-level: a rule is advisory to the model, not a compiler-enforced contract. Drift is possible under long context.
- The rule's conditional prose ("if lang.chat is set...") is a new pattern — existing rules are unconditional. Needs care so the `session-start.sh` classifier doesn't reject it as malformed.

**Risks.**
- Medium: drift-into-file failure mode is identical to A, same mitigation (D).
- Low: rule-file shape diverges from the existing unconditional examples, which could confuse future rule authors. Mitigate by documenting the conditional pattern in the rule's `## How to apply` body.

### Approach D — Pre-commit / post-write guardrail that rejects non-ASCII in committed artifacts

**Sketch.** **Complement, not alternative.** A mechanical check (pre-commit hook, Stop hook lint step, or `bin/specflow-*` post-write sweep) that scans staged files under `.spec-workflow/features/**`, `.claude/**`, `bin/**`, and commit message body for non-ASCII / CJK codepoints. On hit: fail loudly with file+line, ask the user to confirm or rewrite. Whitelist: `.md` files that are already zh-TW (archived non-English fixtures) can be exempted via a path allowlist or a header marker.

**Pros.**
- Mechanical: doesn't rely on model discipline. Catches the failure mode A and C both have.
- Catches human mistakes too — a contributor pasting zh-TW into a PRD by hand is caught.
- Trivially default-on for everyone; has no opt-out knob because English artifacts is a property the repo wants regardless of the language-chat feature.

**Cons.**
- Adds a failure surface to the commit path; needs an allowlist or bypass for legitimate non-ASCII content (rare in this repo — even the 00-request raw quote is kept short and contained).
- Requires a decision on where the check runs: git pre-commit hook, Claude Code Stop hook, or a specflow-level lint.

**Risks.**
- False positives on legitimate non-ASCII (curly quotes, em-dashes, the single zh-TW fragment in 00-request.md). Mitigate by restricting the check to CJK blocks, not all non-ASCII, and by allowlisting the request-quote block pattern.

## Evaluation axes

- **Single knob.** One config edit toggles the feature on/off for all seven agents at once.
- **Default-off preservation.** A contributor with no config set sees today's behavior exactly.
- **Leak resistance.** How reliably does the approach prevent zh-TW from landing in a committed file?
- **Blast radius of failure.** If the mechanism fails, what breaks — one commit, one session, all sessions?
- **Reuses existing machinery.** Prefers extending SessionStart hook / rules tree / config over net-new surfaces.
- **Dogfoodability.** Can this feature exercise its own behavior during its own development session? (Spoiler: no — see Dogfood paradox below.)

## Comparison matrix

| Axis                           | A (hook directive)            | B (per-agent frontmatter)        | C (conditional rule file)     | D (commit guardrail, complement) |
|--------------------------------|-------------------------------|----------------------------------|-------------------------------|----------------------------------|
| Single knob                    | yes (config key)              | no (seven files)                 | yes (config key)              | n/a (always on)                  |
| Default-off                    | yes (key absent → no inject)  | awkward (requires removal)       | yes (key absent → no inject)  | n/a (default-on is desired)      |
| Leak resistance                | medium (model discipline)     | medium (model discipline)        | medium (model discipline)     | high (mechanical)                |
| Blast radius of failure        | session-global chat drift     | session-global chat drift        | session-global chat drift     | one rejected commit              |
| Reuses existing machinery      | partial (new hook field)      | no (new duplicated content)      | yes (rules tree + hook)       | yes (hook or pre-commit)         |
| Dogfoodability                 | no (see paradox)              | no                               | no                             | yes (can catch leaks from day 0) |

## Open-question resolutions

1. **Language set in v1.** Two-value knob: `lang.chat ∈ {zh-TW, en}`, `lang.artifacts` fixed at `en` and not user-configurable. Any additional language (ja, ko, etc.) is out of scope and explicitly punted to a future feature. Rationale: the user's ask names one language; designing a general i18n framework for one user is premature.
2. **Scope of "chat".** In-scope: subagent conversational prose (PM/Architect/TPM/Developer/QA-*/Designer replies) AND the top-level Claude Code session's final-message prose to the user. Out-of-scope, stays English: CLI stdout (`bin/specflow-*`), hook log lines, tool names (`Read`/`Write`/`Bash`/etc.), status telemetry, STATUS Notes entries, commit messages, error messages from scripts, anything grep-ed by machine tooling. Call-out list belongs in the PRD's Non-goals section.
3. **Config location.** Two candidates, hand to Architect at `/specflow:tech`:
   - **`.spec-workflow/config.yml` (specflow-native).** Fits the per-project install model (the config travels with the consumer repo, is versioned, and is naturally ignored by other projects on the same machine). Requires adding a YAML read to `session-start.sh` (no `jq`; use awk/sed per `.claude/rules/bash/bash-32-portability.md`).
   - **`.claude/settings.json` (Claude-harness-native).** Already exists in each consumer repo per per-project-install; JSON parse path already used by `bin/specflow-install-hook`. Risk: mixes specflow concerns with Claude Code settings, which may conflict with future Claude Code schema changes.
   - PM's lean: `.spec-workflow/config.yml`. Reasoning: specflow owns the key; bash 3.2 YAML read is trivial for a single flat key (`lang.chat: zh-TW`); and it won't collide with a future Claude Code schema. Final call belongs to the Architect.

## Recommendation

**Adopt Approach C (conditional rule file in `.claude/rules/common/`) + Approach D (commit-time guardrail) as a paired design.**

Rationale (5 lines):
1. C meets the "single knob" constraint at the config level and reuses the existing rules+hook machinery with no new session surface.
2. C's default-off is structural: absent config key → hook injects nothing → rule body is a no-op.
3. D compensates for C's one real weakness — prompt-level directives drift under long context. A mechanical CJK scan at commit time turns silent leaks into loud failures at the exact moment they would otherwise escape review.
4. C alone is insufficient (leak resistance medium); D alone forces the user to translate manually every turn; the pair is the minimum honest design.
5. Both halves reuse existing primitives: C extends `.claude/rules/` and `.claude/hooks/session-start.sh`; D can live as a Stop-hook lint step or a `bin/specflow-*` sweep, neither of which is a new surface.

Trade-offs accepted:
- **Prompt-level drift remains possible** (guardrail D catches it at commit, not at the point of generation — one extra user-visible cycle when drift occurs).
- **Conditional rule shape is a new pattern** in `.claude/rules/`; existing rules are unconditional. The rule file itself must document the pattern in its `## How to apply` body so future rule authors don't mistake it for a template.

### Runners-up

- **Approach A** is viable if the Architect decides a rule file is too heavyweight for a single conditional directive. A's failure mode is indistinguishable from C's, and A loses the rules-tree discoverability.
- **Approach B** is explicitly rejected — it violates the single-knob constraint.

## Dogfood paradox

Per `shared/dogfood-paradox-third-occurrence.md` (now sixth+ occurrence in this repo), this feature ships a mechanism it would itself invoke: the chat-language directive is injected by a hook that the feature modifies; the guardrail is a commit-time lint the feature itself introduces. Neither is live during this feature's own development.

Implications:
- **Structural verification only during this feature's own `verify` stage.** AC coverage is "rule file exists, hook reads the config key, guardrail script exists and rejects a synthetic zh-TW fixture on a sandbox commit." Runtime verification — "the next session after merge actually replies in zh-TW when the knob is set" — is **deferred to a manual smoke test by the user after archive**.
- **The subagents cannot exercise their own zh-TW output during development.** Every PM/Architect/TPM/Developer reply written during the development of this feature itself will be in English regardless of any knob value, because the knob-reading machinery does not yet exist in the running session.
- **QA-tester guidance.** The `08-verify.md` must mark chat-language ACs as "structural PASS; runtime verification deferred to <first session after archive+restart>" and the PRD's Edge Cases section must include a `## Dogfood paradox` subsection enumerating which ACs are structural-only.

## Risks / follow-ups for PRD

1. **Guardrail scope.** PRD must enumerate exactly which paths are scanned (`.spec-workflow/features/**`, `.claude/**`, `bin/**`, commit messages) and what codepoint ranges count as a hit (CJK Unified Ideographs U+4E00-U+9FFF, Bopomofo U+3100-U+312F, Hiragana/Katakana if we future-proof, Hangul if likewise — or zh-TW only for v1). Keep tight; broaden later.
2. **Allowlist mechanism.** How does a legitimate non-ASCII fragment (e.g. the raw zh-TW quote in `00-request.md`) pass the guardrail? Header marker? Path allowlist? PRD decides.
3. **Config key shape.** `lang.chat: zh-TW` vs `language: { chat: zh-TW, artifacts: en }` vs a flat `specflow.lang.chat`. Architect at `/specflow:tech`.
4. **Config location.** `.spec-workflow/config.yml` vs `.claude/settings.json` vs env var (rejected — env vars don't travel with the repo and break per-project isolation). Architect at `/specflow:tech`.
5. **YAML read without `jq` or non-portable tools.** If config lives in `.spec-workflow/config.yml`, the `session-start.sh` reader must use awk/sed for a single flat key (`.claude/rules/bash/bash-32-portability.md` forbids `jq`). One-liner: `awk -F': *' '/^lang\.chat:/{print $2; exit}' .spec-workflow/config.yml`. PRD should cite this directly so Architect does not re-debate.
6. **Guardrail surface.** Stop hook vs git pre-commit vs specflow lint command. Each has trade-offs (Stop hook is specflow-owned but only fires inside Claude Code; pre-commit fires on every `git commit` regardless of origin). Architect at `/specflow:tech`.
7. **Migration for existing consumers.** The per-project-install model means each consumer repo already has its own `.claude/` tree and (soon) `.spec-workflow/config.yml`. A consumer that hasn't run `specflow:update` since this feature lands will have no language-preferences rule file — default-off naturally. No migration script needed; document this in the PRD's migration section.
8. **Rule conditional pattern.** The new rule file introduces a conditional-body shape to a rule tree that is otherwise unconditional. PRD should include an AC that the rule's `## How to apply` body explicitly documents the condition (`when lang.chat is set to zh-TW, ...`) so the pattern is discoverable to the next rule author.

## Team memory

- `shared/dogfood-paradox-third-occurrence.md` — applied. "Dogfood paradox" section above follows structural-during-own-verify / runtime-next-feature split; PRD Edge Cases will carry the split forward; QA-tester guidance called out.
- `pm/ac-must-verify-existing-baseline.md` — applied as hygiene: no cross-file parity claims asserted in this brainstorm; when PRD writes guardrail-vs-rule-file ACs, do not say "match existing rules shape" without citing one specific rule file (the new conditional pattern is novel by design).
- `pm/housekeeping-sweep-threshold.md` — does not apply (this is a functional feature, not a review-nits sweep).
- `pm/split-by-blast-radius-not-item-count.md` (global) — considered, does not split: Approaches C and D have different surfaces (session-wide rule injection vs commit-time lint) but the request bundles them as a single opt-in UX. Blast radii differ but they only function together; splitting would leave each half partially useful. Flag for PRD: if implementation sequencing suggests C and D ship in different waves, revisit the split then.
