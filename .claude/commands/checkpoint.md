---
description: Orient at the start of a session — what is next, and is anything half-done
allowed-tools: Read, Bash(git status *), Bash(git log *), Bash(node docs/doc-sync.js)
---

Orient me for this session. Read `docs/plan.md` → *Checkpoint* — it is the only place that says what is
next — then run `git status`, `git log --oneline -5`, and `node docs/doc-sync.js`.

Report in **ten lines or fewer**:

- the branch, and whether the tree is clean or something is half-done
- the next item from *What is left, in order*, and the single thing that has to happen first
- any live risk the checkpoint names
- whether the property tables have fallen behind the post, if `doc-sync.js` says so

Do not summarise the whole checkpoint back to me, do not restate the phase status, and do not start the
work. If the checkpoint and the git state disagree — the checkpoint claims a clean baseline but the tree
is dirty, or it names a commit that is not the latest to touch the `.cps` — say so plainly. A stale
checkpoint is the one thing this command exists to catch.
