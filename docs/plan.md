# WCS / Origin Rework — design record & remaining work

The developer/design record for the coordinate/probe/tool-change rework in
`MPCNC_v4.0_Beta2.cps`. Implemented mechanics live in the code; only the **enduring decisions**, the
**design that constrains unbuilt work**, and the **backlog** are kept here.

User-facing usage (hobby vs. Replicate flows, per-machine setup) lives in `README.md`. Verification
and findings live in the two review files:

| File | Owns |
|---|---|
| `docs/HReview.md` | The hobbyist review, its nine landed fixes, and the hobbyist verification record |
| `docs/PReview.md` | The professional side: six deferred findings, every multi-WCS / base / tool-change / dialog test row, and the jet/laser workstream. **The professional review itself has not been done** |
| this file | Design record, remaining work, resolved decisions |

---

## Checkpoint — restart here

*Written so a fresh session can resume with no other context. Update it when the situation moves.*

**Baseline.** Branch **`v4.0-hreview-fixes`**, cut from `wcs-reworked-flow` at `baf37bf`. Working tree
clean apart from an untracked `MPCNC_v4.0_Beta1.zip` (unrelated; add it or ignore it). **Nothing is
half-done and nothing is known-broken.**

**The branch's code work is done.** Every hobbyist-scoped finding that had a fix is landed; what is
left on this branch is **posting**, not coding — three sessions, ranked and specified in
`HReview.md` §3. Start with **Marlin + RRF**: it clears the most rows in one firmware switch and
carries the branch's only open correctness question (whether `M2` is honoured at all).

**Standing rule — a code change is not done until its review file is updated**, in the same commit:
hobbyist behaviour → `HReview.md`, professional behaviour → `PReview.md`. Add the Do→Get row, name the
discriminator, and flag any row whose saved `.gcode` the change invalidates. The full rule is at the
top of each file. It is a priority, not a courtesy — a stale PASS is worse than an unrun test.

**How verification works here:** post the job from Fusion and read the g-code. Machine dry-runs and
physical measurement are out of scope, so every row must stand on the posted file alone.

**Next actions, in order.**

1. **Post the five unverified fixes** — the three sessions in `HReview.md` §3 (Marlin+RRF → drill+tap
   GRBL → GRBL inch). This is the whole remaining job on this branch.
2. **Sweep HR-17's tidy-ups** — four cosmetic items, one commit, no decisions (`HReview.md` §4.3).
3. **Dialog-only checks, no posting** — **D1** and **D3**'s dialog half (`PReview.md` §3.3). D3 gates
   trust in every dialog row: only `group:` strings changed, so a saved preset should survive, but a
   posted file cannot tell a surviving preset from re-entered values.
4. **Open the Tool Change branch** — *Phase 4 — tool-change ordering + base-relative park* below,
   folded together with **HR-7/8/9/10/12/13** (`PReview.md` §2). Design settled for the ordering half;
   nothing depends on it and the base machinery underneath is verified.
5. **The professional review proper** — the pass that produces `PReview.md`'s real content, using the
   method `HReview.md` used. Needs a multi-part / multi-fixture job to post against.
6. **Jet / laser workstream** (`PReview.md` §5) — J5 is a design question before it is a test.

**Open decisions carried forward.** Each is written up where it lives:

- whether first-part `Use Active WCS X0 Y0 Z0` should hold the base clearance instead of descending to
  the probe Safe Z when a base is reserved *(below, and `PReview.md` §6)*;
- `wcsDefinitions` offset-`0` handling *(backlog below; test row in `PReview.md` §3.4)*;
- whether the spoilboard base should gain an explicit probe-point XY rather than relying on the park
  precondition *(Future work — `G53`, below)*;
- whether the **added-part** `Jog to X0 Y0, Probe Z0` should get HR-1's provisional `Z0` for symmetry
  *(`HReview.md` HR-1; settle on the PA1/M4 run)*;
- whether **HR-2's** two-signal probe guard keeps its extra breadth or trims to the strict reference
  form *(`HReview.md` HR-2)*.

*The frame-dependence of the `G38.2` probe target is no longer open on the first-part probe modes —
HR-1 closed it there. It remains open for the `Use Active WCS`, added-part and base probes, which
descend from a retracted clearance and would be made **worse**, not better, by the same fix.*

**One doc loose end.** `README.md`'s doc-sync marker at the top points at a pre-`25768ec` ref, so it
understates what the README already covers. Standing preference: the README is not touched during code
changes unless asked.

---

## Context and stance

The post targets the V1 Engineering **MPCNC / LowRider** family and similar GRBL / Marlin / RepRap
hobby-class machines. The aim is **production-quality CNC workflows** (multi-fixture, multi-tool,
probing, safe cross-part traverses) that **also degrade simply** for a hobby user on the Fusion
Personal licence cutting a single operation. Both are first-class.

**Development role.** This code is developed by an agent acting in two expert capacities at once, and
decisions are made from both lenses together:

