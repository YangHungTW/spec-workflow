# Scaff preflight gate

This file defines the preflight gate that runs at the start of every scaff command. The gate checks that `.specaffold/config.yml` exists in the current working directory, which is the required sentinel confirming that the user has run `/scaff-init` and that the project is initialised. The runtime CWD is the resolution anchor: the check and the refusal message both use `$(pwd)` to report the exact directory that was missing the config. If the config is absent, recovery is always to run `/scaff-init` in the project root. When executing any scaff command, execute the fenced bash block below before invoking any sub-agent or taking any side effect.

```bash
# === SCAFF PREFLIGHT — DO NOT INLINE OR DUPLICATE ===
if [ ! -f ".specaffold/config.yml" ]; then
  printf 'REFUSED:PREFLIGHT — .specaffold/config.yml not found in %s; run /scaff-init first\n' "$(pwd)" >&2
  exit 70
fi
# === END SCAFF PREFLIGHT ===
```

If the block exits non-zero, abort the command immediately with no side effects; print the refusal line verbatim and do not invoke any sub-agent.
