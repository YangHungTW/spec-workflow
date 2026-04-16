# qa-tester — memory index

<!-- One line per memory. Format:
- [Title](file.md) — one-line hook
-->

- [Sandbox-HOME preflight for bash CLI verify](sandbox-home-preflight-pattern.md) — When verifying a bash CLI that reads `$HOME`, always build a `mktemp -d` sandbox and export `HOME=<sandbox>/home` before the first invocation. Hash the tree before/after dry-run to confirm zero mutation.
