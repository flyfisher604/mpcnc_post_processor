# Plan — what is next

The only file that says what is next. Findings and tests are `findings.md`; why the post
behaves as it does is `design.md`.

## Checkpoint — read this first

**Baseline.** Branch **`Assessment`**, 31 commits ahead of `master`. `CoverageFixes`
contributes 18 of them and is **itself unmerged**, so a merge to `master` carries two
ranges, not one. `master` is 6 commits ahead of `origin/master`; `Assessment` is unpushed.

**What is true now.** Phase C, Step 0 and **Steps 1.1 and 1.2 are done and closed** — a
multi-WCS job posts, and on a machine declared homed it posts with every group-5 field left
at its default. `PR-14` closed with 1.2. The post is otherwise untouched by this plan.

**What is next: Step 1.3, nearly closed** — the multi-part jobs in `findings.md` §4.1. **Eight
rows passed 2026-08-14** — `PB1`, `PB2`, `PBV1`, `PBV2`, `PBV3` and, off those artifacts, three
of the four boundary dispatches `M1`, `M2`, `M4`. **What is left is `PA1`/`PA1b`, `P2`/`P3` and
`M3`**, and `PA1` is the only one needing a job that does not exist yet. All take the derived
machine frame; seven spoilboard rows are retired unrun rather than posted against code Step 2
deletes. **Two findings were filed off these runs** — `PR-17`, an `Inter Part Travel Z` at or above
machine zero on a default GRBL build, unwarned; and `PR-18`, two warnings offering a jog mode in the
same dialog that refuses it on GRBL. **`PB1` was reposted 2026-08-14 with that height moved `1` → `0`
and its row passes again**, which *sharpened* `PR-17` rather than closing it: machine Z `0` is the
homing switch's own trigger point, not the ceiling, so the repair tests `>= 0` and the highest safe
value is the pull-off `-$27`. The repost also **destroyed the first `PB1` artifact and moved two
other variables with the height** — §4's reused-filename warning, earned.

**Live risk.** `HR-6 (B)` — the orientation guard may be a no-op on exactly the case it
exists to catch, and the failure mode is a part cut in the wrong plane, silently. It needs a
rotated Setup. `findings.md` → *Owed*.

**No controller access.** Firmware questions are settled from firmware source, citing file
and version.

**Line numbers below are from 2026-08-13 and will have moved.** Locate by symbol name and by
quoted comment text, never by line number.

---

## What is left, in order

| | Item | Blocked on |
|---|---|---|
| **1.3** | Post the six multi-part jobs — `findings.md` §4.1 | — |
| **2** | Retire the spoilboard base | 1.3 |
| **3** | Marlin multi-WCS: delete Guard C, add a version floor | a Marlin changelog reading |
| **4** | Group 6: keep the touch-off, delete the orchestration | 2 and 3 |
| **5** | Group 7: rebuild the tool change as two flows | — (parallel with 1–4) |
| **V** | Post-verify what has landed unposted | — |
| **6** | Clarity | 1–5 |
| **7** | Documents, once | 1–6 |

**Step 1 is first among the code steps because it is the only one that can invalidate the
others.** Steps 2–4 assume F360 emits a multi-WCS job a particular way, read from Autodesk's
post source rather than observed. **Step 5 is independent** and can run in parallel.

---

## Step 1.3 — Post the six multi-part jobs

- **Goal** — the largest untested area in the post stops being unverified.
- **Where** — `findings.md` §4.1. The expected output is **already written** for PB1, PB2,
  PBV1, PBV2, PBV3 and PA1, so this is checking, not designing.
- **The frame is fixed for every row** — `Axes Homed and Trusted` = `XYZ`, `Inter Part Travel
  Z` an absolute machine Z, `Fixed Z Reference` left at `None`. **Post nothing with a
  `Reserved WCS`:** Step 2 deletes that code, and `findings.md` §4 retires its seven rows.
- **What is actually being proved is origin-mode dispatch.** `PR-2a` already proved the frame
  and the traverse on this job with both probe modes at `Skip`; §4.1 is what happens at each
  boundary when they are not.
- **The change** — none to the post unless a row fails. **None has** — `PR-17` and `PR-18` are
  findings the runs exposed, not row failures.
- **Done when** — six posted files exist; every §4.1 row ticked or carrying a finding. **Five
  exist**; `PA1` is the sixth and is the only job still to be built.

## Step 2 — Retire the spoilboard base

