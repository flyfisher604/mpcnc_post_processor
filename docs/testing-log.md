# Testing Log — MPCNC Post Processor

Observations from manually reviewing real Fusion 360-generated `.gcode` output (as opposed to
static code review). These are notes worth following up on, not necessarily confirmed bugs —
confirmed/fixed code defects live in [known-issues-v4.md](known-issues-v4.md).

## Open observations

- **Full-F360 G1→G0 restore run never exercised the "true" branch of `isSafeToRapid`.**
  Source: `2D Contour1.gcode` (single 2D contour, `Map: G1s -> G0 Rapids = true`, `Map: First G1 -> G0 Rapid = true`, SafeZ = Retract = 5mm).
  The whole toolpath stayed at Z ≤ 1mm, below the 5mm safe height, so every `isSafeToRapid` call
  at [MPCNC_v4.0_Beta2.cps:834](../MPCNC_v4.0_Beta2.cps#L834) correctly returned `false` (destination unsafe) —
  none of the `zConstant` / `zUp` / `zDown-with-curZSafe` true-branches at
  [MPCNC_v4.0_Beta2.cps:869-881](../MPCNC_v4.0_Beta2.cps#L869-L881) ever ran. Also confirmed
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
  [MPCNC_v4.0_Beta2.cps:2028-2030](../MPCNC_v4.0_Beta2.cps#L2028-L2030)) is skipped entirely
  ([MPCNC_v4.0_Beta2.cps:1183](../MPCNC_v4.0_Beta2.cps#L1183): only triggered on a tool number
  change). `writeWCS()` itself ([MPCNC_v4.0_Beta2.cps:1110-1139](../MPCNC_v4.0_Beta2.cps#L1110-L1139))
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
  **Correction to the reference check, if this is ever implemented:** Fanuc's actual validation
  (quoted in the `wcsDefinitions` entry below) is narrower than it first looks —
  `getSection(0).workOffset == 0 && section.workOffset > 0` only ever compares each section against
  the *very first* section in the job. It's order-dependent: it catches "first section left at `0`,
  a later section explicitly numbered" (a common oversight — numbering later Setups but forgetting
  to number the first one), but it would **not** catch our own `Setups.gcode` case (Setup1=`1`
  explicit, Setup2=`0` default) — the reverse order — since `getSection(0).workOffset` there is `1`,
  not `0`, so the check never fires for any later section regardless of its value. Confirmed by
  re-reading the exact snippet: it's a fixed comparison against index `0`, not a general
  any-section-vs-any-other-section comparison.
  So if we implement our own equivalent someday, the correct rule for the risk we're actually
  flagging is broader than Fanuc's: **any section with `workOffset == 0` alongside any *other*
  section with a different explicit non-zero offset** should be flagged, regardless of which one
  comes first in the job — not just a check against section index `0`. Fanuc's version is a cheap
  heuristic for their most common real-world mistake, not a complete treatment of the ambiguity.

- **The program's `G92`-based start-of-job origin, plus `writeWCS()` always emitting an explicit
  WCS-select, would defeat a "run the same gcode multiple times, switching WCS on the console
  between runs to mill repeat copies" workflow.**
  Source: discussion prompted by the `Setups.gcode`/multi-WCS review above.
  `job1_SetOriginOnStart` ("Zero Starting Location (G92)") emits `G92 X0 Y0 Z0` at start
  ([MPCNC_v4.0_Beta2.cps:1882-1886](../MPCNC_v4.0_Beta2.cps#L1882-L1886)) — an offset relative to
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

- **Missing `permittedCommentChars` global — a possible kernel-level backstop for the
  comment-sanitization work already done in `known-issues-v4.md` #19/#24.**
  Source: comparing our globals ([MPCNC_v4.0_Beta2.cps:13-36](../MPCNC_v4.0_Beta2.cps#L13-L36))
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
  uses G38.2 regardless of this setting" ([MPCNC_v4.0_Beta2.cps:334-341](../MPCNC_v4.0_Beta2.cps#L334-L341)).
  `probeTool()` ([MPCNC_v4.0_Beta2.cps:2087-2095](../MPCNC_v4.0_Beta2.cps#L2087-L2095)) updated to
  match the new semantics. Note the default flip is a real behavior change for Marlin/RepRap users
  upgrading from Beta 1 with default settings (previously defaulted to `G28`, now defaults to `G38.2`).

- **Tapping's speed-feed synchronization commands were silently dropped, with no warning (unlike
  coolant) — fixed.**
  Source: `Setup1.gcode` T8 tapping section, 9/16-12 right-hand tap; F360 emits
  `COMMAND_ACTIVATE_SPEED_FEED_SYNCHRONIZATION` / `COMMAND_DEACTIVATE_SPEED_FEED_SYNCHRONIZATION`
  around the tap-in and synchronized tap-out moves, assuming the controller performs real
  closed-loop spindle/feed sync — which Marlin/GRBL/RepRap have no capability to do (no `G33`).
  `onCommand()` ([MPCNC_v4.0_Beta2.cps:1558-1573](../MPCNC_v4.0_Beta2.cps#L1558-L1573)) now has
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
  exist. The property group heading ([MPCNC_v4.0_Beta2.cps:220-249](../MPCNC_v4.0_Beta2.cps#L220-L249))
  was renamed from `"3 - Map Rapids"` to `"3 - Map G1s to Rapids (disable on full license)"`, so
  the warning is visible directly in the Fusion 360 post dialog for all four properties at once.

- **`writeWCS()` silently collapsed a raw work offset of `0` into `1` (G54), masking a real
  difference F360 reported, with no debug/info visibility into the decision — fixed.**
  Source: `Setups.gcode` — F360's Operations panel screenshot showed Setup1's ops at Work Offset
  `#1` and Setup2's ops at Work Offset `#0`, confirmed as genuinely different in each Setup's
  dialog. That's exactly why no `G55` (or any second WCS-select line) ever appeared in the
  generated file: [MPCNC_v4.0_Beta2.cps:1112-1114 (pre-fix)](../MPCNC_v4.0_Beta2.cps) treated
  `workOffset == 0` as "unset" and defaulted it to `1`, the same value Setup1 already had — so two
  sections F360 reported as different collapsed to an identical `G54` selection, with no way to
  see that happening from the gcode alone.
  `writeWCS()` ([MPCNC_v4.0_Beta2.cps:1110-1141](../MPCNC_v4.0_Beta2.cps#L1110-L1141)) now logs: a
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

- **Missing `wcsDefinitions` declaration — added, so Fusion's own UI can now resolve/display raw
  work-offset indices as G-code before posting.**
  Source: user confirmed live in the Fusion 360 NC Program editor — with Haas selected as the post,
  the Operations tab's Work Offset column showed `G54`/`G54`/`G55` for a Setup edited to `0`/`1`/`2`
  respectively; with our post selected (same unchanged Setup), the same column just showed the raw
  index (`0`). Added at [MPCNC_v4.0_Beta2.cps:37-49](../MPCNC_v4.0_Beta2.cps#L37-L49), alongside the
  other capability globals we already declare (`capabilities`, `tolerance`, `maximumCircularSweep`,
  `allowHelicalMoves`, `allowedCircularPlanes`):
  ```javascript
  wcsDefinitions = {
    useZeroOffset: false,
    wcs          : [
      {name:"GRBL/RepRap", format:"G", range:[54, 59]},   // G54-G59 (raw offset 1-6)
      {name:"RepRap only", format:"G59.", range:[1, 3]}    // G59.1-G59.3 (raw offset 7-9)
    ]
  };
  ```
  Confirmed real (not invented/legacy) via the `Section` class reference — `getWCS()`/`getWCSIndex()`
  explicitly depend on "a WCS definition" existing (see the earlier correction note in this log),
  even though `wcsDefinitions` itself is absent from Autodesk's own `PostProcessor` class attribute
  list — a genuine gap in Autodesk's documentation, not evidence it isn't real.
  **`useZeroOffset` — determined, per your request, before finalizing the value:** Fetched Fanuc's
  actual official post source, which contains this real validation code (in `validateCommonParameters()`,
  evidently a shared-library convention used by official multi-offset posts like Fanuc/Haas):
  ```javascript
  if (getSection(0).workOffset == 0 && section.workOffset > 0) {
    if (!(typeof wcsDefinitions != "undefined" && wcsDefinitions.useZeroOffset)) {
      error(localize("Using multiple work offsets is not possible if the initial work offset is 0."));
    }
  }
  ```
  So `useZeroOffset` specifically gates one scenario: *the first section's offset is `0` AND some
  later section has an explicit non-zero offset*. When `false` (Fanuc's and Haas's actual value —
  correcting the earlier assumption that Haas accepting `0`→`G54` implied `true`), that combination
  is a hard `error()`, refusing to post at all. When `true`, it's silently permitted. This is
  exactly the "Using WCS `0` and `1` together" ambiguity flagged above — professional posts treat it
  as an error worth blocking, not something to silently alias through. Note, though: this exact
  check is narrower than it looks (order-dependent, only compares against the very first section) —
  see the correction appended to that entry above before using this snippet as a template.
  **Why we declared `false` (not the originally-drafted `true`):** `true` would have been the wrong
  choice — it exists specifically to *waive* the safety check, and we have no reason to waive a
  check aimed at exactly the risk we already flagged as worth future review. `false` matches the
  ecosystem convention and doesn't misrepresent anything about our own validation.
  **Important caveat — this is likely inert for us right now:** `validateCommonParameters()` reads
  like post-script code from a shared include (`commonFunctions.cpi`-style), not a check Fusion's
  kernel runs automatically just because `wcsDefinitions` exists. We don't import that shared
  library, and `writeWCS()` has no equivalent check of its own — it still silently aliases `0`→`1`
  regardless of `useZeroOffset`'s value. So today, `useZeroOffset: false` is the *documented,
  correct* value to declare, but likely does **not** yet give us Fanuc/Haas's actual error-blocking
  behavior. Implementing that check ourselves (mirroring the snippet above inside `writeWCS()` or
  `onSection()`) is the natural next step if the "`0`/`1` mixed design" risk gets revisited — not
  done now, per your instruction to hold off on that fix.
