# Request

**Raw ask**:
- 原文 (zh-TW): `lang 我希望可以設定語言，像我希望討論都是透過中文，但文件都是透過英文`
- EN: "I want to configure a language preference — discussion (chat) in Traditional Chinese, but all documents/artifacts in English."

**Context**:

Why now — the user (yang.hung.tw@gmail.com, a zh-TW native speaker) works through specflow's subagent pipeline (PM, Architect, TPM, Developer, QA-analyst, QA-tester, Designer) daily and wants to collaborate in Chinese while keeping every written artifact (PRDs, plans, tasks, commit messages, code comments, markdown files under `.spec-workflow/features/**`, `.claude/**`, and source code) in English for shareability and PR review.

Constraints:
- Must apply uniformly across **all specflow subagents** — a single config knob, not per-prompt edits.
- Must **not leak Chinese into any committed file**: `.spec-workflow/features/**`, `.claude/**` (agents, rules, team-memory), source code, tests, commit messages.
- Must **not break multi-contributor repos** where other readers expect English artifacts — the feature must be opt-in and default-off so repo behavior is unchanged for users who have not opted in.
- Preserves git-diff-reviewability and grep-ability of artifacts.

Open questions (defer to brainstorm):
- **Which languages in v1?** Assumption: two-value knob — chat = zh-TW, artifacts = English. Other languages are future work, out of scope for v1.
- **Scope of "chat".** Does this include CLI tool stdout (`bin/specflow-*`, hook output, log lines) or only subagent prose replies to the user? Assumption: **subagent prose only**; CLI output, status messages, and tool names stay English for log grep-ability and cross-machine portability.
- **Config location.** Where does the language knob live — `.spec-workflow/config.yml`, `.claude/settings.json`, or an env var? Defer to architect at `/specflow:tech`.

**Success looks like**:
- A single opt-in config setting switches all subagent conversational replies to zh-TW.
- Every file written to `.spec-workflow/features/**`, `.claude/**` (agents, rules, team-memory, commands), source code, tests, and commit messages remains in English regardless of the setting's value.
- All seven specflow subagents (PM, Architect, TPM, Developer, QA-analyst, QA-tester, Designer) honor the knob consistently — no per-agent toggle.
- Default behavior (setting absent or unset) is identical to today's English-only behavior; no change for users who have not opted in.
- A sanity check (grep or hook) can detect accidental Chinese in committed artifacts and fail loudly before merge.

**Out of scope**:
- Translating or back-filling any existing artifact (PRDs, rules, memory, archive) into zh-TW or any other language.
- Localizing specflow CLI stdout, tool names, hook log lines, or status messages — those stay English.
- A general-purpose i18n / locale framework or support for additional languages (ja, ko, etc.) in v1; future extension is not designed-for here.

**UI involved?**: no
