# Assessment status ledger

Over-engineering assessment of `MPCNC_v4.0_Beta2.cps`. This file is the
resumability contract: if the session dies, this says exactly how far it got.

Reviewed HEAD = `CoverageFixes` (3,758 lines).
**All 11 steps DONE. Revised twice — 2026-08-12 (four blocking answers) and
2026-08-13 (scope reconciliation, three firmware corrections, and the first posted-output
evidence in the review).**

**Now on branch `Assessment`**, cut from `CoverageFixes` on 2026-08-13. `d010fee` restores
`docs/PReview.md`, `40fc3c7` adds these twelve documents, `b0ffc33` schedules Phase C, a fourth
commit executes C2/C3/C5, a fifth closes C6 and checks Steps 0 and 1 for readiness, and a sixth
**lands the first post code of the plan — Step 0.3, 0.4 and 0.6.** `CoverageFixes` is itself
unmerged into `master`, so this branch sits on unmerged work — which stopped being merely
academic the moment that sixth commit landed.

**Phase C is done except C4.** `C0` `C1` `C2` `C3` `C5` complete; **`C4` deferred by the
author**; **`C6` closed by deleting both branches unread**, one remote command outstanding;
`C7` `C8` `C9` are records, not actions. Nothing in Phase C touched the post.

**Step 0 is COMPLETE.** 0.1 · 0.3 · 0.4 · 0.6 landed; **0.2 deferred** to the complete tool-change
solution; **0.5 closed with no edit**, group 11 left standing until the `PR-` pass. See *Step 0
executed* below: three of its four active items departed from their own written instructions, and
two registered "complete diffs" turned out to be unsafe. **`REG-MF` was never invalidated** — no
property was added, removed, renamed or relocated, so the property dump has not moved. **The next
unfinished thing in the plan is Step 1.1**, which needs a Fusion keyboard.

**Three things Phase C turned up that the plan did not predict:**

1. **C2's four pointers were six.** Found by running C2's own Done-when rather than trusting
   its table. The two extra were `docs/conventions.md`:24 — whose contract row said
   ***"nothing may be filed against it"***, a standing ban on using the register `CLAUDE.md`
   had just been repointed at — and `.claude/commands/close-finding.md`:12, inside the
   procedure that files findings. A seventh statement, `docs/plan.md`:73–75, was excusing
   that file's budget overrun on the registers being absent.
2. **The Checkpoint's Baseline was wrong three ways, not one.** Besides the branch, it said
   *"`master` is 16 commits ahead of `origin/master` and nothing has been pushed."* It is
   **6** ahead, and `git reflog show origin/master` records a push on **2026-08-09**
   (`94241ec`).
3. **C6 is one branch, not two — and the author then closed it by deleting both.**
   `origin/GRBL_Fixes` is an **ancestor** of `origin/UpdateToolChange`. Both last moved
   **2023-11-19** and both edit `MPCNC.cps`, a filename that no longer exists. On those facts
   the ruling was to delete them unread rather than read them, reversing both of C6's
   conclusions. **The page had valued them as records of attempts without ever checking what
   file they edit or how far the post had moved** — unmerged is not the same as valuable.

**One thing left open for the author: `docs/plan.md` is 143 lines against a 120 budget.**
C3 did not cause the overrun but removed its stated excuse — ~30 lines at :46–77 exist only
because both registers were out of the tree, and both are back. Trimming another author's
Checkpoint history is not a mechanical edit, so it was flagged in the file and not done.

## New evidence that arrived on 2026-08-13

This round was driven by evidence, not opinion. Three sources the review did not have:

| Source | What it settled |
|---|---|
| **24 posted files** at `Documents/Fusion 360/NC Programs/HB-Tests/` `[POSTED]` | First direct look at emitted output. The `>>> WARNING:` channel works; `G10 L20 P1` and the probe cycle are verified; five `error()` aborts land as designed. **And all 24 are single-operation, single-tool, single-WCS** — a precise measure of the test gap |
| **`OneDrive/…/GCode/Andrew.gcode`** | F360's own licence banner. **`C2` closed** by the vendor's words |
| **211 cached F360 machine definitions** + Marlin/RRF firmware source | **Reversed one of my own claims** and **refuted one of `design.md`'s** |

