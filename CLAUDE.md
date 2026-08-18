# MPCNC post processor — working rules

A Fusion 360 post for GRBL / Marlin / RepRap hobby CNC. The deliverable is
`MPCNC_v4.0_Beta3.cps`; everything else in the repo supports it.

## Read `docs/plan.md` first

**It is the only file that says what is next.** Start at its *Checkpoint*, and reach everything else from
there — `docs/findings.md` when a specific finding or test row is in play, `docs/design.md` when changing
frame, Z-reference or ordering behaviour, `docs/integration.md` when running the post against a job file
or asking what a run may claim.

Each of those files states its own rules at its foot. Follow them when you edit it.

## Changing the post

- **Show a diff for every proposed code change** — every time, including one-liners, and whether or not it
  is applied immediately. Proposing and applying are separate steps.
- **Never propose a verification that needs a non-GRBL controller, a sender console or a dry run.** Settle
  firmware questions from the firmware's own source and changelog, and cite file and version.
- `node --check` runs itself on every edit. **Nothing gates the documents** — every rule in them is
  enforced in the diff, by a person.

## Findings ship with the code

Update the row in `docs/findings.md` **before the commit lands** — not after every intermediate edit, but
once the change is settled, so the commit carries the code and its row together. The procedure is at the
foot of that file. Don't ask whether to add the row — add it.

**No register lives outside the tree:** too unfinished to commit is too unfinished to hold the only copy of
an open finding.

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
- **`Personal.cps`** — a git-excluded copy of the post, **superseded and dead**. The Personal-licence
  simulation is now a `visible: false` property inside the post itself; `design.md` says why, and
  `integration.md` §6.5 is the machinery. Do not revive the copy.
- **`Assessment/`** — the analysis this plan came from, dated 2026-08-13. Read it for evidence, never for
  where things live: its file pointers predate the document consolidation.
