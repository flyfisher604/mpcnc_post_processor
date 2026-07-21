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

Not implemented yet — needs a decision on the `G53` change before altering
behavior.

**Production-machine precedent** (confirms this isn't just a hunch): real CNCs
never tie tool-change position to a WCS. Fanuc uses `G30` (a second
reference-return position, defined as a fixed distance from machine zero via
parameters, set once at machine installation) specifically so tool-change
clearance is independent of whatever work offset is active. Haas uses `G53`
the same way, explicitly to establish "a consistent, safe location for tool
changes regardless of the active work offset." Both are machine-coordinate
mechanisms, never WCS-relative.

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
