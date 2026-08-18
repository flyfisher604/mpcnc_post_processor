# Plan — what is next

The only file that says **what is next, in what order, and what is parked.** Nothing else lives
here. Findings and tests are `findings.md`; why the post behaves as it does is `design.md`; how a
run against a job file is performed and what it may claim is `integration.md`; what has already
happened is `git log`.

**This file states no count, tally, branch position or measurement.** Every one it used to carry
went stale between the work landing and someone remembering to edit it. Where a number matters,
the file that computes it is named instead.

## Checkpoint

**Next: Step 6.** Step W is done: the audit ran, `PV-9` closed on it, and the class it bounded is now
a verdict beside every `writeWarning()` call — `grep -n "// TWIN"`. The finding the audit found while
closing another has closed too, so **`findings.md` §2 is empty**.

**No live risk stands.** `HR-6 (B)` was the last and it is answered — `findings.md` §2, and `PV-14`
is the row.

**Nothing is pushed.** No work since the `Assessment` merge is on `origin`. Pushing is the
author's call, not a session's.

**No controller access.** Firmware questions are settled from firmware source, citing file and
version — never from a sender console, a dry run or a non-GRBL controller.

---

## What is left, in order

| | Item | Blocked on |
|---|---|---|
| **6** | Clarity | — |
| **7** | Documents, once | 6 |

## Step 6 — Clarity

- **Re-measure before restructuring.** `validateJob()` and the property block were both named as
  too long, and Steps 2–4 have cut into each since. They may not need the work; the numbers this
  file used to quote were stale every time they were read.
- **The comment-only lines stay, and there are hundreds.** Every one of the sharpest findings in
  the assessment came out of a comment the post wrote about itself. **One of them was wrong** —
  corrected by `PR-19` — which is an argument for reading them, not for thinning them.

## Step 7 — Documents, once

The guides are off-limits during code changes, so they are done here, together: per-step means
rewriting `guide-pro.md` three times.

| Document | What falls due |
|---|---|
| `design.md` | Believed current — **re-read before assuming it** |
| `property-reference.md` | Regenerate, and **recount**: every count it has ever stated was wrong. `mapRapidsTestPersonalLicence` is `visible: false` and belongs in no user document |
| `guide-pro.md` | The **operator's** obligations, stated explicitly — every work offset set before the job, one clearance clearing every fixture, machine homed. F360 states this nowhere and the emitted g-code depends on it. And plainly what is verified and what is not |
| `guide-hobbyist.md` | Flow 1's end-of-file behaviour; the Marlin do-not-home rule and the minimum Marlin version; **mid-job indexing** — the jog modes as a supported workflow, with the sender condition on GRBL and the panel condition on Marlin |
| `README.md` | Feature list, and the hobbyist/professional split |

## Parked, and on what

| Parked | Waiting on |
|---|---|
| Group 9 coolant reduction | a coolant persona |
| Group 8 audit | laser detail — power scaling, dynamic power, enable sequencing, air assist. `findings.md` §6 |
| Group 10 (Duet) fold | handed to `PR-13`, which closed without it |
| A status line in `guide-pro.md` | **deferred by the author 2026-08-13** |

`findings.md` §6 holds unbuilt design and the questions under it. Nothing there is scheduled
until it appears in the table above.

---

## Done

Phase C · Step 0 · Steps 1.1, 1.2, 1.3, 2, 3, 4, 5 · F2–F7 · Step V.

**What each one did is its commits** — `git log --grep` by step or finding id — and what each one
left is a row in `findings.md`. Two are worth knowing without looking them up: **Step 2** retired
the spoilboard base, which was the one thing the assessment called over-built, and **Step V** is
where the post stopped being walked and started being *run*, against Autodesk's own engine —
`integration.md` is that machinery and the bounds on what a run may claim.

*`Assessment/00-08` and `10` are the analysis this plan came from, dated 2026-08-13. Read them for
evidence, never for where things live — their file pointers predate the consolidation.*

---

## How to write in this file

**Four rules. If a change to this file broke one of them, the change is wrong.**

1. **Nothing derived.** If a fact can be read from git, `findings.md`, `integration.md`,
   `design.md` or the post itself, **name the source instead of copying the fact.** Counts,
   tallies, branch positions and line measurements are how this file went stale; a pointer
   cannot.
2. **Completion shrinks the document.** A step that closes must leave this file *shorter* than
   it was while open. If closing it made the file longer, it was written wrong.
3. **An open step carries no history.** State the goal, where, the change, and how you will know
   it is done. Not how the project arrived at it, not what an earlier version said, not what was
   rejected on the way — that is `design.md`'s job, or git's.
4. **A closed step is its name in *Done*.** A clause beside it only where a later reader would
   otherwise have to go looking to know the project changed shape.

**Never point two ways.** A pointer is valid in one direction only: from here toward the file
that owns the work. `findings.md` owns findings and tests and must not point back here.
