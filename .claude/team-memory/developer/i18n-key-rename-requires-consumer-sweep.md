## Rule

When renaming an i18n key (the string argument to `t()` / `i18n.t()`), the TypeScript compiler does NOT flag stale consumers — `t()` accepts an arbitrary string. Every key rename MUST be paired with a full-repo grep at task-authoring time and a wave-close assertion that the old key returns zero hits.

## Why

i18n key identifiers are typically untyped strings in React codebases:

```ts
t("palette.group.specflow")  // compiles forever, even if the key is gone
```

The compiler has no visibility into the JSON bundle's key space. If the key is renamed in the bundle but a consumer call site still references the old name, `t()` returns either an empty string, the literal key, or a hard-to-trace fallback depending on the i18n library — silently at runtime.

Typed i18n key enums (generated from the JSON bundle at build time) would eliminate this class of error by making `t()` arguments compiler-checked. In the absence of that infrastructure, grep is the only discipline.

## How to apply

1. When the rename task scope includes an i18n key rename (not just a value rewrite), the **same task or the next task in the same wave** MUST update every consumer. Express this with an explicit `Depends on:` field if the bundle rename and consumer update are split across tasks.
2. At task-authoring time (TPM or Developer), run `grep -rn '<old-key>' src/` before writing the task scope to enumerate every consumer. The grep output IS the task's Scope.
3. Add a wave-close grep assertion that `<old-key>` returns zero hits in both production source and tests. Put this in the wave's structural gate (e.g. T16 grep assertion).
4. Don't mix i18n key renames with value-only edits in the same task — the rename has consumer-side obligations that value edits don't.
5. If the codebase gains typed i18n keys in the future, retire this manual discipline.

## Example

In `20260421-rename-flow-monitor` the D5 decision was to rename `palette.group.specflow` → `palette.group.scaff`. The plan split this across T9 (bundle rename, both `en.json` and `zh-TW.json`) and T12 (consumer test rename, `CommandPalette.test.tsx` asserts on the key). T12 had an explicit `Depends on: T9` to serialise within W2b, ensuring the key existed before its consumer ran. The wave-close T16 structural gate ran `grep -rn "palette.group.specflow" flow-monitor/src/` and required zero hits — catching any consumer the task scope missed. No runtime drift landed.
