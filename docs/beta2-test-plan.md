# Beta 2 Test Plan

Checklist of what changed between Beta 1 and Beta 2 (`MPCNC_v4.0_Beta1.cps` → `MPCNC_v4.0_Beta2.cps`)
that needs hands-on verification before release.

- [x] **Z-probe default flipped.** `probe4_G382orG28` (renamed from `probe4_UseHomeZ`) now defaults
      to `G38.2` instead of `G28` on Marlin/RepRap. Test: probe on Marlin/RepRap with default
      settings and confirm `G38.2` is emitted; set the property to `No` and confirm `G28` still
      works. GRBL should be unaffected either way (always `G38.2`). Verified working.
- [ ] **Tapping warning.** Run a tapping operation and confirm the new
      `>>> WARNING: Speed-feed synchronization...` comment appears on every
      activate/deactivate occurrence without corrupting the surrounding gcode.
- [x] **"Map Rapids" property group rename.** Confirm the renamed group heading
      ("3 - Map G1s to Rapids (disable when using full license)") displays correctly in the
      Fusion 360 post dialog, and that toggling those 4 properties still behaves exactly as before
      (no functional change intended — label only). Verified: all 4 properties share the group
      string and the post loads cleanly in Fusion after the rename.
- [x] **`wcsDefinitions` added.** Confirm the Fusion 360 Operations panel's Work Offset column now
      resolves/displays `G54` etc. for this post instead of the bare index. Confirm normal
      single- and multi-WCS jobs still post identical `G54`-`G59` output as before (no functional
      change intended). Watch for any unexpected new errors/warnings from Fusion related to work
      offsets. Verified working.
      - Finding: section work offset `1` resolves to `G54` as expected. Work offset `0` displays
        as unresolved (`#0`) instead of a friendly label, because `useZeroOffset: false` excludes
        0 from the `wcs` array.
      - Follow-up: try `useZeroOffset: true` in `wcsDefinitions` and see how it changes the
        Operations panel display for offset 0. Decide whether offset 0 should keep showing as an
        unresolved index, suppress WCS output entirely, or reset to machine coordinates.
- [ ] **`writeWCS()` debug/info logging.** With Comment Level = Debug and = Info, confirm the new
      comments appear, are correctly formatted (no literal `undefined`), and are fully suppressed
      at Off/Important levels.
      - Finding: the "WCS changed:" Info comment was being written after the G-code that selects
        the new WCS, instead of before it. Fixed: `writeWCS()` now computes and validates the
        offset code first, writes the Info comment, then emits the G-code.
      - Finding: in a 2-setup NC file (Setup1 wcs=1, Setup2 wcs=0 -> defaults to 1, unchanged from
        Setup1), Setup1's WCS selection produced an Info comment but Setup2's no-op did not — it
        only had a Debug-level "unchanged, not re-selecting" comment. Fixed: that comment is now
        emitted at Info level so both cases are visible without switching to Debug.
      - Open question: what workOffset `0` should mean is still under discussion (see
        `wcsDefinitions` item above) — currently it silently aliases to WCS 1 (G54).
      - Bug found (uncommitted fix): `writeFirstSection()` ran the origin-zero (`G92`) and
        startup-probe sequence *before* the first `writeWCS()`/`G54` call. Both `G92` and probing
        apply on top of whichever WCS is currently active on the controller — if a prior job left a
        different WCS selected, or the first section's work offset isn't 1, the zero/probe would
        land on the wrong WCS and be discarded once the real WCS got selected afterward. Fix:
        `writeWCS(currentSection)` now runs first thing in `writeFirstSection()`, before `Start()`/
        `gcodeStartFile` and the origin-zero/probe; `onSection()` skips the later redundant call for
        the first section. Needs verification: run a job whose first section uses a non-default WCS
        (or that follows a job that left a different WCS active) and confirm the probe/origin now
        lands under the correct `G54`+ selection.
      - Also reworded the "workOffset not specified" comment to "workOffset defaulted to" — Fusion's
        API can't distinguish "field left at default" from "explicitly set to the default", so 0
        always means "use WCS 1"; the old wording implied an unusual/error case that isn't accurate.
- [x] **File rename / install.** Confirm `MPCNC_v4.0_Beta2.cps` installs/selects cleanly as a
      personal post library file in Fusion 360, replacing the old Beta 1 entry. Verified: loads
      cleanly in Fusion.
- [ ] **Regression pass.** Re-run the existing sample jobs (`Test/*.gcode`) and confirm no output
      differences beyond the items above.

## Phase 2 — establish MCS (machine homing), from `docs/wcs-rework-plan.md`

- [x] **Default regression.** With `A_Machine_HomeX`/`B_Machine_HomeY`/`C_Machine_HomeZ` all
      left at `Power-On` (the default), confirm output is byte-for-byte identical to the pre-Phase-2
      baseline — no new G-code, and no new comments at the default Comment Level (`Info`).
      Verified: default-settings output is byte-for-byte identical to the pre-Phase-2 baseline.
