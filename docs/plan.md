# Plan — what is next

The only file that says what is next. Findings and tests are `findings.md`; why the post
behaves as it does is `design.md`.

## Checkpoint — read this first

**Baseline.** Branch **`Assessment`**, 44 commits ahead of `master`. `CoverageFixes`
contributes 18 of them and is **itself unmerged**, so a merge to `master` carries two
ranges, not one. `master` is 6 commits ahead of `origin/master`; `Assessment` is unpushed.

**What is true now.** Phase C, Step 0, **Steps 1.1, 1.2, 1.3, 2, 3, 4, 5 and F2 are done and closed.** A
multi-WCS job posts on any of the three firmwares given a machine declared homed; the spoilboard
base and the old group 5 no longer exist; the multi-part register is settled; every origin mode
states the condition it depends on; the tool change is both flows, a machine-frame change position on
the manual one, and nothing else. `PR-14` closed with 1.2; `PR-16` and `HR-26` closed by deletion with
2; `PR-17` closed with 2; `PR-18` and `PR-19` closed with 4; `PR-15`, `PR-21` and `PR-22` closed with
5; `PR-24` with F2; `PR-26` and `PR-27` with F3; `PR-28` with F4; `CR-01` with F5; `HR-13`, `HR-19`,
`HR-24` and `CR-02` with F6, which closed `HR-20` and `HR-27` by design alongside them; `CR-17` with
F7.

**What is next: Step V**, and it is **four rows — the whole of it is the jet workstream**
`findings.md` §6 defers. The register re-walk of 2026-08-16 closed forty-eight rows from the
source and the author's rulings closed sixteen more, so **nothing in Step V waits on a licence, a
controller or a sender**, and nothing outside the jet rows waits on a post to close. What is owed
in artifacts rather than rows is two posted files: a factory-default GRBL job and a Marlin
multi-operation one. §4 states the methods and their bounds; §5 carries each row's argument.

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
| **V** | Post-verify what has landed unposted | — |
| **6** | Clarity | — |
| **7** | Documents, once | 6, V |

---

## Step V — Post-verify what has landed unposted

The end park and the `CR-` fixes changed the emitted file and **have never been posted**. What the
source can settle is settled — `findings.md` §5's seventy-seven walked rows — so what is left here is
what a walk cannot reach.

- **The jet workstream — `J4` first**, group 8 having never appeared in any posted file; then `J1`,
  `J2`, `J5`. Deferred by design, and `findings.md` §6 states what blocks it. **`J1` is the one that
  may return a finding rather than a pass**: with a tool that cannot probe, the
  `Use WCS X0 Y0, Probe Z0` arm writes a `Debug` line where every neighbouring arm writes a warning,
  so at the shipped comment level the file says nothing about a Z0 nobody established.
- **Two artifact debts, and neither is a row**: a factory-default GRBL job, which is what
  `findings.md`'s *Invalidated by landed fixes* waits on, and the Marlin multi-operation job that
  settles `S3f`'s corrected comment count — the only place a walk contradicted the register.

**Worth one post of its own, and it is not a row here:** `HR-6 (B)`'s rotated Setup. It is the live
risk, and `PR-2c` closed on a ruling rather than on an artifact, so that job would settle both.

## Step 6 — Clarity

- `validateJob()` was **288 lines**; Steps 2 and 3 removed ~100 of it. **Re-measure
  before restructuring** — it may not need it.
- The property block is **795 lines, 21% of the file.** Step 2 removed description; **Step 4
  did not** — it spent what it cut on the conditions each mode carries, `probeOnStart` ending
  77 characters shorter and `probeOnChange` 415 longer. Re-measure.
- **634 comment-only lines: leave them.** Every one of the sharpest findings in the
  assessment came out of a comment the post wrote about itself — the Guard C / `G53`
  contradiction, *"the spot drifts"*, *"writes into the PREVIOUS section's WCS"*, the `M84`
  hazard note. **One of them was wrong** — *"THE TWO JOG MODES DO NOT WORK ON GRBL"*, corrected by
  `PR-19` — which is an argument for reading them, not for thinning them.

## Step 7 — Documents, once

The guides are off-limits during code changes. Do it all here — per-step means rewriting
`guide-pro.md` three times.

