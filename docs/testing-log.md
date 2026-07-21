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

- **Using WCS `0` and `1` together in the same design is a latent human-factors risk, even though
  the code now handles it correctly and visibly.**
  Source: follow-on consideration while resolving the `writeWCS()` logging entry below, using the
  same `Setups.gcode` case (Setup1=`1`, Setup2=`0`) that started this whole WCS investigation.
  Both `0` and `1` alias to `G54` (confirmed via Autodesk's official offset table and the user's
  own live Fusion test: `0`→`G54`, `1`→`G54`, `2`→`G55`). Using **either one alone**, consistently,
  throughout a design is fine — every section resolves to the same `G54`, no ambiguity. The risk is
  specifically when a design *mixes* them across Setups/operations, exactly like `Setups.gcode` did:
  to a human reading Fusion's Operations panel or Post Process tab, `0` and `1` look like two
  different deliberate choices — reinforced by F360's own "multiple setups with different WCS
  settings" dialog, which fires on exactly this case — when operationally they are identical. An
  operator could reasonably but wrongly conclude the two Setups are meant to reference two separate
  physical fixture offsets and prep hardware accordingly, when the generated gcode will actually
  select `G54` for both. The new debug/info logging (below) makes this visible *inside the
  generated file* after the fact, but nothing currently surfaces it at the point where a human is
  making the physical setup decision, before gcode is even generated.
  **Follow-up needed:** no code fix intended right now — flagged for future review only. Possible
  directions if revisited: a `>>> WARNING` when a job mixes both `0` and `1` across sections despite
  them resolving identically, or documentation guidance recommending users standardize on an
  explicit `1` rather than leaving some Setups at the default `0`.

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

