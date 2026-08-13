# Step 10 — Cleaning up the project

Judged by one test: **does it help someone execute `09-plan.md`, or does it cost
effort to keep true?**

> **Scheduled 2026-08-13.** The items that pass that test are now **Phase C** at the head
> of `09-plan.md`, as C0–C9, each with a Goal / Why / Where / Done when. **This page is the
> reasoning; Phase C is the schedule.** Two things changed in the transfer, both recorded
> below: the branch work is **done** (C0, C1), and **C2 is new** — restoring `PReview.md`
> falsified four statements in three documents, which is the ordinary cost of a restore and
> had to be paid somewhere. Everything still unperformed is marked as such.

---

## 1. The registers — one urgent problem, then a consolidation

### `docs/PReview.md` must come back into the tree — ✅ **DONE 2026-08-13**

**Restored at the author's instruction and committed to branch `Assessment` as `d010fee`:
1,118 lines, 99,153 bytes.** Per `CLAUDE.md` that commit describes the restore and takes
no finding prefix, since it builds no finding of its own. **Done.**

*(Measurement note, twice corrected: 1,118 is right. I reported 1,118, then "corrected" it
to 972, then git reported 1,118 insertions. `Measure-Object -Line` counts only non-empty
lines — 972 of the 1,118 have content. Use `(Get-Content $f).Count` or `git diff --stat`
for a line count on this platform; the same trap applies to every line-count figure in
these documents.)*

The reasoning below is kept because it explains why this was first on the page, and
because item 6 — the policy question — is **not** resolved by the restore.

It was out of the tree entirely, recoverable only as `git show 347ce5d:docs/PReview.md`.
Nobody browsing this repository would ever have found it. And it contains:

- **18 findings, 7 of them open**, including all five tool-change findings the
  unbuilt "Phase 4" blocks
- **§3.1, the multi-part test register** — the six unposted jobs whose outcome
  decides ~780 lines of code
- **§6, the design backlog** of unbuilt work

So the single document that determines the biggest decision in `09-plan.md` is
invisible to anyone who does not already know it exists. `CLAUDE.md` records that it
is out of the tree *"until the professional review runs"* — but the review cannot run
if its own register cannot be found.

**With S12 confirmed in scope this is urgent rather than tidy.** `09-plan.md` Phase 1
*is* §3.1 — those six jobs and their already-written expected output are now the
critical path for the whole project. **The critical path currently lives outside the
tree.**

**Recommendation: restore it, immediately, before any of Phase 1.** Whatever
reasoning justified removing it is outweighed by the fact that this assessment could
only reach its central conclusion because a `git show` happened to be in the
instructions.

### Three id namespaces for one project

Findings currently live as `HB-nn` and `HR-nn` in `docs/HReview.md`, `CR-nn` across
four `Coverage/` files, and `HR-nn` **again** plus `PR-nn` in `PReview.md`. The `HR-`
prefix spans two files by design — `PReview.md` explains the ids are *"kept
deliberately"* so history, `HReview.md` and itself all name the same defect the same
way.

That reasoning is sound, and `CLAUDE.md` already records the cost of getting it
wrong: *"a row split across two files is how seven ids went stale."*

**Recommendation:** one register file, `docs/findings.md`, with the prefixes preserved
(`HB-`, `HR-`, `CR-`, `PR-`) as historical origin markers and a single status column.
Closed rows collapse to one line each — id, subject, resolving commit. The four
`Coverage/` files (3,263 lines) become one section; `CoverageReviewPlan.md` and
`CoverageReview.md` are process records of a finished review and can be archived
wholesale.

**Do this after Phase 2**, not before: Phase 1's posted jobs and Phase 2's tool-change
split will close or re-scope a dozen rows, and consolidating first means doing the work
twice.

## 2. The driving documents

`docs/plan.md` (13 KB), `docs/conventions.md` (24 KB), `docs/design.md` (22 KB).

**Three is the right number**, and the split is principled: what is next / how to
work / why the behaviour is what it is. Keep all three.

**`design.md` is the project's most valuable document** — and **revised 2026-08-13, it
is also the one with a false row in it, and it does shrink.**

Two things changed here. First, the author's correction of method, which applies to this
whole review: **`design.md` is under audit and cannot be used to prove anything.** It is
authoritative about *intent* and useful as a *pointer to primary sources*; it is not
evidence that a claim about F360 or a firmware is true. See the head of `05-history.md`.
I broke that rule twice; one conclusion survived on independent evidence and one did not.

Second, what it now owes:

| # | Change | Why |
|---|---|---|
| 1 | **Line 23 rewritten, not annotated** | *"Marlin is single-frame: no per-WCS registers"* is **false.** Marlin has nine, individually selectable, persistent with EEPROM `[DOC]`. This is the row that produced Guard C, which refuses jobs the firmware would run |
| 2 | **Add: Marlin homing clears the applied workspace offset** | `set_axis_is_at_home()` runs `position_shift[axis] = 0`, and re-sending `G54` does not restore it — `select_coordinate_system()` early-returns. **Homing silently detaches a program from its own work origin.** Tier 2 knowledge, absent today |
| 3 | **Add: minimum Marlin firmware version** | `CNC_COORDINATE_SYSTEMS` is a build option, and issue #14743 reported `G92`-in-`G54` corrupting the `G53` origin |
| 4 | **Correct the TLO row** | *"no TLO, no tool setter"* is too strong: GRBL has `G43.1`, RepRap has `G10 L1` plus `M500 P10`. Only Marlin has none. This changes what a tool change can be on each firmware |
| 5 | **Remove the spoilboard-base sections** | The *Frames* base-transit rules, R1/R2 and the fixed-Z tables describe a subsystem `09-plan.md` Step 2 deletes |
| 6 | **Add: what Step 1.3's six posted jobs emitted** | Once the multi-part workflow is verified, *what was observed* becomes a durable fact of the same species as the firmware table — the most expensive knowledge in the project and the easiest to lose again |

**So the earlier judgement is reversed on two counts:** it does shrink (item 5), and the
`E1` note I proposed adding was itself wrong — I suggested recording that Marlin's array
is *"RAM-only with no addressable per-slot write."* Both halves are false. **Do not add
that clause.** Rewrite the row instead.

**What still stands:** the firmware tables are the project's most valuable asset, and
the reason is visible in this very correction — a wrong row in that table cost a guard,
a property description and a paragraph of `design.md`, and it survived because two
related facts were established at different times and never met on one page. **The table
is the fix, not the problem.** Every other sourced row in it should be protected
exactly as before.

## 3. The user guides — flag, do not touch

`README.md`, `docs/guide-hobbyist.md`, `docs/guide-pro.md`,
`docs/property-reference.md`. `CLAUDE.md` puts these off-limits during code changes
and **that stands** — nothing in `09-plan.md` should touch them until Phase 4.4.

But there is a live problem worth recording now:

**`property-reference.md` is already stale.** Its marker reads
`doc-sync: MPCNC_v4.0_Beta2.cps @ 17a20f2`, and **19 commits have changed the post
since that ref.** It is out of date before this assessment begins.

What the plan will oblige, and when:

| Document | What falls due | When |
|---|---|---|
| `property-reference.md` | Regeneration — 72 → **~60** properties; **Groups 5 and 11 gone**; Group 6 retitled and reduced to 9; Group 4 gains `machineTravelZ` | Step 7, once |
| `guide-pro.md` | **Two obligations now, not one.** (a) State the **operator's** side of multi-fixture work explicitly — every work offset set before the job, one clearance clearing every fixture, machine homed. `04-user-stories.md` shows this is the assumption the emitted G-code depends on and that F360 nowhere states it. (b) **Say what is verified and what is not** — professional testing was deliberately deferred `[AUTHOR]`, and nothing in the repository says so | Step 7 |
| `guide-hobbyist.md` | The Group 7a end-of-file behaviour in its own right; **the Marlin do-not-home rule**; the minimum Marlin firmware version | Step 7 |
| `README.md` | The feature list and the hobbyist/professional split it advertises | Step 7 |

**Regenerate once, at the end.** Doing it per-step means rewriting `guide-pro.md` three
times.

Note that **Group 3 needs no documentation change**: its premise is now
`[SDK]`-confirmed from F360's own emitted header, and its behaviour is unchanged.

### The one documentation finding that is not a sync

**`guide-pro.md` currently describes unverified behaviour in the same voice as verified
behaviour.** That is the *gate* `05-history.md` identifies as missing: the deferral of
professional testing was a sound decision, and the only thing wrong with it is that a
reader cannot tell. This is the cheapest item in the whole plan and the one with the
clearest safety argument — a hobbyist who believes the multi-fixture path is finished
will run it into a fixture.

It should not wait for Step 7. **A status line in `guide-pro.md` is worth writing the
day Step 1.1 confirms the feature does not post.**

> **Scheduled as `09-plan.md` C4, and split** — because half of it is not waiting on
> anything. The *deferral* is already `[AUTHOR]`-confirmed, so the "what is verified, what
> is not" line can be written today; only the sentence naming the feature **blocked** waits
> for 1.1 to turn a report into a reproduced defect.
>
> **And C4 is the one Phase C item that must be asked for.** `CLAUDE.md` puts the guides
> off-limits *"during code changes, only when asked"*. Phase C is not a code change — but
> that rule exists to stop precisely this kind of drive-by edit, so C4 is proposed rather
> than scheduled.

## 4. The tooling

| Item | Verdict |
|---|---|
| `.claude/hooks/post-edit.js` | **Keep.** Runs `node --check` on every edit — cheap, catches the one error class that would ship a broken post |
| `docs/doc-sync.js` | **Keep, and it becomes more valuable.** It answers the one question a diff cannot: whether `property-reference.md` still matches the post. During a purge that removes ~22 properties this is the only mechanical check on the documentation |
| `/checkpoint` | **Keep.** Reads `plan.md` → Checkpoint; ten-line orientation |
| `/close-finding` | **Keep**, but it will need updating if the registers consolidate (item 1) |
| `docs/check-docs.js` | **Already retired** (524 lines, `46bcf2a`) for gating more than a document contract can carry. Correct call |