- [x] **Marlin, Z homed + prompt.** Set `C_Machine_HomeZ = Home` and `D_Machine_PromptBeforeHome
      = On` on Marlin: confirm the attach-plate pause (`askUser`) fires immediately before `G28 Z`,
      and that X/Y (left `Power-On`) emit no motion. Verified: prompt fires immediately before
      `G28 Z`, X/Y emit no motion.
- [x] **GRBL/FluidNC, combined `$H`.** Set `A_Machine_HomeX = Home`, `C_Machine_HomeZ = Power-On`
      on GRBL: confirm exactly **one** `$H` is emitted (not per-axis), and that Comment Level =
      Debug shows which axes were asserted wired. Verified: exactly one `$H` emitted; Debug
      comments show the per-axis assertions.
- [x] **RRF, independent `G28`.** Set `A_Machine_HomeX = Home` only on RepRap: confirm `G28 X`
      fires alone, Y/Z left untouched, and the Z-home prompt never fires on RRF even if
      `D_Machine_PromptBeforeHome` is on (Marlin-only pause). Verified: `G28 X` fires alone, Y/Z
      untouched, no prompt on RRF.
- [x] **Prompt scoping.** Confirm `D_Machine_PromptBeforeHome` has no effect for X/Y homing, for
      GRBL/FluidNC `$H`, or for RRF `G28 Z` — only Marlin `G28 Z` triggers the pause. Verified:
      pause fires only for Marlin `G28 Z`; no effect for X/Y, GRBL `$H`, or RRF.
- [x] **Property naming / dialog order.** Confirm the new `<ItemLetter>_<Group>_<Name>` keys
      (e.g. `A_Job_SelectedFirmware`, `A_Machine_HomeX`) list in the intended order within each
      group, and that the zero-padded group headers (`01 - Job` … `10 - Duet`) list in numeric
      order — in particular that `10 - Duet` sorts **last**, not next to `01 - Job`. Also confirm
      every group still appears (renaming keys must not change values — settings from a Beta 2
      pre-rename post may reset to defaults, verify). Verified: groups and within-group properties
      list in the intended order in the Fusion post dialog.

## Phase 3 — reserved spoilboard base + validation guards, from `docs/wcs-rework-plan.md`

- [x] **Default regression (base None).** With `A_Probe_BaseReserve = None` (the default),
      confirm output is byte-for-byte identical to the Phase-2 baseline — no base probe, no
      base comments at the default Comment Level (`Info`). (`validateJob()` and
      `writeBaseEstablish()` early-return; only a suppressed Debug comment is emitted.)
      Verified: default (base None) output is byte-for-byte identical to the Phase-2 baseline.
- [x] **Base establish (GRBL/RepRap).** Set `A_Probe_BaseReserve = G59`,
      `B_Probe_BaseEstablish = On`, parts on `G54`: confirm a spoilboard probe fires at job
      start (attach ZProbe / `G38.2` / `G10 L20 P6 Z<thickness>` / detach) **before** the first
      section's own origin/probe, and that `G54` work still probes separately. Verified on GRBL:
      base probe writes `G10 L20 P6 Z0.8` before the `G54` (`P1`) XY-zero + Z-probe.
- [x] **Base establish OFF (assume prior).** Same but `B_Probe_BaseEstablish = Off`: confirm
      no base probe, and an Info comment (assuming the base is already established) is emitted
      instead. Verified: no probe; comment shown. Wording broadened to cover the manual-set case
      and de-parenthesized so `writeComment()` no longer mangles it: now
      `assuming base G59 is already established -- from a prior job or set manually`.
- [x] **Guard A (no base redefine).** Reserve `G59` and assign a milling operation's Setup to
      `G59` with `C_Probe_OnStart` (or `D_Probe_OnChange` / `H_ToolChange_ProbeAfterChange`)
      active: confirm the post errors with *"G59 is reserved as the spoilboard base — assign this
      operation to another WCS …"* and names the triggering feature. Verified: post aborts in
      `onOpen()` with *"G59 is reserved as the spoilboard base -- assign this operation to another
      WCS (would be re-established by: Probe at Job Start)."* — no G-code emitted.
- [x] **Guard C (Marlin multi-WCS).** On Marlin, post a job whose Setups use 2+ distinct work
      offsets: confirm the hard error *"Marlin has a single coordinate frame …"*. A single-WCS
      Marlin job posts unchanged. Verified: post aborts in `onOpen()` with *"Marlin has a single
      coordinate frame -- this multi-WCS job cannot be posted; use one work offset."* (the
      accompanying *"Multiple work offsets used in program"* is Fusion's own warning, not ours).
- [x] **RepRap-only base on GRBL.** Set `A_Probe_BaseReserve = G59.1` on GRBL: confirm the error
      *"Reserved base G59.1 requires RepRap …"*. On RepRap it is accepted. Verified on GRBL: post
      aborts with *"Reserved base G59.1 requires RepRap (GRBL supports G54-G59 only)."*
