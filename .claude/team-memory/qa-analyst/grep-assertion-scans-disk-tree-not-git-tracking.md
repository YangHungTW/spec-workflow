## Rule

Forbidden-literal grep assertions that scan the working tree (e.g. `grep -rn` or `grep -rlE`) also see gitignored build output, editor swap files, and untracked scratch; prefer `git ls-files | xargs grep -l` (tracks only version-controlled files) or require a clean working tree before the assertion runs.

## Why

`test/t_grep_allowlist.sh` scans the working tree with `grep -rlE "specflow|spec-workflow" . --exclude-dir=.git`. This matches:

- Gitignored build artefacts like `flow-monitor/dist/assets/index-*.js` (Rollup/Vite bundles can contain legacy brand strings even after source is clean)
- Editor swap files (`.swp`, `#file#`)
- Local scratch and uncommitted experiments

When the assertion flags a bundled JS file, the operator's reflex is to add `flow-monitor/dist/**` to the allow-list. That "fixes" the red but masks the real problem: the scanner should not be looking inside untracked build output. The allow-list grows to absorb transient disk state, silently widening the carve-out — and a future clean build may still contain post-rename content, making the exemption stale-but-harmless yet confusing.

## How to apply

1. When authoring a forbidden-literal assertion, prefer `git ls-files -z | xargs -0 grep -l` over `grep -rl .`. This scans only tracked content — gitignored `dist/`, `target/`, `node_modules/` never hit.
2. If the assertion must scan disk (e.g. to catch files the author forgot to `git add`), wrap it: `git clean -ndx` first to enumerate what's present but untracked, then either fail on untracked or explicitly `git clean -fdx` before the scan.
3. Treat "build artefact in allow-list" as a code smell. The right fix is usually a `.gitignore` entry or a clean-build prerequisite, not a permanent allow-list line.
4. When reviewing an allow-list diff, flag any entry that points at a gitignored path — the exemption is inherently transient (artefact regeneration can change content) and adds nothing durable.

## Example

In `20260421-rename-flow-monitor` T16, the allow-list grew to include `flow-monitor/dist/**`. Root cause: `t_grep_allowlist.sh` scanned disk and hit `flow-monitor/dist/assets/index-B3lnbT4G.js`, a Vite bundle containing legacy brand strings from a pre-rename local build. The correct remediation is either (a) run `npm run clean && rm -rf flow-monitor/dist` before the assertion, or (b) migrate the assertion to `git ls-files`. The allow-list entry is a workaround, not a fix.
