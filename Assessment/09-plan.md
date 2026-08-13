# Step 9 — The go-forward path

**Rewritten 2026-08-13.** Third version. The first offered a scope decision; the second
assumed S12 in scope and made testing the critical path; this one incorporates the
author's separation of the multi-part **workflow** (in scope) from the multi-part
**orchestration** (the operator's), plus three firmware corrections that change what the
work actually is.

**Route: prune forward from HEAD.** A reset was considered and rejected in one sentence:
`06-retention.md` verified that every subsystem under suspicion already exists at the
published tag `v4.0_Beta2`, so a reset would discard nine verified fixes, the firmware
knowledge and seventeen simplification commits while leaving the suspected design intact.

Nothing here has been performed. **The decision to adopt any of it is the author's.**

---

## How to use this document

The author asked that the steps *"make it clear exactly the work needed, or provide the
prompt that will identify the changes needed for a particular step."* Every step
therefore carries the same fields:

| Field | What it holds |
|---|---|
| **Goal** | One sentence — the state the step ends in |
| **Why** | The evidence that makes it worth doing, cited |
| **Where** | Files, functions, line numbers as of HEAD `CoverageFixes` |
| **The change** | What gets edited, at a level a diff can be checked against |
| **Done when** | An observable test, not an opinion |
| **Findings** | Register rows opened, closed or re-scoped — `CLAUDE.md` requires the row to ship with the commit |
| **Prompt** | Paste-ready, for a session that has not had this conversation |

**Phase C is the exception**: its items change documents and branches, never the post, so
there is nothing to discover in the source and no prompt is needed. Each says exactly
which file and line to edit.

Line numbers will drift as steps land, so every prompt tells the session to locate by
**symbol and quoted comment text**, and to re-measure before editing.

**How to count lines on this platform.** Every line figure in these documents — the
3,758-line post, the 288-line `validateJob()`, the ~450–500 to delete — is only as good
as the tool that produced it, and one of them was wrong twice. PowerShell's
`Measure-Object -Line` **counts only non-empty lines**: it reported `PReview.md` at 972
where the file is 1,118. Use `(Get-Content $f).Count`, or `git diff --stat`, and treat any
figure here that came out suspiciously round as unverified.

### The rule that governs all of it

**`CLAUDE.md`: show a diff for every proposed code change, every time, including
one-liners. Proposing and applying are separate steps.** Every prompt below ends by
requiring a diff first. **None of them authorises an edit.**

### Preamble to prepend to any step prompt

```
Read docs/plan.md (Checkpoint) and docs/conventions.md first. This repo's rules
override your defaults: show a diff for every code change before applying it;
never propose a verification that needs a non-GRBL controller, a sender console
or a dry run; do not read or search under ./Test/; a finding row ships with the
commit that acts on it; leave README.md and the docs/guide-*.md files alone.

Context: Assessment/ holds an over-engineering review. Read Assessment/STATUS.md,
then the documents this step names. Assessment/ is analysis, not instructions —
where it disagrees with the code, the code wins and I want to be told.

Locate everything by symbol name and by the comment text quoted below, not by
line number: the line numbers here are from 2026-08-13 and will have moved.
```

---

## Ordering, and why

```
C. Cleanup ────────────────┐ touches no post code; do it first because two
                           │ items misdirect a fresh session and one is a
                           │ safety statement that should not wait
0. Free wins ──────────────┤ independent, no design dependency
                           │
1. Multi-WCS: reproduce ───┤ ◄── CRITICAL PATH. Everything after
   the block, then unblock │     depends on what F360 really emits
                           │
2. Retire the spoilboard ──┤ safe only once 1 proves the homed path
3. Marlin multi-WCS ───────┤ needs 1; independent of 2
4. Group 6 trim ───────────┤ needs 2 and 3 — they remove its reasons to exist
5. Group 7 split ──────────┤ independent of 1–4; can run in parallel
6. Clarity ────────────────┤ after the deletions, or it is done twice
7. Documents, once ────────┘
```

**Phase C was first because it cost nothing and two of its items were actively
misleading**: `docs/plan.md`'s Checkpoint — the one file `CLAUDE.md` tells every session
to read first — sent work to a branch three branches out of date, and six documents said
`PReview.md` was out of the tree after it had been committed. **Both are fixed** (C2, C3),
and running C2 turned up two pointers this plan had not counted — one of them a standing
ban on filing against the register `CLAUDE.md` now points at.

**Step 1 is first among the code steps because it is the only one that can invalidate the
others.** Steps 2–4 assume F360 emits a multi-WCS job the way
`03-f360-and-firmware.md` §3 describes — which is read from Autodesk's post source, not
observed. One posted job settles it. If it comes out differently, 2–4 get re-planned
rather than half-built.

---

## Phase C — Cleanup

Drawn from `10-project-cleanup.md`, which judged every item by one test: **does it help
someone execute this plan, or does it cost effort to keep true?** Only the items that pass
are here. **Nothing in Phase C touches `MPCNC_v4.0_Beta2.cps`**, which is why it can run
before the critical path rather than after it — and why it is the cheapest phase in the
plan by a wide margin.

Two of these are not tidying. **C2 and C3 were corrections to documents that misdirected a
session**, and C4 is a safety statement about behaviour nobody has verified.

**State on 2026-08-13. Phase C is complete.** `C0` `C1` `C2` `C3` `C5` **done**; `C6`
**closed by the author's ruling — the two remote branches are to be deleted unread**, which
also means **C6 no longer gates Steps 2 and 5**; `C4` **deferred by the author**; `C7` `C8`
`C9` are records rather than actions and need nothing. The phase left
`MPCNC_v4.0_Beta2.cps` untouched, as it said it would. **Nothing is outstanding**: the author ran
`git push origin --delete UpdateToolChange GRBL_Fixes` on 2026-08-13, and `git ls-remote --heads`
confirms both are gone. **Step 0 then landed the phase's first post code** — 0.3, 0.4, 0.6.

*Naming, to avoid one collision: `C1`–`C9` are cleanup items. **Guard C** is the Marlin
multi-WCS guard in `validateJob()` and belongs to Step 3. They are unrelated.*

### C0 — The working branch ✅ **DONE 2026-08-13**

Branch **`Assessment`** cut from `CoverageFixes`; `Assessment/` and `docs/PReview.md`
committed as `40fc3c7` and `d010fee`. **Note for anyone merging:** `CoverageFixes` is
itself **not merged into `master`**, so `Assessment` sits on unmerged work. That is fine
for review documents; it matters the moment a code step lands here, because the merge to
`master` then carries two ranges rather than one.

### C1 — `docs/PReview.md` into the tree ✅ **DONE 2026-08-13**

- **Goal** — the register that decides the biggest question in this plan is findable by
  someone browsing the repository.
- **Why** — it held the **only** copy of seven open findings, of §3.1 (Step 1.3's test
  register) and of the design backlog, recoverable only as
  `git show 347ce5d:docs/PReview.md`. `CLAUDE.md` kept it out of the tree *"until the
  professional review runs"* — but the review cannot run if its own register cannot be
  found. **This assessment reached its central conclusion only because a `git show`
  happened to be in the instructions.**
- **Done** — `d010fee`, 1,118 lines, no finding prefix (it builds no finding of its own).
- **One consequence to note, not fix.** `conventions.md` budgets `PReview.md` at *"≤ 920
  lines, and falling"* and the file is **1,118**. C1 did not cause that — the file was this
  size when it left the tree — but the overrun is now visible in a document contract instead
  of hidden in git. By that same contract an overrun *"asks what has stopped being live"*,
  and the answer is already written into the budget: §2's long form and §3's expansions are
  unbuilt design and unrun rows, which **retire on build**. Steps 1–5 are that build. Leave
  the number alone until then; re-measure it at Step 7.

### C2 — Fix the pointers C1 falsified ✅ **DONE 2026-08-13**

**There were six, not four.** The two this page missed were found by running its own Done-when instead of
trusting its table, and one of them mattered more than any of the four: **`docs/conventions.md`:24's
contract row said *"nothing may be filed against it"*** — a standing prohibition on using the register
`CLAUDE.md` had just been changed to point at. The other was `.claude/commands/close-finding.md`:12, inside
the procedure that files findings. A seventh statement, `docs/plan.md`:73–75, justified that file's budget
overrun on the registers being absent; it is fixed too, and **the trim it was excusing is now owed**.

- **Goal** — no document tells a reader to `git show` a file that is now in the tree.
- **Why** — C1 was the right move and it **invalidated four statements in three
  documents**. This is the ordinary cost of a restore, and it is exactly the class of
  staleness `CLAUDE.md` warns about: *"a row split across two files is how seven ids went
  stale."*
- **Where** — all six found present and all six fixed on 2026-08-13:

  | File | Line | What it said | Now |
  |---|---|---|---|
  | `CLAUDE.md` | 14–15 | *"**out of the tree** … recover it with `git show 347ce5d:…`"* | a plain read-order entry naming what the register holds |
  | `CLAUDE.md` | 34 | *"stays in the register it was filed in until `PReview.md` returns"* | rule kept, clause dropped, **plus the §6 policy** |
  | `docs/conventions.md` | 24 | *"until then … **nothing may be filed against it**"* | **in the tree, filed against directly** — the worst of the six |
  | `.claude/commands/close-finding.md` | 12 | *"is out of the tree until the professional review runs"* | *"holds the professional findings"* |
  | `docs/plan.md` | 120–121 | *"a parking lot … **out of the tree** meanwhile"* | the deliberate deferral, and §3.1 as the critical path |
  | `Coverage/CoverageFixes.md` | 227 | *"belongs to the professional register when `PReview.md` returns"* | names `docs/PReview.md` directly |

- **The policy, settled** — `10-project-cleanup.md` §6 asked what the restore does not
  answer. It is now one clause in `CLAUDE.md` → *Registers ship with the code*: **"no
  register lives outside the tree: too unfinished to commit is too unfinished to hold the
  only copy of an open finding."** Stated as a rule about registers rather than about this
  one file, so it binds the next register too. `conventions.md`:24 carries the same
  judgement in the contract row, where the prohibition used to be.
- **Done when** ✅ — `grep -rn "347ce5d|out of the tree"` over everything outside
  `Assessment/` returns **nothing**. It matches inside `Assessment/` by design: these pages
  quote the old wording to explain why it was changed.
- **Budgets held** — `CLAUDE.md` 60/60 (the policy clause spent the last line),
  `conventions.md` 295/300. **`docs/plan.md` did not**: see C3.
- **Findings** — none. Documentation correctness, not a defect in the post.

### C3 — `docs/plan.md`'s Checkpoint points at the wrong branch ✅ **DONE 2026-08-13**

**The Baseline was wrong about more than the branch.** It also said *"`master` is 16 commits ahead of
`origin/master` and **nothing has been pushed**"* — and `git reflog show origin/master` records
`94241ec … update by push`, dated **2026-08-09**. `master` is **6** ahead, and the push did happen. A
paragraph whose job is to say where the work is was wrong on the branch, the count and the push state at
once, which is the strongest argument this plan has for why the Checkpoint is read first and trusted least.

- **Goal** — the file every session is told to read first describes where the work
  actually is.
- **Why** — this is the **resumability contract**. `CLAUDE.md`: *"`docs/plan.md` →
  Checkpoint — always, first. The only place that says what is next."* It read *"Work
  continues on **`hobby-dialog-review`**"* — and work had since moved through
  `Coverage_Review` and `CoverageFixes` to `Assessment`. `hobby-dialog-review` was one of
  the thirteen branches C5 deleted. **A fresh session obeying `CLAUDE.md` was being sent to
  a branch that no longer exists** — which is exactly why C3 landed first.
- **Where** — `docs/plan.md` [:15-19](docs/plan.md#L15) (Baseline) and
  [:107-121](docs/plan.md#L107) (Phase status).
- **The change made** — four touches, all inside the contract `conventions.md` sets for
  this file (checkpoint, phase status, review pointers — nothing else):
  1. **Baseline** — `Assessment`, 21 ahead of `master`, `CoverageFixes` unmerged and
     contributing 18 of them, the thirteen labels deleted, and the corrected push state.
  2. **Phase status** — *"not started"* was too blunt. Now: the deferral was **deliberate**,
     the 24 posted files show it executed, what is missing is any *statement* of it, and
     **§3.1's six never-posted jobs are the critical path**.
  3. **A pointer to `Assessment/`**, three lines, naming `09-plan.md` and `STATUS.md` and
     nothing else — *`conventions.md` warns that two files pointing at each other is how
     content ends up in neither, so this one points and does not summarise.*
  4. **:73–75**, C2's sixth pointer, which lived in this file.
- **Done when** ✅ — a session reading only `docs/plan.md` finds the right branch, the right
  next action and this review.
- **One thing left open, and it is the author's call.** `plan.md` was **132 lines against a
  120 budget** before this edit and is **143 after**. The overrun is not new and C3 did not
  cause it — but C3 removed its stated excuse. The two long paragraphs at :46–77 exist
  because `PReview.md` and the `HR-`/`CR-` register were out of the working tree and those
  paragraphs *"are the only surviving summary of what those registers hold."* **Both
  registers are back**, so roughly thirty lines now duplicate `HReview.md` and `PReview.md`
  and could go. **Deleting thirty lines of another author's Checkpoint history is not a
  mechanical edit**, so the sentence was corrected to say the trim is owed and unstarted,
  and the trim itself was not done. Do it deliberately or raise the budget deliberately.
- **Findings** — none.

### C4 — A status line in `guide-pro.md` — ⏸️ **DEFERRED 2026-08-13, by the author**

**Deferred, not rejected, and not blocked.** The go-ahead this item asks for was not given; the author
deferred it on 2026-08-13 while directing C2, C3 and C5. Nothing in `guide-pro.md` was touched. The argument below stands unchanged and the item stays here rather than moving
to the *Blocked list*, because **nothing external gates its first half** — it waits on a decision, not on
evidence. Whoever picks it up should re-read the safety argument first and not treat this as a new idea.

**What deferral costs, stated once so the trade is explicit:** until it lands, `guide-pro.md` describes the
multi-fixture path in the same voice as the 24-file-verified hobby path, and a reader cannot tell them
apart. That is the gap `05-history.md` identifies; it is now a known, accepted gap rather than an oversight.

- **Goal** — a reader of the professional guide can tell verified behaviour from
  unverified behaviour.
- **Why** — the cheapest item in the whole plan and the one with the clearest safety
  argument. `[AUTHOR]` professional testing was deliberately deferred; **nothing in the
  repository says so**, and `guide-pro.md` describes the multi-fixture path in the same
  voice as the verified hobby path. *A hobbyist who believes that path is finished will
  run it into a fixture.* The deferral was sound sequencing — the only thing wrong with it
  is that a reader cannot tell.
- **The permission problem, stated rather than assumed** — `CLAUDE.md`: the guides are
  *"not touched during code changes, only when asked."* **Phase C is not a code change,
  but that rule was written to stop exactly this kind of drive-by edit.** So this item is
  proposed, not scheduled. It is the one thing in Phase C that must be asked for.
- **The change, split by what is already known:**
  1. **Now, independent of Step 1** — the deferral is `[AUTHOR]`-confirmed, so a status
     line can be written today: which paths are verified against posted output (the hobby
     path, 24 files) and which are not (multi-part, multi-fixture, tool change, laser).
  2. **After Step 1.1** — add that the F360 "Multiple WCS Offsets" job does not post at
     all. This half genuinely waits, because 1.1 is what turns `[AUTHOR]` report into a
     reproduced defect.
- **Done when** — the guide states its own verification status above the feature
  descriptions, not in a footnote.
- **Findings** — none of its own; it is the visible half of the gap
  `05-history.md` identifies.

### C5 — Delete thirteen merged local branches ✅ **DONE 2026-08-13**

All thirteen deleted after C3 landed, with `git branch -d` — never `-D` — so git itself would have refused
any branch that was not fully merged. Tips recorded in the commit for recovery beyond the reflog:
`Coverage_Review 5178e72` · `beta3 4b36697` · `comment-clean-up b7d12fb` · `hobby-dialog-review 1ea32a8` ·
`retire-doc-gate 46bcf2a` · `v4.0-beta2 8189d91` · `v4.0-dev 6b0c0e5` · `v4.0-doc-streamline cedeca4` ·
`v4.0-f360-compliance 1beb47b` · `v4.0-float-compare adef981` · `v4.0-hreview-fixes 1ccff44` ·
`v4.0-readme-update b9b6373` · `wcs-reworked-flow cd57a48`. `git branch` now lists **three**:
`master`, `CoverageFixes`, `Assessment`. **No remote branch was touched by C5** — the two the author later
ruled on are C6's, deleted deliberately and separately, exactly as the caution below asked.

- **Goal** — `git branch` shows the two branches that matter instead of fifteen.
- **Why** — thirteen local branches are **fully merged into `master`**; the work is all
  there and the labels carry nothing. One of them, `hobby-dialog-review`, is what C3's
  stale Checkpoint points at — leaving both in place is how a session ends up doing work
  on a dead branch.
- **Verified 2026-08-13** by `git branch --merged master` — `Coverage_Review`, `beta3`,
  `comment-clean-up`, `hobby-dialog-review`, `retire-doc-gate`, `v4.0-beta2`, `v4.0-dev`,
  `v4.0-doc-streamline`, `v4.0-f360-compliance`, `v4.0-float-compare`,
  `v4.0-hreview-fixes`, `v4.0-readme-update`, `wcs-reworked-flow`.
- **Keep** — `master`, `CoverageFixes` and `Assessment`, which are the only two unmerged
  (`git branch --no-merged master`).
- **Do C3 first.** Deleting the branch the Checkpoint names, before fixing the Checkpoint,
  turns a stale pointer into a broken one.
- **Do not touch the remote branches here.** Twenty of twenty-two are merged and can be
  pruned at leisure, but **remote deletion is the one irreversible action on this page**
  and belongs in a deliberate step of its own, never folded into a phase. Two of them are
  C6.
- **Done when** — `git branch` lists three names; `git branch --no-merged master` lists
  two.

### C6 — The two unmerged remote branches — ✅ **CLOSED 2026-08-13: not read, deleted**

**The author overruled this item, and the dates are why.** Presented with the ages below, the ruling was:
*"the correct action is to ignore this code as it is over 2 years old and has been replaced by the more
recent changes. Delete."* **This reverses the item's own two conclusions** — that the branches were worth a
read before Steps 2 and 5, and that neither should be deleted. Recorded rather than quietly rewritten,
because the reasoning that failed is instructive: this page valued the branches as *records of attempts*,
without ever checking **what file they edit** or **how far the post had moved since**. Both answers are
below and both defeat the premise. **A branch is not a record worth keeping merely because it is unmerged.**

**Deletion status — done 2026-08-13.** The author ran
`git push origin --delete UpdateToolChange GRBL_Fixes`, and `git ls-remote --heads origin` no longer lists
either. The two **local archive tags** — `archive/UpdateToolChange` → `690e586`, `archive/GRBL_Fixes` →
`385edaf` — were set **before** the push because `690e586` was contained by no other ref, and they are now
**the only refs anywhere that reach that history**: the tags were never pushed, so this clone holds it
alone. `git tag -d archive/UpdateToolChange archive/GRBL_Fixes` discards it for good.

*The dates and the reasoning that produced the ruling, retained:*

| Branch | Last commit | Age | Tip |
|---|---|---|---|
| `origin/UpdateToolChange` | **2023-11-19 17:38 −0800** | 2 yr 9 mo | `690e586` *"more"* |
| `origin/GRBL_Fixes` | **2023-11-19 14:00 −0800** | 2 yr 9 mo | `385edaf` *"Elliminasted the End() function and merged code"* |

- **`GRBL_Fixes` is an ancestor of `UpdateToolChange`** (`git merge-base --is-ancestor` confirms). All
  seven of its commits are contained in the other branch, which adds exactly two of its own — `64cd9e6`
  *"Tool change updated"* and `690e586` *"more"*. **Reading `UpdateToolChange` reads both.** The two are
  not independent lines of work, as this item assumed; they are one line and a tag three hours behind it.
- **Both edit `MPCNC.cps`** — a filename that no longer exists. The deliverable has been
  `MPCNC_v4.0_Beta2.cps` since well after these commits, so neither branch can be merged or cherry-picked;
  anything wanted from them must be **read and re-applied by hand**. That is a different task from the
  "may already contain part of the answer" this item was written around.
- **The FluidNC premise is already spent.** Four of the seven shared commits are FluidNC work, and FluidNC
  is **already in the post** and in `design.md`, `conventions.md`, `README.md` and `guide-hobbyist.md`.
  Whatever these branches knew about FluidNC either landed or was re-derived.
- ~~**Still worth the read, for one narrowed reason:** `64cd9e6` *"Tool change updated"* is the only record
  of a tool-change attempt from before the current design, and **Step 5 rewrites that path**.~~ **Overruled.**
  A 2023 tool-change attempt against a differently-named file, predating the machine frame, the fixed Z
  reference, the `G10 L20` rework and Phases 1–4, is not a design input to Step 5 — it is archaeology about
  a post that no longer exists. `ce2c3f7`'s `G38.2`/`G38.3` question likewise: `docs/design.md` already
  carries the current firmware-dialect answer, and `Coverage/CoverageFixes.md`:222–228 already holds the one
  live `G38.2` concern (the RRF ≤ 3.1.1 machine-frame target). **Nothing here is Tier 2 that the tree does
  not already hold.**
- **Consequence for Steps 2 and 5: none. C6 no longer gates either.** That is a real simplification —
  this item was the only Phase C entry with a claim on a code step.

*Original reasoning, retained:*

- **Goal** — no step re-derives, or silently re-adopts, work that already exists.
- **Why** — both carry unmerged work and both land squarely on planned steps:
  - **`origin/UpdateToolChange`** — **Step 5 rewrites the tool-change path.** This branch
    may hold part of the answer, or an approach already tried and rejected. Either is
    worth knowing before writing a line. Given `[AUTHOR]` reports Group 7 *"has not been
    reviewed or tested"*, an abandoned branch is one of the few records of what was
    attempted.
  - **`origin/GRBL_Fixes`** — firmware fixes are **Tier 2** material by
    `06-retention.md`'s classification: knowledge that cannot be re-derived from F360.
    Anything real in here belongs on the preserve list.
- **The change** — none. This is a read, and it produces either a preserve-list addition
  or a note that the branch is superseded.
- **Done when** — each branch has one recorded sentence: what it contains, and whether
  anything in it must survive.
- **Delete neither**, whatever the outcome.

### C7 — Record the `property-reference.md` debt; do not pay it

- **Goal** — nobody trusts a stale generated document in the meantime.
- **Why** — its marker reads `doc-sync: MPCNC_v4.0_Beta2.cps @ 17a20f2`, and **19 commits
  have changed the post since that ref** (verified 2026-08-13,
  `git log 17a20f2..HEAD -- MPCNC_v4.0_Beta2.cps`). **It is out of date before this plan
  begins**, and Steps 2–4 will invalidate it far more than 19 commits did.
- **The change** — **nothing now.** Regeneration is Step 7, once, after the deletions;
  doing it earlier means doing it twice, and the file is off-limits besides. The Phase C
  action is only to carry the figure so a later session does not re-measure it or, worse,
  read the file as current.
- **Done when** — Step 7 regenerates and re-bumps the marker. `node docs/doc-sync.js` is
  the check.

### C8 — The tooling: no change

Verified against `10-project-cleanup.md` §4 and left alone. `.claude/hooks/post-edit.js`
(`node --check` on every edit), `docs/doc-sync.js`, `/checkpoint` and `/close-finding` all
stay. `docs/check-docs.js` is **already retired** (524 lines, `46bcf2a`) for gating more
than a document contract can carry — the right call, and **nothing left has its problem**:
`doc-sync.js` checks one factual correspondence instead of trying to enforce prose quality,
which is precisely the distinction that retirement drew.

One dependency to remember: **`/close-finding` will need updating if the registers ever
consolidate** — see C9.

### C9 — Register consolidation: deliberately **not** in Phase C

`10-project-cleanup.md` §1 proposes one register, `docs/findings.md`, with the `HB-`,
`HR-`, `CR-` and `PR-` prefixes kept as origin markers; the four `Coverage/` files
(3,263 lines) become one section, and `CoverageReviewPlan.md` / `CoverageReview.md` archive
wholesale as process records of a finished review.

**It belongs after Step 2, not here.** Step 1.3's six posted jobs and Step 2's deletion
will close or re-scope a dozen rows — CR-11, CR-12, CR-14 and PR-8 close **by deletion**
alone. Consolidating first means doing the work twice, and it would collide with
`/close-finding` mid-plan.

**What Phase C does instead: nothing.** Recorded here so the item is not mistaken for an
oversight.

---

## Step 0 — Free wins

No design dependency, no ordering constraint between them, each independently
committable.

> ## ✅ **Step 0 is COMPLETE — 2026-08-13**
>
> **0.1 · 0.3 · 0.4 · 0.6 landed. 0.2 deferred to the tool-change solution. 0.5 closed with no edit.**
> Readiness was checked before any of it, and the check is kept below because Step 1 inherits its
> conclusions. **`REG-MF` was never invalidated**: no property was added, removed, renamed or relocated,
> so the property dump has not moved and the baseline can be posted whenever there is Fusion time.
> **The next unfinished thing in this plan is Step 1.1**, which needs a Fusion keyboard.
>
> **What holds.** The post is **untouched at 3,758 lines** — the exact tree this plan was written
> against — so every line reference in Steps 0 and 1 is still valid. Spot-checked and exact:
> `toolChangeDisableZStepper` :552 and its emission :3672-3676, the `M84 S60` comment :1827-1830,
> Guard B :1698-1705, the homing statement :1669, `groupDefinitions.duet` :118 (the plan says
> :117, off by one). Every symbol Steps 0 and 1 name is present: `cycleNotSupported`,
> `parkCanRetract`, `usesMachineZDatum`, `machineHomesXY`, `parseInterPartTravelZ`, `validateJob`.
> Both registers are readable in the tree (C1), Phase C is done, and **C6 no longer gates
> anything**.
>
> **Both things this block asked to be settled are settled — 2026-08-13.**
>
> 1. **The register destination.** Fixed in 0.2, 0.3 and 0.6: every row went to `PReview.md`, which is
>    the only file that carries these ids. The prompts used to say `HReview.md`.
> 2. **The `REG-MF` collision never happened.** With **0.2 deferred** and **0.5 closed without an edit**,
>    the three items that landed — 0.3, 0.4, 0.6 — add, remove, rename and relocate **no property**, so
>    the property dump has not moved and the baseline can be posted at any time. *This is the collision
>    `05-history.md` warns produces work twice, and it was avoided by the two items that would have
>    caused it being declined on their own merits, not by sequencing.* **It returns at Step 5**, which
>    splits group 7, and at whatever the `PR-` pass does with group 11.
>
> **What actually happened when Step 0 was run, and the reason it is worth reading twice:** three of the
> four items departed from their own instructions, and each departure was found by checking the plan's
> claim rather than executing it. 0.2's registered fix contradicts a safety comment 800 lines away.
> 0.3's prescribed `>>> WARNING:` comment would have been written into a file the abort prevents. 0.6's
> *"apply it as written"* covered a diff that fails at Comment Level `Off` and an `M1` that ends the job
> on RepRap. **Only 0.4 landed as written, and it is the one item with no register row behind it.** The
> pattern to carry into Step 1: a complete diff in a register is a proposal that was never run, and its
> age is not evidence.

### 0.1 — `docs/PReview.md` back in the tree ✅ **DONE — moved to Phase C, item C1**

Restored **and committed**: `d010fee` on branch `Assessment`, 1,118 lines. It holds the
only copy of seven open findings and of §3.1, which is Step 1.3's test register. See
**C1**.

### 0.2 — Delete `toolChangeDisableZStepper` and its `M84 Z` — ⏸️ **DEFERRED 2026-08-13, by the author**

**Held for the complete tool-change solution**, with Phase 4 and HR-7 / HR-8 / HR-9. It was on the Step 0
list as a free win because its diff was self-contained; the readiness check below found it is not free —
the registered fix and this item's fix are **incompatible**, and choosing between them is a decision about
what a tool change should do, which is the thing the tool-change work exists to settle. `PReview.md`'s
HR-10 row now carries the ⚠️ so the unsafe diff cannot be picked up as a warm-up commit, and the long form
carries it again at the diff itself. **Nothing below is stale — read it when the tool-change work starts.**
One consequence worth keeping: with 0.2 held **and 0.5 closed unedited, Step 0 deletes no property at all**,
so `REG-MF` came through it untouched.

- **Goal** — the post can no longer emit a command that drops the gantry onto the work.
- **Why** — HR-10, and **the post already knows**. At
  [:1827-1828](MPCNC_v4.0_Beta2.cps#L1827) it writes: *"a bare `M84` releases at once,
  and an unbalanced LowRider gantry with no brake sinks in Z when it does"* — which is
  why `M84 S60` is used there. Then at [:3675](MPCNC_v4.0_Beta2.cps#L3675) it emits
  `writeBlock(mFormat.format(84), 'Z')` — a bare `M84 Z`. **The hazard is documented in
  one function and committed in another.** The `askUser("Z stepper will disable; wait
  for full stop")` beside it is an acknowledgement, not a mitigation.
- **Where** — property [:552-560](MPCNC_v4.0_Beta2.cps#L552); emission
  [:3672-3676](MPCNC_v4.0_Beta2.cps#L3672).
- **The change** — delete both. Do **not** substitute `M84 S<timeout>`: the purpose was
  to free the axis by hand, which a timeout does not do.
- **Done when** — `M84` appears only at :1827-1833. **Properties 66 → 65** — *not* 72 → 71, which
  this line said until 2026-08-13 and which was wrong at both ends. A direct count of the
  properties literal ([:123-952](MPCNC_v4.0_Beta2.cps#L123)) gives **66**; `plan.md`'s 69 is
  itself stale, predating CR-13's deletion of `Retract Across Parts` and `bf0c2bd`'s fold of
  group 3. **`doc-sync` cannot arbitrate** — it is 19 commits behind (C7). Re-count, don't trust.
- **Findings** — **HR-10, and its row is in `docs/PReview.md`, not `HReview.md`.** It is one of
  the seven professional ids that live there **and nowhere else**; `grep HR-10 docs/HReview.md`
  returns nothing, because the duplicate stub rows were deleted on 2026-08-07 for exactly this
  reason. `CLAUDE.md`: a professional finding *"stays in the register it was filed in."*
- ⚠️ **This change supersedes HR-10's registered fix rather than applying it — read the row
  first.** `PReview.md`:262-277 carries a **complete diff that keeps the property** and guards
  it by firmware: warn on GRBL, and **still emit the bare `M84 Z` on Marlin**. Its Pass line
  requires *"`M84 Z` present"* on a Marlin post. But the post's own end-of-job comment at
  [:1827-1828](MPCNC_v4.0_Beta2.cps#L1827) — **on that same non-GRBL branch** — is why `M84 S60`
  is used there: *"a bare `M84` releases at once, and an unbalanced LowRider gantry with no brake
  sinks in Z when it does."* **The registered fix would leave the documented hazard standing on
  the one firmware family that can execute it.** HR-10 was filed as a dialect bug; it is also a
  safety bug, and nobody noticed because the two facts sat in different files. So: retire the
  long form per `/close-finding` step 5, say in the commit that the diff was superseded and why,
  and **rewrite the Do→Get row** — its current Pass criterion asserts the thing this fix removes.
- **Prompt**
  > In MPCNC_v4.0_Beta2.cps the property `toolChangeDisableZStepper` ("Disable Z
  > Stepper") emits a bare `M84 Z` at the tool-change position. Find the property and
  > the emission site (search `toolChangeDisableZStepper` and `mFormat.format(84)`).
  > Then find the comment near the program-end `M84 S60` explaining why a bare M84 is
  > unsafe on an unbalanced gantry, and quote it.
  >
  > Then read HR-10's own row and long form in **docs/PReview.md** — not HReview.md, which
  > does not have it. That long form already carries a complete diff, and it is a *different*
  > fix: it keeps the property and guards it by firmware, so Marlin still gets the bare M84 Z.
  > Say whether that fix is compatible with the End() comment you just quoted.
  >
  > Propose a diff deleting the property and the emission entirely, plus the updated HR-10 row
  > **in docs/PReview.md**, and a replacement Do→Get row — the existing one passes on `M84 Z`
  > being present on Marlin. Do not substitute a timeout variant — say why in the proposal.

### 0.3 — Name the reason WCS probing is refused ✅ **DONE 2026-08-13**

**Landed, with one deliberate departure from *The change* below: the reason goes in `error()`, not in a
`>>> WARNING:` comment.** `cycleNotSupported()` calls `error()`, so the post **aborts and produces no
file** — a comment would have been written into output the operator never receives, and the dialog, which
is the only channel they do get, would still have carried Autodesk's generic text. So `cycleNotSupported()`
is replaced rather than kept: one `error(localize(…))` naming the reason and the two things that do work.
Keeping the call as well would have changed nothing, the first `error()` being the one Fusion reports.
That matches what the post already does at the tool-orientation and radius-compensation refusals, which
replace the SDK's generic text with their own for exactly this reason. **Filed as `PR-12` in
`docs/PReview.md`** — *"new HR row"* below meant that register anyway, the `HR-` series living there, and
§1 puts *"Machining Extension — probing / Inspection strategies"* in professional scope. Verified by
**§3.8**; `node --check` passes.

- **Goal** — an operator who tries an F360 probing operation learns why it cannot work,
  and what to do instead.
- **Why** — `03-f360-and-firmware.md` §5b. The refusal is **correct**: GRBL and Marlin
  have no arithmetic, so a WCS probing cycle is unimplementable there, not merely
  unimplemented. But `cycleNotSupported()` emits Autodesk's generic text and the
  operator learns nothing.
- **Where** — [:2470-2478](MPCNC_v4.0_Beta2.cps#L2470); `isProbeOperation()`
  [:2460](MPCNC_v4.0_Beta2.cps#L2460).
- **The change** — emit a `>>> WARNING:` naming the reason and pointing at the post's
  own Z touch-off (Group 6) or a manual offset set, then keep `cycleNotSupported()`.
  The abort is right; only the silence is wrong.
- **Done when** — a probing operation still refuses to post, and says why.
- **Findings** — new HR row.

### 0.4 — Collapse the frame predicates (partial) ✅ **DONE 2026-08-13**

**Landed as specified.** `parkCanRetract()` is gone; both callers — `validateJob()`'s warning and
`writeMachineParkXY()` — read `fixedZEstablishedInFile()` directly, which is a pure inline, so **no output
byte moves**. Two register rows named the deleted alias and both now say so: `PReview.md` **PR-8**, whose
fix created it, and `HReview.md` **HB-17**, which argued for keeping the park's own name. What those rows
actually bought is *one* predicate behind both call sites, and that survives — it is the name that went.
Each call site's comment absorbed what the deleted header said, including that the answer is false on all
of Marlin by construction. **The remaining predicates are untouched**, Step 2 deleting two of them outright.

- **Goal** — remove the alias now; defer the rest.
- **Why** — `parkCanRetract()` [:2101](MPCNC_v4.0_Beta2.cps#L2101) is
  `return fixedZEstablishedInFile();` — a rename wearing a function.
- **Where** — [:2071-2103](MPCNC_v4.0_Beta2.cps#L2071) and callers.
- **The change** — inline `parkCanRetract()` only. **Step 2 deletes two of the
  remaining predicates outright**, so consolidating further now means doing it twice.
- **Done when** — `parkCanRetract` no longer exists; output byte-identical.
- **Findings** — none; internal.

### 0.5 — Group 11 (Duet, 2 properties) — ✅ **CLOSED 2026-08-13: no change, and Step 0 is done**

> **The author's ruling, in two parts.** First, **the two fields stay** — *"there would be nowhere to
> change this g-code if incorrect."* Then, having seen that the g-code **is** incorrect on current
> firmware: **leave group 11 alone for now, and address it when the `PR-` findings are handled.**
> So `MPCNC_v4.0_Beta2.cps` is not edited by this item at all, and the relocation option below is not
> taken — it is deferred to the professional pass, where `PR-13` already carries the real work.
>
> **Two consequences, both good:**
>
> - **Step 0 is complete.** 0.1 · 0.3 · 0.4 · 0.6 landed, 0.2 is deferred to the tool-change solution,
>   and 0.5 closes without an edit.
> - **`REG-MF` is no longer blocked or blocking.** Nothing that landed in Step 0 adds, removes, renames
>   or *relocates* a property, so the property dump has not moved a byte and the factory-default baseline
>   can be posted whenever there is Fusion time. **The collision `05-history.md` warned about did not
>   happen** — not because it was managed, but because the two items that would have caused it were both
>   declined on their merits. It returns at Step 5, which splits group 7.
>
> **`09-plan.md` overreached here, and `07-code-map.md` did not.** The code map's verdict is *"**Keep or
> fold** into the firmware selector; two controls is not a problem worth solving"* (:258). This page
> carried that forward as *"Fold"* and then wrote an acceptance count that assumed deletion. Nothing new
> was learned in between — the option was simply dropped in transcription, and the count made it look
> decided.

**What the two properties actually emit.** `onSection()`'s `fw == eFirmware.REPRAP` branch writes the
property value **verbatim** when the section type changes — which on a milling-only job is the first
section of every job. Read from `Duet3D/RepRapFirmware` `src/GCodes/GCodes2.cpp` at `2.05` and at
`master`: on **RRF 2.05** every parameter of both strings is parsed and means what the tooltip implies;
on **RRF 3.x** `M453` is read for `S` alone, so `duetMillingMode`'s `P2 I0 R30000 F200` sets no pin, no
maximum RPM and no PWM frequency **and reports no error**, while `duetLaserMode` keeps `R` and `F`/`Q` but
loses `P2 I0`, the laser pin having moved to `C"pin"` / `M950`. The full table is in PR-13.

**So the answer to *is the g-code correct* is: yes on RRF 2.05, and one part in five for `M453` on
RRF 3.x.** No claim here rests on running a Duet — both readings are from the firmware's own switch
statement, and neither string has ever appeared in a posted file.

**What was on the table, kept for the `PR-` pass rather than deleted.** The one option that survived
refusal was **relocation, not deletion**: set both properties' `group` to the firmware selector's. A
`group:` is a display attribute, so **no key changes and no saved setting resets**, the property count
stays at 66 and both fields remain editable — 11 groups → 10, which is the only benefit 0.5 ever claimed.
It is **not taken now** and is not urgent: it would still re-head the property dump, and it buys a dialog
tidy-up in the same group of properties `PR-13` is going to rewrite the defaults of. **Doing both at once
costs one baseline instead of two.**

**Figures for whoever picks it up:** 66 properties **unchanged** either way — the *"66 → 64"* that stood
on this line until 2026-08-13 assumed the deletion that was refused, and `plan.md`'s 69 is staler still.
**Re-count at the edit**; `doc-sync` is 19 commits behind (C7) and cannot arbitrate. `groupDefinitions.duet`
is at [:118](MPCNC_v4.0_Beta2.cps#L118) — :118, not the :117 this line said until 2026-08-13.

### 0.6 — HR-13, the `onCommand` gap ✅ **DONE 2026-08-13 — half applied, half refused**

`onCommand` silently discarded commands it did not name. **Its row is in `docs/PReview.md`**, the same
professional-register rule as 0.2, and `HReview.md` does not carry it.

**The line that stood here — *"this diff has not been found to conflict with anything, so apply it as
written"* — was wrong, and this is the second registered diff in Step 0 that does not survive being
checked.** Two defects, one in each half:

1. **The warning.** The diff used `writeComment(eComment.Important, " >>> WARNING: …")`. That is gated on
   Comment Level, and HR-13's own complaint is that *"at Comment Level `Important` or `Off` not even the
   naming comment survives."* At `Off` the fix would have vanished exactly like the thing it fixes, and it
   would have re-opened `HReview.md` **HB-9**, which routed all thirteen `>>> WARNING:` sites through
   `writeWarning()` precisely so a warning outlives the gate. **Landed through `writeWarning()`.**
2. **`case COMMAND_OPTIONAL_STOP: M1` — refused, on the firmware's own source.** The diff's premise is
   *"`M1` is supported by all three targets, so there is no reason to drop it."* True of the parsers, false
   of the behaviour, and the three disagree in the worst possible way: grbl 1.1 `grbl/gcode.c` has
   `case 1: break; // Optional stop not supported. Ignore.` — **accepted, no error, nothing pauses**;
   RepRapFirmware `src/GCodes/GCodes2.cpp` handles `case 0: // Stop`, `case 1: // Sleep`, `case 2: // Stop`
   in one block, so mid-file `M1` **ends the job**; only Marlin does what Fusion means
   (`Marlin/src/gcode/lcd/M0_M1.cpp`, under HB-1's `HAS_RESUME_CONTINUE`). **So the diff would have shipped
   a no-op on the default firmware and a job abort on another.** *Optional stop* now warns instead of
   vanishing, and is honoured nowhere; promoting it to an unconditional `M0` is a dialog decision and is
   filed in `PReview.md` §6.

**HR-13 is `◑ part-fixed`, not fixed** — the silence is gone, the command is still not honoured. Its long
form is kept for the half that is owed, and the three firmware citations live in it. Verified by **§3.8**.

---

## Step 1 — Multi-WCS: reproduce the block, then unblock it

**The critical path.** Nothing after it should be designed until 1.1 has produced a
file.

> **Readiness checked 2026-08-13: nothing is missing, and the whole step waits on one person.**
>
> **1.1 needs the author at a Fusion keyboard** and produces evidence, not code — so it cannot be
> started from the repository, and 1.2 and 1.3 both wait behind it. That is the plan working as
> designed, not a gap.
>
> **The licence is not a barrier here**, which is worth stating because it blocks other steps.
> Guard B fires on `!usesMachineZDatum() && collectDistinctOffsets().length > 1`
> ([:1702](MPCNC_v4.0_Beta2.cps#L1702)) — no part of that reads the licence, and a refusal happens
> before any rapid is emitted. Contrast **Step 5's** verification, which genuinely needs a
> full-licence two-tool post (*Blocked list*).
>
> **One thing to fix inside 1.3 before it runs**, already recorded there: PA1 and PB2 expect
> `Retract Across Parts`, **deleted by CR-13**. Two of the six rows cannot be run as written, so
> re-scoping them is the first action of 1.3, not a surprise partway through.

### 1.1 — Reproduce the failure and file it

- **Goal** — a recorded, reproducible statement of what F360's "Multiple WCS Offsets"
  feature does today when posted.
- **Why** — `[AUTHOR]`: the checkbox is on the Setup dialog's **Post Process** tab,
  prompts for **Number of Instances** and **WCS Offset Increment**, and **the post
  errors out.** Everything in `07-code-map.md` was written treating this path as
  *untested*. It is worse: **it is blocked.** A supported F360 feature cannot produce a
  file, which makes this a defect rather than a gap.
- **Where** — F360 first. Then trace the error in `validateJob()`
  [:1448](MPCNC_v4.0_Beta2.cps#L1448).
- **The change** — none. This step produces **evidence**.
- **Done when** — for a 2-instance GRBL job the exact error text is captured and the
  guard is identified in source. **Expected: Guard B** at
  [:1702](MPCNC_v4.0_Beta2.cps#L1702), because `Fixed Z Reference` defaults to `None`
  so `usesMachineZDatum()` is false. **Confirm rather than assume** — it could instead
  be the range check at [:1887](MPCNC_v4.0_Beta2.cps#L1887), Guard B′ at
  [:1719](MPCNC_v4.0_Beta2.cps#L1719), or the `workOffset == 0` alias.
- **Findings** — **open a row before fixing anything.** A default-configuration refusal
  of a supported F360 feature belongs in the register.
- **Prompt**
  > `[AUTHOR]` reports that an F360 Setup with "Multiple WCS Offsets" ticked (Post
  > Process tab → Number of Instances, WCS Offset Increment) fails to post with this
  > post. I will paste the error text and the failed output.
  >
  > Trace which `error()` produced it. Read `validateJob()` and each guard: Guard B
  > ("A multi-WCS job requires a fixed Z reference"), Guard B′ ("but the first
  > operation's tool cannot probe it"), Guard C ("Marlin has a single coordinate
  > frame"), the work-offset range check, and the `workOffset == 0` → WCS 1 alias. For
  > each, say whether it fires for this job and why.
  >
  > Then: what is the minimum property configuration under which this job posts
  > **today, with no code change**? List the dialog settings. Do not propose code yet —
  > I need to know whether this is reachable before deciding it is a bug.

### 1.2 — Make the homed machine the answer to Guard B

- **Goal** — a homed machine posts a multi-WCS job from a configuration the operator can
  reach without learning the spoilboard subsystem.
- **Why** — three strands meeting:
  1. Guard B's **reasoning is correct** — a multi-WCS traverse needs a frame that
     outlives one WCS.
  2. Its **route is wrong** — satisfying it means finding Group 5, understanding a
     reserved WCS and a probed base, and clearing four more guards. So the default
     configuration of a supported feature is a refusal, and the error names two
     subsystems the operator has never heard of.
  3. **Multi-part work already requires homing**, by the post's own statement at
     [:1669](MPCNC_v4.0_Beta2.cps#L1669): *"repeatable only on a machine with a homed
     X/Y zero."* A homed machine already has a machine frame. This is also how every
     commercial control does it — three of Autodesk's four `safePositionMethod` options
     are machine-frame (`03-f360-and-firmware.md` §3a).
- **Where** — Guard B [:1698-1705](MPCNC_v4.0_Beta2.cps#L1698); `usesMachineZDatum()`
  [:2012](MPCNC_v4.0_Beta2.cps#L2012); `machineHomesXY/Z()`
  [:2019-2026](MPCNC_v4.0_Beta2.cps#L2019); `parseInterPartTravelZ()`
  [:2054](MPCNC_v4.0_Beta2.cps#L2054); the machine-Z branch
  [:1645-1672](MPCNC_v4.0_Beta2.cps#L1645).
- **The change** —
  1. Multi-WCS ⇒ require homed X/Y/Z, `Home at Job Start`, and a travel height. **All
     four properties already exist.**
  2. Traverse emits `G53 G0 Z<travel>` — correct regardless of any WCS's Z0.
  3. Machine does not home ⇒ refuse in **one** sentence naming the real reason:
     *"multi-part work needs a homed machine; post one job per part."*
  4. **Do not delete the spoilboard path here.** Step 2 does that, after this is proven.
- **Done when** — the 1.1 job posts on GRBL with only Group 4 properties set, and the
  traverse is `G53`-framed. **Read the emitted file; do not infer it.**
- **Findings** — closes 1.1's row; re-scopes CR-13, which made Guard B unconditional.

### 1.3 — Post the six `PReview.md` §3.1 jobs

- **Goal** — the 21% stops being unverified.
- **Why** — §3.1: *"needs a job nobody has posted yet… This is the largest untested area
  in the post."* The expected output is **already written** for PB1, PB2, PBV1, PBV2,
  PBV3 and PA1, so this is checking, not designing. `[AUTHOR]` confirms the gap is
  deliberate deferral — professional testing postponed to get Beta3 stable for hobby
  users — which makes this **the step that discharges the deferral**.
- **Where** — `docs/PReview.md` §3.1, now in the tree (**C1**).
- **The change** — none to the post unless a row fails. Keep the files beside the
  existing 24 in `Documents/Fusion 360/NC Programs/HB-Tests/`, where the hobby-path
  evidence already lives.
- **Done when** — six posted files exist; every §3.1 row ticked or carrying a finding.
- **Note** — PA1 and PB2 reference `Retract Across Parts`, **deleted by CR-13**. Those
  rows need re-scoping before they can be run; that is itself a §3.1 finding.
- **Prompt**
  > docs/PReview.md §3.1 has six unchecked rows (PB1, PB2, PBV1, PBV2, PBV3, PA1) with
  > expected output already written. I will paste posted output one row at a time.
  >
  > For each: compare emitted output against the row's expectation. Report **only**
  > differences, and for each say whether it is (a) the post being wrong, (b) the
  > expectation being wrong, or (c) an F360 behaviour neither anticipated. Quote the
  > emitted lines.
  >
  > Note that PA1 and PB2 mention `Retract Across Parts`, which CR-13 deleted — flag
  > any row whose expectation predates a change that has already landed.
  >
  > Propose the register rows. Do not propose code until every row is read: several may
  > share one cause.

---

## Step 2 — Retire the spoilboard base

- **Goal** — Group 5 ceases to exist; one property survives, in Group 4.
- **Why** — **the subsystem's premise defeats itself.** It exists to give a
  **non-homing** machine a common Z frame for multi-part traverses. But multi-part
  traverses require homing, by the post's own guard at
  [:1669](MPCNC_v4.0_Beta2.cps#L1669). **No machine both needs it and can use it.**
  Three further reasons: its principal hazard is *"mitigation is documentation, not
  code"* by `design.md`'s own admission; it consumes one of GRBL's six registers; and
  four of the seven open findings live in it.
- **Where**
  | What | Where | ~Lines |
  |---|---|---|
  | `writeBaseEstablish()` | [:2998](MPCNC_v4.0_Beta2.cps#L2998) | ~79 |
  | Reserved-base agreement guards | [:1622-1643](MPCNC_v4.0_Beta2.cps#L1622) | ~22 |
  | Slot check, Guard B′, Guard A | [:1708-1729](MPCNC_v4.0_Beta2.cps#L1708) | ~22 |
  | `baseOriginWriteReason()` | [:1406-1431](MPCNC_v4.0_Beta2.cps#L1406) | ~26 |
  | `getReservedBaseWcs()` | [:2042](MPCNC_v4.0_Beta2.cps#L2042) | ~12 |
  | `fixedZEstablishedAtStart/InFile()` | [:2071-2099](MPCNC_v4.0_Beta2.cps#L2071) | ~28 |
  | 4 of 5 Group 5 properties + descriptions | group at [:117](MPCNC_v4.0_Beta2.cps#L117) | ~90 |
- **The change** — delete the above. **Keep `spoilboardTravelZ`**, rename to
  `machineTravelZ`, move to `groupDefinitions.machine`. `getFixedZReference()`
  [:2005](MPCNC_v4.0_Beta2.cps#L2005) reduces to one branch, so the enum becomes a
  boolean or disappears into *"is there a travel height and is the machine homed?"*.
- **Done when** — ~250–300 lines gone; 10 groups → 9; the Step 1.3 files still post.
  **Re-post at least two of the six** — a deletion under a verified baseline is the only
  kind that can be checked.
- **Findings** — CR-11, CR-12, CR-14 and PR-8 close **by deletion**. Each row must say
  the code was removed rather than repaired. `06-retention.md` already frames this
  correctly: *"that is not lost work, it is work that stops being needed."*
- **Prompt**
  > Assessment/07-code-map.md argues the spoilboard-base subsystem should be deleted:
  > multi-part traverses require a homed machine (see the post's own error text at the
  > `homedXY` check in `validateJob`), while the spoilboard base exists to serve
  > machines that do not home — so no machine both needs it and can use it.
  >
  > **First, try to refute that.** Find any configuration where the spoilboard base is
  > the only workable answer — including single-WCS jobs, jet/laser tools, and any path
  > where `Fixed Z Reference = Spoilboard` changes output without a WCS change. Search
  > every reader of `getFixedZReference`, `usesMachineZDatum`, `getReservedBaseWcs`,
  > `fixedZEstablishedInFile` and `fixedZEstablishedAtStart`. Report before proposing.
  >
  > If it survives, propose the deletion as diffs in reviewable pieces. For each piece
  > list the findings it closes and any behaviour change for a **single-WCS** job —
  > which must be none.

---

## Step 3 — Marlin multi-WCS: delete Guard C, add a version floor

- **Goal** — Marlin users can run multi-WCS jobs, above a stated firmware version.
- **Why** — `05-history.md`. Marlin with `CNC_COORDINATE_SYSTEMS` has **nine** WCS
  registers, individually selectable, **persistent with EEPROM** `[DOC]`. Guard C's
  message — *"Marlin has a single coordinate frame"* — is **a false statement emitted to
  the user**, and `design.md` line 23 is its source. The post already cited the same
  build flag correctly for `G53` forty lines above
  ([:1646-1649](MPCNC_v4.0_Beta2.cps#L1646)); the two facts never met on one page.
- **Where** — Guard C [:1689-1694](MPCNC_v4.0_Beta2.cps#L1689); RepRap-only slot gate
  [:1709-1712](MPCNC_v4.0_Beta2.cps#L1709); write dialect in `writeWCS()`
  [:1860](MPCNC_v4.0_Beta2.cps#L1860); and `probeOnChange`'s description at
  [:416](MPCNC_v4.0_Beta2.cps#L416), which **asserts the false claim to the operator**.
- **The change** —
  1. **Delete Guard C.**
  2. Slot gate becomes "not GRBL" — Marlin has `G59.1`–`G59.3` via `parser.subcode`.
  3. **Keep the write dialect**: `G10 L20 P<n>` on GRBL/RepRap, `G5x` then `G92` on
     Marlin. This is the one real difference — Marlin can only write the **active**
     register, and only positionally. For *selection* there is full parity, and
     selection is all a multi-WCS job needs.
  4. **State a minimum firmware version** `[AUTHOR]`. Two reasons, both needed:
     `CNC_COORDINATE_SYSTEMS` is a **build option**, so a stock Marlin lacks it; and
     `[DOC]` Marlin issue **#14743** reported `G92` inside `G54` corrupting the `G53`
     machine origin — closed, fix version not established from the issue page.
  5. **Record the homing hazard.** `set_axis_is_at_home()` runs
     `position_shift[axis] = 0` (`motion.cpp`), and re-sending `G54` does **not**
     restore it because `select_coordinate_system()` early-returns when that system is
     already active. **On Marlin, homing silently detaches the program from its own work
     origin.** Tier 2 firmware knowledge; `design.md` does not have it.
- **Blocked on** — the version floor. `CLAUDE.md` requires firmware questions settled
  from the firmware's own source and changelog, citing file and version. **Establishing
  which Marlin release fixed #14743 is a prerequisite, not a documentation
  afterthought** — and it is the one question this review could not close.
- **Done when** — a two-WCS Marlin job posts; `design.md` line 23 **rewritten, not
  annotated**; the version floor appears in the property description and
  `guide-hobbyist.md`; the homing hazard is in `design.md`'s firmware table.
- **Findings** — new row for Guard C; new row for the false property description.
- **Prompt**
  > Marlin 2.1.x with `CNC_COORDINATE_SYSTEMS` enabled has nine work coordinate systems:
  > `MAX_COORDINATE_SYSTEMS` = 9 in `Marlin/src/gcode/gcode.h`; `G54`–`G59.3` select
  > them in `G53-G59.cpp`; `G92` writes `coordinate_system[active_coordinate_system]` in
  > `G92.cpp`; the header comment says *"with EEPROM support they may be restored from a
  > previous session"*. V1's MarlinBuilder enables the flag.
  >
  > **Verify all of that against the source yourself before acting on it**, citing file
  > and version per CLAUDE.md.
  >
  > Then: (a) find every place in the post that assumes Marlin is single-frame — Guard
  > C, the RepRap-only WCS slot gate, and any property description asserting it to the
  > operator; (b) determine from Marlin's changelog which release fixed issue #14743
  > (`G92` in `G54` altering the `G53` origin), so a minimum version can be stated;
  > (c) confirm whether `set_axis_is_at_home()` still zeroes `position_shift`, and
  > whether re-selecting the same workspace restores the offset.
  >
  > Report findings first. Then propose diffs for the code and for docs/design.md line
  > 23 — which is the origin of the wrong premise and must be rewritten, not footnoted.

---

## Step 4 — Group 6: keep the touch-off, delete the orchestration

- **Goal** — 10 properties → 9, **14 enum decisions → 9**, and nothing offered that the
  firmware cannot do.
- **Why** — `06-retention.md` carries the property-by-property verdict. Two drivers:
  1. **Four of ten enum options do not work on the default firmware.** The post says so
     itself at [:399](MPCNC_v4.0_Beta2.cps#L399): *"THE TWO JOG MODES DO NOT WORK ON
     GRBL, the default firmware."* Two on `probeOnStart`, two on `probeOnChange`,
     protected only by a warning.
  2. **`probeOnChange` is the orchestration**, which `[AUTHOR]` assigns to the operator
     — and after Steps 2 and 3 the question it asks does not arise: select `G55`, and
     the register the operator already set is right.
- **Where** — `probeOnStart` [:397-413](MPCNC_v4.0_Beta2.cps#L397); `probeOnChange`
  [:414+](MPCNC_v4.0_Beta2.cps#L414); `writeWcsOnStart()`
  [:3145](MPCNC_v4.0_Beta2.cps#L3145); `partProbe()`
  [:3100](MPCNC_v4.0_Beta2.cps#L3100); `writeWCS()`
  [:1860](MPCNC_v4.0_Beta2.cps#L1860).
- **The change** —
  1. `probeOnStart`: **six modes → three.** Keep `Current XY & Probe Z` (default),
     `Current XYZ`, `Probe Z`. **Merge** `Skip` into `Probe Z` as a boolean — they
     differ only in whether Z is probed. **Delete both Jog modes.**
  2. **Delete `probeOnChange`.** Replace with at most one boolean — *"re-probe Z at each
     WCS change"*, default off — for the operator whose parts differ in height.
  3. **Retitle the group.** *"On WCS / Part / Fixture Changes"* says when it fires; it
     should say what the operator is deciding — the work origin. *(A title change does
     not reset settings; a key change does.)*
  4. **Shorten the descriptions.** `probeOnStart`'s is ~1,900 characters, so the GRBL
     warning buried inside it is not read. Three modes is what makes it short enough to
     work.
- **Keep untouched** — `probePause`, `probeOffsetX/Y`, `probeG382orG28`,
  `probeG38Target`, `probeG38Speed`, `probeSafeZ`, `probeThickness`. These are the Z
  touch-off mechanics, they answer to S1, and **every one is confirmed by emitted
  output** (`G38.2 F30 Z-10`, `G10 L20 P1 Z0.8`, `M0 (MSG Attach ZProbe)`). Best-evidenced
  block in the post.
- **Done when** — no offered option is non-functional on any supported firmware, and the
  24 hobby files in `HB-Tests/` re-post **byte-identically** for the surviving modes.
- **Findings** — new row for the non-functional options; PR-11 re-scoped.
- **Prompt**
  > In MPCNC_v4.0_Beta2.cps, `probeOnStart` ("First WCS / Part") offers six enum modes
  > and `probeOnChange` ("Subsequent WCS / Part") offers four. `probeOnStart`'s own
  > description says the two Jog modes do not work on GRBL, the default firmware.
  >
  > Establish the facts first: for each of the ten options, which firmwares can actually
  > execute it, and what does the post emit? Quote the emitting code. Settle whether a
  > genuine jog-at-pause exists on GRBL and on Marlin **from firmware source**, not from
  > the post's own comments.
  >
  > Then propose, as separate diffs: (a) `probeOnStart` reduced to three modes, merging
  > the stored-XY-with/without-probe pair into one mode plus a boolean; (b) deleting
  > `probeOnChange`, since Assessment/04-user-stories.md assigns multi-part orchestration
  > to the operator; (c) a group retitle without a key change.
  >
  > For each, list which files in `Documents/Fusion 360/NC Programs/HB-Tests/` would
  > change output. The answer should be none — tell me if it isn't.

---

## Step 5 — Group 7: split it, and build 7b on include files

Independent of Steps 1–4; can run in parallel. **`[AUTHOR]`: this group has not been
reviewed or tested.** Eight properties, ~65 lines, five open findings, and **zero posted
files exercising a tool change** — none of the 24 has more than one tool.

### 5.1 — 7a: *"end this file so a manual tool change costs nothing"*

Personal licence, answering **S3** and **S13**. Five rules, four of them removals:

1. **It is an option, not a policy** — S3 as corrected: *"the **option** for a posted
   file to end…"*. The last file of a sequence carries no tool-change scaffolding.
2. **Never home at end-of-file on Marlin.** Homing zeroes `position_shift` and
   re-selecting `G54` does not restore it, so **homing detaches the next file from the
   origin this one established.** The single concrete safety rule to come out of S13.
3. **`toolChangeDisableZStepper` already gone** — Step 0.2.
4. **Fix the frame of the park position.** `toolChangeX/Y/Z` emit plain `G0` words and
   are therefore WCS-relative; the post's own comment at
   [:3657-3658](MPCNC_v4.0_Beta2.cps#L3657) says *"the spot drifts"*. Either emit `G53`
   and require homing, or rename the fields to say they are work-frame. **Not both
   meanings on one field** — PR-4, open.
5. **Leave the work origin untouched.** No `G10 L20`, no `G92`, at end of file. That is
   the whole point of 7a.

### 5.2 — 7b: mid-program tool change, driven by F360

**`[AUTHOR]`, and this was the gap in my previous answer:** *"someone is making the
actual tool change happen and remeasuring the tool length… on these firmwares there is
no such support, or at a minimum there must be the inclusion of gcode files that do that
operation."*

**Completing it.** A measured tool change needs a probe, a **subtraction**, and a
register to hold the result. The firmwares split on the subtraction
(`03-f360-and-firmware.md` §5a):

| | Probe | Arithmetic | TLO register | So who does it |
|---|---|---|---|---|
| **RepRapFirmware** | `G38.2` | **Yes** — meta G-code | `G10 L1 P<t> Z`, persisted by `M500 P10` | **The machine**, via a `tpost` macro |
| **GRBL / FluidNC** | `G38.2` | **No** — no variables, no expressions | `G43.1 Z<offset>` needs a literal | **The sender's** tool-change macro |
| **Marlin** | `G38.2`\* | **No** | **none exists** | **The operator** — re-probe, re-zero work Z |

So `design.md`'s bare *"no TLO"* is too strong — GRBL has `G43.1`, RepRap has a real
tool table — **and none of the three answers is the post.** The post cannot compute an
offset it will not learn until the operator swaps the tool, hours after posting.

**Therefore 7b's deliverable is a contract, not a routine:**

1. **A stop in a known place, in a stated frame** — `M0`, at a position the operator
   chose, frame documented per 5.1 rule 4.
2. **A named include-file hook at exactly that point.** Group 8 already implements
   include files, is 36 lines, and is verified in the posted files —
   `HB-12(A).gcode.failed` even shows the empty-file abort working. **The mechanism
   exists.** The operator drops in their RRF macro call, sender trigger, or
   probe-and-rezero sequence. One feature, correct on all three firmwares, because the
   part only the operator can know is supplied by the operator.
3. **A written contract for that file** — which frame is active, where the tool is, what
   the file may change, what it must restore. Without this the hook is a trapdoor.
4. **Fix the WCS bug first, on its own.** `probeTool()` *"writes into the PREVIOUS
   section's WCS"* — the post's own comment at
   [:3691-3692](MPCNC_v4.0_Beta2.cps#L3691). A probe result in the wrong register is a
   crash on the next plunge. A bug, not a design question.

\* Marlin's `G38.2` needs its own build flag — same minimum-version statement as Step 3.

### 5.3 — Close the five findings against the split

PR-4, HR-7 (`toolChange()` clobbers `forceSectionToStartWithRapid`), HR-8 (post-injected
motion never updates F360's tracked position), HR-9 (`Do First Change` with
probe-after-change off zeroes Z against the wrong tool), HR-13. With 7a and 7b
separated each becomes a small change in **one** path rather than a change to shared
code — which is why the split comes first.

- **Done when** — a **posted two-tool job** exists. The acceptance test is emitted
  output, not a code review.
- **Prompt**
  > Group 7 of MPCNC_v4.0_Beta2.cps is two features sharing one 65-line `toolChange()`:
  > (a) end-of-file, leave the machine tool-changeable — personal licence, where F360
  > emits no tool change at all; (b) mid-program, driven by F360's
  > `tool.manualToolChange` — professional. Five open findings live in the overlap
  > (PR-4, HR-7, HR-8, HR-9, HR-13).
  >
  > Map it first: for each of the 8 `toolChange*` properties and each branch of
  > `toolChange()` and `probeTool()`, say which feature it serves, or both. Quote the
  > code. Identify every place the two share state.
  >
  > Then propose the split as a sequence of diffs. Constraints:
  > – (a) must be optional; must not home on Marlin (homing zeroes `position_shift`, and
  >   re-selecting the same workspace does not restore it); must not write the work
  >   origin.
  > – (b) must not attempt to compute a tool length — GRBL and Marlin have no
  >   arithmetic. It emits a stop plus a named include-file hook reusing Group 8, with a
  >   written contract for what that file may assume and must restore.
  > – `probeTool()` writing into the previous section's WCS is a bug: fix it as its own
  >   commit, **first**, before any restructuring.
  >
  > For each diff, name the finding rows it closes.

---

## Step 6 — Clarity

Only after 1–5, because they delete much of what would otherwise be tidied.

- `validateJob()` is **288 lines** at [:1448](MPCNC_v4.0_Beta2.cps#L1448). Step 2
  removes ~44 and Step 3 ~6. **Re-measure before restructuring** — it may not need it.
- The property block is **795 lines, 21% of the file.** Steps 2 and 4 remove ~150 of
  description alone. Re-measure.
- **634 comment-only lines: leave them.** `b7d12fb` already trimmed the commentary, and
  this review depended on those comments repeatedly — the Guard C / `G53` contradiction,
  *"the spot drifts"*, *"writes into the PREVIOUS section's WCS"*, the `M84` hazard note,
  *"THE TWO JOG MODES DO NOT WORK ON GRBL"*. **Every one of the sharpest findings here
  came out of a comment the post wrote about itself.** That is an argument for keeping
  them.

---

## Step 7 — Documents, once

`CLAUDE.md` puts the guides off-limits during code changes. Do it all here — per-step
means rewriting `guide-pro.md` three times.

| Document | What falls due |
|---|---|
| `docs/design.md` | **Line 23 rewritten** — Marlin has nine registers. **Add** the Marlin homing/`position_shift` hazard, the minimum firmware version, the corrected TLO table, and what Step 1.3 emitted. **Remove** the spoilboard-base sections. The only document where a wrong row is expensive: it is the project's most valuable asset and it is where Guard C came from |
| `docs/property-reference.md` | Regenerate. 72 → ~60 properties; Groups 5 and 11 gone; Group 6 retitled. Marker reads `@ 17a20f2` and is **19 commits stale before this plan starts** |
| `docs/guide-pro.md` | State the **operator's** obligations explicitly — every work offset set before the job, one clearance clearing every fixture, machine homed. `04-user-stories.md` shows this is the assumption the G-code depends on and that F360 nowhere states it. And say plainly what is verified and what is not |
| `docs/guide-hobbyist.md` | Group 7a's end-of-file behaviour in its own right; the Marlin do-not-home rule; the minimum Marlin version |
| `README.md` | Feature list and the hobbyist/professional split |
| `docs/PReview.md` | §3.1 ticked; findings resolved. Then consider the register consolidation in `10-project-cleanup.md` — **after** this step |

---

## Preserve list — must survive whatever else happens

- **Nine verified bug fixes:** `5a6a4e0` (GRBL `%` wrapper), `b84f602` (feedrate leak),
  `b61c005` (missing include refused), `cb1c9f2` (drag before offset probe), `ec5af37`
  (homing that homes nothing), `ae0e013` (plane modal escaping an include), `eea70d1`
  (Safe-Z separator), `1c5fcce` (`>>> WARNING:` at Comment Level Off), `e5db625`
  (unparseable Safe Z).
- **The firmware knowledge in full** — `174c4df`, `2b5dfd5`, and every sourced fact in
  `design.md`'s tables **except line 23**. Cannot be re-derived from F360.
- **`writeMachineHoming()`**, the `workOffset 0` → WCS 1 alias, the `>>> WARNING:`
  channel, the seventeen dialog-simplification commits, Group 8 entire.
- **Group 6's touch-off mechanics** — the best-evidenced block in the post.
- **Tier 3 revised:** CR-11, CR-12, CR-14 and PR-8 are **superseded by Step 2's
  deletion**, not preserved. `06-retention.md`'s framing holds — *"not lost work, work
  that stops being needed."* CR-13 and `556a378` survive.

## Delete list

| What | ~Lines | Risk |
|---|---|---|
| Spoilboard base subsystem (Step 2) | ~250–300 | Medium — gated on Step 1 |
| `probeOnChange` + 4 Jog modes (Step 4) | ~100 | Low |
| `toolChangeDisableZStepper` + `M84 Z` | ~12 | None — it is a hazard |
| Guard C | ~6 | Low — it blocks supported behaviour |
| Group 11 folded | ~20 | Very low |
| Group 10 coolant surplus | ~50 | Low — pending persona |
| `parkCanRetract()` alias | ~4 | Very low |

**~450–500 lines.** Four times the previous version's figure, and it comes from three
decisions rather than a campaign to shrink the file.

## Blocked list

| Blocked | Waiting on | What it changes |
|---|---|---|
| **C4's second half** | **Step 1.1** | Whether the guide can call the multi-WCS feature *blocked* rather than *unverified*. **The first half is not blocked** — the deferral is already `[AUTHOR]`-confirmed, but **the whole item is deferred by the author** as of 2026-08-13, so this row is moot until that reverses |
| **Steps 2 and 4** | **Step 1.1 + 1.2** | Whether the homed path actually posts |
| **Step 3's version floor** | Marlin changelog for #14743 | Whether Marlin multi-WCS can be claimed at all |
| Step 5's verification | a full-licence posted two-tool file | 7b cannot be checked without one |
| §3.1 rows PA1, PB2 | re-scoping against CR-13 | Their expectations predate a landed change |
| Group 10 reduction | a coolant persona | ~50 lines |
| Group 9 audit | laser detail — power scaling, `M3`/`M4` dynamic power, enable sequencing, air assist | Whether 7 properties is right. **Persona confirmed but unexercised by any test** |

---

## The three questions, answered plainly

### Group 6 — was the instinct right?

**Yes, and more specifically than either of my first two answers.**

My first reading was that the post reaches into F360's job. **Wrong** — F360 never
learns where the fixtures are, so it cannot compute a path between work offsets and does
not claim to. *(I originally reached this by quoting `design.md`, which was the wrong
method — it is under audit. The conclusion survives on Autodesk's machine-definition
files instead: `03-f360-and-firmware.md` §1a.)*

My second reading was that the machinery serves a user who does not exist. **Wrong** —
the author confirms the user, and F360 has a feature for them.

**What is actually true is narrower and worse:** the machinery serves a real user by a
route that user cannot take. F360's "Multiple WCS Offsets" job **does not post at all**
in the default configuration, and the subsystem built to make it safe — the spoilboard
base — exists for machines that cannot home, while the workflow requires homing. So:

> **Not over-built in general. Over-built in one place, for a machine that cannot use
> the feature — and under-verified everywhere else, by a deliberate deferral nothing
> in the repository states.**

The remedy is Step 1 (unblock), Step 2 (delete the part with no user), and Step 1.3
(post the six jobs). Roughly 300 lines out and the seven findings closed.

### Group 7b — how does a full-licence tool change actually work, end to end?

The operator assigns a tool per operation in F360. Where consecutive operations differ,
the CAM engine flags the boundary and, for tools marked manual, sets
**`tool.manualToolChange`** on the tool object handed to the post. **The post is told;
it detects nothing.** Autodesk's whole response is three lines — stop, comment naming
the tool, resume — wrapped in a Z retract, coolant off, cancel length compensation.

This post never reads the flag; on the professional path it asks the same question again
through `toolChangeInsertCode`, and its own comments admit the result parks in a frame
that drifts and probes *"into the PREVIOUS section's WCS."*

**Two corrections to my own earlier answers.**

*First:* I recommended reading the flag and deleting the duplicate control. On a personal
seat **F360 never emits a tool change at all**, so there is no flag — that change would
have broken the hobby path. Two features sharing a function, not one feature with a
switch. **Split them.**

*Second, and this was the incomplete half:* **somebody has to physically change the tool
and re-establish its length, and on these firmwares nothing does that for free.** The
complete answer is the table in 5.2 — the machine can do it on RepRap, the sender must
on GRBL, and only the operator can on Marlin, because Marlin has no TLO register at all
and neither GRBL nor Marlin can do arithmetic. **So the post's deliverable is a stop, a
named include-file hook, and a written contract** — one mechanism that is correct on all
three, because the piece only the operator knows is supplied by the operator. Group 8
already provides the machinery.

### Clearance and Z-trust — is computing a safe height the post's job?

**No, and Autodesk agrees in code.** Unchanged by anything in this round, and now with
better evidence behind it.

"Z untrusted" means the controller was never told where its own frame is, so an absolute
machine height is not approximately right — it is arbitrary. A relative lift is always
**exact**; only its *sufficiency* is unknown. That is the sharper form of S8, and it is
why a warning is the correct response and an error is not: erroring would refuse the
project's founding user, the hand-zeroed hobbyist, who is 24 of the 24 posted files.

When Autodesk's own post is in this situation it emits *"Ensure the clearance height will
clear the part and or fixtures. Raise the Z-axis to a safe height before starting the
program."* A warning and a comment. Nothing else.

**And the new evidence strengthens it.** F360 has a machine-frame safe-Z slot —
`getRetractPlane()` — and **no way for an operator to fill it**: zero occurrences in 211
machine definitions, `setRetractPlane` commented out in all 159 posts that mention it.
So the post asking for a travel height is **filling a hole, not duplicating a field**,
and non-goal N3 is withdrawn.

**The mechanism already exists** — the `>>> WARNING:` channel that bypasses Comment
Level, visible working in `HB-9(A).gcode` and `HB-13(A)-off.gcode`. Extend it; do not
replace it with arithmetic. The legitimate exception stays: where the program **itself**
homed, the frame is known for the rest of that program and an absolute retract is honest
— a condition the post can verify, because it emitted the homing command.
