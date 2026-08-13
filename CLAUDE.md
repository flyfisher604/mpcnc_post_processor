# MPCNC post processor — working rules

A Fusion 360 post for GRBL / Marlin / RepRap hobby CNC. The deliverable is
`MPCNC_v4.0_Beta2.cps`; everything else in the repo supports it.

## Read in this order

1. **`docs/plan.md` → *Checkpoint*** — always, first. The only place that says what is next.
   `/checkpoint` reads it and reports in ten lines.
2. **`docs/conventions.md`** — when writing code. The guards, the property and dialog rules, how to run
   a test, and the harness method and its hard-won lessons.
3. **`docs/design.md`** — only when changing frame, Z-reference or ordering behaviour. Why the post emits
   what it does, and the firmware facts behind it.
4. **`docs/HReview.md`** — only when a specific finding or test row is in play. **`docs/PReview.md`** is the
   professional register: the seven open `HR-` ids, §3.1's unposted jobs, and the design backlog in §6.

Do not read or search files under `./Test/` unless explicitly asked.

## Changing the post

- **Show a diff for every proposed code change** — every time, including one-liners, and whether or not it
  is applied immediately. Proposing and applying are separate steps.
- **Never propose a verification that needs a non-GRBL controller, a sender console or a dry run.** Settle
  firmware questions from the firmware's own source and changelog, and cite file and version.
- `node --check` runs itself on every edit. **Nothing gates the documents** — every rule in them is
  enforced in the diff, by a person.

## Registers ship with the code

Update the register **before the commit lands** — not after every intermediate edit, but once the change
is settled, so the commit carries the code and its row together. Hobbyist → `docs/HReview.md`. A
**professional** finding (multi-WCS, spoilboard base, tool changes, Manual NC, dialog) stays in the
register it was filed in — a row split across two files is how seven ids went stale. And **no register
lives outside the tree**: too unfinished to commit is too unfinished to hold the only copy of an open
finding. **`/close-finding <id>` runs the procedure.** Don't ask whether to add the row — add it.

## Commits

Every commit carries a descriptive message — no exceptions, no placeholders, however mechanical the
change. The message describes **the code change and why**; it never narrates doc bookkeeping.

A commit that acts on a registered finding **leads its subject with the id** — `CR-11: …`, `HB-4: …` — so
the work on a finding is findable with `git log --grep` and visible in a one-line log. A commit that only
builds tooling around a register does not take a prefix, however much it mentions one.

## Before writing to memory

Ask which driving doc should hold the fact instead; if one should, **propose that edit and write no
memory**. If none should, **say what you would write and why, and get agreement first** — never as a
side effect of another task. Repo docs are reviewed in a diff; memories go stale unseen, and twelve did.

## Leave alone

- **The user guides** — `README.md` and `docs/guide-hobbyist.md` / `guide-pro.md` /
  `property-reference.md`. Not touched during code changes, only when asked — and **when they fall behind
  the post, that is the author's call to make**, not something a session detects or acts on.
- **`Personal.cps`** — a git-excluded test harness, not part of the post.