## Corrections this round — three of mine, one of the project's

**Mine:**

1. **`machineConfiguration` does not hold the operator's clearance height.** I wrote that
   a post asking for one *"is duplicating a field F360 already has."* Wrong. `retractPlane`
   appears in **0** of 211 machine definitions; `setRetractPlane` is **commented out** in
   all 159 posts that mention it; there is no `getHomePositionZ()` at all. `getRetractPlane()`
   **is** a machine-frame safe Z — and it is an empty hook, so **non-goal N3 is withdrawn**
   and the post's travel-height property is filling a hole. `03-f360-and-firmware.md` §1a.
2. **RepRapFirmware has nine work coordinate systems, not one.** I let Autodesk's stock
   `reprap.cps` (`range:[1,1]`) stand in for a firmware fact. **The post already had this
   right** — more accurate than Autodesk's own RepRap post.
3. **My `E1` "RAM-only" reconciliation was false in every part.** Marlin's registers
   persist and every slot is reachable. Withdrawn.

**The project's:**

4. **`design.md` line 23 — *"Marlin is single-frame: no per-WCS registers"* — is false.**
   Marlin with `CNC_COORDINATE_SYSTEMS` has **nine**, persistent with EEPROM `[DOC]`. So
   **Guard C refuses jobs the firmware would run**, and its message is a false statement
   shown to the user. The post had already cited the same build flag correctly for `G53`
   forty lines above; the two facts never met on one page. **That is the clearest single
   justification for this whole review.**

### On using `design.md` as evidence — the author's correction, accepted

The author challenged this sentence in the previous STATUS.md:

> *"I first concluded the post was usurping F360's job. Wrong — `design.md` rebutted it
> correctly."*

**The challenge is right, and it lands on more than one place in these documents.**
`design.md` is under audit here; it cannot be its own evidence. And the audit has now
found a false premise in it, which settles the point.

**The rule, now explicit** (`05-history.md`): `design.md` is authoritative about *intent*
and useful as a *pointer to primary sources*. It is **not** evidence that a claim about
F360 or a firmware is true.

Re-grounded on primary sources, one rested claim held and one failed:

- **The cross-frame clearance argument holds** — on Autodesk's machine-definition files
  and on how F360 generates a multi-fixture job, not on `design.md`.
- **`Marlin is single-frame` failed.**

### And the question the author actually asked

> *"…unless the CNC operator's assumption is that all fixtures for multi-parts are the
> same and therefore being clear of one will be clear of the others if the WCS for each
> has Z0 set the same… but this is a CNC operator and F360 agreement that I don't know to
> be true. Is it?"*

**Close, but the real convention is narrower — and it is not how the problem is actually
solved.** Full answer in `03-f360-and-firmware.md` §3a. In short:

- **F360 guarantees nothing.** "Multiple WCS Offsets" gives it **two integers** — a count
  and a stride. It never learns where any fixture is, so it cannot compute or check a path
  between them.
- **The convention is not "identical fixtures."** It is: *every work offset in the job has
  its Z0 at the same physical height, and the clearance clears everything on the path.*
  X/Y offsets can be anything. Identical fixtures are how people usually satisfy that, not
  the condition itself.
- **Production shops do not rely on it.** They traverse in the **machine** frame — `G53`,
  `G28`, `G30` — which is correct whatever any WCS's Z0 is, and needs no agreement with
  anyone. Three of Autodesk's four `safePositionMethod` options are machine-frame.

