# Request

**Raw ask**:
- User text (EN): "user-level language config fallback — `~/.config/specflow/config.yml` (or user-home equivalent) provides a default `lang.chat` setting that applies across all repos; project-level `.spec-workflow/config.yml` still overrides when present. Follow-up to `20260419-language-preferences` which only shipped project-level config (design gap: chat language is a personal preference, should not require per-repo opt-in)."
- Trigger moment: immediately after the parent feature (`20260419-language-preferences`) reached verify PASS, the user (yang.hung.tw) asked in-session `這 config 不是 user level 的嗎?` ("isn't this config supposed to be user-level?"). This feature exists to close that gap.

**Context**:

Why now — the parent feature shipped a single config knob at `.spec-workflow/config.yml` (per-repo, opt-in, default-off, team-shareable via commit). Within ~10 minutes of archive-ready, the user realised that "reply in zh-TW" is a **personal** preference, not a **project** preference: it should follow the person across every repo they drive specflow in, not require an identical two-line YAML file in each consumer tree. N repos → N identical files → forgetting one means English chat in that repo, which is a pure papercut with no upside. The design gap is that the parent optimised for team-level opt-in (correct for projects that want the whole team in zh-TW) but did not consider the single-user-many-repos case (which is the actual shape for a zh-TW native working across their own repos).

Who asked — yang.hung.tw@gmail.com, the same user who authored the parent feature.

Constraints:
- **Extend the parent's hook read-path, do not replace it.** The parent's `.claude/hooks/session-start.sh` currently reads only `.spec-workflow/config.yml`. This feature adds a second, user-home source that the hook consults when the project-level file is absent. Project-level retains highest precedence (team override semantics preserved for consumers that already rely on them).
- **Default-off invariant preserved.** If neither the project-level nor the user-home file exists (or neither sets `lang.chat`), the hook emits no `LANG_CHAT=…` marker — exactly today's behaviour. A user who has not authored either file sees zero change.
- **Artifacts-always-English invariant preserved.** This feature is about config **location**, not about directive semantics. The parent's rule file (`.claude/rules/common/language-preferences.md`) and its carve-outs (R3) are untouched. File writes, tool arguments, commit messages, and CLI stdout remain English regardless of config source.
- **Bash 3.2 portable** (same discipline as parent). No `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `[[ =~ ]]` for portability-critical logic. The existing `awk` YAML sniff pattern in the parent hook (D7) is the template; the new user-home read reuses the same parser shape on a second file path.
- **Precedence is explicit and documented.** When both files exist, project-level wins **wholesale** (whole-file override, not key-level merge). The rule body in the README must state the resolution order unambiguously so a user with both files knows which one is live.
- **Schema unchanged.** Both files speak the parent's v1 schema (`lang:` block → `  chat: <zh-TW|en>`); no new keys, no nesting changes.

Open questions (defer to brainstorm):
- **Exact user-home path.** Candidates: `~/.config/specflow/config.yml` (XDG-style, Linux-idiomatic, macOS-compatible); `~/.specflow/config.yml` (short, tool-specific dotdir); `~/.claude/specflow-config.yml` (piggybacks the Claude Code dotdir already used by `~/.claude/settings.json`). Should `$XDG_CONFIG_HOME` be honoured when set, falling back to `~/.config/specflow/` otherwise? PM leans a single path for v1 (documented, no env-var fork); architect picks the path at `/specflow:tech`.
- **Merge vs override semantics.** When both files exist: **file-level override** (simpler — whichever file is consulted, it wins wholesale) vs **key-level merge** (project overrides only the keys it sets; user-home provides defaults for any key it doesn't). PM recommends file-level override for v1: simpler parser, no merge-rule complexity, matches the current one-key schema. Key-level merge is only worth the complexity when the schema grows beyond one key. Architect confirms at tech.
- **Discoverability.** Should the parent's README "Language preferences" section be updated immediately to describe both locations, or should this feature's docs live only in the new feature's own PRD until archive? PM decision at PRD stage; brainstorm just flags the question.

**Success looks like**:
- A user can run a single command (`mkdir -p ~/.config/specflow && echo "lang:\n  chat: zh-TW" > ~/.config/specflow/config.yml`, or the path architect picks) once per machine and get zh-TW chat in **every** specflow consumer repo on that machine — no per-repo config file required.
- Existing `.spec-workflow/config.yml` behaviour is unchanged: repos that already have a project-level config continue to work exactly as today; the project-level value wins when both files exist.
- Precedence is documented in the repo `README.md` and is testable via a smoke test that sets up both files with different values and asserts the project-level value is emitted by the hook.
- Default-off (both files absent) is preserved: the hook emits no `LANG_CHAT=` marker; English chat is the baseline — identical to today's behaviour for any user who has not opted in at either level.
- A sanity test in `test/smoke.sh` exercises all four cells of the {project-present, project-absent} × {user-home-present, user-home-absent} matrix and asserts the hook's digest contents match the expected precedence.

**Out of scope**:
- Multiple user-home candidate paths beyond the one chosen at `/specflow:tech`. If the architect picks `~/.config/specflow/config.yml`, then `~/.specflow/config.yml`, `~/.claude/specflow-config.yml`, and `$XDG_CONFIG_HOME`-conditional resolution are all out of scope for v1 — one path, documented, end of story. A second path can be added later if a concrete portability case arises.
- Migrating existing project-level configs to the user-home location. One-way extension only: the hook learns to read a second file; no tooling is shipped to move or symlink existing `.spec-workflow/config.yml` contents to `~/.config/specflow/config.yml`.
- Any new config keys beyond `lang.chat`. The schema remains exactly the parent's (§D9 of `20260419-language-preferences/04-tech.md`): `lang:` block with a `chat:` field, values `zh-TW` or `en`. No `lang.default`, no `artifacts`, no new axes.
- Changing the parent feature's directive semantics, carve-outs, subagent coverage, or the commit-time CJK guardrail. Those requirements (R3–R6, R2 AC2.\*) are frozen; this feature only extends the read path that feeds `LANG_CHAT`.
- User-home config management UX (CLI writer like `specflow config set`, validation tooling, template installer). Users author the YAML by hand in v1, same as the parent's model for `.spec-workflow/config.yml`.
- Cross-machine synchronisation of the user-home file (dotfile-manager integration, cloud sync). Out of scope: the file is local to the machine, same as any other dotfile.

**UI involved?**: no