- an **expert software developer** — Fusion 360 post-processor engineering in JavaScript: clean,
  maintainable code faithful to this post's existing idioms (e.g. the combined-inline `properties`
  form), with careful regression discipline;
- an **expert in best-practice CNC operations** — how these machines actually behave, and what a safe
  workflow looks like for both the **V1E hobbyist** (Personal licence, single operation, manual
  zeroing) and the **professional** (multi-fixture, multi-tool, probing, multiple WCS).

The habit is: settle the CNC-correct workflow first (what a seasoned operator would want to happen at
the machine), then design the software that delivers it.

Two principles drive every decision:

- **Work-relative.** Most target machines have no reliable machine-Z (no tool setter, often no Z
  endstop). The everyday reference is the active **WCS**, never the machine frame. Tool length is
  folded into a **Z re-probe after each tool change** (there is no TLO). Homing, where present, gives
  **X/Y** repeatability only; Z homing exists for its own sake and never becomes the everyday Z
  reference.
- **Graceful degradation.** Every advanced feature (reserved base, cross-part safe-Z, per-part
  probing, jog prompts) is opt-in and emits nothing until enabled.
  > **Twice amended — the byte-identical guarantee is gone, deliberately.** This was originally
  > "the default single-operation job's output stays byte-for-byte unchanged". The **full property
  > dump** broke it for header comments (~98 Info lines added to every file), because a file that
  > cannot be reviewed without guessing its settings was judged the worse failure. Then **HR-1** broke
  > it for *emitted commands* on a default job, appending `Z0` to the default origin write, because an
  > unbounded probing descent on the path every hobbyist uses was the worse failure. What survives is
  > the *shape* — advanced features still emit nothing until enabled. What does not survive is any byte
  > anchor against a pre-rework reference. Treat a future default-output change as a decision to be
  > argued, not a line that cannot be crossed. *(`HReview.md` HR-1 and §5's H-REG note.)*

---

## References — Fusion 360 post-processor documentation

Captured so they don't have to be rediscovered:

- **PostProcessor API class reference** — authoritative list of hooks and helpers:
  <https://cam.autodesk.com/posts/reference/classPostProcessor.html>
- **Post Processor Training Guide (PDF)**:
  <https://cam.autodesk.com/posts/posts/guides/Post%20Processor%20Training%20Guide.pdf>
- **Dumper post** — emits every property / parameter / section value Fusion exposes for a CAM job; run
  it to discover what's actually available before relying on it: <https://cam.autodesk.com/hsmposts?p=dump>
- **Library of existing posts**: <https://cam.autodesk.com/hsmposts>
- **HSM post-processor forum**: <https://forums.autodesk.com/t5/hsm-post-processor-forum/bd-p/218>

Firmware g-code references: Marlin <https://marlinfw.org/meta/gcode/> · GRBL 1.1 wiki
<https://github.com/gnea/grbl/wiki> · FluidNC wiki <http://wiki.fluidnc.com/>

---

## Coordinate model

Production controls keep three references separate: **MCS** (`G53`, from homing), **WCS**
(`G54`–`G59`, `G59.1`–`G59.3` on RepRap), and **TLO** (`G43`, from a tool setter). Most V1E machines
have none fully, hence the work-relative stance.

- **Persistence:** WCS origins are written with `G10 L20 P<n>` on GRBL/RepRap — scoped to that WCS's
  own register, no cross-contamination. `P` maps 1:1 to Fusion's `workOffset` (P1–P6 = G54–G59;
  P7–P9 = G59.1–G59.3, RepRap only; GRBL is P1–P6).
- **Marlin is single-frame:** no per-WCS registers, so it uses one global `G92` origin. A Marlin job
  using more than one distinct work offset is a hard error (Guard C).
- **`workOffset 0`** (Fusion's "default / unset") aliases to WCS 1 / `G54`.

Helper `writeWcsOrigin(wcsNumber, x, y, z)` persists a position into a WCS's own origin (any axis
`undefined` = leave alone); `G10 L20` on GRBL/RepRap, `G92` on Marlin.

**The post asserts the WCS selection; it never inherits it.** This is the justification for the
ordering in `writeFirstSection()` and the answer to "what if the operator changed WCS at the sender
first?":

- Fusion **always** supplies a work offset per section (`0` for unset/default, else `1`–`9`), so the
  post always has a design-time answer for every section.
- `currentWorkOffset` is **not** the machine's state. `onOpen()` sets it to `undefined` — "no work
  offset emitted yet". It records only what *this post* has emitted, and exists to suppress redundant
  selects.
- Because it starts undefined, the suppression cannot match on the first section, so the first section
  **unconditionally emits its select**, overwriting whatever the sender left modal. From then on the
  post is the only thing changing the selection, so its model and the controller agree by
  construction. This is exactly why `writeWCS()` runs before `Start()`, the base establish and
  `writeWcsOnStart()` — it defends against both a stale WCS left active by a prior job and the
  controller's power-on default.
