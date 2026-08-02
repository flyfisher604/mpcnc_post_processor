# MPCNC post processor — working rules

A Fusion 360 post for GRBL / Marlin / RepRap hobby CNC. The deliverable is
`MPCNC_v4.0_Beta2.cps`; everything else in the repo supports it.

## Read in this order

1. **`docs/plan.md` → *Checkpoint*** — always, first. The only place that says what is next.
   `/checkpoint` reads it and reports in ten lines.
2. **`docs/conventions.md`** — when writing code. The models the code assumes, the guards, the property
   and dialog rules, how to run a test, and the harness method and its hard-won lessons.
3. **`docs/HReview.md` / `docs/PReview.md`** — only when a specific finding or test row is in play.

Do not read or search files under `./Test/` unless explicitly asked.

## Changing the post

- **Show a diff for every proposed code change** — every time, including one-liners, and whether or not it
  is applied immediately. Proposing and applying are separate steps.
- **Never propose a verification that needs a non-GRBL controller, a sender console or a dry run.** Settle
  firmware questions from the firmware's own source and changelog, and cite file and version.
- `node --check` runs itself on every edit, and the document contracts are re-counted at commit — see
  `docs/conventions.md` → *Tooling that ships with the repo*. A fresh clone must arm the second one.

## Registers ship with the code

Update the register **before the commit lands** — not after every intermediate edit, but once the change
is settled, so the commit carries the code and its row together. Hobbyist → `docs/HReview.md`;
professional (multi-WCS, spoilboard base, tool changes, Manual NC, dialog) → `docs/PReview.md`.
**`/close-finding <id>` runs the procedure.** Don't ask whether to add the row — add it.

## Commits

Every commit carries a descriptive message — no exceptions, no placeholders, however mechanical the
change. The message describes **the code change and why**; it never narrates doc bookkeeping.

## Before writing to memory

Ask which driving doc should hold the fact instead; if one should, **propose that edit and write no
memory**. If none should, **say what you would write and why, and get agreement first** — never as a
side effect of another task. Repo docs are reviewed in a diff; memories go stale unseen, and twelve did.

## Leave alone

- **`README.md`** — not touched during code changes, only when asked. Its `doc-sync` marker records the
  ref it last synced to; refresh from `git diff <ref>..HEAD -- MPCNC_v4.0_Beta2.cps`, then re-bump it.
- **`Personal.cps`** — a git-excluded test harness, not part of the post.