- [x] **Base ignored on Marlin.** Reserve a base on Marlin (single-WCS job): confirm the base
      probe is skipped and a warning comment notes the base is ignored on Marlin. Verified: no base
      probe on Marlin. Also fixed a pre-existing parens-mangling bug in the two Marlin `writeWCS()`
      warnings (`writeComment()` strips `()`): now `work offset 6/G59 …` instead of the mangled
      `work offset 6  G59 `.
- [x] **Guards silent on valid job.** Single-WCS job, no base reserved, on GRBL/RepRap: confirm
      no new errors or warnings. Verified in the stronger form — a GRBL job with base `G59`
      reserved (establish on) and the section on `G54`: posted fully, Guard A correctly stayed
      silent (using a WCS other than the base is fine), Guard C N/A. The no-base-reserved silent
      case is covered by the Default regression (base None) item above. (The lone coolant Flood
      warning is unrelated pre-existing behavior.)

## Phase 4 — consume the base (re-probe / safe-Z / traverses), from `docs/wcs-rework-plan.md`

Partial phase. Landed and testable: Guard B, the added-part re-probe repositioning, and the
WCS/Probe property relabels + default flip. **Not yet built** (so not testable): the
base-relative traverse retract that would consume `Cross Part Clearance` — that property and
the `Safe Z Retract Across WCS` *motion* do nothing yet; the toggle currently only drives
Guard B. See the "Not yet implemented" item at the end.

- [x] **Guard B (safe-Z across WCS needs a base).** On GRBL, a 2-WCS job (`G54`+`G55`):
      - `WCS for Spoilboard = None`, `Safe Z Retract Across WCS = On` (default) → post errors
        *"Safe-Z across WCS requires a base: reserve a spoilboard base … or turn off Safe Z
        Retract Across WCS."* (1a). Verified.
      - Same, toggle `Off` → posts, no Guard B error (1b). Verified.
      - Same, base reserved `G59` → posts (1c). Verified.
      - Single-WCS job, `None`, `On` → posts (single-WCS exempt) (1d). Verified.
      - Marlin, 2 WCS → Guard C fires first, not Guard B (1e). Verified.
- [x] **Added-part re-probe repositions before probing.** GRBL Replicate job, two copies on
      `G54`/`G55`, same tool, `Each Added Part: Re-probe Z = Probe Z per added part` (the new
      default). At the `G54→G55` boundary the post must retract, select `G55`, rapid to the new
      part origin (`X0 Y0`), then probe. Verified in `Test2.gcode` (2a): the emitted order is
      `Z<SafeZ>` retract → `G55` → `X0 Y0` → `G38.2` → `G10 L20 P2 Z`. Previously it probed at
      the *previous* part's end position (bogus Z into the new offset).
- [x] **First-part probe unchanged.** In the same job the first section (`G54`,
      `First Part: Set Work Origin = Zero XY, probe Z`) sets XY in place (`G10 L20 P1 X0 Y0`, a
      register write) and probes at the parked position — no `X0 Y0` rapid before the probe (2b).
      Verified.
- [x] **WCS/Probe relabels + default flip + group rename.** Dialog shows `First Part: Set Work
      Origin`, `Each Added Part: Re-probe Z` (default `Probe Z per added part`), `Safe Z Retract
      Across WCS`, `Cross Part Clearance (above spoilboard)`, and group `02 - Establish Machine
      Coordinates` (Test 3). Verified. No enum ids or property keys changed, so existing presets
      keep working — labels/defaults only.
- [x] **Base-relative re-probe retract (transit through the spoilboard base).** GRBL, base `G59`
      reserved, `Safe Z Retract Across WCS` on, two copies on `G54`/`G55`: at the `G54→G55`
      boundary the post transits through the base and clears to Cross Part Clearance before
      re-probing. Verified in `Setup1 Multi.gcode` (Debug on): `retract decision -- baseRelative:
      true base: 6 J_SafeZAcrossWcs: true` → `( Retract to spoilboard-base clearance G59 …)` →
      `G59` → `Z40` → `G55` → `X0 Y0` → `G38.2` → `G10 L20 P2 Z`. With the toggle off (or no base)
      it falls back to Safe Z in the outgoing frame.
- [x] **Single-WCS regression (byte-identical) — OMITTED (not run, per decision).** Rationale:
      single-WCS paths are unchanged by inspection — the new `writeWCS` branch requires a genuine
      WCS change, Guard B early-returns on a single offset, and the new properties emit nothing.
- [ ] **Not yet implemented — do not test yet.** These plan items have no code, so they will
      show no new behavior:
      - Safe-Z retract on inter-part traverses that do NOT re-probe (the re-probe path already
        transits the base — see the verified item above). This is the "retract on every traverse"
        case; it must reconcile with the re-probe retract so a boundary that does both isn't
        retracted twice.
      - Tool-change position work-relative to the base.
      - Tool-change re-probe ordering fix (`toolChange()` still runs before `writeWCS()`).
      - Probe XY offset applied at every part probe (first + added).
