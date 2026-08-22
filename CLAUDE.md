# MPCNC post processor — working rules

A Fusion 360 post for GRBL / Marlin / RepRap hobby CNC. The deliverable is
`MPCNC_v4.1.1_Beta3.cps`; everything else in the repo supports it.

## Read only what the task needs

| The task | Read |
|---|---|
| A code change against a registered finding | **that row in `docs/findings.md`**, then the code |
| A code change with no finding yet | the code; register the finding when the change is settled |
| What is next, or what is parked | `docs/plan.md` — the only file that says |
| Changing frame, Z-reference or ordering behaviour | `docs/design.md` |
| Running the post against a job file, or what a run may claim | `docs/integration.md` |
| What already happened, and why | `git log`, `git show <ref>` |

**Do not read the whole set before a change.** `findings.md`, `design.md` and `integration.md` are
370KB between them; a session that opens all four to fix a one-liner has spent more than the fix.
`findings.md`, `plan.md` and `integration.md` state their own rules at their foot — read those when
you are editing that file, not when you are reading it.

## Changing the post

- **Show the diff before applying it** — every time, including one-liners. Proposing and applying are
  separate steps. Count the call sites in the code before believing a diff is complete.
- **Never propose a verification that needs a non-GRBL controller, a sender console or a dry run.**
  There is no hardware and no machine time. Settle firmware questions from the firmware's own source
  and changelog, and cite file and version.
- `node --check` runs itself on every edit. **Nothing else gates the documents** — every rule in them
  is enforced in the diff, by a person, so a rule that cannot be checked by reading the diff does not
  belong in them.

## Findings ship with the code

Register the finding and close its row **in the commit that carries the fix** — not after every
intermediate edit, once the change is settled. The four-step procedure is at the foot of
`docs/findings.md`; don't ask whether to add the row, add it.

Two things that procedure is deliberately *not*: a test row is written **only where a run or a walk
would distinguish the fix** — otherwise the Resolution cell carries a clause instead — and **no count
in that file is written by hand**. `node tools/register-tally.js --check` owns the tallies.

**No register lives outside the tree:** too unfinished to commit is too unfinished to hold the only
copy of an open finding.

## Commits

Every commit carries a descriptive message. The message describes **the code change and why**; it
never narrates doc bookkeeping.

A commit acting on a registered finding **leads its subject with the id** — `CR-11: …`, `HB-4: …` —
so `git log --grep` finds the work. A commit that only builds tooling around a register takes no
prefix.

**Land the code and its rows together.** A doc-only follow-up commit re-truing what the last one
changed means the rules asked for state that has to be maintained twice; say so rather than paying it
again.

## Before writing to memory

Ask which driving doc should hold the fact instead; if one should, **propose that edit and write no
memory**. If none should, **say what you would write and why, and get agreement first** — never as a
side effect of another task. Repo docs are reviewed in a diff; memories go stale unseen.

## Leave alone

- **The user guides** — `README.md` and `docs/guide-hobbyist.md` / `guide-pro.md` /
  `property-reference.md`. Not touched during code changes, only when asked — and **when they fall
  behind the post, that is the author's call to make**, not something a session detects or acts on.
- **`Personal.cps`** — a git-excluded copy of the post, superseded and dead. The Personal-licence
  simulation is a `visible: false` property inside the post itself (`design.md` says why,
  `integration.md` §6.5 is the machinery). Do not revive the copy.
- **`Assessment/`** — the 2026-08-13 analysis this plan came from; `Assessment/README.md` is the
  index. Read it for evidence and for what the post is *for*, **never for where things live** — its
  file pointers predate two consolidations and a version. Four pages remain of ten, so a reference
  to a retired one is a dead pointer; the index says where each one's conclusions went.
