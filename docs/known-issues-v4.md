# Known Issues — MPCNC_v3.0_Beta3.cps

Findings from a general code-quality review (logic errors, unhandled edge cases, dead code,
unclear variable usage). This pass did **not** check the file against Autodesk's post processor
spec — that's a separate review.

Legend: `[x]` fixed, `[ ]` open.

## Breaking bugs

- [x] **#1 — Severity: Breaking** — [Line 1983](../MPCNC_v3.0_Beta3.cps#L1983) — `toolChange()` sent `M17` (Enable Steppers) instead of `M18`/`M84` (Disable Steppers) when "Disable Z stepper" was enabled, keeping the Z axis energized during a manual tool change despite the operator prompt saying it would be disabled. **Fixed** in commit `648aec9` (changed to `M84`).
- [x] **#2 — Severity: Breaking** — [Line 830](../MPCNC_v3.0_Beta3.cps#L830) — `propertyDefinitions.mapF_SafeZ.title` referenced an undefined variable (properties are just `properties` in this file), throwing a `ReferenceError` and aborting post-processing if `mapF_SafeZ` couldn't be parsed, instead of printing the intended warning. **Fixed** by using `properties.mapF_SafeZ.title` (also added the missing space before "format error").
- [x] **#3 — Severity: Breaking** — [Line 1744](../MPCNC_v3.0_Beta3.cps#L1744) — `writeComment(...)` was called with a single argument (missing the `level` param), so it always bypassed the comment-level filter and wrote a literal `;undefined` line after every loaded custom G-code file. **Fixed** by passing `eComment.Info` as the level and the correct text as the second argument.

## Correctness risks

- [x] **#4 — Severity: Correctness** — [Line 1821](../MPCNC_v3.0_Beta3.cps#L1821) — `spindleOn` wrote `sOutput.format(spindleSpeed)` (the framework-injected global, like `tool`/`currentSection`/`unit`) instead of the function's own `_spindleSpeed` parameter. Was masked because all call sites happened to pass matching values. **Fixed** by using `_spindleSpeed`.
- [x] **#5 — Severity: Correctness** — [Lines 1403-1412](../MPCNC_v3.0_Beta3.cps#L1403-L1412) — `setSpindeSpeed` only compared speed value, ignoring `_clockwise`; a direction reversal at unchanged RPM silently emitted no G-code. **Fixed** by tracking `currentSpindleClockwise` alongside `currentSpindleSpeed` and re-triggering `spindleOn` when direction changes while running.
- [x] **#6 — Severity: Correctness** — [Line 1501](../MPCNC_v3.0_Beta3.cps#L1501) — `handleMinMax` compared `pair.max < rmin` instead of `rmax`, under-reporting the true max range in the informational Ranges Table header comment. **Fixed** by comparing against `rmax` and dropping the stale "changed by DG" comment.
- [x] **#7 — Severity: Correctness** — [Lines 1061-1093](../MPCNC_v3.0_Beta3.cps#L1061-L1093) — `onClose` only called `flushMotions()` once, before the final `rapidMovementsXY(0, 0)`/coolant-off/spindle-off/"Job end" message, so those could fire before the machine finished moving to origin (Marlin/RepRap; GRBL's `flushMotions()` is a no-op and its command queue is already sequential). Also affected the `gcodeStopFile` branch, where a custom footer file loaded via `loadFile()` could contain its own motion with no wait afterward. **Fixed** by adding `flushMotions()` after `COMMAND_STOP_SPINDLE` in the default branch, and after `loadFile()` in the custom-stop-file branch.
- [x] **#8 — Severity: Correctness** — [Line 2048](../MPCNC_v3.0_Beta3.cps#L2048) — `rapidMovementsZ(...)` was called with a stray second argument (`false`); the function only takes one parameter (`_z`), so it was silently dropped — likely a remnant of an incomplete refactor. **Fixed** by removing the unused argument.
- [x] **#9 — Severity: Correctness** — [Line 719](../MPCNC_v3.0_Beta3.cps#L719) — Typo `alue: 2` instead of `value: 2` in `eSafeZ.prop[2]`. Was unused elsewhere, but a landmine if ever referenced. **Fixed** by correcting the key name.
- [x] **#10 — Severity: Correctness** — [Lines 326-333](../MPCNC_v3.0_Beta3.cps#L326-L333) — `probe3_Thickness` declared `type: "integer"` but defaulted to `0.8` (fractional) — type/value mismatch. **Fixed** by changing the type to `"number"`.

## Dead code / style / maintainability

- [ ] **#11 — Severity: Style** — [Lines 424-439](../MPCNC_v3.0_Beta3.cps#L424-L439) — `cutter3_OnEtch` property defined twice, identically. Harmless but redundant.
- [ ] **#12 — Severity: Style** — [Lines 1114-1115](../MPCNC_v3.0_Beta3.cps#L1114-L1115), [1330-1332](../MPCNC_v3.0_Beta3.cps#L1330-L1332), [1452](../MPCNC_v3.0_Beta3.cps#L1452) — Implicit globals (`vectorX`, `vectorY`, `sectionComment`, `strCoolant`) from missing `var`/`let`.
- [ ] **#13 — Severity: Style** — [Line 837](../MPCNC_v3.0_Beta3.cps#L837) — Monkey-patches `Number.prototype.round` instead of using a standalone helper function.
- [ ] **#14 — Severity: Style** — [Lines 1812-1843](../MPCNC_v3.0_Beta3.cps#L1812-L1843) — `spindleOn`/`spindleOff` use bare `this.spindleEnabled`, relying on non-strict-mode `this`-is-global semantics instead of an explicit module-level variable.
- [ ] **#15 — Severity: Style** — [Lines 1601-1602](../MPCNC_v3.0_Beta3.cps#L1601-L1602), [1619-1621](../MPCNC_v3.0_Beta3.cps#L1619-L1621) — Stale comments ("Rapid movements with G1", "No longer called for general Rapid only for probing, homing, etc.") that no longer match actual behavior (emits G0; used for every general rapid).
- [ ] **#16 — Severity: Style** — [Line 2014](../MPCNC_v3.0_Beta3.cps#L2014), [Line 2042](../MPCNC_v3.0_Beta3.cps#L2042) — `getProperty(properties.probe7_SafeZ) != ""` is always true since the property is `type: "integer"` — vestigial conditional from an earlier string-typed property.
- [ ] **#17 — Severity: Style** — [Line 21](../MPCNC_v3.0_Beta3.cps#L21) — Missing semicolon after `minimumRevision` assignment, inconsistent with the rest of the file.
- [ ] **#18 — Severity: Style** — [Line 3](../MPCNC_v3.0_Beta3.cps#L3), [Line 13](../MPCNC_v3.0_Beta3.cps#L13) — Header comment and `description` string both say "Beta 1" while the file is `MPCNC_v3.0_Beta3.cps` (Beta 3) — stale version metadata.
