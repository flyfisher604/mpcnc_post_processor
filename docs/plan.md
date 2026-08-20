# Plan — what is next

The only file that says **what is next, in what order, and what is parked.** Nothing else lives
here. Findings and tests are `findings.md`; why the post behaves as it does is `design.md`; how a
run against a job file is performed and what it may claim is `integration.md`; what has already
happened is `git log`.

**This file states no count, tally, branch position or measurement.** Every one it used to carry
went stale between the work landing and someone remembering to edit it. Where a number matters,
the file that computes it is named instead.

## Checkpoint

**The tree is Beta 3.** The deliverable is `MPCNC_v4.0_Beta3.cps`, and what the beta contains is
`release-notes-v4.0-beta3.md`. **Next: Step 8 — cut the release.**

Step 7 is done: the four user documents describe the post as it now is, and `guide-pro.md` states
plainly what is not verified. **What is open stands in `findings.md` §2**, which owns that count.

**Issue 16 is in flight, on branch `Issue16`** — the two Marlin output modes the tracker asked for,
laser first and the spindle after it. `findings.md` `GH-16a` and `GH-16b` own the work; `GH-16c` is what
it turned up and left.

**No live risk stands.** `HR-6 (B)` was the last and it is answered — `findings.md` §2, and `PV-14`
is the row.

**What the beta still owes is `findings.md` §7.** Its first item is a file posted from Fusion, which
no session can supply.

**Nothing is pushed.** No work since the `Assessment` merge is on `origin`. Pushing is the
author's call, not a session's.

**No controller access.** Firmware questions are settled from firmware source, citing file and
version — never from a sender console, a dry run or a non-GRBL controller.

---

## What is left, in order

| | Item | Blocked on |
|---|---|---|
| **8** | Cut the Beta 3 release | the author — `findings.md` §7's first item needs Fusion |

**`validateJob()` and the property block were never restructured** — Step 6 measured both and left
them. Neither is short; whether either is too long is a judgement no measurement settles, and it is
the author's to make against the file as it now reads.

## Step 8 — Cut the Beta 3 release

- **`README.md` still calls Beta 2 current** and names the Beta 2 file in its install steps. A
  guide is the author's to change, and this one now contradicts the tree.
- **The tag**, once §7 is answered or accepted as outstanding at the beta.
- **§7's first item** — a file posted from Fusion, which most of *Invalidated by landed fixes* in
  `findings.md` §5 also waits on.

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

Phase C · Step 0 · Steps 1.1, 1.2, 1.3, 2, 3, 4, 5, 6, 7 · F2–F7 · Step V.

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
