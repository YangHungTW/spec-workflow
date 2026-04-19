# Flow Monitor

Native macOS desktop application for monitoring multiple parallel specflow
sessions across one or more git repositories. Read-only dashboard (B1 scope);
control plane is a separate follow-up feature (B2).

## Status

In active development. See `.spec-workflow/features/20260419-flow-monitor/`
for full specs.

## Build

```sh
cd flow-monitor
npm install
npm run tauri build
```

Output: `src-tauri/target/release/bundle/dmg/Flow Monitor_*.dmg`
