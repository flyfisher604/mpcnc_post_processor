# WCS / Origin Rework — design record & remaining work

The developer/design record for `MPCNC_v4.0_Beta2.cps`. Implemented mechanics live in the code; only the
**enduring decisions**, the **design that constrains unbuilt work**, and the **backlog** are kept here.

User-facing usage lives in `README.md`. Verification and findings live in three files:

| File | Owns |
|---|---|
| `docs/HReview.md` | The hobbyist review — **complete**. Findings register + the 83-row test register |
| `docs/PReview.md` | The professional side — findings, every multi-WCS / base / tool-change / dialog row, the jet/laser workstream. **The professional review itself has not been done** |
| `docs/review.md` | The 2026-08-01 full code review — 17 findings, 14 fixed, 3 closed by design |
| this file | Design record, remaining work, resolved decisions |

---

## Checkpoint — restart here

*Written so a fresh session can resume with no other context. Update it when the situation moves.*

**Baseline.** Branch **`v4.0-hreview-fixes`** at **`c73726c`**. **Nothing is half-done and nothing is
known-broken.** Untracked and deliberate: `MPCNC_v4.0_Beta1.zip`, and `Personal.cps` (a test harness,
excluded via `.git/info/exclude` — see *Workflow notes*).

**Two reviews are finished.** The **hobbyist review** (`HReview.md`) — 26 findings, 13 fixed and verified,
6 moved to `PReview.md`, 83 test rows, nothing failing or unrun. And the **full code review**
(`review.md`, 2026-08-01) — a fresh pass driven by the dialog and the F360 API, 17 findings, **14 fixed at
`c73726c`**, 3 closed as by-design. Nothing in either found the factory-default single-operation job
broken; every High/Medium finding needed one dialog field moved off its default.

**What the code review changed that a reader will notice.** `$H` no longer breaks under line numbering;
`validateJob()` warns on homing-plus-`Current Pos` origin and on a suppressed multi-tool change;
`onClose()` stops the spindle **before** the return traverse; the coolant `Use custom` fields load a file
as documented; a jet job warns that Z0 was never established; and the `properties` literal is now declared
in dialog order (a pure move — checksum-verified, no preset resets).

**Status lives in two registers.** `HReview.md`'s test register for hobbyist rows; `PReview.md` §3 for
professional ones. Nothing else records a pass. **Read the Method column, not just the state** —
`posted` is a real file from the real post and the only method that proves what a hobbyist receives;
`read` is a reading of control flow and is **weaker than the rest**.

**What is left, in order.**

| | Item | Note |
|---|---|---|
| 1 | **Post-verify the 14 fixes** | `review.md` → *Verification*. Five posts; **post 1 (GRBL/mm defaults) is the regression that matters most**. CR-1 additionally needs `Enable Line #s` on + `Home Before Start = XY`, a combination no configuration in the record has ever used |
| 2 | **Tidy-up sweep** | `HR-19`'s `M291` doubled space, **HR-21** (wire the dead `Tool Change Probe` property into `probeTool()` — Tool Change branch work — or delete it), **HR-24** (`writeWCS()` should read `section.getTool()`, not the global `tool`). All one-liners, none changing output |
| 3 | **Dialog-only checks** | **D1** and **D3**'s dialog half (`PReview.md` §3.3). CR-14 sharpened D1: the literal is now declared in display order, so if the dialog *still* shows groups out of numeric order, Fusion is not sorting and the zero-padding convention is wrong |
| 4 | **Open the Tool Change branch** | *Phase 4* below, folded with **HR-7/8/9/10/13** (`PReview.md` §2). Design settled for the ordering half; HR-10 and HR-13 have complete diffs and can go first as warm-up commits |
| 5 | **The professional review proper** | The pass that produces `PReview.md`'s real content. Needs a multi-part / multi-fixture job to post against |
| 6 | **Jet / laser workstream** | `PReview.md` §5. **J4 is now the priority** — group 09 has never appeared in *any* posted file, and `review.md` CR-10 landed a fix there sight-unseen. J5 is a design question before it is a test |

**The one residual that could still hide a real defect: `HR-6 (B)`.** The orientation guard rejects a
tilted `workPlane.forward` — proven over 13 vectors by harness — but **nothing evidences what Fusion
actually puts in `forward` for a re-oriented Setup.** If Fusion re-expresses the frame so `forward` stays
`X0 Y0 Z1`, the guard is a no-op on exactly the case it exists to catch. No code reading can settle it; it
needs a rotated Setup. The failure mode is a **missed** rejection — a part cut in the wrong plane,
silently.