- **The distinction that matters:** the post always knows *which* frame is active (it commanded it); it
  never knows *where* that frame is. Register contents are controller-side runtime state (GRBL
  persists `G10 L20` to EEPROM), set by prior jobs or manual touch-offs, and the post cannot read them
  back. So **selection is deterministic, origin is trusted** — every "Use Active WCS" mode is a trust
  assertion, which is why the *defaults* establish an origin rather than rely on one. On a fresh GRBL
  controller all offsets are `0`, so `G54` means machine coordinates — on a machine with no endstops,
  power-on position.
- Undefendable by any post: an operator typing `G55` into the console *mid-run*. Out of scope.

## Reserved spoilboard base

For multi-fixture jobs one WCS can be reserved as a **spoilboard base** — a *fixed-surface* zero
(the spoilboard, independent of stock thickness). It is the one frame in which a safe height is
meaningful across parts of differing thickness, which is why the cross-part safe-Z feature requires it
(Guard B).

- **`A_Spoilboard_BaseReserve`** (`None` default | `G54`–`G59` | `G59.1`–`G59.3 (RepRap)`). Default
  `None` keeps the default job unchanged. When reserved, `G59` is the natural choice (highest GRBL
  slot, keeps `G54` free for parts). Ignored on Marlin (warned).
- **`B_Spoilboard_BaseEstablish`** ("Probe to Set Base") enum, default **Pause & Probe Z** (option
  title *Pause, Probe Z, Pause*): `None` = assume pre-set (probe-once/run-many, Info comment);
  `Probe Z` = probe with no operator prompt; `Pause & Probe Z` = prompt to attach, probe, prompt to
  detach. The probe XY offset never applies.

**The base probe emits no XY move — the park position is an operator precondition.**
`writeBaseEstablish()` positions nothing before its `G38.2`: it probes the surface under the tool at
job start. The omission is deliberate and hard to remove — the base establish runs before any origin is
established, so there is no frame in which an XY target could be trusted, and the base's own X0 Y0 may
never have been set at all. The consequence is real and silent: **whatever is under the tool becomes
the base's Z0**, so parking over the stock records the stock top as "the spoilboard" and every
clearance derived from it is short by the stock thickness. Mitigation is documentation, not code — the
operator parks over bare spoilboard, clear of stock and clamps. The durable fix is sketched under
*Future work — a machine-coordinate base probe point*.

**The base is transited, not parked** — see *Base WCS is transited, not parked* below; it governs the
retract and the tool-change park.

## Machine frame (homing / MCS)

Group `04 - Establish Machine Coordinates`, one enum `A_Machine_HomeBeforeStart`: **None** (default —
accept the current position, including an axis already homed at the controller or a power-on 0,0,0; no
motion), **XY** (the usual case), or **XYZ** (only where the machine is wired for it). Per-axis
granularity was dropped: the only combinations any target machine wants are None / XY / XYZ.

| Firmware | Command |
|---|---|
| Marlin / RRF (Duet) | `G28 X` / `G28 Y` (XY) then `G28 Z` (XYZ) — independent per axis |
| GRBL / FluidNC | `$H` only — one command homes all configured axes |

On GRBL/FluidNC `$H` is all-or-nothing, so XY and XYZ both emit one `$H` (the mode only documents
intent). `B_Machine_PromptBeforeHome` (default off) pauses **once before any homing motion**,
independent of firmware and of which axes home — so it never needs revisiting when the machine changes
(place a movable Z plate, clear the bed, etc.). The post does not control homing order.

## Probing & tool changes

- **Work-Z probing only** (`G38.2`, thickness-compensated, attach/remove pauses). No tool-length
  system; X/Y is never probed.
- **Re-probe after each tool change** is the tool-length substitute (`H_ToolChange_ProbeAfterChange`).
- **Manual tool change:** retract → move to change position → pause → re-probe Z → resume. The
  ordering fix and the base-relative park are in *Remaining work*.

## Validation guards