- **Goal** — group 5 ceases to exist; one property survives, in group 4.
- **Why** — **multi-part and multi-WCS work belongs to the full-licence user, and that machine
  homes.** The spoilboard answer exists to give a **non-homing** machine a Z frame, and it buys
  that with one of GRBL's six registers, a probe cycle whose Z0 is whatever happens to be under
  the tool, a second meaning for `Inter Part Travel Z`, and five properties that are only
  correct together. **The setup burden is real and the failure is silent** — `PR-16`. A homed
  machine already has the frame, for nothing.
- **Where** — `writeBaseEstablish()` :2998 (~79); reserved-base agreement guards :1622-1643
  (~22); slot check, Guard B′, Guard A :1708-1729 (~22); `baseOriginWriteReason()` :1406-1431
  (~26); `getReservedBaseWcs()` :2042 (~12); `fixedZEstablished*()` :2071-2099 (~28); four of
  five group 5 properties (~90). **Locate by call site, not by that list** — search every
  reader of `getFixedZReference`, `usesMachineZDatum`, `getReservedBaseWcs`,
  `fixedZEstablishedInFile` and `fixedZEstablishedAtStart`.
- **The change** — delete the above, **including `spoilboardFixedZRef` entire**: no enum, no
  boolean replacing it. **Keep `spoilboardTravelZ`**, rename `machineTravelZ`, retitle
  `Machine Travel Z`, move to `groupDefinitions.machine`. `getFixedZReference()` :2005 becomes
  *declares Z homed **and** the height parses*, **ungated by offset count** — the field is the
  opt-in, and it ships empty. The target is `design.md` → *▶ Target — the fixed Z reference*;
  build against that section, not against this bullet.
- **Two behaviours change, both intended, and neither is a pure deletion.** A multi-part job on
  a machine declared **not** homed posts today by reserving a base — Guard B sits inside the
  `base == 0` arm and never runs when one is — and afterwards Guard B refuses it. And a
  **single-WCS** job gains the frame when the height is filled, where the offset-count gate
  denied it: a real `G53` arrival, and a retract before the machine park crosses the bed.
- **`PR-2e`'s artifact goes stale**, not wrong: the header echo loses the *derived from the
  declaration* clause, there being no dialog answer left to distinguish it from. Re-baseline it
  with the two re-posts below.
- **Done when** — ~250–300 lines gone; 10 groups → 9; the Step 1.3 files still post.
  **Re-post at least two of the six** — a deletion under a verified baseline is the only kind
  that can be checked.
- **Findings** — `PR-16` and `HR-26` close **by deletion**; each row must say the code was
  removed rather than repaired. `CR-11`, `CR-12`, `CR-14` and `PR-8` are **already closed by
  repair** — their code goes with the subsystem and their §3 rows do not change.

## Step 3 — Marlin multi-WCS: delete Guard C, add a version floor

- **Goal** — Marlin users can run multi-WCS jobs, above a stated firmware version.
- **Why** — Marlin with `CNC_COORDINATE_SYSTEMS` has **nine** WCS registers, individually
  selectable, persistent with EEPROM. Guard C's message — *"Marlin has a single coordinate
  frame"* — is **a false statement emitted to the user**, and `design.md` is its source. The
  post already cited the same build flag correctly for `G53` forty lines above.
- **Where** — Guard C :1689-1694; RepRap-only slot gate :1709-1712; write dialect in
  `writeWCS()` :1860; `probeOnChange`'s description :416, which **asserts the false claim to
  the operator**.
- **The change** — delete Guard C; slot gate becomes "not GRBL"; **keep the write dialect**
  (`G10 L20 P<n>` on GRBL/RepRap, `G5x` then `G92` on Marlin — Marlin can only write the
  *active* register, and only positionally, but for *selection* there is full parity and
  selection is all a multi-WCS job needs); **state a minimum firmware version**; and record
  that **on Marlin, homing silently detaches the program from its own work origin** —
  `set_axis_is_at_home()` zeroes `position_shift` and re-sending `G54` does not restore it.
- **Guard C is not the only refusal, and deleting it alone changes nothing.** A multi-part job
  needs a fixed Z frame, and on Marlin the job falls through Guard C into **Guard B′ today and
  Guard B after Step 2**, refused either way. **The frame question is a design question, not a
  firmware limit** — Marlin homes Z, and until the job's first `G92` its one frame *is* the
  machine frame; it is the post's own origin write that ends the correspondence. `design.md` →
  *▶ Target — the fixed Z reference* states it exactly. Two candidate routes, neither settled:
  a flow that never writes `G92 Z`, or cancelling the shift — **and whether Marlin implements
  `G92.1` is not in this record; settle it from source before either is designed.** The
  homing route is poisoned independently: `G28 Z` re-establishes the frame but
  `set_axis_is_at_home()` zeroes `position_shift`, detaching the job from the origins it is
  traversing between.
