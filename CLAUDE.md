# MPCNC post processor — working rules

A Fusion 360 post for GRBL / Marlin / RepRap hobby CNC. The deliverable is
`MPCNC_v4.0_Beta2.cps`; everything else in the repo supports it.

## Read in this order

1. **`docs/plan.md` → *Checkpoint*** — always, first. The only place that says what is next.
2. **`docs/conventions.md`** — when writing code. The models the code assumes, the guards, the property
   and dialog rules, how to run a test, and the harness method and its hard-won lessons.
3. **`docs/HReview.md` / `docs/PReview.md`** — only when a specific finding or test row is in play.

Do not read or search files under `./Test/` unless explicitly asked.

## Changing the post

- **Show a diff for every proposed code change** — every time, including one-liners, and whether or not it
  is applied immediately. Proposing and applying are separate steps.
- **Run `node --check MPCNC_v4.0_Beta2.cps` after every edit.**
- **Never propose a verification that needs a non-GRBL controller, a sender console or a dry run.** Settle
  firmware questions from the firmware's own source and changelog, and cite file and version.

## Registers ship with the code

Update the register **before the commit lands**, and in any case before moving on to a new issue or task.
Not after every intermediate edit — once the change is settled. The commit then carries the code and its
register row together. Hobbyist behaviour → `docs/HReview.md`; professional (multi-WCS, spoilboard base,
tool changes, Manual NC, dialog) → `docs/PReview.md`. Two halves, both required:

- **Add** the Do→Get row: exact dialog settings, an exact expected g-code block, and a Pass line naming
  the discriminator token — often an *absence*. Cover both branches of any new condition, the one that
  emits and the one that suppresses. Flag any `PASS` row whose saved `.gcode` the change invalidates.
- **Retire** on close: when a finding reaches FIXED or closed-by-design, delete its long form and leave
  the register row. `git show <commit>` holds the buggy code, the diagnosis and the diff. Long form is a
  promissory note, justified only while the work is unbuilt.

Don't ask whether to add the row — add it.

## Commits

Every commit carries a descriptive message — no exceptions, no placeholders, however mechanical the
change. The message describes **the code change and why**; it never narrates doc bookkeeping.

## Leave alone

- **`README.md`** — not touched during code changes, only when asked. Its `doc-sync` marker records the
  ref it last synced to; refresh from `git diff <ref>..HEAD -- MPCNC_v4.0_Beta2.cps`, then re-bump it.
- **`Personal.cps`** — a git-excluded test harness, not part of the post.