**Nothing left has `check-docs.js`'s problem.** `doc-sync.js` checks one factual
correspondence rather than trying to enforce prose quality, which is exactly the
distinction the retirement drew. No further tooling change recommended.

## 5. The branches

**15 local, 22 remote. Fourteen of the fifteen local branches are fully merged into
`master`** — everything except `CoverageFixes` (HEAD).

**Safe to delete locally, now:** `Coverage_Review`, `beta3`, `comment-clean-up`,
`hobby-dialog-review`, `retire-doc-gate`, `v4.0-beta2`, `v4.0-dev`,
`v4.0-doc-streamline`, `v4.0-f360-compliance`, `v4.0-float-compare`,
`v4.0-hreview-fixes`, `v4.0-readme-update`, `wcs-reworked-flow`. Thirteen branches,
zero risk — the work is all in `master`. Keep `master` and `CoverageFixes`.

> **Re-verified 2026-08-13** against `git branch --merged master`: the same thirteen, and
> now **three** to keep — `master`, `CoverageFixes` and the new `Assessment`. Two cautions
> that only appeared once this was scheduled as **C5**:
>
> - **`hobby-dialog-review` is the branch `docs/plan.md`'s Checkpoint currently sends every
>   session to.** Delete it before fixing the Checkpoint (**C3**) and a stale pointer
>   becomes a broken one. C3 goes first.
> - **`CoverageFixes` is itself not merged into `master`**, and `Assessment` was cut from
>   it. Irrelevant to review documents; it matters the moment a code step lands, because
>   the eventual merge carries two ranges rather than one.

**Two remote branches carry unmerged work, and both matter to this plan:**

- **`origin/UpdateToolChange`** — unmerged. Given that `09-plan.md` Phase 2 rewrites
  the tool-change path, **read this before writing any new code there.** It may
  already contain part of the answer, or a rejected approach worth knowing about.
- **`origin/GRBL_Fixes`** — unmerged. Firmware fixes are Tier 2 material; anything
  real in here belongs in the preserve list.

**Recommendation: examine both before Phase 2, delete neither.** The other 20 remote
branches are merged and can be pruned at leisure — but remote deletion is the one
irreversible item on this page, so it should be a deliberate separate action, not
folded into any code phase.

> **Dated 2026-08-13, and the count was wrong: there is one line of work here, not two.**
> `origin/GRBL_Fixes` is an **ancestor** of `origin/UpdateToolChange` — its seven commits are
> contained in the other, which adds two of its own. Both last moved **2023-11-19**
> (`UpdateToolChange` 17:38 −0800, `GRBL_Fixes` 14:00 −0800), two years nine months ago.
>
> **Both edit `MPCNC.cps`**, a filename the project no longer has, so neither can be merged
> or cherry-picked — anything wanted must be re-applied by hand. And the FluidNC premise is
> spent: four of the shared commits are FluidNC work, and FluidNC is already in the post,
> `design.md`, `conventions.md`, `README.md` and `guide-hobbyist.md`. What survives is a
> two-commit read, scheduled as **`09-plan.md` C6**. **Neither branch was deleted**, and no
> remote ref was touched by C5.

## 6. One thing to add rather than remove

`CLAUDE.md` currently says `PReview.md` is out of the tree *"until the professional
review runs."* Whatever happens to the S12 decision, that arrangement has cost this
project the visibility of its own most important open questions.

**Recommendation:** if a document is too unfinished to live in the tree, it is too
unfinished to hold the only copy of seven open findings. Either the findings move to
the main register, or the document comes back. Not both out of sight.

> **Scheduled as the second half of `09-plan.md` C2.** The restore settled the instance;
> this settles the rule, and one sentence in `CLAUDE.md` does it. Worth doing while C2 has
> that file open anyway — the four stale pointers and the policy live in the same paragraphs.
>
> **The four pointers C1 falsified**, verified 2026-08-13: `CLAUDE.md`:14–15 and :34,
> `docs/plan.md`:120–121, `Coverage/CoverageFixes.md`:227. Note that `CLAUDE.md`:34's rule
> — a professional finding stays in the register it was filed in — **survives in
> substance**; it loses only its *"until `PReview.md` returns"* clause.
>
> **✅ DONE 2026-08-13 — and there were six, not four.** Running C2's Done-when instead of
> trusting the list above found `docs/conventions.md`:24, whose contract row said
> ***"nothing may be filed against it"*** — a standing prohibition on using the register, and
> the worst of the six — and `.claude/commands/close-finding.md`:12, inside the procedure that
> files findings. A seventh, `docs/plan.md`:73–75, justified that file's budget overrun on the
> registers being absent.
>
> **The policy is settled as a rule about registers, not about this file**, so it binds the
> next one too. `CLAUDE.md` → *Registers ship with the code* now carries: **"no register lives
> outside the tree: too unfinished to commit is too unfinished to hold the only copy of an open
> finding."** `conventions.md`:24 states the same judgement where the prohibition used to be.
