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
