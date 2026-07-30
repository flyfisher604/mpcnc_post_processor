# WCS / Origin Rework — design record & remaining work

This is the design record for the coordinate/probe/tool-change rework in
`MPCNC_v4.0_Beta2.cps`. Phases 1–3 are implemented and verified; their mechanics now live
in the code, so only the enduring decisions are kept here. The actionable backlog to
finish the post is in **[Remaining work](#remaining-work-pick-up-here)**.

User-facing usage (hobby vs. Replicate flows, per-machine setup) lives in `README.md`;
this document is the developer/design record.

---

## Context and stance

The post targets the V1 Engineering **MPCNC / LowRider** family and similar
GRBL / Marlin / RepRap hobby-class machines. The aim is **production-quality CNC workflows**
(multi-fixture, multi-tool, probing, safe cross-part traverses) that **also degrade simply**
for a hobby user on the Fusion Personal license cutting a single operation. Both the full
license and the hobbyist are first-class.

**Development role.** This code is developed by an agent acting in two expert capacities at
once, and decisions should be made from both lenses together:

- an **expert software developer** — Fusion 360 post-processor engineering in JavaScript:
  clean, maintainable code, faithful to this post's existing idioms (e.g. the combined-inline
  `properties` form), with careful regression discipline (default output stays byte-identical);
- an **expert in best-practice CNC operations** — understanding how these machines actually
  behave and designing appropriate, *safe* workflows for both the **V1E hobbyist** (Fusion
  Personal, single operation, manual zeroing) and the **professional** (multi-fixture,
  multi-tool, probing, multiple WCS).

The habit is: settle the CNC-correct workflow first (what a seasoned operator would want to
happen at the machine), then design the software that delivers it.

Two principles drive every decision:

- **Work-relative.** Most target machines have no reliable machine-Z (no tool setter, often
  no Z endstop). The everyday reference is the active **WCS** (the work zero), never the
  machine frame. Tool length is folded into a **Z re-probe after each tool change** (there
  is no TLO). Homing, where present, gives **X/Y** repeatability only; Z homing (where it
  exists) is for its own sake and never becomes the everyday Z reference.
- **Graceful degradation.** Defaults keep the simple single-operation job **byte-for-byte
  unchanged**; every advanced feature (reserved base, cross-part safe-Z, per-part probing)
  is opt-in and emits nothing until enabled.

---

## References — Fusion 360 post-processor documentation

Captured so they don't have to be rediscovered:

- **PostProcessor API class reference** — authoritative list of hooks and helpers
  (`onSection`, `onLinear`/`onRapid`, `writeBlock`, `getProperty`, formatting/motion helpers,
  etc.): <https://cam.autodesk.com/posts/reference/classPostProcessor.html>
- **Post Processor Training Guide (PDF)** — Autodesk's narrative guide to writing posts:
  <https://cam.autodesk.com/posts/posts/guides/Post%20Processor%20Training%20Guide.pdf>
- **Dumper post** — emits every property / parameter / section value Fusion exposes for a CAM
  job; run it to discover what's actually available before relying on it:
  <https://cam.autodesk.com/hsmposts?p=dump>
- **Library of existing posts** — reference implementations to compare against:
  <https://cam.autodesk.com/hsmposts>
- **HSM post-processor forum** — Autodesk's Q&A for post authors:
  <https://forums.autodesk.com/t5/hsm-post-processor-forum/bd-p/218>

Firmware g-code references (target controllers):

- Marlin: <https://marlinfw.org/meta/gcode/>
- GRBL 1.1 wiki: <https://github.com/gnea/grbl/wiki>
- FluidNC wiki: <http://wiki.fluidnc.com/>

---

## Coordinate model

Production controls keep three references separate: **MCS** (`G53`, from homing), **WCS**
(`G54`–`G59`, `G59.1`–`G59.3` on RepRap), and **TLO** (`G43`, from a tool setter). Most V1E
machines have none fully, hence the work-relative stance above.

- **Persistence:** WCS origins are written with `G10 L20 P<n>` on GRBL/RepRap — scoped to
  that WCS's own register, no cross-contamination. `P` maps 1:1 to Fusion's `workOffset`
  (P1–P6 = G54–G59; P7–P9 = G59.1–G59.3, RepRap only; GRBL is P1–P6).
- **Marlin is single-frame:** no per-WCS registers, so it uses one global `G92` origin. A
  Marlin job that uses more than one distinct work offset is a hard error (Guard C).
