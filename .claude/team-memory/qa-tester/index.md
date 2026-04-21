# qa-tester — memory index

<!-- One line per memory. Format:
- [Title](file.md) — one-line hook
-->

_No memories yet._
- [Validate artefact filename is 08-validate.md, not 08-verify.md](validate-artefact-filename-is-08-validate-not-08-verify.md) — QA-tester writes `08-validate.md` and never flips `[x] validate`; both are orchestrator responsibilities. Observed: `20260420-flow-monitor-control-plane` qa-tester wrote 08-verify.md and pre-ticked box; orchestrator had to rename + reconcile.
- [PRD AC wording superseded by tech decision → PARTIAL + D-id](prd-ac-wording-superseded-by-tech-decision.md) — When an AC's literal wording is unmet but a tech D-id deliberately supersedes it, mark PARTIAL and cite the superseding D-id; never silent-PASS or hard-FAIL on architect-approved deviations. Source: 20260421-rename-to-specaffold AC13 vs tech D3.
