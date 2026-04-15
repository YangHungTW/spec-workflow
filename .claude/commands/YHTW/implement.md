---
description: Developer executes a task. Usage: /YHTW:implement <slug> [task-id]
---

1. Read `06-tasks.md`. Select task: the one specified, or the first unchecked task with all dependencies satisfied.
2. Invoke **YHTW-developer** subagent for that single task.
3. Developer implements, runs acceptance check, checks off the box, logs to STATUS.
4. Stop after one task. Report: which task was done, what's next unchecked.
5. If all tasks checked, update STATUS: check `[x] implement`. Tell user next is `/YHTW:gap-check <slug>`.