- **`workOffset 0`** (Fusion's "default / unset") aliases to WCS 1 / `G54`.

**The post asserts the WCS selection; it never inherits it.** Worth stating because it's the
justification for the ordering in `writeFirstSection()` and the answer to "what if the operator
changed WCS at the sender first?":

- Fusion **always** supplies a work offset per section (`section.getWorkOffset()` → `0` for
  unset/default, else `1`–`9`), so the post always has a design-time answer for every section.
- `currentWorkOffset` is **not** the machine's state. `onOpen()` sets it to `undefined` — "no work
  offset emitted yet". It records only what *this post* has emitted, and exists to suppress redundant
  selects.
- Because it starts undefined, the `workOffset == currentWorkOffset` suppression cannot match on the
  first section, so the first section **unconditionally emits its select**, overwriting whatever the
  sender left modal. From then on the post is the only thing changing the selection, so its model and
  the controller agree by construction. This is exactly why `writeWCS()` runs before `Start()`, the
  base establish, and `writeWcsOnStart()` — it defends against both "a stale WCS left active by a
  prior job" and "the controller's power-on default".
- **The distinction that matters:** the post always knows *which* frame is active (it commanded it);
  it never knows *where* that frame is. Register contents are controller-side runtime state (GRBL
  persists `G10 L20` to EEPROM), set by prior jobs or manual touch-offs, and the post cannot read
  them back (no `$#`, no round trip). So **selection is deterministic, origin is trusted** — and every
  "Use Active WCS" mode is a trust assertion, which is why the *defaults* establish an origin
  rather than rely on one. On a fresh GRBL controller all offsets are `0`, so `G54` means machine
  coordinates — on a machine with no endstops, power-on position.
- Undefendable by any post: an operator typing `G55` into the console *mid-run*. Out of scope.

Helper `writeWcsOrigin(wcsNumber, x, y, z)` persists a position into a WCS's own origin
(any axis `undefined` = leave alone); `G10 L20` on GRBL/RepRap, `G92` on Marlin.

## Reserved spoilboard base

For multi-fixture jobs one WCS can be reserved as a **spoilboard base** — a *fixed-surface*
zero (the spoilboard, independent of stock thickness). It is the one frame in which a safe
height is meaningful across parts of differing thickness, which is why the cross-part
safe-Z feature requires it (Guard B).

- **`A_Spoilboard_BaseReserve`** (`None` default | `G54`–`G59` | `G59.1`–`G59.3 (RepRap)`).
  Default `None` keeps the default job byte-identical. When reserved, `G59` is the natural
  choice (highest GRBL slot, keeps `G54` free for parts). Ignored on Marlin (warned).
- **`B_Spoilboard_BaseEstablish`** ("Probe to Set Base") enum, default **Pause & Probe Z**:
  `None` = assume pre-set (probe-once/run-many, Info comment); `Probe Z` = probe with no
  operator prompt (fixed/known point); `Pause & Probe Z` = prompt to attach the probe, probe,
  prompt to detach (the manual touch-off; the byte-identical default). Always probed at the
  origin (0,0); the probe XY offset never applies.

**Base is transited, not parked** — see the design note below; it governs the retract and
tool-change work.

## Machine frame (homing / MCS)

Group `02 - Establish Machine Coordinates`, one enum `A_Machine_HomeBeforeStart`:
**None** (default — accept the current position, incl. an axis already homed at the controller
or a power-on 0,0,0; no motion), **XY** (home X and Y — the usual case), or **XYZ** (also home
Z, only where the machine is wired for it). The per-axis granularity was dropped: the only
combinations any target machine wants are None / XY / XYZ. Homing commands:

| Firmware | Command |
|---|---|
| Marlin / RRF (Duet) | `G28 X` / `G28 Y` (XY) then `G28 Z` (XYZ) — independent per axis |
| GRBL / FluidNC | `$H` only — one command homes all configured axes |

On GRBL/FluidNC `$H` is all-or-nothing: XY and XYZ both emit one `$H` (the mode only documents
intent). `B_Machine_PromptBeforeHome` (default off) pauses **once before any homing motion**,
independent of firmware and of which axes home — so it never needs revisiting when the machine
changes (place a movable Z plate, clear the bed, etc.). The post does not control homing order.
Default `None` → no homing emitted.

## Probing & tool changes

- **Work-Z probing only** (`G38.2`, thickness-compensated, attach/remove pauses). No
  tool-length system; X/Y is never probed.
- **Re-probe after each tool change** is the tool-length substitute
  (`H_ToolChange_ProbeAfterChange`).
- **Manual tool change:** retract → move to change position → pause → re-probe Z → resume.
  See remaining work for the ordering fix and the base-relative park.

## Validation guards

Post-time only (the post can't read the live controller):

- **Guard A — no base redefine.** *Using* the reserved base is fine; an operation that would
  **re-establish its origin** (via `A_Probe_OnStart` / `B_Probe_OnChange` /
  `H_ToolChange_ProbeAfterChange`) errors.
- **Guard B — safe-Z across parts needs a base.** `C_Spoilboard_SafeZAcrossWcs` on + >1 distinct
  offset on GRBL/RRF + no base reserved → error. Single-WCS jobs are exempt.
- **Guard C — Marlin single-frame.** A Marlin job using >1 distinct work offset → hard error.

## Property / dialog conventions

Needed when adding new properties:

- **Group order** = the `group:` string, zero-padded to two digits (`01 - Job` …
  `11 - Duet`). Padding is required so `11 - Duet` sorts last, not next to `01 - Job`.
  The current order: `01 - Job`, `02 - Establish Machine Coordinates`, `03 - Feeds and Speeds`,
  `04 - Map G1s to Rapids...`, `05 - Establish Spoilboard Reference`, `06 - On WCS / Part /
  Fixture Changes`, `07 - Tool Changes`, `08 - External Include Files`, `09 - Laser`, `10 - Coolant`,
  `11 - Duet`.
  > **Resolved (was: reorder WCS/Probe after Map G1s).** The old combined
  > `03 - Work Coordinate System - WCS / Probe` group was split into two: **`03 - Spoilboard
  > Base`** (`A_Spoilboard_BaseReserve`, `B_Spoilboard_BaseEstablish`,
  > `C_Spoilboard_SafeZAcrossWcs`, `D_Spoilboard_SafeZClearance`) placed right after machine
  > homing so it reads as a setup thought-walk, and **`06 - On WCS / Part / Fixture Changes`** (the part
  > origins, probe XY offset, and G38/Safe-Z/thickness mechanics) placed after Map G1s.
  > This re-lettered the moved keys and changed four keys' group segment from `Probe` to
  > `Spoilboard`; because the key is the stored identifier, the eight renamed keys reset any
  > saved preset to default — a release-notes item.
  > **Resolved (later): moved the spoilboard group to `05` and renamed it.** The group formerly
  > at `03 - Spoilboard Base` now sits at **`05 - Establish Spoilboard Reference`** (between
  > Map-G1s and On WCS / Part / Fixture Changes); `04 - Feeds and Speeds` → `03` and
  > `05 - Map G1s...` → `04` shifted up to fill the gap. Only the `group:` strings changed —
  > the `_Spoilboard_` key segments were kept (the word still fits the new name), so this move
  > does **not** reset saved presets.
- **Within-group order** = a single-letter item prefix on the key,
  `<Letter>_<Group>_<Name>` (`A`, `B`, … restarting per group), e.g. `A_Machine_HomeBeforeStart`.
  New properties take the next free letter (re-letter following ones if inserting mid-group).
- This post uses the **combined-inline** `properties = {}` form (title/description/type/value
  inline). The split `properties` + `propertyDefinitions` form is the *old broken* approach —
  do not reintroduce it.

**Origin/probe controls (Group `06 - On WCS / Part / Fixture Changes`).** Three separate controls
(kept separate — merging the two origin controls was rejected: it would apply job-start
XY-zeroing to a mid-job WCS change, a positioning bug). Full behavior in the implemented section
below ("selection-driven origin/probe model"); summary (enum ids in parentheses):

- `A_Probe_OnStart` = **"First WCS / Part"** (dropdown order, default first) —
  `Set X0 Y0 to Current Pos, Probe Z0` (`Current XY & Probe Z`, default) /
  `Set X0 Y0 Z0 to Current Pos` (`Current XYZ`) / `Use Active WCS X0 Y0, Probe Z0` (`Probe Z`) /
  `Use Active WCS X0 Y0 Z0` (`Skip`) / `Jog to X0 Y0, Probe Z0` (`Jog XY & Probe Z`) /
  `Jog to X0 Y0 Z0` (`Jog XYZ`). First/only part origin. The *Current Pos* modes assume a pre-jog
  before start (no prompt); the *Use Active WCS* modes trust the stored fixture offset (rapid to
  its X0 Y0, optionally re-probe Z); the *Jog* modes pause (M0) so the operator jogs during the run.
- `B_Probe_OnChange` = **"Subsequent WCS / Part"** (dropdown order, default first) —
  `Use Active WCS X0 Y0, Probe Z0` (`Probe Z`, default) / `Use Active WCS X0 Y0 Z0` (`Skip`) /
  `Jog to X0 Y0, Probe Z0` (`Jog XY & Probe Z`) / `Jog to X0 Y0 Z0` (`Jog XYZ`). Fires on a genuine
  WCS change after the first section. The *Use Active WCS* modes take XY from the fixture's pre-set
  offset (Replicate); the *Jog* modes let the operator jog to each part and record its origin.
  Defaults are the no-prompt modes because jogging at the pause isn't universally supported.
- `C_Probe_Pause` = **"Probe Pause"** — `No` / `Before` / `Before & After` (default). Gates the
  operator attach(before)/detach(after) prompts for the **part** probes (first + added). It
  does not add new stops — it turns the existing `Attach ZProbe` / `Detach ZProbe` prompts on
  or off (`Before & After` = the historical always-prompt behavior). Threaded to `probeTool()`
  via the module-level `probePauseBefore`/`probePauseAfter`, which the base establish sets too
  and `probeTool()` resets to true after each probe (so the tool-change re-probe still prompts).

> **Resolved — `B_Spoilboard_BaseEstablish` is now an enum** ("Probe to Set Base": `None` /
> `Probe Z` / `Pause & Probe Z`, default `Pause & Probe Z`). The earlier "Spoilboard WCS is /
> Zero XY, Probe Z" idea (giving the base an XY origin) was dropped: the base stays a Z-only
> reference. Instead the enum mirrors the part-probe `Probe Pause` control — `Probe Z` = probe with
> no prompt, `Pause & Probe Z` = attach + detach prompts. Boolean→enum reset the stored preset
> to the default (release-notes item).

---

## Design notes that constrain the remaining work

### Traverse clearance is not the G1→G0 plane

`C_MapRapids_SafeZ` / `safeZHeight` answers a narrower question — "within *this* operation,
is Z high enough to re-emit a cut G1 as a G0?" It is operation-scoped and only populated when
the hobby "Map G1s to Rapids" group is on, so it is the wrong source for an inter-op/inter-WCS
retract (wrong height, and unset for full-license jobs). The cross-part retract instead uses
a **job-level clearance measured above the spoilboard base** (`D_Spoilboard_SafeZClearance` =
"Inter Part Safe Z" in the Establish Spoilboard Reference group), the one frame meaningful across all the job's parts. Single-WCS jobs
need none of this — their shared frame makes each operation's own clearance a safe reference,
so they stay byte-identical.

**Why the Inter Part Safe Z can't be an F360 expression (asked and answered).** The Safe-Z
expression syntax (`parseSafeZExpr`) already accepts `Feed:`, `Retract:` and `Clearance:` with a
fallback constant, and F360's **Clearance Height** *is* its "clears everything" concept — the height
the tool rapids to on the way in and retracts to at the end. So `Clearance:40` would parse today, and
`eSafeZ.CLEARANCE` → `operation:clearanceHeight_value` is already wired. **It is still the wrong
source for this property, and deliberately not offered:**

- Every F360 height parameter is **per-operation and expressed in that operation's own WCS** (and
  only usable when `..._absolute == 1`). The Inter Part Safe Z must be expressed in the **base's**
  frame. Feeding a part-frame number into a base-frame `G0 Z` under-clears by the stock thickness —
  precisely the failure mode the base exists to prevent, and it would fail *silently*.
- F360 has **no job-level "above the machine table" height at all**. It knows nothing of a
  spoilboard; every height it exposes is relative to the model / stock / WCS. The base frame is a
  post-invented concept, so no F360 parameter can express a height in it.
- The two are also scoped differently: F360's clearance height is per-operation and may legitimately
  differ between operations, whereas this is one job-wide physical height.

So it stays a plain whole-mm `integer`. If an expression is ever wanted here, the only sound use is
as a **floor** (`max(constant, resolved)`), never a substitute — and the resolved value would still
need converting from the part frame to the base frame, which the post cannot do at post time (the
numeric relation between two WCS is only known after runtime probing).

### Base WCS is transited, not parked (R1/R2)

The base-relative retract must *select* the base to move in its frame (the numeric relation
between two WCS is only known after runtime probing). Two rules:

- **R1 — always restore the operating WCS.** After a base transit, advance to the next
  operations' WCS before any cutting; never cut with the base left active. Also restore after
  a section that legitimately cut on the base.
- **R2 — never round-trip the base empty.** Enter the base only when a real move (the
  retract) is emitted there; skip it entirely when in/out WCS match or no traverse is needed.

Mechanism (implemented in `retractThroughBaseClearance()`): transit-select the base with a
low-level `writeBlock` (**not** `writeWCS()` — no re-probe, no origin write), emit the `G0 Z`
clearance, leave the base active; the caller then selects the destination WCS. No base transit
at `onClose`.

---

## Phase status

- **Phase 1 — done & shipped.** WCS origin/probe rework to `G10 L20` (replaces the old `G92`
  single-global-origin hazard); the two probe-timing properties; `writeWcsOrigin()`;
  tool-change re-probe now G10-scoped.
- **Phase 2 — done & verified.** Establish MCS (homing), in isolation; default
  `None` (was per-axis `Power-On`, since collapsed to one `Home Before Start` enum)
  output byte-identical to the Phase-1 baseline.
- **Phase 3 — done & verified.** Reserved base + establish + Guards A/C (and B's placeholder);
  default `None` byte-identical.
- **Phase 4 — in progress.** Consume the base for safe-Z / traverses / tool-change. Landed &
  verified: Guard B; `Safe Z` (inter-part retract height) + `Retract Across Parts`; the
  base-relative traverse retract on **every** inter-part WCS change (transit-through-base),
  verified on both the re-probe and non-re-probe (Skip) boundaries; added-part re-probe
  repositions to the new part's `X0 Y0` before probing; the WCS/Probe relabels + default flip.
  Landed, verification pending: **probe XY offset** (`D_Probe_OffsetX` / `E_Probe_OffsetY`, added
  parts still open). The new first-part **`Use Active WCS X0 Y0, Probe Z0`** mode is **verified on
  its main path and with a nonzero offset** (test-plan H7 + H7a); still open there are H7b–H7e —
  jet/tool-0, Guard A, firmware variants, and the base-reserved traverse-height question (H7c).
  Remaining items below.
- **Phase 5 — not started** (likely no-op).

---

## Completed reviews (archived)

Three standalone review passes are finished; every finding is fixed in `MPCNC_v4.0_Beta2.cps`
and preserved in git. Their tracking docs were removed at closeout to keep the working set to
the two driving files (this plan + the test plan). Recover the fix rationale from git if needed:

- **Code-quality review** — 26 findings (#1–#26), all fixed. `git log --follow -- docs/known-issues-v4.md`
- **Autodesk / F360 compliance review** — F1–F11, all resolved (fixed or accepted as-designed).
  `git log --follow -- docs/f360-compliance-issues.md`
- **Floating-point comparison review** — FP1 fixed, remainder cleared.
  `git log --follow -- docs/float-comparison-review.md`

---

## Remaining work (pick up here)

### Phase 4 — tool-change ordering + base-relative park *(one unit; design settled)*

Root cause: in `onSection()`, `toolChange()` runs **before** `writeWCS(currentSection)` for
non-first sections, so a boundary that is both a tool change and a WCS change:
- **re-probes into the wrong WCS** — `toolChange()`'s re-probe writes `G10 L20` into
  `currentWorkOffset`, still the *previous* part's WCS; and
- **parks in the wrong frame** — the change-position `onRapid` runs in the previous WCS.

Fix (reorder so the WCS is resolved before the tool-change re-probe, and coordinate the two
so a combined boundary does each thing once):
1. Run `writeWCS()` first — it owns the base retract + frame switch. When a tool change on the
   same section will re-probe, have `writeWCS()` **skip its own `B_Probe_OnChange` probe** and
   let the tool-change flow own the single re-probe (now into the correct WCS).
2. The tool-change re-probe **repositions to the new part's `X0 Y0`** before measuring (same
   fix already applied to the added-part probe), so it reads the stock top, not the park point.
3. **Park position, two branches (decision):**
   - **Base reserved** → park relative to the base (a fixed physical spot for the whole job);
     reuse the transit-select machinery (`retractThroughBaseClearance()`-style low-level emit).
   - **No base** → plain `G0` in the current WCS, as today.
   Never `G53`.

Net at a both-boundary: retract through base → switch WCS → park → swap → rapid to `X0 Y0` →
probe once into the correct WCS. Test matrix: tool-change-only, WCS-change-only, and combined,
each with and without a base.

### Phase 4 — probe XY offset *(implemented — verification pending)*

`D_Probe_OffsetX` / `E_Probe_OffsetY` (`06 - On WCS / Part / Fixture Changes` group). The probe touch-point becomes
origin + (offsetX, offsetY), so the origin can sit at a corner / off the material while Z
probes the stock top. Job-wide, not per-fixture; default `0,0` reproduces prior output.
Applied at **every part probe** — first part (`writeWcsOnStart`, "Current XY & Probe Z") and
each added part (`writeWCS` `probeNewPart` branch) — and **never** the spoilboard base probe
(`writeBaseEstablish`, always at the origin) nor the tool-change re-probe (that reposition is
part of the ordering item above). Default byte-identical: first-part emits the reposition
rapid only when the offset is nonzero; added-part keeps the exact `X0 Y0` comment/output at
offset 0. Tooltips (`D`/`E` offsets + `B_Spoilboard_BaseEstablish`) and README state the base
probes at 0,0.

*Verification status:* **first-part nonzero path + base-at-origin confirmed** via `Face1.gcode`
(single part, offset X10 Y5, base `G59` reserved): `G10 L20 P1 X0 Y0` → reposition `X10 Y5` →
`G38.2` → `G10 L20 P1 Z0.8`, and the base probes with no reposition (`G10 L20 P6 Z0.8`). Offset-0
first-part + base already NC-confirmed earlier. The offset on the other first-part probing mode
(`Use Active WCS X0 Y0, Probe Z0`) is confirmed too, via `H7a.gcode` — diffed against `H7.gcode`,
the offset changes only the probe-point comment and reposition rapid, nothing downstream (test-plan
H7a). **Still pending:** the added-part paths — nonzero
(P2) and zero-offset (P3) — need a multi-part Replicate run. See `docs/test-plan.md` P1–P3.

### Phase 4 — dialog / property polish *(from the Face1.gcode review)*

Dialog wording and number-format fixes; low-risk, do together. Re-lettering / changing an enum
`id` resets saved presets to default (release-notes item), so prefer keeping ids where noted.

- ✅ **`B_Spoilboard_BaseEstablish` option label (group 05).** Renamed the option to
  **`Pause, Probe Z, Pause`**; kept the enum `id` (`Pause & Probe Z`) so saved presets don't reset.
- ✅ **`D_Spoilboard_SafeZClearance` "Safe Z" (group 05).** `type: "number"` → `"integer"`
  (whole-mm clearance; no decimals).
- ✅ **`D_Probe_OffsetX` / `E_Probe_OffsetY` (group 06).** **Decided: `integer`** (whole mm, no
  fractions — user confirmed no fractional offset needed). Tooltips corrected from "in the job's
  units" to "in whole mm"; the code converts via `propertyMmToUnit`.
- ✅ **Cosmetic — probe-point comment.** Reworded to `Move to probe point = origin + offset X.. Y..,
  then probe Z` (no parens) in `partProbe()`, so `sanitizeMessageText` no longer leaves double spaces.

- ✅ **`Use Existing WCS …` → `Use Active WCS …` (both dropdowns, group 06).** "Existing" read as a
  *temporal* claim — "the WCS that was already active before the job" — which is wrong: the register
  is the one **this operation's Fusion Setup designates**, and the post *selects* it at job start,
  overwriting whatever the sender had. (The word was accurate about the register's *contents*, which
  is why the misread is easy.) Renamed all four option titles; **enum ids `Probe Z` / `Skip` kept, so
  saved presets do not reset**. Both tooltips now spell out: which register (the Setup's Work Offset,
  selected by the post), that it is *not* the sender's current selection, and that the stored values
  are trusted-not-verified because the post cannot read them back. README gained a
  *What "Active WCS" means* section with a safe-to-use / watch-out-for table and the fresh-controller
  caveat (all offsets `0` → `G54` is machine coordinates).
- ✅ **`D_Spoilboard_SafeZClearance` title (group 05).** Renamed **"Safe Z" → "Inter Part Safe Z"**:
  the old title collided with the group-06 `I_Probe_SafeZ`, also titled "Safe Z", and the two mean
  different heights in different frames. Key unchanged, so saved presets don't reset. The tooltip now
  documents both consumers (the post-base-probe retract and the inter-part traverse) and states it is
  whole mm above the spoilboard.

> ~~*Verified, not a bug: the spoilboard base probe writes `G10 L20 P6` and emits no `G59` select —
> `G10 L20` does not change the active WCS, and the section's WCS `G54` is selected before base
> establish and stays active into the cut, so the section runs under the correct WCS. The base is
> only transit-selected when it is later consumed for a cross-part retract — not when established.*~~
>
> **Superseded — the missing select *was* the defect.** The reasoning above is correct that the
> section ends up under the right WCS, but it missed that the base's own probe and, critically, its
> post-probe retract then execute in the *part's* frame, whose Z may be stale. The base establish now
> transit-selects the base and restores the operating WCS afterwards; see the H7c open-question
> section below for the full analysis and what changed.

### Phase 4 — selection-driven origin/probe model for first + added parts *(implemented)*

**Structure (user): a short Action dropdown per stage + the existing shared Pause control**
(`C_Probe_Pause`, relabelled **"Probe Pause"** — No / Before / Before & After — kept separate; the
earlier "fold pause into the option names" idea was dropped). Group `06` renamed
**"On WCS / Part / Fixture Changes"**. The group rename and the Probe Pause relabel don't reset
presets (keys/ids unchanged), but the later Current-Pos/Jog split *did* rename and add origin-mode
ids, which resets those presets. (Current enum ids in parentheses below.)

- **`A_Probe_OnStart` "First WCS / Part"** — reworked into an explicit *Current Pos* (no prompt)
  vs *Use Active WCS* (no prompt) vs *Jog* (M0 prompt) taxonomy, dropdown ordered default-first:
  `Set X0 Y0 to Current Pos, Probe Z0` (`Current XY & Probe Z`, default) /
  `Set X0 Y0 Z0 to Current Pos` (`Current XYZ`) / `Use Active WCS X0 Y0, Probe Z0` (`Probe Z`) /
  `Use Active WCS X0 Y0 Z0` (`Skip`) / `Jog to X0 Y0, Probe Z0` (`Jog XY & Probe Z`) /
  `Jog to X0 Y0 Z0` (`Jog XYZ`). The new `Probe Z` (first part) mirrors the Subsequent `Probe Z`:
  rapid to the WCS's stored X0 Y0 and re-probe Z (`partProbe(false)`), no XY re-zero.
- **`B_Probe_OnChange` "Subsequent WCS / Part"** — four modes, two coexisting workflows,
  ordered default-first:
  - *Use Active WCS (pre-set fixture offset / Replicate):* `Use Active WCS X0 Y0, Probe Z0` (`Probe Z`,
    default) and `Use Active WCS X0 Y0 Z0` (`Skip`) — both auto-position to the stored `X0 Y0`.
  - *Jog (operator jogs):* `Jog to X0 Y0, Probe Z0` (`Jog XY & Probe Z`) and `Jog to X0 Y0 Z0`
    (`Jog XYZ`) — pause (jog-enabled) so the operator jogs to this part, then record the origin
    there (mirrors the first-part options).
  Both default to the no-prompt mode because jogging at the pause isn't universally supported.
  The renamed/added ids reset a saved `A_Probe_OnStart` / `B_Probe_OnChange` preset (release-notes).

**Safe arrival at X0 Y0 (user).** Every genuine WCS change now retracts to a safe Z *first*
(base-relative through the spoilboard base when reserved + Retract Across Parts on, else to the
probe Safe Z in the outgoing frame — whose Z is established), then dispatches by mode:
- `Skip` — rapids to the stored `X0 Y0` (X/Y only, so the safe Z holds) — the "do nothing but get
  there safely" case.
- `Probe Z` — `partProbe(false)` travels to the probe point and probes.
- `Jog XYZ` / `Jog XY & Probe Z` — `askUser(..., allowJog=true)` prompts the operator to jog, then
  writes the origin (`G10 L20 P<n>` / G92) and, for the probe variant, `partProbe(true)`.

**Selection-aware prompts.** The jog modes emit a jog prompt ("Jog to X0 Y0 …");
probe attach/detach prompts continue to follow `C_Probe_Pause` via `partProbe()`.

**Reconciled decisions (updated):**
- "The post never sets XY for added parts" → **superseded**: the manual modes set added-part XY
  from a jog; the Replicate modes (`Skip`/`Probe Z`) still take XY from the pre-stored offset.
- "Multi-WCS is Replicate-only" → **superseded**: manual per-part multi-WCS is supported too.
- `A_Probe_OnStart` / `B_Probe_OnChange` remain **separate controls** (only their option sets are
  now symmetric); `C_Probe_Pause` remains a separate shared control.

**Open question — the first-part `Probe Z` mode's traverse height when a base is reserved.** The
`Probe Z` branch of `writeWcsOnStart()` deliberately emits **no absolute Z move**: the part WCS's Z
is stale (about to be re-probed), so it travels to the stored `X0 Y0` at whatever height the tool
already holds. That premise is sound with no base, but `writeBaseEstablish()` runs immediately
before it and its `probeTool()` retract (`rapidMovementsZ(probeSafeZ())`) is an absolute `G0 Z`
evaluated in the **still-stale part WCS**. So a base-reserved job traverses at
`staleZ0 + probeSafeZ`, colliding when the new stock top rises more than `probeSafeZ` above where
the stale Z0 was set — reachable in exactly the changed-stock case this mode exists for.
*Verification: `docs/test-plan.md` H7c.*

Two things this is **not**, both worth stating because they're the obvious first guesses:

- **It is not the group-05 `Safe Z` retracting too low.** `D_Spoilboard_SafeZClearance` ("Safe Z",
  group 05, default 40) is *not used at all* by the base establish. Its single consumer is
  `retractThroughBaseClearance()`, and its own tooltip scopes it to "when Retract Across Parts is on
  and a base is reserved". The base establish retracts via `probeTool()` → `probeSafeZ()`, which is
  the **group-06 `I_Probe_SafeZ`** — a different property that also happens to be titled "Safe Z".
  Two properties, same label, different groups, different frames of reference: that collision is
  itself a fix candidate (rename one, e.g. group-05 → "Cross-Part Clearance Z").
- **It is not the base probe changing the WCS.** `writeBaseEstablish()` emits no WCS select at all,
  and `G10 L20 P<base>` writes a register without selecting it, so the operating WCS is never
  disturbed and `currentWorkOffset` is never touched. There is nothing to save and restore. The
  defect is the **opposite**: because the base is never selected, the base's own probe *and* retract
  both execute in the part's stale frame.

**Framing (user): the first WCS change is deliberately suppressed — should it be?** In `writeWCS()`,
`isTraverse = (previousWorkOffset != undefined)` is false on the first section (`currentWorkOffset`
starts undefined), so the first section skips **both** the safe-Z retract and the origin/probe
dispatch that every later WCS change gets. That asymmetry is the real root of this item: every
inter-part traverse arrives safely, the *first* arrival does not — which is exactly why `H7.gcode`
opens with a full-bed rapid at an unknown height. So the instinct is right: the first section should
get a safe-arrival retract too. But **un-suppressing it where it currently sits does not work**:

- **Ordering.** `writeWCS()` is step 3 of `writeFirstSection()`; `writeBaseEstablish()` is step 5. At
  step 3 *neither* the part WCS's Z nor the base's Z has been established, so both retract paths
  would emit an absolute `G0 Z` into a stale frame — the same defect relocated, not fixed.
- **Direction.** An absolute Z against a stale zero can move the tool *down*. Emitting nothing at
  least leaves it where the operator parked it, so a naive un-suppress is potentially worse than
  today's behavior.
- **Byte-identical.** With `isTraverse` true on the first section the `else if (isTraverse)` fallback
  fires on *every* job including the default, adding a `G0 Z<probeSafeZ>` at the start of all output
  and breaking the H2 / H-REG anchor.

The resolution keeps the intent and fixes the placement: give the first section its safe-arrival
retract **after** the base establish, in the base's frame — which is the same emitted g-code as the
fix below, just structurally homed on the first-part path rather than bolted inside
`writeBaseEstablish()`. And note the hard limit this exposes: **with no base reserved there is no
established frame at job start at all**, so no retract can be made safe there — that case is
handled only by the "unknown Z" Info comment (next item). The clean split is *base reserved →
retract base-relative; no base → say so in a comment*.

**Fix — IMPLEMENTED (mirrors R1/R2).** Do the base's Z work in the base's frame and hand back the
operating WCS — structurally the save/restore shape, just with the selection added rather than a
stray one removed:

1. Transit-select the base (low-level `writeBlock`, as `retractThroughBaseClearance()` does — no
   re-probe, no origin write) *before* probing, so both the `G38.2` target and the retract are
   measured against the base.
2. Probe (`G38.2` → `G10 L20 P<base> Z<thk>`), then retract to the **Inter Part Safe Z**. After that
   register write the base's Z0 is a known height on a fixed physical surface, so *now* the height
   means what its tooltip claims: clearance above the spoilboard, independent of stock thickness.
3. Re-select the operating WCS (**R1** — never leave the base active) and continue. The reselect
   moves nothing, so `writeWcsOnStart()`'s subsequent `G0 X0 Y0` traverses at spoilboard +
   clearance — safe by construction, and no longer dependent on any stale datum.

**As built.** `writeBaseEstablish()` saves `currentWorkOffset`, emits the base select (+ `resetAll()`
— a frame change invalidates the tracked coordinates), probes, then restores and resets again. Both
selects are skipped when the section already runs on the base (`switched` false), which is only
reachable with `A_Probe_OnStart = Skip` since Guard A otherwise blocks a section on the base.
`probeTool()` gained an optional second parameter `retractZ`, defaulting to `probeSafeZ()` — so the
only caller whose output changes is the base establish; the part probes and the tool-change re-probe
are byte-identical.

**Decisions taken:** (a) the Inter Part Safe Z is used here **regardless of Retract Across Parts** —
a reserved base is sufficient reason to want a clearance above the spoilboard, and the tooltip was
rewritten to document both consumers; (b) the base-frame retract applies to **every** base establish,
not just when the first-part mode has a stale Z — simpler, safer, and uniform, at the cost of
changing output for base-reserved jobs.

**Output changes (base-reserved jobs only — default `None` is untouched, so H2/H-REG hold).** Adds a
base select, a restore select, two Info comments, and changes the base retract height from the
group-06 probe Safe Z to the Inter Part Safe Z. This **supersedes** the previously verified Phase-3
base-establish shape and the "*Verified, not a bug*" note above about the base emitting no `G59`
select — that suppression was the defect. Re-verify via test-plan **H7c** and **PB1**.

**Incidental improvement.** The base probe's `G38.2` target is now evaluated in the *base's* prior
Z0 rather than the part's — and since the spoilboard doesn't move between runs, the base's own stale
Z0 is far more likely to be a sane reference than a part WCS's. The general frame-dependence of the
probe target remains (see the wrinkle below).

**Follow-on to consider (not done).** First-part `Skip` (`writeWcsOnStart`) still retracts to the
group-06 probe Safe Z **in the part's frame**. That is legitimate on its own terms — `Skip` trusts
the stored Z, so the height is meaningful — but with a base now reserved the tool arrives at
spoilboard + Inter Part Safe Z and then *descends* to a part-relative hop that may not clear a taller
clamp elsewhere on the bed. Worth deciding whether `Skip` (and the added-part `Skip`) should hold the
base clearance instead when a base is reserved. `Skip` is a verified path (H5), so this is a
deliberate change, not a silent one.

**Related pre-existing wrinkle (separate item).** The base probe's `G38.2` **target**
(`G_Probe_G38Target`, default `-10`) is likewise evaluated in the active frame, so a stale Z0 can
make the base probe under-travel (never reaches the spoilboard → probe alarm) or over-travel.
Selecting the base first does *not* fix this — the base's Z is also stale *before* its probe. Probing
is inherently "descend until trigger", so the target is a travel limit whose meaning is frame-
dependent no matter what; worth documenting, and possibly worth a more generous target for the base
probe specifically.

**To do — warn in the file that the traverse Z is unknown.** In the `Probe Z` first-part mode the
`G0 X0 Y0` to the stored origin is the **first motion in the program** and runs at whatever height
the operator left the tool at — confirmed in `H7.gcode`, where that full-bed rapid is the very first
motion and nothing in the file hints at its height. The post cannot emit a Z move here (the frame's
Z is stale by definition), so it must say so instead: add an **Info comment** along the lines of
`Ensuring that Z is safe. Unknown Z for XY move.` immediately before that rapid, so both the
operator and an automated review of the g-code can see the precondition. Emit it only on the path
that actually has an unknown Z (`writeWcsOnStart()`'s `Probe Z` branch — **not** `Skip`, which
retracts to a known height first). *Note the byte-identical constraint below: the default Comment
Level is `Info`, so this adds a line to default output on this non-default mode's path only — the
default `Set X0 Y0 to Current Pos, Probe Z0` path is untouched, so the H2 / H-REG anchor holds.*

*Safe arrival applies to `Skip` at both stages:* first-part `Skip` (`writeWcsOnStart`) now
retracts to the probe Safe Z (milling only) and rapids to the stored `X0 Y0` instead of emitting
nothing — Skip uses a stored origin, so the tool must travel there. Added-part `Skip` retracts
(base-relative or probe Safe Z in the outgoing frame) then rapids to `X0 Y0`. Non-base multi-WCS
`Skip`/manual now also retract before the switch (previously only base-relative or the re-probe
path retracted). The **default** job (`Set X0 Y0 to Current Pos, Probe Z0`) and single-WCS jobs are unaffected.
*Verification pending — see `docs/test-plan.md`.*

### Phase 4 — dump ALL properties in the file header *(IMPLEMENTED)*

**Original finding.** `writeInformation()` dumped only **11 of 68** properties at Info level: the
seven `03 - Feeds and Speeds` values and the four `04 - Map G1s to Rapids` values. **57 were absent**,
including every group that the WCS/probe rework touches:

| Group | Dumped? | Notably missing |
|---|---|---|
| `01 - Job` (9) | ✗ | **Firmware**, Comment Level, arcs, spindle control, sequence numbers |
| `02 - Establish Machine Coordinates` (2) | ✗ | Home Before Start, Prompt Before Home |
| `03 - Feeds and Speeds` (7) | ✓ | — |
| `04 - Map G1s to Rapids` (4) | ✓ | — |
| `05 - Establish Spoilboard Reference` (4) | ✗ | Reserved WCS, Probe to Set Base, Retract Across Parts, Safe Z |
| `06 - On WCS / Part / Fixture Changes` (10) | ✗ | **First WCS / Part**, **Subsequent WCS / Part**, Probe Pause, Probe X/Y Offset, G38 target/speed, probe Safe Z, thickness |
| `07 - Tool Changes` (8) | ✗ | all, incl. Probe After Change and the change position |
| `08 - External Include Files` (5) | ✗ | all |
| `09 - Laser` (7) / `10 - Coolant` (10) / `11 - Duet` (2) | ✗ | all |

**Why it matters.** Reviewing a posted `.gcode` — by a person or an agent — currently means
*inferring* the settings from the output. Verifying `H7.gcode` required deducing from motion and
comment text alone that the firmware was GRBL, First WCS / Part was `Use Active WCS X0 Y0, Probe
Z0`, the probe offsets were `0`, Probe Pause was `Before & After`, and no base was reserved. Each
inference is a chance to mis-review, and a negative ("no base reserved") can only ever be inferred
from an *absence*, which is exactly the weakest kind of evidence. A full dump turns every test row's
setup into an assertion the file itself carries.

**As built.** Two new functions, called from `writeInformation()` in place of the two hand-written
blocks (whose contents are now covered by their own groups, so nothing was lost but the friendly
labels):

- **`writeAllProperties()`** — buckets `properties` by `group`, sorts the group names and the keys
  within each, and emits one Info block per group. It **iterates the object rather than listing
  keys**, so a newly added property is dumped for free and this cannot drift. The zero-padded
  `group:` strings mean a plain lexicographic sort reproduces the dialog order, and the
  single-letter key prefix does the same within a group — the two conventions already documented
  above now do double duty. Values print in their **stored** form: an enum shows its `id`, not its
  display title, so the dump survives dialog relabelling (the ids have already outlived two rounds
  of retitling). An unset string prints `<empty>` — a typed check, so a numeric `0` isn't caught.
- **`writeResolvedValues()`** — the things that are *not* any property's stored value: output unit
  (Fusion's, not the dialog's), resolved firmware, **both** Safe-Z modes with their resolved
  defaults, the reserved base as `G59 (P6)`, and the probe XY offset and Inter Part Safe Z converted
  to output units. Without this the dump misleads: `I_Probe_SafeZ = Retract:15` does not tell you the
  retract actually resolved to `5.08` for a given operation, which is exactly what cost time reading
  `H7.gcode`.

Verified by a harness against the real `properties` object: **11 groups, all 68 properties, none
missing, correct dialog order** within and between groups.

**Route taken on the byte-identical question: (a) — unconditional at Info.** Default Comment Level is
`Info`, so this **does** change default output: roughly 98 comment lines are added to every posted
file's header. The alternatives were (b) hide it behind Debug and (c) gate it on a new "Dump All
Properties" property defaulting off. (a) was chosen because the whole purpose — a posted file that
carries its own configuration for review — is defeated by a switch a reviewer has to remember to
flip. **Consequence: the H2 / H-REG byte-for-byte anchor must be re-baselined** against a
current-post reference; no *motion* changed, only header comments. Reverting to (c) is a one-line
guard around the two calls if the header proves too heavy.

Still open if wanted: dumping the *per-section* effective Safe Z (the resolved block reports the
mode and the fallback, not each operation's resolved height).

### Phase 4 — backlog: "Copy first part's Z" option on `B_Probe_OnChange`

A third enum value alongside `Skip` / `Probe Z`: write the first part's probed Z into each
added copy's own register (`G10 L20 P<n> Z<firstPartZ>`) — a register write, **no motion, no
probe** — for same-thickness co-planar fixtures. Requires caching the first part's probed Z at
`A_Probe_OnStart` time. Marlin no-op. The neutral "Subsequent WCS / Part" title already
accommodates it. *Deferred until the retract/tool-change work is done.*

### Phase 4 — closeout tests
- Regression: single-WCS, no-base jobs byte-for-byte unaffected.
- Hands-on: multi-WCS via base retract/travel; Guard B fires when safe-Z + multi-WCS + no
  base; a spoilboard-surfacing section on the base restores the following sections' WCS (R1).
- Update `docs/test-plan.md`.

### Phase 5 — G0/G1 rapid-mapping review
Confirm the "Map G1s to Rapids" optimization needs no change under the new model: does it ever
run across a section/WCS boundary (where Phase 4 injects safe-Z/base logic), or strictly within
one section/WCS? If strictly single-section: document "no change needed" and close as a no-op.
If a cross-boundary case exists: file it as a new item (a collision-risk case Phase 4 didn't
anticipate).

### Backlog / future review *(lower priority; folded from the old testing-log)*

Observations from reviewing real F360 g-code output that need no immediate action:

- **WCS `0`/`1` mixed-design warning (human-factors).** A job that uses work offset `0` in one
  section and `1` in another resolves both to `G54` (both alias to WCS 1), but to an operator
  reading Fusion's Operations panel they look like two deliberate, different fixtures — F360's
  own "multiple setups with different WCS" dialog reinforces the illusion. No code fix intended
  yet. If revisited: emit a `>>> WARNING` when a job mixes `0` with a *different* explicit
  offset, and/or add README guidance to standardize on an explicit `1`. The correct rule is
  any-section-vs-any-other-section — broader than Fanuc's `getSection(0).workOffset == 0`
  check, which is order-dependent and would miss the `Setups.gcode` case (Setup1=`1`, Setup2=`0`).
- **`useZeroOffset` enforcement.** `wcsDefinitions.useZeroOffset: false` is declared but is
  likely inert — the enforcing `validateCommonParameters()` lives in a shared post library this
  post doesn't import, so `writeWCS()` still silently aliases `0`→`1`. Mirroring that check in
  `writeWCS()`/`onSection()` is the natural companion to the item above if the mixed-design risk
  is pursued.
- **`job1_SetOriginOnStart` (G92) vs. the G10 L20 model.** The original motivation for revisiting
  origins — a `G92 X0 Y0 Z0` start origin defeating a "switch WCS on the console between runs to
  mill repeat copies" workflow — is now addressed by the Replicate multi-WCS path (per-copy Z
  re-probe + reserved base). Confirm the remaining G92 start origin doesn't undercut a
  console-selected WCS on re-runs. Pending the dedicated auto-iterate-WCS test file.
- **`permittedCommentChars` global.** A comparable community GRBL post declares it; research
  whether declaring it adds real kernel-side comment filtering on top of the existing
  `sanitizeMessageText()` (code-quality #19/#24) before adding — it may be purely informational.
- **Global-metadata gaps.** Consider declaring `extension: "gcode"` (so Fusion defaults the save
  dialog to `.gcode` instead of `.nc`/`.tap`); optionally `vendorUrl` / `model`. Cosmetic.

---

## Decisions (resolved)

- **`B_Machine_PromptBeforeHome`** pauses once before any homing motion, on any firmware and
  for any axes (deliberately not Z/Marlin-specific, so it survives a machine change).
- **Homing is one `Home Before Start` enum (None / XY / XYZ)** — the earlier per-axis
  X/Y/Z pickers were collapsed; no target machine needs a combination outside those three.
- **Homing order** is not post-controlled (firmware concern).
- **`B_Spoilboard_BaseEstablish`** is an enum defaulting **Pause & Probe Z** (attach/probe/detach);
  `Probe Z` probes with no prompt; `None` emits an "assumed pre-set" Info comment.
- **Marlin multi-WCS is a hard post error** (Guard C).
- **No real TLO** — per-tool re-probe is the substitute.
- **Multi-WCS supports two coexisting per-part workflows** *(updated — was "Replicate-only")* —
  milling multiple parts/copies, one WCS per part. (1) *Pre-set fixture offsets (Replicate):*
  `B_Probe_OnChange` = `Skip` (use stored X/Z) or `Probe Z` (stored XY, re-probe Z). (2) *Manual
  per-part:* `Jog XYZ` / `Jog XY & Probe Z` — the operator jogs to each part and the post records
  its origin. The reserved base + Safe Z give the cross-part clearance in either. One part from
  multiple datums, or a flip, is still out of scope for a single run (separate jobs).
- **Tool-change position:** base-relative when a base is reserved (fixed spot across fixtures),
  else current-WCS. Never `G53`. *(Remaining work — current code does only the no-base branch.)*

---

## Reference — per-machine settings

Each row maps a machine to its `Home Before Start` (None / XY / XYZ) and `Prompt Before Home`
settings so the operator knows what to do at job start.
(Candidate for migration into `README.md` if a per-machine section is added there.)

| Machine / firmware | Home Before Start | Prompt Before Home | Reserved base | Operator does |
|---|---|---|---|---|
| LowRider (Marlin or FluidNC) | `XYZ` if Z endstops fitted, else `XY` | Off | `G59` if multi-fixture, else `None` | homes X/Y; Z endstops optional (beam squaring); work-Z touched off with the plate either way |
| MPCNC + FluidNC, X/Y switches | `XY` | Off | `G59` if multi-fixture | homes X/Y; machine Z n/a (probe pin can't home), Z set by the work plate |
| MPCNC + Marlin, plate as Z-endstop | `XYZ` | On | `G59` if multi-fixture | homes X/Y; at the pause places the movable plate, then Z homes to it |
| MPCNC, no switches | `None` | Off | `G59` if multi-fixture | parks X/Y by hand as zero; Z set by the work plate |
| Single-part job (any machine) | per row above | per row above | `None` | one WCS zeroed to the part; no base |