- **Settle what Marlin multi-WCS is *for* before writing code** — a real frame, or a refusal
  whose message is finally true. Guard C's text is a false statement either way, so it is worth
  fixing even if the answer is that the refusal stands.
- **Blocked on the version floor.** `CNC_COORDINATE_SYSTEMS` is a build option, and Marlin
  issue **#14743** reported `G92` inside `G54` corrupting the `G53` origin. **Establishing
  which release fixed it is a prerequisite, not a documentation afterthought** — and it is the
  one question the assessment could not close.
- **Done when** — a two-WCS Marlin job posts; `design.md`'s Marlin row **rewritten, not
  annotated**; the version floor is in the property description; the homing hazard is in
  `design.md`'s firmware table.

## Step 4 — Group 6: keep the touch-off, delete the orchestration

- **Goal** — 10 properties → 9, **14 enum decisions → 9**, and nothing offered that the
  firmware cannot do.
- **Why** — **four of ten enum options do not work on the default firmware**, and the post
  says so itself at :399: *"THE TWO JOG MODES DO NOT WORK ON GRBL, the default firmware."*
  And `probeOnChange` is orchestration, which is the operator's; after Steps 2 and 3 the
  question it asks does not arise — select `G55`, and the register the operator already set
  is right.
- **Where** — `probeOnStart` :397-413; `probeOnChange` :414+; `writeWcsOnStart()` :3145;
  `partProbe()` :3100; `writeWCS()` :1860.
- **The change** — `probeOnStart` **six modes → three**: keep `Current XY & Probe Z`
  (default), `Current XYZ`, `Probe Z`; **merge** `Skip` into `Probe Z` as a boolean; **delete
  both Jog modes**. **Delete `probeOnChange`**, replaced by at most one boolean — *re-probe Z
  at each WCS change*, default off. Retitle the group to say what the operator is deciding.
  Shorten `probeOnStart`'s ~1,900-character description; three modes is what makes that
  possible. **`PR-18` closes here** — two `validateJob()` warnings recommend a Jog mode, and the
  clauses go with the modes; search the warning texts for `"Jog to ..."`, not just the enums.
- **Keep untouched** — `probePause`, `probeOffsetX/Y`, `probeG382orG28`, `probeG38Target`,
  `probeG38Speed`, `probeSafeZ`, `probeThickness`. **The best-evidenced block in the post** —
  every one confirmed by emitted output.
- **Done when** — no offered option is non-functional on any supported firmware, and the 24
  hobby files in `HB-Tests/` re-post **byte-identically** for the surviving modes.

## Step 5 — Group 7: rebuild the tool change as two flows

Independent of 1–4. **The shipped design is being replaced, not repaired** — the design is
`design.md` → *Tool changes*, and `PR-15` is the one finding that the code does not comply
with it. Eight properties, ~65 lines, **zero posted files exercising a tool change**, and
after the register deletion **zero test rows** either.

- **Goal** — the post arrives correctly, hands over, and resumes correctly. It performs no
  tool change itself, in either flow.
- **Where** — `toolChange()`; `probeTool()`; `onSection()`'s call order around `writeWCS()`;
  group 7 entire; `includeProbeFile` in group 8.

**5.1 — Flow 1: end this file so a manual tool change costs nothing.** The Personal-licence
answer, and an **option, not a policy**. The work origin survives untouched — no `G10 L20`, no
`G92`, and **no homing at end of file**, which on Marlin detaches the next file from the origin
this one established. **The park gets one frame and says which**: `toolChangeX/Y/Z` emit plain
`G0` words and are WCS-relative, and the post's own comment at :3657 says *"the spot drifts"*.

**5.2 — Flow 2: call the macro and get out of the way.** Pre-change setup, the call, the
resume — nothing else. **The deliverable is the contract, not a routine:** what state the
macro may assume, what it may change, what it must restore. Without it the call is a trapdoor.
**Blocked on which token the sender keys on** — `findings.md` §6 holds the question, and it is
the first one in this project that no firmware source can close.

**5.3 — the shared corrections both flows need**, listed at the foot of `design.md`'s section.
**Take the ordering one first and on its own:** `onSection()` calls `toolChange()` before
`writeWCS()`, so a re-probe writes into the previous section's register — the post's own
comment at :3691 says so — and a probe result in the wrong register is a crash on the next
plunge. That is a bug, not a design question, and it does not wait for the contract.

