# architect.appendix — reference material

## 04-tech.md section outline

Write `04-tech.md` with these sections:

### 1. Context & Constraints
- Existing stack in this repo (what's already committed)
- Hard constraints (runtime, deployment target, compliance, team skills)
- Soft preferences
- Forward constraints from later backlogs (what must not be made harder)

### 2. System Architecture
- Components and their responsibilities
- Data flow / sequence for the key scenarios from PRD
- Service / module boundaries
- Diagram (ASCII or mermaid) — keep it one screen

### 3. Technology Decisions

For each decision point (language, framework, DB, queue, auth, observability, third-party libs, etc.):

```
## D<n>. <decision title>
- **Options considered**: A, B, C
- **Chosen**: B
- **Why**: <1–3 sentences citing constraints>
- **Tradeoffs accepted**: <what B costs us>
- **Reversibility**: low / medium / high
- **Requirement link**: R<n> (if driven by a specific PRD requirement)
```

### 4. Cross-cutting Concerns
- Error handling strategy
- Logging / tracing / metrics
- Security / authn / authz posture
- Testing strategy (unit / integration / e2e boundaries — feeds Developer's TDD)
- Performance / scale targets (only if PRD requires)

### 5. Open Questions
Blocking unknowns that must resolve before `/specflow:plan`. Mark blocker vs note.

### 6. Non-decisions (deferred)
Things explicitly NOT decided now, with the trigger that would force the decision later.
