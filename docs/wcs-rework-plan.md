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

3. **New property `wcsA_OnStart`** (enum: `Skip` / `Zero XYZ` / `Zero XY & Probe Z`),
   default `Zero XYZ` (preserves today's default: `job1_SetOriginOnStart` was `true`,
   `probe1_OnStart` was `false`). Replaces `job1_SetOriginOnStart` + `probe1_OnStart`.
   Applies to the WCS resolved for the *first* section in the file (whatever offset
   that turns out to be, not necessarily G54). Executed in `writeFirstSection()`
   *after* `writeWCS(currentSection)` has already selected that WCS — this redoes
   (properly, via G10 instead of G92) the ordering fix from earlier this session,
   which is being backed out since it was G92-based and superseded by this plan.

4. **New property `wcsB_OnChange`** (enum: `Skip` / `Probe Z`), default `Skip`. Fires
   inside `writeWCS()` whenever it detects a genuine WCS change on a section *after*
   the first (i.e. `previousWorkOffset != undefined` at the point a change is
   detected) — distinguishing "initial establishment" (handled by `wcsA_OnStart`)
   from "subsequent change" using the same `currentWorkOffset` tracking already in
   place. No blind X/Y re-zero option here: there's no X/Y touch-off mechanism in this
   post, only Z-probing, so re-zeroing X/Y blindly on a WCS change would just be
   guessing. Naturally a no-op on Marlin, since Marlin's `writeWCS()` branch never
   reaches the change-detection code (it only warns and returns).

