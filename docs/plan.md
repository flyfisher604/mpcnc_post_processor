# Plan — what is next

The only file that says what is next. Findings and tests are `findings.md`; why the post
behaves as it does is `design.md`.

## Checkpoint — read this first

**Baseline.** Branch **`Assessment`**, 44 commits ahead of `master`. `CoverageFixes`
contributes 18 of them and is **itself unmerged**, so a merge to `master` carries two
ranges, not one. `master` is 6 commits ahead of `origin/master`; `Assessment` is unpushed.

**What is true now.** Phase C, Step 0, **Steps 1.1, 1.2, 1.3, 2 and 3 are done and closed.** A
multi-WCS job posts on any of the three firmwares given a machine declared homed; the spoilboard
base and group 5 no longer exist; the multi-part register is settled. `PR-14` closed with 1.2;
`PR-16` and `HR-26` closed by deletion with 2; `PR-17` closed with 2.

**What is next: Step 4, then Step 5.** Both delete code the register has no pass criterion for —
group 5's orchestration, and the whole tool change. Step 5 is independent and can run in parallel.

**Step V shrank but did not go away.** `findings.md` §4 holds **31 unrun rows, from 57**, twenty-six
having closed by code walk 2026-08-14. A walk settles what the post writes and nothing beyond it, so
what is left there is what needs Fusion or a controller. **One of those rows matters to Step 4**: the
walk found `S3f`'s byte-identity claim false, so the Marlin files in `HB-Tests/` no longer match
their saved artifacts. §4 states the method and its bound; §5 carries each row's argument.

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
| **4** | Group 5: keep the touch-off, delete the orchestration | — |
| **5** | Group 6: rebuild the tool change as two flows | — (parallel with 4) |
| **V** | Post-verify what has landed unposted | — |
| **6** | Clarity | 4–5 |
| **7** | Documents, once | 4–6, V |

**4 and 5 are independent of each other and can run in either order or together.** Step 4 assumes
F360 emits a multi-WCS job a particular way, read from Autodesk's post source rather than observed;
**Step 1.3's artifacts are what that assumption is now checked against**, which is why it came first.

---

## Step 4 — Group 5: keep the touch-off, delete the orchestration

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
  hobby files in `HB-Tests/` re-post **byte-identically** for the surviving modes. **The Marlin
  files among them already carry one known delta** — `findings.md` `S3f`, a `WCS unchanged`
  comment per section after the first — so diff against a build of `e11d0c9`, not against the
  saved artifacts.

## Step 5 — Group 6: rebuild the tool change as two flows

Independent of Step 4. **The shipped design is being replaced, not repaired** — the design is
`design.md` → *Tool changes*, and `PR-15` is the one finding that the code does not comply
with it. Eight properties, ~65 lines, **zero posted files exercising a tool change**, and
after the register deletion **zero test rows** either.

- **Goal** — the post arrives correctly, hands over, and resumes correctly. It performs no
  tool change itself, in either flow.
- **Where** — `toolChange()`; `probeTool()`; `onSection()`'s call order around `writeWCS()`;
  group 6 entire; `includeProbeFile` in group 7.

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

The end park and the `CR-` fixes changed the emitted file and **have never been posted**. The
machine-frame rework is settled from the source instead — `findings.md` §5's twenty-six walked
rows — so what is left here is what a walk cannot reach.

- **`REG-MF` first** — the GRBL/mm factory-default diff. "Factory default" now means `Scale
  Feedrate` **on**, so the expected diff is the property dump, the Resolved-Values block
  **and every `F` word**, and nothing else. It is still owed because the closest run was
  diffed against a file that is neither factory-default nor pre-machine-frame. **`S2a` predicts
  the dump delta exactly**, so this run either confirms that walk or breaks it.
- **Then the Marlin multi-operation job** — `S3f`'s corrected count, and the only place a walk
  contradicted the register.
- Then `PR-2c`, `HR-28 (A)`; then `PR-6d`, `PR-6a`, `PR-6b`, `PR-7a`, `PR-9`, `PR-11`; then
  `FCR-4`, `FCR-5`, `FCR-13`.
- **`PR-2d` on its own** — the post has never emitted an inch file, and no walk can say what
  `createFormat` resolved its decimals to.
- **Dialog-only:** `D1`, `D3`, `D4`, `P7`. The properties literal is now declared in display
  order, so if the dialog *still* shows groups out of numeric order, Fusion is not sorting and
  the zero-padding convention is wrong.
- **The tidy-ups:** `HR-19` and `HR-24`, both one-liners, neither changing output.

## Step 6 — Clarity

Only after 4 and 5, because they delete much of what would otherwise be tidied.