Post-time only (the post can't read the live controller):

- **Guard A — no base redefine.** *Using* the reserved base is fine; an operation that would
  **re-establish its origin** (via `A_Probe_OnStart` / `B_Probe_OnChange` /
  `H_ToolChange_ProbeAfterChange`) errors.
- **Guard B — safe-Z across parts needs a base.** `C_Spoilboard_SafeZAcrossWcs` on + >1 distinct
  offset on GRBL/RRF + no base reserved → error. Single-WCS jobs are exempt.
- **Guard C — Marlin single-frame.** A Marlin job using >1 distinct work offset → hard error.

Guards A/B/C run in `onOpen()`, before any output, so a rejected job writes **no file at all**. The two
*geometry* guards (multi-axis, and HR-6's orientation check) fire later, in `onSection()`, and can
therefore leave a truncated file on disk — promoting both into `validateJob()` is a recorded follow-up
(`HReview.md` §4.1).

## Property / dialog conventions

Needed when adding new properties:

- **Group order** = the `group:` string, zero-padded to two digits. Padding is required so `11 - Duet`
  sorts last, not next to `01 - Job`. Current order: `01 - Job`, `02 - Feeds and Speeds`,
  `03 - Map G1s to Rapids…`, `04 - Establish Machine Coordinates`,
  `05 - Establish Spoilboard Reference`, `06 - On WCS / Part / Fixture Changes`, `07 - Tool Changes`,
  `08 - External Include Files`, `09 - Laser`, `10 - Coolant`, `11 - Duet`.
- **Within-group order** = a single-letter item prefix on the key, `<Letter>_<Group>_<Name>`
  (restarting per group). New properties take the next free letter (re-letter following ones if
  inserting mid-group).
- This post uses the **combined-inline** `properties = {}` form (title/description/type/value inline).
  The split `properties` + `propertyDefinitions` form is the *old broken* approach — do not
  reintroduce it.
- **What resets a saved preset:** the **key** is the stored identifier, so renaming or re-lettering a
  key resets that property to its default, as does changing an enum **`id`** or a boolean→enum
  conversion. Changing only a `group:` string, a title, or an option title does **not**. Every reset is
  a release-notes item. *(Rationale for the current group layout: groups `04`/`05`/`06` — machine
  coordinates, spoilboard, parts — are one physical setup sequence and now sit contiguous and in
  machine-execution order, with the two tuning groups ahead of them. The moves that produced it changed
  only `group:` strings; the earlier `Probe`→`Spoilboard` key renames did reset presets.)*

**Origin/probe controls (group `06`).** Three separate controls — merging the two origin controls was
rejected, since it would apply job-start XY-zeroing to a mid-job WCS change, a positioning bug. Enum
`id`s in parentheses; both dropdowns are ordered **default-first**, and both defaults are **no-prompt**
modes because jogging at a pause isn't universally supported.

- `A_Probe_OnStart` = **"First WCS / Part"** — `Set X0 Y0 to Current Pos, Probe Z0`
  (`Current XY & Probe Z`, default) / `Set X0 Y0 Z0 to Current Pos` (`Current XYZ`) /
  `Use Active WCS X0 Y0, Probe Z0` (`Probe Z`) / `Use Active WCS X0 Y0 Z0` (`Skip`) /
  `Jog to X0 Y0, Probe Z0` (`Jog XY & Probe Z`) / `Jog to X0 Y0 Z0` (`Jog XYZ`). The *Current Pos*
  modes assume a pre-jog (no prompt); the *Use Active WCS* modes trust the stored fixture offset (rapid
  to its X0 Y0, optionally re-probe Z); the *Jog* modes pause (M0) so the operator jogs during the run.
- `B_Probe_OnChange` = **"Subsequent WCS / Part"** — `Use Active WCS X0 Y0, Probe Z0` (`Probe Z`,
  default) / `Use Active WCS X0 Y0 Z0` (`Skip`) / `Jog to X0 Y0, Probe Z0` / `Jog to X0 Y0 Z0`. Fires
  on a genuine WCS change after the first section. Two coexisting workflows: the *Use Active WCS* modes
  take XY from the fixture's pre-set offset (Replicate); the *Jog* modes let the operator jog to each
  part and record its origin.
- `C_Probe_Pause` = **"Probe Pause"** — `No` / `Before` / `Before & After` (default). Gates the
  attach/detach prompts for the **part** probes (first + added); it adds no new stops. Threaded to
  `probeTool()` via module-level `probePauseBefore`/`probePauseAfter`, which the base establish sets too
  and `probeTool()` resets after each probe, so the tool-change re-probe still prompts.

> **Rejected: giving the base an XY origin** ("Spoilboard WCS is / Zero XY, Probe Z"). The base stays a
> Z-only reference; the enum mirrors the part-probe `Probe Pause` control instead.

**"Use Active WCS", not "Use Existing WCS".** "Existing" read as a *temporal* claim — the WCS that was
already active before the job — which is wrong: the register is the one this operation's Fusion Setup
designates, and the post *selects* it at job start, overwriting whatever the sender had. The word was
accurate about the register's *contents*, which is why the misread was easy. Both tooltips now spell
out which register, that it is not the sender's current selection, and that the stored values are
trusted-not-verified because the post cannot read them back.

**Two properties were both titled "Safe Z"**, in different groups and different frames. Group 05's is
now **"Inter Part Safe Z"** (whole mm above the spoilboard; consumers are the post-base-probe retract
and the inter-part traverse); group 06's `I_Probe_SafeZ` keeps "Safe Z" (the post-probe retract). Keys
unchanged, so no preset reset.

---

## Design notes that constrain the remaining work

### Traverse clearance is not the G1→G0 plane

`C_MapRapids_SafeZ` / `safeZHeight` answers a narrower question — "within *this* operation, is Z high
enough to re-emit a cut G1 as a G0?" It is operation-scoped and only populated when the hobby
"Map G1s to Rapids" group is on, so it is the wrong source for an inter-op/inter-WCS retract (wrong
height, and unset for full-licence jobs). The cross-part retract instead uses a **job-level clearance
measured above the spoilboard base** (`D_Spoilboard_SafeZClearance`, "Inter Part Safe Z"), the one frame
meaningful across all the job's parts. Single-WCS jobs need none of this — their shared frame makes each
operation's own clearance a safe reference.

**Why the Inter Part Safe Z can't be an F360 expression (asked and answered).** The Safe-Z expression
syntax already accepts `Feed:`, `Retract:` and `Clearance:` with a fallback constant, and F360's
**Clearance Height** *is* its "clears everything" concept — so `Clearance:40` would parse today. It is
still the wrong source and deliberately not offered:

- Every F360 height parameter is **per-operation and expressed in that operation's own WCS** (and only
  usable when `..._absolute == 1`). The Inter Part Safe Z must be expressed in the **base's** frame.
  Feeding a part-frame number into a base-frame `G0 Z` under-clears by the stock thickness — precisely
  the failure mode the base exists to prevent, and it would fail *silently*.
- F360 has **no job-level "above the machine table" height at all**. It knows nothing of a spoilboard;
  every height it exposes is relative to the model / stock / WCS. The base frame is a post-invented
  concept, so no F360 parameter can express a height in it.
- The two are scoped differently: F360's clearance height is per-operation and may legitimately differ
  between operations; this is one job-wide physical height.

So it stays a plain whole-mm `integer`. If an expression is ever wanted here, the only sound use is as
a **floor** (`max(constant, resolved)`), never a substitute — and the resolved value would still need
converting from the part frame to the base frame, which the post cannot do at post time (the numeric
relation between two WCS is only known after runtime probing).

### Base WCS is transited, not parked (R1/R2)

The base-relative retract must *select* the base to move in its frame (the numeric relation between two
WCS is only known after runtime probing). Two rules:

- **R1 — always restore the operating WCS.** After a base transit, advance to the next operation's WCS
  before any cutting; never cut with the base left active. Also restore after a section that
  legitimately cut on the base.
- **R2 — never round-trip the base empty.** Enter the base only when a real move (the retract) is
  emitted there; skip it entirely when in/out WCS match or no traverse is needed.

Mechanism (`retractThroughBaseClearance()`): transit-select the base with a low-level `writeBlock`
(**not** `writeWCS()` — no re-probe, no origin write), emit the `G0 Z` clearance, leave the base
active; the caller then selects the destination WCS. No base transit at `onClose`.

The same rules govern the **base establish**: it transit-selects the base *before* probing so that both
the `G38.2` target and the post-probe retract are measured against the base, then restores the
operating WCS (R1). Skipped when the section already runs on the base. That ordering is what makes the
Inter Part Safe Z mean what its tooltip claims — clearance above the spoilboard, independent of stock
thickness — and it is why the first-part `Use Active WCS X0 Y0, Probe Z0` mode can traverse safely when
a base is established, and only then.

> **Superseded reasoning, kept because it is the plausible wrong answer.** An earlier note argued the
> base establish needed no `G59` select, since `G10 L20` does not change the active WCS and the
> section's own WCS stays active into the cut. Correct as far as it goes — but it missed that the
> base's own probe and, critically, its post-probe retract then execute in the *part's* frame, whose Z
> may be stale. **The missing select was the defect.**

### Why the first section's arrival is asymmetric

In `writeWCS()`, `isTraverse = (previousWorkOffset != undefined)` is false on the first section, so the
first section skips **both** the safe-Z retract and the origin/probe dispatch that every later WCS
change gets: every inter-part traverse arrives safely, the *first* arrival does not. Un-suppressing it
where it sits does **not** work, and the reasons are worth keeping:

- **Ordering.** `writeWCS()` is step 3 of `writeFirstSection()`; `writeBaseEstablish()` is step 5. At
  step 3 *neither* the part WCS's Z nor the base's Z has been established, so both retract paths would
  emit an absolute `G0 Z` into a stale frame — the same defect relocated.
- **Direction.** An absolute Z against a stale zero can move the tool *down*. Emitting nothing at least
  leaves it where the operator parked it.
- **Blast radius.** With `isTraverse` true on the first section, the fallback fires on *every* job
  including the default.

The resolution keeps the intent and fixes the placement: the first section's safe arrival happens
**after** the base establish, in the base's frame. And it exposes a hard limit — **with no base
reserved there is no established frame at job start at all**, so no retract can be made safe there.
That case is handled by an Info comment instead (`Ensuring that Z is safe. Unknown Z for XY move.`),
emitted inside `partProbe()` only on the one path that deliberately emits no absolute Z move and only
when no base is established, since claiming "unknown Z" after a base-frame retract would be a false
safety comment. *(Verified all three branches — `PReview.md` §4.)*

---

## Phase status

- **Phase 1 — done & shipped.** WCS origin/probe rework to `G10 L20` (replacing the old `G92`
  single-global-origin hazard); the two probe-timing properties; `writeWcsOrigin()`; tool-change
  re-probe now G10-scoped.
- **Phase 2 — done & verified.** Establish MCS (homing); default `None` emits no motion.
- **Phase 3 — done & verified.** Reserved base + establish + Guards A/C (and B's placeholder).
- **Phase 4 — in progress.** Landed and verified: Guard B; Inter Part Safe Z + Retract Across Parts;
  the base-relative transit-through-base retract on every inter-part WCS change; added-part re-probe
  repositioning; the base-frame base establish; the six-mode first-part origin model; the full property
  dump and resolved values; the group/label rework. Landed with verification pending: the **probe XY
  offset**'s added-part halves (`PReview.md` P2/P3) and the multi-part rows generally. **Remaining to
  build:** tool-change ordering + base-relative park (below).
- **Phase 5 — not started** (likely no-op).
- **Hobbyist review — code complete for this branch's scope.** 17 findings; nine landed, six moved to
  `PReview.md`, HR-16 recorded with no fix, HR-17 tidy-ups pending. Verification status in
  `HReview.md` §3.
- **Professional review — not started.** `PReview.md` is a parking lot until it runs.

## Completed reviews (archived)

Four review passes are finished; every finding is fixed in `MPCNC_v4.0_Beta2.cps` and preserved in git.
Their tracking docs were removed at closeout to keep the working set small. Recover the rationale from
git if needed:

- **Code-quality review** — 26 findings (#1–#26), all fixed. `git log --follow -- docs/known-issues-v4.md`
- **Autodesk / F360 compliance review** — F1–F11, all resolved. `git log --follow -- docs/f360-compliance-issues.md`
- **Floating-point comparison review** — FP1 fixed, remainder cleared. `git log --follow -- docs/float-comparison-review.md`
- **Beta-2 test plan** — dissolved into `HReview.md` and `PReview.md`; every row survives in one of
  them. `git log --follow -- docs/test-plan.md`

---

## Remaining work (pick up here)

### Phase 4 — tool-change ordering + base-relative park *(one unit; design settled)*

> **This is the Tool Change branch's work.** Tool changes are a professional feature (Fusion Personal
> does not support them), so this item and the six deferred findings — **HR-7**, **HR-8**, **HR-9**,
> **HR-10**, **HR-12**, **HR-13** — land together on a separate branch. Read each one's entry in
> `PReview.md` §2 first; HR-10 and HR-13 have complete diffs and are independent of the reorder, so
> they can go in first as warm-up commits.

Root cause: in `onSection()`, `toolChange()` runs **before** `writeWCS(currentSection)` for non-first
sections, so a boundary that is both a tool change and a WCS change **re-probes into the wrong WCS**
(`toolChange()`'s re-probe writes `G10 L20` into `currentWorkOffset`, still the *previous* part's WCS)
and **parks in the wrong frame** (the change-position rapid runs in the previous WCS).

Fix — reorder so the WCS is resolved before the tool-change re-probe, and coordinate the two so a
combined boundary does each thing once:

1. Run `writeWCS()` first — it owns the base retract and the frame switch. When a tool change on the
   same section will re-probe, have `writeWCS()` **skip its own `B_Probe_OnChange` probe** and let the
   tool-change flow own the single re-probe, now into the correct WCS.
2. The tool-change re-probe **repositions to the new part's `X0 Y0`** before measuring (the same fix
   already applied to the added-part probe), so it reads the stock top and not the park point.
3. **Park position, two branches (decision):** base reserved → park relative to the base (a fixed
   physical spot for the whole job), reusing the transit-select machinery; no base → plain `G0` in the
   current WCS, as today. **Never `G53`.**

Net at a both-boundary: retract through base → switch WCS → park → swap → rapid to `X0 Y0` → probe
once into the correct WCS. Test matrix in `PReview.md` §3.4.

### Future work — a machine-coordinate base probe point (`G53`) *(not started; design sketch)*

The base probes wherever the tool is parked (see *Reserved spoilboard base*), defended only by an
operator precondition. The durable fix is to give the base an explicit **probe point in machine
coordinates** — `G53 G0 X<n> Y<n>` before the `G38.2` — so the touch-off lands on the same bare-
spoilboard spot every run, independent of every WCS.

**Why machine coordinates are the right frame here, and why homing is the enabler.** First the
question that has to be settled: *does homing change any WCS's coordinates?* **No.** `G54`–`G59` hold
offsets **from machine zero**, persisted in EEPROM on GRBL; `$H` writes the machine position and never
touches those registers — the stored numbers are identical before and after. What homing changes is
whether they still *mean* anything: on a homed machine, machine zero returns to the same physical spot,
so a stored offset points at the same physical place across power cycles; on a machine with no
endstops, machine zero is wherever the controller was last reset, so last session's offsets now point
somewhere else. **Homing doesn't change the WCS — it makes the WCS trustworthy**, which is the missing
half of the "every *Use Active WCS* mode is a trust assertion" note in *Coordinate model*. It also
means `Home Before Start = None` + `Use Active WCS X0 Y0` after a power cycle is quietly unsound today,
and worth a warning independent of this item.

**Rejected: `G53 G0 X0 Y0` (machine zero itself).** Tempting because it needs no new property, but
wrong on three counts:

- **It's the worst spot on the bed** — the homing corner, the extreme of travel, offset only by the
  pull-off. Whether that is the far corner with a negative work envelope (default GRBL) or the near
  corner depends on `$23` / `$27` / `$130`–`$132`. It is routinely off the spoilboard entirely.
- **It's machine-config dependent**, which is itself the argument against hard-coding it.
- **Z is unsolved, and the move makes it worse.** Homing XY gives no Z reference. Today the base
  establish emits *no motion at all*, so the unknown Z is inert — the only exposure is probing the
  wrong surface. Adding a traverse converts that into a full-bed diagonal at an unknown height: a
  collision risk traded for a bookkeeping improvement. Only safe under `XYZ` homing, which most target
  machines cannot do.

**Sketch, if built.** A group-05 property pair (base probe point X/Y, machine coordinates, whole mm),
emitted as `G53 G0 X<n> Y<n>` immediately before the base `G38.2`, plus:

- **Guard: requires homing.** Refuse (or warn) when `A_Machine_HomeBeforeStart = None` — machine zero
  is arbitrary there, so the point means nothing. This is the first place the machine-frame group and
  the spoilboard group interact, and the reason they sit adjacent as `04` and `05`.
- **An answer for Z**, one of: require `XYZ` homing; or precede the move with an `M0` *"jog clear in Z,
  then continue"*, converting an unknown-Z traverse into an operator-confirmed one. The prompt is
  preferred — it works on the no-Z-endstop machines that are the majority of the target set.
- **Default off** (empty / unset = today's probe-where-parked behaviour), so no existing job changes.

**Reconcile `G53` across all three uses before building any of it.** This file carries a standing
**"Never `G53`"** decision (tool-change position, resolved in favour of a base-relative park), while
the code comment at the tool-change position still argues the opposite — that it "should probably be a
`G53` move". That comment predates the decision and is stale. The three candidate uses — base probe
point, tool-change park, cross-part retract — should be decided **together**, since they share one
question: *does this post ever address the machine frame directly, or is everything work-relative?* The
current answer is "everything work-relative"; this item is the strongest case for revisiting it,
because a spoilboard is the one thing in the job that genuinely is fixed to the machine.

### Backlog — "Copy first part's Z" mode on `B_Probe_OnChange`

A further enum value: write the first part's probed Z into each added copy's own register
(`G10 L20 P<n> Z<firstPartZ>`) — a register write, **no motion, no probe** — for same-thickness
co-planar fixtures. Requires caching the first part's probed Z at `A_Probe_OnStart` time. Marlin no-op.
The neutral "Subsequent WCS / Part" title already accommodates it. *Deferred until the
retract/tool-change work is done.*

### Phase 5 — G0/G1 rapid-mapping review

Confirm the "Map G1s to Rapids" optimisation needs no change under the new model: does it ever run
across a section/WCS boundary (where Phase 4 injects safe-Z/base logic), or strictly within one
section/WCS? If strictly single-section, document "no change needed" and close as a no-op. If a
cross-boundary case exists, file it as a new item — a collision-risk case Phase 4 didn't anticipate.
*(`HReview.md` §6 carries the related gap: `isSafeToRapid()`'s true branches have never been
exercised by any posted file.)*

### Backlog / future review *(lower priority)*

Observations from reviewing real F360 output that need no immediate action:

- **WCS `0`/`1` mixed-design warning (human factors).** A job using work offset `0` in one section and
  `1` in another resolves both to `G54`, but to an operator reading Fusion's Operations panel they look
  like two deliberate, different fixtures — and F360's own "multiple setups with different WCS" dialog
  reinforces the illusion. If revisited: emit a `>>> WARNING` when a job mixes `0` with a *different*
  explicit offset, and/or add README guidance to standardise on an explicit `1`. The correct rule is
  any-section-vs-any-other-section — broader than Fanuc's order-dependent
  `getSection(0).workOffset == 0` check.
- **`useZeroOffset` enforcement.** `wcsDefinitions.useZeroOffset: false` is declared but likely inert —
  the enforcing `validateCommonParameters()` lives in a shared post library this post doesn't import,
  so `writeWCS()` still silently aliases `0`→`1`. Mirroring that check is the natural companion to the
  item above.
- **`job1_SetOriginOnStart` (G92) vs. the `G10 L20` model.** The original motivation for revisiting
  origins — a `G92 X0 Y0 Z0` start origin defeating a "switch WCS on the console between runs" workflow
  — is now addressed by the Replicate multi-WCS path. Confirm the remaining G92 start origin doesn't
  undercut a console-selected WCS on re-runs.
- **`permittedCommentChars` global.** A comparable community GRBL post declares it; research whether
  declaring it adds real kernel-side comment filtering on top of `sanitizeMessageText()` before adding
  — it may be purely informational.
- **Global-metadata gaps.** Optionally `vendorUrl` / `model`. Cosmetic.

---

## Workflow notes

- **`node --check MPCNC_v4.0_Beta2.cps` is a valid syntax gate** for this post — run it after every
  edit.
- **Individual functions can be extracted from the `.cps` with a regex and `eval`'d in node against
  stubbed kernel globals.** That is how HR-2, HR-4, HR-5, HR-6 and HR-14 were checked without Fusion:
  `propertyMmToUnit`, `getProperty`, `getCircularPlane`, `hasParameter`, `cycleType`, `unit` and a fake
  section are all easy to fake, and a fixture table of inputs → expected outputs catches unit and plane
  errors that reading cannot. The `properties` literal can be brace-matched out and `eval`'d the same
  way (with the `e*` enum declarations from the file head) — that is how the property dump's
  grouping/ordering was verified. Not a substitute for posting, but it settles arithmetic cheaply and
  reduces the posted file's job to "do these values reach the file".
- **Run the harness against `HEAD` as well as the working tree** (`git show HEAD:MPCNC_v4.0_Beta2.cps`
  to a temp file, taking the path as `argv[2]`). A harness that only passes on the fixed file cannot
  tell you it would have caught anything.
- **A `const` declared inside `eval()` does not leak to the caller's scope**, so extracting
  declarations and `eval`ing them silently yields `ReferenceError` for anything `const`/`let`. Wrap
  them in `new Function(src + 'return {a: a, b: b};')()` instead — that also lets you evaluate several
  declarations together, in file order, which matters when one reads another.
- **`git commit -m` with a PowerShell here-string mangles messages containing double quotes** — write
  the message to a file and use `git commit -F`.

---

## Decisions (resolved)

- **`B_Machine_PromptBeforeHome`** pauses once before any homing motion, on any firmware and for any
  axes (deliberately not Z/Marlin-specific, so it survives a machine change).
- **Homing is one `Home Before Start` enum (None / XY / XYZ)** — the per-axis pickers were collapsed;
  no target machine needs a combination outside those three.
- **Homing order** is not post-controlled (firmware concern).
- **`B_Spoilboard_BaseEstablish`** is an enum defaulting **Pause & Probe Z**; `Probe Z` probes with no
  prompt; `None` emits an "assumed pre-set" Info comment.
- **Marlin multi-WCS is a hard post error** (Guard C).
- **No real TLO** — per-tool re-probe is the substitute.
- **Multi-WCS supports two coexisting per-part workflows** — one WCS per part/copy. (1) *Pre-set
  fixture offsets (Replicate):* `Skip` (use stored X/Y/Z) or `Probe Z` (stored XY, re-probe Z).
  (2) *Manual per-part:* the two `Jog …` modes — the operator jogs to each part and the post records
  its origin. The reserved base + Inter Part Safe Z give the cross-part clearance in either. One part
  from **multiple datums on the same fixture** is supported (`PReview.md` PA1); a **flip or re-clamp**
  is still out of scope for a single run — separate jobs.
- **Tool-change position:** base-relative when a base is reserved (a fixed spot across fixtures), else
  current-WCS. Never `G53`. *(Current code does only the no-base branch.)*
- **HR-11's `M84` vs `M84 S60`:** `S60` — restore a 60-second timeout rather than releasing the motors
  immediately, which would drop Z on an unbalanced LowRider gantry.
- **Tool changes and Manual NC are professional features**, so they are out of the hobbyist review's
  scope and their findings live in `PReview.md`.

---

## Reference — per-machine settings

Each row maps a machine to its `Home Before Start` and `Prompt Before Home` settings, so the operator
knows what to do at job start. (Candidate for migration into `README.md` if a per-machine section is
ever added there.)

| Machine / firmware | Home Before Start | Prompt Before Home | Reserved base | Operator does |
|---|---|---|---|---|
| LowRider (Marlin or FluidNC) | `XYZ` if Z endstops fitted, else `XY` | Off | `G59` if multi-fixture, else `None` | homes X/Y; Z endstops optional (beam squaring); work-Z touched off with the plate either way |
| MPCNC + FluidNC, X/Y switches | `XY` | Off | `G59` if multi-fixture | homes X/Y; machine Z n/a (probe pin can't home), Z set by the work plate |
| MPCNC + Marlin, plate as Z-endstop | `XYZ` | On | `G59` if multi-fixture | homes X/Y; at the pause places the movable plate, then Z homes to it |
| MPCNC, no switches | `None` | Off | `G59` if multi-fixture | parks X/Y by hand as zero; Z set by the work plate |
| Single-part job (any machine) | per row above | per row above | `None` | one WCS zeroed to the part; no base |
