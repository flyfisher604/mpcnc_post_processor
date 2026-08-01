# review.md — full code review of `MPCNC_v4.0_Beta2.cps`

**Date:** 2026-08-01 · **Subject:** `MPCNC_v4.0_Beta2.cps` @ `f5d2a2f` (branch `v4.0-hreview-fixes`)

A fresh, whole-file review driven by **the dialog and the Fusion 360 API**, not by saved output. The
question asked of every line was: *given the properties the operator can actually select, and the
callbacks Fusion actually drives, does this produce the g-code the hobbyist expects?*

---

## Status

**17 findings · 14 fixed · 3 closed as by-design · 1 open decision (CR-15).**
Fixes landed 2026-08-01. `node --check` passes; the two arithmetic changes are harness-verified
against both the working tree and `HEAD` (see *Verification*).

| ID | Finding | Severity | Where | Status |
|---|---|---|---|---|
| [CR-1](#cr-1) | `$H` goes through `writeBlock()`, so `Enable Line #s` emits `N10 $H` and GRBL rejects it | **High** | `writeMachineHoming()` | ✅ **FIXED** — `writeln()` |
| [CR-2](#cr-2) | Homing moves the tool, then the default origin mode records the *homing corner* as the part origin | **High** | `validateJob()` | ✅ **FIXED** — post-time `warning()` |
| [CR-3](#cr-3) | A required tool change is dropped in complete silence when group 07 is off (the default) | **Med-High** | `toolChange()`, `validateJob()` | ✅ **FIXED** — file comment + `warning()` |
| [CR-4](#cr-4) | Coolant *Use custom* writes the property text as g-code; the tooltip and README call it a **file** | **Medium** | `CoolantA/B()` | ✅ **FIXED** — option (a), `loadFile()` |
| [CR-5](#cr-5) | On a jet/laser job the default First-WCS mode never establishes **Z0** at all | **Medium** | `writeWcsOnStart()` | ✅ **FIXED** — `Important` warning |
| [CR-6](#cr-6) | `onClose()` traverses to X0 Y0 **before** stopping the spindle | **Medium** | `onClose()` | ◑ **PART-FIXED** — spindle now stops first; **Z retract deliberately not added** |
| [CR-7](#cr-7) | A Start include substitutes for `G90`/`G21`/`G94`/`G17`, so the job inherits unknown modal state | **Medium** | `writeFirstSection()` | ⬛ **BY DESIGN — no change** |
| [CR-8](#cr-8) | Feed scaling can **raise** a feedrate on a zero-length move, against the documented contract | **Low-Med** | `limitFeedByXYZComponents()` | ✅ **FIXED** — clamped, harness-verified |
| [CR-9](#cr-9) | An unrecognised jet mode leaves the laser power `undefined` → `S NaN` | **Low** | `onSection()` | ✅ **FIXED** |
| [CR-10](#cr-10) | GRBL laser mode passes the enum's **string** id into `mFormat.format()`; group 09 has never been posted | **Low** | `laserOn()` | ✅ **FIXED** — explicit `Number()` |
| [CR-11](#cr-11) | `roundTo()` returns `NaN` for any value JS renders in exponential notation | **Low** | `roundTo()` | ✅ **FIXED** — harness-verified |
| [CR-12](#cr-12) | `probeTool()` writes `F` and `Z` through the raw formats, desynchronising `fOutput`/`zOutput` | **Low** | `probeTool()` | ✅ **FIXED** — `resetAll()` documented as load-bearing |
| [CR-13](#cr-13) | `onOpen()` resets 2 of ~14 mutable module globals | **Low** | `resetPostState()` | ✅ **FIXED** — all 18, one function |
| [CR-14](#cr-14) | The `properties` literal's declaration order does not match the dialog order it promises | **Low** | `properties` | ✅ **FIXED** — pure move, checksum-verified |
| [CR-15](#cr-15) | `Tool Change Probe` is a dialog field wired to nothing | **Low** | `E_Include_ProbeFile` | ⬜ **OPEN** — decision, tracked as HR-21 |
| [CR-16](#cr-16) | `Use Active WCS X0 Y0 Z0` calls a move a "retract" when it can descend | **Low** | `writeWcsOnStart()` | ✅ **FIXED** — comment + tooltip |
| [CR-17a](#cr-17) | `Retract the tool to 5.080000000000001` — raw JS number in a comment | Cosmetic | `probeTool()` | ✅ **FIXED** |
| [CR-17b](#cr-17) | Section separator is an empty comment `()`, not a blank line | Cosmetic | `onSectionEnd()` | ⬛ **BY DESIGN — no change** |
| [CR-17c](#cr-17) | `feedFormat` declared and never used | Cosmetic | formats | ✅ **FIXED** — deleted |
| [CR-17d](#cr-17) | `wcsGcode(0)` returns `G53` against the standing "never `G53`" rule | Cosmetic | `wcsGcode()` | ⬛ **BY DESIGN — no change** |
| [CR-17e](#cr-17) | `sectionComment` prints `undefined`, or inherits the previous operation's name | Cosmetic | `onSection()`/`onSectionEnd()` | ✅ **FIXED** |

**Nothing was found that breaks the factory-default single-operation job.** Every High/Medium finding
needed the operator to change one dialog field away from its default — but each of those fields is one
the README explicitly tells a hobbyist to consider.

### Behaviour changes to be aware of

Four fixes change the output of jobs that posted cleanly before. None affects the factory-default
single-operation job:

| Change | Who sees a difference |
|---|---|
| CR-1 | GRBL + homing + line numbers — the `$H` line loses its `N` prefix (and starts working) |
| CR-3 | A multi-tool job with group 07 off gains a `>>> WARNING` comment per boundary and a dialog warning |
| CR-4 | Anyone who typed **raw g-code** into a coolant `... Custom` field now gets a missing-file `error()` and no output — the field means a filename, loudly, instead of silently doing the wrong thing |
| CR-5 / CR-6 | A jet/laser job gains a `>>> WARNING`; every job's tail reorders to spindle-stop **then** `G0 X0 Y0` |

`PReview.md` §3.5 carries the Do→Get rows for the four whose reach extends into professional
controls, per the standing same-commit rule.

---

## Scope and method

**In scope — the hobbyist, as `README.md` defines them.** Fusion Personal licence; one Setup, one or
more Operations, one tool; no tool changes; a single WCS (Fusion work offset `0`, aliased to `G54`);
groups `04` and `05` at `None`; group `03` turned **on** and group `02`'s `Scale Feedrate` turned on,
as the README instructs; the six `First WCS / Part` origin modes; laser jobs (group `09` is part of
the hobbyist quick-start); coolant, includes, line numbers, comment levels, whitespace, inch and mm,
and all three firmwares.

**Out of scope.** Multi-WCS / multi-fixture, the reserved spoilboard base, `Subsequent WCS / Part`,
group `07` tool-change *mechanics*, and Manual NC. Where the review touches those it is only because a
hobbyist-reachable default leads into them; `PReview.md` was consulted **solely** to check whether a
finding was already parked as professional work, and overlaps are named in the finding.

**Method.** Reading the post's control flow against the Fusion PostProcessor API and the dialog. No
posted `.gcode` was read, no saved output was used, and `HReview.md` and `test-plan.md` were not
opened. `node --check` passes.

**Every fix below needs a review-file row in the same commit** (hobbyist behaviour →
`HReview.md`, professional → `PReview.md`), per the standing rule in `plan.md`. Four of them —
CR-2, CR-3, CR-6 and CR-7 — change the output of jobs that post cleanly today, so they are behaviour
decisions as much as fixes.

---

## Findings

<a id="cr-1"></a>
### CR-1 — `$H` is emitted through `writeBlock()`, so line numbering corrupts it — **High**

**Reached by:** GRBL / FluidNC · `Home Before Start` = `XY` or `XYZ` · `Enable Line #s` = **on**.
Both are ordinary hobbyist dialog choices; the README tells a hobbyist with X/Y endstops to pick `XY`.

`writeMachineHoming()` emits the homing command with `writeBlock("$H")`, and `writeBlock()` prefixes an
`N` word whenever `E_Job_SequenceNumbers` is set:

```js
function writeBlock() {
  if (getProperty(properties.E_Job_SequenceNumbers)) {
    writeWords2("N" + sequenceNumber, arguments);
```

GRBL recognises a `$` **system command** only when `$` is the first character of the line. `N10 $H`
is handed to the g-code parser instead, which has no word letter `$` — the controller answers an
error and every sender halts, on the **first motion line of the preamble**. With
`Include Whitespace` = off it is worse still: `N10$H`.

`%` (`onOpen`/`onClose`) already avoids this by using `writeln()`; `$H` is the only other raw
controller command in the file.

```diff
@@ function writeMachineHoming() {
     writeComment(eComment.Debug, " writeMachineHoming: GRBL/FluidNC, emitting single combined $H (mode " + mode + ")");
-    writeBlock("$H");
+    // writeln(), not writeBlock(): with "Enable Line #s" on, writeBlock() prefixes an N word, and
+    // GRBL only recognises a $ system command when $ is the first character of the line. "N10 $H"
+    // reaches the g-code parser instead and errors out on the first line of the preamble. The two
+    // other raw controller strings in this file (the GRBL "%" wrappers) already use writeln().
+    writeln("$H");
     return;
```

Line numbering is then absent from the `$H` line, which is correct — it is not a g-code block.

---

<a id="cr-2"></a>
### CR-2 — homing destroys the pre-jog that the default origin mode depends on — **High**

**Reached by:** `Home Before Start` = `XY` or `XYZ` · `First WCS / Part` left at its default
`Set X0 Y0 to Current Pos, Probe Z0` (or set to `Set X0 Y0 Z0 to Current Pos`). Any firmware.

`writeFirstSection()`'s phase order is fixed:

```
2. writeMachineHoming()   ->  $H   /   G28 X, G28 Y, G28 Z
...
6. writeWcsOnStart()      ->  G10 L20 P1 X0 Y0 Z0   at the current position
```

Homing **moves the tool** — to the endstop corner, at the extreme of travel. The `Set … to Current
Pos` modes then record *that* as the part origin, and the probe descends there. The README's
instruction for the default mode is the opposite:

> **Before sending your post to the CNC, jog the tool to the part's XY corner** (in your sender).

The pre-jog is destroyed between steps 2 and 6, and nothing warns. The result is either a
`G38.2` that never contacts (probe alarm) or, if something *is* under the tool at the home corner, a
part cut a full bed-diagonal away from the stock. On Marlin the damage is compounded: `G28` clears the
existing `G92` offsets for the homed axes, so there is no stale origin left to notice the mistake by.

The `A_Probe_OnStart` tooltip does mention it — *"when machine homing or a spoilboard base is enabled
they move the tool last, so 'current position' is that point"* — but that sentence reads as a
reassurance that the post copes, not as a warning that the combination is almost always wrong. On a
machine whose home corner genuinely *is* the fixture datum the combination is legitimate, so this
should warn, not error.

```diff
@@ function validateJob() {
+  // Homing MOVES the tool, and the "Set ... to Current Pos" origin modes record wherever it ends up
+  // -- after homing, the endstop corner. writeMachineHoming() is step 2 of writeFirstSection() and
+  // writeWcsOnStart() is step 6, so the operator's pre-jog (which the README instructs for the
+  // default mode) is destroyed in between, silently. warning(), not error(): the combination is
+  // legitimate on a machine whose home corner IS the datum.
+  var startMode = getProperty(properties.A_Probe_OnStart);
+  if (getProperty(properties.A_Machine_HomeBeforeStart) != "None" &&
+      (startMode == "Current XY & Probe Z" || startMode == "Current XYZ")) {
+    warning(localize("\"Home Before Start\" moves the tool to the homing corner before "
+      + "\"First WCS / Part\" records the current position as the part origin, so jogging to the "
+      + "part before starting has no effect. Choose a \"Use Active WCS ...\" or \"Jog to ...\" mode, "
+      + "or set \"Home Before Start\" to None."));
+  }
+
   // Guard C -- Marlin is single-frame: a job using more than one distinct work offset
```

The same text is worth writing into the file as an `Important` comment, since a warning in Fusion's
dialog is easy to click past and the posted file is what gets reviewed.

---

<a id="cr-3"></a>
### CR-3 — a required tool change is dropped in complete silence — **Medium-High**

**Reached by:** the **default** group 07 (`Tool Changes are Included` = off) plus any job whose
sections do not all use the same tool.

```js
function toolChange() {
  // If tool changes are not to be include in the NC file then exit
  if (!getProperty(properties.A_ToolChange_Enabled))
    return;
```

`onSection()` correctly detects the boundary (`tool.number != getPreviousSection().getTool().number`)
and calls `toolChange()`, which returns having emitted **nothing at all** — no comment, no `M6`, no
`warning()`. The file then cuts operation 2's toolpath with operation 1's tool still in the spindle,
at operation 2's feeds and speeds, computed for a different diameter and flute count.

The only trace is the header's Tools Table listing two tools, which the operator has to notice and
interpret. This is the configuration a hobbyist reaches *by accident* — they left the group at its
default and added a second tool in CAM — which is precisely why it should be loud.

Two halves: a warning in the file at the boundary, and a warning in Fusion's dialog at post time.

```diff
@@ function toolChange() {
-  // If tool changes are not to be include in the NC file then exit
-  if (!getProperty(properties.A_ToolChange_Enabled))
-    return;
+  // If tool changes are not to be included in the NC file then SAY SO and exit. Returning silently
+  // meant a job whose sections use different tools posted a file that cuts all of them with
+  // whichever tool is in the spindle, at the other tools' feeds and speeds, with nothing in the
+  // file marking the boundary. Off is the default, so this is a configuration reached by accident.
+  if (!getProperty(properties.A_ToolChange_Enabled)) {
+    writeComment(eComment.Important, " >>> WARNING: change to T" + tool.number + " " + tool.comment
+      + " suppressed -- \"Tool Changes are Included\" is off; the previous tool stays in the spindle");
+    return;
+  }
```

```diff
@@ function validateJob() {
+  // Post-time half of toolChange()'s suppression warning, so it reaches Fusion's dialog and not
+  // only the file. Counted over sections rather than getToolTable(), which lists tools the job may
+  // never switch between.
+  if (!getProperty(properties.A_ToolChange_Enabled)) {
+    var seenTool = {};
+    var distinct = 0;
+    for (var s = 0; s < getNumberOfSections(); ++s) {
+      var tn = getSection(s).getTool().number;
+      if (!seenTool[tn]) { seenTool[tn] = true; ++distinct; }
+    }
+    if (distinct > 1) {
+      warning(localize("This job uses more than one tool, but \"Tool Changes are Included\" is off: "
+        + "no tool-change code is emitted and every operation runs with the tool already in the "
+        + "spindle. Enable group 07, or post one tool per file."));
+    }
+  }
+
   // Guard C -- Marlin is single-frame: a job using more than one distinct work offset
```

> The *mechanics* of tool changing are professional scope (`PReview.md` §1) and nothing above touches
> them. What is in hobbyist scope is that the default configuration fails silently.

---

<a id="cr-4"></a>
### CR-4 — coolant *Use custom* writes the property text as g-code, but it is documented as a file — **Medium**

**Reached by:** group 10 · `Turn Channel A/B On/Off` = `Use custom`.

```js
function CoolantA(on) {
  var coolantText = on ? getProperty(properties.C_Coolant_ChannelAOn) : getProperty(properties.D_Coolant_ChannelAOff);
  if (coolantText == "Use custom") {
    coolantText = on ? getProperty(properties.G_Coolant_ChannelAOnCustom) : getProperty(properties.H_Coolant_ChannelAOffCustom);
  }
  writeBlock(coolantText);
}
```

The four custom properties are documented as **files**, in their own tooltips —

> "File with custom GCode to turn ON coolant channel A (**in nc folder**)."

— and in the README's group-10 table ("Custom **include files** when Mode = Use custom"). Nothing in
the post ever calls `loadFile()` for them. An operator who does what the field asks and types
`air_on.g` gets the literal block `air_on.g` streamed to the controller, which answers an
unsupported-command error mid-job. An operator who leaves the field empty gets `writeBlock("")` — a
stray blank line.

This is a genuine fork in the road, not just a bug:

- **(a) Make the code match the documentation** — recommended, because it makes the four custom
  coolant fields behave exactly like group 08's five include fields, and `loadFile()` already carries
  the missing-file error and the missing-trailing-newline repair.
- **(b) Make the documentation match the code** — retitle to *"Custom g-code to turn ON coolant
  channel A"*, drop "(in nc folder)", and fix the README row. Cheaper, but it leaves two different
  meanings of "custom" in one dialog.

Diff for (a), channel A; channel B is identical:

```diff
 function CoolantA(on) {
   var coolantText = on ? getProperty(properties.C_Coolant_ChannelAOn) : getProperty(properties.D_Coolant_ChannelAOff);
 
   if (coolantText == "Use custom") {
-    coolantText = on ? getProperty(properties.G_Coolant_ChannelAOnCustom) : getProperty(properties.H_Coolant_ChannelAOffCustom);
+    // The *Custom properties are documented -- in their own tooltips and in the README -- as FILES
+    // in the nc output folder, the same contract group 08's includes use. Emitting the property
+    // value as a block put the literal filename into the g-code stream.
+    var customFile = on ? getProperty(properties.G_Coolant_ChannelAOnCustom)
+                        : getProperty(properties.H_Coolant_ChannelAOffCustom);
+    if (customFile == "") {
+      writeComment(eComment.Important, " >>> WARNING: coolant channel A is set to \"Use custom\""
+        + " but no custom file is named -- nothing emitted");
+      return;
+    }
+    loadFile(customFile);
+    return;
   }
 
   writeBlock(coolantText);
 }
```

---

<a id="cr-5"></a>
### CR-5 — a jet/laser job on the default First-WCS mode never establishes Z0 — **Medium**

**Reached by:** a laser / plasma operation with group 06 at its **defaults**. Group 09 is in the
README's hobbyist quick-start and a diode laser on an MPCNC is an everyday hobbyist build.

`writeWcsOnStart()`'s `Current XY & Probe Z` branch splits on `canProbe`:

```js
} else {
  // Tool 0 / jet tool: no probe, so there is no G38 target to bound ...
  writeWcsOrigin(currentWorkOffset, 0, 0, undefined);
  writeComment(eComment.Debug, " writeWcsOnStart: probe skipped (tool 0 or jet tool)");
}
```

X0 and Y0 are written; **Z is left alone**. The register keeps whatever it already held — on GRBL that
survives a power cycle in EEPROM, written by some previous job. Fusion then emits absolute `Z` words
for the jet section's cutting / focus height against that unknown zero. The tool head either flies
high (no cut, and no clue why) or drives down into the material.

The README does document the degradation *"A jet tool or tool 0 never probes … Any probe-Z mode
degrades to recording the origin with no `G38.2`"* — but "no probe" is not the same statement as "Z0
is never set", and the mode the README tells jet users to pick (`Set X0 Y0 Z0 to Current Pos`) is not
the default they will land on.

The suppression is deliberate and correct as far as it goes: writing a provisional `Z0` here would
silently convert the mode into `Set X0 Y0 Z0 to Current Pos`. So the fix is to be loud, not to change
the origin write.

```diff
   } else {
     // Tool 0 / jet tool: no probe, so there is no G38 target to bound and nothing for a
     // provisional Z0 to fix -- writing one would silently turn this mode into
     // "Set X0 Y0 Z0 to Current Pos". XY only, unchanged.
     writeWcsOrigin(currentWorkOffset, 0, 0, undefined);
+    // ... which leaves Z0 at whatever this register already held -- on GRBL, persisted in EEPROM by
+    // some earlier job -- while the jet section that follows emits absolute Z words for its cutting
+    // height. Say so at Important: silence here is a head crash or a job that cuts nothing.
+    writeComment(eComment.Important, " >>> WARNING: a jet tool / tool 0 cannot probe, so Z0 was NOT"
+      + " established -- this job uses whatever Z origin " + wcsName(currentWorkOffset) + " already"
+      + " holds. Use \"Set X0 Y0 Z0 to Current Pos\" for a jet job.");
     writeComment(eComment.Debug, " writeWcsOnStart: probe skipped (tool 0 or jet tool)");
   }
```

> **Overlap:** `PReview.md` §5 parks the jet/tool-0 branches as a separate workstream (J1, and HR-1
> (D) for this exact write). That framing is fine for *testing* them; it does not cover the fact that
> the **default** hobbyist configuration on a laser job is silently unsafe today.

---

<a id="cr-6"></a>
### CR-6 — `onClose()` traverses to X0 Y0 before stopping the spindle — **Medium**

**Reached by:** the **defaults** — `At End Go to 0,0` = on, `Manual Spindle On/Off` = on.

```js
onCommand(COMMAND_COOLANT_OFF);
if (getProperty(properties.I_Job_GoOriginOnFinish)) {
  rapidMovementsXY(0, 0);
}
onCommand(COMMAND_STOP_SPINDLE);
```

Two problems in three lines.

**(1) The spindle is still running across the work.** On the default hobbyist configuration
`COMMAND_STOP_SPINDLE` is not an `M5` — it is an `M0 (MSG Turn OFF spindle)` prompt to a
hand-switched router. So the file sends the tool diagonally across the whole part at travel speed
with the router still spinning, *then* asks the operator to switch it off. Simply swapping the two
statements fixes it and costs nothing: the operator is prompted, switches off, resumes, and the
machine parks.

**(2) No clearance is asserted for the traverse.** `rapidMovementsXY(0, 0)` emits X and Y only, at
whatever Z the last operation left. The property's own text says *"Z remains unchanged"*, so this is
by contract — and for milling the operation's own end-of-toolpath retract normally covers it. It does
**not** cover a jet section, which ends at cutting height and never retracts.

The reorder is safe and unambiguous; the Z retract is a behaviour decision (it would add a `G0 Z` to
every default job's tail) and is left open.

```diff
   if (getProperty(properties.B_Include_StopFile) == "") {
     onCommand(COMMAND_COOLANT_OFF);
+    // Stop the spindle BEFORE the return traverse. On the default configuration (Manual Spindle
+    // On/Off) the "stop" is an M0 prompt, so the old order sent the tool across the work at travel
+    // speed with a hand-switched router still turning and only then asked for it to be switched
+    // off. Prompting first parks the machine after the operator has resumed.
+    onCommand(COMMAND_STOP_SPINDLE);
     if (getProperty(properties.I_Job_GoOriginOnFinish)) {
       rapidMovementsXY(0, 0);
     }
-    onCommand(COMMAND_STOP_SPINDLE);
 
     flushMotions();
```

> **Decided 2026-08-01 — the reorder landed, the Z retract did NOT.** No `rapidMovementsZ()` precedes
> the return move. The property promises "Z remains unchanged" and a hobbyist milling job is already
> covered by its last operation's own end-of-toolpath retract, so adding an absolute `G0 Z` would
> change every default job's tail to defend a case milling does not have. **The jet/laser case is
> genuinely uncovered** — a section that ends at cutting height traverses at cutting height — and
> stays owed: `PReview.md` §5 records it against HR-16 and J5, which is where a jet job's Z model
> has to be settled anyway. The code carries a comment saying the omission is deliberate, so the next
> reader does not "fix" it by accident.

---

<a id="cr-7"></a>
### CR-7 — a Start include substitutes for the modal preamble — **CLOSED: by design, no change**

> **Resolved 2026-08-01 as correct-as-designed.** The substitution contract is the feature, and it is
> not qualified: naming a file in `A_Include_StartFile` replaces the **whole** start phase, modal
> preamble included. An operator who supplies a start file owns what it contains — including whether
> it sets `G90`/`G21`. Splitting `writeModalPreamble()` out and emitting it on both branches would
> take that away, and would silently override a start file that deliberately selects `G20` or a
> different plane. This is the same reasoning that closed the Stop-file case (`plan.md`, HR-23):
> **before calling a bypass a defect, ask whether the bypass is the feature.**
>
> What is owed instead is documentation — the README should say plainly what a Start file takes
> responsibility for, which is already item 3 on the doc-sync list. The proposed diff below is kept
> for the record; **do not apply it.**

The analysis that led to the finding, retained because it is the argument the decision answers:

**Reached by:** group 08 · `Start GCode File` set to any filename.

```js
if (getProperty(properties.A_Include_StartFile) == "") {
     Start();
} else {
  loadFile(getProperty(properties.A_Include_StartFile));
}
```

Naming a file skips `Start()` **on the property string alone**, before the file's contents are looked
at. `Start()` is the only place the post emits `G90`, `G21`/`G20`, and (GRBL) `G94` and `G17`. So:

- an include file that exists but is **empty** contributes nothing and the job runs in whatever
  absolute/relative mode and whatever units the controller was left in by the last job;
- a **non-empty** include that does not itself set them has exactly the same effect — and an operator
  writing a "start file" is far more likely to be thinking about dust collection or a laser-mode
  `$32=1` than about `G21`.

An inch/mm mix-up here scales the whole job by 25.4; a `G91` left modal turns every absolute
coordinate into an increment.

This is a narrower case than the general substitution contract (an include file *replaces* the phase
it names, which is the right rule for the Stop file: the operator owns what their footer does). The
modal preamble is not the post's opinion about how a job should end — it is what makes every
coordinate in the rest of the file mean anything. Recommend splitting it out so it is emitted on both
branches, leaving the include free to override anything it likes afterwards:

```diff
+// The modal preamble -- absolute mode and units, plus GRBL's feed-rate mode and plane select. Split
+// out of Start() because these are NOT part of what a Start include substitutes for: they are what
+// makes every coordinate in the rest of the file mean something. An include that omits them (or an
+// include file that exists but is empty) otherwise leaves the job running in whatever modal state
+// the controller was left in. See docs/plan.md, HR-22 (B).
+function writeModalPreamble() {
+  writeComment(eComment.Info, "   Set Absolute Positioning");
+  writeComment(eComment.Info, "   Units = " + (unit == IN ? "inch" : "mm"));
+
+  writeBlock(gAbsIncModal.format(90));                  // Set to Absolute Positioning
+  writeBlock(gUnitModal.format(unit == IN ? 20 : 21));  // Set the units
+
+  if (fw == eFirmware.GRBL) {
+    writeComment(eComment.Info, "   Set Feed Rate Mode to units per minute");
+    writeBlock(gFeedModeModal.format(94));
+    writeComment(eComment.Info, "   Use the XY plane for circular motion");
+    writeBlock(gPlaneModal.format(17));
+  }
+}
+
 function Start() {
-  // Common GCODE
-
-  // Set absolute positioning and units of measure
-  writeComment(eComment.Info, "   Set Absolute Positioning");
-  writeComment(eComment.Info, "   Units = " + (unit == IN ? "inch" : "mm"));
-
-  writeBlock(gAbsIncModal.format(90)); // Set to Absolute Positioning
-  writeBlock(gUnitModal.format(unit == IN ? 20 : 21)); // Set the units
-
-  // Is Grbl?
-  if (fw == eFirmware.GRBL) {
-    // Set the feedrate mode to units per minute
-    writeComment(eComment.Info, "   Set Feed Rate Mode to units per minute");
-    writeBlock(gFeedModeModal.format(94));
-
-    // Select the workspace plane XY for circular motion
-    writeComment(eComment.Info, "   Use the XY plane for circular motion");
-    writeBlock(gPlaneModal.format(17));
-  }
-
-  // Not GRBL
-  else {
+  writeModalPreamble();
+
+  // Not GRBL
+  if (fw != eFirmware.GRBL) {
     // Disable stepper timeout
     writeComment(eComment.Info, "   Disable stepper timeout");
     writeBlock(mFormat.format(84), sFormat.format(0)); // Disable steppers timeout
   }
 }
```

```diff
@@ function writeFirstSection() {
   if (getProperty(properties.A_Include_StartFile) == "") {
-       Start();
+    Start();
   } else {
+    // The include replaces the START BLOCK, not the modal preamble -- see writeModalPreamble().
+    writeModalPreamble();
     loadFile(getProperty(properties.A_Include_StartFile));
   }
```

> **Not applied.** The diff above would change output for everyone already using a Start include, and
> the decision went the other way — see the closure note at the head of this finding. `plan.md`'s
> open `HR-22 (B)` item can be closed the same way: an empty Start include is the degenerate case of
> a Start include that does not set the modals, and both are the operator's to own. The
> already-landed `HR-22 (A)` Info comment (*"Custom gcode file is empty, nothing included"*) is the
> right amount of noise for it.

---

<a id="cr-8"></a>
### CR-8 — feed scaling can *raise* a feedrate on a zero-length move — **Low-Medium**

**Reached by:** `Scale Feedrate` = on (the README tells hobbyists to enable it) with
`First G1 → G0 Rapid` = **off** — the exact combination the function's own comment describes.

```js
  if (xyz.length == 0) {
    var lesserFeed = (xyLimit < zLimit) ? xyLimit : zLimit;
    return lesserFeed;
  }
```

With no direction vector to project onto, the slowest axis limit is a sound *assumption*. Returning
it **unconditionally** is not: with the defaults `lesserFeed` is 180 mm/min, so a move Fusion asked
for at F100 is emitted at F180. The README states the contract plainly — *"Scaling only ever
**reduces** a feed."*

The move itself is zero length, so nothing is cut wrongly by it — but `F` is modal, `resetAll()` at
the previous section end forces the words out, and `linearMovements()` will emit
`G1 X… Y… Z… F180` for it. Clamping costs one comparison:

```diff
     if (xyz.length == 0) {
     var lesserFeed = (xyLimit < zLimit) ? xyLimit : zLimit;
 
-    return lesserFeed;
+    // Never RAISE a feed -- the contract (README, "Feeds and feedrate scaling") is that scaling
+    // only ever reduces. With no direction vector the slowest axis limit is the safe assumption,
+    // but only as a CAP on what was asked for: returning it outright turned an F100 move into F180.
+    return (lesserFeed < feed) ? lesserFeed : feed;
   }
```

---

<a id="cr-9"></a>
### CR-9 — an unrecognised jet mode leaves the laser power undefined — **Low**

```js
      default:
        jetModeStr = "*** Unknown ***";
        warn = true;
```

Every other branch of that `switch` sets `cutterOnCurrentPower`; the `default:` does not. `laserOn()`
then computes `undefined * 10` (GRBL) or `undefined / 100 * 255`, and the block carries `S NaN` — or,
if a previous section set it, the **previous section's power**, which is worse because it looks
plausible. The post does warn in a comment, then emits the bad block anyway.

Only the three mapped modes exist today (`JET_MODE_THROUGH` / `ETCHING` / `VAPORIZE`), so this is a
guard against a future Fusion enum rather than a live failure — which is exactly why it should not be
left to produce `NaN`.

```diff
       default:
         jetModeStr = "*** Unknown ***";
+        // Leave the power DEFINED. Falling through with cutterOnCurrentPower unset made laserOn()
+        // compute undefined * 10 and emit "S NaN" -- or silently reuse the previous section's power,
+        // which looks plausible and is not. Through is the conservative middle setting.
+        cutterOnCurrentPower = getProperty(properties.B_Laser_OnThrough);
         warn = true;
```

---

<a id="cr-10"></a>
### CR-10 — the GRBL laser mode passes an enum *string* into `mFormat.format()` — **Low, needs verifying**

```js
writeBlock(mFormat.format(getProperty(properties.F_Laser_GrblMode)), sFormat.format(laser_pwm));
```

`F_Laser_GrblMode`'s ids are the strings `"4"` and `"3"`. Every other `mFormat.format()` call in the
file is handed a numeric literal. Whether `createFormat().format()` coerces a numeric string is not
something reading can settle, and it matters: if it does not, **every GRBL laser job emits a
malformed laser-on block and the laser never fires**.

`PReview.md` §5 (J4) records that the laser property group has **never appeared in any posted file**,
so there is no evidence either way. Cheap to make certain:

```diff
   if (fw == eFirmware.GRBL) {
     var laser_pwm = power * 10;
 
-    writeBlock(mFormat.format(getProperty(properties.F_Laser_GrblMode)), sFormat.format(laser_pwm));
+    // The enum stores its id as a STRING ("4" / "3"); hand format() a number rather than relying on
+    // kernel-side coercion. No posted file has ever exercised the laser group -- see PReview.md J4.
+    writeBlock(mFormat.format(Number(getProperty(properties.F_Laser_GrblMode))), sFormat.format(laser_pwm));
   }
```

The Marlin/RepRap path is unaffected — `D_Laser_MarlinMode`'s id is used in a `switch` on strings, and
the `M` numbers there are literals.

---

<a id="cr-11"></a>
### CR-11 — `roundTo()` returns `NaN` for exponential-notation values — **Low**

```js
function roundTo(value, places) {
  return +(Math.round(value + "e+" + places) + "e-" + places);
}
```

The trick relies on `String(value)` never itself containing an exponent. JavaScript renders any
magnitude below `1e-6` exponentially, so `value = 1e-7` builds the string `"1e-7e+3"`, `Number()` of
which is `NaN` — and `Math.round(NaN)` is `NaN` all the way out.

Consequences are mild but real. In `isSafeToRapid()` every comparison against `NaN` is false, so the
move simply is not converted — it **fails closed**, costing an optimisation rather than safety. In
`isSectionOrientationSupported()`'s Debug trace the tilt prints as `NaN`, which the surrounding
comment already anticipates as a diagnosis. A Z coordinate of exactly `1e-7` is float noise from a
toolpath that meant zero, so this is reachable, not theoretical.

```diff
 function roundTo(value, places) {
-  return +(Math.round(value + "e+" + places) + "e-" + places);
+  // Plain arithmetic, not the string-exponent trick: JS renders magnitudes below 1e-6 in
+  // exponential notation, so value = 1e-7 built the string "1e-7e+3" and the result was NaN. The
+  // string form exists to dodge cases like Math.round(1.005 * 100); that error lives in the 15th
+  // digit and cannot change an answer here, where the only job is to compare two coordinates at the
+  // precision they will be written with.
+  var scale = Math.pow(10, places);
+  return Math.round(value * scale) / scale;
 }
```

---

<a id="cr-12"></a>
### CR-12 — `probeTool()` bypasses the tracked output variables — **Low (latent)**

```js
writeBlock(gMotionModal.format(38.2), fFormat.format(...G38Speed...), zFormat.format(...G38Target...));
```

`fFormat`/`zFormat` are the raw formats; `fOutput`/`zOutput` are the *tracked* variables the rest of
the post writes through. So after the probe block, the controller's modal feed is the probe speed
(30 mm/min by default) and its Z is the probe target, while `fOutput` and `zOutput` still hold
whatever preceded them.

Today this is rescued two statements later by `resetAll()`, which forces the next `F` and `Z` to be
re-emitted. That is a coincidence of ordering, not a guarantee: with `Enforce Feedrate` **off**, any
future path that emitted a cut move between the `G38.2` and the `resetAll()` would have its `F`
suppressed as "unchanged" and the cut would run at **F30**.

No fix is proposed — routing the probe through `fOutput`/`zOutput` would let the modal suppress the
probe's own words, which is worse. The right change is a comment recording *why* the `resetAll()` is
load-bearing:

```diff
   writeWcsOrigin(targetWcs, undefined, undefined, propertyMmToUnit(getProperty(properties.J_Probe_Thickness)));
 
-  resetAll();
+  // LOAD-BEARING, not housekeeping. The G38.2 block above writes F and Z through the raw formats
+  // (deliberately -- routing them through fOutput/zOutput would let the modal suppress the probe's
+  // own words), so the tracked values now disagree with the controller's modals. Without this reset,
+  // and with "Enforce Feedrate" off, the next move whose feed happens to match the stale tracked
+  // value would be emitted with no F and would run at the probe speed.
+  resetAll();
   // move up tool to safe height again after probing
   rapidMovementsZ(retractZ);
```

---

<a id="cr-13"></a>
### CR-13 — `onOpen()` resets 2 of ~14 mutable module globals — **Low**

`onOpen()` explicitly resets `currentWorkOffset` and `sequenceNumber`. Left carrying state from a
previous invocation: `spindleEnabled`, `lastPromptedSpeed`, `lastPromptedClockwise`,
`currentSpindleSpeed`, `currentSpindleClockwise`, `curCoolant`, `coolantChannelA`, `coolantChannelB`,
`machineMode`, `powerState`, `probePauseBefore`, `probePauseAfter`, `safeZHeight`,
`forceSectionToStartWithRapid`, `cutterOnCurrentPower`, `pendingRadiusCompensation`.

If Fusion gives every output file a fresh JavaScript context this is inert — and for single-file
hobbyist posting it certainly is. But the two globals that *are* reset show the post already declines
to rely on that, and the failure mode if the assumption breaks is quiet: a second file would open with
`spindleEnabled == true` and never emit its "Turn ON … RPM" prompt.

```diff
+// Reset every mutable module global to its declared initial value. onOpen() already did this for
+// two of them, which is the tell that the post does not want to rely on getting a fresh JavaScript
+// context per output file. Collected here so a new global is reset by editing one function.
+function resetPostState() {
+  currentWorkOffset = undefined;                 // no work offset emitted yet
+  sequenceNumber = getProperty(properties.F_Job_SequenceNumberStart);
+  forceSectionToStartWithRapid = false;
+  sectionComment = undefined;
+  machineMode = undefined;
+  safeZHeight = undefined;
+  curCoolant = eCoolant.Off;
+  coolantChannelA = eCoolant.Off;
+  coolantChannelB = eCoolant.Off;
+  cutterOnCurrentPower = undefined;
+  powerState = false;
+  spindleEnabled = false;
+  currentSpindleSpeed = 0;
+  currentSpindleClockwise = true;
+  lastPromptedSpeed = "";
+  lastPromptedClockwise = true;
+  probePauseBefore = true;
+  probePauseAfter = true;
+  pendingRadiusCompensation = RADIUS_COMPENSATION_OFF;
+}
+
 function onOpen() {
   fw = getProperty(properties.A_Job_SelectedFirmware);
 
+  resetPostState();
+
   // Validate the job configuration before emitting anything (may error() out).
   validateJob();
@@
-  // Set the starting sequence number for line numbering
-  sequenceNumber = getProperty(properties.F_Job_SequenceNumberStart);
-
-  // No work offset emitted yet
-  currentWorkOffset = undefined;
-
```

---

<a id="cr-14"></a>
### CR-14 — the `properties` literal is declared out of dialog order — **Low**

Groups appear in the source in the order **01, 04, 02, 03, 07, 05, 06, 05, 06, 08, 09, 10, 11** —
group 05 and group 06 are interleaved twice, and inside group 06 `D_Probe_OffsetX` /
`E_Probe_OffsetY` (lines 493, 501) are declared **after** `J_Probe_Thickness` (line 469).

The dialog order the README promises —

> "The groups are ordered to be worked through in sequence … groups **01–03** … groups **04–06** …"

— therefore rests entirely on Fusion sorting groups lexicographically by the `group:` string and
properties by key. That is what the zero-padding and the single-letter key prefixes are *for*, and
`plan.md` records the padding as established from observation. But the source itself provides no
second line of defence, and the dialog checks that would confirm the current layout (`PReview.md` D1
and D3) are unrun.

Reordering the literal is a pure move: it touches no **key**, no `group:` string, no `id` and no
default, so no saved preset resets. It costs nothing and removes the dependency:

```diff
@@ properties = {
   ...
   I_Job_GoOriginOnFinish: { ... group: "01 - Job" ... },
 
-  A_Machine_HomeBeforeStart: { ... group: "04 - Establish Machine Coordinates" ... },
-  B_Machine_PromptBeforeHome: { ... group: "04 - Establish Machine Coordinates" ... },
-
   A_Feeds_TravelSpeedXY: { ... group: "02 - Feeds and Speeds" ... },
   ...
+  D_MapRapids_AllowRapidZ: { ... group: "03 - Map G1s to Rapids ..." ... },
+
+  A_Machine_HomeBeforeStart: { ... group: "04 - Establish Machine Coordinates" ... },
+  B_Machine_PromptBeforeHome: { ... group: "04 - Establish Machine Coordinates" ... },
+
+  A_Spoilboard_BaseReserve:      { ... group: "05 ..." ... },
+  B_Spoilboard_BaseEstablish:    { ... group: "05 ..." ... },
+  C_Spoilboard_SafeZAcrossWcs:   { ... group: "05 ..." ... },   // moved up from line 477
+  D_Spoilboard_SafeZClearance:   { ... group: "05 ..." ... },   // moved up from line 485
+
+  A_Probe_OnStart: { ... }, B_Probe_OnChange: { ... }, C_Probe_Pause: { ... },
+  D_Probe_OffsetX: { ... },   // moved up from line 493, into letter order
+  E_Probe_OffsetY: { ... },   // moved up from line 501
+  F_Probe_G382orG28: { ... }, ... J_Probe_Thickness: { ... },
+
+  A_ToolChange_Enabled: { ... group: "07 - Tool Changes" ... },   // moved down from line 296
   ...
```

Worth doing in the same sweep as the group-06 letter audit, and worth re-checking against D1 when the
dialog is next open.

---

<a id="cr-15"></a>
### CR-15 — `Tool Change Probe` is a dialog field wired to nothing — **Low**

`E_Include_ProbeFile` is declared in group 08 alongside four working include fields and is never read
by any code path. The source comment and the tooltip both now say `NOT IMPLEMENTED YET`, which is the
right interim mitigation — but a hobbyist reviewing group 08 top-to-bottom (as the README instructs)
still meets a control that does nothing among four that do.

Either wire it into `probeTool()` (Tool Change branch work) or delete it. Deleting resets no other
property — the key is the stored identifier and no other key changes. No diff proposed; the choice is
the open decision `plan.md` already carries as **HR-21**.

---

<a id="cr-16"></a>
### CR-16 — `Use Active WCS X0 Y0 Z0` calls a move a "retract" when it can descend — **Low (doc)**

```js
writeComment(eComment.Info, "   Use stored work origin; move to X0 Y0 at Safe Z");
resetAll();
if (canProbe) {
  rapidMovementsZ(probeSafeZ());
}
rapidMovementsXY(0, 0);
```

`rapidMovementsZ(probeSafeZ())` is an **absolute** move to (by default) 15 mm in the trusted frame.
If the tool is parked above that — a hobbyist who left it at the top of travel, which is the natural
place to park — the first thing the job does is *descend* at Z travel speed to 15 mm, over terrain the
post knows nothing about, before the XY traverse. The code comment calls it a retract and the
`I_Probe_SafeZ` tooltip calls it "Safe Z the tool retracts to".

The post cannot fix this: it has no way to know the physical Z, and the whole premise of this mode is
that the stored frame is trusted. What it can do is stop calling it a retract:

```diff
-    writeComment(eComment.Info, "   Use stored work origin; move to X0 Y0 at Safe Z");
+    writeComment(eComment.Info, "   Use stored work origin; move Z to Safe Z, then to X0 Y0");
```

and add a sentence to `A_Probe_OnStart`'s `Use Active WCS X0 Y0 Z0` description saying the tool moves
*to* Safe Z, which may be downward. `plan.md` carries the related open decision for the
base-reserved variant of the same branch.

---

<a id="cr-17"></a>
### CR-17 — cosmetic bundle — **Cosmetic**

Five one-liners, none of which changes behaviour:

**(a) A raw JavaScript number in a comment.** `probeTool()` prints
`"   Retract the tool to " + retractZ`, so a resolved inch retract reads
`Retract the tool to 5.080000000000001`.

```diff
-  writeComment(eComment.Info, "   Retract the tool to " + retractZ);
+  writeComment(eComment.Info, "   Retract the tool to " + xyzFormat.format(retractZ));
```

**(b) The section separator is an empty comment, not a blank line.** — **CLOSED: by design, no
change.** `writeComment(eComment.Important, "")` in `onSectionEnd()` emits `()` on GRBL and a bare `;`
on Marlin/RepRap. That is intended: routing it through `writeComment()` keeps the separator **subject
to the comment level**, so it disappears with everything else at `Off`, and it stays a *comment* on
both dialects rather than a bare empty line. A `writeln("")` would be neither. Legal on all three
parsers.

**(c) `feedFormat` (line 801) is declared and never used** — every feed goes through `fFormat` /
`fOutput`. Delete it.

**(d) `wcsGcode(0)` returns `53`.** — **CLOSED: by design, no change.** `wcsGcode()` is the arithmetic
map from a work-offset number to its G word, and `53 + 0` is the correct answer to the question it was
asked. No caller can reach it: `writeWCS()` aliases `0`→`1` before calling, and
`retractThroughBaseClearance()` only runs with a reserved base. Guarding it would put a policy
decision ("never `G53`") inside a pure conversion, which is the wrong place for it — the policy
belongs where a frame is *chosen*, not where a number is formatted. The proposed guard is not applied.

**(e) `sectionComment` can be `undefined`.** It is only ever assigned from
`onParameter("operation-comment")`; an operation with no comment leaves the previous section's value
in place, or prints `undefined` on the first section. Initialise it per section in `onSection()`.

---

## Checked and found correct

Recorded so a later pass can tell "looked at, fine" from "never looked at". All by reading control
flow against the API — no posted file was consulted.

**The default single-operation job, all three firmwares.** `onOpen()` → `validateJob()` → `%`
(GRBL) → `onParameter()` header comments → `writeFirstSection()`'s six phases → section body →
`onClose()`. The phase order is right where it matters: `writeWCS()` emits `G54` **before** any origin
write, so the origin cannot land on a WCS left active by a previous job; `Start()` sets `G90`/`G21`
before the base establish and the probe; the provisional `Z0` is written before the `G38.2` so the
`G38 Target` is a true relative limit, and `probeTool()`'s `G10 L20 P1 Z0.8` overwrites it before any
cutting. The probe and its prompts run with the spindle **off** — `COMMAND_START_SPINDLE` is not
reached until after `writeFirstSection()` returns.

**Multi-operation, single WCS (the common Personal-licence job).** Section 2+ short-circuits at
`writeWCS()`'s `workOffset == currentWorkOffset` test and emits nothing but the `WCS unchanged`
comment — no spurious retract, no re-probe, no re-select. Two Setups both left at Fusion's default
work offset `0` alias to the same `1` in `collectDistinctOffsets()` and in `writeWCS()`, consistently.

**Guard reachability from hobbyist settings.** Guard B correctly exempts the single-WCS job
(`collectDistinctOffsets().length > 1`), so the default `Retract Across Parts = on` with no base
reserved does **not** fire. Guard C's Marlin check runs before the base logic. Guard A is unreachable
with no base. All three run in `onOpen()` before any output, so a rejected job writes no file.

**Units.** Every dialog dimension is converted with `propertyMmToUnit()` before it is emitted as a
coordinate or compared against one — travel speeds, cut-speed limits, `G38 Target`, `G38 Speed`, plate
thickness, probe XY offsets, Inter Part Safe Z, tool-change XYZ, and both Safe-Z literal fallbacks.
F360 level values (`operation:retractHeight_value` and friends) are correctly **not** converted — they
already arrive in the output unit — and `resolveSafeZHeight()` / `describeSafeZ()` keep that
distinction straight, including in what the header prints.

**Safe-Z expression parsing.** `parseSafeZExpr()` handles a bare number and all three
`Feed:`/`Retract:`/`Clearance:` forms, and falls to `ERROR` (fallback 15 mm, with a warning) for
anything else including negative literals. The `_absolute == 1` test is applied on every level path,
and every one asks the **passed** section rather than the global `hasParameter()`.

**The G1→G0 mapper's move ordering is safe despite the untracked position.** The post never calls
`setCurrentPosition()`, so the kernel's model does not follow the post's own `G0`s. On the hobbyist
path this cannot bite: the only post-injected motion before the first section's body is the probe
retract, which leaves the tool **higher** than the kernel believes, and `rapidMovements()`'s
`_z < getCurrentPosition().z` test then errs toward Z-first (retract before travel) — the safe order.
The general defect is real and is tracked as professional scope (`PReview.md` HR-8), where a
tool-change park can invert the ordering; nothing in a single-tool, single-WCS job reaches it.

**Feed handling.** `G0` blocks carry their travel `F` through the same `fOutput` the cut moves use, so
the tracked value and the controller's modal feed stay in step regardless of `Enforce Feedrate`
(the one exception is CR-12). `limitArcFeed()` caps `G2`/`G3` against the axes the arc actually
sweeps, and arcs the post linearizes re-enter through `onLinear()` and are limited the ordinary way.
Both limiters return the feed untouched when `Scale Feedrate` is off.

**Canned cycles — expansion is the only correct choice, confirmed against all three firmwares.**
`onCyclePoint()` expands drill/peck/bore/tap into plain `G0`/`G1`/`G4`, and rejects Fusion's
WCS/inspection *probing* strategies via a locally-defined `isProbeOperation()` rather than depending
on the kernel supplying one — the reason a routine drilling job cannot abort with a bare
`ReferenceError`.

The question "could the post emit real `G81`/`G82`/`G83` instead?" was checked rather than assumed,
because the source comment asserts three firmware facts:

| Firmware | Canned drilling cycles? |
|---|---|
| **GRBL 1.1 / FluidNC** | **No.** Canned cycles are *deliberately* omitted; the supported set is G0–G3, G4, G10 L2/L20, G17–G19, G20/G21, G28/G30(.1), G38.2–G38.5, G40, G43.1, G49, G53, G54–G59, G61, G80, G90/G91(.1), G92(.1), G93/G94. **`G80` is "cancel motion mode", not "cancel canned cycle"** — there is no cycle to cancel. Only the third-party *GRBL-Advanced* fork adds G73/G76/G81–G83. |
| **Marlin 2.x** | **Only in an opt-in build.** G81 (drill), G82 (spot/dwell) and G83 (peck) exist but are gated behind the `CNC_DRILLING_CYCLE` configuration option, off by default, and they were added by community PRs rather than being part of a stock build. A post cannot know whether the operator compiled it in. |
| **RepRapFirmware / Duet** | **No — and worse than merely absent.** RRF's own "GCodes not implemented" list carries G80 and G81–G89, while the wider RepRap g-code dialect assigns those very numbers to *other* functions: `G80` mesh-based Z probe, `G81` mesh bed levelling status, `G82` single Z probe at current location, `G83` babystep Z and store to EEPROM. Sources disagree on how much of that RRF itself implements, and settling it properly needs the RRF source rather than the wiki — **but the post's decision is safe under either reading**: either the command is unknown, or it triggers a bed-probing routine instead of drilling a hole. |

So the answer is **no** — no supported firmware can be relied on to drill from a canned cycle, and on
the RepRap dialect emitting one is actively hazardous rather than merely useless. Expansion is
correct, the source comment is accurate, and this needs no change. *(Marlin's `CNC_DRILLING_CYCLE`
would be the only candidate for a future opt-in property, and it would need the operator to assert
their build has it — a poor trade against expansion that already works everywhere.)*

**Early rejections.** Multi-axis (`onSection`, plus `onRapid5D`/`onLinear5D` as a backstop) and
control-side radius compensation (`onRadiusCompensation`) both `error()` with actionable text. The
off-axis Setup guard fails **open** on anything it cannot read, which is the right bias for a check
whose false positive would abort every job.

**Comment levels are behaviourally inert.** No control flow depends on a comment being emitted;
`loadFile()`'s missing-trailing-newline repair in particular is independent of the surrounding
`Info` markers, which is what makes it work at `Important` and `Off`.

**`Include Whitespace = off`** produces valid blocks everywhere — `askUser()` and `display_text()`
each prepend their own separator, and the concatenated forms (`G10L20P1X0Y0Z0`, `G38.2F30Z-10`) are
accepted by all three parsers.

**Coolant channel bookkeeping.** `setCoolant()` turns both channels off before switching, warns when a
tool requests a coolant no channel is configured for, and derives `coolantLevels` from `eCoolant` so
the numeric `tool.coolant` index and the channel-mode enum ids cannot drift apart.

**Property structure.** 68 properties across 11 groups — 9 / 7 / 4 / 2 / 4 / 10 / 8 / 5 / 7 / 10 / 2 —
with no gaps or duplicates in the per-group letter prefixes, and every one carrying `scope: "post"`.
`writeAllProperties()` iterates the object rather than a hand-kept list, so the header dump cannot
drift.

---

## Verification

**Done — static.** `node --check` passes. The properties reorder (CR-14) was proved a pure move by
matching **sorted-line checksums** against `HEAD`: identical, so no character of any key, group
string, id, title, description or default changed. Resulting order is 01→11 with letters sequential
inside every group and the counts unchanged at 9/7/4/2/4/10/8/5/7/10/2 = 68.

**Done — harness.** `roundTo()` (CR-11) and `limitFeedByXYZComponents()` (CR-8) were brace-matched out
of the `.cps` and run in node against stubbed kernel globals, 14 fixtures. It aborts rather than
reports if extraction yields nothing, and it was run against **both** the working tree and `HEAD`:

```
working tree : PASSED all 14 checks
HEAD         : FAILED 3/14  -- roundTo(1e-7,3) = NaN, roundTo(-1e-7,4) = NaN,
                              zero-length feed 100 -> 180
```

The three failures on `HEAD` are exactly the two defects, so the harness discriminates rather than
passing vacuously. (The extraction binds each function as an **expression** — a bare declaration
inside `eval()` does not leak to the caller's scope under `'use strict'`, the same trap `plan.md`
records for `const`/`let`.)

**Owed — posted.** Everything below still rests on reading. In priority order:

1. **One GRBL/mm post at Comment Level `Info`, factory defaults, single operation.** The regression
   that matters most: CR-13's `resetPostState()`, CR-6's reordered tail, CR-17(a)/(e) and the
   properties reorder must leave a default job **otherwise unchanged**. *Discriminators:*
   `M0 (MSG Turn OFF spindle)` now precedes `G0 X0 Y0`; the probe comment reads
   `Retract the tool to 5.08`, not `5.080000000000001`; the header property dump is unchanged
   (it was always sorted by the post, so the reorder must not show there).
2. **CR-1 — GRBL, `Home Before Start = XY`, `Enable Line #s` on.** *Discriminator: `$H` on its own
   line with no `N` prefix while every surrounding block has one.* **No configuration in the record
   has ever combined homing with line numbers**, which is why this shipped broken.
3. **CR-2 / CR-3 — the two dialog warnings.** Post with homing + a `Current …` origin mode, and a
   two-tool job with group 07 off. Both must warn and still post. Then the negative: a **one**-tool
   default job must produce **no** warning.
4. **CR-4 — coolant `Use custom`** with a real file, then with the field empty.
5. **CR-5 / CR-10 — the first laser post ever made.** Group 09 has no posted evidence of any kind
   (`PReview.md` J4), so this is the one item where a fix and its first-ever exercise coincide.

`PReview.md` §3.5 carries the full Do→Get rows for CR-3, CR-4, CR-5 and CR-13, and §3.3/§3.4 gained
notes for CR-14 and CR-1, per the standing same-commit rule.

> **`HReview.md` was not touched.** It was excluded from this review's scope, but its §0 register is
> the project's single source of truth for hobbyist test state and **these fixes touch rows in it** —
> at minimum any row whose saved `.gcode` shows the old `onClose` tail order (CR-6) or the
> unformatted retract comment (CR-17a), plus the `Home Before Start` and property-dump rows. Those
> need marking by whoever owns that file; this review deliberately did not do it for them.