- `validateJob()` was **288 lines**; Steps 2 and 3 removed ~100 of it. **Re-measure
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
| `design.md` | **Remove** the *Tool changes* section's "the code implements neither" framing once it does. The Marlin rewrite and the version floor landed with Step 3 |
| `property-reference.md` | Regenerate. The old groups 5 and 11 are gone and 6–11 renumbered to 5–10; group 5 retitled; group 6 rebuilt as two flows. **63 grouped properties, not the stated 69** |
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
  the seventeen dialog-simplification commits, the include-files group entire.
- **Group 5's touch-off mechanics.**
- `CR-11`, `CR-12`, `CR-14` and `PR-8` are landed fixes whose **code** Step 2 deleted — not
  lost work, work that stopped being needed. `CR-13` and `556a378` survive.

## Delete list — ~450–500 lines

| What | ~Lines | Risk |
|---|---|---|
| `probeOnChange` + 4 Jog modes (Step 4) | ~100 | Low |
| `toolChangeDisableZStepper` + `M84 Z` | ~12 | None — it is a hazard |
| Group 10 (Duet) folded | ~20 | Very low |
| Group 9 coolant surplus | ~50 | Low — pending a coolant persona |

## Blocked, and on what

| Blocked | Waiting on |
|---|---|
| Step 5's verification | a full-licence posted two-tool file |
| Step 5's Flow 2 | which token the sender keys on — `findings.md` §6 |
| Group 9 reduction | a coolant persona |
| Group 8 audit | laser detail — power scaling, dynamic power, enable sequencing, air assist |
| A status line in `guide-pro.md` | **deferred by the author 2026-08-13** |

---

## The assessment's conclusion

> **Not over-built in general. Over-built in one place, for a machine that cannot use the
> feature — and under-verified everywhere else, by a deliberate deferral nothing in the
> repository states.**

The over-built place was the spoilboard base: it served the non-homing machine at a cost —
five interlocking properties, a register, and a probe defended only by where the operator
parked — that the multi-part user did not have to pay, because that user's machine homes.
Steps 1, 1.3 and 2 were the remedy, and all of them have landed. **The under-verification is the
half still standing** — smaller than it was, and now explicit about which of its rows a posted
file could still overturn. The two design questions the assessment
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
✅ · `0.5` the Duet group ✅ closed with no edit, handed to `PR-13` · `0.6` the `onCommand` gap ✅
`f54beb0`, half applied and half refused — `HR-13`.

**Step 1.1 — reproduce the multi-WCS block ✅ closed 2026-08-13.** The job was built from
**Multiple WCS Offsets** and posted three times: the refusal is **Guard B**, firing
**correctly**; two dialog edits make it post, a third makes it post clean with no post warning
at all. Filed as **`PR-14`** — error *text*, not logic. The author's verdict, accepted: the
failed post was operator error, and the route to the setting is the separate issue. **It did
what the critical path promised — it invalidated part of Steps 1–4's premise before any of it
was built.**

**`PR-17` ✅ closed 2026-08-14.** A `>= 0` warning on GRBL in both channels, taken with the field's
rename because one baseline covers both. `>= 0` and not `> 0` is the whole point: homing ends one
pull-off below the trigger, so machine Z `0` *is* the switch, and soft limits reject only `> 0`.

**Step 3 — Marlin multi-WCS ✅ closed 2026-08-14.** Guard C is gone: its message, *"Marlin has a
single coordinate frame"*, was a false statement emitted to the user. `gcode.cpp` 2.1.2.5 puts
`G54`–`G59` in the same `#if ENABLED(CNC_COORDINATE_SYSTEMS)` as `G53`, and `G92` under it writes
the **active** workspace's own register — so selection has full parity and the write dialect is all
that differs. **The version floor is 2.0.9.7**, the oldest release at which both files were read;
`#14743` cannot reproduce against that code. A Marlin multi-part job is now refused by exactly one
thing, Guard B, on the same terms as every other firmware.

**Step 2 — retire the spoilboard base ✅ closed 2026-08-14.** One fixed Z reference survives:
the machine's own homed Z, addressed with `G53`, opted into by filling `Machine Travel Z` in
group 4 — no enum, no boolean, ungated by offset count. Six frame predicates collapsed to one;
group 5, Guard A, Guard B′, the reserved-base guards and the enum-flip guard all went with it.
**−354 lines, 10 groups → 9.** `PR-16` and `HR-26` closed **by deletion**.

**Step 1.3 — the multi-part register ✅ closed 2026-08-14.** Eight rows on posted files, then
**twenty-six by code walk against `e11d0c9`** — the remainder plus the whole `S2`/`S3` debt Steps 2
and 3 created. `findings.md` §4.1 is gone and the walk corrected the register four times.

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