**And that single fact restructured the plan**, because a machine-frame traverse needs a
homed machine — which the post already requires for multi-part work, at
[MPCNC_v4.0_Beta2.cps:1669](MPCNC_v4.0_Beta2.cps#L1669).

## The headline, revised

> ### Not over-built in general. Over-built in one place — for a machine that cannot use the feature — and under-verified everywhere else by a deliberate deferral that nothing in the repository states.

Three findings behind it:

1. **It is blocked, not just untested.** `[AUTHOR]` An F360 Setup with **"Multiple WCS
   Offsets"** ticked **fails to post.** The whole 21% serves a supported F360 feature that
   cannot currently produce a file.
2. **The spoilboard base has no user.** It exists to give a *non-homing* machine a common Z
   frame for multi-part traverses — but multi-part traverses require homing, by the post's
   own guard. **No machine both needs it and can use it.** ~250–300 lines, four of the
   seven open findings.
3. **The deferral was deliberate and is undocumented.** `[AUTHOR]` *"the professional level
   tests have not yet been done. Goal was to get a Beta3 that was stable for hobby users."*
   Sound sequencing — and the 24 posted files prove it was executed. What is missing is the
   **gate**: `guide-pro.md` describes unverified behaviour in the same voice as verified
   behaviour.

## Net effect on the plan

| | Original | 08-12 | **08-13** |
|---|---|---|---|
| Lines to delete | ~780 | ~110 | **~450–500** |
| Target size | ~2,900–3,150 | ~3,650–3,800 | **~3,300–3,450** |
| Property groups | 11 | 10 | **9** — Groups 5 and 11 go |
| Groups deleted | Group 5 | none | **Group 5, Group 11** |
| Guards deleted | none | none | **Guard C** |
| Enum options that don't work on GRBL | 4 | 4 | **0** |
| Critical path | the S12 decision | post the six §3.1 jobs | **unblock the F360 feature, *then* post them** |
| Open findings at target | 1 | 0 | **0** |

**The scope decision did not reverse.** S12 is in scope. What changed is the author's
separation of the multi-part **workflow** (in scope, the post must not block it) from the
multi-part **orchestration** (the operator's). Serving that user turns out to need far
less code than has been written for it.

## Step ledger

| Step | File | State | Conclusion |
|---|---|---|---|
| 0 — facts needed | `00-facts-needed.md` | DONE — **`C2` and `E1` now CLOSED** | `E1` settled from Marlin source; `C2` from F360's banner. **One new blocker:** which Marlin release fixed #14743 |
| 1 — personas | `01-personas.md` | DONE | 7 personas. P6 laser and P7 multi-fixture confirmed. **Autodesk ships no Marlin post** — the project's strongest reason to exist |
| 2 — Z-trust | `02-z-trust.md` | DONE — **now evidenced** | Absolute machine-Z is illegitimate unless this program homed. The `>>> WARNING:` channel is visible working in `HB-9(A)` and `HB-13(A)-off` |
| 3 — F360 + firmware | `03-f360-and-firmware.md` | DONE — **heavily revised** | §1a machineConfiguration (reversal), §3 the `workOffset 0` guard, §3a how F360 generates multi-fixture, §4 **rewritten** — 6/9/9 slots, all three persist, §5a TLO, §5b WCS probing, §6 `C2` closed |
| 4 — user stories | `04-user-stories.md` | DONE — freeze lifted twice, marked in place | S3 reworded to *"the option"*; N2 merged and N2b's method re-grounded; **N3 withdrawn**; N6 confirmed as the WCS First/Subsequent verdict; S13's TLO ladder and corrected Marlin fragility; **the S12 scope reconciliation** |
| 5 — project history | `05-history.md` | DONE — **two new sections** | The `design.md`-as-evidence rule; §3.1's deferral explained `[AUTHOR]`; **`Marlin is single-frame` refuted** |
| 6 — retention | `06-retention.md` | DONE — **per-property verdicts added** | Reset closed. **Group 6: 10 properties → 9, 14 enum decisions → 9.** Four of ten options don't work on GRBL — the post says so itself |
| 7 — code map | `07-code-map.md` | DONE — **verdicts revised a second time** | Group 6 is **blocked**, not untested; **Group 5 retires**; Group 7 gets concrete recommendations and 7b moves onto Group 8's include-file hook |
| 8 — the target | `08-target.md` | DONE — revised | ~3,300–3,450 lines, ~60 properties, **9 groups**, 0 findings, 6 posted multi-part jobs, ≥1 posted tool-change job |
| 9 — the path | `09-plan.md` | DONE — **rewritten, given a Phase C, and Phase C and Step 0 now executed** | **Phase C (C0–C9) + 8 steps**, each with Goal / Why / Where / The change / Done when / Findings / **Prompt**. `C0` `C1` `C2` `C3` `C5` done, `C4` deferred, `C6` closed unread; **Step 0 complete — 0.3 / 0.4 / 0.6 landed, 0.2 deferred, 0.5 closed unedited** |
| 10 — project cleanup | `10-project-cleanup.md` | DONE — **now scheduled, not just recommended** | **`PReview.md` restored and committed.** Its items are `09-plan.md` Phase C; this page keeps the reasoning. `design.md` owes six changes including a rewritten line 23 |

## Readiness for Steps 0 and 1 — checked 2026-08-13

**Step 0: ready, and it is the only work that can start from the repository alone.** The post is
**untouched at 3,758 lines** — the exact tree the plan was written against — so every line
reference holds; spot-checks were exact. Every symbol Steps 0 and 1 name exists. Both registers
are in the tree. Phase C is done and C6 gates nothing.

**Step 1: nothing is missing, but the whole step waits on the author.** 1.1 produces evidence at a
Fusion keyboard, and 1.2 and 1.3 queue behind it. The **licence is not a barrier for 1.1** — Guard
B fires on `!usesMachineZDatum() && collectDistinctOffsets().length > 1`, which never reads the
licence, and the refusal precedes any rapid. Step 5's verification is the one that needs a full
licence.

**Four defects the readiness check found in the plan itself. Three are fixed in `09-plan.md`; one
is a decision.**

1. **0.2 and 0.6 sent their register rows to the wrong file.** Both close professional ids —
   **HR-10 and HR-13 live in `docs/PReview.md` and nowhere else**; `grep` finds neither in
   `HReview.md`, because the duplicate stubs were deleted on 2026-08-07 to stop precisely this.
   Following the old prompt would have re-created the failure that cost seven ids. **Fixed.**
2. **0.2's fix contradicts HR-10's registered fix, and 0.2 is the right one.** `PReview.md`:262-277
   holds a complete diff that **keeps** the property and guards it by firmware — warn on GRBL,
   still emit the bare `M84 Z` on Marlin, with a Pass line requiring `M84 Z` **present** there. The
   post's own comment at :1827-1828, on that same non-GRBL branch, says a bare `M84` *"releases at
   once, and an unbalanced LowRider gantry with no brake sinks in Z when it does."* **The
   registered fix leaves the documented hazard standing on the only firmware that can execute
   it.** HR-10 was filed as a dialect bug and is also a safety bug; the two facts were in
   different files. 0.2 must **supersede** the diff and **rewrite the Do→Get row**, not apply it.
   **Recorded in the plan.**
3. **0.2's acceptance count was wrong at both ends** — *"Properties 72 → 71."* A direct count of
   the properties literal (:123-952) gives **66**, so it is 66 → 65. `plan.md`'s 69 is also stale,
   predating CR-13 and `bf0c2bd`. **`doc-sync` cannot arbitrate — it is 19 commits behind.**
   **Fixed.**
4. **The decision: Step 0 invalidates a baseline that has never been established.** `plan.md`'s
   outstanding item 0 (REG-MF) expects a diff of *"the property dump, the Resolved-Values block
   and every `F` word."* **0.2 and 0.5 delete three properties between them.** Post REG-MF first,
   or accept re-posting it after Step 0 — but decide it deliberately. **Resolved by not arising:**
   both items were declined, so no Step 0 commit moved the dump. See below.

## Step 0 executed — 2026-08-13

**0.3, 0.4 and 0.6 are landed code. 0.2 is deferred by the author** to the complete tool-change
solution, with Phase 4 and HR-7 / HR-8 / HR-9. **0.5 is closed with no edit** — the two Duet fields
stay and group 11 is left standing until the `PR-` findings are handled. **Step 0 is done.**

**The `REG-MF` collision never happened.** No item that landed adds, removes, renames or relocates
a property, so the property dump has not moved and the factory-default baseline can be posted
whenever there is Fusion time. It was avoided by the two items that would have caused it — 0.2 and
0.5 — being declined on their own merits, not by sequencing around it. **It returns at Step 5**,
which splits group 7, and at whatever the `PR-` pass does with group 11.

**Three of the four items departed from their own written instructions, and every departure came
from checking the plan's claim instead of executing it.**

- **0.3 — the reason belongs in `error()`, not in a `>>> WARNING:` comment.** The plan said emit a
  warning comment and keep `cycleNotSupported()`. But `cycleNotSupported()` calls `error()`, so the
  post **aborts and writes no file**: the comment would have gone into output the operator never
  receives, while the dialog — their only channel — kept Autodesk's generic text. One
  `error(localize(…))` replaces it, matching the tool-orientation and radius-compensation refusals.
  Filed as **PR-12**, ✅ fixed.
- **0.4 — landed exactly as written**, and it is the only item with no register row behind it.
- **0.6 — the registered diff was wrong in both halves.** *(a)* It used
  `writeComment(eComment.Important, …)`, which is gated on Comment Level — so at `Off` the fix
  would have vanished exactly like the silence it fixes, re-opening `HReview.md` **HB-9**. Landed
  through `writeWarning()`. *(b)* `case COMMAND_OPTIONAL_STOP: M1` is **refused on the firmware's
  own source**: grbl 1.1 `grbl/gcode.c` has `case 1: break; // Optional stop not supported.
  Ignore.` — no pause, no error; RepRapFirmware `src/GCodes/GCodes2.cpp` handles `case 0: // Stop`,
  `case 1: // Sleep`, `case 2: // Stop` in one block, so mid-file `M1` **ends the job**; only
  Marlin does what Fusion means. **The diff would have shipped a no-op on the default firmware and
  a job abort on another.** HR-13 is **◑ part-fixed**: the silence is gone, *Optional stop* is
  honoured nowhere, and promoting it to `M0` is filed as a dialog question in `PReview.md` §6.

**The lesson to carry into Step 1: a complete diff sitting in a register is a proposal that was
never run, and its age is not evidence.** Two of the three registered diffs Step 0 touched were
unsafe or self-defeating.

**No output byte moves on an ordinary job** — 0.4 is a pure inline, 0.3 fires only on a probing
cycle, 0.6 only on a command the `switch` does not name, and every command the post routes itself
is named. `REG-S0` in `PReview.md` §3.8 is the row that proves it.

## What to do first

1. ~~Commit the restored `docs/PReview.md`~~ — **done**, `d010fee` (C1).
2. ~~**Phase C, C2 and C3**~~ — **done**, and C3 landed before C5 as required.
3. ~~**C5, the thirteen merged branches**~~ — **done**, `git branch -d`, tips recorded in the
   commit message. `git branch` now lists three. **No remote branch was touched**, and remote
   deletion remains the one irreversible action on that page.
4. ~~**Step 0**~~ — **complete.** 0.3, 0.4 and 0.6 landed; 0.2 deferred; 0.5 closed with no edit.
5. **Step 1.1: reproduce the "Multiple WCS Offsets" failure and file it.** **Now the next
   unfinished thing in the plan**, and nothing in the repository blocks it. The critical path:
   cheap, and able to invalidate Steps 2–4 — which is exactly why it goes first. Needs a Fusion
   keyboard; the paste-ready prompt is written. **`REG-MF` can be posted in the same sitting** —
   the property dump never moved, so the baseline is still available from `HEAD`.
6. ~~**0.5 — group 11**~~ — **closed 2026-08-13 with no edit: the fields stay, and group 11 is left
   standing until the `PR-` findings are handled.** Deletion was refused, and the reason got
   stronger under checking: **both defaults are RRF 2.x g-code**, and on RRF 3.x `M453` is parsed
   for `S` alone, so `M453 P2 I0 R30000 F200` sets no pin, no max RPM and no PWM frequency **and
   reports no error** — filed as **PR-13**, with `GCodes2.cpp` citations from tags `2.05` and
   `master`. `07-code-map.md` had said *"keep or fold"*; `09-plan.md` transcribed it as *"fold"* and
   wrote an acceptance count that assumed deletion. The one surviving option — relocating both
   `group:` attributes beside the firmware selector, which changes no key and resets nothing —
   rides with PR-13, so the dialog move and the default rewrite cost one baseline instead of two.
7. ~~**C6's read**~~ — **overruled by the author, and now closed.** The two branches were over two
   years old and edit `MPCNC.cps`, a filename the project no longer has, so they were deleted
   unread. `git push origin --delete UpdateToolChange GRBL_Fixes` was **run by the author on
   2026-08-13**. The local tags `archive/UpdateToolChange` (`690e586`) and `archive/GRBL_Fixes`
   (`385edaf`) still anchor the tips — **they are now the only refs that reach that history**;
   `git tag -d` drops them if it is genuinely unwanted. **C6 gates nothing.**
8. **`docs/plan.md`'s 20-line overrun** — decide the trim or raise the budget. See above.
9. ⏸️ **C4 — a status line in `guide-pro.md`. Deferred by the author 2026-08-13.** Not
   rejected and not blocked: its first half needs nothing from Step 1.1, so it waits on a
   decision rather than on evidence. Until it lands, `guide-pro.md` describes the
   multi-fixture path in the same voice as the 24-file-verified hobby path — a known,
   accepted gap now rather than an oversight.

## Environment

- No full-licence Fusion 360, no hardware, no sender, no dry run. Every F360/firmware claim
  carries an evidence tag; `[AUTHOR]` marks facts asserted by the project owner;
  `[POSTED]` marks emitted output read from disk.
- Web access: **used** — Marlin 2.1.x source (`G53-G59.cpp`, `G92.cpp`, `gcode.h`,
  `motion.cpp`, `G28.cpp`), Marlin issues #14734/#14743, Duet3D GCode dictionary, gnea/grbl
  wiki, V1 Engineering docs and MarlinBuilder.
- Local `[SDK]` evidence: **carried the review** — 490 cached Autodesk posts and **211
  machine definitions** at `AppData/Local/Autodesk/Autodesk Fusion 360/CAM/cache/`.
  **No `marlin.cps` exists.**
- **Repo changes made**, all at the author's instruction: branch `Assessment`;
  `docs/PReview.md` restored (`d010fee`); `Assessment/` committed (`40fc3c7`); Phase C
  scheduled (`b0ffc33`); then **C2/C3/C5 executed** — edits to `CLAUDE.md`, `docs/plan.md`,
  `docs/conventions.md`, `Coverage/CoverageFixes.md` and
  `.claude/commands/close-finding.md`, plus thirteen local branch deletions; then **C6 closed**
  and **Step 0.3 / 0.4 / 0.6 landed**.
- **`MPCNC_v4.0_Beta2.cps` is edited from Step 0 onwards** — this line said *"no post code
  edited"* until 2026-08-13. 3,758 → 3,786 lines, `node --check` passing, and **no output byte
  moves on an ordinary job** (`REG-S0`). Register rows were written with it, in the same commit,
  to `docs/PReview.md` (PR-12, HR-13, HR-10, PR-8, §3.8, §6) and `docs/HReview.md` (HB-17).
  **No memory writes and no remote refs touched**, still.
- **Document budgets after Step 0:** `CLAUDE.md` 60/60, `conventions.md` 295/300,
  `plan.md` **143/120** — the open item above. `PReview.md` is **1,167** against a stated
  *"≤ 920, and falling"*: it grew 49 lines here, because a register that carries a landed fix has
  to carry its Do→Get row too. That budget was written for a file expected to shrink as the
  professional review closed it out, and it retires when the review runs; it is not a reason to
  file a row somewhere else, which is how seven ids went stale.
- **Measurement convention.** PowerShell's `Measure-Object -Line` counts only **non-empty**
  lines — it reported `PReview.md` at 972 where git counted 1,118, and a "correction" on
  this page was wrong for a day because of it. Use `(Get-Content $f).Count` or
  `git diff --stat`.
