# Plan — what is next

The only file that says **what is next, in what order, and what is parked.** Nothing else lives
here. Findings and tests are `findings.md`; why the post behaves as it does is `design.md`; how a
run against a job file is performed and what it may claim is `integration.md`; what has already
happened is `git log`.

**This file states no count, tally, branch position or measurement.** Every one it used to carry
went stale between the work landing and someone remembering to edit it. Where a number matters,
the file that computes it is named instead.

## Checkpoint

**The tree is v4.1.1 Beta 3 on `PropertyReduce`; `v4.1_Beta3` is tagged and on `origin`.** The
deliverable is now `MPCNC_v4.1.1_Beta3.cps` — Step 9 renamed it — and what the **v4.1 Beta 3** release
contains is `release-notes-v4.1-beta3.md`.
**Next: the release page, which is the last of Step 8, and then merging Step 9.**

Step 7 is done: the four user documents describe the post as it now is, and `guide-pro.md` states
plainly what is not verified. **What is open stands in `findings.md` §2**, which owns that count.

**Issue 16 is answered, and it is what v4.1 Beta 3 is** — `findings.md` `GH-16a` to `GH-16d`.

**No live risk stands.** `HR-6 (B)` was the last and it is answered — `findings.md` §2, and `PV-14`
is the row.

**§7 is accepted as outstanding at the beta**, which is what let the tag be cut. Its first item is a
file posted from Fusion, which no session can supply; the release notes and the tag both say so.

**`master` and `v4.1_Beta3` are on `origin`.** What is not is the release page.

**No controller access.** Firmware questions are settled from firmware source, citing file and
version — never from a sender console, a dry run or a non-GRBL controller.

---

## What is left, in order

| | Item | Blocked on |
|---|---|---|
| **8** | Publish the v4.1 Beta 3 release page | an authenticated `gh` — the merge, the tag and the push are done |
| **9** | Merge `PropertyReduce`, and decide what the four user documents owe it | the author — the code and the register are done, and the guides are the author's call |

**`validateJob()` and the property block were never restructured** — Step 6 measured both and left
them. Neither is short; whether either is too long is a judgement no measurement settles, and it is
the author's to make against the file as it now reads.

## Step 8 — Publish the release page

**The asset is `MPCNC_v4.1_Beta3.cps` itself, under exactly that name.** Both announcements link
`releases/download/<tag>/MPCNC_v4.1_Beta3.cps`, so a zip uploaded there answers the download with a
404. `announce-v4.1-beta3.md` is the line that fixes the name.

**Step 9 renamed the deliverable and does not block this.** The asset is the *tagged* file, not the
working tree's: `git show v4.1_Beta3:MPCNC_v4.1_Beta3.cps > MPCNC_v4.1_Beta3.cps` produces it under
the name the download expects, from any branch. Do not upload the working tree's `.cps` — on or after
Step 9 it is a different version under a different name.

## Step 9 — The property reduction

**Done on `PropertyReduce`, unmerged.** The dialog went from **65 fields to 57** across six folds —
`findings.md` `PC-1` to `PC-6`, each naming the configuration it costs — and the deliverable is
`MPCNC_v4.1.1_Beta3.cps`. The suite is green and `integration.md` §6.2 carries the re-measured
coverage.

**What it does not touch is the four user documents**, which are the author's to move: `README.md`
and `guide-hobbyist.md` / `guide-pro.md` / `property-reference.md` still describe the 65-field dialog,
and `property-reference.md` opens by stating that count. Nothing detects that for the author, which is
why it is a step here rather than a finding.

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

*`Assessment/` is the analysis this plan came from, dated 2026-08-13, and its own `README.md` is the
index. Read it for evidence, never for where things live.*

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
