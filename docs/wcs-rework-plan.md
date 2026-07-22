# WCS / Origin Rework Plan

## Problem statement

- `G92` is a single global offset, not scoped to whichever WCS was active when it was
  issued — it shifts every coordinate system (G54-G59.3) simultaneously and persists
  across WCS changes until explicitly cleared. Any job that establishes an origin via
  `G92` and then switches to a different WCS later in the file silently carries that
  offset into the new WCS, corrupting it by an arbitrary amount.
- This hazard exists in three places today, all using `G92`:
  - `job1_SetOriginOnStart` (start-of-file zero, group "1 - Job").
  - `probe1_OnStart` (start-of-file probe, group "5 - Probe").
  - `probe2_OnToolChange` (re-probe after every tool change, group "5 - Probe") —
    same hazard, different trigger.
- `job1_SetOriginOnStart` and `probe1_OnStart` overlap in a confusing way: if both are
  enabled, Z gets set twice in a row (zeroed, then immediately overwritten by the
  probe) — a sign these are two strategies for the same moment, not independent
  toggles.
- There's no mechanism today to re-establish an origin when a WCS actually changes
  mid-job (Setup2 onward) — only at file-start and at tool changes.

## Design decisions

1. **Persistence mechanism**: `G10 L20 P<n>` on GRBL and RepRap — writes the current
   position directly into WCS `<n>`'s own offset register, scoped to just that WCS,
   no cross-contamination. Confirmed both firmwares support `G10 L2`/`G10 L20`, and
   the `P` parameter maps 1:1 onto this post's existing `workOffset` numbering
   (P1-P6 = G54-G59, P7-P9 = G59.1-G59.3 on RepRap; GRBL supports P1-P6 only, matching
   the post's existing GRBL range limit). **Marlin keeps `G92`** — no user-facing
   choice, it's a firmware capability gap: Marlin has no addressable per-WCS register
   without `CNC_COORDINATE_SYSTEMS` (which this post doesn't assume), and even with it,
   `G10 L20 P1-6` support is an open Marlin feature request, not shipped.

2. **Consolidate into one group.** Rename group `"5 - Probe"` → `"5 - WCS / Probe"`.
   Remove `job1_SetOriginOnStart` (group "1 - Job") and `probe1_OnStart` entirely;
   fold their behavior into two new properties in the renamed group. Group "1 - Job"
   keeps its remaining properties as-is (numbering gap where `job1_` was removed is
   accepted deliberately, to avoid unrelated renumbering churn across unrelated
   properties).

3. **New property `probeA_OnStart`** (shipped name — kept the `probe` prefix to match
   the sibling properties already in the "5 - WCS / Probe" group, e.g. `probeC_G382orG28`,
   rather than introduce a separate `wcs` prefix) (enum: `Skip` / `Zero XYZ` / `Zero XY &
   Probe Z`),
   default `Zero XYZ` (preserves today's default: `job1_SetOriginOnStart` was `true`,
   `probe1_OnStart` was `false`). Replaces `job1_SetOriginOnStart` + `probe1_OnStart`.
   Applies to the WCS resolved for the *first* section in the file (whatever offset
   that turns out to be, not necessarily G54). Executed in `writeFirstSection()`
   *after* `writeWCS(currentSection)` has already selected that WCS — this redoes
   (properly, via G10 instead of G92) the ordering fix from earlier this session,
   which is being backed out since it was G92-based and superseded by this plan.

4. **New property `probeB_OnChange`** (enum: `Skip` / `Probe Z`), default `Skip`. Fires
   inside `writeWCS()` whenever it detects a genuine WCS change on a section *after*
   the first (i.e. `previousWorkOffset != undefined` at the point a change is
   detected) — distinguishing "initial establishment" (handled by `probeA_OnStart`)
   from "subsequent change" using the same `currentWorkOffset` tracking already in
   place. No blind X/Y re-zero option here: there's no X/Y touch-off mechanism in this
   post, only Z-probing, so re-zeroing X/Y blindly on a WCS change would just be
   guessing. Naturally a no-op on Marlin, since Marlin's `writeWCS()` branch never
   reaches the change-detection code (it only warns and returns).

5. **Fix `probe2_OnToolChange`'s shared hazard.** `probeTool()` is used by all three
   triggers (`probeA_OnStart`'s probe path, `probeB_OnChange`, and the existing
   `probe2_OnToolChange`). Its final origin-set line changes from a hardcoded
   `G92 Z<thickness>` to a call through the new `writeWcsOrigin()` helper, targeted at
   `currentWorkOffset` — fixing the hazard for all three callers with one change.

6. Shared probe mechanics (`probe3_Thickness`, `probe4_G382orG28`, `probe5_G38Target`,
   `probe6_G38Speed`, `probe7_SafeZ`) are unchanged and reused by all triggers.

## New helper: `writeWcsOrigin(wcsNumber, x, y, z)`

Persists the current position as WCS `wcsNumber`'s own origin. Any of `x`/`y`/`z` may
be `undefined` to leave that axis alone (e.g. "Zero XY" only sets X/Y).

- GRBL/RepRap: `G10 L20 P<wcsNumber> [X..] [Y..] [Z..]`
- Marlin: `G92 [X..] [Y..] [Z..]` (ignores `wcsNumber` — Marlin has one global origin)

## Property/behavior migration (old → new)

| Old (`job1_SetOriginOnStart`, `probe1_OnStart`) | New `probeA_OnStart` |
|---|---|
| `false`, `false` | `Skip` |
| `true`, `false` | `Zero XYZ` |
| *(either)*, `true` | `Zero XY & Probe Z` (probe already won at runtime today) |

Existing Fusion personal-post presets that reference `job1_SetOriginOnStart` /
`probe1_OnStart` by internal property id will silently drop those values (property no
longer exists) and fall back to `probeA_OnStart`'s default (`Zero XYZ`) — call this out
in release notes / the test plan, since a preset built around `probe1_OnStart=true`
would otherwise silently lose the probe-on-start behavior.

## Open technical items to double-check during/after implementation

- Confirm `writeBlock()` cleanly drops `undefined` arguments (needed for
  `writeWcsOrigin` to omit untouched axes) — check its definition/existing call
  patterns in the file rather than assuming.
- Confirm GRBL's `G10 L20` truly ignores/rejects P7-P9 the same way plain WCS
  selection does (existing code already errors on GRBL workOffset > 6, so this should
  already be unreachable, but worth a sanity check once implemented).
- Hands-on test: a job whose first section is *not* WCS 1, to confirm
  `probeA_OnStart` targets the right WCS via G10 instead of always assuming G54.
- Hands-on test: a multi-WCS job with `probeB_OnChange = Probe Z`, confirming each
  WCS's own offset register is written independently and none of the others shift.

## Open design question: tool-change position should likely be G53, not WCS-relative

Found while cleaning up `toolChange()`'s wording (property renames are already
in; the underlying behavior is deliberately left unchanged for now).
`toolChange2_X`/`toolChange3_Y`/`toolChange4_Z` are currently emitted as plain
`G0` words (no `G53`), so the tool-change rapid lands wherever those numbers
resolve in whichever WCS is *currently* active, not machine coordinates.

A dedicated manual tool-change spot (or a real ATC installation) only works as
a fixed *machine* location — the whole point is that the operator can always
reach it. WCS-relative positioning breaks that: the physical spot would
silently drift to wherever each job's WCS happens to be zeroed, which differs
per workpiece.

Separately, `toolChange7_ProbeAfterChange`'s probe *does* need a specific WCS
to write into (it's not a fixed-location question) — for that part, the
existing ordering caveat still applies: in `onSection()`, `toolChange()` (and
therefore this probe) runs *before* `writeWCS(currentSection)` selects the new
section's WCS, so it currently targets the *previous* section's WCS if a tool
change coincides with a WCS change.

**RESOLVED / superseded — see "The everyday reference — work-relative, G54-base"
below.** The `G53` conclusion held for production mills but was reconsidered for
V1E hardware: most target machines can't home Z (no machine Z), machine
coordinates are negative/confusing on GRBL, and mixing a machine-Z reference on
one machine with a work-Z reference on another is itself a crash class. The
adopted default is a **work-relative, reserved-base** convention (a high WCS such
as `G59` reserved as the spoilboard base), with machine-referenced (`G53`)
positioning demoted to an optional robustness feature where homing supports it.
The `toolChange7_ProbeAfterChange` ordering caveat above still stands regardless.

## Implementation checklist (Phase 1) — done, verified against shipped code

- [x] Remove `job1_SetOriginOnStart`, `probe1_OnStart` properties. *(confirmed absent)*
- [x] Add `probeA_OnStart`, `probeB_OnChange` enum properties to group
      `"5 - WCS / Probe"`. *(confirmed present; shipped with the `probe` prefix — see
      note above, not the `wcs` prefix originally drafted here)*
- [x] Rename group `"5 - Probe"` → `"5 - WCS / Probe"` on all properties in it.
      *(confirmed)*
- [x] Add `writeWcsOrigin(wcsNumber, x, y, z)` helper (G10 L20 / G92 branch).
      *(confirmed, `MPCNC_v4.0_Beta2.cps:1198`)*
- [x] `writeFirstSection()`: call `writeWCS(currentSection)` first (redo ordering
      fix), then a new `writeWcsOnStart()` implementing the `probeA_OnStart` enum,
      replacing the old G92/probe block that lived inside `Start()`. *(confirmed)*
- [x] `Start()`: remove the old `job1_SetOriginOnStart` / `probe1_OnStart` block
      (moved to `writeWcsOnStart()`). *(confirmed)*
- [x] `writeWCS()`: after a genuine non-first-section offset change, trigger
      `probeB_OnChange`'s probe-Z logic for GRBL/RepRap. *(confirmed)*
- [x] `probeTool()`: replace the hardcoded `G92 Z<thickness>` line with
      `writeWcsOrigin(currentWorkOffset, undefined, undefined, thickness)`.
      *(confirmed, `MPCNC_v4.0_Beta2.cps:2224`)*
- [ ] Update `docs/beta2-test-plan.md` (or a successor doc) with test items for:
      `probeA_OnStart` (all 3 modes, including first section on a non-default WCS),
      `probeB_OnChange = Probe Z`, tool-change re-probe now G10-scoped, Marlin
      unaffected (still G92, still warn-only above WCS 1). **Still open** — the
      current test plan covers the pre-rework G92 ordering bug, not these specific
      probe-mode test items.

---

# Plan: coordinate handling, probing, and tool changes

Forward plan for a coherent operator workflow, building on the Phase-1 `G10`
rework above. Written so it can condense into an end-user section of `README.md`.
It must serve both fully-licensed Fusion 360 and the Fusion Personal ("hobby")
case that mills one operation at a time.

## Coordinate model, and the stance this post takes

Production controls keep three references separate:

- **MCS** (`G53`, set by homing) — the fixed machine frame. Safe-Z retracts and
  tool-change / park positions normally live here.
- **WCS** (`G54`-`G59`) — where the part is; set once at setup and persisted.
- **TLO** (`G43 Hn`) — each tool's length, measured once at a tool setter, so tool
  changes don't require re-probing the part.

Most V1E machines have none of the three fully — often no Z homing, no tool setter,
no persisted setup. So this post takes a deliberate **work-relative stance**:

- The everyday reference is the **active WCS**, not the machine frame.
- **Tool length is folded into a Z re-probe after every tool change** (no TLO).
- Homing (the machine frame) establishes MCS for **X/Y only** — gantry squaring and a
  repeatable XY origin, and as an *optional* robustness feature. **Z homing is a
  separate concern**: where a real Z endstop exists (LowRider switches, Marlin sharing
  the Z-min pin with a movable plate), it is homed for its own sake (squaring, or
  because the plate-homing trick needs it) — it is never in service of MCS
  establishment and never becomes the everyday Z reference, which is always the
  work-Z touch-off below.

This is the right stance for the audience: it works on the lowest-common-denominator
machine (no Z homing) and matches the GRBL ecosystem (Shapeoko / OpenBuilds /
Onefinity all zero to the work and probe Z).

## The everyday reference — work-relative, G54-base

**Decision** (supersedes the earlier "tool-change should be G53"): every everyday move
— safe-Z retract, tool-change position, inter-section and inter-WCS traverses — is
**work-relative** to a stable **base WCS zeroed to the spoilboard** (a fixed surface,
so it is independent of stock thickness — not the stock top).

**Why:** if one machine used a machine-Z reference (LowRider: Z0 at the top of travel,
work envelope negative below) and another a work-Z reference (MPCNC: Z0 at the
spoilboard, positive up), the same posted "retract to Z30" is safe on one and
out-of-range / a crash on the other. Standardizing on work-Z everywhere (Z0 =
spoilboard, up = positive) removes that frame-mixing crash class. An **absolute**
work-Z clearance clears the stock from any pocket depth, so a machine-Z retract buys no
real safety here.

**The reserved base:**

- Chosen from a dropdown, default **G59** — the highest slot GRBL supports, so the
  Fusion default (`G54`) stays a free part slot and beginners never collide with the
  base. Higher slots (`G59.1` / `G59.2` / `G59.3`) are offered but marked **RepRap
  only**. `None` disables the base feature and its guards.
- Two sub-behaviors: **establish at job start** (probe the spoilboard) or **assume
  already set** (probe once, run many jobs).

Machine-referenced (`G53`) positioning remains available only as an opt-in robustness
variant on homed machines; never the default.

## Establishing the machine frame (homing / MCS)

Used for gantry squaring and a repeatable origin (resume after power loss) — not the
everyday Z reference.

**Two ways to set an axis's machine zero (the whole basis):**

1. **Power-On** — accept the current position as zero; the post emits no motion.
   Repeatable only via a parking ritual; the fallback for an axis with no endstop.
   (Also covers "I already homed in my sender.")
2. **Home** — the post emits the firmware home command and the axis runs to its
   endstop. Repeatable and crash-recoverable; best practice where wired. The post does
   **not** model *how* the axis homes (switch vs. plate, thickness) — that is firmware
   config.

Per-axis, opt-in, default all `Power-On` — out of the box the post emits no homing,
because a wrong home command is a crash.

**Homing command by firmware:**

| Firmware | Command |
|---|---|
| Marlin | `G28 X` / `G28 Y` / `G28 Z` (subsets) |
| GRBL / FluidNC | `$H` only — homes all configured axes together |
| RRF / Duet | `G28 X` / `G28 Y` / `G28 Z` |

**Decision:** we do not assume a recompiled FluidNC with `allow_single_axis` — stock
FluidNC and stock GRBL are treated identically, both `$H`-only. This collapses the
firmware table to three rows and has a property-model consequence: on GRBL/FluidNC the
per-axis `A_Machine_HomeX`/`B_Machine_HomeY`/`C_Machine_HomeZ` pickers cannot each
trigger their own command, because `$H` is all-or-nothing. There, the post emits **one** `$H` if
*any* axis is set to `Home`; the per-axis pickers still matter as documentation/bookkeeping
(which axes the user asserts are actually wired to home) but do not each cause separate
motion. Marlin and RRF/Duet get true independent subsets via `G28 X`/`G28 Y`/`G28 Z`.

The post does **not** control homing *order*: `$H` homes every configured axis together,
and Marlin/RRF run their firmware-defined sequence. We only choose *whether* homing runs,
not the order axes move in.

**Machine-referenced moves differ by firmware:** GRBL/FluidNC `G53` works from a homed
*or* a power-on frame (warn on power-on, don't block). Marlin has no `G53` on the
target config — machine moves use the homed native frame via plain `G0` (minus any
active `G92`). RRF refuses motion on un-homed axes, so there a machine move requires
that axis homed.

**The V1E plate reality (why machine Z is usually unavailable on the MPCNC):**

- **LowRider** homes X/Y/Z to switches (Z up); its touch plate is a *separate,
  optional* work-Z probe.
- **MPCNC** usually has no Z endstop, and the plate wiring differs by controller:
  on **FluidNC (Jackpot)** the plate is a dedicated probe pin (gpio.36) that
  **cannot home** — Z is work-probe only; on **Marlin** it shares the Z-min pin, so
  with `Z_MIN_PROBE_USES_Z_MIN_ENDSTOP_PIN` it *can* home Z to the plate (a movable
  plate → needs an attach/remove pause).
- Power-on Z is useless (nobody parks Z at a repeatable height), so where Z can't home
  there is **no usable machine Z** — machine-Z features degrade to work-relative, and
  only machine **XY** (if switches are fitted) is available.

## Probing and tool changes

- **Work-Z probing only.** `G38.2` down to a touch plate (thickness compensated), with
  the existing attach/remove pauses. There is **no tool-length system**, and X/Y is
  never probed (manual jog). State this plainly to users.
- **Re-probe after every tool change** — this is the tool-length substitute: a new
  tool's length differs, so Z is re-referenced after each swap.
- **Manual tool changes** (no ATC): retract to a work-relative safe Z → move to a
  work-relative change position → pause for the swap → re-probe Z → return to the next
  section's start. Every leg is collision-sensitive; this sequence is the crux of safe
  multi-tool jobs on V1E machines.

## Properties (the dialog)

**Property naming convention (dialog ordering).** In Fusion's post dialog, groups are
ordered by the `group:` string and, within a group, properties are ordered by a string
sort of the **property key** (the inline-property form this post uses has no `order`
field — that only exists in the split `propertyDefinitions` form, deliberately not
adopted here). Two independent mechanisms, so ordering is controlled in two places:

- **Group order — the `group:` string, zero-padded to two digits:** `01 - Job`,
  `02 - Machine`, `03 - Feeds and Speeds`, `04 - Map G1s to Rapids...`,
  `05 - Tool Changes`, `06 - WCS / Probe`, `07 - External Include Files`, `08 - Laser`,
  `09 - Coolant`, `10 - Duet`. Padding is required: unpadded, `10 - Duet` sorts adjacent
  to `1 - Job` (the classic `1, 10, 2` lexicographic bug) instead of last. Fixed-width
  digits sort correctly under every collation Fusion might use (and regardless of whether
  it ignores the ` - ` punctuation). A single-letter group prefix in the *key* does **not**
  drive group order — only the `group:` string does.
- **Within-group order — a single-letter item prefix on the key:**
  `<ItemLetter>_<GroupName>_<PropertyName>`, the item letter (`A`, `B`, …) restarting at
  `A` in each group, e.g. `A_Job_SelectedFirmware`, `B_Job_ManualSpindlePowerControl`,
  `A_Machine_HomeX`, `B_Machine_HomeY`.

Old-prefix → new mapping (historical prose below still uses the old names):
`job*`→`?_Job_*`, `machine*`→`?_Machine_*`, `fr*`→`?_Feeds_*`, `map*`→`?_MapRapids_*`,
`toolChange*`→`?_ToolChange_*`, `probe*`→`?_Probe_*`, `gcode*`→`?_Include_*`,
`cutter*`→`?_Laser_*`, `cl*`→`?_Coolant_*`, `duet*`→`?_Duet_*` (`?` = item letter).
**New properties added in later phases must follow this convention** (pick the next free
item letter in their group; if inserting mid-group, re-letter the ones after it).

**Group "02 - Machine"** (sorts right after `"01 - Job"`, so the firmware picker
`A_Job_SelectedFirmware` is already visible above it — the per-axis pickers' behavior
depends on which firmware is selected: bookkeeping-only on GRBL/FluidNC vs. real
independent `G28` on Marlin/RRF):

- `A_Machine_HomeX` / `B_Machine_HomeY` / `C_Machine_HomeZ`: `Power-On` | `Home`
  (default `Power-On`). On Marlin/RRF each fires its own `G28 <axis>`. On GRBL/FluidNC
  (no per-axis `$H`, see homing section) any axis set to `Home` triggers one combined
  `$H`; the three pickers still document which axes are actually expected to home.
- `D_Machine_PromptBeforeHome` (bool): pause before the **Z** home so the operator can
  place the movable Z plate. Fires only when Z is set to `Home` on a plate-homed setup
  (Marlin sharing the Z-min pin); never for switch homing or X/Y.

**Reserved base** (`H_Probe_BaseReserve` / `I_Probe_BaseEstablish`, in the WCS / Probe
group):

- `H_Probe_BaseReserve` (dropdown): `None` | `G54` | `G55` | `G56` | `G57` | `G58` | `G59` |
  `G59.1 (RepRap)` | `G59.2 (RepRap)` | `G59.3 (RepRap)`. **Default `None`** (feature
  opt-in). *Deviation from the earlier draft, which proposed default `G59`:* defaulting the
  base on would make every default job — including the hobby single-part common case —
  emit a spoilboard probe at start, breaking the Phase-2 "byte-identical by default"
  stance. So the base is off unless the user picks a slot. When a user does reserve one,
  `G59` remains the natural choice (highest GRBL slot, keeps `G54` free for beginners'
  parts); `G54` is still offered for those who deliberately want the base on the Fusion
  default slot. `G59.1`-`G59.3` require RepRap; a base is ignored on Marlin (no per-WCS
  registers) with a warning.
- `I_Probe_BaseEstablish` (bool, default **on**): the reserved base's version of the
  probe-on-start step — at job start, probe the spoilboard and write the result into the
  reserved base WCS (`G10 L20 P<n>`). When **disabled**, the post skips the probe and
  emits an Info comment like `(assuming base G59 was established in a previous job)`, so
  the probe-once / run-many workflow is explicit rather than silent. No effect when
  `H_Probe_BaseReserve` is `None`.

**Unchanged:** the Phase-1 `A_Probe_OnStart` / `B_Probe_OnChange` /
`H_ToolChange_ProbeAfterChange` and the shared probe mechanics (`C_Probe_G382orG28`,
`D_Probe_G38Target`, `E_Probe_G38Speed`, `F_Probe_SafeZ`, `G_Probe_Thickness`).

Tooltips must state, per axis, that the machine must actually be wired to home that
axis, and that machine homing is distinct from the work-Z touch-off. The README gets
the per-machine settings table below plus the base conventions.

## Validation guards

Post-time only — the post errors in Fusion; it cannot read the controller's live state.

- **Guard A — no redefine of the base.** *Using* the reserved base (selecting / cutting
  in it) is fine; the post writing its offset a *second* time is the error. If a base
  is reserved and any section's origin-establishment would re-write it →
  error: *"G<n> is reserved as the spoilboard base — assign this operation to another
  WCS."*
- **Guard B — safe-Z across WCS needs a base.** If a safe-Z feature is enabled, the job
  uses more than one WCS, and no base is reserved →
  error: *"Safe-Z across WCS requires a base; reserve a spoilboard base."* A single-WCS
  job is exempt — its one part zero is a stable enough reference.
- **Guard C — Marlin is single-frame.** Marlin has one coordinate frame (the post fakes
  WCS with `G92`), so a multi-fixture job that uses more than one distinct work offset is
  silently wrong on it. On Marlin, a job using more than one WCS is a **hard post error**:
  *"Marlin has a single coordinate frame — this multi-WCS job cannot be posted; use one
  work offset."*

## Proposal under discussion: consolidate the two probe properties (NOT yet decided)

Raised during Phase 3 testing. The two probe-timing dropdowns (`A_Probe_OnStart`
"Probe at Job Start" and `B_Probe_OnChange` "Probe on WCS Change") are easy to confuse —
in testing, the job-start probe was mistaken for the on-change probe. **Proposal:**
collapse them into a single property.

- **Remove** `A_Probe_OnStart` ("Probe at Job Start").
- **Rename** `B_Probe_OnChange`'s label `"Probe on WCS Change"` → `"Probe on WCS"`.
- **New option set:** `Skip` | `Probe Z on First WCS` | `Probe Z on WCS Change`.

Open questions to resolve before implementing (do not action yet):

- **Where do the non-probe behaviors go?** `A_Probe_OnStart` today also offers `Zero XYZ`
  (set current position to 0,0,0, no probe) and the `Zero XY` half of `Zero XY & Probe Z`
  (set current X/Y to 0,0). A probe-only dropdown drops both. Does XY-zero become
  automatic/unconditional, a separate property, or is it dropped?
- **Does `Probe Z on WCS Change` include the first WCS or only subsequent changes?**
  i.e. are "First WCS" and "WCS Change" mutually exclusive options, or should there be a
  "both" behavior (probe the first WCS *and* every later change)?
- **Interaction with the reserved base** (`I_Probe_BaseEstablish`): the base already
  probes at job start independently; make sure the consolidated option doesn't double-probe
  or conflict.
- **Migration:** existing presets referencing `A_Probe_OnStart` / `B_Probe_OnChange` by id
  would need a mapping (and would silently reset otherwise, as happened with the Beta1→Beta2
  property renames).

## Workflow conventions (for the README)

- **Single operation / single part (the hobby common case):** zero the active WCS to
  the part; safe-Z and tool-change are relative to that one zero; no base needed.
- **Multi-fixture / multi-setup:** reserve the base (default `G59`) zeroed to the
  spoilboard, set once, and put each part on `G54`-`G58`. Don't re-zero the base per
  part.

## Per-machine settings (README-ready)

Each machine row says **how that axis gets its reference** so the operator knows what to
do at job start. The X / Y / Z cells take one of three values:

- **Home** — the axis has an endstop; the post homes it (machine frame). Set the matching
  `machine*_Home*` property to `Home`.
- **Power-On** — no endstop; the current position is accepted as zero. Set the property to
  `Power-On`. The operator must park the axis deliberately if they want repeatability.
- **Probe** — the axis has no machine home; its cutting zero comes from the **work-Z touch
  plate** (`G38.2`), not the machine frame. The machine property stays `Power-On`; the Z
  reference is established by the probe step, and re-probed after every tool change.

| Machine / firmware | X | Y | Z | Reserved base | What the operator does |
|---|---|---|---|---|---|
| LowRider (Marlin or FluidNC) | Home | Home | Home if fitted, else Probe | `G59` if multi-fixture, else `None` | homes X/Y; Z endstops are optional (used for beam squaring) — if fitted Z homes, otherwise Z is set with the work plate. Work-Z is touched off with the plate before cutting either way |
| MPCNC + FluidNC, X/Y switches | Home | Home | Probe | `G59` if multi-fixture | homes X/Y; machine Z n/a (probe pin can't home), so Z is set by the work plate |
| MPCNC + Marlin, plate as Z-endstop | Home | Home | Home + prompt | `G59` if multi-fixture | homes X/Y; places the movable plate at the pause, then Z homes to it |
| MPCNC, no switches | Power-On | Power-On | Probe | `G59` if multi-fixture | parks X/Y by hand as zero; Z set by the work plate |
| Single-part job (any machine) | per row above | per row above | per row above | `None` | one WCS zeroed to the part; no base needed |

## Phased roadmap

Incremental — the machine frame is established and verified before existing behavior is
rewired. Index only; each phase's concrete checklist is its own section below.

- **Phase 1 — done.** WCS origin/probe rework to `G10 L20`.
- **Phase 2 — done** (verified in `docs/beta2-test-plan.md`; README write-up still outstanding).
  Establish MCS in isolation.
- **Phase 3 — done** (guards + reserved base, verified in `docs/beta2-test-plan.md`;
  README write-up still outstanding). Reserved base + validation guards.
- **Phase 4 — next, not started.** Consume the base for safe-Z / tool-change / traverses.
- **Phase 5 — not started, likely no-op.** Confirm `G0`/`G1` rapid mapping needs no change.

## Implementation checklist (Phase 2) — establish MCS, in isolation

Goal: the post can home (or explicitly not home) each axis at job start and say so in
the output. X/Y homing is what actually establishes MCS (repeatable origin, gantry
squaring); Z homing, where wired, is included for its own reason (a real endstop or the
plate-homing trick) — it is never in service of MCS and never changes the everyday Z
reference (still always the work-Z touch-off). **Change nothing else this phase** —
with every axis left at the default `Power-On`, output must stay byte-for-byte
identical to the current Phase-1 baseline.

- [x] Add property group `"02 - Machine"` and zero-pad all group headers to two digits
      (`01 - Job` … `10 - Duet`), so Machine sorts right after Job (the firmware picker is
      visible above the per-axis homing pickers whose behavior depends on it) and the
      headers sort in numeric order — see the naming convention above for why padding is
      required.
- [x] Add `A_Machine_HomeX` / `B_Machine_HomeY` / `C_Machine_HomeZ` (enum: `Power-On` |
      `Home`, default `Power-On` each) — keys follow the naming convention above.
- [x] Add `D_Machine_PromptBeforeHome` (bool, default off) — pause before a *Z* home only,
      on the plate-homed setup (Marlin sharing the Z-min pin). Not shown/not fired for
      X/Y or for GRBL/FluidNC/RRF switch homing.
- [x] Add a `writeMachineHoming()` function, called once at job start, **before**
      `writeWCS(currentSection)`/`writeWcsOnStart()` in `writeFirstSection()`:
  - [x] Marlin / RRF: emit `G28 <axis>` independently per axis set to `Home`.
  - [x] GRBL / FluidNC: emit **one** `$H` if *any* axis is set to `Home` (no per-axis
        command — see homing section); Debug-log which axes the user asserted are
        wired, since the pickers don't map to independent motion here.
  - [x] Any axis left `Power-On`: emit a Debug comment stating no motion, current
        position accepted as zero — never silent.
  - [x] Wire `D_Machine_PromptBeforeHome`'s pause using the post's existing
        `askUser()` mechanism (the same plate-attach pause the probe path uses),
        immediately before the Z home command; Marlin-only.
- [x] Tooltips: each axis property states the machine has to actually be wired to
      home that axis, and that machine homing is distinct from the work-Z touch-off.
- [ ] README: add the "Per-machine settings" table and a short explanation of Home vs.
      Power-On vs. Probe. **Still outstanding.**
- [x] Regression check: default settings (`Power-On`/`Power-On`/`Power-On`) produce
      identical `.nc` output to the current Phase-1 baseline — no new G-code.
- [x] Hands-on tests: Marlin with `Home` + prompt on Z fires the pause then `G28 Z`;
      GRBL/FluidNC with X=`Home`, Z=`Power-On` fires exactly one `$H` (not per-axis);
      RRF with X=`Home` only fires `G28 X` only, Y/Z left alone.
- [x] Update `docs/beta2-test-plan.md` (or successor) with these test items.

## Implementation checklist (Phase 3) — reserved base + validation guards

Goal: a spoilboard base WCS can be reserved and (optionally) self-established, and the
post catches the misconfigurations identified in "Validation guards" above — all before
anything downstream (Phase 4) actually depends on the base existing.

- [x] Add `H_Probe_BaseReserve` dropdown (`None` | `G54`-`G59` | `G59.1`-`G59.3 (RepRap)`)
      to the `"06 - WCS / Probe"` group (item letter `H`, after `G_Probe_Thickness`).
      **Default `None`, not `G59`** — see the deviation note in the Reserved base section
      above (keeps default output byte-identical, per the Phase-2 stance).
- [x] Add `I_Probe_BaseEstablish` (bool, default on) — item letter `I`.
- [x] Job-start (`writeBaseEstablish()`, called from `writeFirstSection()` after `Start()`,
      before `writeWcsOnStart()`): if a base is reserved and `I_Probe_BaseEstablish` is on,
      probe the spoilboard and write it via `probeTool(base)` → `writeWcsOrigin()` into the
      reserved WCS. If off, emit the `(assuming base G<n> was established ...)` Info comment
      and skip. `probeTool()` gained an optional `targetWcs` param (defaults to the active
      offset) so the base reuses the existing probe mechanics.
- [x] Guard A (no redefine of the base): `baseOriginWriteReason()` walks the sections and
      errors if `A_Probe_OnStart` / `B_Probe_OnChange` / `H_ToolChange_ProbeAfterChange`
      would write to the base WCS.
- [x] Guard C (Marlin single-frame): `validateJob()` errors if a Marlin job uses more than
      one distinct work offset. Also added: `G59.1`-`G59.3` base rejected on GRBL.
- [x] Guard B (safe-Z across WCS needs a base): left as a documented code note in
      `validateJob()` — nothing to key off until Phase 4 adds the safe-Z-across-WCS feature.
- [x] Tooltips: property descriptions explain the reserved base and establish behavior.
      **README still outstanding** (shared with the Phase-2 README write-up).
- [x] Regression check: `H_Probe_BaseReserve = None` (the default) takes the early-return
      path in `validateJob()`/`writeBaseEstablish()` — no base output; Info-level output
      identical to the Phase-2 baseline. *(code-verified; hands-on below)*
- [x] Hands-on tests: Guard A fires when a section's WCS collides with the reserved
      base; Guard C fires on a Marlin job using 2+ WCS; both guards stay silent on a
      valid single-WCS job with no base reserved. *(All 8 items in `docs/beta2-test-plan.md`
      verified in Fusion.)*
- [x] Update `docs/beta2-test-plan.md` (or successor) with these test items.

## Implementation checklist (Phase 4) — consume the base

Goal: safe-Z, tool-change, and inter-section/inter-WCS traverses actually use the
reserved base as their common work-relative reference. Each item below is separately
verifiable — land and test one before starting the next.

- [ ] Confirm/adjust job-start call order: home (Phase 2) → base establish (Phase 3) →
      per-section WCS (Phase 1) — check `onOpen()`/`writeFirstSection()` sequencing.
- [ ] Add the absolute work-Z safe-Z retract (relative to the reserved base if one
      exists, else the active WCS) and wire Guard B to it.
- [ ] Make the tool-change position (`toolChange2_X`/`3_Y`/`4_Z`) explicitly
      work-relative to the reserved base rather than "whichever WCS happens to be
      active" (see "Open design question" note earlier in this doc).
- [ ] Fix the tool-change re-probe ordering caveat: `toolChange()` currently runs
      before `writeWCS(currentSection)` selects the new section's WCS in `onSection()`,
      so a tool change coinciding with a WCS change re-probes into the *previous*
      section's WCS. Reorder so the probe targets the correct (new) WCS.
- [ ] Emit the safe-Z retract on every inter-section / inter-WCS traverse, not just
      tool changes.
- [ ] Regression check: single-WCS, no-base jobs are byte-for-byte unaffected.
- [ ] Hands-on tests: multi-WCS job on GRBL/RepRap correctly retracts/travels via the
      base; Guard B fires when safe-Z is enabled, multi-WCS, and no base reserved.
- [ ] Update `docs/beta2-test-plan.md` (or successor) with these test items.

## Implementation checklist (Phase 5) — G0/G1 rapid-mapping review

Goal: confirm the existing "Map G1s to Rapids" optimization needs no change under the
new model, or file concrete follow-up items if it does.

- [ ] Re-examine the rapid-mapping code against Phase 4's changes: does it ever run
      across a section/WCS boundary (where Phase 4 now injects safe-Z / base logic), or
      strictly within one section and one WCS?
- [ ] If strictly single-section/single-WCS as expected: document the "no change
      needed" conclusion (comment + README), close this phase as a no-op.
- [ ] If a cross-boundary case is found: file it as a new checklist item rather than
      patching silently, since it would be a new collision-risk case Phase 4 didn't
      anticipate.

## Decisions (resolved)

- **`D_Machine_PromptBeforeHome`** fires only before a plate-homed **Z** home, never
  globally or for X/Y.
- **Homing order** is not post-controlled (see the homing section) — a firmware concern,
  not a plan question.
- **`wcsBase_Establish`** defaults **on** (probe the spoilboard into the base at job
  start); disabling it emits an Info comment that the base is assumed pre-set.
- **No machine-profile presets** — the per-axis properties stand on their own.
- **Marlin multi-WCS is a hard post error** (Guard C), not a warning.
- **No real TLO** — per-tool re-probe remains the tool-length substitute.