| Document | What falls due |
|---|---|
| `design.md` | Nothing outstanding — the *Tool changes* retitle and the token paragraph landed with `F2`, and the Marlin rewrite and the version floor with Step 3. **Re-read before assuming that** |
| `property-reference.md` | Regenerate. The old groups 5 and 11 are gone and 6–11 renumbered to 5–10; group 5 is now *5 - Part Origins*, retitled and rewritten but offering exactly what it did; group 6 is **ten** properties where it was eight — rebuilt entire, with the change position and the two tool-change include files moved in from group 7 — and group 7 is now only the two files that **replace** the header and footer, having also lost `includeProbeFile`. **Recount — the stated 69 was already wrong** |
| `guide-pro.md` | State the **operator's** obligations explicitly — every work offset set before the job, one clearance clearing every fixture, machine homed. F360 nowhere states this and the emitted g-code depends on it. And say plainly what is verified and what is not |
| `guide-hobbyist.md` | Flow 1's end-of-file behaviour; the Marlin do-not-home rule; the minimum Marlin version; **mid-job indexing** — the jog modes as a supported workflow, the sender condition on GRBL, and the panel condition on Marlin |
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

## Delete list — ~370–420 lines

| What | ~Lines | Risk |
|---|---|---|
| Group 10 (Duet) folded | ~20 | Very low |
| Group 9 coolant surplus | ~50 | Low — pending a coolant persona |

## Blocked, and on what

| Blocked | Waiting on |
|---|---|
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

**`CR-23`, `CR-24`, `PR-25` ✅ closed 2026-08-16 — `findings.md` §2 is empty.** `CR-23` closed on the
author's ruling: the parser functions as designed and `0` is a legal Safe-Z. `CR-24` names what the post
can only name — stock grbl compiles `M7` only under `ENABLE_M7` and answers `error:20` without it, while
**FluidNC never errors and pin-gates `M7` *and* `M8`**, so on a V1 Engineering Jackpot 2 or 3 the failure
is a job that cuts dry in silence rather than a halt in the cut. One warning gated on a channel the
operator switched on, both codes in it, and V1E's own shipped configs in the description. `PR-25` settled
from RRF's source: `G53` drops the tool offset with the workplace offset at 2.05 through 3.6.0, so a
machine-frame height means on RRF what it means on GRBL and the hedged headroom warning is **deleted**.
Three walk rows; `TC-15` corrected, having counted the warning the fix removes.

**`PR-23`, `CR-21`, `CR-22` ✅ closed 2026-08-16.** `writeWCS()` is the select alone and
`writeWcsEstablish()` the origin work, so `onSection()` orders select → change → establish and a
boundary that is both probes the part **once**, with the tool that cuts it — `wcsOriginEstablishesZ0()`
being the one statement of when the change may hand its re-probe over and when it is the only
correction there is. `resetPostState()` gained the three modal formatters and the six coordinate
variables, without which a second file in one Fusion invocation has no preamble at all; the four
coolant custom files joined `validateJob()`'s include pre-flight. Four walk rows; `PR-23` stops being
a `➖` row and asserts an absence instead.

**Register triage ✅ 2026-08-16.** Four fixes and four rulings: `CR-05` puts the replaced-header
precondition in the file; `CR-09` names Marlin's build option — and V1 Engineering's own
`LASER_FEATURE` builds, where `M3` fires but `S` is not RPM — in the property description; `PR-13`
takes RRF 3.x defaults with both generations' forms in the description, the group-10 fold not with
it; `CR-10` warns in both channels instead of taking the `Near Machine X0 Y0` redesign. `CR-03`
closed as designed, and `PR-7b` and `REG-MF` retired. It also detailed `CR-15`, which closed the
same day on a fix the detail is what made findable.

**`CR-15` ✅ closed 2026-08-16.** The preamble stops moving the tool before it records where the tool
is: `writeFirstSection()` holds two orders now, and on the two `Set … to Current Pos` modes the
fixed-Z establish falls **below** the origin — it led only because it is the height a *travel* to the
part origin starts from, and those modes make none. `Prompt for the First Tool` is dropped there
rather than reordered, a pre-jog implying a fitted tool. `PR-10`'s warning is deleted with its
defect. Eight walk rows; the walk corrected `TC-6`, `S2e` and one `Debug` trace.

