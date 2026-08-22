# Plan — what is next

The only file that says **what is next, in what order, and what is parked.** Findings and tests are
`findings.md`; why the post behaves as it does is `design.md`; how a run against a job file is
performed and what it may claim is `integration.md`; what has already happened is `git log`.

## Checkpoint

**Next: the release page, which is the last of Step 8.** Nothing else is scheduled.

Branch, tag and push positions are `git status` and `git log`; what is open is `findings.md` §2;
what the **v4.1 Beta 3** release contains is `release-notes-v4.1-beta3.md`.

## What is left, in order

| | Item | Blocked on |
|---|---|---|
| **8** | Publish the v4.1 Beta 3 release page | an authenticated `gh` — the merge, the tag and the push are done |

**`validateJob()` and the property block were never restructured** — Step 6 measured both and left
them. Whether either is too long is a judgement no measurement settles, and it is the author's to
make against the file as it now reads.

## Step 8 — Publish the release page

**The asset is `MPCNC_v4.1_Beta3.cps` itself, under exactly that name.** Both announcements link
`releases/download/<tag>/MPCNC_v4.1_Beta3.cps`, so a zip uploaded there answers the download with a
404.

**Upload the tagged file, not the working tree's** — Step 9 renamed the deliverable, so on or after
it the tree holds a different version under a different name:

```
git show v4.1_Beta3:MPCNC_v4.1_Beta3.cps > MPCNC_v4.1_Beta3.cps
```

## Parked, and on what

| Parked | Waiting on |
|---|---|
| Group 9 coolant reduction | a coolant persona |
| Group 8 audit | laser detail — power scaling, dynamic power, enable sequencing, air assist. `findings.md` §6 |
| Group 10 (Duet) fold | handed to `PR-13`, which closed without it |
| A status line in `guide-pro.md` | **deferred by the author 2026-08-13** |

`findings.md` §6 holds unbuilt design and the questions under it. Nothing there is scheduled until it
appears in the table above.

## Done

Phase C · Step 0 · Steps 1.1, 1.2, 1.3, 2, 3, 4, 5, 6, 7, 9 · F2–F7 · Step V.

**What each one did is its commits** — `git log --grep` by step or finding id. Two are worth knowing
without looking them up: **Step 2** retired the spoilboard base, the one thing the assessment called
over-built, and **Step V** is where the post stopped being walked and started being *run*, against
Autodesk's own engine — `integration.md` is that machinery and the bounds on what a run may claim.

---

## How to write in this file

**Four rules. If a change to this file broke one of them, the change is wrong.**

1. **Nothing derived.** If a fact can be read from git, `findings.md`, `integration.md`, `design.md`
   or the post itself, **name the source instead of copying the fact.** No count, tally, branch
   position or line measurement is written here. Every one this file used to carry went stale
   between the work landing and someone remembering to edit it.
2. **Completion shrinks the document.** A step that closes must leave this file *shorter* than it
   was while open.
3. **An open step carries no history.** State the goal, where, the change, and how you will know it
   is done — not how the project arrived at it, and not what was rejected on the way.
4. **A closed step is its name in *Done*.** A clause beside it only where a later reader would
   otherwise have to go looking to know the project changed shape.

**Never point two ways.** A pointer is valid in one direction only: from here toward the file that
owns the work.
