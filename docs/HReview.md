# HReview — Hobbyist-perspective code review of `MPCNC_v4.0_Beta2.cps`

> **File name.** Requested as `HReview.MB`; created as `HReview.md` (markdown, alongside the other
> two driving documents). Rename if `.MB` was intended literally.

**Reviewed:** `MPCNC_v4.0_Beta2.cps` @ branch `wcs-reworked-flow`, working tree at `baf37bf`.
**Reviewer stance:** the two lenses `docs/plan.md` sets out — Fusion post-processor engineering, and
best-practice CNC operation — applied *only* from the hobbyist's chair.
**Method:** static read of the post against the README's documented hobbyist use cases, walking every
entry point Fusion calls and every property branch a hobbyist can reach. No Fusion post was run for
this pass; findings are marked **`READ`** (settled by reading the code) or **`POST`** (needs a posted
file to confirm), and every finding carries a Do→Get row so it can be folded into
`docs/test-plan.md` when fixed.

**Out of scope by design** (per `docs/plan.md` and the standing verification rule): machine dry-runs
and physical measurement. Everything below is decidable from the post source or from a posted
`.gcode` file.

---

## 1. What "correct" means for this review

The README makes a specific promise to the hobbyist (README *What this post does*, *Quick Start by
User Type → Hobbyist*):

> A **hobby** job — one operation, one part — needs almost no setup. Jog to your zero, accept the
> defaults (the post records XY there and probes Z for you), post, run.

So the bar is: **with the dialog at its defaults plus the handful of changes the README tells a
hobbyist to make, the emitted file must be well-formed for the selected firmware, structurally
complete, and never command a move whose height or frame the post cannot justify.** Anything that
requires the operator to know an undocumented precondition is a finding.

### 1.1 The documented hobbyist configurations

The README's hobbyist walkthrough is a single persona with five reachable variations. These are the
perspectives this review reads the code from.

| ID | Perspective | Config (delta from dialog defaults) |
|---|---|---|
| **HP-1** | *The documented baseline.* One Setup, one Operation, one tool, pre-jogged XY, touch plate. | Defaults + firmware set + real travel/max speeds + **Scale Feedrate on** + **all four `03 - Map G1s to Rapids` on** |
| **HP-2** | *No probe.* Same, but Z touched off by hand. | HP-1 + **First WCS / Part = `Set X0 Y0 Z0 to Current Pos`** |
| **HP-3** | *Guided jog.* Prefers the post to prompt rather than pre-jogging. | HP-1 + **First WCS / Part = `Jog to X0 Y0, Probe Z0`** (or `Jog to X0 Y0 Z0`) |
| **HP-4** | *Marlin / RepRap hobbyist.* Same job, different controller. | HP-1 + **CNC Firmware = Marlin** (or RepRap) |
| **HP-5** | *Several operations, maybe several tools.* Still one part, one WCS, Personal license. | HP-1 + optionally **`07 - Tool Changes` enabled** (+ `Probe After Tool Change`) |

Everything the README puts *outside* the hobbyist's reach — multi-WCS, the reserved spoilboard base,
`Retract Across Parts`, `Subsequent WCS / Part`, `Use Active WCS …` — is only touched here where a
hobbyist default can wander into it. Group `05` and the multi-fixture flows stay the professional
review's ground.

### 1.2 What a hobbyist does *not* change, and why that matters

Group `04` = `None`, group `05` = `None`, group `06` = all defaults except possibly the origin mode,
group `07` = off, groups `08`–`11` = untouched. That prunes the flow graph sharply, and it is the
reason a defect on the **default first-part probe path** outranks anything in the base/traverse
machinery: for this persona the default path is the *only* path.

---

## 2. How Fusion drives this post

### 2.1 Declared surface (module scope, before any callback)