**Register re-walk ✅ 2026-08-16.** The open register executed against the source: **forty-eight of
sixty-three unrun rows closed**, four of them corrected rather than confirmed, and every full-licence
blocker gone. It found three defects — `WR-1` a refusal naming a deleted group, `WR-2` a machine
coordinate read as *unset* when it is a typo, and `CR-21`'s third instance — all fixed. `HR-22` closed
onto `CR-21`, being the same question twice.

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

**F2 — Flow 2, the macro call ✅ closed 2026-08-14.** The token stopped being one unanswerable question
by becoming a property: `Tool Change Handled By` names gSender, CNCjs, the RepRapFirmware tool table or
`Other`, and the post emits what that handler reads — `T<n> M6` where a sender strips the `M6`, `T<n>`
alone where the T word **is** the change, an operator's include file where neither. `At a Tool Change`
gained a third value and **the two flows share their arrive-and-stop half**, so no route can be given a
hand-over the others do not get. What F2 added beyond the call is the resume — modal re-assert, an
unconditional WCS re-select, and a return to `Machine Travel Z` — because a macro the post did not write
may have left the machine anywhere. **Marlin is refused**, having no register for a macro to write into.
**`PR-25` is what it left**: Flow 2 on RRF is the first setting that makes a tool offset active while the
post moves in `G53`, and whether RRF applies one there is a source read this project has not done.

**F3 — where the manual change happens ✅ closed 2026-08-14.** `Tool Change X/Y/Z` was deleted in Step 5
as unsound and never replaced, which left every manual change happening directly above the cut. The
replacement is three **machine-frame** fields through the same `writeMachineFrameBlock()` as every other
`G53` move, so a change position means the same thing on every part of every job — the frame was the
defect, not the feature. **There is no X/Y retrace**: nothing after a change is measured from where the
tool stood before it, and across a change of work offset the two probed registers' true relationship is
not known to the post at all. What *is* owed is the ordering of the next rapid, which `PR-26` forces to
cross before it descends — without it the tool crossed the bed at the section's clearance height. Flow 2
is untouched, the changer position being the macro's own, and the fields warn there rather than being
dropped in silence. `PR-27` rode along: GRBL's steppers de-energise at the pause and `$1` is a setting
the post can never emit, so it says so. All three close **on a walk alone** — `TC-17` … `TC-20` are
unrun. F3 left `PR-28`, which **F4 closed**.

**F4 — the post tells the kernel where the tool is ✅ closed 2026-08-14.** `PR-28`, opened by F3's own
walk. `getCurrentPosition()` is the **toolpath's** position and was blind to the nine moves the post
injects itself, so four readers — the rapid ordering, `isSafeToRapid()`, and the feedrate projection in
`linearMovements()` and the arc handler — were each computing from a point the tool had left blocks
before. The fix reports every **work-frame** injected move through the kernel's own
`setCurrentPosition()`, from inside `rapidMovementsXY()` / `rapidMovementsZ()` so no injection site
needed editing. **The machine frame is where it stops, and that is not a shortfall but the same fact
the rest of this plan turns on**: a `G53` height has no work-frame value until a probe establishes the
offset, so `forceRapidXYBeforeZ` remains for the one move after a relocated change — as the named
residue now, not as a point fix. Autodesk's own posts stop at the same line. `PR-28a` is unrun.

**F5 — the file says what sets travel speed ✅ closed 2026-08-14.** `CR-01`, open since the code review.
GRBL and FluidNC take a rapid's rate off the axis limits and never out of the block, so group 2's two
speeds described an `F` word the default firmware does not read — and **no line a posted file may contain
reaches that rate**: `$110`–`$112` are settings refused outside `Idle`, and the rapid override is
real-time bytes. So the post names the parameter instead, as the **first line of every GRBL file** at
every comment level, in both dialects — FluidNC has no `$110`, its limit being `max_rate_mm_per_min` per
axis. `PR-27`'s `$1` warning is the precedent and this one is ungated, being true of every job on the
default firmware. **Mapping travels to `G1` so the `F` would be obeyed was built and rejected by the
author**: a rapid is a rapid, and the machine's limit is the operator's setting to make. The cost is one
line at the top of every GRBL file, which moves every line number in every GRBL artifact — `findings.md`
§5 carries it, and `validateJob()`'s *"the FIRST LINE of the file"* clause was reworded with the fix.
`CR-01a` unrun.