- **Post is missing a `wcsDefinitions` declaration, so Fusion's own UI can't resolve/display raw
  work-offset indices as G-code before posting.**
  Source: user confirmed live in the Fusion 360 NC Program editor — with Haas selected as the
  post, the Operations tab's Work Offset column showed `G54`/`G54`/`G55` for a Setup edited to
  `0`/`1`/`2` respectively; with our post selected (same unchanged Setup), the same column just
  showed the raw index (`0`). `wcsDefinitions` is a real, documented top-level global (confirmed
  in Autodesk's official Haas post source) that a post declares — alongside globals we *do*
  already have like `capabilities`, `tolerance`, `maximumCircularSweep`, `allowHelicalMoves`,
  `allowedCircularPlanes` ([MPCNC_v4.0_Beta1.cps:26-36](../MPCNC_v4.0_Beta1.cps#L26-L36)) — purely
  so Fusion's *own UI* can resolve/validate/display work-offset indices, independent of and prior
  to actually posting. We don't declare it at all, so Fusion has nothing to resolve the index
  against and falls back to showing the bare number. This is a UI/pre-post-visibility gap only —
  `writeWCS()` already resolves the same values correctly at actual posting time.
  Haas's declaration, for reference:
  ```javascript
  wcsDefinitions = {
    useZeroOffset: false,
    wcs          : [
      {name:"Standard", format:"G", range:[54, 59]},
      {name:"Extended", format:"G154 P", range:[1, 99]}
    ]
  };
  ```
  **Follow-up needed:** draft a `wcsDefinitions` matching what `writeWCS()` actually supports —
  not applied, needs approval and (ideally) live verification in Fusion since neither of us can
  confirm rendering without posting:
  ```javascript
  wcsDefinitions = {
    useZeroOffset: true,  // matches writeWCS(): raw offset 0 silently aliases to WCS 1 (G54)
    wcs          : [
      {name:"Standard", format:"G", range:[54, 59]},        // GRBL/RepRap: G54-G59 (raw 1-6)
      {name:"Extended", format:"G59.", range:[1, 3]}         // RepRap only: G59.1-G59.3 (raw 7-9)
    ]
  };
  ```
  Open question: this is a single static declaration, but the post supports 3 firmwares behind one
  property (Marlin has no G54-G59 at all — `writeWCS()` only warns there). Unclear whether/how a
  static `wcsDefinitions` can or should vary by the firmware property, or whether declaring the
  GRBL/RepRap scheme unconditionally (and continuing to rely on Marlin's existing runtime warning
  comment for that case) is an acceptable simplification.
  **Correction/update after further research:** `wcsDefinitions` does **not** appear in Autodesk's
  official, complete `PostProcessor` class attribute list (confirmed by fetching the full ~300-entry
  list directly — every other global we already declare, like `capabilities`/`tolerance`/
  `certificationLevel`, is on it; `wcsDefinitions` is not). Initially read that as "maybe not a real
  kernel feature." But the companion `Section` class reference settles it the other way: `Section`
  has `getWCS()`, `getWCSIndex()`, `getWCSOrigin()`, `getWCSPlane()`, `getWCSPosition()`,
  `getDynamicWCSOrigin/Plane()`, plus attributes `wcs`, `wcsOrigin`, `wcsPlane`, `wcsIndex` — and
  `getWCS()`'s own documented text is *"Returns the WCS code string. If there is no WCS definition
  defined or the work offset is out of range, it will return an empty string"* (`getWCSIndex()`
  says the same, returning `-1` instead). So "a WCS definition" is a real, load-bearing, documented
  prerequisite that `Section` methods depend on — Autodesk's docs just never document the mechanism
  that defines it (presumably `wcsDefinitions` itself). That's a genuine gap in Autodesk's own
  documentation, not evidence the feature isn't real.
  **Practical implication we hadn't considered:** if `wcsDefinitions` were declared correctly, our
  own `writeWCS()` could potentially call `currentSection.getWCS()` (or `getWCSIndex()`) directly to
  get the properly formatted code string, instead of hand-computing `gFormat.format(53 + workOffset)`
  itself ([MPCNC_v4.0_Beta1.cps:1128-1132](../MPCNC_v4.0_Beta1.cps#L1128-L1132)) — potentially a real
  simplification, not just a cosmetic UI fix, and it would generalize the RepRap `G59.1`-`G59.3`
  case for free instead of our own hand-rolled arithmetic. Still unverified without live testing in
  Fusion — the drafted `wcsDefinitions` block above remains a starting point, not something to trust
  blindly.

- **Missing `permittedCommentChars` global — a possible kernel-level backstop for the
  comment-sanitization work already done in `known-issues-v4.md` #19/#24.**
  Source: comparing our globals ([MPCNC_v4.0_Beta1.cps:13-36](../MPCNC_v4.0_Beta1.cps#L13-L36))
  against a comparable, actively-maintained community GRBL post (OpenBuilds' Fusion 360
  post-processor), which declares `permittedCommentChars` alongside the same
  `capabilities`/`tolerance`/circular-move globals we already have. That global tells the Fusion
  post-processing kernel itself which characters are legal inside a comment; we have no
  equivalent, and instead rely entirely on our own hand-rolled `sanitizeMessageText()` (added for
  #19/#24) to strip unsafe characters from `sectionComment`/`tool.comment` before they reach
  `writeComment()`/`askUser()`/`display_text()`. Not confirmed whether declaring this would add a
  real second layer of protection or is purely cosmetic/informational on Fusion's side.
  **Follow-up needed:** research what `permittedCommentChars` actually enforces (kernel-side
  filtering vs. just documentation) before deciding whether it's worth adding on top of the
  existing `sanitizeMessageText()` fix.

- **Minor/cosmetic global-metadata gaps, lower priority.**
  Source: same OpenBuilds GRBL post comparison as above. That post also declares `vendorUrl`,
  `model`, `debugMode`, and `extension` (`"gcode"`, so Fusion defaults the save-dialog file
  extension) — none of which we declare. `capabilities` there also includes
  `CAPABILITY_INSPECTION`/`CAPABILITY_MACHINE_SIMULATION`, which we correctly omit since this post
  rejects probing/inspection operations (`isProbeOperation()` → `cycleNotSupported()`). No action
  needed on the capability omission; `extension` might be a small, genuine convenience win (default
  `.nc`/`.tap` vs. an explicit `.gcode`) worth a look sometime.

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

- **Tapping's speed-feed synchronization commands were silently dropped, with no warning (unlike
  coolant) — fixed.**
  Source: `Setup1.gcode` T8 tapping section, 9/16-12 right-hand tap; F360 emits
  `COMMAND_ACTIVATE_SPEED_FEED_SYNCHRONIZATION` / `COMMAND_DEACTIVATE_SPEED_FEED_SYNCHRONIZATION`
  around the tap-in and synchronized tap-out moves, assuming the controller performs real
  closed-loop spindle/feed sync — which Marlin/GRBL/RepRap have no capability to do (no `G33`).
  `onCommand()` ([MPCNC_v4.0_Beta1.cps:1558-1573](../MPCNC_v4.0_Beta1.cps#L1558-L1573)) now has
  explicit `case`s for both commands (no longer falling through silently), each emitting
  `>>> WARNING: Speed-feed synchronization (rigid tapping) is not supported; a floating/tension
  tap holder is required` — on every occurrence (not just once), so every affected move in the
  file is individually flagged for diagnosis, matching the coolant-mismatch warning precedent.

- **"3 - Map Rapids" properties had no tooltip warning that they shouldn't be enabled for a full
  F360 license — fixed.**
  Source: property review, prompted by the `2D Contour1.gcode` run's deliberate use of these
  switches against full-F360 output "to exercise the code" — a scenario the properties' own
  descriptions didn't warn against. `mapD_RestoreFirstRapids`, `mapE_RestoreRapids`, `mapF_SafeZ`,
  and `mapG_AllowRapidZ` exist specifically to undo what F360 Personal/hobbyist edition does
  (downgrading all `G0` rapids to `G1`) — not needed on a full license, where real `G0`s already
  exist. The property group heading ([MPCNC_v4.0_Beta1.cps:220-249](../MPCNC_v4.0_Beta1.cps#L220-L249))
  was renamed from `"3 - Map Rapids"` to `"3 - Map G1s to Rapids (disable on full license)"`, so
  the warning is visible directly in the Fusion 360 post dialog for all four properties at once.

- **`writeWCS()` silently collapsed a raw work offset of `0` into `1` (G54), masking a real
  difference F360 reported, with no debug/info visibility into the decision — fixed.**
  Source: `Setups.gcode` — F360's Operations panel screenshot showed Setup1's ops at Work Offset
  `#1` and Setup2's ops at Work Offset `#0`, confirmed as genuinely different in each Setup's
  dialog. That's exactly why no `G55` (or any second WCS-select line) ever appeared in the
  generated file: [MPCNC_v4.0_Beta1.cps:1112-1114 (pre-fix)](../MPCNC_v4.0_Beta1.cps) treated
  `workOffset == 0` as "unset" and defaulted it to `1`, the same value Setup1 already had — so two
  sections F360 reported as different collapsed to an identical `G54` selection, with no way to
  see that happening from the gcode alone.
  `writeWCS()` ([MPCNC_v4.0_Beta1.cps:1110-1141](../MPCNC_v4.0_Beta1.cps#L1110-L1141)) now logs: a
  `Debug` entry line (raw `workOffset` + prior `currentWorkOffset`, showing `"none"` instead of a
  literal `undefined` before the first section), a `Debug` note *only* when the `0→1` fallback
  actually fires, a `Debug` line when a section's offset is unchanged (skipped, not re-selected),
  and an `Info` line (`WCS changed: A -> B`) whenever a real `G54`-`G59` selection is actually
  written — placed after the write succeeds so the out-of-range `error()` path never falsely
  announces a change that didn't happen. Streamlined to avoid duplicating information: since
  `Debug` level already includes everything `Info` shows (`commentLevels.indexOf(level) <= ...` in
  `writeComment()`), lines that would have just repeated an `Info` line's own value (e.g. a
  standalone "resolved workOffset" line matching the entry line in the common non-zero case, or an
  "exit changed" line repeating the `Info` message's own target value) were dropped rather than
  kept as redundant `Debug` output.
  See the "Using WCS `0` and `1` together" entry above — this fix makes the `0`/`1` aliasing
  visible in the generated file, but doesn't address the underlying human-factors risk of a design
  mixing them in the first place.
