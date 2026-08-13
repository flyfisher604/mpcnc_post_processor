# Plan — what is next

The only file that says what is next. Findings and tests are `findings.md`; why the post
behaves as it does is `design.md`.

## Checkpoint — read this first

**Baseline.** Branch **`Assessment`**, 31 commits ahead of `master`. `CoverageFixes`
contributes 18 of them and is **itself unmerged**, so a merge to `master` carries two
ranges, not one. `master` is 6 commits ahead of `origin/master`; `Assessment` is unpushed.

**What is true now.** Phase C and Step 0 are done. **Step 1.1 is done and closed** — the
multi-WCS job posts, in three dialog edits, and the refusal chain is filed as `PR-14`. The
post is otherwise untouched by this plan since Step 0.

**What is next: Step 1.2.** It is a decision rather than a wait, and it now has a real
posted file to be measured against. **The single thing that has to happen first:** read
`Multi_WCS (b)` — already on disk, unread. If its traverse is already `G53`-framed at
today's settings, Step 1.2 is measured against a known-good file instead of a prediction,
and `PR-2a`/`PR-2b`/`PR-2d` come off it rather than off a re-post.

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
| **1.2** | Make the homed machine the answer to Guard B | — |
| **1.3** | Post the six multi-part jobs — `findings.md` §4.1 | 1.2 |
| **2** | Retire the spoilboard base | 1.2 + 1.3 |
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

## Step 1.2 — Make the homed machine the answer to Guard B

- **Goal** — a homed machine posts a multi-WCS job from a configuration the operator can
  reach without learning the spoilboard subsystem.
- **Why** — Guard B's reasoning is right: a multi-WCS traverse needs a frame that outlives
  one WCS. Its *route* is wrong. Only the spoilboard route needs a reserved WCS, a probed
  base and four more guards; the **machine-Z** route needs none of them, and on the machine
  1.1 was run from, its four guards were already satisfied by group 4. **What this buys is
  discoverability and defaults, not capability** — the capability landed with `PR-2`.
- **Where** — Guard B :1698-1705; `usesMachineZDatum()` :2012; `machineHomesXY/Z()`
  :2019-2026; `parseInterPartTravelZ()` :2054; the machine-Z branch :1645-1672.
- **The change** —
  1. Multi-WCS ⇒ require homed X/Y/Z, `Home at Job Start`, and a travel height. **All four
     properties already exist.**
  2. Traverse emits `G53 G0 Z<travel>` — correct regardless of any WCS's Z0.
  3. Machine does not home ⇒ refuse in **one** sentence naming the real reason: *multi-part
     work needs a homed machine; post one job per part.*
  4. **Do not delete the spoilboard path here.** Step 2 does that, after this is proven.
- **Done when** — the 1.1 job posts on GRBL with only group 4 properties set, and the
  traverse is `G53`-framed. **Read the emitted file; do not infer it.** Measured against the
  2026-08-13 baseline, this step's own measure is **one dialog field removed, not a job newly
  enabled**.
- **Findings** — `PR-14` does **not** close here: this removes the first refusal, not the
  second. Closing it needs the error text to name `Inter Part Travel Z` and the group both
  cures live in — cheap, and worth doing *inside* this step so the operator meets one
  complete sentence instead of two halves.

## Step 1.3 — Post the six multi-part jobs

- **Goal** — the largest untested area in the post stops being unverified.
- **Where** — `findings.md` §4.1. The expected output is **already written** for PB1, PB2,
  PBV1, PBV2, PBV3 and PA1, so this is checking, not designing.
- **The change** — none to the post unless a row fails.
- **Done when** — six posted files exist; every §4.1 row ticked or carrying a finding.
- **First** — `PA1` and `PB2` reference `Retract Across Parts`, deleted by `CR-13`. Re-scope
  those rows before running them; that is itself a finding.

## Step 2 — Retire the spoilboard base

- **Goal** — group 5 ceases to exist; one property survives, in group 4.
- **Why** — **the subsystem's premise defeats itself.** It exists to give a **non-homing**
  machine a common Z frame for multi-part traverses, but multi-part traverses require homing
  by the post's own guard at :1669. **No machine both needs it and can use it.** It also
  consumes one of GRBL's six registers, and four open findings live in it.
- **Where** — `writeBaseEstablish()` :2998 (~79); reserved-base agreement guards :1622-1643
  (~22); slot check, Guard B′, Guard A :1708-1729 (~22); `baseOriginWriteReason()` :1406-1431
  (~26); `getReservedBaseWcs()` :2042 (~12); `fixedZEstablished*()` :2071-2099 (~28); four of
  five group 5 properties (~90).
- **The change** — delete the above. **Keep `spoilboardTravelZ`**, rename `machineTravelZ`,
  move to `groupDefinitions.machine`. `getFixedZReference()` :2005 reduces to one branch.
- **Done when** — ~250–300 lines gone; 10 groups → 9; the Step 1.3 files still post.
  **Re-post at least two of the six** — a deletion under a verified baseline is the only kind
  that can be checked.
- **Findings** — `CR-11`, `CR-12`, `CR-14` and `PR-8` close **by deletion**. Each row must say
  the code was removed rather than repaired.
- **Refute it first.** Find any configuration where the spoilboard base is the only workable
  answer — including single-WCS jobs, jet/laser tools, and any path where `Fixed Z Reference
  = Spoilboard` changes output without a WCS change. Search every reader of
  `getFixedZReference`, `usesMachineZDatum`, `getReservedBaseWcs`, `fixedZEstablishedInFile`
  and `fixedZEstablishedAtStart`.

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
  possible.
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
  lives or dies on), `PR-2a`, `PR-2c`, `PR-5b`, `HR-28 (A)`; then `PR-6d`, `PR-6a–c`,
  `PR-7a–b`, `PR-8a/b`, `PR-9`, `PR-11`; then `FCR-3`, `FCR-4`, `FCR-5`, `FCR-13`.
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
- `CR-11`, `CR-12`, `CR-14` and `PR-8` are **superseded by Step 2's deletion**, not preserved
  — not lost work, work that stops being needed. `CR-13` and `556a378` survive.

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
| Steps 2 and 4 | Step 1.2 — whether the homed path actually posts |
| Step 3's version floor | the Marlin changelog for #14743 |
| Step 5's verification | a full-licence posted two-tool file |
| Step 5's Flow 2 | which token the sender keys on — `findings.md` §6 |
| `findings.md` §4.1 rows `PA1`, `PB2` | re-scoping against `CR-13` |
| Group 10 reduction | a coolant persona |
| Group 9 audit | laser detail — power scaling, dynamic power, enable sequencing, air assist |
| A status line in `guide-pro.md` | **deferred by the author 2026-08-13** |

---

## The assessment's conclusion

> **Not over-built in general. Over-built in one place, for a machine that cannot use the
> feature — and under-verified everywhere else, by a deliberate deferral nothing in the
> repository states.**

The over-built place is the spoilboard base: it serves a real user by a route that user
cannot take. Steps 1, 1.3 and 2 are the remedy. The two design questions the assessment
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