5. **Fix `probe2_OnToolChange`'s shared hazard.** `probeTool()` is used by all three
   triggers (`wcsA_OnStart`'s probe path, `wcsB_OnChange`, and the existing
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

| Old (`job1_SetOriginOnStart`, `probe1_OnStart`) | New `wcsA_OnStart` |
|---|---|
| `false`, `false` | `Skip` |
| `true`, `false` | `Zero XYZ` |
| *(either)*, `true` | `Zero XY & Probe Z` (probe already won at runtime today) |

Existing Fusion personal-post presets that reference `job1_SetOriginOnStart` /
`probe1_OnStart` by internal property id will silently drop those values (property no
longer exists) and fall back to `wcsA_OnStart`'s default (`Zero XYZ`) — call this out
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
  `wcsA_OnStart` targets the right WCS via G10 instead of always assuming G54.
- Hands-on test: a multi-WCS job with `wcsB_OnChange = Probe Z`, confirming each
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
per workpiece. So this is likely a real bug, not just a documented quirk — it
should probably be a `G53` move instead. `G53` doesn't require true
limit-switch homing to be internally consistent (GRBL/RepRap track machine
position by step-counting from the controller's last reset/power-up), so it
just needs the operator to reset from a consistent physical position, which is
a normal habit on switch-less hobby builds.

Separately, `toolChange7_ProbeAfterChange`'s probe *does* need a specific WCS
to write into (it's not a fixed-location question) — for that part, the
existing ordering caveat still applies: in `onSection()`, `toolChange()` (and
therefore this probe) runs *before* `writeWCS(currentSection)` selects the new
section's WCS, so it currently targets the *previous* section's WCS if a tool
change coincides with a WCS change.

**Production-machine precedent** (the original reasoning): real CNCs never tie
tool-change position to a WCS. Fanuc uses `G30` (a second reference-return
position, defined as a fixed distance from machine zero via parameters, set once
at machine installation) specifically so tool-change clearance is independent of
whatever work offset is active. Haas uses `G53` the same way. Both are
machine-coordinate mechanisms.

**RESOLVED / superseded -- see "The G54-base decision + spoilboard base +
validation guards" below.** The `G53` conclusion held for production mills but
was reconsidered for V1E hardware: most target machines can't home Z (no machine
Z), machine coordinates are negative/confusing on GRBL, and mixing a machine-Z
reference on one machine with a work-Z reference on another is itself a crash
class. The adopted default is instead a **work-relative, G54-base** convention
(a `G54` reserved as the spoilboard base), with machine-referenced (`G53`)
positioning demoted to an optional robustness feature where homing supports it.
The `toolChange7_ProbeAfterChange` ordering caveat above still stands regardless.

## Open design idea: switch to ignore Fusion's per-section WCS assignment

For users who don't need multi-fixture jobs, a boolean could make `writeWCS()`
skip reacting to `section.getWorkOffset()` for every section after the first —
staying on whatever WCS `wcsA_OnStart` established, regardless of what
Fusion's Setups say. `wcsA_OnStart` wouldn't need to change, since it only ever
deals with the first section.

Risk: if a job genuinely spans two different physical fixtures (two real
WCS's), silently pinning everything to the first one would cut the second
setup's toolpaths using the wrong offset — a real footgun, not just a
simplification. If built, it needs a loud warning (same tier as the existing
Marlin WCS-ignored warning) whenever a later section's WCS actually differs
and gets overridden, so it's never silent.

## Open design idea: multi-fixture reposition-and-probe on WCS change

`wcsB_OnChange` currently offers only `Skip` / `Probe Z`. A genuine
multi-fixture workflow — pause for the operator to physically move the
stock/vise to a different location, then probe to establish *that* WCS's own
origin — would mean growing a third option that mirrors `wcsA_OnStart`'s
richer choice, e.g. `Skip` / `Probe Z` / `Reposition & Probe XY+Z`, with an
`askUser()` pause for the reposition step before probing.

Note: this establishes a *work* origin (via `G10 L20 P<n>`, scoped to that
WCS), not the machine's true 0,0,0 — there's no such thing as "probing to
machine coordinates"; machine position is fixed by step-counting from the
controller's last reset/power-up (or true homing), not something a probe cycle
can set. This is exactly the scenario the G10-per-WCS rework was built for — it
wouldn't have worked cleanly under the old global-`G92` approach, since every
WCS's origin needs to be independently addressable for this to be safe.

## Implementation checklist

- [ ] Remove `job1_SetOriginOnStart`, `probe1_OnStart` properties.
- [ ] Add `wcsA_OnStart`, `wcsB_OnChange` enum properties to group `"5 - WCS / Probe"`.
- [ ] Rename group `"5 - Probe"` → `"5 - WCS / Probe"` on all properties in it.
- [ ] Add `writeWcsOrigin(wcsNumber, x, y, z)` helper (G10 L20 / G92 branch).
- [ ] `writeFirstSection()`: call `writeWCS(currentSection)` first (redo ordering
      fix), then a new `writeWcsOnStart()` implementing the `wcsA_OnStart` enum,
      replacing the old G92/probe block that lived inside `Start()`.
- [ ] `Start()`: remove the old `job1_SetOriginOnStart` / `probe1_OnStart` block
      (moved to `writeWcsOnStart()`).
- [ ] `writeWCS()`: after a genuine non-first-section offset change, trigger
      `wcsB_OnChange`'s probe-Z logic for GRBL/RepRap.
- [ ] `probeTool()`: replace the hardcoded `G92 Z<thickness>` line with
      `writeWcsOrigin(currentWorkOffset, undefined, undefined, thickness)`.
- [ ] Update `docs/beta2-test-plan.md` (or a successor doc) with test items for:
      `wcsA_OnStart` (all 3 modes, including first section on a non-default WCS),
      `wcsB_OnChange = Probe Z`, tool-change re-probe now G10-scoped, Marlin
      unaffected (still G92, still warn-only above WCS 1).

---

# Broader review: the CNC coordinate model (WCS / probing / tool changes / MCS)

Everything above (the G10 rework) is Phase 1. This section is the wider expert
review it sits inside: how a production control handles coordinates, where this
post diverges and why, and what a coherent longer-term architecture looks like
for the V1E / hobby audience. Reference material for future work, not a
commitment to build all of it.

## The production model: three orthogonal layers

Production controls keep three coordinate concepts strictly separate:

1. **Machine Coordinate System (MCS / `G53`)** — fixed, established by homing.
   The absolute reference. Tool-change positions, safe-Z retracts, park/end
   positions all live here.
2. **Work Coordinate System (WCS / `G54`-`G59`)** — where the *part* is. One per
   fixture. Established **once at setup** (operator touch-off or a probing
   cycle) and **persisted in the controller**. The post *selects* it (`G54`); it
   does not *set* it.
3. **Tool Length Offset (TLO / `G43 Hn`)** — how long *each tool* is. Measured
   once per tool at a tool setter. Lets you swap tools without re-touching the
   part -- the control compensates for the length difference automatically.

The payoff is that these are **independent**: home once, zero the part once,
measure each tool once. After that, tool changes "just work" -- the control
knows machine position, part position, and tool length, so it never re-probes
the part.

## What this post does, and why it collapses all three layers

This post merges all three layers into one, for reasons rooted in the target
hardware:

- **No MCS**: most MPCNC/LowRider builds historically had no homing, so `G53`
  was unreliable -- the post has *no machine-coordinate concept anywhere*.
  Everything is WCS- or `G92`-relative.
- **No TLO**: no tool setter, and hobby-firmware TLO support is thin. So instead
  of measuring tool length, the post **re-probes Z after every tool change** and
  folds the tool's length directly into the work Z-origin.
- **WCS set at runtime**: no persistent setup workflow, so the post both
  *selects* the WCS and *establishes its origin* (`probeA_OnStart`,
  `G92`/`G10`) inside the job -- something production posts never do.

This conflation is the root cause of nearly every WCS/probe/tool-change quirk in
the post. It is a defensible design for touch-off-and-go hobbyists, but naming
it explicitly is what makes the rest reason-about-able.

## WCS assessment

Sound today: per-section `G54`-`G59` selection on GRBL/RepRap; `G10 L20` per-WCS
scoping (the Phase 1 rework); Marlin honestly degrading to a single `G92` with a
warning.

The conceptual divergence: this post *sets* the WCS origin from inside the job;
production assumes it was set at setup time and persisted. Neither is wrong --
they serve different operators:
- **Runtime-set** (today): touch-off-and-go, no homing, one-shot jobs -- the
  common V1E case.
- **Assume-already-set** (production): needed for repeatability -- re-running
  after a crash without re-zeroing, or cutting N identical parts across
  sessions. Impossible today because the post always re-establishes origin.

Recommendations:
- Treat "establish origin" and "use origin" as separately switchable behaviors.
  `probeA_OnStart = Skip` is effectively "assume already set" -- but it only
  makes sense with homing + persisted offsets (see MCS section below).
- Multi-WCS is only truly coherent on GRBL/RepRap. On Marlin, consider making a
  multi-WCS job a **hard error** rather than a per-section warning, since a
  Marlin multi-fixture job is silently wrong.

## Probing assessment

Production separates **work probing** (find the part: corner/boss/bore, sets
WCS -- Fusion has a native framework via `onProbe`) from **tool-length probing**
(measure the tool at a setter, sets TLO). This post has neither cleanly -- it has
one Z-touch-plate cycle serving both jobs at once.

- **X/Y is never probed** -- always blind manual jog. `Zero XY` just declares
  "current position is 0,0," silently assuming the operator already jogged to
  the corner. That implicit manual step is load-bearing and invisible in the UI.
- **Z probing conflates part-top with tool-length reference** -- which is *why*
  you can never skip re-probing after a tool change.
- **The `G28` Marlin fallback** (endstop as reference) is a clever hack but
  conceptually muddy: an endstop standing in for a tool setter.

Recommendations:
- State the honest framing to users: this post does **work-Z probing only**;
  X/Y is manual; there is **no tool-length system**, so Z is re-established per
  tool.
- Level-up paths (optional): (a) consume Fusion's native probing operations
  (`onProbe`) -- the production path, large lift; or (b) add real TLO for
  firmware that supports it (`G43.1` on GRBL, `G10 L1` / tool offsets on RRF),
  which would break the "must re-probe every tool change" limitation.

## Tool-change assessment

Manual-only is correct (no ATC hardware). Two real problems, both tracing to the
missing MCS layer:

1. **Tool-change position is WCS-relative** (see the earlier open question) --
   production uses `G53`/`G30` precisely so the change spot is machine-fixed and
   always reachable. Genuine bug.
2. **Re-probe-after-change is the TLO substitute** -- correct given no tool
   setter, but it exposes the muddiness: this post probes "at current location,"
   whereas production probes at a *fixed* tool-setter location (machine coords).
   Without TLO or a fixed probe location, "re-establish the tip" has no
   well-defined reference in a multi-WCS job.

Also: the **bare `M6 Tn`** path (relocation assist off) is close to a no-op /
alarm on GRBL 1.1 and needs specific config on Marlin -- so that path can emit
gcode that stalls the controller. Worth a warning or firmware guard.

## The cross-cutting gap: there is no machine-coordinate story at all

Step back and the pattern is clear: the absence of any `G53`/MCS concept is the
shared root of at least three separate issues -- the WCS-relative tool-change
position, the end-of-job `X0 Y0` that traverses at whatever Z the last op left
(production retracts to `G53 Z0` *first*), and the inability to offer a
production-style "assume WCS already set" mode. One coherent machine-coordinate
layer resolves all three at once.

## Establishing the MCS: how to make G53 actually work

`G53` is meaningless until the controller knows where machine zero is, and the
only thing that establishes a reliable, repeatable machine zero is **homing**.
So "make G53 work" == "establish and trust an MCS" == "home the machine."

Homing is a **per-machine hardware capability, not a firmware property**. GRBL,
Marlin, and RRF all *can* home; whether a given build *can* depends on the
switches/probe fitted. So the post must not assume either way -- capability is
**operator-declared**, and G53 features activate or degrade from that.

**Three tiers, with graceful degradation:**
- **Tier A -- fully homeable** (e.g. X/Y endstops + Z endstop or Z-by-probe):
  home at job start -> MCS reliable across power cycles -> full G53
  (machine-fixed tool change, safe-Z retract, park). Can also reach the
  production "WCS already set, don't re-zero" workflow.
- **Tier B -- partial** (X/Y switches, no Z reference): home X/Y -> `G53 X/Y`
  trustworthy, `G53 Z` not. Tool-change position uses machine X/Y; Z stays
  relative / operator-handled.
- **Tier C -- no switches**: no reliable machine zero. `G53` references the
  power-on/reset position, consistent only with a "reset in the same corner"
  ritual. Honest default is today's WCS/`G92`-relative behavior + a comment that
  machine-fixed positioning requires homing.

**Homing cycle by firmware** (emit *first* at job start, before WCS
establishment, so machine zero exists before anything references it): GRBL/
FluidNC `$H`; Marlin `G28` (or `G28 X Y` for XY-only); RRF `G28`.

**Design shape:** a machine-capability declaration (homing type enum:
`None` / `XY only` / `XYZ (Z endstop)` / `XYZ (Z by probe)`, plus an optional
"home at job start" toggle). That one declaration drives whether the G53
features (and later the TLO layer) exist, and everything degrades cleanly to
current behavior when it is `None`.

**Convergence to exploit -- Z-by-probe homing IS tool-length setting.**
Establishing machine-Z by probing a *fixed* reference surface (bed/spoilboard,
or a fixed plate at a known location) is physically the same operation as
measuring tool length at a tool setter: both touch the current tool's tip to a
fixed point and record where. So a single fixed-location Z probe can solve
**both** the missing-MCS-Z problem and the missing-TLO problem (the one that
forces re-probing every tool change). This is the highest-value hardware
addition for the audience, and the post should be structured to exploit it when
present. Caveat that ties it together: a probed machine-Z is valid only for the
tool installed when probed -- change tools and it shifts by the length
difference, which is exactly why TLO exists and why re-probing substitutes for
it today.

**Practical gotcha -- machine coords are not work coords.** Post-homing, GRBL
commonly puts home at the max corner with the work envelope in *negative*
machine space (`G53 Z0` = top, work below); Marlin/RRF CNC configs often home to
min with positive work space. So asking users to type a tool-change position
"in machine coordinates" invites sign/origin-corner mistakes. Manage it by:
- **Leading with the unambiguous win:** `G53 Z<near-top>` for a **safe-Z retract
  before any traverse** is nearly sign-proof ("go to the top of the machine"),
  delivers the biggest safety payoff, and also fixes the end-of-job traverse
  gap. Do this one first.
- **For machine XY** (tool-change spot): label explicitly as machine
  coordinates, and consider "distance from home" semantics or `G30`/`G28`
  predefined-position return as a lower-ambiguity alternative to raw `G53`
  numbers.

**How it folds into the three-layer model:** MCS is Layer 1. Establishing it via
declared homing is the keystone -- it makes the `G53` tool-change fix *correct
rather than fragile*, enables the "assume WCS already set" repeatability mode
(Layer 2), and via the fixed Z-probe convergence opens a real TLO layer
(Layer 3).

## Implementation options for review: a "Machine" (MCS) dialog section

Concrete design for how the MCS would be declared and used, refined from a
per-axis proposal. Still for review, not committed.

### Critique of the starting proposals

- **"None" -> "Operator Established" (honest rename, with a firmware-specific
  caveat).** Good instinct -- there is always *some* machine frame, so "None" is
  misleading. But *which* frame an operator "zero" touches differs by firmware
  (see the next subsection). On GRBL/FluidNC/RRF an operator zero sets only the
  **work** frame, so it never hands the post a machine reference -- that comes
  from homing or the power-on position. On Marlin the picture is blurrier
  (single frame, no `G53`, plus a near-home `M428`), but the practical upshot is
  the same: a *repeatable* machine reference still comes from homing, not from
  an arbitrary jog-and-zero. So for MCS purposes this option means "assume
  power-on == machine zero (a ritual)" or "no usable MCS, stay work-relative" --
  label it so it doesn't imply the post is establishing a machine frame it
  can't.
- **Per-axis dropdowns (adopt over the single enum).** The LowRider-vs-MPCNC
  split is exactly why: Z establishment is genuinely heterogeneous per machine,
  and a single "homing type" enum cannot express "X=home, Y=home,
  Z=probe-to-bed." Per-axis is the honest model.

### What an operator "zero axis" actually does, per firmware (verified)

Correcting an over-broad earlier claim ("you can't reset the machine frame
without homing"). The real question is not *can* the operator zero an axis --
they can, on all three -- but *which frame* that zero affects, and whether it
gives the post's `G53` (or Marlin equivalent) a repeatable machine reference.

- **GRBL / FluidNC** -- hard machine/work split. Sender "zero X/Y/Z" buttons
  emit `G10 L20 P1` (persistent, survives power-cycle) or `G92` (temporary);
  both set the **work** offset. Machine position (`MPos`) is explicitly
  *unchanged*. Machine zero is established **only** by `$H` homing or the
  power-on position. So operator zeroing never gives the post a machine
  reference -- `G53` always resolves against the homed/power-on frame, not the
  operator's work-zero.
- **RepRapFirmware / Duet** -- same split. `G10 L2`/`L20` = workplace offset;
  machine frame from homing (`G28`). Operator zero = work frame.
- **Marlin (stock, no `CNC_COORDINATE_SYSTEMS` -- the post's target)** -- the
  blurry case, and the source of the "I zeroed XY on the panel" recollection:
  - `G53`-`G59` are **not compiled in** by default, so there is **no `G53`
    machine addressing at all** on the target config. Marlin effectively has
    **one** frame.
  - `G28` homing sets that native frame from endstops. *After* homing and before
    any `G92`, plain absolute `G0` moves are in the home-referenced native frame
    -- which *functions* as machine coordinates, addressed by plain `G0`, not
    `G53`.
  - `M428` ("Set Home Offsets" on the LCD) shifts the native frame to the
    current position -- **but only within ~2cm of home/zero**, so it is a
    fine-home-tune, not an arbitrary "set machine zero wherever I jogged."
  - `G92` (what a panel/sender "zero here" at an arbitrary spot uses) sets a
    **work** offset on top of the native frame; it does not move the native
    frame.
  - So the recalled "jog XY, zero, home Z" flow most likely sets a **work**
    origin for XY (`G92`) and homes Z -- a working reference that, on Marlin's
    single-frame model, doubles as the de-facto origin. Real and useful, but
    it's the work frame; it doesn't contradict GRBL/RRF.

**Design implications:**
- The post's machine-fixed features (tool-change position, safe-Z retract)
  need a *real* machine frame:
  - **GRBL/FluidNC/RRF**: only homing provides it; operator work-zeroing does
    not. The tier model above holds unchanged.
  - **Marlin**: there is no `G53` to emit. "Machine-fixed" positioning must use
    the homed native frame via plain absolute `G0` (accounting for any active
    `G92` work offset), or a `G28`-return -- a Marlin-specific code path, *not*
    `G53`. This is a real complication for any G53-based feature: it needs a
    separate Marlin implementation, or those features are simply
    GRBL/RRF-only with an honest "not available on Marlin" note.
- Net correction: "the operator can't set the machine frame" is accurate for
  GRBL/FluidNC/RRF. For Marlin it is technically wrong (`M428` shifts the native
  frame near home, and the single-frame model means the homed native frame *is*
  the working reference) -- but the practical conclusion still stands: a
  repeatable machine reference comes from **homing**, not from an arbitrary
  jog-and-zero.

### The two ways to establish an MCS (the entire basis)

On these firmwares there are exactly **two** ways to give an axis a machine
zero, and the dialog is built from that:

1. **Power-On** -- the controller adopts wherever the axis sits at power-on /
   reset as machine zero. No motion is emitted. Repeatable *only* if the
   operator parks at a consistent physical position before powering on (a
   ritual). This is the fallback for axes with no endstop.
2. **Home** -- the axis runs a homing cycle to a physical reference and sets
   machine zero there. The reference is whatever the firmware's homing config
   uses: a limit switch, or a plate/contact wired as the axis endstop. Emitted
   by the post as the firmware's home command. Repeatable and crash-recoverable;
   best practice wherever the hardware supports it.

That's the whole model. Everything below builds on this per-axis `Power-On` vs
`Home` choice.

**Key simplification (from an earlier over-complicated draft):** the post does
**not** need to know *how* an axis homes -- switch vs. plate, fixed vs. movable,
any plate-thickness offset. It emits the home command; the machine's firmware
homing config does the rest (including any plate-thickness offset baked into the
home position). So there is no plate-thickness field in the Machine group.

**The MPCNC Z-plate, pinned down.** Two different things use a plate, and they
must not be conflated:
- If the plate/contact is **wired as the Z endstop** and Z homing is configured,
  then "Home Z" is real machine homing (option 2) -- it establishes machine Z.
- If instead the movable plate is used with **`G38.2` as a work touch-off** (the
  common movable-plate case: place plate on the *part*, probe tool to it), that
  is **not** machine homing -- it is *work-Z* establishment and belongs to the
  WCS/Probe layer (`probeA_OnStart`), leaving Z's machine zero as `Power-On`.

So on the MCS layer Z is still just `Power-On` or `Home`; the movable-plate work
touch-off lives entirely in the WCS/Probe section, where plate thickness already
matters. This removes the double-probe worry from the earlier draft: MCS-Home
and work-Z probing are simply different operations in different layers.

### Verified against V1E docs/forums (LowRider vs MPCNC reality)

- **LowRider CNC (V4)** homes with **adjustable Z endstop switches** (Z homes up
  to the switches), plus X/Y endstops -- a fully switch-homed machine. Its touch
  plate is **optional and supplementary**, for setting *work-surface* zero,
  explicitly separate from homing. So LowRider: machine frame from switches
  (`Home` on all axes), optional work-Z plate probe on top.
- **Where the plate physically wires differs by controller, and it matters
  (verified from the build docs):**
  - **FluidNC (Jackpot board)**: the plate goes to a **dedicated probe port
    (gpio.36)**, separate from the limit/homing pins, reading active-high (LED
    lit *when triggered*, opposite the normally-closed limit switches). It is a
    **probe only** -- FluidNC keeps the probe pin architecturally separate from
    the axis limit pins that homing uses, so on a Jackpot the plate **cannot home
    Z**. Setting Z from it is always a `G38.2` **work-Z** touch-off.
  - **Marlin (SKR/Rambo dual-endstop)**: the plate goes to the **Z-min endstop
    pin** -- there is no separate probe header; the pin is *shared*. Via
    `Z_MIN_PROBE_USES_Z_MIN_ENDSTOP_PIN` that one pin does double duty: it can be
    a `G38.2` **work-Z probe** *and/or* the **Z homing endstop** (`G28 Z` homes
    to the plate, establishing the native/machine Z).
  - **Consequence:** the *same plate* can establish a machine/native Z on Marlin
    (home to it) but **cannot** on FluidNC (the probe pin has no homing role). So
    "plate as a homing reference" is **not** a weird exception -- on Marlin it is
    the natural shared-pin config; it is simply architecturally unavailable on
    FluidNC/Jackpot.
- **MPCNC** typically has **X/Y switches that may or may not be fitted** (often
  absent on simpler builds) and usually **no dedicated Z endstop switch**. So
  machine XY = `Home` *if* switches are fitted, else `Power-On`; work-Z is the
  plate probe. Machine **Z** then splits by firmware (below).
- **Machine Z on an MPCNC -- by firmware:**
  - **FluidNC/Jackpot**: the plate is probe-only, so there is **no way to
    establish machine Z** from it. Machine Z would need a separate Z limit switch
    on a limit pin. Without one, machine Z falls back to power-on -- which is
    useless (next point) -- so effectively **no usable machine Z**.
  - **Marlin**: if the plate is configured as the Z endstop
    (`Z_MIN_PROBE_USES_Z_MIN_ENDSTOP_PIN`), `G28 Z` homes to it and **does**
    establish a native/machine Z. The plate is movable, so this needs an
    attach/remove pause. If instead the plate is used only as a `G38.2` probe,
    machine Z is again power-on / useless.
- **Power-on Z is effectively useless (the XY/Z asymmetry).** Power-on can only
  serve as a machine reference if the operator parks that axis at a repeatable
  physical spot before power-on. That is plausible for **XY** (jog to a marked
  corner or hard stop) but **not for Z** -- the router's Z is left wherever the
  last job ended, and nobody cranks Z to a fixed height every power-on. So where
  Z can't home (FluidNC MPCNC, or a Marlin MPCNC with the plate used only as a
  probe), there is **no usable machine Z**, and machine-**Z** features (`G53`
  safe-Z retract, tool-change Z in machine coords) must degrade to **relative /
  work-Z** moves -- which is what the post does today (`rapidMovementsZ` to a
  work-relative safe height). Machine **XY** features can still work when X/Y
  switches are fitted.
- **Tool changes re-probe Z per tool** (the Z reference shifts with tool length)
  -- confirmed community practice, and the reason the re-probe substitutes for a
  tool-length-offset system.

**Consequence for pauses:** the "attach plate / remove plate" prompts belong to
the **work-Z plate probe** (`G38.2`), which the post *already* does in
`probeTool()` (`askUser("Attach ZProbe")` / `askUser("Detach ZProbe")`).
Automatic *switch* homing (`Home`) needs **no** pause. The case where machine
`Home` **does** need those pauses is the **Marlin plate-as-Z-endstop** config
(`Z_MIN_PROBE_USES_Z_MIN_ENDSTOP_PIN`): `G28 Z` homes to the movable plate, so
the operator must place it first -- which is exactly what
`machine3_PromptBeforeHome` covers. (On FluidNC this case can't arise -- the
probe pin can't home.) So: real *switch* `Home` = silent cycle; Marlin
plate-home = guided with pauses; and the work-Z plate probe keeps its existing
pauses regardless.

### Firmware mechanics (verified) -- homing and machine-referenced moves

- **Per-axis homing:** FluidNC has it built in (`$HX`/`$HY`/`$HZ`, per-axis
  `allow_single_axis: true`). Stock GRBL 1.1 does **not** -- `$H` homes all
  configured axes (per-axis needs a compile-time flag, off by default; default
  order Z-up first, then X/Y). Marlin/RRF support `G28 X`/`G28 Y`/`G28 Z`
  subsets. So per-axis *intent* maps cleanly to FluidNC/Marlin/RRF; on stock
  GRBL the post emits all-axis `$H` and warns if the per-axis choices don't
  match what `$H` will actually do.
- **Machine-referenced moves, by firmware** (this is what "Home vs Power-On"
  ultimately feeds):
  - **GRBL/FluidNC**: `G53` works whether the frame came from homing *or*
    power-on (it just references whichever). Power-On is fully functional, only
    less reliable -- warn, don't block.
  - **Marlin**: no `G53` on the target config. Machine-referenced moves use the
    homed native frame via plain absolute `G0` (minus any active `G92`), or a
    `G28`-return. Works after `G28` or from the power-on position.
  - **RRF**: typically **refuses motion on un-homed axes** ("insufficient axes
    homed"), so on RRF a machine-referenced move effectively *requires* that
    axis to be `Home` -- Power-On alone may not permit it. This is a real
    per-firmware gate to honor.

### Proposed group: "0 - Machine" (sorts first; homing is the first physical act)

Per-axis, each declaring how that axis's machine zero is established, defaulting
to the safe no-motion choice:

- `machine0_HomeX`: `Power-On` | `Home`   (default `Power-On`)
- `machine1_HomeY`: `Power-On` | `Home`   (default `Power-On`)
- `machine2_HomeZ`: `Power-On` | `Home`   (default `Power-On`)

Likely one supporting option:
- `machine3_PromptBeforeHome` (bool, default false): pause (`askUser`) before
  homing so the operator can, e.g., place a Z touch-plate or clear the bed. Needed
  for machines whose homing reference isn't a permanently-installed switch.

Defaults are all `Power-On` so the post's out-of-box behavior emits **no homing
motion** -- a wrong homing command is a crash, so homing must be opt-in per axis
by someone who knows their machine is wired for it.

### Tooltips and GitHub docs (user-facing -- this is the point)

The whole feature is useless if operators can't tell which to pick. Draft copy:

- `machine2_HomeZ` tooltip: *"How Z machine-zero is set at job start. Power-On:
  Z zero is wherever the tool is when you power on / reset -- you must park Z at
  a known height first or machine-referenced Z moves (safe retract, tool change)
  will be wrong. Home: Z runs its homing cycle to its endstop (a limit switch,
  or a plate/contact wired as the Z endstop). Establishes a repeatable Z zero.
  Only choose Home if your machine actually has Z homing configured. NOTE: this
  is not the work-Z touch-off that sets your part origin -- that's under WCS /
  Probe."*
- X/Y tooltips: same shape, minus the touch-off note.
- GitHub README/docs section should cover: the Power-On ritual (park in the same
  corner every time) and its risk; that Home requires endstops wired + homing
  configured in the *firmware* (the post only triggers it); the GRBL
  all-axis-`$H` caveat; the RRF "un-homed axes refuse motion" behavior; and the
  explicit distinction between machine homing (this group) and work-Z touch-off
  (WCS/Probe group). Include a per-machine example matrix (LowRider / MPCNC /
  switch-less) mapping hardware to the recommended settings.

### What it emits at job start (isolated -- Phase 2)

- For each axis set to `Home`, emit the firmware-appropriate home command
  (`$H`/`$HX...` , `G28 X...`), optionally preceded by an `askUser` pause if
  `machine3_PromptBeforeHome`.
- For `Power-On` axes, emit nothing but a comment recording the assumption
  ("MCS X: assuming power-on position is machine zero").
- Emit a clear comment block documenting the resulting MCS state, so the gcode
  is self-describing at every comment level.
- Nothing else changes yet (see roadmap): tool change, retract, section
  transitions, and WCS logic stay exactly as they are until MCS is proven.

### Which machine-referenced features each choice later enables

Applies to the **optional** machine-referenced variants only -- the everyday
default is work-relative to the G54 base (see "The G54-base decision"). Where a
user opts into a machine-referenced move, reliability vs. availability differs by
firmware:
- **Optional machine-Z retract / machine-XY tool-change** become *reliable* when
  the relevant axes are `Home`. With `Power-On` they still function on
  GRBL/FluidNC/Marlin (referencing the power-on frame) but must warn about the
  parking ritual; on **RRF** an un-homed axis will refuse the move, so there they
  are effectively gated on `Home`.

### Target operator flows (the goal: effectively produce parts on V1E machines)

Grounded in the verified V1E reality above. These describe what each machine's
frame *can* support; the everyday default for safe-Z / tool-change is still
work-relative to the G54 base (see "The G54-base decision") -- "machine-
referenced" below means the optional robustness variant.

**LowRider -- X/Y + Z endstop switches (the standard build):** Home X/Y/Z at job
start (Z homes *up* to its switches) -> full machine frame -> safe-Z retract,
fixed tool-change position, and end-of-job park all machine-referenced.
Best-practice, most repeatable. Work-Z (part top) is set separately via the
optional plate probe in the WCS/Probe layer.

**MPCNC + FluidNC/Jackpot -- X/Y switches (if fitted), plate on the dedicated
probe pin:** `Home` X/Y if switches are fitted (else `Power-On`). Machine Z has
**no usable reference** -- the probe pin can't home, and power-on Z isn't
repeatable (XY/Z asymmetry above). Work Z is the plate probe (`G38.2`, with the
existing attach/remove pauses) in the WCS/Probe layer. Result: machine XY
features (fixed tool-change XY, XY park) work when switches are fitted; all
machine-**Z** behavior (safe retract, tool-change Z) stays **relative / work-Z**,
exactly as today; Z zeroing stays the plate probe.

**MPCNC + Marlin -- X/Y switches (if fitted), plate on the shared Z-min pin:**
`Home` X/Y if fitted. Z has a choice: (a) plate as a `G38.2` probe only -> same
as the FluidNC case (no machine Z, work-Z via probe); or (b) plate as the Z
endstop (`Z_MIN_PROBE_USES_Z_MIN_ENDSTOP_PIN`) -> `Home` Z homes to the plate and
**does** give a native/machine Z, but the movable plate needs an attach/remove
pause (`machine3_PromptBeforeHome`). Option (b) is the only way an MPCNC gets a
real machine Z without adding a separate switch.

**Switch-less MPCNC (either firmware):** all axes `Power-On`. Machine-referenced
features rely on the parking ritual (or are avoided); everything else stays
work/`G92`-relative, exactly as today, with a warning.

### Phased implementation roadmap

Deliberately incremental -- MCS is established and *verified* before any existing
behavior is rewired.

- **Phase 1 (done, committed):** WCS origin/probe rework to `G10 L20`.
- **Phase 2 (next -- establish MCS, in isolation):** add the "0 - Machine"
  group; emit homing (or the power-on comment) at job start; document the MCS
  state in comments; tooltips + GitHub docs. **Change nothing else.** Verify per
  firmware that the right home commands appear, power-on axes emit only a
  comment, and existing output is otherwise byte-for-byte unchanged.
  Note: Phase 2's homing establishes the machine **XY** frame (gantry squaring +
  a repeatable origin for resume). It is *not* the everyday Z reference -- that
  is the work-relative G54 base (Phase 3). See "The G54-base decision" section.
- **Phase 3 (spoilboard base + validation guards -- the everyday reference):**
  add the `wcsBase_Spoilboard` mode (Off / Establish at start / Assume already
  set); when non-Off, establish `G54` once as the spoilboard reference and treat
  it read-only. Add Guard A (error if any option would re-write `G54` after the
  base is set) and Guard B (error if a safe-Z feature is enabled in a multi-WCS
  job with no base declared). Verify the guards fire on the intended
  misconfigurations and stay silent on valid single-WCS jobs.
- **Phase 4 (consume the base -- each step separately verifiable, all
  work-relative in the active WCS / G54 base):**
  1. Job-start integration: sequence homing (Phase 2) -> spoilboard base
     establish (Phase 3) -> per-section WCS.
  2. Safe-Z retract before any traverse: an **absolute** clearance height in the
     active WCS / G54 base (clears the stock regardless of pocket depth).
     Machine-top (`G53 Z` / homed native) stays an *optional* extra-clearance
     mode for homed machines, not the default.
  3. Tool-change position: work-relative to the G54 base (fixed spoilboard
     reference), with a safe-Z retract first. `G53` machine-XY offered only as
     the optional robust variant where XY is homed.
  4. Tool-change Z re-establishment (tool-length / re-zero). NOTE for design:
     a new tool has a different length, so Z must be re-referenced after the
     swap. Without a tool-length-offset system (see Layer 3 / TLO), this means a
     full guided sequence: safe-Z retract -> travel to the probe point (a fixed
     tool-setter location if one exists, otherwise back over the work / a placed
     plate) -> probe Z (re-zero the work Z for the new tool) -> safe-Z retract ->
     travel to the next section's start. Every leg is collision-sensitive. This
     is the crux of making multi-tool jobs actually safe on V1E machines; treat
     it as its own sub-step, not a bolt-on to step 3.
  5. Inter-section moves: absolute safe-Z clearance (active WCS / base) before
     the XY traverse to the next section's start (collision avoidance).
  6. Inter-WCS moves: same retract-before-traverse when the WCS changes between
     sections -- the retract references the stable G54 base, not the shifting
     per-part WCS.
- **Phase 5 (likely no-op):** review the `G0`/`G1` (rapid-mapping) optimizations.
  Expected fine as-is: they operate **within a single section and a single WCS**,
  so there is no coordinate-frame transition and thus no cross-frame collision
  risk. Collisions happen at *transitions* (job start, tool change, between
  sections, on WCS change) -- which is exactly what Phase 4 covers -- not inside
  one continuous toolpath. Confirm, then leave alone.

### Open decisions for this design

- Whether `machine3_PromptBeforeHome` is one global toggle or per-axis (Z often
  needs it, X/Y with fixed switches don't).
- Homing emission order (Z-first-up to clear is normal; some MPCNC Z-to-plate
  setups need XY positioned or the plate placed first -- ties into the prompt).
- Optional machine-profile presets (LowRider / MPCNC / switch-less / custom)
  that pre-fill the per-axis defaults -- nicer UX, but added maintenance and
  another thing to keep in sync with firmware behavior.

## The G54-base decision + spoilboard base + validation guards

The pivotal design decision, replacing the earlier "tool-change should be `G53`"
conclusion. It came from a concrete crash class: if the post uses a *machine*-Z
reference on one machine (LowRider, Z0 at the top of travel, work envelope
negative below) but a *work*-Z reference on another (MPCNC, Z0 at the
spoilboard, positive up), then a single posted concept like "retract to Z30"
means "30 above the spoilboard" (safe) on one and "30 above the top of travel"
(out of range / crash) on the other.

### Decision

Standardize on a **work-relative, G54-base convention** as the everyday
reference, on every machine and firmware:

- `G54` is a **stable base zeroed to the spoilboard** (a *fixed* surface, so it
  is independent of stock thickness -- not the stock top).
- All everyday moves (safe-Z retract, tool-change position, inter-section and
  inter-WCS traverses) are **work-relative** to that base / the active WCS. Z0 =
  spoilboard, up = positive, identically everywhere -- the frame-mixing crash
  class disappears.
- Machine-referenced (`G53` / homed-native) positioning is **demoted to an
  optional robustness feature** for homed machines (e.g. an extra-clearance
  machine-top retract), never the default.
- An **absolute** work-Z clearance clears the stock as reliably as a machine-top
  retract (from any pocket depth), so nothing safety-critical is lost. A
  botched work-Z ruins the cut regardless, so machine-top's immunity to that is
  not a real safety argument for the audience.

Why this is right for V1E (not just a preference): it is the only reference that
works on the lowest-common-denominator machine (no-Z-home MPCNC/FluidNC), it
matches the GRBL ecosystem (Shapeoko/OpenBuilds/Onefinity all zero to work +
probe), it fits Marlin's single-frame/`G92` model with no `G53` needed, and it
*simplifies* the post (one frame, no machine-Z tiering on the everyday path).

### The property

In the WCS group, a mode (not a bare boolean -- "declare the base" and
"establish it now" are separable, and "probe once, run many jobs" is a real
workflow):

- `wcsBase_Spoilboard`: **Off** | **Establish at start (probe G54 to spoilboard)**
  | **Assume already set (G54 is the spoilboard base)**.

Establishing is mostly a **Z** operation (probe the spoilboard surface, write
`G54` Z via `writeWcsOrigin(1, …, thickness)` + the plate pauses); its **XY**
origin is the homed XY or a declared corner -- so a fully stable base (incl. a
fixed tool-change XY) depends on **homed XY** (ties back to the MCS group). On a
switch-less machine the base is Z-only and tool-change XY still has no fixed
reference.

### The two validation guards (post-time -- the post errors in Fusion, it cannot
check the controller's live state)

- **Guard A -- no redefine.** "Using" `G54` (selecting/cutting in it) is always
  fine; "redefining" it (the post emitting a *second* write to `G54`'s offset
  after the base establish) is the error. If `wcsBase_Spoilboard != Off` and any
  section's origin-establishment (`probeA_OnStart`/`probeB_OnChange` resolving to
  offset 1) would re-write `G54` -> **post error**: "G54 is reserved as the
  spoilboard base -- assign this operation's Work Offset to G55 or higher."
  Note the `0 -> default -> G54` collision: a Setup with an unset Work Offset
  resolves to `G54`, so the error text must call that out explicitly.
- **Guard B -- safe-Z needs a base, scoped to multi-WCS.** If a safe-Z-dependent
  feature (tool-change retract, inter-WCS safe move) is enabled **and** the job
  uses **more than one WCS** **and** `wcsBase_Spoilboard == Off` -> **post
  error**: "Safe-Z moves across WCS require a base; set 'Spoilboard base' to
  Establish or Assume." A **single-WCS** job is exempt -- its one part zero is a
  stable-enough reference for safe-Z on its own.

### Workflow conventions this encodes (must be documented for users)

- **Single-part job:** zero the active WCS to the part; safe-Z and tool-change
  are relative to that one zero. No separate base needed. The common case.
- **Multi-fixture job:** `G54` = fixed spoilboard base (set once, never moved);
  `G55+` = per-part offsets. If the operator instead re-zeroes `G54` per part,
  the base drifts -- Guard A catches the post-side symptom, but the convention
  itself must be taught in the docs.

## Pragmatic priorities for the V1E / hobby audience

This is a *value* ranking (what's worth doing); the *execution* order is the
phased roadmap above.

1. **Per-axis "Machine" (MCS) group** (Phase 2). Establishes the machine **XY**
   frame (gantry squaring + repeatable origin for resume). Ships first, in
   isolation, verified before anything else changes. Not the everyday Z
   reference.
2. **Spoilboard base (`G54`) + Guards A/B** (Phase 3). The everyday reference and
   the safety net that makes the work-relative model enforceable at post time.
3. **Work-relative safe-Z + tool-change position** (Phase 4). Absolute clearance
   in the active WCS / G54 base; `G53` machine-XY / machine-top only as optional
   robustness where homed.
4. **Name the model honestly in UI/docs**: "work-Z probing only, X/Y manual, no
   tool-length system -> Z re-probed per tool change," plus the single-part vs.
   multi-fixture base convention. Costs nothing, prevents wrong-mental-model
   crashes. Can land anytime.
5. **Marlin multi-WCS -> hard error**, not per-section warning. Independent of
   the above.
6. *(Optional, later)* Real TLO for RRF/GRBL to break the re-probe-every-change
   requirement -- best paired with the fixed Z-probe / tool-setter convergence.
7. *(Probably skip)* Consuming Fusion's native `onProbe` framework -- production-
   correct but overkill for this audience.