**F6 — six registered findings, cleared on the author's rulings ✅ closed 2026-08-14.** Four took code.
`HR-13`: a Manual NC *Optional stop* now emits **`M0`**, the ruling being that a stop that cannot be
skipped beats a command that vanishes — no supported firmware has a working `M1`, GRBL ignoring it,
RRF ending the job on it and Marlin alone waiting. `CR-02`: every GRBL prompt gains the **comma**,
which grblHAL requires and without which its operator sees an unexplained pause; it moves every prompt
line in every GRBL file. `HR-19` and `HR-24` are the one-liners — one space after `M291` instead of
two, and `writeWCS()` reading the tool of the section it is handed rather than the global that happens
to match. Two closed on a ruling alone: **`HR-20`, tapping is not supported** — rigid tapping needs a
`G33`/`G84` none of the three has, and the post already warns on every sync command — and **`HR-27`,
the geometry guards function as designed**, moving them into `validateJob()` stranding the orientation
guard's `Debug` trace, which is the only thing separating a guard that read nothing from one that read
`+Z`. Alongside them the **tool-change include files left group 7 for group 6**, being the only
tool-change settings outside it and the only two in that group that ADD to a sequence rather than
replace one. `CR-02`, `HR-19` and `HR-24` are unrun; `PR-2c` now carries `HR-27`'s falsifier.

**F7 — a part is set up once ✅ closed 2026-08-15.** `CR-17`: a job that returned to a work offset it
had already used re-ran the whole origin dispatch, driving a second `G38.2` into a pocket floor the
roughing pass had cut and displacing every finishing cut by that depth. A return now sets nothing up —
retract, select, rapid to the stored X0 Y0 — under **any** mode, the two jog modes included, X0 Y0
being what nothing in a job moves. **Only Z re-opens and only a tool change opens it**: with no
tool-length system the change's re-probe corrects the active offset alone, so it clears the Z half for
every other part and a return to one of those re-establishes Z by the mode's own answer. **The control
says so** — `Subsequent WCS / Part` is `Each New WCS / Part`, its default `Use WCS X0 Y0, Probe Z0 Once
per Part`, and `Active` is gone from all four stored-origin titles; no title reaches a posted file.
`CR-17a`, `CR-17b` and `CR-17c` are unrun, two of them licence-free.

**Step 5 — the tool change is Flow 1 and nothing else ✅ closed 2026-08-14.** The post changes no
tool: no `M6`, no `M84 Z`, no `T` word, no beep, and no `Tool Change X/Y/Z` — the hand-over retracts
in the **machine frame**, stops coolant and spindle on the one route there now is, prompts, and
re-probes through `partProbe()` into the **active** offset, `onSection()` having selected the WCS
first. Eight properties to three; a first tool load moved into `writeFirstSection()`, ahead of the
origin work; `includeProbeFile` deleted. `PR-15` closed with it. **Three things the step did not
foresee:** the multi-tool default became a **refusal** rather than a warning, because the warned
alternative cut every operation with one tool; the walk found the spindle stop reading the
**incoming** tool's jet guard, so a change into a laser handed over a turning cutter — `PR-22`; and
`PR-21`, the Marlin end park being a homing cycle that zeroes the very origin the two-file answer
depends on.

**Step 4 — group 5 keeps every mode and states each one's condition ✅ closed 2026-08-14.** Nothing
deleted; the group retitled *5 - Part Origins*, both descriptions rewritten around the condition each
mode carries, and the jog refusal replaced by `jogAtPauseCondition()` — one statement, written by the
dialog and the file alike. `PR-18` and `PR-19` closed with it. **Two things it cost that the step did
not foresee:** the retitle moves one property-dump line in every file posted at `Info`, so
byte-identity is no longer an available criterion and `S2a`/`D5`'s enumeration is one line short; and
the walk found Marlin had the same unstated condition as GRBL, which is now warned in both channels.
**`PR-20` is what the walk found**, and it is not a jog defect: under gSender the **first operator
stop in the file is deleted rather than obeyed** whenever `Comment Level` is below `Info`, which at
`Off` costs the default job its `Attach ZProbe` prompt and `Pause, then Home` its stop at line 1.
Closed on a post-time warning, `PR-10`'s precedent — the threshold is another program's.

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
