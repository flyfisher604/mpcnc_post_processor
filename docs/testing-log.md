# Testing Log — MPCNC_v4.0_Beta1.cps

Observations from manually reviewing real Fusion 360-generated `.gcode` output (as opposed to
static code review). These are notes worth following up on, not necessarily confirmed bugs —
confirmed/fixed code defects live in [known-issues-v4.md](known-issues-v4.md).

## Open observations

- **Full-F360 G1→G0 restore run never exercised the "true" branch of `isSafeToRapid`.**
  Source: `2D Contour1.gcode` (single 2D contour, `Map: G1s -> G0 Rapids = true`, `Map: First G1 -> G0 Rapid = true`, SafeZ = Retract = 5mm).
  The whole toolpath stayed at Z ≤ 1mm, below the 5mm safe height, so every `isSafeToRapid` call
  at [MPCNC_v4.0_Beta1.cps:834](../MPCNC_v4.0_Beta1.cps#L834) correctly returned `false` (destination unsafe) —
  none of the `zConstant` / `zUp` / `zDown-with-curZSafe` true-branches at
  [MPCNC_v4.0_Beta1.cps:869-881](../MPCNC_v4.0_Beta1.cps#L869-L881) ever ran. Also confirmed
  `forceSectionToStartWithRapid` was already `false` by the time of the first `onLinear` (real
  `G0`s from F360 preceded it), so the "First G1 → G0" branch was a correct no-op too.
  **Follow-up needed:** generate a toolpath that has a horizontal link/transition move at or
  above the safe-Z height (e.g. multiple contours with a linking move at retract height) to
  actually validate the conversion logic, not just its conservative refusal.

- **Tapping's speed-feed synchronization commands are silently dropped, with no warning (unlike coolant).**
  Source: `Setup1.gcode` T8 tapping section ([Setup1.gcode:18438-18496](c:\Users\don_m\OneDrive\Documents\Hobbies\Coding\GCode\Setup1.gcode#L18438-L18496)),
  9/16-12 right-hand tap. F360 emits `COMMAND_ACTIVATE_SPEED_FEED_SYNCHRONIZATION` /
  `COMMAND_DEACTIVATE_SPEED_FEED_SYNCHRONIZATION` around the tap-in (`G1 Z-43.18 F1058`) and
  synchronized tap-out (`Z-12.7` at the reversed spindle direction) moves. `F1058` is exactly
  500 RPM × 2.117mm pitch — F360 assumes the controller performs real closed-loop spindle/feed
  sync for these moves.
  In `onCommand()` ([MPCNC_v4.0_Beta1.cps:1513-1571](../MPCNC_v4.0_Beta1.cps#L1513-L1571)), there
  is no `case` for either `COMMAND_ACTIVATE_SPEED_FEED_SYNCHRONIZATION` or
  `COMMAND_DEACTIVATE_SPEED_FEED_SYNCHRONIZATION` — they fall through with only the generic
  top-of-function id comment, emitting no G-code. That's the only thing that *can* be done
  (GRBL/Marlin on an MPCNC have no `G33`/rigid-tapping capability), so tapping only works with a
  floating/tension tap holder absorbing timing drift.
  The gap: unlike the coolant-channel mismatch, which explicitly warns
  (`>>> WARNING: No matching Coolant channel : Flood requested`), and unlike
  `COMMAND_LOCK_MULTI_AXIS`/`UNLOCK_MULTI_AXIS`/`BREAK_CONTROL`, which are explicit no-op `case`s
  acknowledging they're intentionally ignored, the speed-feed-sync commands aren't handled at all
  — silently. An operator could run a tapping op without a floating tap holder and get no
  indication from the post that real spindle sync isn't happening.
  **Follow-up needed:** add explicit no-op `case`s for both commands (for clarity/consistency with
  `LOCK_MULTI_AXIS` etc.), and consider a one-time `>>> WARNING` when a tapping operation is
  detected, noting that a floating/tension tap holder is required (needs approval before changing).

- **"3 - Map Rapids" properties have no tooltip warning that they shouldn't be enabled for a full F360 license.**
  Source: property review, prompted by the `2D Contour1.gcode` run in this log's first entry,
  which deliberately enabled these switches against full-F360 output "to exercise the code" —
  a scenario the properties' own descriptions don't warn against.
  `mapD_RestoreFirstRapids` ("First G1 -> G0 Rapid") and `mapE_RestoreRapids` ("Map: G1s -> G0
  Rapids"), defined at [MPCNC_v4.0_Beta1.cps:220-235](../MPCNC_v4.0_Beta1.cps#L220-L235), exist
  specifically to undo what F360 Personal/hobbyist edition does — downgrading all `G0` rapids to
  `G1` — per the comment at [MPCNC_v4.0_Beta1.cps:1294-1301](../MPCNC_v4.0_Beta1.cps#L1294-L1301)
  ("only required when F360 Personal edition is used"). Their descriptions ("Enable to ensure
  that the first move of a cut starts with a G0 Rapid." / "Enable to convert G1s to G0s Rapids
  when safe.") don't say this, so nothing in the Fusion 360 post dialog stops a full-license user
  from enabling them unnecessarily.
  **Follow-up needed:** add a note to both tooltips (and probably `mapG_AllowRapidZ`, which only
  matters when `mapE_RestoreRapids` is on) that they should be left off for a full (non-Personal)
  F360 license, since real `G0`s are already present and there's nothing for the switches to
  recover (needs approval before changing).

- **No safe clearance move at a work-offset (WCS) transition between sections.**
  Source: `Setups.gcode` (two Fusion Setups in one job), prompted by F360's own dialog:
  "Multiple setups with different WCS settings have been selected... Your post must be customized
  to handle your setup such that the tool is clear of parts and fixtures when moving between
  different work offsets." Confirmed in [Setups.gcode:18385-18403](c:\Users\don_m\OneDrive\Documents\Hobbies\Coding\GCode\Setups.gcode#L18385-L18403):
  Setup1's last op and Setup2's first op both use tool T171, so `toolChange()` (the only place
  that retracts to a configured safe position,
  [MPCNC_v4.0_Beta1.cps:2028-2030](../MPCNC_v4.0_Beta1.cps#L2028-L2030)) is skipped entirely
  ([MPCNC_v4.0_Beta1.cps:1183](../MPCNC_v4.0_Beta1.cps#L1183): only triggered on a tool number
  change). `writeWCS()` itself ([MPCNC_v4.0_Beta1.cps:1110-1139](../MPCNC_v4.0_Beta1.cps#L1110-L1139))
  never moves anything — selecting a different WCS doesn't move the machine, so the tool is left
  wherever the *previous* section's own final retract happened to put it (relative to the *old*
  WCS's Z zero), with no verification that position is clear of the *new* WCS's fixture/part.
  **Follow-up needed:** add a guaranteed retract-to-safe-height (and ideally move-away-in-XY)
  whenever `writeWCS()` is about to change the active offset, not just on a tool change (needs
  approval before changing).
  **Note:** `G53` (machine-coordinate rapid, supported on GRBL/RepRap — see the earlier "Is G53
  supported" discussion) may be a good mechanism for this. Autodesk's own official posts (e.g.
  Haas) solve exactly this class of problem with a shared `writeRetract()` function, driven by a
  "Safe Retracts" property (`G28`/`G53`/clearance-height options), called from `onSection()` at
  every section/WCS boundary — not just on tool change. Worth using as the template when this is
  implemented.

- **`writeWCS()` silently collapses a raw work offset of `0` into `1` (G54), masking a real
  difference F360 reported, with no debug/info visibility into the decision.**
  Source: `Setups.gcode` — F360's Operations panel screenshot showed Setup1's ops at Work Offset
  `#1` and Setup2's ops at Work Offset `#0`, confirmed as genuinely different in each Setup's
  dialog. That's exactly why no `G55` (or any second WCS-select line) ever appeared in the
  generated file: [MPCNC_v4.0_Beta1.cps:1112-1114](../MPCNC_v4.0_Beta1.cps#L1112-L1114) treats
  `workOffset == 0` as "unset" and defaults it to `1`, the same value Setup1 already had — so two
  sections F360 reported as different collapse to an identical `G54` selection, and there was no
  way to see that happening from the gcode alone (no comment logs the raw vs. resolved value).
  **Follow-up needed:** add `eComment.Debug`/`Info` logging in `writeWCS()` for the raw
  `section.getWorkOffset()` value, the resolved value after the `0→1` fallback, and whether the
  WCS-select line was actually written or skipped (matches the existing debug-comment style used
  in `isSafeToRapid`/`parseSafeZProperty`). Drafted but **not applied** — needs approval:
  ```diff
   function writeWCS(section) {
     var workOffset = section.getWorkOffset();
  +  writeComment(eComment.Debug, " writeWCS: raw workOffset: " + workOffset);
  +
     if (workOffset == 0) {
       workOffset = 1; // default to the first WCS (G54)
     }
  +  writeComment(eComment.Debug, " writeWCS: resolved workOffset: " + workOffset + " currentWorkOffset: " + currentWorkOffset);

     if (fw == eFirmware.MARLIN) {
       ...
     }

     // GRBL / RepRap: select the work coordinate system (only when it changes).
     if (workOffset == currentWorkOffset) {
  +    writeComment(eComment.Info, "   WCS unchanged, not re-selecting");
       return;
     }
     ...
  ```

- **The program's `G92`-based start-of-job origin, plus `writeWCS()` always emitting an explicit
  WCS-select, would defeat a "run the same gcode multiple times, switching WCS on the console
  between runs to mill repeat copies" workflow.**
  Source: discussion prompted by the `Setups.gcode`/multi-WCS review above.
  `job1_SetOriginOnStart` ("Zero Starting Location (G92)") emits `G92 X0 Y0 Z0` at start
  ([MPCNC_v4.0_Beta1.cps:1882-1886](../MPCNC_v4.0_Beta1.cps#L1882-L1886)) — an offset relative to
  wherever the tool physically is at that instant, not a lookup into a pre-stored fixture-offset
  table. With it **on** (as in every file reviewed so far), manually selecting a different WCS on
  the console before a re-run has no effect: the program's own `G92` immediately re-anchors the
  origin to the current tool position. With it turned **off**, that particular problem goes away,
  but `writeWCS()` would still unconditionally emit an explicit WCS-select line (defaulting to
  `G54` when unset, per the entry above) every run — overriding whatever WCS the operator picked
  on the console unless Fusion's assigned offset happens to match it. Turning `job1_SetOriginOnStart`
  off also removes today's self-zeroing safety net: the program would then fully trust whatever
  offset is already stored in the active WCS slot, with no validation — a real collision risk if
  that slot is stale or was never configured.
  Separately: F360 has its own native feature to automatically iterate the WCS across multiple
  copies of the same part within one job (seen in the Setup dialog) — likely the "correct" way to
  do this rather than fighting the post's current assumptions. User is building a dedicated test
  file for that feature; revisit this entry once that's reviewed.
  **Follow-up needed:** no action yet — pending the dedicated auto-iterate-WCS test file.

## Resolved

- **`probe4_UseHomeZ` ("Use Home Z (G28)") was silently ignored when firmware = GRBL, with no
  tooltip warning — renamed and fixed.**
  Source: comparing `2D Contour1.gcode` (Marlin-style, emitted `G28 Z`) against
  `T171 - Face1.gcode` (GRBL-style, emitted `G38.2 F30 Z-10` regardless of the property).
  The property was renamed `probe4_G382orG28` and its semantics were flipped: `true` (default) now
  probes with `G38.2`, `false` probes with `G28`, and the description explicitly notes "Grbl always
  uses G38.2 regardless of this setting" ([MPCNC_v4.0_Beta1.cps:334-341](../MPCNC_v4.0_Beta1.cps#L334-L341)).
  `probeTool()` ([MPCNC_v4.0_Beta1.cps:2087-2095](../MPCNC_v4.0_Beta1.cps#L2087-L2095)) updated to
  match the new semantics. Note the default flip is a real behavior change for Marlin/RepRap users
  upgrading from Beta 1 with default settings (previously defaulted to `G28`, now defaults to `G38.2`).