`description`/`vendor`/`legal`, `certificationLevel = 2`, `minimumRevision = 45917`,
`extension = "gcode"`, `setCodePage("ascii")`,
`capabilities = CAPABILITY_MILLING | CAPABILITY_JET`, `tolerance`, the arc limits
(`maximumCircularSweep = toRad(180)`, `allowHelicalMoves = false`, `allowedCircularPlanes = undefined`),
`wcsDefinitions`, and the `properties` literal ([MPCNC_v4.0_Beta2.cps:84](../MPCNC_v4.0_Beta2.cps#L84)).

The `createFormat` calls at [:763](../MPCNC_v4.0_Beta2.cps#L763) read the global `unit` at load time —
correct and idiomatic; the whole file's precision (3 dp mm / 4 dp inch) is fixed there.

### 2.2 Call sequence for HP-1 (the documented hobby job)

This is the order Fusion actually invokes things, with what the post emits at each step. Read it as
the spine the findings hang off.

```
onOpen()                         .cps:1340
  ├ fw = <CNC Firmware>
  ├ validateJob()                .cps:1300   ← Guards A/B/C. Single-WCS hobby job: all three no-op
  ├ writeln("%")                 (GRBL only)
  ├ gMotionModal rebuilt         GRBL: modal; Marlin/RRF: force:true
  ├ fOutput rebuilt              Enforce Feedrate on → force:true
  ├ currentWorkOffset = undefined            ← so section 1 ALWAYS emits its WCS select
  ├ parseSafeZProperty()         C_MapRapids_SafeZ  → safeZMode / safeZHeightDefault
  └ parseProbeSafeZProperty()    I_Probe_SafeZ      → probeSafeZMode / probeSafeZHeightDefault

onParameter() × N                .cps:1877   ← header comments (generated-by, date, document, setup)

onSection()  [section 1]         .cps:1614
  ├ isMultiAxis() guard
  ├ forceSectionToStartWithRapid = true
  ├ writeFirstSection()          .cps:2272
  │   ├ writeInformation()       .cps:2069   ranges + tools + writeAllProperties() + writeResolvedValues()
  │   ├ writeMachineHoming()     .cps:2217   HP-1: "None" → emits nothing
  │   ├ writeWCS(currentSection) .cps:1427   offset 0 → 1 → "G54"   (isTraverse false → no retract, no probe dispatch)
  │   ├ Start()                  .cps:2678   G90, G21/G20, +GRBL: G94, G17 / +Marlin,RRF: M84 S0
  │   ├ writeBaseEstablish()     .cps:2309   HP-1: base None → emits nothing
  │   └ writeWcsOnStart()        .cps:2440   ← the whole hobbyist origin story lives here
  ├ safeZforSection()            .cps:888    populates safeZHeight for the G1→G0 mapper
  ├ toolChange()                 .cps:2825   HP-1: group 07 off → returns immediately
  ├ (writeWCS skipped — first section already selected)
  ├ Duet mode block              RepRap only
  ├ onCommand(START_SPINDLE)     → spindleOn() → manual: M0 "Turn ON …RPM"
  ├ onCommand(COOLANT_ON)        → setCoolant(Off) → no-op
  └ display_text()               Marlin/RRF: M117

  onMovement / onLinear / onRapid / onCircular / onCyclePoint …   the toolpath body
onSectionEnd()                   .cps:1730   resetAll() + comments only

  … sections 2..N repeat onSection() without writeFirstSection(); writeWCS() runs in the body …

onClose()                        .cps:1383
  ├ flushMotions()
  ├ onCommand(COOLANT_OFF)
  ├ rapidMovementsXY(0,0)        At End Go to 0,0 (default true) — Z unchanged
  ├ onCommand(STOP_SPINDLE)
  ├ GRBL: M30   /  Marlin,RRF: M117 "Job end"       ← see HR-11
  └ writeln("%")                 (GRBL only)
```

Two structural notes, both deliberate and both correct as built:

- **WCS selection is split** — section 1 selects inside `writeFirstSection()` (it must precede the
  origin write), every later section selects in `onSection()`'s body. Documented at
  [:2257](../MPCNC_v4.0_Beta2.cps#L2257) and [:1659](../MPCNC_v4.0_Beta2.cps#L1659); the two comments agree.
- **`currentWorkOffset` is post state, not machine state.** Starting `undefined` is what forces
  section 1 to emit its select unconditionally, which is what lets the post assert rather than
  inherit the frame. Sound.

### 2.3 Entry-point inventory

Every callback the post defines, judged for the hobbyist paths.

| Entry point | Line | Hobbyist role | Verdict |
|---|---|---|---|
| `onOpen` | [1340](../MPCNC_v4.0_Beta2.cps#L1340) | firmware resolve, guards, formats, Safe-Z parse | **OK.** Guards run before any output, so a rejected job writes no file. |
| `onClose` | [1383](../MPCNC_v4.0_Beta2.cps#L1383) | coolant off → go-to-0,0 → spindle off → end | **HR-11**, **HR-16** |
| `onSection` | [1614](../MPCNC_v4.0_Beta2.cps#L1614) | preamble, tool change, WCS, spindle/coolant | **HR-6**, **HR-7**, **HR-9** |
| `onSectionEnd` | [1730](../MPCNC_v4.0_Beta2.cps#L1730) | `resetAll()` + comments | **OK** (no motion, nothing to get wrong) |
| `onComment` | [1736](../MPCNC_v4.0_Beta2.cps#L1736) | Fusion notes → `Important` comment | **OK** |
| `onPassThrough` | [1742](../MPCNC_v4.0_Beta2.cps#L1742) | Manual NC *Pass through*, verbatim, per line | **OK** — deliberately unsanitised, documented |
| `onRadiusCompensation` | [1753](../MPCNC_v4.0_Beta2.cps#L1753) | rejects control-side G41/G42 | **OK** — errors with the actionable "In computer" message |
| `onRapid` | [1765](../MPCNC_v4.0_Beta2.cps#L1765) | full-license rapids; converted G1s | **HR-8** (ordering input is stale at boundaries) |
| `onLinear` | [1772](../MPCNC_v4.0_Beta2.cps#L1772) | the hobby workhorse — first-G1 and safe-G1 conversion | **HR-7**, **HR-8**; conversion logic itself OK |
| `onRapid5D` / `onLinear5D` | [1798](../MPCNC_v4.0_Beta2.cps#L1798) | backstop multi-axis rejection | **OK** |
| `onCircular` | [1810](../MPCNC_v4.0_Beta2.cps#L1810) | arcs (on by default) | **HR-5** (no feed scaling) |
| `onCyclePoint` | [1827](../MPCNC_v4.0_Beta2.cps#L1827) | drilling — expanded to G0/G1 | **HR-2** — possible hard abort |
| `onPower` | [1841](../MPCNC_v4.0_Beta2.cps#L1841) | jet only | out of scope (J-series) |
| `onDwell` | [1857](../MPCNC_v4.0_Beta2.cps#L1857) | Manual NC *Dwell*; drill dwell | **OK** — GRBL `G4 P`, Marlin/RRF `G4 S`, clamped |
| `onParameter` | [1877](../MPCNC_v4.0_Beta2.cps#L1877) | header lines + `sectionComment` | **OK** |
| `onMovement` | [1911](../MPCNC_v4.0_Beta2.cps#L1911) | `Info` label per movement type | **OK** (verbose by design) |
| `onSpindleSpeed` | [1988](../MPCNC_v4.0_Beta2.cps#L1988) | mid-job RPM change | **HR-12** — silently dropped in manual mode |
| `onCommand` | [1992](../MPCNC_v4.0_Beta2.cps#L1992) | spindle, coolant, tool measure, stop | **HR-3**, **HR-13** |

**Callbacks intentionally not defined** — the kernel default applies, and in each case that is the
right call:

- `onManualNC` → kernel `expandManualNC()`, which routes to the `onDwell` / `onPassThrough` /
  `onCommand` handlers above. Correct; **but see HR-13** for what falls through `onCommand`.
- `onCycle` / `onCycleEnd` → not needed; `onCyclePoint` expands every point.
- `onMessage` / display-message → nothing emitted. Minor, folded into HR-13.
- `onOpenFile` / `onTerminate` / `onMachine` → not applicable to a single-file post.
- No `writeRetract`/`setRotation` machinery — consistent with the deliberate work-relative stance,
  except for the missing orientation guard (**HR-6**).

### 2.4 How the hobbyist's properties change the flow

The branch points a hobbyist can actually move, and where each lands:

| Property | Consumers | Hobbyist branch effect |
|---|---|---|
| `A_Job_SelectedFirmware` | ~20 sites | GRBL: `%` wrapper, `(comments)`, `$H`, always `G38.2`, `M30`, no `M117`, modal G-words. Marlin: `;comments`, `G92` origins, `G28 <axis>`, `M84 S0`, forced G-words, **no program end (HR-11)**. RepRap: GRBL's WCS model + Marlin's comment style + `M291` dialogs. |
| `C_Job_CommentLevel` | `writeComment` | `Info` (default) emits the ~98-line property dump + every `Move to…`/`Retract…` narration. `Important` and `Off` suppress the operator-facing narration but **not** any motion. |
| `D_Job_UseArcs` | `circular` | off → `linearize(tolerance)`; on → G2/G3, **unscaled (HR-5)** |
| `H_Job_SeparateWordsWithSpace` | `setWordSeparator("")` | `G0X10Y5F2500` — legal on all three firmwares; the prompt helpers re-insert a leading space |
| `I_Job_GoOriginOnFinish` | `onClose` | adds `G0 X0 Y0` at end, Z untouched (**HR-16**) |
| `C_Feeds_EnforceFeedrate` | `onOpen` → `fOutput` | force `F` on every block. Off is still safe: `fOutput` is shared between rapid and cut emitters, so a travel feed can never leak into a following cut silently |
| `D_Feeds_ScaleFeedrate` | `limitFeedByXYZComponents` | on → per-axis projection + `Max Toolpath Speed` cap on **`G1` only** (**HR-5**) |
| `A_MapRapids_RestoreFirstRapids` | `onLinear` | first move of each section → `G0`. **Defeated on tool-change sections (HR-7)** |
| `B_MapRapids_RestoreRapids` | `isSafeToRapid`, `safeZforSection` | gates the whole mapper *and* whether `safeZHeight` is populated at all |
| `C_MapRapids_SafeZ` | `parseSafeZProperty` | `Retract:15` → F360 retract level when absolute, else `15` **un-converted (HR-4)** |
| `D_MapRapids_AllowRapidZ` | `isSafeToRapid` | also converts vertical moves that stay inside the safe zone |
| `A_Probe_OnStart` | `writeWcsOnStart` | the six-way branch below |
| `C_Probe_Pause` | `partProbe` → `probeTool` | `No` / `Before` / `Before & After` attach-detach prompts |
| `G_Probe_G38Target` | `probeTool` | **absolute Z in the active frame, not a relative travel limit (HR-1)** |
| `I_Probe_SafeZ` | `probeSafeZ` | post-probe retract height; same expression syntax, same **conversion gap (HR-4)** |
| `A_ToolChange_*` (group 07) | `toolChange` | off by default; on → **HR-7**, **HR-9**, **HR-10** |

**`A_Probe_OnStart` — the hobbyist's one real decision.** All six branches in `writeWcsOnStart()`
([:2440](../MPCNC_v4.0_Beta2.cps#L2440)), with what reaches the file:

| Mode (id) | Persona | Emitted | Notes |
|---|---|---|---|
| `Current XY & Probe Z` **(default)** | HP-1 | `G10 L20 P1 X0 Y0` → probe → `G10 L20 P1 Z0.8` → `G0 Z<probeSafeZ>` | **HR-1** applies |
| `Current XYZ` | HP-2 | `G10 L20 P1 X0 Y0 Z0`, no probe | Clean. Nothing to get wrong |
| `Jog XY & Probe Z` | HP-3 | `M0` jog prompt → same as default | **HR-1** applies |
| `Jog XYZ` | HP-3 | `M0` jog prompt → `G10 L20 P1 X0 Y0 Z0` | Clean |
| `Probe Z` | pro | `G0 X0 Y0` at unknown height → probe | Carries the "unknown Z" Info line (H7f). **HR-1** applies with a larger exposure |
| `Skip` | pro | `G0 Z<probeSafeZ>` → `G0 X0 Y0`, no write | Trusts stored Z, so the retract is meaningful |

For HP-1/HP-2/HP-3 the two `Current …` and two `Jog …` modes are the whole story, and their
structure is right: XY (and optionally Z) recorded at a position the operator physically chose, and
`G10 L20 P<n>` scoping means no cross-WCS leakage.

---

## 3. Findings

Severity is *hobbyist* severity: how likely this persona is to hit it, times what it costs when they
do. Each finding names the config that reaches it, so nothing here is hypothetical.

---

### HR-1 — `G38 Target` is an absolute Z in a frame whose Z0 is stale — on the default probe path — **High** · `READ` · **IMPLEMENTED**

**Reaches it:** HP-1 and HP-3 (the two probing defaults), GRBL/Marlin/RepRap, any run after the
first on a controller that persists work offsets.

`writeWcsOnStart()` writes **XY only** on the `Current XY & Probe Z` path
([:2498](../MPCNC_v4.0_Beta2.cps#L2498)):

```
G10 L20 P1 X0 Y0        ← Z0 deliberately left alone, it is about to be probed
M0 (MSG Attach ZProbe)
G38.2 F30 Z-10          ← absolute Z in G54, whose Z0 is whatever the LAST run left there
G10 L20 P1 Z0.8
G0 Z5.08
```

`probeTool()` ([:2926](../MPCNC_v4.0_Beta2.cps#L2926)) emits `G_Probe_G38Target` verbatim as a `Z`
word. `Z-10` is therefore "descend to the point 10 mm below G54's stored Z zero", **not** "descend at
most 10 mm". Those coincide only when G54's Z0 already happens to sit near the tool.

The failure is a second-run failure, which is why it survives a first-run test:

1. Run 1 probes and writes `G10 L20 P1 Z0.8`. GRBL persists that offset to EEPROM.
2. Operator powers down. With `Home Before Start = None` (the hobbyist default) machine Z resets to
   wherever the controller came up — call it 0.
3. Run 2: work Z now reads `0 − storedOffset`. If run 1's probe happened 35 mm down the Z travel, the
   tool reads roughly `Z+35.8` while sitting at the touch plate.
4. `G38.2 F30 Z-10` is now a **~46 mm probing descent** at F30. If the plate is under the tool it
   still stops on contact — but if the operator mis-parked, or the plate is thinner/absent, the tool
   drives ~46 mm into the work at probe feed with no travel ceiling.

The mirror case is as bad the other way: a stored offset that makes work Z read `−20` turns `Z-10`
into an *upward* target, so the probe never contacts and the controller alarms.

`docs/plan.md` carries this as a known open decision (*"the frame-dependence of the `G38.2` probe
target"*, and the related wrinkle under the base-probe section), but only ever assessed against the
**base** probe and the `Use Active WCS` modes. It has not been recorded as landing on the **default
hobbyist path**, which is where it matters most.

**Recommended fix.** On the two paths where the operator has *just* positioned the tool at the
origin, write a provisional `Z0` alongside the XY zero. The probe overwrites it two lines later, so the
only observable change is that `G38 Target` becomes a true relative travel limit:

```diff
--- a/MPCNC_v4.0_Beta2.cps
+++ b/MPCNC_v4.0_Beta2.cps
@@ -2495,9 +2495,14 @@ function writeWcsOnStart() {
 
   // "Current XY & Probe Z" or "Jog XY & Probe Z"
   writeComment(eComment.Info, "   Set current X,Y position to 0,0");
-  writeWcsOrigin(currentWorkOffset, 0, 0, undefined);
+  // Z0 is written provisionally alongside XY -- the probe overwrites it with the plate thickness a
+  // few lines below. Its purpose is to make G_Probe_G38Target mean what its title says: with Z0 at
+  // the tool's current height, "G38 Target -10" is a 10 mm travel limit. Left unwritten, the target
+  // is evaluated against whatever Z0 a previous run persisted into this register, so the probe
+  // descent can be arbitrarily longer (or inverted) than the operator asked for.
+  writeComment(eComment.Info, "   Provisional Z0 at current height so the probe target is relative");
+  writeWcsOrigin(currentWorkOffset, 0, 0, 0);
   if (canProbe) {
     // The origin is the current position; partProbe() steps to the probe point (origin + XY
     // offset) only when an offset is set, so a zero-offset job stays byte-identical.
     partProbe(true);
```

**Deliberately *not* extended to `Probe Z` / `Skip` / the added-part paths.** There the tool arrives
at a safe height that may be far above the stock (base clearance, or the probe Safe Z in the outgoing
frame), so pinning `Z0` to the current height would make `Z-10` *too tight* and turn a working probe
into a "did not contact" alarm. Those paths need a separate decision — most likely a distinct,
larger travel allowance for a from-clearance probe — and that belongs with the `G53` base-probe-point
item already sketched in `docs/plan.md`.

**Consequence to record:** this adds ` Z0` to one `G10 L20` line plus one Info comment on the H2
path, so it breaks the H2 / H-REG byte-identical anchor. Given H-REG is already `OMITTED`, that cost
is nominal — but the test plan must say so.

#### As built — two deviations from the diff above

Implemented in `writeWcsOnStart()` ([:2496](../MPCNC_v4.0_Beta2.cps#L2496)). `node --check` passes.

1. **Gated on `canProbe`, not unconditional.** The diff above writes `Z0` on both branches; as built,
   the provisional zero is written **only** where a probe follows. With a jet tool or tool 0 there is
   no `G38.2`, so there is no target to bound and nothing for the provisional zero to fix — while
   writing one *would* silently convert `Set X0 Y0 to Current Pos, Probe Z0` into
   `Set X0 Y0 Z0 to Current Pos` for those tools, recording a Z origin the operator never asked for.
   The `else` branch therefore keeps the original XY-only write verbatim. This split needed the
   `if (canProbe)` to move above the origin write, which is the only structural change.
2. **The added-part `Jog to X0 Y0, Probe Z0` was left alone.** `writeWCS()`'s jog branch
   ([:1533](../MPCNC_v4.0_Beta2.cps#L1533)) has the same shape — operator jogs, XY-only origin write,
   `partProbe(true)` — so the same argument arguably reaches it. **Left unchanged deliberately, as an
   open question**, on two grounds: it is a professional multi-part path whose verification rows
   (PA1, M4) are unrun, so changing it now would move an unmeasured target; and the tool arrives
   there from a *retracted* clearance (base-relative, or the probe Safe Z in the outgoing frame)
   before the operator jogs, so where it ends up in Z is materially less predictable than on the
   first part, where the operator positioned it from scratch. **Decision needed** — if the answer is
   "yes, symmetric", it is the same three lines and belongs with the PA1/M4 verification run.

**Verify (Do → Get).** Full four-post row is **HR1** in `docs/test-plan.md`; short form:
*Do:* HP-1 defaults, GRBL, one milling op. *Get:* `G10 L20 P1 X0 Y0 Z0` immediately before the
attach prompt; `G38.2 F30 Z-10` unchanged; `G10 L20 P1 Z0.8` after. **Pass:** the `Z0` word is
present on the pre-probe origin write — proving the probe target is bounded to 10 mm regardless of
what the register held on arrival. The row's (C) and (D) posts prove the *scope*: `Use Active WCS X0
Y0, Probe Z0` and a jet/tool-0 job must **not** gain the `Z0`.

---

### HR-2 — `isProbeOperation()` has no definition in this file — any drilling operation may abort the post — **High** · `POST` · **IMPLEMENTED**

**Reaches it:** HP-1/HP-5 with any drill, peck, bore or tap operation — i.e. any hobbyist who drills
a hole.

[:1831](../MPCNC_v4.0_Beta2.cps#L1831), inside `onCyclePoint()`:

```js
if (isProbeOperation()) {
  cycleNotSupported();
  return;
}
expandCyclePoint(x, y, z);
```

`cycleNotSupported()` and `expandCyclePoint()` are kernel globals. **`isProbeOperation()` is not
defined anywhere in this file** (confirmed: the only occurrence is the call site itself), and in the
Autodesk post library it is conventionally a *post-local* helper, defined per `.cps`:

```js
function isProbeOperation() {
  return hasParameter("operation-strategy") && (getParameter("operation-strategy") == "probe");
}
```

If it is not a kernel global at `minimumRevision = 45917`, then `onCyclePoint` throws a
`ReferenceError` on its first invocation and the post aborts — on the *first drilled hole*, with no
useful message. The whole canned-cycle path would be unusable, and nothing else in the post would
show a symptom.

I could not settle this from the source: it depends on the kernel's global table, which only a real
post run reveals. The asymmetry of cost makes the decision easy either way — a local definition is
three lines, is what every reference post does, and is harmless if the kernel also provides one.

```diff
--- a/MPCNC_v4.0_Beta2.cps
+++ b/MPCNC_v4.0_Beta2.cps
@@ -1819,6 +1819,14 @@
+// Local definition, as in the Autodesk reference posts: `isProbeOperation` is conventionally
+// post-local rather than a kernel global, and onCyclePoint() below is the only caller. Defining it
+// here makes the drilling path independent of whether the kernel happens to supply one.
+function isProbeOperation() {
+  return hasParameter("operation-strategy") && (getParameter("operation-strategy") == "probe");
+}
+
 // Drilling / canned cycles.
```

#### As built — one deviation from the diff above

Defined at [:1820](../MPCNC_v4.0_Beta2.cps#L1820), immediately above `onCyclePoint()`, its only
caller. `node --check` passes.

**Two signals, not one.** The diff above proposed the reference-post form — the `operation-strategy`
test alone. As built it also returns true when `cycleType` is prefixed `probing`:

```js
function isProbeOperation() {
  if (hasParameter("operation-strategy") && (getParameter("operation-strategy") == "probe")) {
    return true;
  }
  return (typeof cycleType != "undefined") && (String(cycleType).indexOf("probing") == 0);
}
```

The reason is that the two signals answer slightly different questions and either can miss alone.
The strategy names the *operation*; `cycleType` names the *individual cycle at each point*
(`probing-x`, `probing-xy-outer-corner`, …). If the strategy string ever differs from `"probe"` —
across Fusion versions, or for a probing cycle embedded in an operation Fusion labels otherwise —
the strategy-only form falls through to `expandCyclePoint()` and emits **plain `G0`/`G1` motion where
a probe was intended**. That is precisely the silent-wrong outcome the existing comment at
[:1849](../MPCNC_v4.0_Beta2.cps#L1849) says the guard exists to prevent, so letting a string
comparison be the single point of failure seemed the wrong trade. Every probing cycle type is
prefixed `probing`, so the prefix test needs no per-cycle list to stay current. `typeof` guards
`cycleType` in case it is ever absent.

**This makes the guard broader, which is a behaviour change worth naming:** a job containing a
probing cycle whose strategy was not `"probe"` previously *posted* (silently, as non-probing motion)
and now *errors*. Failing loud is the intent, but it is a change, not just a fix. Trimming back to
the three-line reference form is a two-line edit if you would rather stay strictly idiomatic.

**Unit-checked at the JS level**, since the probing half cannot be posted on a Personal licence (see
below). The helper was extracted and run against stubbed `hasParameter`/`getParameter`/`cycleType`:
strategy `probe` → true; `probing-x` / `probing-xy-outer-corner` / `probing-z` → true;
`drilling` / `tapping` / `boring` → false; no strategy parameter → false; `cycleType` absent →
false. Eight cases, all passing.

**Verify (Do → Get).** Full row is **HR2** in `docs/test-plan.md`; short form:
*Do:* add one **Drill** operation to the hobby Setup and post. *Get:* the drill points expand to
`G0`/`G1` plunge-and-retract pairs, no `G81`/`G82`/`G83`, and the file completes through
`*** STOP end ***`. **Pass:** the post produces a file at all — a `ReferenceError`/abort with no
`.gcode` written is the failing discriminator, and would confirm the definition was load-bearing
rather than merely defensive.

**The probing half is not postable by this persona.** Fusion's probing / Inspection strategies
require the Machining Extension, so a Personal-licence hobbyist cannot create one — which is also
why the drilling path has never been exercised by the test plan while the probing guard sat
unreachable. The unit check above is the substitute evidence; **HR2 (B)** records it as *not
applicable* rather than unrun, so nobody later reads a blank as a gap.

**Worth noting what this does not resolve.** Whether the kernel supplies `isProbeOperation()` at
`minimumRevision = 45917` is now *moot* — a local definition shadows it either way — so the original
open question can be closed without ever being answered. But that also means **HR2 (A) no longer
distinguishes "the fix was necessary" from "the fix was redundant"**: a passing drill post is
consistent with both. If you want that answered, post a drill from a stashed pre-fix copy of the
`.cps` first; if it aborts, the finding was live. Only worth the trouble if you care for the record.

---

### HR-3 — GRBL + Manual Spindle On/Off never prompts the operator to switch the router *off* — **High** · `READ` · **IMPLEMENTED**

**Reaches it:** HP-1 exactly as documented. GRBL is the default firmware and `Manual Spindle
On/Off` defaults **true**; the README tells the hobbyist to *"Leave Manual Spindle On/Off on if you
start your router/spindle by hand."*

`spindleOn()` ([:2709](../MPCNC_v4.0_Beta2.cps#L2709)) honours the manual setting on every firmware —
it prompts `M0 (MSG Turn ON 18000RPM)`. `spindleOff()` ([:2724](../MPCNC_v4.0_Beta2.cps#L2724)) does
not:

```js
function spindleOff() {
  if (fw == eFirmware.GRBL) {
    writeBlock(mFormat.format(5));            // ← manual setting ignored entirely
  } else {
    if (getProperty(properties.B_Job_ManualSpindlePowerControl)) {
      writeBlock(mFormat.format(300), ...);   // beep
      askUser("Turn OFF spindle", "Spindle", false);
    } else {
      writeBlock(mFormat.format(5));
    }
  }
}
```

So on the default hobbyist configuration the file *asks* the operator to switch the router on, then
ends with a bare `M5` — which does nothing on a hand-switched router — and the job finishes with the
router still spinning. Marlin and RepRap users get the prompt; GRBL users, the majority, do not.

The same asymmetry bites harder at a tool change: `toolChange()` calls
`onCommand(COMMAND_STOP_SPINDLE)` ([:2860](../MPCNC_v4.0_Beta2.cps#L2860)) and then
`askUser("Insert Tool #…")` ([:2874](../MPCNC_v4.0_Beta2.cps#L2874)). On GRBL + manual spindle the
operator is invited to reach into the machine and change the cutter with **no instruction to switch
the router off first**.

**Recommended fix** — make the manual branch firmware-independent, mirroring `spindleOn()`:

```diff
--- a/MPCNC_v4.0_Beta2.cps
+++ b/MPCNC_v4.0_Beta2.cps
@@ -2724,17 +2724,21 @@
 function spindleOff() {
-  // Is Grbl?
-  if (fw == eFirmware.GRBL) {
-    writeBlock(mFormat.format(5));
-  }
-
-  //Default
-  else {
-    if (getProperty(properties.B_Job_ManualSpindlePowerControl)) {
-      writeBlock(mFormat.format(300), sFormat.format(300), pFormat.format(3000));
-      askUser("Turn OFF spindle", "Spindle", false);
-    } else {
-      writeBlock(mFormat.format(5));
-    }
-  }
+  // Manual control is a property of the MACHINE (a hand-switched router), not of the firmware, so
+  // the prompt must fire on every dialect -- mirroring spindleOn(). Previously GRBL emitted a bare
+  // M5, which does nothing to a hand-switched router: the job ended, and every tool change paused
+  // for the operator to reach in, with the spindle still running and nothing telling them so.
+  if (getProperty(properties.B_Job_ManualSpindlePowerControl)) {
+    if (fw != eFirmware.GRBL) {
+      writeBlock(mFormat.format(300), sFormat.format(300), pFormat.format(3000));  // beep (no M300 on GRBL)
+    }
+    askUser("Turn OFF spindle", "Spindle", false);
+  } else {
+    writeBlock(mFormat.format(5));
+  }
 
   spindleEnabled = false;
 }
```

#### As built

Implemented in `spindleOff()` ([:2745](../MPCNC_v4.0_Beta2.cps#L2745)) as proposed — the branch order
inverts, property first and firmware only inside it. `node --check` passes. Two points worth stating
because both are removals a later reader might question:

- **No `M5` on the manual path, on any firmware.** This mirrors `spindleOn()`, which emits no `M3`
  under manual control: the post does not command a spindle the operator owns, it asks them. It is
  also what the Marlin/RepRap manual path already did, so the alternative — prompt *and* emit `M5`
  as belt-and-braces — would have made GRBL inconsistent with Marlin in the opposite direction. Jet
  tools never reach here (`onCommand` guards `COMMAND_STOP_SPINDLE` on `!tool.isJetTool()`, and laser
  power is handled by `laserOff()`), so GRBL laser-mode jobs are unaffected by the missing `M5`.
- **The `M300` beep stays Marlin/RepRap-only**, guarded inside the manual branch. GRBL has no beep
  command; emitting one would be HR-10's defect in a new place.

**Blast radius — wider than HR-1's.** Every GRBL job with the default `Manual Spindle On/Off` now
ends with a prompt instead of `M5`, and gains one at each tool change. That is *every* saved GRBL
`.gcode` in the H, P and PB series, not just the rows HR-1 touched. No row's assertions move —
none of them assert on the stop block or on `M5` (checked across the whole test plan) and no motion
changed — but a tail diff against any saved file will now show a difference that is not a
regression. Recorded as a banner note in `docs/test-plan.md`'s runbook conventions rather than as a
⚠ on a dozen individual rows.

**Verify (Do → Get).** Full four-post row is **HR3** in `docs/test-plan.md`; short form:
*Do:* HP-1 defaults (GRBL, Manual Spindle On/Off on), one milling op. *Get:* `M0 (MSG Turn OFF
spindle)` in the `*** STOP begin ***` block, and **no** bare `M5` anywhere. Repeat with Manual
Spindle On/Off **off**: `M3 S<rpm>` and `M5`, no prompts. **Pass:** both branches — the prompt appears
exactly when manual control is selected. The row's (C) post is the one that matters most: group 07
enabled, confirming the turn-off prompt precedes `M0 (MSG Insert Tool #…)`.

---

### HR-4 — Safe-Z fallback constants are never converted from mm to output units — **Medium-High** · `READ` · **IMPLEMENTED**

**Reaches it:** HP-1 on an **inch** Setup — a large share of the V1E audience — whenever the Safe-Z
expression falls back to its literal, i.e. a bare number, a malformed string, or a Fusion level that
is defined but *relative* (`..._absolute != 1`).

The README states the contract plainly:

> **Units:** the post outputs in whatever units the Setup uses (mm or inch), **but all post
> properties must be entered in millimeters.**

Every other dimensional property honours it via `propertyMmToUnit()` — `G38 Target`, `G38 Speed`,
`Plate Thickness`, travel speeds, cut-speed limits, `Inter Part Safe Z`, the probe XY offsets, the
tool-change position. The two Safe-Z properties do not.
`resolveSafeZHeight()` ([:986](../MPCNC_v4.0_Beta2.cps#L986)) returns the literal untouched:

```js
default:  // CONST or ERROR -- use the literal fallback
  return dflt;
```

and `safeZforSection()`'s `eSafeZ.CONST` / `eSafeZ.ERROR` branches assign `safeZHeightDefault`
directly. The convention is stated in the comments at [:965](../MPCNC_v4.0_Beta2.cps#L965) —
*"the literal fallback are used as-is, never mm-converted"* — so it is deliberate, but it is
deliberate against the README's own rule, and it produces two distinct wrong behaviours:

1. **`I_Probe_SafeZ` → a 15-inch retract.** `probeSafeZ()` feeds `rapidMovementsZ()` directly and its
   header comment asserts *"already unit-correct, so callers must NOT wrap it in
   `propertyMmToUnit()`"*. True for a resolved F360 level (which is in output units); false for the
   fallback. An inch job that falls back emits `G0 Z15` = **381 mm** — a full-travel Z retract, most
   likely a hard stop against the Z limit.
2. **`C_MapRapids_SafeZ` → the mapper silently stops working.** `isSafeToRapid()` compares
   `zr >= safeZHeight` with `zr` in inches against a threshold of `15`. Never true, so no `G1` is
   ever converted — the hobbyist enables the group the README tells them to enable and gets none of
   it, with no diagnostic. Fails safe, but fails silently, which is its own problem.

**Recommended fix** — convert at the two points where a *literal* is adopted, leaving resolved F360
levels alone:

```diff
--- a/MPCNC_v4.0_Beta2.cps
+++ b/MPCNC_v4.0_Beta2.cps
@@ -983,8 +983,12 @@ function resolveSafeZHeight(mode, dflt, _section) {
-    default:  // CONST or ERROR -- use the literal fallback
-      return dflt;
+    default:
+      // CONST or ERROR -- the literal fallback. It came from the dialog, and every dialog
+      // dimension is mm by contract (README, "Units"), so it converts like any other property.
+      // A resolved F360 level is NOT converted: Fusion already reports those in output units.
+      return propertyMmToUnit(dflt);
   }
```

and the matching change in `safeZforSection()`'s `CONST` / `ERROR` / `not abs` / `not defined`
branches (five assignments of `safeZHeightDefault`), most cleanly by converting once:

```diff
@@ -888,6 +888,9 @@ function safeZforSection(_section)
 {
   if (getProperty(properties.B_MapRapids_RestoreRapids)) {
+    // Dialog literals are mm by contract; F360 level values below are already in output units.
+    var dfltInUnit = propertyMmToUnit(safeZHeightDefault);
     switch (safeZMode) {
```
…then use `dfltInUnit` in place of `safeZHeightDefault` at every assignment inside the switch.

#### As built — the diff above understated the work

`node --check` passes. Four call sites, not the two the diff showed. **Three corrections to what I
originally wrote**, all found by reading the code again rather than trusting the earlier pass:

1. **`resolveSafeZHeight()` has TWO `return dflt` sites, not one.** The diff patched only the
   `default:` switch case. The second is the fall-through at the end of the function — reached
   whenever the named F360 level is *relative* (`..._absolute != 1`) or absent, which is a far more
   common path than a bare number. Patching only the first would have left `Retract:15` on an inch
   job still returning 15 inch in exactly the case a hobbyist is most likely to hit. Both now go
   through a single `fallback` local computed once at the top.
2. **`safeZforSection()` has EIGHT fallback assignments, not the "five" I claimed.** One each for
   `CONST` and `ERROR`, and *two* each for `FEED`/`RETRACT`/`CLEARANCE` (level-not-absolute and
   level-not-defined). All eight now assign a `dfltInUnit` local.
3. **`describeSafeZ()` needed converting too — the diff did not mention it.** It prints the fallback
   *beside* the resolved value, and the resolved value now comes back converted. Left alone, an inch
   job's header would read `fallback 15.000, resolves to 0.2000` — mm and inch on the same line,
   which is worse than the original error because it looks authoritative. The fallback is now
   converted for display while `resolveSafeZHeight()` is still handed the **raw mm** value, since it
   does its own conversion and pre-converting would apply it twice.

Also updated: the unit is now named at both `safeZHeightDefault` and `probeSafeZHeightDefault`
declarations (they hold mm; `safeZHeight` holds the resolved output-unit height), and
`probeSafeZ()`'s "callers must NOT wrap this in `propertyMmToUnit()`" comment now records that the
claim finally holds on *both* paths rather than only the F360-level one.

**mm jobs are bit-for-bit unchanged**, because `propertyMmToUnit()` is the identity in mm. That is
what keeps HR-4 from invalidating a single existing PASS row — every saved reference file is a mm
job. It is the one fix in this series with no blast radius.

**Harness-verified across both units** before landing. Extracting `parseSafeZExpr` /
`resolveSafeZHeight` / `describeSafeZ` and stubbing `unit` + `propertyMmToUnit` + a section:

| expression | F360 level | mm job | inch job |
|---|---|---|---|
| `Retract:15` | 5 / 0.2, absolute | `5` | `0.2` — level passes through untouched |
| `Retract:15` | relative | `15` | `0.5906` |
| `Retract:15` | absent | `15` | `0.5906` |
| `20` | n/a | `20` | `0.7874` |
| `Retract:` (malformed) | n/a | `15` | `0.5906` |

**Verify (Do → Get).** Full four-post row is **HR4** in `docs/test-plan.md`; short form:
*Do:* an **inch** Setup, `Safe Z` = `20` (bare number, so no F360 level is consulted), one op with a
probe. *Get:* the post-probe retract is `G0 Z0.7874` and Resolved Values reads
`Probe SafeZ = Const = 0.7874`. **Pass:** `Z0.7874`, not `Z20`. The row's (B) post — mm Setup, same
property, `G0 Z20` unchanged — is the one that proves nothing regressed for existing users.

---

### HR-5 — `Scale Feedrate` does not apply to arcs — **Medium-High** · `READ` · **IMPLEMENTED**

**Reaches it:** HP-1 exactly. `Use Arcs` defaults **on**, and the README instructs the hobbyist:
*"Enable Scale Feedrate so cut moves are scaled to stay within those limits."*

`linearMovements()` runs every `G1` through `limitFeedByXYZComponents()`
([:2640](../MPCNC_v4.0_Beta2.cps#L2640)). `circular()` does not — both the GRBL and Marlin branches
emit `fOutput.format(feed)` with Fusion's raw feed
([:2779](../MPCNC_v4.0_Beta2.cps#L2779), [:2797](../MPCNC_v4.0_Beta2.cps#L2797)).

So on a job with `Max XY Cut Speed = 900` and a tool-library feed of 1800, every straight cut is
scaled to ≤ 900 while every arc is emitted at `F1800`. The whole reason the feature exists — the
machine physically cannot hold that feed — is defeated on curved geometry, and the transition is
invisible in the file unless you are watching the `F` word across a `G1`→`G2` boundary.

The README's *Feeds and feedrate scaling* section says "`G1` cut feedrates", so this is arguably
documented-as-built. It is still the wrong behaviour for the persona: a hobbyist enabling the feature
to protect a slow machine has no reason to expect arcs to be exempt.

**Recommended fix.** Do **not** reuse the linear projection: `Vector.diff(end, start)` on an arc
gives the *chord*, and a 90° chord splits the feed across both axes (≈0.707 each), so a projection
check under-protects an arc whose instantaneous axis speed reaches the full feed at each quadrant.
For a planar arc the correct cap is the axis limit of the plane it lies in:

```diff
--- a/MPCNC_v4.0_Beta2.cps
+++ b/MPCNC_v4.0_Beta2.cps
@@
+// Cap an arc's feed at the axis limits of the plane it lies in. Deliberately NOT the linear
+// projection used by limitFeedByXYZComponents(): that projects the START-to-END chord, and on an
+// arc the instantaneous axis speed reaches the full toolpath feed at each quadrant point -- so a
+// chord projection under-protects by up to 1/cos(45deg). A planar arc's real constraint is simply
+// the limit of the axes it sweeps.
+function limitArcFeed(feed) {
+  if (!getProperty(properties.D_Feeds_ScaleFeedrate)) {
+    return feed;
+  }
+  var xyLimit = propertyMmToUnit(getProperty(properties.E_Feeds_MaxCutSpeedXY));
+  var zLimit  = propertyMmToUnit(getProperty(properties.F_Feeds_MaxCutSpeedZ));
+  var limit = (getCircularPlane() == PLANE_XY) ? xyLimit : (xyLimit < zLimit ? xyLimit : zLimit);
+  var xyzLimit = propertyMmToUnit(getProperty(properties.G_Feeds_MaxCutSpeedXYZ));
+  if (limit > xyzLimit) limit = xyzLimit;
+  return (feed > limit) ? limit : feed;
+}
+
 function circular(clockwise, cx, cy, cz, x, y, z, feed) {
   if (!getProperty(properties.D_Job_UseArcs)) {
     linearize(tolerance);
     return;
   }
+  feed = limitArcFeed(feed);
 
   var start = getCurrentPosition();
```

#### As built

`limitArcFeed()` added next to `limitFeedByXYZComponents()` ([:2700](../MPCNC_v4.0_Beta2.cps#L2700)),
called from `circular()` ([:2919](../MPCNC_v4.0_Beta2.cps#L2919)). Implemented as proposed;
`node --check` passes. Three points worth recording:

- **Called inside `circular()`, after the `Use Arcs` check — not in `onCircular()`.** `circular()`
  has three `linearize(tolerance)` exits (Use Arcs off, and the unsupported-plane `default:` in each
  firmware branch). Those re-enter through `onLinear()` and are limited the ordinary way, so placing
  the cap after the first exit keeps it to arcs the post actually emits and avoids double-limiting.
  Mutating the local `feed` is safe for the other two exits because `linearize()` re-drives the
  kernel's own feed, not this variable.
- **The conservative-for-short-arcs consequence is documented in the code**, not just here — with the
  reason a fillet may legitimately post slower than the diagonals either side of it. That asymmetry
  will look like a bug to whoever next reads a posted file, so it needed to be answered at the site.
- **Composes with HR-4.** The three limits go through `propertyMmToUnit()`, so on an inch job
  `Max XY Cut Speed = 900` mm/min correctly becomes 35.433 in/min. Verified in the harness below.

**No blast radius.** `Scale Feedrate` defaults **off**, and the function returns the feed untouched on
that branch, so every existing PASS row — all posted at the default — is unaffected. Only a job that
has *deliberately* enabled scaling changes, which is the job that asked for it. HR5 (B) is the row
that proves it.

**Harness-verified** before landing: scaling off → untouched; XY arc `1800`→`900`; under-limit and
exactly-at-limit → untouched; `Max Toolpath Speed 500` → `500`; ZX and YZ arcs → `180` (the slower
of the two axes they sweep); ZX where Z is the *faster* axis → the XY limit; inch job → `35.433`;
zero feed → zero. Eleven cases, all passing.

**Verify (Do → Get).** Full four-post row is **HR5** in `docs/test-plan.md`; short form:
*Do:* HP-1 with `Scale Feedrate` on, `Max XY Cut Speed = 900`, and an operation containing a filleted
contour whose tool feed is 1800. *Get:* the `G2`/`G3` blocks carry `F900`, matching the surrounding
`G1` blocks. **Pass:** a grep for `F1800` returns nothing. The row's (B) post — `Scale Feedrate` off,
arcs back at `F1800` — proves the cap is gated by the property and the default path is untouched.

---

### HR-6 — no tool-orientation guard: a rotated 3-axis Setup posts silently wrong g-code — **Medium** · `POST` · **IMPLEMENTED**

**Reaches it:** any hobbyist who builds a Setup off a model face rather than the stock top — a
routine accident in Fusion, and the symptom is a part cut in the wrong plane rather than an error.

`onSection()` rejects multi-axis ([:1618](../MPCNC_v4.0_Beta2.cps#L1618)) and `onLinear5D`/`onRapid5D`
back that up. But a **3-axis section whose tool axis is not machine +Z** passes every check: the post
never inspects `currentSection.workPlane`, never calls `isSameDirection()`, never calls
`setRotation()` (confirmed — none of those three appear anywhere in the file). Fusion will happily
generate such a section, and the post emits its X/Y/Z words as though the frame were upright.

Every reference 3-axis post carries the guard. It is four lines and cannot false-positive on a
correctly built Setup:

```diff
--- a/MPCNC_v4.0_Beta2.cps
+++ b/MPCNC_v4.0_Beta2.cps
@@ -1618,6 +1618,16 @@ function onSection() {
   if (currentSection.isMultiAxis()) {
     error(localize("Multi-axis toolpath is not supported. Use a 3-axis milling or 2D/jet strategy."));
     return;
   }
 
+  // A 3-axis section can still be oriented off machine +Z (a Setup built on a model face rather
+  // than the stock top). The isMultiAxis() check above does not catch it: Fusion emits ordinary
+  // X/Y/Z for such a section, so without this guard the post would post it as if it were upright
+  // and the part would be cut in the wrong plane with no diagnostic anywhere in the file.
+  if (!isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1))) {
+    error(localize("Tool orientation is not supported: this operation's Z axis is not the machine Z. "
+      + "Rebuild the Setup with its Z axis along the machine's Z (the stock top)."));
+    return;
+  }
+
```

#### As built — deliberately not the idiomatic form

Added in `onSection()` at [:1650](../MPCNC_v4.0_Beta2.cps#L1650), immediately after its multi-axis
sibling. `node --check` passes. Two decisions, both driven by the fact that **this guard's failure
mode is asymmetric**: it catches a rare misconfiguration, but a false positive aborts *every* job.

1. **Component-wise comparison, not `isSameDirection()`.** The reference form uses the kernel's
   `isSameDirection(workPlane.forward, new Vector(0,0,1))`. I checked what this post already depends
   on — `new Vector`, `localize`, `clamp`, `spatial`, `toRad`, `linearize`, `getCircularPlane`,
   `isMultiAxis`, `is3D`, `getGlobalRange` are all in use, but **`isSameDirection` and
   `Section.workPlane` are both new dependencies**, neither evidenced by any posted file. HR-2 is the
   cautionary case: an unverified kernel global inside a guard is how you turn a missing feature into
   a dead post. Comparing `forward`'s components costs the same line and removes one of the two
   unknowns.
2. **The condition fails open.** It errors only when the orientation is readable *and* unambiguously
   not `+Z`. A missing `workPlane`, a missing `forward`, non-numeric or `NaN` components all fall
   through and post exactly as before. So if `Section.workPlane` turns out not to be the shape assumed
   here, the outcome is "the guard silently does nothing" — the status quo — rather than "no job can
   be posted". The tolerance is ~0.006° of tilt: orders of magnitude beyond float noise in a rotation
   matrix, far below any orientation chosen on purpose, and a near-miss posts and cuts correctly.

A `Debug`-level comment reports the tool axis it read, so a surprising result can be diagnosed from a
posted file rather than by guesswork.

**`setRotation()` deliberately omitted.** The reference snippet calls `setRotation(remaining)` after
the check. Here the check *errors* on anything non-upright, so `setRotation()` could only ever be
called with an identity plane — a no-op transform, but one whose effect on the kernel's coordinate
delivery I cannot verify without posting. Adding it would risk changing output on every job for no
benefit.

**Harness-verified** over every shape `workPlane` might take: exact `+Z`, float noise and a 0.001°
tilt → post; Z-along-X, Z-along-−Y, a 30° tilt, an inverted Z-down frame → rejected; missing
`workPlane`, missing `forward`, non-numeric components, `NaN` → post (the fail-open cases). Eleven
cases, all passing. What no harness can settle is what Fusion actually puts in `workPlane` — hence
the row below.

**Follow-up worth doing separately: promote both geometry guards into `validateJob()`.** This guard
and the multi-axis check both fire in `onSection()`, after the header is written, so Fusion can leave
a **truncated `.gcode` on disk** — a partial file someone could run. Guards A/B/C run in `onOpen()`
and write nothing at all (H7d confirmed). Both geometry checks could iterate `getSection(i)` in
`validateJob()` and fail before any output, which is strictly safer. Not done here: it changes the
multi-axis guard's long-standing behaviour too, and that deserves its own decision rather than
riding along with this one.

**Verify (Do → Get).** Full row is **HR6** in `docs/test-plan.md`. **Run the regression half first
and treat it as the real test:** re-post any previously-passing job (H2's is cheapest) and confirm it
still posts with no `Tool orientation` message. If that fails, the guard misreads a normal Setup and
must be reverted at once, because it would block all posting. Only then post a deliberately
re-oriented Setup and confirm the error names the fix.

---

### HR-7 — `toolChange()` clobbers `forceSectionToStartWithRapid`, defeating "First G1 → G0" on every tool-change section — **Medium** · `READ`

**Reaches it:** HP-5 — the hobbyist with several tools who enabled group 07 *and*, per the README,
turned all of group 03 on.

`onSection()` sets `forceSectionToStartWithRapid = true` at [:1631](../MPCNC_v4.0_Beta2.cps#L1631) so
that the section's first `G1` — which on a Personal license *is* the lost positioning rapid — gets
converted back. But `toolChange()` reaches the change position by calling the post's **own**
`onRapid()` ([:2855](../MPCNC_v4.0_Beta2.cps#L2855)), and `onRapid()`'s first statement is
`forceSectionToStartWithRapid = false` ([:1766](../MPCNC_v4.0_Beta2.cps#L1766)).

Since `toolChange()` runs *before* the body's motion, the flag is already cleared by the time the
section's first `onLinear()` arrives. The conversion the whole group-03 workaround exists for does
not happen — on precisely the boundary where it matters most, the move from the tool-change park
position back to the work. The result is a `G1` at cut feed (and, with `Scale Feedrate` on, at a feed
derived from a stale current position — see HR-8) across the job instead of a `G0`.

Every other post-injected move already avoids this correctly by calling the low-level emitters
(`rapidMovementsXY` / `rapidMovementsZ` / `rapidMovements`) rather than the callback. `toolChange()`
is the only place that routes through `onRapid()`, and the fix is to match:

```diff
--- a/MPCNC_v4.0_Beta2.cps
+++ b/MPCNC_v4.0_Beta2.cps
@@ -2852,7 +2852,10 @@ function toolChange() {
     flushMotions();
-    onRapid(propertyMmToUnit(getProperty(properties.C_ToolChange_X)), propertyMmToUnit(getProperty(properties.D_ToolChange_Y)), propertyMmToUnit(getProperty(properties.E_ToolChange_Z)));
+    // rapidMovements(), not onRapid(): onRapid() clears forceSectionToStartWithRapid, and this runs
+    // BEFORE the section's body -- so routing through the callback silently disables the
+    // "First G1 -> G0 Rapid" conversion for every section that changes tools, which is exactly the
+    // boundary (park position -> back to the work) the conversion exists to protect.
+    rapidMovements(propertyMmToUnit(getProperty(properties.C_ToolChange_X)), propertyMmToUnit(getProperty(properties.D_ToolChange_Y)), propertyMmToUnit(getProperty(properties.E_ToolChange_Z)));
     flushMotions();
```

**Verify (Do → Get).**
*Do:* HP-5 — two operations, two tools, group 07 on with Include Relocation Code, `First G1 → G0
Rapid` on. *Get:* the `( First G1 --> G0)` comment and a `G0` appear at the start of section 2's
body, after the `Tool Change End` comment. **Pass:** section 2's first motion block is `G0`, not
`G1` — today it is `G1`.

---

### HR-8 — post-injected motion never updates Fusion's tracked position — **Medium** · `READ`

**Reaches it:** every persona, at every section boundary that follows a post-emitted move (probe
retract, tool-change park, WCS-change retract, base clearance).

`setCurrentPosition()` / `setCurrentPositionZ()` appear **nowhere** in the file (confirmed). The
kernel tracks position from the callbacks it drives; when the post emits its own `G0` through
`rapidMovementsZ()` or `rapidMovementsXY()`, the kernel's model does not move. Three consumers read
that model:

1. **`rapidMovements()`** ([:2563](../MPCNC_v4.0_Beta2.cps#L2563)) picks Z-then-XY vs XY-then-Z from
   `_z < getCurrentPosition().z`. This is the ordering the README sells as the reason the G1→G0
   conversions are safe — *"retracts before travelling and travels before descending."* When the
   tracked Z is higher than the physical Z, the post concludes it is descending and travels **first,
   at the lower physical height**. Reachable at a tool-change boundary: the section ends at a
   clearance of 40, the park move and re-probe retract bring the tool physically to ~5 without the
   kernel noticing, and the next section's first rapid to 15 is then ordered XY-first — a full
   traverse at 5 mm above the stock top rather than at 15.
2. **`isSafeToRapid()`** ([:1076](../MPCNC_v4.0_Beta2.cps#L1076)) reads `getCurrentPosition()` for
   its `zConstant` / `zUp` / `curZSafe` tests, so the first conversion decision of a section can be
   made against a stale Z.
3. **`limitFeedByXYZComponents()`** ([:2640](../MPCNC_v4.0_Beta2.cps#L2640)) builds its direction
   vector from `getCurrentPosition()`, so the first cut move after injected motion can be scaled
   along the wrong vector. (The zero-length case is already handled and commented at
   [:2586](../MPCNC_v4.0_Beta2.cps#L2586); a *wrong* non-zero vector is not.)

Within a section the tracked position is accurate, which is why this has not shown up in the H-series
— they are all single-section jobs. It is a boundary defect.

**Recommended fix** — tell the kernel about the post's own moves, at the two places that emit them:

```diff
--- a/MPCNC_v4.0_Beta2.cps
+++ b/MPCNC_v4.0_Beta2.cps
@@ -2526,6 +2526,10 @@ function rapidMovementsXY(_x, _y) {
     else {
       let f = fOutput.format(propertyMmToUnit(getProperty(properties.A_Feeds_TravelSpeedXY)));
       writeBlock(gMotionModal.format(0), x, y, f);
+      // Keep Fusion's tracked position in step with moves the POST emits (probe repositions, the
+      // tool-change park, the go-to-origin at close). The kernel only tracks motion it drove, so
+      // without this the next section's rapid ordering, G1->G0 tests and feed scaling all reason
+      // from a position the tool left several blocks ago.
+      var cur = getCurrentPosition();
+      setCurrentPosition(new Vector(_x, _y, cur.z));
     }
```

with the matching `setCurrentPositionZ(_z)` in `rapidMovementsZ()` after its `writeBlock`.

**Caveat, and why this one wants a posted file before it lands.** `setCurrentPosition()` inside a
section could interact with the kernel's own bookkeeping for the section that follows. The safe
sequencing is: apply it, then re-post H2, H5, H7 and H7c and diff **motion only** against the saved
references. If any of those move, prefer the narrower variant — track a post-local
`lastEmittedZ` and have `rapidMovements()` consult `max(getCurrentPosition().z, lastEmittedZ)` for
its ordering decision, which fixes the collision-relevant half with no kernel interaction at all.

**Verify (Do → Get).**
*Do:* HP-5, two ops, two tools, group 07 with Include Relocation Code and `Tool Change Z = 40`, and a
second operation whose clearance is 15. *Get:* section 2's opening rapid pair is `G0 Z15` **then**
`G0 X… Y…`. **Pass:** the Z block precedes the XY block — today the order inverts, traversing at the
post-probe retract height.

---

### HR-9 — `Do First Change` with `Probe After Tool Change` off zeroes Z against the wrong tool — **Medium** · `READ`

**Reaches it:** HP-5 with group 07 enabled and `Do First Change` on — the natural choice for "the
spindle is empty, load tool 1 for me" — while `Probe After Tool Change` is left at its default
**off**.

The order inside `onSection()` is fixed: `writeFirstSection()` runs at
[:1634](../MPCNC_v4.0_Beta2.cps#L1634), and the tool-change block only at
[:1652](../MPCNC_v4.0_Beta2.cps#L1652). So for the first section:

1. `writeWcsOnStart()` probes and writes `G10 L20 P1 Z0.8` — **with whatever tool is currently in the
   spindle**, which by the premise of `Do First Change` is not the job's tool.
2. `toolChange()` then parks, prompts, and the operator installs tool 1 — a different length.
3. With `Probe After Tool Change` **off**, nothing re-references Z. Every cut in the job runs at
   `(actual tool length − probe tool length)` off nominal.

With `Probe After Tool Change` **on** the second probe corrects it, so the combination is merely
wasteful (two attach/detach prompt pairs). With it off the depth of cut is wrong by the tool-length
difference and nothing in the file says so.

**Recommended fix** — the ordering change is the real answer but touches the Phase-4 tool-change
rework already scoped in `docs/plan.md`. Pending that, warn at post time, next to the existing
guards:

```diff
--- a/MPCNC_v4.0_Beta2.cps
+++ b/MPCNC_v4.0_Beta2.cps
@@ -1336,6 +1336,17 @@ function validateJob() {
+  // Do First Change loads the job's first tool AFTER writeWcsOnStart() has already probed Z with
+  // whatever tool was in the spindle, so without a re-probe the work Z0 belongs to the wrong tool
+  // and every cut is off by the length difference. Not an error -- the operator may be loading an
+  // identical tool -- but it must not be silent.
+  if (getProperty(properties.A_ToolChange_Enabled)
+      && getProperty(properties.G_ToolChange_DoFirstChange)
+      && !getProperty(properties.H_ToolChange_ProbeAfterChange)) {
+    warning(localize("\"Do First Change\" loads the first tool after Z has already been probed with "
+      + "the tool that was in the spindle. Enable \"Probe After Tool Change\" so the new tool "
+      + "re-references Z, or set the origin manually (\"Set X0 Y0 Z0 to Current Pos\")."));
+  }
+
```

**Verify (Do → Get).**
*Do:* HP-5, group 07 on, `Do First Change` on, `Probe After Tool Change` off; post. *Get:* Fusion
shows the warning in the post dialog, and the file still posts (a warning, not an error). **Pass:**
the warning text names both controls by their exact dialog titles. Second post with `Probe After Tool
Change` **on**: no warning, and two `G38.2` blocks appear (the initial probe and the post-change
re-probe) — which also documents the redundancy.

---

### HR-10 — `Disable Z Stepper` emits Marlin-only `M84 Z` on GRBL — **Medium** · `READ`

**Reaches it:** HP-5, GRBL, group 07 enabled with `Disable Z Stepper` on (a reasonable choice on a
machine whose Z drifts under a heavy spindle).

[:2870](../MPCNC_v4.0_Beta2.cps#L2870):

```js
if (getProperty(properties.F_ToolChange_DisableZStepper)) {
  askUser("Z stepper will disable; wait for full stop", "Tool change", false);
  writeBlock(mFormat.format(84), 'Z');
}
```

No firmware guard. `M84` does not exist in GRBL — the controller answers `error:20` (unsupported
command) and, in most senders, **halts the program mid-tool-change**. Contrast `Start()`
([:2703](../MPCNC_v4.0_Beta2.cps#L2703)), which correctly puts its `M84 S0` inside the non-GRBL
branch: the same command is already known to be Marlin-family-only elsewhere in the file.

```diff
--- a/MPCNC_v4.0_Beta2.cps
+++ b/MPCNC_v4.0_Beta2.cps
@@ -2867,8 +2867,15 @@
     // Disable Z stepper
     if (getProperty(properties.F_ToolChange_DisableZStepper)) {
-      askUser("Z stepper will disable; wait for full stop", "Tool change", false);
-      writeBlock(mFormat.format(84), 'Z'); // Disable steppers timeout
+      // M84 is Marlin-family only -- GRBL answers error:20 and most senders halt the program
+      // mid-tool-change. Start() already scopes its own M84 S0 the same way.
+      if (fw == eFirmware.GRBL) {
+        writeComment(eComment.Important, " >>> WARNING: \"Disable Z Stepper\" ignored on GRBL -- M84 is not a GRBL command");
+      } else {
+        askUser("Z stepper will disable; wait for full stop", "Tool change", false);
+        writeBlock(mFormat.format(84), 'Z'); // Disable steppers timeout
+      }
     }
```

**Verify (Do → Get).**
*Do:* HP-5 on GRBL, group 07 on, `Disable Z Stepper` on. *Get:* the warning comment and **no `M84`**
anywhere in the file. **Pass:** absence of `M84`. Second post on Marlin: `M0` prompt + `M84 Z`
present, no warning — proving the Marlin path is untouched.

---

### HR-11 — Marlin / RepRap jobs never end, and leave every stepper energised — **Medium** · `READ`

**Reaches it:** HP-4 — the Marlin or RepRap hobbyist, on every job.

Two halves, both in the same place:

- **No program end.** `onClose()` ([:1397](../MPCNC_v4.0_Beta2.cps#L1397)) emits `M30` on GRBL and,
  for everything else, only `display_text("Job end")` → `M117 Job end`. There is no `M2` or `M30`.
  The saved reference files in `Test/` confirm this is long-standing: they end
  `M5` → `G0 X0 Y0 F2500` → `M117 Job end`, nothing after.
- **Steppers stay on.** `Start()` ([:2703](../MPCNC_v4.0_Beta2.cps#L2703)) emits `M84 S0` on
  Marlin/RepRap to *disable the idle timeout* — deliberately, so the machine cannot lose position
  mid-job. Nothing ever restores it or releases the motors, so after the job the machine sits with
  all axes energised indefinitely: motors and drivers heating, for a job that finished.

The GRBL path has neither problem (`M30` resets modal state and GRBL has no equivalent timeout
disable), which is why this reads as a gap in the Marlin branch rather than a design choice.

```diff
--- a/MPCNC_v4.0_Beta2.cps
+++ b/MPCNC_v4.0_Beta2.cps
@@ -1397,9 +1397,16 @@ function onClose() {
     // Is Grbl?
     if (fw == eFirmware.GRBL) {
       writeBlock(mFormat.format(30));
     }
 
     // Default
     else {
       display_text("Job end");
+      // Marlin/RepRap had no program end at all. M2 ends the program; the M84 restores the idle
+      // timeout that Start() disabled for the duration of the job (S0 = never time out), so the
+      // machine does not sit with every axis energised after the job finishes.
+      writeBlock(mFormat.format(84));
+      writeBlock(mFormat.format(2));
     }
```

**Decision needed before this lands:** `M84` with no `S` releases the motors immediately, which drops
Z on a machine with an unbalanced gantry and no brake. On a LowRider that is a real consideration.
The safer variant is `M84 S60` — restore a 60-second timeout instead of releasing now — and that is
probably the right default for this machine family. Worth the user's call.

**Verify (Do → Get).**
*Do:* HP-4 (Marlin), one op. *Get:* the file's last three blocks are `M117 Job end`, `M84 S60`, `M2`.
**Pass:** an explicit program end is present. Second post on GRBL: still ends `M30` then `%`, with no
`M84`/`M2` — the GRBL path is unchanged.

#### As built — `M84 S60` chosen; `M2` emitted but flagged as unconfirmed

Implemented at [:1436](../MPCNC_v4.0_Beta2.cps#L1436), in `onClose()`'s non-GRBL branch.
`node --check` passes.

1. **`M84 S60`, per the decision above.** A bare `M84` releases the motors the instant it runs, and
   an unbalanced LowRider gantry with no brake sinks in Z when it does; the timeout holds the axes
   while the operator retrieves the part and then releases without anyone remembering to. Emitted
   with an `   Restore stepper timeout` Info comment, mirroring `Start()`'s `   Disable stepper
   timeout` so the pair reads as one bracket around the job.

2. **`M2` is emitted, but the diff above overstated the confidence in it.** This post confines `M30`
   to GRBL *because Marlin reads `M30` as "delete SD file"* — so it is already established that this
   firmware family's M-code semantics diverge from GRBL's, and `M2` may be unrecognised here too.
   That possibility deserves stating rather than assuming, and it also means the existing absence of
   a program end may have been an informed choice rather than the oversight this finding assumed.
   Emitted anyway, because the cost of being wrong is bounded: motion is flushed and the spindle is
   off before this point, so an unsupported `M2` produces an unknown-command echo and nothing else.
   The call site says so, and **test-plan HR11 (A) is written to settle it from the sender's console**,
   not from the file — the block appears in the file whether or not the firmware honours it. If it
   turns out unsupported, the follow-up is to drop `M2` and record that end-of-file *is* the program
   end on Marlin/RRF; the `M84 S60` half stands either way.

3. **The `Stop File` branch is deliberately untouched.** `onClose()` bypasses the whole stop block
   when `B_Include_StopFile` is set, and `M30` is already inside the bypassed region — so a custom
   stop file owns the entire stop sequence, program end included. The new blocks went beside `M30`
   rather than after the branch, keeping that contract rather than half-breaking it. Covered by
   test-plan **HR11 (D)**.

4. **Stale reference files.** `H6 - Marlin.gcode` and `H6 - RRF.gcode` end `M117 Job end` with
   nothing after; both now differ at the tail. Flagged on the H6 row — its assertions are unaffected.

---

### HR-12 — a manual spindle is never told about an RPM change between operations — **Medium** · `READ`

**Reaches it:** HP-5 — several operations at different spindle speeds, with `Manual Spindle On/Off`
on (the default).

`spindleOn()` ([:2711](../MPCNC_v4.0_Beta2.cps#L2711)) guards its prompt on `!spindleEnabled`:

```js
if (getProperty(properties.B_Job_ManualSpindlePowerControl)) {
  if (!spindleEnabled) {
    writeComment(eComment.Important, " >>> Spindle Speed: Manual");
    askUser("Turn ON " + speedFormat.format(_spindleSpeed) + "RPM", "Spindle", false);
  }
}
```

`spindleEnabled` is only cleared in `spindleOff()`, which within a job runs only at a tool change or
at close. So section 2 asking for 12000 RPM after section 1 ran at 18000 calls `setSpindeSpeed()` →
`spindleOn()` → the guard blocks the prompt, and nothing in the file mentions the change.
`currentSpindleSpeed` is updated regardless, so the post believes it happened.

For a hand-set router this is the difference between the operator's dial and what Fusion computed the
feed against — a burnt cutter or a poor finish, silently.

```diff
--- a/MPCNC_v4.0_Beta2.cps
+++ b/MPCNC_v4.0_Beta2.cps
@@ -2709,11 +2709,15 @@ function spindleOn(_spindleSpeed, _clockwise) {
   if (getProperty(properties.B_Job_ManualSpindlePowerControl)) {
-    // For manual any positive input speed assumed as enabled. so it's just a flag
-    if (!spindleEnabled) {
+    // Prompt when the spindle is off (turn it on) AND when a running manual spindle needs a
+    // different speed -- the caller only reaches here when the requested RPM actually changed, so
+    // suppressing the second case left the operator's dial silently disagreeing with the feeds
+    // Fusion computed.
+    if (!spindleEnabled) {
       writeComment(eComment.Important, " >>> Spindle Speed: Manual");
       askUser("Turn ON " + speedFormat.format(_spindleSpeed) + "RPM", "Spindle", false);
+    } else {
+      writeComment(eComment.Important, " >>> Spindle Speed: Manual change");
+      askUser("Set spindle to " + speedFormat.format(_spindleSpeed) + "RPM", "Spindle", false);
     }
   } else {
```

**Verify (Do → Get).**
*Do:* HP-5 — two operations, same tool, spindle speeds 18000 and 12000, `Manual Spindle On/Off` on.
*Get:* `M0 (MSG Turn ON 18000RPM)` before section 1 and `M0 (MSG Set spindle to 12000RPM)` before
section 2. **Pass:** two prompts. Third check: two operations at the *same* RPM → one prompt only
(`setSpindeSpeed` short-circuits, so no new stop is introduced on the common case).

---

### HR-13 — `onCommand` silently discards every command it does not name — **Low-Medium** · `READ`

**Reaches it:** any hobbyist using Manual NC **Optional stop**, Display message, or Orientate
spindle.

`onCommand()` ([:1992](../MPCNC_v4.0_Beta2.cps#L1992)) opens with an `Info` comment naming the
command, then a `switch` with no `default:`. `COMMAND_STOP` → `M0`; `COMMAND_OPTIONAL_STOP` → nothing
at all. So Manual NC *Optional stop* produces no `M1`, and at Comment Level `Important` or `Off` not
even the naming comment survives — the instruction vanishes without trace.

`M1` is supported by all three targets (GRBL treats it as a program pause; Marlin/RRF as
`M1`/optional stop), so there is no reason to drop it. And an explicit `default:` turns every future
gap into a visible warning instead of a silent one:

```diff
--- a/MPCNC_v4.0_Beta2.cps
+++ b/MPCNC_v4.0_Beta2.cps
@@ -2056,6 +2056,15 @@ function onCommand(command) {
     case COMMAND_STOP:
       writeBlock(mFormat.format(0));
       return;
+    case COMMAND_OPTIONAL_STOP:
+      writeBlock(mFormat.format(1));
+      return;
   }
+
+  // Anything not named above reaches here. The Info comment at the top of this function is the only
+  // trace otherwise, and it disappears entirely at Comment Level Important/Off -- so a Manual NC
+  // instruction the post cannot honour would vanish from the file without any indication.
+  writeComment(eComment.Important, " >>> WARNING: command " + getCommandStringId(command)
+    + " is not supported by this post and was not emitted");
 }
```

**Verify (Do → Get).**
*Do:* add Manual NC *Optional stop* to the hobby operation and post. *Get:* `M1` in the body at the
Manual NC's position. **Pass:** `M1` present. Second check: add Manual NC *Orientate spindle* → a
`>>> WARNING: command COMMAND_ORIENTATE_SPINDLE …` comment appears instead of silence.

---

### HR-14 — two coolant modes can never match a channel — **Low** · `READ`

**Reaches it:** any hobbyist whose tool requests *Flood and Mist* or *Flood and ThroughTool* with a
matching channel configured — niche, but the failure is total and the diagnostic is misleading.

Two parallel string tables disagree at indices 7 and 8:

```js
const coolantLevels = ["Off", "Flood", "Mist", "ThroughTool", "Air", "AirThroughTool",
                       "Suction", "FloodMist",        "FloodThroughTool"];         // :71
var eCoolant = { … FloodMist: "Flood and Mist", FloodThroughTool: "Flood and ThroughTool" };  // :72
```

`onCommand(COMMAND_COOLANT_ON)` maps `tool.coolant` through `coolantLevels`
([:2026](../MPCNC_v4.0_Beta2.cps#L2026)) → `"FloodMist"`, while the channel-mode property stores the
`eCoolant` value `"Flood and Mist"`. `setCoolant()` compares the two, never matches, and emits
`>>> WARNING: No matching Coolant channel : FloodMist requested` — naming a string the operator never
saw in the dialog, for a channel they *did* configure.

Deriving one table from the other removes the class of defect rather than the instance (note
`eCoolant` must move above `coolantLevels`):

```diff
--- a/MPCNC_v4.0_Beta2.cps
+++ b/MPCNC_v4.0_Beta2.cps
@@ -71,15 +71,6 @@
-const coolantLevels = ["Off", "Flood", "Mist","ThroughTool", "Air", "AirThroughTool", "Suction", "FloodMist", "FloodThroughTool"];
 var eCoolant = {
     Off: "Off",
@@ -82,6 +73,13 @@
     FloodThroughTool: "Flood and ThroughTool",
     };
+
+// Index = Fusion's numeric tool.coolant (COOLANT_DISABLED=0 … COOLANT_FLOOD_THROUGH_TOOL=8).
+// Derived from eCoolant rather than repeated, so the two can't drift: they previously disagreed at
+// indices 7 and 8 ("FloodMist" vs "Flood and Mist"), and since the channel-mode properties store
+// the eCoolant value, those two coolant modes could never match a channel -- they always fell
+// through to "No matching Coolant channel", naming a string the dialog never shows.
+const coolantLevels = [eCoolant.Off, eCoolant.Flood, eCoolant.Mist, eCoolant.ThroughTool,
+  eCoolant.Air, eCoolant.AirThroughTool, eCoolant.Suction, eCoolant.FloodMist,
+  eCoolant.FloodThroughTool];
```

**Verify (Do → Get).**
*Do:* set the operation's tool coolant to *Flood and Mist*, Channel A Mode = *Flood and Mist*,
Channel A On = `M8`. *Get:* `( >>> Coolant Channel A: Flood and Mist)` and `M8`. **Pass:** no
`No matching Coolant channel` warning. Second check: Channel A Mode = *Off* with the same tool → the
warning fires and names `Flood and Mist` (not `FloodMist`).

#### As built — no deviation from the diff above

`eCoolant` now precedes `coolantLevels` at [:71](../MPCNC_v4.0_Beta2.cps#L71), and the array is built
from it. `node --check` passes. The declaration order is load-bearing and the comment says so — the
`const` is initialised at load time and reads `eCoolant`, so putting it back above would throw.

The comment also records that the **index is Fusion's `tool.coolant` constant**, so the array must
never be sorted or re-ordered for tidiness. That is the property the original literal depended on
silently, and it is the one an unwary edit would break.

**Harness-verified before and after, which is what makes this more than a plausible fix.** Both
declarations were extracted from the `.cps` and evaluated, then every index `0`–`8` compared against
the id the channel-mode property stores for the same coolant:

| | index 0–6 | index 7 (`Flood and Mist`) | index 8 (`Flood and ThroughTool`) |
|---|---|---|---|
| Before | match | `FloodMist` ≠ `Flood and Mist` — **no match** | `FloodThroughTool` ≠ … — **no match** |
| After | match | match | match |

Also checked: `coolantLevels.indexOf()` finds every entry, so the fall-through warning names the mode
instead of printing `unknown`; and an out-of-range `tool.coolant` still falls back to `Off`. The
before/after contrast is the useful part — it rules out a harness that would pass either way.

**No saved reference file is affected.** Coolant defaults to `Off`, indices 0–6 are unchanged, and
the two modes that changed could not previously produce a match on any file. *Verification:
`docs/test-plan.md` **HR14** — three posts, the second being the one that proves the fix reached the
diagnostic and not only the comparison.*

---

### HR-15 — `safeZforSection()` mixes global `hasParameter()` with `_section.getParameter()` — **Low** · `READ`

The exact defect already found and fixed in `resolveSafeZHeight()` (see the comment at
[:990](../MPCNC_v4.0_Beta2.cps#L990) and the plan's write-up) survives in
`safeZforSection()` ([:898](../MPCNC_v4.0_Beta2.cps#L898), [:918](../MPCNC_v4.0_Beta2.cps#L918),
[:938](../MPCNC_v4.0_Beta2.cps#L938)): each branch tests the **global** `hasParameter()` and then
reads from the **passed** `_section`.

Harmless today — the sole caller passes `currentSection` from inside `onSection()`, so the global and
the parameter are the same section. It is a latent trap: the function takes a `_section` argument,
which is an invitation to call it with a different one, and the moment anyone does, the guard reports
on the wrong section and hands back the fallback. Three one-word changes (`hasParameter(` →
`_section.hasParameter(`) close it and make the two Safe-Z resolvers consistent.

**Verify:** no output change is expected; a re-post of H2 must be byte-identical. That *is* the test.

#### As built — no deviation from the three changes above

All three guards now read `_section.hasParameter(...)` ([:912](../MPCNC_v4.0_Beta2.cps#L912),
[:932](../MPCNC_v4.0_Beta2.cps#L932), [:952](../MPCNC_v4.0_Beta2.cps#L952)). `node --check` passes.

One addition beyond the three words: a comment above the `switch` stating the rule once for all three
branches and pointing at `resolveSafeZHeight()`, where the same mismatch was a live defect rather than
a latent one. The point of the fix is that the next reader adding a fourth `eSafeZ` mode copies the
`_section.` form — a silent convention would not survive that, which is how the original three came to
disagree with their own `getParameter()` calls.

**Verification is two rows, not one** (`docs/test-plan.md` **HR15**). The proposed "a re-post must be
byte-identical" is necessary but not sufficient: a fix that broke all three guards to `false` would
*also* post byte-identically on a `Const:` job, since that mode consults no level at all. So (A) is
the identical re-post and (B) posts a `Retract:`-mode job and asserts the ` SafeZ retract level: <n>`
comment appears instead of ` SafeZ: retract level not defined`. Same fail-open lesson HR-6 (A) taught.

---

### HR-16 — `onClose` traverses to X0 Y0 before stopping the spindle, with no guaranteed safe Z — **Low** · `READ`

`onClose()` ([:1388](../MPCNC_v4.0_Beta2.cps#L1388)) orders: coolant off → `G0 X0 Y0` → spindle off.
The `At End Go to 0,0` tooltip is honest (*"Z remains unchanged"*), and after a milling operation
Fusion's own final retract leaves Z at the operation's clearance, so the traverse is normally safe.
Two residual notes:

- The move happens with the spindle still running. Not dangerous (a spinning cutter traversing in air
  is the safer of the two), but it inverts the conventional order and is worth a deliberate decision
  rather than an accident.
- On a jet/laser job, or any last operation that does not retract, the traverse runs at cut height.
  Out of scope here (J-series), but it is the same line of code.

No fix proposed; recorded so the ordering is a choice on the record.

---

### HR-17 — tidy-ups (no behavioural effect)

| Item | Location | Note |
|---|---|---|
| `sanitizeMessageText` strips parentheses, leaving double spaces | tapping warning [:2046](../MPCNC_v4.0_Beta2.cps#L2046); group name `"03 - Map G1s to Rapids (disable when using full license)"` [:251](../MPCNC_v4.0_Beta2.cps#L251) | **Already tracked** in the plan's checkpoint. The group name reaches the file through `writeAllProperties()`'s `Properties -- <group>:` heading |
| `linearMovements(x, y, z, feed, true)` passes 5 args to a 4-parameter function | [:1794](../MPCNC_v4.0_Beta2.cps#L1794) | Vestigial `true`; harmless, misleading to a reader |
| `"Turn ON " + …format(rpm) + "RPM"` → `Turn ON 18000RPM` | [:2714](../MPCNC_v4.0_Beta2.cps#L2714) | Missing space |
| `flushMotions()` has an empty `if (fw == eFirmware.GRBL) {}` block | [:818](../MPCNC_v4.0_Beta2.cps#L818) | Intentional (GRBL has no `M400`); an early `return` with the reason in a comment reads better |

---

## 4. Checked and found sound

Recording the negative results, because "we looked" is part of the confidence claim.

| Area | Why it is correct |
|---|---|
| **Guards on hobbyist jobs** | A single-WCS job trips none of A/B/C. Guard B correctly exempts one distinct offset ([:1320](../MPCNC_v4.0_Beta2.cps#L1320)); Guard C's `collectDistinctOffsets()` aliases `0`→`1` the same way `writeWCS()` does, so a default Marlin Setup cannot false-positive. All three run before any output, so a rejected job writes no file (H7d). |
| **Feedrate leakage from rapids into cuts** | `rapidMovementsXY`/`Z` emit `F<travel>` on their `G0` lines, which on Marlin *is* honoured and on GRBL sets the modal feed. Safe regardless of `Enforce Feedrate`, because `fOutput` is the **same** modal variable the cut emitter uses — a differing cut feed always re-emits `F`. Deliberate and correct. |
| **Split rapids** | `rapidMovements()` emitting Z and XY as separate `G0`s, each at its own axis travel speed, is what makes travel speeds meaningful on Marlin (where `G0` honours `F`). The *ordering input* is the problem (HR-8), not the split. |
| **`G1 → G0` conversion rules** | `isSafeToRapid()`'s three cases (Z constant in the safe zone; Z up with XY constant; Z down with XY constant and both ends safe) are conservative and correctly gated. Rounding both sides to output precision before comparing ([:1066](../MPCNC_v4.0_Beta2.cps#L1066)) is the right fix for representation noise — two positions that format identically *are* the same point. |
| **`G10 L20 P<n>` origin scoping** | Writing into a named register rather than `G92` means an origin cannot leak across WCS. `writeWcsOrigin()`'s per-axis `undefined` handling is exactly what the XY-only and Z-only writes need. |
| **WCS assertion, not inheritance** | `currentWorkOffset = undefined` in `onOpen()` forces section 1 to emit its select unconditionally, so a stale selection in the sender cannot be inherited. The reasoning in the plan matches the code. |
| **Comment safety** | `writeComment()` sanitises `()` before wrapping in GRBL's `(…)`, and `askUser`/`display_text` sanitise `();` — so a tool comment or operation name containing a paren, semicolon or newline cannot break out into an active block. |
| **Multi-axis rejection** | `onSection` fails at the start of the offending operation, with `onLinear5D`/`onRapid5D` as a backstop. Good layering. (The *orientation* gap is HR-6 — a different check.) |
| **Radius compensation** | Rejected in `onRadiusCompensation` with an actionable message, and re-checked in `onCircular` and both rapid emitters. Thorough. |
| **Arc handling** | `maximumCircularSweep = toRad(180)` splits full circles into two arcs, avoiding the start==end quirk; `allowHelicalMoves = false` linearizes helices; Marlin's XY-only restriction is enforced in `circular()`'s `default: linearize()`. The `gPlaneModal` `onchange` → `gMotionModal.reset()` correctly re-emits G2/G3 after a plane switch, and survives `gMotionModal` being *reassigned* in `onOpen()` because the closure resolves the variable at call time. |
| **Canned cycles** | Expanding to `G0`/`G1` is the right call for all three firmwares, and the reasoning per firmware is documented at [:1820](../MPCNC_v4.0_Beta2.cps#L1820). Rejecting probing cycles rather than expanding them into non-probing motion is correct. (Subject to HR-2.) |
| **`Include Whitespace = false`** | `G0X10Y5F2500`, `G10L20P1X0Y0`, `M84Z` are all legal — these parsers are word-based. The prompt helpers re-insert a leading space where the message needs separating. |
| **Property dump** | Iterating `properties` rather than listing keys means it cannot drift; the zero-padded group strings make a lexicographic sort reproduce dialog order; enum values print as stored `id`s so relabelling does not break a saved review. `writeResolvedValues()`'s `describeSafeZ()` now genuinely resolves rather than restating. This is the single most valuable thing in the file for reviewability — every finding above was easier to reason about because of it. |
| **Probe pause threading** | `probePauseBefore`/`probePauseAfter` set by the caller and reset to `true`/`true` by `probeTool()` is fragile-looking but correct: every caller sets both immediately before invoking, and the reset keeps the tool-change re-probe prompting. |

---

## 5. Confidence statement

**What this review establishes by reading:** for HP-1 through HP-5, the *structure* of the emitted
file is correct — preamble ordering, WCS selection before any origin write, units and absolute mode
before any probe, comment syntax per firmware, arc and cycle handling, guard placement, and the
origin/probe dispatch for all six `First WCS / Part` modes. HR-1, HR-3, HR-4, HR-5, HR-7 and HR-11
are settled defects on documented hobbyist configurations; HR-8, HR-9, HR-10, HR-12, HR-13 and HR-14
are settled defects on reachable hobbyist configurations.

**What it cannot establish without posting:** HR-2 (kernel global availability) and HR-6 (whether
Fusion's `workPlane.forward` behaves as the reference posts assume for these sections) both need a
real post run. Neither can be resolved by reading the `.cps`.

**To reach "high confidence that the post outputs correctly formatted and structured g-code for a
hobbyist from all F360 entry points"**, three posts are needed beyond the fixes:

1. **A drilling operation** — the only way to exercise `onCyclePoint` at all (HR-2), and currently
   the largest unknown in the whole hobbyist surface. The existing H-series contains no cycle.
2. **An arc-bearing contour with `Scale Feedrate` on** (HR-5) — and it doubles as the first real
   check of `onCircular` against the feeds group.
3. **A multi-operation, multi-tool single-WCS job** (HP-5) — the persona the README explicitly
   sanctions and the H-series never posts. HR-7, HR-8, HR-9, HR-10 and HR-12 all live at boundaries
   only a multi-section job produces.

That third gap is the notable one. Every `PASS` row in `docs/test-plan.md`'s hobbyist block (H1–H7f)
is a **single-section** job, so every section-boundary behaviour in the post — tool change ordering,
the `forceSectionToStartWithRapid` lifecycle, position tracking across injected motion, spindle-speed
changes, WCS re-selection suppression — is currently unverified for this persona. The professional
rows (PB/PBV/PA) would cover some of it, but they are unrun and they change the WCS at the same
boundary, which confounds the two variables. A plain **HP-5 row** — two operations, two tools, one
WCS, no base — isolates them and is worth adding to the test plan regardless of which findings above
are actioned.

---

## 6. Suggested action order

1. ~~**HR-2**~~ **done** (uncommitted) — test-plan row **HR2** added, including (A2) tapping, which
   doubles as the first evidence for HR-17's parenthesis stripping. Unit-checked at the JS level; the
   posted half still wants a drill.
2. ~~**HR-1**~~ **done** — committed `8d61790` on `v4.0-hreview-fixes`; test-plan row **HR1** added,
   H1 / H2 / H6 / P1 marked superseded, H-REG's "no motion changed" claim retracted, and
   `plan.md`'s *Graceful degradation* principle amended a second time. One open decision it raised:
   whether the added-part jog probe should be treated symmetrically — see its *As built* note.
   ~~**HR-3**~~ **done** — test-plan row **HR3** added plus a blast-radius banner in the runbook
   conventions. Neither fix is verified by a post yet: **HR1** and **HR3** are both unrun.
3. ~~**HR-4**~~, ~~**HR-5**~~ **both done** — the two features the README tells the hobbyist to enable
   are now correct. HR-4 committed; HR-5 uncommitted. Test-plan rows **HR4** and **HR5** added.
   Neither invalidates an existing PASS row: HR-4 is the identity in mm, and HR-5's branch is gated
   on `Scale Feedrate`, which defaults off.
4. ~~**HR-6**~~ **done** (uncommitted) — test-plan row **HR6** added; run its regression half before
   anything else, since a false positive would block all posting. **HR-10**, **HR-13**, **HR-14**
   still open — independent, small, each closes a silent failure.
5. **HR-7**, **HR-9**, **HR-12** — group-07 behaviour. Consider folding into the Phase-4 tool-change
   ordering work already scoped in `docs/plan.md` rather than patching twice.
6. **HR-8** — do last, behind a motion-only diff of H2/H5/H7/H7c, and prefer the narrow variant if
   anything moves.
7. **HR-11** — needs the `M84` vs `M84 S60` decision before it lands.
8. **HR-15**, **HR-16**, **HR-17** — tidy-ups, any time.

Per the standing rule at the top of `docs/test-plan.md`, each of these lands with its Do→Get row in
the same commit as the code change.
