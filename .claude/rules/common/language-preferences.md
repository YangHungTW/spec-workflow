---
name: language-preferences
scope: common
severity: should
created: 2026-04-19
updated: 2026-04-19
---

## Rule

When `LANG_CHAT=zh-TW` appears in the SessionStart additional-context payload, write all chat replies to the user in Traditional Chinese (zh-TW); otherwise this rule is a no-op and all output remains English.

## Why

Users who prefer Traditional Chinese for conversational replies should receive responses in that language without needing to repeat the preference each turn; centralising the rule in a common scope ensures every specaffold subagent role (PM, Architect, TPM, Developer, QA-analyst, QA-tester, Designer) honours it uniformly without per-agent duplication.

## How to apply

The marker `LANG_CHAT=zh-TW` is injected by the SessionStart hook when `.specaffold/config.yml` contains:

```yaml
# .specaffold/config.yml
lang:
  chat: zh-TW    # or "en" (explicit default)  -- any other value -> warning + default-off
```

When the marker is present, apply **only** the following change: replies shown to the user in chat are written in zh-TW. Everything else listed below stays English regardless of config value, with no exceptions:

(a) **Chat replies to the user**  -- in zh-TW when `LANG_CHAT=zh-TW` is active; English when absent or `LANG_CHAT=en`.
(b) **File content**  -- every file written via any tool (`Write`, `Edit`, `NotebookEdit`, etc.) has English content.
(c) **Tool-call arguments**  -- all paths, patterns, flags, commit messages, and branch names passed to any tool are English.
(d) **CLI stdout**  -- output emitted by any `bin/scaff-*` script or hook script is English.
(e) **Commit messages**  -- always English.
(f) **STATUS Notes and team-memory files**  -- STATUS Notes entries and any file under `.claude/team-memory/**` are English.

No reverse directive applies: there is no condition under which file content, CLI stdout, commit messages, tool arguments, or team-memory files should be written in zh-TW.

## Example

**Positive  -- chat reply in zh-TW (correct when opted in):**

PM's brainstorm summary shown to the user in chat is zh-TW when `LANG_CHAT=zh-TW` is active. For example, after gathering requirements the PM agent may write a summary paragraph in zh-TW as its chat reply, while any file it writes (e.g. a draft PRD) remains English.

**Negative  -- these always stay English regardless of config:**

1. CLI stdout from a `bin/scaff-*` script:
   ```
   PASS: session-start hook syntax OK
   ```
   This line is English even when `LANG_CHAT=zh-TW` is set; zh-TW output here would break log parsing.

2. A STATUS Notes line written by the Developer:
   ```
   - 2026-04-19 Developer -- created language-preferences rule file
   ```
   STATUS Notes are written to `.claude/team-memory/` files or task markdown; both are English-only per carve-out (f).

3. A commit message authored by any agent:
   ```
   T1: .claude/rules/common/language-preferences.md + index row
   ```
   Commit messages must be English so that `git log` output and automated tooling remain parseable by all contributors regardless of locale.