- **Done when** — a **posted two-tool job** exists, `PR-15` closes, and §4 carries the test
  rows the deletion left owing. The acceptance test is emitted output, not a code review.

## Step V — Post-verify what has landed unposted

The machine-frame rework, the end park and the `CR-` fixes all changed the emitted file and
**none has been posted**. A node guard harness stands in — 38 guard cases + 24 unit checks —
and it proves logic only, never output.

- **`REG-MF` first** — the GRBL/mm factory-default diff. "Factory default" now means `Scale
  Feedrate` **on**, so the expected diff is the property dump, the Resolved-Values block
  **and every `F` word**, and nothing else. It is still owed because the closest run was
  diffed against a file that is neither factory-default nor pre-machine-frame.
- Then `PR-5a` (the enum flip — the one hazard consolidation created, and the row `PR-5`
  lives or dies on), `PR-2c`, `PR-5b`, `HR-28 (A)`; then `PR-6d`, `PR-6a–c`,
  `PR-7a–b`, `PR-8b`, `PR-9`, `PR-11`; then `FCR-3`, `FCR-4`, `FCR-5`, `FCR-13`.
- **Dialog-only:** `D1` and `D3`. The properties literal is now declared in display order, so
  if the dialog *still* shows groups out of numeric order, Fusion is not sorting and the
  zero-padding convention is wrong.
- **The tidy-ups:** `HR-19` and `HR-24`, both one-liners, neither changing output.

## Step 6 — Clarity

Only after 1–5, because they delete much of what would otherwise be tidied.

- `validateJob()` is **288 lines** at :1448. Step 2 removes ~44 and Step 3 ~6. **Re-measure
  before restructuring** — it may not need it.
- The property block is **795 lines, 21% of the file.** Steps 2 and 4 remove ~150 of
  description alone. Re-measure.
- **634 comment-only lines: leave them.** Every one of the sharpest findings in the
  assessment came out of a comment the post wrote about itself — the Guard C / `G53`
  contradiction, *"the spot drifts"*, *"writes into the PREVIOUS section's WCS"*, the `M84`
  hazard note, *"THE TWO JOG MODES DO NOT WORK ON GRBL"*.

## Step 7 — Documents, once

The guides are off-limits during code changes. Do it all here — per-step means rewriting
`guide-pro.md` three times.

| Document | What falls due |
|---|---|
| `design.md` | **The Marlin single-frame row rewritten** — nine registers, not one. **Add** the homing/`position_shift` hazard, the minimum firmware version, and what Step 1.3 emitted. **Remove** the spoilboard-base sections, and the *Tool changes* section's "the code implements neither" framing once it does |
| `property-reference.md` | Regenerate. Groups 5 and 11 gone; group 6 retitled; group 7 rebuilt as two flows. **Its stated count of 69 is already wrong** |
| `guide-pro.md` | State the **operator's** obligations explicitly — every work offset set before the job, one clearance clearing every fixture, machine homed. F360 nowhere states this and the emitted g-code depends on it. And say plainly what is verified and what is not |
| `guide-hobbyist.md` | Flow 1's end-of-file behaviour; the Marlin do-not-home rule; the minimum Marlin version |
| `README.md` | Feature list and the hobbyist/professional split |

---

## Preserve list — must survive whatever else happens

- **Nine verified bug fixes:** `5a6a4e0`, `b84f602`, `b61c005`, `cb1c9f2`, `ec5af37`,
  `ae0e013`, `eea70d1`, `1c5fcce`, `e5db625`.
- **The firmware knowledge in full** — `174c4df`, `2b5dfd5`, and every sourced fact in
  `design.md`'s tables **except the Marlin single-frame row**. Cannot be re-derived from F360.
- **`writeMachineHoming()`**, the `workOffset 0` → WCS 1 alias, the `>>> WARNING:` channel,
  the seventeen dialog-simplification commits, group 8 entire.
- **Group 6's touch-off mechanics.**
- `CR-11`, `CR-12`, `CR-14` and `PR-8` are landed fixes whose **code** Step 2 deletes — not
  lost work, work that stops being needed. `CR-13` and `556a378` survive.

## Delete list — ~450–500 lines

| What | ~Lines | Risk |
|---|---|---|
| Spoilboard base subsystem (Step 2) | ~250–300 | Medium — gated on Step 1 |
| `probeOnChange` + 4 Jog modes (Step 4) | ~100 | Low |
| `toolChangeDisableZStepper` + `M84 Z` | ~12 | None — it is a hazard |
| Guard C (Step 3) | ~6 | Low — it blocks supported behaviour |
| Group 11 folded | ~20 | Very low |
| Group 10 coolant surplus | ~50 | Low — pending a coolant persona |