**Closed decisions — do not relitigate.**

- **HP-1's group-03 clause** was amended: group 03 is part of the HP-1 *persona*, not of the config a
  verification post must carry. It cannot execute on a paid licence (`isSafeToRapid()` has one caller,
  `onLinear()`, and full Fusion emits real `G0`s). **Don't re-add it.**
- **`HR-23` / `HR-22 (B)` — an include file substitutes for the phase it names**, modal preamble included.
  A Stop include therefore drops coolant-off, the spindle-off prompt, `M84 S60` and `M30`/`M2`; a Start
  include owns `G90`/`G21`/`G94`/`G17`, and a named-but-*empty* one is the degenerate case of the same
  rule. Both were filed as defects and both resolved as correct. **The reusable lesson: before calling a
  bypass a defect, ask whether the bypass is the feature.** What it needs is a README line.
- **`HR-25` (`wcsGcode(0)` → `G53`) and the `()` empty-comment form** are correct as built — a pure
  conversion should not carry frame policy, and the separator is deliberately comment-level-gated.

**Three things a fresh session will otherwise get wrong.**

1. **Fusion posts with its own copy** of the `.cps` at `%APPDATA%\Autodesk\Fusion 360 CAM\Posts\`. A
   session was once posted twice because the first run used a copy three hours stale, and two rows
   asserting an *absence* would have been recorded as false PASSes. Copy the post, then **date the output**
   against a token the newest commit changed.
2. **Read the posted file's own property dump before believing a row ran.** Six files were once posted
   with the whole `03` group `false`, which left a row unrun rather than passed.
3. **Posted `.gcode` is not in the repo**, so a reused filename destroys evidence with no way back. **Name
   a post for the row it serves** (`HR12a`), not for what the job does, and grep the review files for the
   filename before re-posting.

**No controller access.** Settle firmware questions from Marlin/RRF source and changelogs; never file a
row that needs a non-GRBL machine. Two answered that way: Marlin has never implemented `M2` (RRF gained it
in 3.5.1), and GRBL/Marlin/RRF all accept a bare `\r` as a block terminator. A third: **no supported
firmware has canned drilling cycles** — GRBL omits them deliberately, Marlin's `G81`–`G83` need an opt-in
`CNC_DRILLING_CYCLE` build, and on the RepRap dialect `G80`–`G83` mean mesh-probe/babystep, so emitting
one would be worse than useless. `expandCyclePoint()` is correct and needs no revisiting.

---

## Context and stance

The post targets the V1 Engineering **MPCNC / LowRider** family and similar GRBL / Marlin / RepRap
hobby-class machines. The aim is **production-quality CNC workflows** (multi-fixture, multi-tool, probing,
safe cross-part traverses) that **also degrade simply** for a hobby user on the Fusion Personal licence
cutting a single operation. Both are first-class.

**Development role.** Decisions are made from two expert lenses together: **post-processor engineering**
(clean JavaScript faithful to this post's idioms, careful regression discipline) and **best-practice CNC
operations** (how these machines behave, and what a safe workflow looks like for both personas). The habit
is: settle the CNC-correct workflow first, then design the software that delivers it.

Two principles drive every decision:

- **Work-relative.** Most target machines have no reliable machine-Z (no tool setter, often no Z endstop).
  The everyday reference is the active **WCS**, never the machine frame. Tool length is folded into a **Z
  re-probe after each tool change** (there is no TLO). Homing, where present, gives **X/Y** repeatability
  only.
- **Graceful degradation.** Every advanced feature (reserved base, cross-part safe-Z, per-part probing,
  jog prompts) is opt-in and emits nothing until enabled.
  > **The byte-identical guarantee is gone, deliberately.** This was originally "the default job's output
  > stays byte-for-byte unchanged". The full property dump broke it for comments, **HR-1** broke it for
  > *emitted commands*, and `review.md` CR-6 reordered the tail. What survives is the *shape* — advanced
  > features still emit nothing until enabled. **Treat a future default-output change as a decision to be
  > argued, not a line that cannot be crossed.**

---

## References — Fusion 360 post-processor documentation

- **PostProcessor API class reference** — <https://cam.autodesk.com/posts/reference/classPostProcessor.html>
- **Post Processor Training Guide (PDF)** — <https://cam.autodesk.com/posts/posts/guides/Post%20Processor%20Training%20Guide.pdf>
- **Dumper post** — emits every property/parameter/section value Fusion exposes; run it before relying on
  anything: <https://cam.autodesk.com/hsmposts?p=dump>
- **Library of existing posts** — <https://cam.autodesk.com/hsmposts> · **Forum** —
  <https://forums.autodesk.com/t5/hsm-post-processor-forum/bd-p/218>

Firmware: Marlin <https://marlinfw.org/meta/gcode/> · GRBL 1.1 <https://github.com/gnea/grbl/wiki> ·
FluidNC <http://wiki.fluidnc.com/> · Duet/RRF <https://docs.duet3d.com/User_manual/Reference/Gcodes>

---

## Coordinate model

Production controls keep three references separate: **MCS** (`G53`), **WCS** (`G54`–`G59`, `G59.1`–`G59.3`
on RepRap), and **TLO** (`G43`). Most V1E machines have none fully, hence the work-relative stance.

- **Persistence:** WCS origins are written with `G10 L20 P<n>` on GRBL/RepRap — scoped to that WCS's own
  register. `P` maps 1:1 to Fusion's `workOffset` (P1–P6 = G54–G59; P7–P9 = G59.1–G59.3, RepRap only).
- **Marlin is single-frame:** no per-WCS registers, so one global `G92` origin. A Marlin job using more
  than one distinct work offset is a hard error (Guard C).
- **`workOffset 0`** (Fusion's "default / unset") aliases to WCS 1 / `G54`.
- Helper `writeWcsOrigin(wcsNumber, x, y, z)` persists a position into a WCS's own origin (any axis
  `undefined` = leave alone).

**The post asserts the WCS selection; it never inherits it.** This is the justification for the ordering
in `writeFirstSection()`:

- Fusion **always** supplies a work offset per section, so the post always has a design-time answer.
- `currentWorkOffset` is **not** machine state. `onOpen()` sets it `undefined` — "no work offset emitted
  yet". Because it starts undefined the suppression cannot match on the first section, so section 1
  **unconditionally emits its select**, overwriting whatever the sender left modal. From then on the post
  is the only thing changing the selection. This is exactly why `writeWCS()` runs before `Start()`, the
  base establish and `writeWcsOnStart()`.
- **The distinction that matters:** the post always knows *which* frame is active (it commanded it); it
  never knows *where* that frame is. Register contents are controller-side runtime state and cannot be
  read back. So **selection is deterministic, origin is trusted** — every "Use Active WCS" mode is a trust
  assertion, which is why the *defaults* establish an origin rather than rely on one.
- **Homing does not change a WCS — it makes one trustworthy.** `G54`–`G59` hold offsets from machine zero
  and `$H` never touches those registers. On a homed machine a stored offset points at the same physical
  place across power cycles; with no endstops, machine zero is wherever the controller was last reset. So
  `Home Before Start = None` + `Use Active WCS X0 Y0` after a power cycle is quietly unsound, and worth a
  warning independent of anything else.
- Undefendable by any post: an operator typing `G55` into the console *mid-run*. Out of scope.

## Reserved spoilboard base

For multi-fixture jobs one WCS can be reserved as a **spoilboard base** — a *fixed-surface* zero,
independent of stock thickness. It is the one frame in which a safe height is meaningful across parts of
differing thickness, which is why the cross-part safe-Z feature requires it (Guard B).

- **`A_Spoilboard_BaseReserve`** (`None` default | `G54`–`G59` | `G59.1`–`G59.3 (RepRap)`). When reserved,
  `G59` is the natural choice. Ignored on Marlin (warned).
- **`B_Spoilboard_BaseEstablish`**, default **Pause & Probe Z**: `None` = assume pre-set (Info comment);
  `Probe Z` = probe with no prompt; `Pause & Probe Z` = prompt, probe, prompt. The probe XY offset never
  applies.

**The base probe emits no XY move — the park position is an operator precondition.** The base establish
runs before any origin is established, so there is no frame in which an XY target could be trusted. The
consequence is real and silent: **whatever is under the tool becomes the base's Z0**, so parking over the
stock records the stock top as "the spoilboard" and every clearance derived from it is short by the stock
thickness. Mitigation is documentation, not code. The durable fix is *Future work — a machine-coordinate
base probe point*.

> **Rejected: giving the base an XY origin.** The base stays a Z-only reference.

## Machine frame (homing / MCS)

Group `04`, one enum `A_Machine_HomeBeforeStart`: **None** (default — accept the current position, no
motion), **XY** (the usual case), or **XYZ** (only where wired for it). Per-axis granularity was dropped.

| Firmware | Command |
|---|---|
| Marlin / RRF | `G28 X` / `G28 Y` (XY) then `G28 Z` (XYZ) — independent per axis |
| GRBL / FluidNC | `$H` only — one command homes all configured axes |

On GRBL `$H` is all-or-nothing, so XY and XYZ both emit one `$H` (the mode documents intent).
`B_Machine_PromptBeforeHome` pauses **once before any homing motion**, independent of firmware and axes.
The post does not control homing order. **`$H` is emitted with `writeln()`, not `writeBlock()`** — GRBL
only recognises `$` as a system command when it is the first character of the line (`review.md` CR-1).

## Probing & tool changes

- **Work-Z probing only** (`G38.2`, thickness-compensated, attach/remove pauses). No tool-length system;
  X/Y is never probed.
- **Re-probe after each tool change** is the tool-length substitute (`H_ToolChange_ProbeAfterChange`).
- **Manual tool change:** retract → move to change position → pause → re-probe Z → resume. The ordering
  fix and the base-relative park are in *Remaining work*.

## Validation guards

Post-time only (the post can't read the live controller):

- **Guard A — no base redefine.** *Using* the reserved base is fine; an operation that would
  **re-establish** its origin errors.
- **Guard B — safe-Z across parts needs a base.** `C_Spoilboard_SafeZAcrossWcs` on + >1 distinct offset on
  GRBL/RRF + no base reserved → error. Single-WCS jobs are exempt.
- **Guard C — Marlin single-frame.** A Marlin job using >1 distinct work offset → hard error.

Guards A/B/C run in `onOpen()`, before any output, so a rejected job writes **no file at all**. Two
non-fatal `warning()`s run alongside them (`review.md` CR-2, CR-3): homing combined with a
`Set … to Current Pos` origin mode, and a multi-tool job with group 07 off. The two *geometry* guards
(multi-axis, and HR-6's orientation check) fire later, in `onSection()`, and can therefore leave a
truncated file on disk — promoting both into `validateJob()` is a recorded follow-up.

## Property / dialog conventions

- **Group order** = the `group:` string, zero-padded to two digits, so `11 - Duet` sorts last. Current:
  `01 - Job`, `02 - Feeds and Speeds`, `03 - Map G1s to Rapids…`, `04 - Establish Machine Coordinates`,
  `05 - Establish Spoilboard Reference`, `06 - On WCS / Part / Fixture Changes`, `07 - Tool Changes`,
  `08 - External Include Files`, `09 - Laser`, `10 - Coolant`, `11 - Duet`.
- **Within-group order** = a single-letter key prefix, `<Letter>_<Group>_<Name>`, restarting per group.
  New properties take the next free letter (re-letter following ones if inserting mid-group).
- **The literal is now declared in that same order** (`review.md` CR-14), so display order no longer rests
  solely on Fusion sorting. Keep it that way when adding a property.
- This post uses the **combined-inline** `properties = {}` form. The split `properties` +
  `propertyDefinitions` form is the *old broken* approach — do not reintroduce it.
- **What resets a saved preset:** the **key** is the stored identifier, so renaming or re-lettering a key
  resets that property to its default, as does changing an enum **`id`** or a boolean→enum conversion.
  Changing only a `group:` string, a title, an option title, or the declaration *order* does **not**. Every
  reset is a release-notes item.

**Origin/probe controls (group `06`).** Three separate controls — merging the two origin controls was
rejected, since it would apply job-start XY-zeroing to a mid-job WCS change. Both dropdowns are ordered
default-first, and both defaults are **no-prompt** modes because jogging at a pause isn't universally
supported.

- `A_Probe_OnStart` = **"First WCS / Part"** — `Set X0 Y0 to Current Pos, Probe Z0` (default) /
  `Set X0 Y0 Z0 to Current Pos` / `Use Active WCS X0 Y0, Probe Z0` / `Use Active WCS X0 Y0 Z0` /
  `Jog to X0 Y0, Probe Z0` / `Jog to X0 Y0 Z0`. The *Current Pos* modes assume a pre-jog; the *Use Active
  WCS* modes trust the stored fixture offset; the *Jog* modes pause (M0).
- `B_Probe_OnChange` = **"Subsequent WCS / Part"** — the same four non-Current modes, default
  `Use Active WCS X0 Y0, Probe Z0`. Fires on a genuine WCS change after the first section.
- `C_Probe_Pause` = **"Probe Pause"** — `No` / `Before` / `Before & After` (default). Gates the
  attach/detach prompts for the **part** probes only; adds no new stops.

> **"Use Active WCS", not "Use Existing WCS".** "Existing" read as a *temporal* claim — the WCS active
> before the job — which is wrong: the register is the one this Setup designates, and the post *selects*
> it at job start.

**Two properties were both titled "Safe Z".** Group 05's is now **"Inter Part Safe Z"** (whole mm above
the spoilboard); group 06's `I_Probe_SafeZ` keeps "Safe Z" (the post-probe retract). Keys unchanged.

---

## Design notes that constrain the remaining work

### Traverse clearance is not the G1→G0 plane

`C_MapRapids_SafeZ` answers a narrower question — "within *this* operation, is Z high enough to re-emit a
cut G1 as a G0?" It is operation-scoped and only populated when the hobby group is on, so it is the wrong
source for an inter-op/inter-WCS retract. The cross-part retract uses a **job-level clearance measured
above the spoilboard base** (`D_Spoilboard_SafeZClearance`).

**Why the Inter Part Safe Z can't be an F360 expression (asked and answered).** `Clearance:40` would parse
today, and it is still the wrong source: every F360 height parameter is **per-operation and expressed in
that operation's own WCS**, while this must be expressed in the **base's** frame — feeding a part-frame
number into a base-frame `G0 Z` under-clears by the stock thickness, silently. F360 has no job-level
"above the machine table" height at all; the base frame is a post-invented concept. So it stays a plain
whole-mm `integer`. If an expression is ever wanted here, the only sound use is as a **floor**
(`max(constant, resolved)`), never a substitute.

### Base WCS is transited, not parked (R1/R2)

The base-relative retract must *select* the base to move in its frame (the numeric relation between two
WCS is only known after runtime probing). Two rules:

- **R1 — always restore the operating WCS.** After a base transit, advance to the next operation's WCS
  before any cutting; never cut with the base left active.
- **R2 — never round-trip the base empty.** Enter the base only when a real move is emitted there.

Mechanism (`retractThroughBaseClearance()`): transit-select the base with a low-level `writeBlock`
(**not** `writeWCS()` — no re-probe, no origin write), emit the `G0 Z` clearance, leave the base active;
the caller then selects the destination WCS. No base transit at `onClose`.

The same rules govern the **base establish**: it transit-selects the base *before* probing so that both the
`G38.2` target and the post-probe retract are measured against the base, then restores the operating WCS.

> **Superseded reasoning, kept because it is the plausible wrong answer.** An earlier note argued the base
> establish needed no `G59` select, since `G10 L20` does not change the active WCS. Correct as far as it
> goes — but it missed that the base's own probe and its post-probe retract would then execute in the
> *part's* frame, whose Z may be stale. **The missing select was the defect.**

### Why the first section's arrival is asymmetric

In `writeWCS()`, `isTraverse = (previousWorkOffset != undefined)` is false on the first section, so the
first section skips **both** the safe-Z retract and the origin/probe dispatch that every later WCS change
gets. Un-suppressing it where it sits does **not** work:

- **Ordering.** `writeWCS()` is step 3 of `writeFirstSection()`; `writeBaseEstablish()` is step 5. At step
  3 *neither* the part WCS's Z nor the base's Z has been established, so both retract paths would emit an
  absolute `G0 Z` into a stale frame — the same defect relocated.
- **Direction.** An absolute Z against a stale zero can move the tool *down*.
- **Blast radius.** With `isTraverse` true on the first section, the fallback fires on *every* job.

The resolution keeps the intent and fixes the placement: the first section's safe arrival happens **after**
the base establish, in the base's frame. And it exposes a hard limit — **with no base reserved there is no
established frame at job start at all**, so no retract can be made safe there. That case gets an Info
comment instead (`Ensuring that Z is safe. Unknown Z for XY move.`), emitted only on the one path that
deliberately emits no absolute Z move and only when no base is established.

---

## Phase status

- **Phase 1–3 — done & verified.** WCS origin/probe rework to `G10 L20`; `writeWcsOrigin()`; MCS homing;
  reserved base + establish + Guards A/B/C.
- **Phase 4 — in progress.** Landed and verified: Guard B; Inter Part Safe Z + Retract Across Parts; the
  base-relative transit-through-base retract; added-part re-probe repositioning; the base-frame base
  establish; the six-mode first-part origin model; the full property dump; the group/label rework. Landed
  with verification pending: the probe XY offset's added-part halves and the multi-part rows generally.
  **Remaining to build:** tool-change ordering + base-relative park (below).
- **Phase 5 — answered, no work needed.** `isSafeToRapid()` is called only from `onLinear()` and is scoped
  to a single section, so the G1→G0 mapper cannot run across the boundaries Phase 4 injects logic at.
  Close it as a no-op when Phase 4 lands.
- **Hobbyist review — complete.** `HReview.md`.
- **Full code review — complete.** `review.md`; 14 fixes at `c73726c`, post-verification owed.
- **Professional review — not started.** `PReview.md` is a parking lot until it runs.

## Completed reviews (archived)

Every finding is fixed in `MPCNC_v4.0_Beta2.cps` and preserved in git. Recover the rationale if needed:

- **Code-quality review** — 26 findings, all fixed. `git log --follow -- docs/known-issues-v4.md`
- **Autodesk / F360 compliance review** — F1–F11, all resolved. `git log --follow -- docs/f360-compliance-issues.md`
- **Floating-point comparison review** — FP1 fixed. `git log --follow -- docs/float-comparison-review.md`
- **Beta-2 test plan** — dissolved into the review files. `git log --follow -- docs/test-plan.md`

---

## Remaining work (pick up here)

### Phase 4 — tool-change ordering + base-relative park *(one unit; design settled)*

> **This is the Tool Change branch's work.** Tool changes are a professional feature, so this item and the
> five deferred findings — **HR-7**, **HR-8**, **HR-9**, **HR-10**, **HR-13** — land together on a separate
> branch. Read each one's entry in `PReview.md` §2 first; **HR-10 and HR-13 have complete diffs and are
> independent of the reorder**, so they can go in first as warm-up commits.

Root cause: in `onSection()`, `toolChange()` runs **before** `writeWCS(currentSection)` for non-first
sections, so a boundary that is both a tool change and a WCS change **re-probes into the wrong WCS**
(`toolChange()`'s re-probe writes `G10 L20` into `currentWorkOffset`, still the *previous* part's WCS) and
**parks in the wrong frame**.

Fix — reorder so the WCS is resolved before the tool-change re-probe, and coordinate the two so a combined
boundary does each thing once:

1. Run `writeWCS()` first — it owns the base retract and the frame switch. When a tool change on the same
   section will re-probe, have `writeWCS()` **skip its own `B_Probe_OnChange` probe** and let the
   tool-change flow own the single re-probe, now into the correct WCS.
2. The tool-change re-probe **repositions to the new part's `X0 Y0`** before measuring (the same fix
   already applied to the added-part probe), so it reads the stock top and not the park point.
3. **Park position, two branches (decision):** base reserved → park relative to the base (a fixed physical
   spot for the whole job), reusing the transit-select machinery; no base → plain `G0` in the current WCS,
   as today. **Never `G53`.** *(The stale code comment at the tool-change position still argues for `G53`;
   remove it with this work.)*

Net at a both-boundary: retract through base → switch WCS → park → swap → rapid to `X0 Y0` → probe once
into the correct WCS. Test matrix in `PReview.md` §3.4.

### Future work — a machine-coordinate base probe point (`G53`) *(not started; design sketch)*

The base probes wherever the tool is parked, defended only by an operator precondition. The durable fix is
to give the base an explicit **probe point in machine coordinates** — `G53 G0 X<n> Y<n>` before the
`G38.2` — so the touch-off lands on the same bare-spoilboard spot every run.

**Rejected: `G53 G0 X0 Y0` (machine zero itself).** It is the homing corner — the extreme of travel,
routinely off the spoilboard entirely; it is machine-config dependent (`$23`/`$27`/`$130`–`$132`); and Z is
unsolved. Today the base establish emits *no motion at all*, so the unknown Z is inert; adding a traverse
converts that into a full-bed diagonal at an unknown height.

**Sketch, if built.** A group-05 property pair (base probe point X/Y, machine coordinates, whole mm),
emitted as `G53 G0 X<n> Y<n>` immediately before the base `G38.2`, plus:

- **Guard: requires homing.** Refuse (or warn) when `A_Machine_HomeBeforeStart = None` — machine zero is
  arbitrary there. This is the first place groups `04` and `05` interact, and why they sit adjacent.
- **An answer for Z:** require `XYZ` homing, or precede the move with an `M0` *"jog clear in Z, then
  continue"*. The prompt is preferred — it works on the no-Z-endstop machines that are the majority.
- **Default off** (empty = today's probe-where-parked behaviour).

**Reconcile `G53` across all three uses before building any of it.** This file carries a standing **"Never
`G53`"** decision. The three candidate uses — base probe point, tool-change park, cross-part retract —
should be decided **together**, since they share one question: *does this post ever address the machine
frame directly, or is everything work-relative?* The current answer is "everything work-relative"; this
item is the strongest case for revisiting it, because a spoilboard is the one thing in the job that
genuinely is fixed to the machine.

### Backlog

- **"Copy first part's Z" mode on `B_Probe_OnChange`.** Write the first part's probed Z into each added
  copy's own register (`G10 L20 P<n> Z<firstPartZ>`) — a register write, **no motion, no probe** — for
  same-thickness co-planar fixtures. Requires caching the first part's probed Z. Marlin no-op.
- **WCS `0`/`1` mixed-design warning (human factors).** A job using work offset `0` in one section and `1`
  in another resolves both to `G54`, but reads as two deliberate fixtures in Fusion's Operations panel.
  Emit a `>>> WARNING` when a job mixes `0` with a *different* explicit offset. The correct rule is
  any-section-vs-any-other-section, broader than Fanuc's order-dependent check.
- **`useZeroOffset` enforcement.** `wcsDefinitions.useZeroOffset: false` is declared but likely inert — the
  enforcing `validateCommonParameters()` lives in a shared post library this post doesn't import, so
  `writeWCS()` still silently aliases `0`→`1`. Natural companion to the item above.
- **`permittedCommentChars` global.** A comparable community GRBL post declares it; research whether it
  adds real kernel-side filtering on top of `sanitizeMessageText()` before adding — may be informational.
- **Global-metadata gaps.** Optionally `model`. Cosmetic.

---

## Workflow notes

- **`node --check MPCNC_v4.0_Beta2.cps` is a valid syntax gate** — run it after every edit.
- **Individual functions can be brace-matched out of the `.cps` and `eval`'d in node against stubbed kernel
  globals.** `propertyMmToUnit`, `getProperty`, `getCircularPlane`, `hasParameter`, `cycleType`, `unit`,
  `Vector` and a fake section are all easy to fake. Not a substitute for posting, but it settles
  arithmetic cheaply.
- **Run the harness against `HEAD` as well as the working tree** (`git show HEAD:MPCNC_v4.0_Beta2.cps` to a
  temp file, taking the path as `argv[2]`). A harness that only passes on the fixed file cannot tell you it
  would have caught anything.
- **Bind extracted functions as *expressions*** — `eval('(' + src + ')')`. A bare declaration (or a
  `const`/`let`) inside `eval()` does not leak to the caller's scope under `'use strict'`.
- **Make a harness abort rather than report when its extraction yields nothing.** One sweep harness
  over-ran its terminator, left the properties object **empty**, and reported eight vacuous passes.
- **A pure reorder can be proved safe by matching sorted-line checksums** against `HEAD` — that is how
  CR-14's properties move was shown to change no character of any key, title or default.
- **`git commit -m` with a PowerShell here-string mangles messages containing double quotes** — write the
  message to a file and use `git commit -F`.

---

## Decisions (resolved)

- **`B_Machine_PromptBeforeHome`** pauses once before any homing motion, on any firmware and for any axes.
- **Homing is one enum (None / XY / XYZ)**; homing order is not post-controlled.
- **`B_Spoilboard_BaseEstablish`** defaults **Pause & Probe Z**; `None` emits an "assumed pre-set" comment.
- **Marlin multi-WCS is a hard post error** (Guard C).
- **No real TLO** — per-tool re-probe is the substitute.
- **Multi-WCS supports two coexisting per-part workflows** — one WCS per part/copy. (1) *Pre-set fixture
  offsets (Replicate):* `Skip` or `Probe Z`. (2) *Manual per-part:* the two `Jog …` modes. One part from
  **multiple datums on the same fixture** is supported (`PReview.md` PA1); a **flip or re-clamp** is out of
  scope for a single run — separate jobs.
- **Tool-change position:** base-relative when a base is reserved, else current-WCS. Never `G53`.
  *(Current code does only the no-base branch.)*
- **HR-11's `M84 S60`, not a bare `M84`** — restore a 60-second timeout rather than dropping Z on an
  unbalanced LowRider gantry.
- **Tool changes and Manual NC are professional features** — their findings live in `PReview.md`.
- **An include file substitutes for the phase it names** (HR-23 / HR-22 (B)); `wcsGcode()` carries no frame
  policy (HR-25); the `()` empty-comment separator is comment-level-gated on purpose.

**Open decisions carried forward.** Each is written up where it lives:

- whether first-part `Use Active WCS X0 Y0 Z0` should hold the base clearance instead of descending to the
  probe Safe Z when a base is reserved *(`PReview.md` §6)*;
- `wcsDefinitions` offset-`0` handling *(backlog above; test row in `PReview.md` §3.4)*;
- whether the spoilboard base should gain an explicit probe-point XY *(Future work — `G53`, above)*;
- whether the **added-part** `Jog to X0 Y0, Probe Z0` should get HR-1's provisional `Z0` for symmetry
  *(settle on the PA1/M4 run)*;
- whether **HR-2's** two-signal probe guard keeps its extra breadth or trims to the strict reference form;
- how **HR-26** should be closed — `writeBaseEstablish()` skips the probe for a jet/tool-0 job, but
  `retractThroughBaseClearance()` has no matching guard and will still emit an absolute `G0 Z` in a frame
  whose Z0 was never set. **The one place the "never move absolutely in an unestablished frame" rule is
  broken.** Candidates: a module-level `baseEstablished` flag, a `validateJob()` refusal, or falling back
  to the outgoing frame's probe Safe Z *(`PReview.md` §3.4)*;
- whether `onClose()`'s return-to-origin should retract Z first — declined for milling, still owed for jet
  *(`review.md` CR-6, `PReview.md` §5)*.

*The frame-dependence of the `G38.2` probe target is closed on the first-part probe modes (HR-1). It
remains open for the `Use Active WCS`, added-part and base probes, which descend from a retracted clearance
and would be made **worse** by the same fix.*

**README.** Doc-sync marker points at `924d1f6`. Standing preference: **the README is not touched during
code changes unless asked.** Owed to the next sync, list kept in `HReview.md` → *Owed* item 6: the stale
group-03 label, the group-08 "post processor might be unsafe" prompt, HR-23's substitution contract, and
the `Tool Change Probe` field that does nothing. **Add from `review.md`:** the coolant `... Custom` fields
now load a file (CR-4), and the `Use Active WCS X0 Y0 Z0` Safe Z move can descend (CR-16).

---

## Reference — per-machine settings

| Machine / firmware | Home Before Start | Prompt Before Home | Reserved base | Operator does |
|---|---|---|---|---|
| LowRider (Marlin or FluidNC) | `XYZ` if Z endstops fitted, else `XY` | Off | `G59` if multi-fixture, else `None` | homes X/Y; work-Z touched off with the plate either way |
| MPCNC + FluidNC, X/Y switches | `XY` | Off | `G59` if multi-fixture | homes X/Y; machine Z n/a, Z set by the work plate |
| MPCNC + Marlin, plate as Z-endstop | `XYZ` | On | `G59` if multi-fixture | homes X/Y; at the pause places the movable plate, then Z homes to it |
| MPCNC, no switches | `None` | Off | `G59` if multi-fixture | parks X/Y by hand as zero; Z set by the work plate |
| Single-part job (any machine) | per row above | per row above | `None` | one WCS zeroed to the part; no base |

> **Note the interaction** (`review.md` CR-2): any row above with homing on must **not** use a
> `Set … to Current Pos` origin mode — homing moves the tool, and the origin would be recorded at the
> endstop corner. `validateJob()` now warns.
