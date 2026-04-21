---
name: Validate artefact filename is 08-validate.md, not 08-verify.md
description: QA-tester writes `08-validate.md`, not `08-verify.md`, and never flips `[x] validate` — both are orchestrator responsibilities; misnaming or early flip forces reconciliation.
type: feedback
created: 2026-04-21
updated: 2026-04-21
---

## Rule

The QA-tester's output artefact filename is `08-validate.md`, not `08-verify.md`. Additionally, the QA-tester does NOT flip the `[x] validate` checkbox in STATUS.md — that flip is the orchestrator's post-merge bookkeeping action after both tester and analyst axes have landed and the aggregate verdict is recorded. Writing the wrong filename or flipping the box early requires an orchestrator reconciliation pass.

## Why

`20260420-flow-monitor-control-plane` at validate stage: the QA-tester authored `08-verify.md` (old filename from the pre-tier-model contract) and also ticked `[x] validate` in STATUS's stage checklist. The orchestrator had to:

1. Rename the file to `08-validate.md`.
2. Reconcile the prematurely-ticked box (which pointed to the wrong filename).
3. Add the analyst axis output to the renamed file.
4. Log the reconciliation in STATUS Notes.

The drift is a contract violation, not a quality issue — the tester's actual verdict content (16 structural ACs PASS, 15 runtime deferred, structured evidence per AC) was correct. But the filename and the checkbox-flip are part of the tier-model merged-shape contract, not the tester's deliverable scope.

## How to apply

1. QA-tester artefact filename is `08-validate.md`. When in doubt, look at the feature dir listing before authoring — the orchestrator will usually have pre-created the file as a stub, or the pattern from archived features is discoverable.
2. QA-tester writes the tester axis into `08-validate.md` and leaves room for the analyst axis. The analyst writes to the same file (append analyst axis section + consolidated verdict footer).
3. QA-tester does NOT touch STATUS.md's stage checklist. The tester may append a STATUS Notes line describing the tester-axis verdict if useful, but the validate checkbox flip happens after analyst also lands.
4. If the QA-tester is invoked before the analyst, the file is in a partial state (tester axis only, no consolidated verdict) — that is OK. The orchestrator knows the stage is not complete until the analyst also writes.

## Example

From this feature's STATUS 2026-04-21 reconciliation line: "qa-tester wrote wrong filename + prematurely ticked validate box; orchestrator reconciled". One occurrence; memory exists so the second occurrence does not happen.