## Blocked, and on what

| Blocked | Waiting on |
|---|---|
| Steps 2 and 4 | Step 1.3 — the six multi-part jobs |
| Step 3's version floor | the Marlin changelog for #14743 |
| Step 5's verification | a full-licence posted two-tool file |
| Step 5's Flow 2 | which token the sender keys on — `findings.md` §6 |
| Step 3's goal, not just its floor | an answer for Marlin's cross-part Z — see Step 3 |
| Group 10 reduction | a coolant persona |
| Group 9 audit | laser detail — power scaling, dynamic power, enable sequencing, air assist |
| A status line in `guide-pro.md` | **deferred by the author 2026-08-13** |

---

## The assessment's conclusion

> **Not over-built in general. Over-built in one place, for a machine that cannot use the
> feature — and under-verified everywhere else, by a deliberate deferral nothing in the
> repository states.**

The over-built place is the spoilboard base: it serves the non-homing machine at a cost —
five interlocking properties, a register, and a probe defended only by where the operator
parked — that the multi-part user does not have to pay, because that user's machine homes.
Steps 1, 1.3 and 2 are the remedy. The two design questions the assessment
settled on the way — whether the post reaches into F360's job, and whether computing a safe
height is the post's job — are in `design.md`.

---

## Done

**Phase C — cleanup, 2026-08-13.** `C0` branch `Assessment` cut from `CoverageFixes` ✅ ·
`C1` `PReview.md` restored to the tree `d010fee` ✅ (superseded — it is now `findings.md`) ·
`C2` six falsified pointers fixed ✅ · `C3` this checkpoint repointed ✅ · `C4` a status line
in `guide-pro.md` ⏸️ deferred by the author · `C5` thirteen merged local branches deleted ✅ ·
`C6` two unmerged remote branches deleted unread, by the author's ruling ✅ · `C7` the
`doc-sync` debt — **gone with the tool** · `C8` tooling — superseded · `C9` register
consolidation — **done**.

**Step 0 — free wins, 2026-08-13.** `0.1` = `C1` ✅ · `0.2` delete `toolChangeDisableZStepper`
⏸️ deferred to Step 5; `M84 Z` is a hazard on both firmwares and goes with the rework ·
`0.3` name the reason WCS probing is refused ✅ `f54beb0` · `0.4` collapse the frame predicates
✅ · `0.5` group 11 ✅ closed with no edit, handed to `PR-13` · `0.6` the `onCommand` gap ✅
`f54beb0`, half applied and half refused — `HR-13`.

**Step 1.1 — reproduce the multi-WCS block ✅ closed 2026-08-13.** The job was built from
**Multiple WCS Offsets** and posted three times: the refusal is **Guard B**, firing
**correctly**; two dialog edits make it post, a third makes it post clean with no post warning
at all. Filed as **`PR-14`** — error *text*, not logic. The author's verdict, accepted: the
failed post was operator error, and the route to the setting is the separate issue. **It did
what the critical path promised — it invalidated part of Steps 1–4's premise before any of it
was built.**

**Step 1.2 — the homed machine answers Guard B ✅ closed 2026-08-14, `c0ceb86`.**
`getFixedZReference()` derives `Machine Z` for a multi-part job on a machine declared `XYZ`
homed, so the operator reaches the frame from group 4 and never visits the spoilboard
subsystem; `Home at Job Start` is not required, because the declaration is the trust
assertion. Six rows posted and passed — `findings.md` §5. **The measure held:** the same job
that produced `Multi_WCS (b).gcode` posts with `Fixed Z Reference` back at its factory `None`
and **two lines of the file change, no g-code.** `PR-14` closed with it.

*`Assessment/00-08` and `10` are the analysis this plan came from. They are dated
2026-08-13 and their file pointers predate this consolidation; read them for evidence, not for
where things live.*

---

## How to write in this file

**Three rules. If a change to this file broke one of them, the change is wrong.**

1. **Completion shrinks the document.** A step that closes must end up *shorter* than it was
   while open. If closing it made this file longer, it was written wrong.
2. **An open step carries no history.** State the goal, where, the change, and how you will
   know it is done. Not how the project arrived at it, not what an earlier version said, not
   what was rejected on the way — that is `design.md`'s job, or git's.
3. **A closed step is one line** in *Done* — id, what it did, commit ref where there is one.

**Never point two ways.** A pointer is valid in one direction only: from here toward the file
that owns the work. `findings.md` owns findings and tests and must not point back here.
