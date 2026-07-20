# Fusion 360 / Autodesk HSM Post-Processor Compliance Issues — MPCNC_v3.0_Beta3.cps

Findings from a review of the post against **Autodesk / Fusion 360 post-processor
functionality**, using the official Autodesk documentation (Post Processor Training Guide,
rev. 4/2/25; the `cam.autodesk.com/posts/reference/` class/entry-function references). This is a
**separate** pass from the general code-quality review in [known-issues-v4.md](known-issues-v4.md)
(findings #1–#26); it looks specifically at correctness against the Autodesk API and at
functionality that a compliant milling + jet post is expected to provide.

Legend: `[x]` fixed, `[ ]` open. All items are currently **open** (review/report only — no edits made).

Numbering uses an `F` prefix (F1, F2, …) to keep these distinct from the code-quality findings.

Context — the target is hobby firmware (Marlin / GRBL / RepRap-Duet), not an industrial
Fanuc/Haas control. Several industrial conventions (tool-length-offset tables, WCS fixtures) are
intentionally handled differently here (G92-based zeroing, manual tool changes with Z re-probe).
Where a "missing" feature is actually appropriate for the target firmware, it is called out as
**by design** rather than a defect.

---

## Breaking — produces wrong or no output

- [x] **F1 — `tolerance` is unset but is used by every arc-linearization path.** — [Line 27](../MPCNC_v3.0_Beta3.cps#L27), [`circular()`: 1858-1928](../MPCNC_v3.0_Beta3.cps#L1858-L1928). **Fixed** by uncommenting line 27 so `tolerance = spatial(0.002, MM);` is assigned. Original finding: `tolerance = spatial(0.002, MM)` was **commented out**, yet `circular()` calls `linearize(tolerance)` in several places. Per Autodesk docs `tolerance` is a kernel-consumed global the post **must** assign (in MM), with **no documented default** and no documented kernel initialization (the class reference lists it as a bare `Number` attribute — unlike `unit`, which the docs explicitly say the kernel populates). An unassigned global reads as `undefined`, so these calls become `linearize(undefined)`.

  **Verified — not injected by the environment:** Autodesk's own stock **GRBL** post and **Carbide3D (GRBL)** post (the closest official comparables to the MPCNC target) both assign `tolerance = spatial(0.002, MM);` in the header and call `linearize(tolerance)` in `onCircular` — the exact pattern this post uses, except the assignment is commented out here. No Autodesk stock post omits it. So the environment does **not** supply a usable default; the post must set it.

  **Severity is latent-but-real.** In the common 2.5D case with "Use Arcs" enabled, XY arcs are emitted directly as G2/G3 and `linearize()` is never reached — which is likely why this hasn't been widely noticed. It manifests in two concrete paths:
  1. **`job4_UseArcs = false`** → [lines 1859-1861](../MPCNC_v3.0_Beta3.cps#L1859-L1861) route **every** arc through `linearize(tolerance)` = `linearize(undefined)`. This is a normal user choice (senders/controllers that handle arcs poorly), so it's a live trigger.
  2. **Non-XY-plane arcs on Marlin** (default firmware) and full-circle/helical fallbacks → the `linearize(tolerance)` calls in [circular()](../MPCNC_v3.0_Beta3.cps#L1858-L1928) (e.g. the Marlin branch linearizes ZX/YZ arcs, [1904-1927](../MPCNC_v3.0_Beta3.cps#L1904-L1927)).

  **Fix:** restore `tolerance = spatial(0.002, MM);` (uncomment line 27). Autodesk: *"Specifies the tolerance used to linearize circular moves… This variable must be set in millimeters (MM)."*

  *Residual uncertainty (honest):* the exact behavior of `linearize(undefined)` — segment explosion vs. thrown error vs. silent pass-through — is **not** doc-confirmed; the Autodesk forum/KB pages that discuss the "built-in tolerance" 403-block automated fetching. What is confirmed is that assigning `tolerance` is required and universal in Autodesk's own posts.

- [x] **F2 — No canned-cycle handlers (`onCycle`/`onCyclePoint`/`onCycleEnd`) → drilling operations do not post.** — **Fixed** by adding an `onCyclePoint(x, y, z)` that calls `expandCyclePoint(x, y, z)`, decomposing every drilling/tapping/boring cycle into ordinary `G0/G1` moves through the existing `onRapid`/`onLinear`/`onDwell` paths (portable across Marlin/GRBL/RepRap; no native canned cycles emitted, per the firmware analysis below). Probe operations are guarded with `isProbeOperation()` → `cycleNotSupported()` so Fusion WCS-probing errors clearly instead of silently expanding into fake (non-G38) motion. Original finding: (absent from file). Autodesk docs: `onCyclePoint(x, y, z)` is *"the controlling function for drilling, probing, and inspection cycles,"* and there is **no automatic linearization if `onCyclePoint` is entirely absent** — a drilling/tapping/boring/probing operation will produce no drilling motion or error out. Today, any Drilling operation in Fusion will fail against this post.

  **Fix must be expansion-only — do NOT emit native G81/G82/G83 for these firmwares** (verified against firmware docs):
  - **GRBL v1.1** does not support canned cycles at all — only `G80` (cancel) exists in its modal group; `G81/G82/G83` are unimplemented.
  - **Marlin** supports `G81/G82/G83` *only* in a non-default custom build compiled with `CNC_DRILLING_CYCLE`, and with non-Fanuc parameter semantics (`L` repeat, `Q` peck). A post can't assume a user's build has it.
  - **RepRap/Duet (RRF)** reuses `G81/G82/G83` for entirely different 3D-printer functions (mesh bed compensation / Z-probe / babystepping) — emitting a drilling `G81` to a Duet would be **misinterpreted as an unrelated command (a hazard)**, not merely ignored.

  So the correct, portable fix is: implement `onCyclePoint`/`onCycle`/`onCycleEnd` where `onCyclePoint` calls the built-in **`expandCyclePoint(x, y, z)`** to decompose every cycle into ordinary `G0/G1` plunge-and-retract moves (identical behavior on all three firmwares). Native canned-cycle output should **not** be added. Note: expanded tapping/boring also rely on `onCommand` support for `COMMAND_SPINDLE_CLOCKWISE/COUNTERCLOCKWISE`/`COMMAND_STOP_SPINDLE` (already handled by this post).

---

## Correctness / safety risks

- [x] **F3 — `rapidMovements()` outputs Z before XY, contrary to the documented safe initial-positioning order.** — [`rapidMovements`](../MPCNC_v3.0_Beta3.cps#L1655-L1667). The function emitted `rapidMovementsZ(_z)` **then** `rapidMovementsXY(_x, _y)` unconditionally. For any combined rapid where Z descends while XY moves (e.g. a diagonal approach the kernel hands to `onRapid` as a single X/Y/Z move), moving **Z first** plunged the tool at the *current* XY before it travelled to position — a collision/plunge-into-fixture risk. Autodesk's canonical safe-start sequence is the opposite: **rapid XY above the part first, then bring Z down**. **Fixed** by ordering the two split moves on Z direction: when `_z < getCurrentPosition().z` (descending) do XY first then Z; otherwise (rising/unchanged — i.e. retract) keep Z first then XY. Handles the section-start edge case safely too (when current == destination Z, it takes the Z-first branch, unchanged from before).

- [x] **F4 — A non-default Work Coordinate System set in Fusion was silently ignored.** — Original: no `getWorkOffset` usage; the only WCS output was a hardcoded `G54` in the `toolChange1_InsertCode == false` branch — emitted for *all* firmwares including stock Marlin, which doesn't understand G54. With tool changes disabled (the default), the post emitted **no** work-offset code at all, so a Fusion setup assigning WCS 2+ (G55…) was silently posted against the single G92 origin.

  **Fixed** by adding a firmware-aware `writeWCS(section)` (reads `currentSection.getWorkOffset()`), called per-section in `onSection`, and removing the firmware-blind hardcoded `G54` from `toolChange`:
  - **GRBL** — emits `G54`–`G59` (offsets 1–6); offsets >6 `error()` (GRBL has no extended WCS).
  - **RepRap/Duet** — emits `G54`–`G59` and `G59.1`–`G59.3` (offsets 1–9).
  - **Marlin** — keeps the existing `G92` origin ([`job1_SetOriginOnStart`](../MPCNC_v3.0_Beta3.cps#L1811-L1814)); emits **no** G5x (stock Marlin has none) and issues a warning comment when a non-default WCS (offset >1) is selected, since it can't be honored. This also removed the pre-existing bug where the hardcoded `G54` was sent to stock Marlin.
  - `currentWorkOffset` tracks the last-emitted WCS to avoid re-emitting it every section (reset in `onOpen`).

  **Why not replace G92 with WCS everywhere (reviewed):** verified against firmware docs — GRBL and RepRap/Duet fully support G54–G59 (`G10 L2/L20`, EEPROM-persisted), but **stock Marlin has no WCS** (needs the opt-in `CNC_COORDINATE_SYSTEMS` build; and even then `G92`+`G54` interact buggily — Marlin issue #14743). Since Marlin is the default target, G92 must remain there; hence the hybrid (WCS where supported, G92+warning on Marlin).

  **Reviewed: can G92 be replaced by WCS (G54–G59) on these firmwares? No — keep G92.** Verified against firmware docs:
  - **GRBL v1.1** — full WCS support (G54–G59 modal group, `G10 L2/L20 P#`, persisted in EEPROM).
  - **RepRap/Duet (RRF)** — full WCS support (G53–G59.3, `G10 L2/L20`).
  - **Marlin (this post's DEFAULT firmware)** — **no WCS in stock builds**; G53/G54–G59.3 and `G10 L2/L20` exist only when compiled with the non-default `CNC_COORDINATE_SYSTEMS` flag. And even on builds that enable it, mixing `G92` with `G54` is buggy (Marlin issue #14743: `G54` + `G92 X0 Y0` also resets the G53 machine origin).

  G92 is the **only origin mechanism that works on all three firmwares out of the box**, and it fits the MPCNC no-homing "jog-to-corner-and-zero" workflow. Switching to WCS would break the default (Marlin) target, so G92 stays.

  **The actual defect** is therefore not "should emit WCS" but that a user who assigns a **non-default work offset** in Fusion (e.g. WCS 2 → G55 for a multi-fixture setup) has it silently dropped — every section runs at the single G92 origin. Single-WCS jobs (the common case) are fine; multi-WCS jobs are silently mis-posted. **Fix (recommended):** keep G92, but detect `currentSection.getWorkOffset() > 1` (a non-default WCS) and emit a `warning()`/`error()` so the user is told their multi-WCS intent isn't honored, instead of producing misleading output. Do **not** emit G54–G59 (unsafe on the default firmware).

- [x] **F5 — `onPassThrough` not implemented → Manual NC "Pass through" is silently dropped.** — Autodesk: when `onManualNC` is not defined, each Manual NC entry falls back to an individual handler; "Pass through" routes to `onPassThrough(value)`, which should emit the text unmodified. The post implements `onDwell`, `onComment`, and `onCommand` (so Dwell / Comment / Stop / Optional Stop / etc. work), but had no `onPassThrough`, so any Manual NC → Pass Through block a user added was discarded from the output. **Fixed** by adding `onPassThrough(value)` that writes the user text verbatim, one `writeBlock` per line (split on newlines, empty lines skipped) — deliberately **not** run through `sanitizeMessageText`, since pass-through must reach the controller untouched. `onManualNC`/`expandManualNC` was not needed (this post has no reason to distinguish Manual-NC-originated commands from internal ones).

---

## Limitations / deviations from standard practice (lower priority; several are by-design)

- [x] **F6 — Control-side radius (cutter) compensation is not supported; it hard-errors.** — [`onRadiusCompensation`](../MPCNC_v3.0_Beta3.cps#L1256-L1264), `linearMovements`. Erroring on unsupported control-side comp is a **sanctioned fallback** (Marlin/GRBL/RepRap have no G41/G42), so the behavior was already acceptable — but the error was generic ("Radius compensation mode is not supported.") and fired late (at the first compensated move in `linearMovements`). **Fixed** by rejecting it early in `onRadiusCompensation` with an actionable message that names the cause and the fix (set the operation's Compensation Type to "In computer"). Also removed the now-dead handling in `linearMovements`: the vestigial `xOutput.reset()/yOutput.reset()` block (which misleadingly implied comp was supported) and the duplicate "not supported" error — since `onRadiusCompensation` now halts before any compensated move reaches `linearMovements`. (Did not use `getSetting("supportsRadiusCompensation")` — that belongs to the newer settings-object post framework this older-style post doesn't use.)

- [ ] **F7 — Coolant uses a bespoke dual-channel implementation instead of the declarative `coolants` array.** — [`setCoolant`/`CoolantA`/`CoolantB`: 880-958](../MPCNC_v3.0_Beta3.cps#L880-L958). Autodesk's recommended approach is a declarative `coolant.coolants` array plus `setCoolant(tool.coolant)` / `getCoolantCodes()`, which the kernel validates. This post rolls its own two-channel, pin-based (M42 P# S#) coolant with custom-file overrides. That's a deliberate design to express MPCNC's pin-driven coolant, which the stock mechanism can't easily represent — **by design**, but it bypasses kernel validation of coolant modes. Note only.

- [ ] **F8 — No tool-length compensation output (G43 H#); tool-change block is `M6 T#`.** — [`toolChange`: 1990-1998](../MPCNC_v3.0_Beta3.cps#L1990-L1998). Industrial posts emit `G43 H#` with initial positioning. Marlin/GRBL/RepRap have no tool-length-offset tables, and this post instead re-probes Z after a tool change ([`probe2_OnToolChange`](../MPCNC_v3.0_Beta3.cps#L2000-L2003)). So the G43 omission is **appropriate for the target firmware** — flagged here only so it isn't mistaken for a gap. (Minor: `writeBlock(M6, T#)` emits `M6 T#`; the more common order is `T# M6`, but Marlin accepts either.)

- [ ] **F9 — `maximumCircularSweep = toRad(180)` makes the `isFullCircle()` branches in `circular()` dead code.** — [Line 34](../MPCNC_v3.0_Beta3.cps#L34), [`circular()` full-circle branches: 1868-1885, 1906-1917](../MPCNC_v3.0_Beta3.cps#L1868-L1917). With a 180° max sweep, the kernel never delivers a full circle to `onCircular` (it splits it into ≤180° arcs), so the `isFullCircle()` handling can never execute. Autodesk: *"if you wish to have 360-degree circular records you must define `maximumCircularSweep` to be 360 degrees."* Either set `maximumCircularSweep = toRad(360)` if single-block full circles are desired (GRBL/Marlin support them), or remove the dead `isFullCircle()` branches. Minor consistency issue.

- [ ] **F10 — `getProperty(properties.key)` uses the object-reference form.** — throughout the file. Autodesk documents **both** `getProperty("key")` (recommended) and `getProperty(properties.key)` (object reference) as valid; the object form works here because the post uses the *combined inline* `properties` structure. So this is **not a defect**. Recommendation only: the string-key form is form-independent (survives a future move to the split `propertyDefinitions` structure) and is what Autodesk recommends. Informational.

- [ ] **F11 — Multi-axis is only rejected at the first 5-axis move, not at section start.** — [`onLinear5D`/`onRapid5D`: 1240-1250](../MPCNC_v3.0_Beta3.cps#L1240-L1250). Multi-axis toolpaths correctly `error()` out, but only once motion begins. Minor: a `currentSection.isMultiAxis()` check in `onSection` would fail faster with a clearer message. Declared-unsupported, so low priority.

---

## Checked and NOT an issue (ruled out against the docs)

- **Formats built from `unit` at module-load time** ([lines 638-661](../MPCNC_v3.0_Beta3.cps#L638-L661)) — Autodesk confirms `unit` is populated **before** the global section executes, and the stock RS-274D sample computes `createFormat` decimals from `unit` at load time. Sanctioned pattern, not a bug.
- **`allowedCircularPlanes = undefined`** ([line 36](../MPCNC_v3.0_Beta3.cps#L36)) — documented to mean "allow all three planes" (not "disabled"). Correct.
- **`certificationLevel = 2`** — current/standard value; correct.
- **`highFeedrate` not set** — only used when `highFeedMapping` maps rapids to feed moves, which this post doesn't do. Benign.
- **`onPower` jet handling** ([`onPower`: 1265-1278](../MPCNC_v3.0_Beta3.cps#L1265-L1278)) — `onPower` is the correct/required jet on-off handler and is implemented; `currentSection.jetMode` (THROUGH/ETCHING/VAPORIZE) is read correctly. Compliant.
- **`onMovement` not filtering non-cutting moves for jet** — acceptable, because the laser/jet is held off during rapids via `onPower(false)`; the `MOVEMENT_PIERCE*` remapping in `onMovement` is comment-only, which is fine.

---

## Sources (Autodesk official documentation)

- [CAM Post Processor Training Guide (rev. 4/2/25), PDF](https://cam.autodesk.com/posts/posts/guides/Post%20Processor%20Training%20Guide.pdf) — kernel settings & `tolerance` (§5.1.1, §5.26.1), `onManualNC`/`expandManualNC` (§6.1), cycles & `writeDrillCycle` (§5.28–5.30), WCS/`wcsDefinitions`/`writeWCS` (§5.3, §5.3.8), retract & initial positioning (§5.3.1, §5.3.11, §5.31.5), radius comp (§5.15), coolant (§4.1, §5.3.10), properties/`getProperty` (§5.1.2–5.1.6)
- [Entry Functions reference](https://cam.autodesk.com/posts/reference/entry_functions.html) — `onCyclePoint`, `onPower`, `onPassThrough`, `onMovement`, `onManualNC`, `onRadiusCompensation`, etc.
- [PostProcessor Class Reference](https://cam.autodesk.com/posts/reference/classPostProcessor.html) — `tolerance`, `unit`, `highFeedrate`, `allowedCircularPlanes`, `expandCyclePoint`, `getProperty`/`setProperty`, `getPower`
- [Section Class Reference](https://cam.autodesk.com/posts/reference/classSection.html) — `getWorkOffset`, `getJetMode` (JET_MODE_THROUGH/ETCHING/VAPORIZE), `getQuality`, `isMultiAxis`, `getMaximumFeedrate`
- [Cycles reference](https://cam.autodesk.com/posts/reference/cycles.html) — cycle callback flow, `cycleType`, expansion behavior

### Firmware capability sources (for F2 — canned-cycle support)

- [GRBL v1.1 Commands (gnea/grbl wiki)](https://github.com/gnea/grbl/wiki/Grbl-v1.1-Commands) — motion modal group is `G0 G1 G2 G3 G38.x G80`; no `G81/G82/G83`.
- [Marlin `CNC_DRILLING_CYCLE` — G81/G82/G83 PRs/issue](https://github.com/MarlinFirmware/Marlin/issues/14448) (also PR [#14225](https://github.com/MarlinFirmware/Marlin/pull/14225), PR [#16103](https://github.com/MarlinFirmware/Marlin/pull/16103)) — drilling cycles are an opt-in build flag, not stock.
- [RepRap G-code dictionary](https://reprap.org/wiki/G-code) — `G81/G82/G83` are mesh bed compensation / Z-probe / babystep in RepRapFirmware, conflicting with CNC drilling meaning.

### Firmware capability sources (for F4 — work coordinate systems)

- [GRBL v1.1 Commands (gnea/grbl wiki)](https://github.com/gnea/grbl/wiki/Grbl-v1.1-Commands) — G54–G59 coordinate-system modal group; `G10 L2/L20 P#`; offsets persisted in EEPROM.
- [Marlin G54-G59.3 docs](https://marlinfw.org/docs/gcode/G054-G059.html) + [Marlin issue #14743](https://github.com/MarlinFirmware/Marlin/issues/14743) — WCS requires the opt-in `CNC_COORDINATE_SYSTEMS` build flag (not stock); G92+G54 interaction bug.
- [Duet3D GCode dictionary](https://docs.duet3d.com/User_manual/Reference/Gcodes) — RRF supports G53–G59.3 (9 systems) via `G10 L2/L20`.
