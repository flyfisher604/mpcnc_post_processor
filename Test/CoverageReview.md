# Coverage review — `MPCNC_v4.0_Beta2.cps`

A pre-Beta review of the **current source only**, for evidence of correctness in the operational sense:
that the emitted G-code **executes** on the selected firmware, and that it is **faithful** to what Fusion
asked for.

**Nothing was executed.** No posting, no harness, no machine. The method is hand-execution of the callback
sequence against the source, tracking module state as it changes.

**The toolpath is not re-derived.** Fusion's geometry is taken as correct; CAM-driven motion is judged on
fidelity of translation, post-generated motion on the full safety test.

**Out of scope by decision:** laser / plasma / jet paths — `laserOn`, `laserOff`, `onPower`, the group-9
properties, and the jet arms of `onCommand` / `writeWcsOnStart` / `writeBaseEstablish`. Drilling is in
scope. Everything unwalked is listed in *Unwalked code* rather than left implied.

---

## The six invariants each walk is checked against

- **I1 Frame.** Every absolute `X`/`Y`/`Z` word is interpreted in the WCS active at that block. An absolute
  `Z` is only emitted into a frame whose Z0 this job established or the operator declared.
- **I2 Motion safety** — post-generated motion only. No traverse crosses the bed at an unknown Z; Z-down is
  ordered after XY, Z-up before it. For CAM-driven motion the test is fidelity instead.
- **I3 Modal truth.** Every belief the post caches matches what the controller would hold — across include
  files, `G53` blocks, `G38.2` blocks and WCS switches, all written through raw formats.
- **I4 Dialect.** Every emitted `G`/`M`/`$` code exists and means the same thing on the firmware selected.
- **I5 Guard fidelity.** Each `error()` / `warning()` / `writeWarning()` fires on exactly the condition that
  makes the emitted code wrong, and fires before the output it protects.
- **I6 Units.** Every dialog dimension is millimetres and passes `propertyMmToUnit()` exactly once.

## The licence dimension

Fusion **Personal** emits every rapid as a feed move: `onRapid` is never called and those moves arrive at
`onLinear` at a cutting feedrate. Fusion **Full** emits real rapids. Group 3 exists for that difference, so
every Direction-1 story is walked under both. All four cells of licence × `Map G1s -> G0` are covered:
A1/A3 (Full, off), A2 (Personal, on), A2′ (Personal, off), A2″ (Full, on).

---

## Story ledger

`P` = Fusion Personal, `F` = Full.

### A — Hobbyist baselines

| ID | Firmware | Homed | Shape | Lic | Status |
|---|---|---|---|---|---|
| **A1** | GRBL | None | J1 | F | walked |
| **A2** | GRBL | None | J2 | P | walked |
| **A2′** | GRBL | None | J2 | P | walked |
| **A2″** | GRBL | None | J2 | F | walked |
| **A3** | GRBL | None | J2 (2D) | F | walked |
| **A4** | Marlin | None | J2 | F | walked |
| **A5** | RepRap | XY / `Home` | J2 | F | walked |

### B — Machine frame and homing

| ID | Firmware | Homed / action | Shape | Lic | Status |
|---|---|---|---|---|---|
| **B1** | GRBL | XY / `Off` | J1 | F | walked |
| **B2** | GRBL | XYZ / `Pause, then Home` | J4 | F | walked |
| **B3** | Marlin | XYZ / `Home` | J1 | F | walked |
| **B4** | GRBL | `Z Only` → `None` → `XY` | J1 | F | walked |
| **B5** | GRBL | None / `Home` | J1 | F | walked |
| **B6** | GRBL | XY / `Home` | J1 | F | walked |

### C — Multi-part, multi-WCS, spoilboard base

| ID | Firmware | Homed | Shape | Lic | Status |
|---|---|---|---|---|---|
| **C1** | GRBL | XY / `Home` | J4, G54–G56 | F | walked |
| **C2** | RepRap | XY / `Home` | J4, G59.1–G59.3 | F | walked |
| **C3** | GRBL | XY | J4 | F | walked |
| **C4** | Marlin | any | J4 | F | walked |
| **C5** | GRBL | XY | J5 | F | walked |
| **C6** | GRBL | XY | J4 | F | walked |
| **C7** | GRBL | XY | J3 | F | walked |
| **C8** | GRBL | XY / `Home` | J6 | F | walked |

### D — Operation mix and Manual NC

| ID | Firmware | Shape | Lic | Status |
|---|---|---|---|---|
| **D1** | GRBL | J2, drilling | P | walked |
| **D2** | Marlin | J2, drilling | F | walked |
| **D3** | GRBL | J2, probing operation | F | walked |
| **D4** | GRBL | J5, 3 tools | F | walked |
| **D5** | GRBL | J1 + Manual NC | F | walked |
| **D6** | GRBL | J1, rejected inputs | F | walked |
| **D7** | GRBL | J2, arcs | F | walked |

### E — Units, coolant, parsing, re-entry

| ID | Covers | Status |
|---|---|---|
| **E1** | Inch-unit job, every `propertyMmToUnit` site | walked |
| **E2** | Coolant, both channels, custom files | walked |
| **E3** | Second file in one JavaScript context | walked |
| **E4** | Safe-Z expression parsing | walked |
| **E5** | Include files | walked |

### Cross-cutting sweeps

| ID | Covers | Status |
|---|---|---|
| **S1** | Property cross-reference — every entry in `properties`, every read site | walked |
| **S2** | Guard and warning inventory | walked |
| **S3** | Emission inventory × three firmwares | walked |
| **S4** | Fusion API contract | walked |

---

## Walks

### A — Hobbyist baselines

**A1 — GRBL, no endstops, single operation, all defaults.** `validateJob()` fires nothing: `homesAtJobStart()`
is false so the three group-4 warnings are dead, `startMode` is `Current XY & Probe Z` so the stored-offset
warning does not apply, `fixedZEstablishedInFile()` is false so the fixed-Z warning is dead, park is `Work`,
one tool, both Safe-Z expressions parse. Guards: no include files, `Fixed Z Reference` and `Reserved WCS`
agree at None/None, park is not `Machine`, firmware is not Marlin, `base == 0` and `collectDistinctOffsets()`
has length 1 so Guard B does not apply. Clean no-fire, as intended.

`onOpen()` then rebuilds `gMotionModal` unforced (GRBL), `fOutput` forced (`Enforce Feedrate` on), sets the
word separator, and parses both Safe-Z properties to `{RETRACT, 15}`.

The emitted preamble, in order: the four `onParameter` header comments; `writeInformation()`'s ranges table,
tool table, full property dump and resolved-values block; `writeMachineHoming()` emitting nothing;
`writeWCS()` → `G54` (offset 0 aliased to 1, `isTraverse` false so no retract and no origin dispatch);
`Start()` → `G90`, `G21`, `G94`, `G17`; `writeFixedZReference()` emitting nothing; `writeWcsOnStart()` →
`G10 L20 P1 X0 Y0 Z0` (provisional), then `partProbe(true)` with no offset move, then `probeTool()` →
`M0 (MSG Attach ZProbe)`, `G38.2 F30 Z-10`, `G10 L20 P1 Z0.8`, `resetAll()`, `G0 Z15 F300`,
`M0 (MSG Detach ZProbe)`. Then the section body, then `onClose()` → coolant off (no-op),
`M0 (MSG Turn OFF spindle)`, `G0 X0 Y0 F2500`, `M30`.

I1–I3 hold throughout. The provisional `Z0` write before the probe is what makes `G38 Target = -10` a
relative travel limit rather than an absolute position, and it is the only path in the post that does this —
see CR-11 and CR-12. I4 produced **CR-01** and **CR-02**.

Feed handling checks out under `Enforce Feedrate` on: `fOutput` is forced, so every motion block carries `F`
and the modal feed the post tracks and the one the controller holds cannot diverge. With it off (walked in
A3) the post still tracks exactly the `F` values it emitted, including the `F` it writes onto `G0` blocks, so
suppression stays correct.

**A2 — Personal licence, `Map G1s -> G0` on, `Safe Z to Rapid` = `Retract:15`, comment level Debug.** This is
the intended hobbyist configuration. `parseSafeZProperty()` takes the RETRACT arm; `safeZforSection()` is
called once per section from `onSection()` (after `writeFirstSection()`, before any motion, so `safeZHeight`
is never read undefined) and all four of its RETRACT sub-arms are reachable: absolute level, non-absolute
level, level not defined, and the ERROR arm via a malformed expression.

`isSafeToRapid()`'s three true-branches and its fall-through all behave as documented:

- `zConstant` — a horizontal move at or above safe Z becomes `G0` whatever XY does. Intended.
- `zUp && xyConstant` — a pure retract becomes `G0`.
- `!zUp && xyConstant && curZSafe` — a pure descent that both starts and ends in safe air.
- everything else — including any move that changes Z *and* XY — stays `G1`. Correct: that is the only
  class that can be cutting.

The rounding rule is sound. Both compared positions go through `roundTo(_, 3)` (mm) / `roundTo(_, 4)` (inch),
so two positions that format to the same G-code compare equal; `safeZHeight` itself is deliberately not
rounded, which only ever makes the boundary test more permissive by half a display unit. `describeSafeZ()`
reports `varies by operation` across J2's differing retract levels, resolving each section through
`resolveSafeZHeight(mode, dflt, getSection(i))` — the passed-section form, which is required because
`writeResolvedValues()` runs from the header where no section is current.

At Debug level `isSafeToRapid()` writes three comment lines per `onLinear`. That is a Debug-level cost and
correct as designed, but it means a Debug post of a real job is several times the size of the same job at
Info.

**A2′ — same job, `Map G1s -> G0` off.** The unrecovered Personal stream. Every positioning move stays a
`G1` at a cutting feedrate, and with `Scale Feedrate` on those feeds are additionally reduced by
`limitFeedByXYZComponents()`. Slow, but not unsafe: nothing is emitted that Fusion did not ask for, and no
move is *raised* above the CAM's feed.

The zero-length arm of `limitFeedByXYZComponents()` — reached when `curPos == destPos` — was walked and does
**not** survive as a defect. It returns `min(xyLimit, zLimit)` (180 on the defaults) capped at the requested
feed, but the block that value would ride on emits no `X`/`Y`/`Z` word, so `linearMovements()` falls into its
`else if (f)` arm: either `getNextRecord().isMotion()` is true and `fOutput.reset()` discards the value
before it reaches the file, or a bare `G1 F180` is written that the next motion block (which carries its own
`F` under `Enforce Feedrate`, and an accurately tracked one without it) immediately supersedes. No move ever
executes at that feed.

The sequential `multiply()` composition in `limitFeedByXYZComponents()` is correct. Each test reads the
already-scaled vector, and because every step only reduces, the composed factor is exactly
`min(1, zLimit/z, xyLimit/x, xyLimit/y)` — the largest feasible scale, with every axis component at or below
its limit and the result never above the requested feed (`|dir| = 1`, so `|xyzFeed|` starts at `feed` and only
shrinks). The trailing `Math.abs(newFeed - feed) > 0.01` test returns the original feed for changes below one
hundredth of a unit, which is below `fFormat`'s resolution in mm and at it in inches. Per-axis projection was
checked for a pure-Z plunge, a shallow ramp, a steep ramp, pure XY, a 45° XY diagonal and a 3-axis diagonal;
the toolpath cap (`feedsMaxCutSpeedXYZ`) was checked on a diagonal that satisfies both axis limits and still
exceeds it.

**A2″ — Full licence, `Map G1s -> G0` on.** The misconfiguration group 3's title warns about. Real `G0`s
arrive at `onRapid`, which clears `forceSectionToStartWithRapid` before any `onLinear` sees it, so the
first-move conversion is usually inert here — but genuine cutting `G1`s are still offered to
`isSafeToRapid()` on every move, and nothing in the code, the dialog or the file says the job is
misconfigured. **CR-03**, **CR-04**.

**A3 — `Scale Feedrate` off, `Use Arcs` off, `Enforce Feedrate` off, comment level Off, line numbers on,
whitespace off, `First WCS / Part` = `Set X0 Y0 Z0 to Current Pos`, 2D job.** Both scaling functions
early-return their argument untouched, so Fusion's feeds reach the file exactly. `circular()` takes the
`linearize(tolerance)` arm before any plane logic, so `gPlaneModal` is never formatted and no `G17`/`G18`/`G19`
is emitted after `Start()`'s. `writeBlock()` takes its `writeWords2("N" + sequenceNumber, …)` arm, and
`setWordSeparator("")` produces `N10G0X0Y0F2500` — valid, and the three sites that prepend a manual space
(`display_text`, `askUser`, both `M291`/`M0`/`M117` forms) keep their message separated from the code word.

Comment level Off suppresses every `writeComment()` — `commentLevels.indexOf(level) <= indexOf("Off")` is
false for Important, Info and Debug — while `writeWarning()` still emits, which is the documented and correct
split. `is3D()` false leaves `toolZRanges` empty, so the tool table prints no `ZMIN` column; nothing else
reads it. `writeWcsOnStart()`'s `Current XYZ` arm writes `G10 L20 P1 X0 Y0 Z0` and emits no probe and no
motion at all.

Line numbers interact with exactly one emission: `writeMachineHoming()`'s `$H` goes through `writeln()` and
so carries no `N` word, which is required — GRBL recognises `$` only as the line's first character — and
leaves a deliberate gap in the numbering.

**A4 — Marlin, `Manual Spindle` off, `Probe with G38.2` off, tool changes on with relocation +
`Do First Change` + `Probe After Tool Change`, 2 tools, Setup work offset G56.** `onOpen()` takes the
`createModal({force: true})` arm, so every motion block carries its `G` word. `writeWCS()` takes the Marlin
arm: `workOffset` 3 > 1 and differs from `currentWorkOffset` (undefined), so the unsupported-offset warning
fires once, `currentWorkOffset` is set to 3 and **no WCS select is emitted** — correct, since Marlin has
none. `Start()` takes the non-GRBL arm: `G90`, `G21`, `M84 S0`, and deliberately no `G94`/`G17`.
`writeWcsOrigin()` takes the `G92` arm. `probeTool()` takes the `G28 Z` arm. `askUser()` takes the default
arm (`M0 <text>`), `display_text()` emits `M117`. `spindleOn`/`spindleOff` take their commanded arms
(`M3 S…` / `M5`). `onClose()` takes the non-GRBL arm: `M117 Job end`, `M84 S60`, and no `M2` (RepRap only).

Three findings here. The ordering of `writeFirstSection()` against the `Do First Change` tool change is
**CR-06**; the WCS the post-tool-change re-probe writes into is **CR-07**; `M84 Z` under `Disable Z Stepper`
is **CR-08**, and Marlin's `M3`/`M5` build gating is **CR-09**.

One interaction worth recording because it silently disables a group-3 feature: `toolChange()`'s relocation
path calls `onRapid()`, which clears `forceSectionToStartWithRapid`. On any section that changes tool with
`Include Relocation Code` on, the first-move conversion therefore never runs — the property is on, and for
that section it does nothing.

**A5 — RepRap, XY homed with `Home`, `First WCS / Part` = `Jog to X0 Y0, Probe Z0`, start and stop include
files named.** `duetMillingMode` is emitted on the first section (`machineMode` starts undefined) and not
again while the type is unchanged. `askUser()` takes the `M291 P"…" R"…" S3` arm and, on the jog dispatch,
appends `X1 Y1 Z1`; `warnJogAtPauseOnGrbl()` correctly does not fire off GRBL. `writeMachineHoming()` takes
the `G28 X` / `G28 Y` arm and skips `G28 Z` (Z not declared). `loadFile()` is walked at both sites: the
trailing-newline repair, the empty-file arm, and the three modal resets (`gPlaneModal`, `gMotionModal`,
`resetAll`) that follow a successful include. `onClose()` takes the include-stop arm, so the `G17` assert
(GRBL-only) is skipped and the built-in footer — coolant off, spindle stop, park, `M84 S60`, `M2` — is
replaced wholesale, which is what the property says it does.

The start-file replacement is **CR-05**: `Start()` is skipped entirely, and `G90`/`G21` are emitted from
nowhere else in the post.

### B — Machine frame and homing

**B1 — XY declared, `Home at Job Start` = Off, `First WCS / Part` = `Use Active WCS X0 Y0, Probe Z0`, park
Machine, Setup offset G56.** The property set as specified **does not post**: `At End Park At` = Machine on a
non-Marlin firmware with `Home at Job Start` = Off hits the guard at `validateJob()` — machine X0 Y0 is a
`G53` rapid addressing a frame the job must have established. That is the guard behaving exactly as designed,
and it is the reason the story exists, so it is recorded as a pass rather than a finding. Re-walked with park
= Work to reach the rest:

`writeWcsOnStart()`'s `Probe Z` arm calls `partProbe(false, true)`. `atOrigin` is false so the reposition
block runs; `zUnknown && !fixedZEstablishedInFile()` is true so the "no Z reference is established" warning
is emitted **before** the `G0 X0 Y0` it protects — correct ordering under I5 — and the traverse runs at
whatever height the operator left the tool at, which is precisely what the warning says. `validateJob()`'s
twin (the `startMode == "Probe Z" && !fixedZEstablishedInFile()` warning) fires in the dialog with the same
content, so the operator gets it before posting as well as in the file. The stored-offset warning does not
fire, correctly: X/Y is declared homed, so a stored `G56` origin is repeatable across a power cycle.

**B2 — XYZ declared, `Pause, then Home`, J4, `Fixed Z Reference` = Machine Z, `Inter Part Travel Z` = -12,
park Machine, retract-across-parts on, line numbers on.** Both applicable warnings fire and both are true:
homing runs before the default `Current XY & Probe Z` records the origin, and the machine-Z establish moves
the tool to -12 before that same record. Walking the emission confirms the second one concretely — the
provisional `G10 L20 P1 X0 Y0 Z0` is written with the tool at machine Z -12, so the `G38.2 F30 Z-10` that
follows searches ten millimetres below bed clearance and never touches the stock. `validateJob()`'s guard
fidelity is good here: the configuration is warned about rather than posted silently.

`promptsBeforeHome()` produces one `M0 (MSG Prepare machine for homing)` before any homing motion, then
`writeln("$H")` — no `N` word, correct. `writeFixedZReference()` takes the machine-Z arm and
`writeMachineTravelZ()` emits `G53 G0 Z-12 F300` as a single block: `G53` is programmed on the same line as
`G0` (required — it is an error without `G0`/`G1` active) and nothing is appended to it (required — `G53` is
not modal). The `G0` goes through `gFormat`, not `gMotionModal`, so it cannot be suppressed when `G0` is
already the active mode; `gMotionModal.reset()` afterwards forces the next `G` word. The `resetAll()` before
the block is inert (every word in it is written through a raw format) and the one after is load-bearing. I3
holds: after a machine-frame move the post claims to know no work-frame coordinate.

The inter-part traverse takes `writeWCS()`'s `machineFrame` route — `G53 G0 Z-12 F300` **before** the new
`G55` is selected, which is correct because the machine frame is independent of the work offset. Then
`partProbe(false)` emits `G0 X0 Y0 F2500` at that machine height and probes. I1 and I2 hold across the
traverse.

The end park is **CR-10**.

**B3 — Marlin, XYZ, `Home`, park Machine, `Fixed Z Reference` = None.** `writeMachineHoming()` emits
`G28 X`, `G28 Y`, `G28 Z` — the genuinely independent per-axis form. `writeMachineParkXY()` takes the Marlin
arm: `parkCanRetract()` is false (it is `fixedZEstablishedInFile()`, which excludes Marlin unconditionally),
so the no-retract warning fires, then `G28 X` / `G28 Y` re-establish the frame rather than addressing it. The
firmware split is right: Marlin needs no prior homing for this because it is a homing cycle, which is exactly
why `validateJob()`'s `homesAtJobStart()` requirement is `fw != MARLIN`-gated while the `machineHomesXY()`
requirement is not.

**B4 — machine-Z guards, one at a time.** With `Fixed Z Reference` = Machine Z: `Z Only` passes
`machineHomesZ()`, passes the homing-action guard, passes or fails the `Inter Part Travel Z` parse, and then
fails the homed-X/Y guard — each guard firing on its own condition, in the documented order, with the axis
guard reached only after the frame guards. Flipping the declaration to `None` or `XY Only` fails at
`machineHomesZ()` instead, before any of the others. No guard subsumes another and none is unreachable.

**B5 — `Home at Job Start` set, `Axes Homed and Trusted` = None.** The pair cannot disagree: both
`validateJob()`'s warning and `writeMachineHoming()`'s `writeWarning()` test the identical expression
(`homesAtJobStart() && !homedXY && !homedZ`), and `writeMachineHoming()` returns without emitting motion on
exactly that branch. Dialog and file say the same thing.

**B6 — `First WCS / Part` = `Set X0 Y0 to Current Pos, Probe Z0` with homing on.** The "homing destroys the
pre-jog" warning fires on `homesAtJobStart() && (homedXY || homedZ) && startMode in {Current XY & Probe Z,
Current XYZ}`. With the action set back to Off it does not fire, and correctly so — the declaration alone
moves nothing. Either axis group qualifies, which is right: X/Y homing destroys the pre-jogged XY and Z
homing destroys the height that becomes Z0.

### C — Multi-part, multi-WCS, spoilboard base

**C1 — GRBL, XY homed with `Home`, J4 across G54–G56, `Fixed Z Reference` = Spoilboard, `Reserved WCS` = G59,
`Probe to Set Base` = `Pause, Probe Z, Pause`, `Inter Part Travel Z` = 40, `Subsequent WCS / Part` = `Probe Z`,
probe XY offset 10/10, `Probe Pause` = `Before & After`.** Guard A does not fire (no section is assigned to
G59 and no origin write targets it), the reserve/reference agreement guards pass, and the positive-travel-Z
guard passes.

`writeBaseEstablish()` walks its full path: `operatingWcs` is 1, `switched` is true, so it transit-selects
`G59` with a bare `writeBlock` (not `writeWCS()` — R2's rule, so no re-probe and no origin write), calls
`resetAll()` because the frame changed, sets both pause flags from `Pause & Probe Z`, probes with
`probeTool(6, interPartTravelZ())`, then restores `G54` and resets again. R1 holds: the base is never left
active. The retract after the probe uses `Inter Part Travel Z` rather than `probeSafeZ()`, correctly — it is
the base's own frame and it has to clear the stock.

Two things in that sequence are findings. The probe target is **CR-11**; the tool-0 skip is **CR-14**.

The traverse to the second part takes `writeWCS()`'s `baseRelative` route:
`retractThroughBaseClearance()` selects `G59` (skipping the select when the base is already active),
`resetAll()`, `G0 Z40 F300`, then the new `G55` is written and `currentWorkOffset` updated — the base is
never left selected across a cut. `partProbe(false)` then emits `G0 X10 Y10 F2500` at that height in the new
frame, which is safe: the physical height is 40 above the probed spoilboard whatever the new part's
thickness, which is the entire point of the fixed reference. The probe-offset traverse is walked at both
sites (`partProbe()` and `writeWcsOnStart()`'s pre-traverse retract), and `probeOffsetIsSet()` is the single
definition both consult, so they cannot disagree about when the traverse happens.

The story as specified leaves `First WCS / Part` at its default, and the walk shows why that combination is
warned about: **CR-15**.

**C2 — RepRap, J4 across G59.1–G59.3, `Fixed Z Reference` = Spoilboard with `Reserved WCS` = G59.1,
`Subsequent WCS / Part` = `Use Active WCS X0 Y0 Z0`, `Probe Pause` = No.** `wcsGcode(7)` returns `59.1` and
`gFormat`'s single decimal renders `G59.1`; `wcsName(7)` returns the same string through a different
expression, and the two agree for 7, 8 and 9. The RepRap-only slot guard passes here and, re-walked with the
firmware flipped to Grbl, produces the error — so both arms are covered. `writeWCS()`'s `Skip` arm emits
`resetAll()` + `G0 X0 Y0 F2500` after the base retract, X/Y only, so the clearance height survives the move:
correct. `Probe Pause` = No is reached through the first part's probe and suppresses both `askUser` calls in
`probeTool()` while leaving the probe itself intact.

**C3 — `Fixed Z Reference` = None, multi-WCS, retract-across-parts on then off.** On: Guard B errors, as
designed — across offsets whose numeric relation is only known after runtime probing, no single clearance
height is meaningful. Off: the guard does not apply and `writeWCS()` falls through to its bare `isTraverse`
retract. That fall-through is **CR-13**.

**C4 — Marlin, J4.** Guard C errors on `collectDistinctOffsets().length > 1` and then `return`s, so Guard B,
the RepRap slot check and Guard A are all skipped. Walking what that skip costs: the only Marlin job that
reaches past Guard C is a single-WCS one, and for such a job Guard B is inapplicable (it requires multi-WCS)
and Guard A is inapplicable (no section can change to the base). The slot check is genuinely skipped — a
single-WCS Marlin job may reserve `G59.1` — but the reservation never emits anything: `writeBaseEstablish()`
warns and returns on Marlin, and `fixedZEstablishedInFile()` is false there, so every consumer that reasons
about the tool's height behaves as if no reference exists. The skip is sound.

**C5 — J5, tool changes on with `Probe After Tool Change`, `Reserved WCS` set to a WCS a part is assigned
to.** Guard A fires through all three of `baseOriginWriteReason()`'s triggers, each independently reachable:
section 0 on the base with `First WCS / Part` not `Skip`; a later section changing to the base with
`Subsequent WCS / Part` not `Skip`; and a tool change on a section assigned to the base with
`Probe After Tool Change` on. The interleave itself — `toolChange()` running before `writeWCS()` — is
**CR-07**, including its effect on this guard.

**C6 — `Subsequent WCS / Part` = `Jog to X0 Y0, Probe Z0` and `Jog to X0 Y0 Z0`.** Both arms of `writeWCS()`
call `warnJogAtPauseOnGrbl()` at the dispatch site before `askUser()`, so the file carries the warning ahead
of the `M0` it describes. `validateJob()`'s twin gates the subsequent-part half on `multiWcs` and the
first-part half not at all, which matches where each control is actually read — `Subsequent WCS / Part` is
consulted only on a genuine traverse. The two cannot disagree.

**C7 — J3: one part, several operations, several WCS.** Nothing refuses it and nothing distinguishes it from
J4. **CR-16**.

**C8 — J6: G54 → G55 → G54, `Fixed Z Reference` = Spoilboard, `Subsequent WCS / Part` = `Probe Z`.**
`writeWCS()`'s suppression is `workOffset == currentWorkOffset`, so the return to G54 is *not* suppressed:
it takes a full base-relative retract, re-selects `G54`, and re-probes. Frame handling is correct throughout.
What the re-probe overwrites is **CR-17**.

### D — Operation mix and Manual NC

**D1 — GRBL, drilling, Personal licence, with `Map G1s -> G0` on.** `onCyclePoint()` rejects probing
operations and otherwise calls `expandCyclePoint()`, so drill / peck / bore / tap all arrive as ordinary
`onRapid` / `onLinear` / `onDwell` streams. The interaction with group 3 is the interesting part, and it
comes out right for every move of a plain drill cycle: the inter-hole traverse has Z constant at or above
Safe Z and becomes `G0`; the retract has XY constant and Z rising to a safe height and becomes `G0`; the
plunge has a destination below Safe Z, so `zSafe` is false and it stays `G1` at the CAM's feed. A peck
cycle's intermediate retracts stop below Safe Z and therefore stay `G1` — slower than they need to be, but
never a rapid into a hole. The only conversion that is not reasoned about is the section's first move
(**CR-04**).

Feed scaling on the plunge is the case group 2 exists for: `dir.abs` is `(0,0,1)`, `xyzFeed` is `(0,0,feed)`,
and any feed above `Max Z Cut Speed` scales to exactly that limit — 180 on the defaults. `onDwell()` takes
the GRBL `G4 P<seconds>` arm with `secFormat`'s three forced decimals.

**D2 — Marlin, drilling.** `onDwell()` takes the `G4 S<seconds>` arm. `rapidMovements()`'s ordering holds
across the whole expanded cycle: every move with a descending destination emits XY first and Z second, every
other move emits Z first. Since `getCurrentPosition()` is read once at entry and the kernel updates it after
each callback, the comparison is against the true pre-move position for every point of the cycle.

**D3 — a WCS / inspection probing operation.** Both of `isProbeOperation()`'s signals were checked
independently: `operation-strategy == "probe"` names the operation as a whole, and `String(cycleType)`
beginning `"probing"` names each point. Either alone identifies the ordinary cases; together they need no
per-cycle list. `cycleNotSupported()` is reached instead of `expandCyclePoint()`, which is right — expansion
would emit plain `G0`/`G1` with no `G38` at all, i.e. a probing operation silently turned into motion.

**D4 — J5, three tools.** With `Tool Changes are Included` off, `toolChange()`'s `writeWarning()` fires per
occurrence and `validateJob()`'s twin fires once in the dialog on `countDistinctTools() > 1`. The pair is
consistent for the case it was built for, and asymmetric in one corner: **CR-20**. With tool changes on and
`Include Relocation Code` off, the bare `M6 T<n>` route is **CR-18**, and what that route does not do is
**CR-19**.

**D5 — Manual NC.** `onPassThrough()` splits on `\r?\n`, skips empty lines and emits each remaining line
through `writeBlock()` — so line numbers are applied and the text is otherwise untouched, which is what
pass-through is for. `onComment()` maps to an Important-level comment, so it survives every comment level
except Off. `COMMAND_STOP` emits a bare `M0`; unlike every prompt in the post it carries no `(MSG …)`, so on
GRBL the operator sees a pause with no reason given — worth a message, not worth a finding.
`COMMAND_ACTIVATE_SPEED_FEED_SYNCHRONIZATION` and its deactivate twin both route to
`writeSpeedFeedSyncWarning()`, warning on every occurrence so that every affected move in the file is
flagged. Manual NC dwell reaches `onDwell()`.

**D6 — rejected inputs.** `onRadiusCompensation()` stores the pending mode and errors for anything but
`RADIUS_COMPENSATION_OFF`; `onCircular()` errors again if compensation is pending; `onSection()` errors on
`isMultiAxis()`; `onRapid5D`/`onLinear5D` error as a backstop. `isSectionOrientationSupported()` was walked
through all four traces — `workPlane` missing, `forward` missing, non-numeric components, and a readable
vector — and it fails open exactly as its comment claims: it errors only when the orientation is readable
**and** unambiguously off machine +Z, and every path emits its Debug trace, so "read nothing" and "read +Z
and allowed it" are distinguishable in the file.

**D7 — arcs.** All three GRBL planes are walked. `gPlaneModal`'s `onchange` resets `gMotionModal`, and
because `writeBlock(gPlaneModal.format(18), gMotionModal.format(2), …)` evaluates its arguments left to
right, the reset lands before the motion word is formatted — so a plane change always re-emits `G2`/`G3`.
That ordering is load-bearing and undocumented at the call site. `iOutput`/`jOutput`/`kOutput` are reference
variables formatted against the arc start, and the word pairs are correct per plane: I/J for XY, I/K for ZX,
J/K for YZ. `maximumCircularSweep = toRad(180)` splits full circles into two arcs upstream, and
`allowHelicalMoves = false` linearizes helices, so only planar partial arcs reach `circular()` — which is
what makes the unconditional `zOutput.format(z)` in the XY arm harmless (z equals the start z, so the word
is suppressed). `limitArcFeed()` applies the XY limit to an XY arc and the lesser of XY and Z to a ZX/YZ arc,
then the toolpath cap; the deliberate conservatism is correct, since on an arc the instantaneous axis
velocity reaches the full toolpath feed at the quadrant points and a chord projection would under-protect.
The Marlin cross-check confirms non-XY arcs take `linearize(tolerance)` and re-enter through `onLinear()`,
where they are feed-limited the usual way — and, if group 3 is on, are also offered to `isSafeToRapid()`
segment by segment (**CR-03**).

### E — Units, coolant, parsing, re-entry

**E1 — inch-unit job, GRBL, `Fixed Z Reference` = Machine Z.** Every `propertyMmToUnit()` site was traced for
double conversion and for omission, and the contract holds throughout: the dialog literal converts exactly
once, and an F360 level value (which arrives already in the output unit) never converts. The subtle pair is
`describeSafeZ()`, which converts `dflt` for display **and** hands the raw millimetre value to
`resolveSafeZHeight()`, which does its own conversion — two conversions of the same number for two different
purposes, neither compounding. `probeSafeZ()` and `interPartTravelZ()` are both documented as returning
output units and no caller wraps them again. `xyzFormat`'s four decimals and `fFormat`'s two are selected
from `unit` at load time, which is correct for a single file and is the one place E3 bites.

Emission checks out in inches: `G20`; `G53 G0 Z-0.4724` for a -12 mm travel height, read in the active unit
as `G53` requires; `Plate Thickness` 0.8 mm as `Z0.0315`; `G38 Target` -10 mm as `Z-0.3937`; the travel
speeds as 98.43 and 11.81 in/min; and the three group-2 limits converted inside the scaling maths before any
comparison, so the projection is done entirely in output units.

**E2 — coolant.** GRBL with a Flood tool and `Channel A Mode` = Flood emits `M8` at `COMMAND_COOLANT_ON` and
`M9` at `onClose()`. Marlin's `M42 P6 S255` / `M42 P6 S0` pair is emitted verbatim, which is why the property
descriptions insist the dialect must match the firmware — the post does not check. `Use custom` with a named
file routes through `loadFile()` and inherits its missing-file error and trailing-newline repair; with an
empty name it emits `writeWarning()` and nothing else. A tool coolant no channel matches reaches
`setCoolant()`'s "No matching Coolant channel" warning. Both channels configured for the same coolant both
fire, both set `curCoolant`, and the warning is correctly suppressed. `tool.coolant` maps through
`coolantLevels`, whose index is the Fusion constant, and an out-of-range value falls back to `Off` — silently,
since `setCoolant(Off)` from an already-off state returns before the warning; the array covers all nine codes
Fusion defines, so this is a dead corner rather than a defect. Coolant is switched off at `onClose()` and at
a relocation-route tool change; the `M6` route is **CR-19**.

**E3 — a second file posted in one JavaScript context.** `resetPostState()` is thorough about values and
incomplete about formatters: **CR-21**.

**E4 — Safe-Z expression parsing.** `parseSafeZExpr()` was walked against `15`, `15.5`, `Retract:15`,
`Feed:2`, `Clearance:40` (all accepted, case-insensitively on the prefix), and against `""`, `Retract:`,
`-5`, `15mm`, `Retract:15mm`, `.5` and `abc` (all reaching the ERROR arm with a 15 mm fallback, which is what
`validateJob()`'s warning describes). Both properties share the function, so the two that document each other
as "same syntax" cannot drift; the ERROR arm is reported from `parseProbeSafeZProperty()` once per job for
the probe property and from `safeZforSection()` once per section for the map property — an asymmetry in
volume, not in content. `resolveSafeZHeight()`'s non-absolute-level fallback is reached whenever
`…_absolute != 1`, and its three level parameters are the only difference between its arms.
`describeSafeZ()`'s single-value and `varies by operation` arms are both reachable; its
"no operations to resolve against" arm is not (see *Unwalked code*). `roundTo()` is correct at very small
magnitudes — the plain-arithmetic form has no exponent-string failure. `parseInterPartTravelZ()` accepts
`-12`, `+40`, `0` and surrounding whitespace, and rejects `""`, `.5`, `5.`, `1e3` and `40mm`, returning
`undefined` for each, which `validateJob()` turns into a refusal under both non-None answers. One value it
accepts that it arguably should not is **CR-23**.

**E5 — include files.** `validateJob()`'s pre-flight checks `Start GCode File` and `Stop GCode File`
unconditionally and the two tool-change files only when `Tool Changes are Included` is on — matching where
they are read. A missing file is refused before any output; a missing file that escapes the pre-flight
reaches `loadFile()`'s own `error()` after the header is already in the stream, which is why the pre-flight
exists. An empty file writes an Info comment and — correctly — performs no modal reset, since nothing was
written. A file with no trailing newline gets a `writeln("")` so the next block cannot merge onto its last
line. After any non-empty include, `gPlaneModal`, `gMotionModal` and the coordinate/feed variables are all
reset, so the post re-asserts lazily rather than trusting beliefs a foreign file may have invalidated. The
start file replacing `Start()` is **CR-05**; the four coolant custom files are **CR-22**.

### The four sweeps

**S1 — property cross-reference.** `properties` holds **67** entries: job 8, feeds 7, mapRapids 2, machine 3,
spoilboard 5, probe 10, toolChange 8, include 5, laser 7, coolant 10, duet 2. Excluding group 9, **60** are in
scope. Every key was counted against its `getProperty(properties.<key>)` read sites across the whole file:

- **Declared but never read: `includeProbeFile`, and only that one.** Confirmed by exhaustive count — it is
  the sole property with zero read sites, and both its title and description say so.
- **Read on a path the dialog cannot reach: none.** Every in-scope property has at least one read site on a
  path a dialog-reachable configuration can take. The closest case is `spoilboardBaseReserve`, whose reads go
  through `getReservedBaseWcs()`, which returns 0 unless `Fixed Z Reference` = Spoilboard — but
  `validateJob()` refuses the disagreeing combination outright, so the property is never quietly inert.
- **Read but never validated:** `feedsTravelSpeedXY`/`Z`, the three group-2 limits, `probeG38Speed`,
  `probeOffsetX`/`Y`, `probeThickness`, `toolChangeX`/`Y`/`Z` and `jobSequenceNumberStart`/`Increment` are all
  emitted or compared with no range check. Fusion's `integer`/`number` types accept negatives and zero, so a
  `Max Z Cut Speed` of 0 collapses every scaled feed to zero and a negative `Plate Thickness` shifts Z0 the
  wrong way. None of these is a code defect on its own; the exposure is the same class as **CR-23**, and
  `Inter Part Travel Z` is the one dimension that *is* guarded — which is the argument that the others could
  be.
- **Read on a firmware where it has no effect, with nothing saying so:** `feedsTravelSpeedXY` and
  `feedsTravelSpeedZ` on GRBL (**CR-01**). `probeG382orG28` is the good counter-example: its description
  states plainly that GRBL ignores it. The four coolant code enums carry `Grbl:`/`Mrln:` prefixes in their
  titles, which is the pattern the travel speeds lack.

**S2 — guard and warning inventory.** 16 `error()` sites, 10 `warning()` sites, 13 `writeWarning()` sites.
All 26 dialog-facing sites were checked for trigger condition, reachability and timing:

- Every `error()` in `validateJob()` fires before any output, by construction — `validateJob()` is called
  from `onOpen()` before the first `writeComment()`. The `error()` sites outside it (`writeWCS()`'s
  out-of-range offset, `loadFile()`'s missing file, the four motion/compensation errors, `onSection()`'s two)
  all fire at the point of the offending construct.
- **`validateJob()`'s ordering is sound.** Guard C's Marlin branch `return`s, so Guard B, the RepRap-slot
  check and Guard A are unreachable on Marlin. Walked in **C4**: each is either inapplicable to the only
  Marlin jobs that get past Guard C, or harmless because `writeBaseEstablish()` warns and
  `fixedZEstablishedInFile()` is false there. Nothing below Guard C is needed on the firmware it excludes.
- **Warning/`writeWarning()` pairs.** Four conditions are raised in both places, and each pair tests an
  identical expression, so dialog and file cannot disagree: the "home at job start with nothing declared"
  pair, the jog-at-pause-on-GRBL pair, the Safe-Z format pair, and the tool-change-suppression pair — that
  last with one asymmetric input (**CR-20**).
- **Three `writeWarning()` sites have no dialog twin and are the file's only signal:** the coolant
  "no matching channel", the coolant "Use custom with no file named", and the Marlin unsupported-work-offset
  warning. That is the reason `writeWarning()` ignores `Comment Level`, and the design holds — walked at
  level Off in A3, where the warnings still emit.
- **No false negative found in any guard's condition** except the two already filed: Guard A's off-by-one
  section (**CR-07**) and `fixedZEstablishedInFile()` reporting an establish that did not happen
  (**CR-14**).
- **No false positive found.** Every warning walked fired on a configuration that genuinely produces wrong
  motion; **CR-15** is the one case where a warning fires on a shipped default, and it is the default that is
  wrong rather than the warning.

**S3 — emission inventory.** Every `G`/`M`/`$` code the post can emit outside group 9, against the three
firmwares:

| Code | Sites | Grbl 1.1 | Marlin 2.x | RRF 3.x |
|---|---|---|---|---|
| `G0` `G1` | `rapidMovements*`, `linearMovements`, `writeMachineTravelZ`, `writeMachineParkXY` | yes | yes | yes |
| `G2` `G3` | `circular` | yes, 3 planes | XY only — others linearized | XY only — others linearized |
| `G4 P` / `G4 S` | `onDwell` | `P`, seconds | `S`, seconds | `S`, seconds |
| `G10 L20 P<n>` | `writeWcsOrigin` | yes | not emitted (`G92` instead) | yes |
| `G17` | `Start`, `onClose`, `circular` | yes | **GRBL-only in this post** — `CNC_WORKSPACE_PLANES`, off by default | GRBL-only here; RRF has it from 2.03 |
| `G18` `G19` | `circular` | yes | not emitted | not emitted |
| `G20` `G21` | `Start` | yes | yes | yes |
| `G28 X/Y/Z` | `writeMachineHoming`, `writeMachineParkXY`, `probeTool` | not emitted (`$H` instead) | yes | yes |
| `G38.2` | `probeTool` | yes | build option `G38_PROBE_TARGET` — documented in the property | ≥ RRF 3; target frame changed at 3.1.1 — documented |
| `G53` | `writeMachineTravelZ`, `writeMachineParkXY` | yes | **refused by guard** — `CNC_COORDINATE_SYSTEMS` | yes |
| `G54`–`G59` | `writeWCS`, `retractThroughBaseClearance`, `writeBaseEstablish`, `writeMachineParkXY` | yes | not emitted | yes |
| `G59.1`–`G59.3` | same | **guarded off** | not emitted | yes |
| `G90` | `Start` | yes | yes | yes |
| `G92` | `writeWcsOrigin` | not emitted | yes | not emitted |
| `G94` | `Start` | yes | **GRBL-only in this post** — Marlin has no `G93`/`G94` | GRBL-only here; RRF gained it at 3.5.1 |
| `M0` | `askUser`, `onCommand` | yes | yes | not emitted (`M291`) |
| `M2` | `onClose` | not emitted | not emitted — never implemented | ≥ 3.5.1 |
| `M3` `M4` `M5` | `spindleOn`/`spindleOff` | yes | **`SPINDLE_FEATURE`, off by default — CR-09** | yes |
| `M6 T<n>` | `toolChange` | **no — CR-18** | build-dependent | yes, runs tool macros |
| `M7` | coolant enum (channel B default) | **`ENABLE_M7`, off by default — CR-24** | n/a | n/a |
| `M8` `M9` | coolant enum | yes | n/a | n/a |
| `M30` | `onClose` | yes | not emitted | not emitted |
| `M42 P<n> S<n>` | coolant enum | n/a | yes | yes |
| `M84 S0` / `M84 S60` | `Start`, `onClose` | not emitted | yes | yes |
| `M84 Z` | `toolChange` | **emitted, unsupported — CR-08** | yes | yes |
| `M117` | `display_text` | not emitted | yes | yes |
| `M291` | `askUser` | not emitted | not emitted | yes |
| `M300` | `spindleOff`, `toolChange` | not emitted | yes | yes |
| `M400` | `flushMotions` | not emitted, deliberately | yes | yes |
| `M453` / `M452` | `onSection` (duet mode) | not emitted | not emitted | yes |
| `$H` | `writeMachineHoming` | yes, via `writeln` | not emitted | not emitted |

Two new results from the table: **CR-24**, and the confirmation that the post's firmware splits are otherwise
complete — every code that is firmware-specific is emitted only inside a firmware arm, with `M84 Z` the sole
exception.

**S4 — API contract.** No factory post library is installed on this machine, so every claim below rests on
the source's own usage and on the Post Processor Guide rather than on a read of the kernel. Each is marked
with what would break if it were wrong.

| Symbol | How the post depends on it | If wrong |
|---|---|---|
| `wcsDefinitions` with `useZeroOffset: false` | lets Fusion's UI resolve a section's work offset to its G-code; does not change `writeWCS()`'s aliasing of offset 0 → 1 | cosmetic in the dialog; the alias is implemented in the post, twice, consistently (`writeWCS`, `collectDistinctOffsets`, `baseOriginWriteReason`) |
| `getWorkOffset()` returning 0 for "unset" | the 0 → 1 alias | a section would select the wrong WCS; the alias is applied identically at all three sites, so at least it cannot disagree with itself |
| `capabilities`, `tolerance` | milling + jet; 0.002 mm for `linearize()` | linearization density only |
| `maximumCircularSweep = toRad(180)`, `allowHelicalMoves = false`, `allowedCircularPlanes = undefined` | `circular()` assumes only planar partial arcs arrive, which is what makes the unconditional `zOutput.format(z)` in the XY arm safe | a helical move reaching `onCircular()` would emit a `G2` with a `Z` word and no `K` — a real defect, entirely dependent on the kernel honouring these |
| `getCurrentPosition()` inside `onLinear`/`onCircular`/`rapidMovements` | `isSafeToRapid()`'s current-position tests, `rapidMovements()`'s ordering, `limitFeedByXYZComponents()`'s vector, `circular()`'s I/J/K reference | it is the kernel's belief, and the post emits post-generated moves the kernel never sees (probe retracts, `G53` moves, base transits), so it is stale immediately after those. Walked: every such stale case ends with the tool *above* the kernel's belief or at a height that is safe in both readings, so no hazard was found — but the property is incidental, not enforced |
| `getNextRecord().isMotion()` | `linearMovements()`'s feed-without-motion suppression | a spurious `G1 F<n>` block, harmless |
| `expandCyclePoint`, `cycleNotSupported` | all drilling | drilling would emit nothing or unsupported canned cycles |
| `section.workPlane.forward` | `isSectionOrientationSupported()` | the function is written to fail open on every unreadable shape, so a wrong assumption degrades to "no check" rather than to a false abort |
| `is3D()` | the per-tool ZMIN column | a missing table column |
| `Vector.diff`, `.abs`, `.getNormalized()`, `.multiply`, `Vector.product` | the whole of `limitFeedByXYZComponents()` | feed scaling silently wrong. `.multiply` is used for its **mutating** effect, which is the one place the post depends on a Vector method's aliasing behaviour rather than its value |
| `createModal`/`createVariable` force semantics | `gMotionModal` forced off GRBL, `fOutput` forced under `Enforce Feedrate`, `sOutput` always forced | wrong suppression of `G` and `F` words |
| `FileSystem.isFile` / `getOutputPath()` in `onOpen()` | `validateJob()`'s include pre-flight | the pre-flight would throw or mis-report during `onOpen()`; factory posts use both in `onOpen()`, so this is the least doubtful item here |
| `onOpen()` re-running in one JavaScript context | the whole of `resetPostState()` | **CR-21** either matters or `resetPostState()` is dead code; the post is written on the assumption that it matters |

---

## Findings

**Severity index** — the CR numbers below are in discovery order and are *not* renumbered, because they are
referenced from the walks above and are more useful as stable identifiers. Read in this order instead:

| Severity | Findings |
|---|---|
| **Machine damage** | CR-11, CR-13, CR-14, CR-19, CR-21, CR-03, CR-04, CR-12, CR-16, CR-05, CR-23 |
| **Wrong part** | CR-06, CR-07, CR-17, CR-15 |
| **Wrong output** | CR-18, CR-08, CR-10, CR-01, CR-09, CR-22, CR-24 |
| **Cosmetic** | CR-02, CR-20 |

### CR-01 — GRBL ignores `F` on `G0`, so the group-2 travel speeds do nothing there

**Audience:** Both
**Severity:** Wrong output
**Confidence:** Firmware-assumption
**Conditions to repeat:** `CNC Firmware` = Grbl (the default). Any job. `Travel Speed X/Y` /
`Travel Speed Z` at any value.
**Problem:** `rapidMovementsXY()` and `rapidMovementsZ()` emit `G0 … F<travel speed>`. On GRBL 1.1 a `G0`
executes at the per-axis rapid rates `$110`/`$111`/`$112` and the `F` word does not affect it; `F` is
accepted and updates the modal feed, but the rapid runs at the machine's configured rate. So on the post's
default firmware the two travel-speed properties change nothing about how fast the machine moves, while the
dialog presents them as "High speed for Rapid movements". They are honoured on Marlin and RepRap, where `G0`
consumes the feedrate word. Nothing in the tooltips or the file says which firmware they apply to. The `F`
word itself is not harmful — the post tracks the value it emitted, so `fOutput` suppression stays truthful —
but an operator tuning those fields on GRBL is tuning nothing.

### CR-02 — `(MSG …)` prompts omit the conventional comma

**Audience:** Both
**Severity:** Cosmetic
**Confidence:** Firmware-assumption
**Conditions to repeat:** `CNC Firmware` = Grbl, any prompt — probe attach/detach, spindle, tool change,
homing pause.
**Problem:** `askUser()`'s GRBL arm emits `M0 (MSG Attach ZProbe)`. The convention senders match on is
`(MSG,<text>)` with a comma (LinuxCNC's message comment form, which GRBL-facing senders copy). GRBL itself
ignores the comment either way, so nothing breaks at the controller, but a sender that keys on `(MSG,` will
not surface the prompt and the operator sees an unexplained pause.

### CR-03 — group 3 is not gated to the licence it exists for, and nothing warns

**Audience:** Hobbyist
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** Fusion **Full** licence (real `G0`s reach `onRapid`), `Map G1s -> G0 Rapids` on,
any milling job.
**Problem:** `Map G1s -> G0 Rapids` is documented — in the group title and its own description — as a
recovery for the Personal edition's habit of emitting rapids as cuts. Nothing enforces that. With a Full
licence the property is still read on every `onLinear`, so genuine cutting moves are offered to
`isSafeToRapid()` and any of them whose destination Z is at or above the resolved Safe Z, with Z constant
or XY constant, is re-emitted as `G0` at travel speed. Under a Full licence the conversion can only *add*
rapids Fusion deliberately did not make: a `MOVEMENT_HIGH_FEED` link move, a lead-in or lead-out at the feed
height, or any cut on an operation whose retract/feed level sits at or below the stock top, all become
rapids. There is no `validateJob()` warning and no in-file warning for the combination, so the only signal
is the group's title. Either the group should be inert when real rapids are seen, or the combination should
warn.

### CR-04 — the first-move conversion applies no test of any kind to the destination

**Audience:** Hobbyist
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** `Map G1s -> G0 Rapids` on; any section whose first motion callback is `onLinear`.
Reached under the Personal licence on every section, and under a Full licence on any section whose first
emitted move is not a rapid.
**Problem:** `onSection()` sets `forceSectionToStartWithRapid = true`, and `onLinear()` converts the first
move that follows to `onRapid()` on the strength of that flag alone — no Safe-Z test, no comparison against
the current position, no check that the destination is in air. It is the only conversion in the post with no
`isSafeToRapid()` guard. The premise is that a section always opens with a positioning move, which is true
of ordinary Fusion output but is an assumption about the CAM rather than a property of the code: any section
that opens with a cut has that cut emitted as `G0`, which on GRBL runs at `$110`–`$112` rather than at a
feedrate, and `rapidMovements()` will order it Z-last only if the destination is below the tracked current
position. A destination Z test costs nothing here — `isSafeToRapid()` already exists — and would leave the
intended case (a positioning move at or above Safe Z) untouched.

### CR-05 — a start include file leaves `G90`, `G21`/`G20`, `G94` and `G17` unwritten, with no warning

**Audience:** Both
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** `Start GCode File` naming any file. Any firmware, any job.
**Problem:** `writeFirstSection()` calls `Start()` only when `includeStartFile` is empty; otherwise it calls
`loadFile()` instead. `Start()` is the only place in the post that emits `G90`, `G20`/`G21`, and (on GRBL)
`G94` and `G17` — no other path writes any of them, and `gAbsIncModal` / `gUnitModal` / `gFeedModeModal` are
never reset, so nothing re-asserts them later either. Everything the post emits after that point assumes
absolute positioning and the job's own units: `writeFixedZReference()`'s `G53 G0 Z…`, every `G10 L20`, every
probe target, every coordinate. If the operator's start file omits `G90` or sets the wrong unit, the whole
job is silently interpreted in the wrong mode. The property description says the file replaces the modal
preamble, but the post issues no `writeWarning()` and no `validateJob()` warning, and — unlike a missing
file, which the pre-flight catches — there is no detectable failure at post time. A one-line
`writeWarning()` at the replacement site would put the precondition in the file where the operator reads it.

### CR-06 — the first part's Z0 is probed before the `Do First Change` tool change

**Audience:** Both
**Severity:** Wrong part
**Confidence:** Certain
**Conditions to repeat:** `Tool Changes are Included` on, `Do First Change` on,
`Probe After Tool Change` **off**, any `First WCS / Part` mode that probes (the default included).
**Problem:** In `onSection()`, `writeFirstSection()` runs at the top of the first section and
`toolChange()` for `Do First Change` runs some twenty lines later. `writeFirstSection()` →
`writeWcsOnStart()` → `partProbe()` → `probeTool()` establishes the part's Z0 with whatever tool is in the
spindle at the start of the job — which is precisely the tool `Do First Change` exists to replace. The tool
is then changed, and the new tool's length differs from the old one's by an amount nobody measured. Every
cut in the job is off by that difference. Turning `Probe After Tool Change` on masks it (the re-probe
rewrites the same WCS, which for the first section is the right one), but the two properties are
independent and nothing ties them together. The fix is ordering: the first change belongs before the
first-part origin work, not after it.

### CR-07 — the post-tool-change re-probe writes Z into the previous section's WCS

**Audience:** Professional
**Severity:** Wrong part
**Confidence:** Certain
**Conditions to repeat:** Multi-WCS job (J5/J6 shapes), `Tool Changes are Included` on,
`Probe After Tool Change` on, any section that changes both tool and work offset at once — which is the
normal shape of a multi-part multi-tool job, since Fusion orders sections by the operation list.
**Problem:** `onSection()` calls `toolChange()` **before** `writeWCS()`. `toolChange()`'s re-probe goes
`onCommand(COMMAND_TOOL_MEASURE)` → `probeTool()` with `targetWcs` undefined, which resolves to
`currentWorkOffset` — still the *previous* section's offset. So the new tool's Z is written into the
previous part's register with `G10 L20 P<previous>`, overwriting a good origin with a measurement taken over
a different part, while the section that actually needs the new Z0 gets none. With `Include Relocation Code`
on it is worse: the relocation rapid moved the tool to `Tool Change X/Y/Z` in the previous part's frame, so
the probe touches off there. `probeTool()`'s post-probe retract uses `probeSafeZ()`, resolved from the
*current* section, emitted in the previous section's frame — a second frame mismatch in the same block
sequence.

The same off-by-one reaches Guard A. `baseOriginWriteReason()` tests `reprobe && toolChanged && wo == base`
using section `i`'s own work offset, but the write lands in section `i-1`'s. The guard therefore misses the
case it exists for (previous section on the base, current section not) and refuses a case that is safe
(current section on the base, previous not). Fixing the ordering fixes the guard; leaving the ordering and
fixing only the guard would encode the defect.

### CR-08 — `Disable Z Stepper` emits `M84` on GRBL, which has no such command

**Audience:** Both
**Severity:** Wrong output
**Confidence:** Firmware-assumption
**Conditions to repeat:** `CNC Firmware` = Grbl, `Tool Changes are Included` on,
`Include Relocation Code` on, `Disable Z Stepper` on.
**Problem:** `toolChange()` emits `M84 Z` with no firmware test, unlike every other `M84` in the post
(`Start()`'s `M84 S0` and `onClose()`'s `M84 S60` are both inside non-GRBL arms). GRBL 1.1's supported
M-codes are `M0`, `M1`, `M2`, `M30`, `M3`, `M4`, `M5`, `M7`, `M8`, `M9`, `M56`; `M84` is not among them and
reaches `error:20 Unsupported command`, which halts the program mid tool change with the spindle stopped and
the operator holding a tool. The property is reachable from the dialog on GRBL with nothing to indicate it
is Marlin/RepRap-only. Either gate the emission on firmware, or say so in the property description.

### CR-09 — commanded spindle control emits `M3`/`M4`/`M5`, which are a build option on Marlin

**Audience:** Both
**Severity:** Wrong output
**Confidence:** Firmware-assumption
**Conditions to repeat:** `CNC Firmware` = Marlin, `Manual Spindle On/Off` **off**.
**Problem:** `spindleOn()`/`spindleOff()` emit `M3 S<n>` / `M4 S<n>` / `M5` on every firmware. On Marlin
those codes exist only when the firmware was compiled with `SPINDLE_FEATURE` (or `LASER_FEATURE`) enabled in
`Configuration_adv.h`, and both ship disabled. On a stock Marlin CNC build the codes reach
`unknown_command_warning()` — Marlin warns and continues rather than halting, so the job runs to completion
with the spindle never commanded on, which is the quiet failure rather than the loud one. This is the same
class of fact the post already documents for `G38.2` (`G38_PROBE_TARGET`), `G53` (`CNC_COORDINATE_SYSTEMS`)
and `G17` (`CNC_WORKSPACE_PLANES`), and it belongs beside them in the property description.

### CR-10 — parking at machine `X0 Y0` drives back onto the homing switches

**Audience:** Both
**Severity:** Wrong output
**Confidence:** Firmware-assumption
**Conditions to repeat:** `CNC Firmware` = Grbl or RepRap, `Axes Homed and Trusted` includes X/Y,
`Home at Job Start` = Home or Pause then Home, `At End Park At` = `Machine X0 Y0`.
**Problem:** `writeMachineParkXY()` emits `G53 G0 X0 Y0 F<travel>` as the last motion of the job. On a stock
GRBL build `HOMING_FORCE_SET_ORIGIN` is disabled (`grbl/config.h`), so machine zero sits **at the homing
switch trigger point** and the machine rests `$27` (homing pull-off) away from it after `$H`. `G53 G0 X0 Y0`
therefore drives X and Y back into the switches. With hard limits enabled (`$21=1`) that raises a hard-limit
alarm, which on GRBL means the controller enters `Alarm` and the program ends in an error state rather than
parked; with them disabled the axes press against the switches until the move ends. The property description
calls machine X0 Y0 "the machine's own homing corner — one park point for every job", which is true of the
coordinate and misleading about what happens when you go there. A park at the pull-off distance, or at a
small documented inset, is the ordinary way this is done. The Marlin route is unaffected: it re-homes rather
than rapids, so it ends at the pull-off position by construction.

### CR-11 — the spoilboard base is probed to a target measured in the frame the probe is establishing

**Audience:** Professional
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** `Fixed Z Reference` = Spoilboard with any `Reserved WCS`; any firmware that runs
it (Grbl or RepRap); any `Probe to Set Base` mode.
**Problem:** `writeBaseEstablish()` transit-selects the base WCS and calls `probeTool()`, which emits
`G38.2 F<speed> Z<G38 Target>`. `G38 Target` is a **position in the active frame**, and the active frame here
is the base WCS whose Z0 this probe exists to establish — so the target is measured from a register holding
whatever a previous job, a manual touch-off or a power-on left in it. Nothing writes a provisional Z0 first.
Compare `writeWcsOnStart()`'s `Current XY & Probe Z` arm, which writes `G10 L20 P<n> X0 Y0 Z0` immediately
before probing with the comment "so the probe target is a relative limit" — that is the mechanism that turns
`-10` into "search 10 mm down from here", and the base establish is the one probe in the post that does not
have it. The two failure directions are both real: a stale base Z0 that reads high turns `-10` into a plunge
of arbitrary depth at probing speed, and one that reads low puts the target *above* the current position, so
`G38.2` moves up, never touches, and ends in a GRBL alarm. Writing a provisional `G10 L20 P<base> Z0` before
the `G38.2` would make the target a relative limit here as it is everywhere else.

### CR-12 — both `Use Active WCS …, Probe Z0` modes measure the probe target from the Z0 they distrust

**Audience:** Professional
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** `First WCS / Part` = `Use Active WCS X0 Y0, Probe Z0`, or `Subsequent WCS / Part` =
`Use Active WCS X0 Y0, Probe Z0` on a multi-WCS job. Grbl or RepRap.
**Problem:** The same mechanism as CR-11 on the part probes. `partProbe()` → `probeTool()` emits
`G38.2 … Z<G38 Target>` in the part's own WCS, and these two modes exist precisely because that WCS's stored
Z0 is not trusted — the `probeG38Target` description says so outright ("measured from that WCS's STORED Z
zero instead, which may be anywhere"). The consequence is that the one property whose job is to bound the
probe's travel does not bound it on these paths. For the first part `validateJob()` at least warns
(`startMode == "Probe Z" && !fixedZEstablishedInFile()`), and that warning names the problem. For the
**subsequent-part** path there is no warning at all: neither `validateJob()` nor `writeWCS()` says anything,
and the stored-offset warning that does exist is about X/Y and is suppressed as soon as X/Y is declared
homed. This is separated from CR-11 because here the operator has alternatives in the dialog; at the base
establish they have none.

### CR-13 — with `Retract Across Parts` off, the inter-part traverse height is resolved in one frame and emitted in another

**Audience:** Professional
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** Multi-WCS job, `Retract Across Parts` **off** (which is also the only way to post a
multi-WCS job with `Fixed Z Reference` = None, Guard B refusing the alternative). Grbl or RepRap.
**Problem:** With `spoilboardSafeZAcrossWcs` off, `crossPart` is false, so `writeWCS()` skips both the
machine-frame and base-relative routes and falls into its bare `isTraverse` arm: `resetAll()`,
`rapidMovementsZ(probeSafeZ())`, `flushMotions()`. Two things are wrong with that height. It is resolved
from `currentSection` — the section being *entered* — through `probeSafeZ()` → `resolveSafeZHeight(…,
currentSection)`, so it is the new operation's retract level; and it is emitted **before** the WCS select,
so it is interpreted in the **previous** part's frame. The tool then traverses to the next part at
`previous part's Z0 + new operation's retract height`, a number that belongs to neither part. On parts of
differing thickness, or with differing retract levels, that height can be below the next part's stock top or
below a clamp. Guard B refuses this configuration when `Retract Across Parts` is on, which is the setting
that *asks* for cross-part safety; turning the safety feature off silently enables the unsafe traverse
rather than suppressing the traverse. Nothing warns.

### CR-14 — the base-establish tool-0 skip leaves the job believing a base was established

**Audience:** Professional
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** `Fixed Z Reference` = Spoilboard with a `Reserved WCS`, on Grbl or RepRap, where
the first section's tool number is 0 (or a jet tool).
**Problem:** `writeBaseEstablish()` wraps its whole probe sequence in `if (tool.number != 0 &&
!tool.isJetTool())` and takes an `else` branch that writes only a Debug comment — no probe, no
`G10 L20 P<base>`, and no warning at any comment level. Meanwhile `fixedZEstablishedInFile()` asks only the
dialog and the firmware, so it goes on returning true. Every consumer of that predicate is then wrong at
once: `retractThroughBaseClearance()` emits `G0 Z<Inter Part Travel Z>` into a base register nobody set;
`partProbe()` suppresses its "no Z reference is established" warning; `parkCanRetract()` reports that the
end-of-job park can retract, and `validateJob()`'s matching warning stays silent. Every one of those is an
absolute Z move into an unestablished frame — the exact failure I1 exists to catch. The skip itself is
right; its silence is not, and the predicate should reflect what was actually emitted.

### CR-15 — the shipped default `First WCS / Part` is incompatible with every `Fixed Z Reference`

**Audience:** Professional
**Severity:** Wrong part
**Confidence:** Certain
**Conditions to repeat:** `Fixed Z Reference` = Spoilboard or Machine Z (i.e. any multi-part job — the whole
reason group 5 exists), `First WCS / Part` left at its default `Set X0 Y0 to Current Pos, Probe Z0`.
**Problem:** Establishing the fixed Z reference is step 5 of `writeFirstSection()` and it *moves the tool* —
to `Inter Part Travel Z` above the base, or to the machine travel height. `writeWcsOnStart()` is step 6, and
the two `Set … to Current Pos` modes record wherever the tool now is. So the first part's origin is recorded
at bed clearance and the `G38.2` that follows searches `G38 Target` below bed clearance and never reaches the
stock. `validateJob()` warns about exactly this, so guard fidelity is intact — but the warning fires on the
**default** value of `First WCS / Part` for every job that sets a fixed Z reference at all, which means the
two groups the professional workflow needs cannot both be left in a working state without changing a control
in a third. That is a defaults problem rather than a logic one, and it is worth fixing in the defaults or in
group 5's description, which currently sends the operator to group 6 for nothing.

### CR-16 — one part machined from several WCS is accepted and traverses to an unset register

**Audience:** Professional
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** A single physical part whose operations are assigned to different work offsets
(J3). Grbl or RepRap; X/Y declared homed, so the stored-offset warning is suppressed.
**Problem:** Both `First WCS / Part` and `Subsequent WCS / Part` say in their descriptions that one part from
multiple datums, or a flip, must be run as separate jobs. Nothing in the code checks it, and the post cannot
tell J3 from J4 — a WCS change is a WCS change. So a J3 job posts, and on the first traverse `writeWCS()`
rapids to the *stored* X0 Y0 of a register the operator never set (`Skip`), or probes there (`Probe Z`),
which on a machine whose G55 register holds a leftover or a zero means a rapid to somewhere else on the bed
followed by a probe into whatever is under it. The one partial protection is `validateJob()`'s stored-offset
warning, which fires only when X/Y is **not** declared homed — so declaring the machine's endstops removes
the only signal. This is the gap J3 exists to characterise: the guidance is real, it is in the right place,
and it is entirely advisory.

### CR-17 — a revisited WCS is re-probed on a surface the job has already cut

**Audience:** Professional
**Severity:** Wrong part
**Confidence:** Certain
**Conditions to repeat:** A job that returns to a work offset it has already used — rough every part then
finish every part, G54 → G55 → G54 (J6) — with `Subsequent WCS / Part` = `Use Active WCS X0 Y0, Probe Z0`
(the default). Grbl or RepRap.
**Problem:** `writeWCS()` suppresses only a *repeat* of the currently active offset, so a return to an
earlier one is a full traverse and takes the `probeOnChange` dispatch. With the default mode that means a
second `G38.2` into a register that already holds a good, job-established Z0 — and the touch point is the
part origin plus `Probe X/Y Offset`, which after the roughing pass may be a machined pocket floor, a cut-away
region, or air. The re-probe then overwrites the correct Z0 with a wrong one and every finishing cut is
displaced by the roughing depth at that point. Nothing detects that the WCS was established earlier in this
same file, although `currentWorkOffset` history is exactly the information needed: a WCS this job has already
probed does not need probing again. Sequencing a multi-part job to save tool changes is ordinary shop
practice, so this is not an exotic shape.

### CR-18 — `M6` is not a GRBL command, so the no-relocation tool-change route halts the job

**Audience:** Both
**Severity:** Wrong output
**Confidence:** Firmware-assumption
**Conditions to repeat:** `CNC Firmware` = Grbl (the default), `Tool Changes are Included` on,
`Include Relocation Code` **off**, a job with more than one tool.
**Problem:** `toolChange()`'s else-branch emits `M6 T<n>`. GRBL 1.1's M-code set is `M0`, `M1`, `M2`, `M30`,
`M3`, `M4`, `M5`, `M7`, `M8`, `M9`, `M56` — `M6` is absent and returns `error:20 Unsupported command`, which
stops the program. (`T` alone is parsed and ignored, so the tool word is harmless.) On Marlin `M6` exists
only in builds with tool-change support compiled in and otherwise warns and continues, and on RepRap it is
a real tool change that will try to run `tfree`/`tpre`/`tpost` macros the operator has not written. So this
route works on none of the three firmwares as a manual-tool-change prompt. `Include Relocation Code` off is
the shipped default, which makes this the configuration a first-time operator reaches by simply turning tool
changes on.

### CR-19 — the `M6` tool-change route stops nothing before the change

**Audience:** Both
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** `Tool Changes are Included` on, `Include Relocation Code` off, any firmware, a job
with more than one tool.
**Problem:** The relocation branch of `toolChange()` moves the tool clear, then calls
`onCommand(COMMAND_COOLANT_OFF)` and `onCommand(COMMAND_STOP_SPINDLE)` before prompting. The else-branch does
none of it: it emits `M6 T<n>` and nothing else. Coolant keeps running, the spindle keeps turning (or, under
`Manual Spindle On/Off`, the operator is never asked to switch the router off), and the tool is wherever the
last cut left it — in the material. Whatever the controller does with the `M6`, the state the post hands the
operator to change a tool in is unsafe. The coolant/spindle stop is not a property of the relocation feature
and belongs on both routes.

### CR-20 — the tool-change suppression warning has no dialog twin for the single-tool case

**Audience:** Both
**Severity:** Cosmetic
**Confidence:** Certain
**Conditions to repeat:** `Tool Changes are Included` **off**, `Do First Change` on, a job using exactly one
tool.
**Problem:** `onSection()` calls `toolChange()` for the first section whenever `Do First Change` is on,
regardless of `Tool Changes are Included`, so the in-file `writeWarning()` fires. `validateJob()`'s twin is
gated on `countDistinctTools() > 1` and stays silent, so the operator sees nothing at post time and finds
the warning only by reading the file. The two are otherwise a matched pair; this is the one input where they
disagree.

### CR-21 — `resetPostState()` does not reset the modal formatters, so a second file in one context loses its preamble

**Audience:** Both
**Severity:** Machine damage
**Confidence:** API-assumption
**Conditions to repeat:** Two or more NC files posted from one Fusion invocation where the post's JavaScript
context is reused — the case `resetPostState()`'s own comment says the post does not rely on avoiding.
**Problem:** `resetPostState()` resets every mutable value global and `gPlaneModal`, and `onOpen()` rebuilds
`gMotionModal` and `fOutput` on both branches precisely so neither leaks. Three modal formatters and seven
variables are left out: `gAbsIncModal`, `gUnitModal`, `gFeedModeModal`, and `xOutput`/`yOutput`/`zOutput`/
`sOutput`/`iOutput`/`jOutput`/`kOutput`. The consequence in the second file is that `Start()`'s
`gAbsIncModal.format(90)`, `gUnitModal.format(unit == IN ? 20 : 21)` and `gFeedModeModal.format(94)` all find
the modal already holding those values and emit **nothing** — so file two has no `G90`, no `G21`/`G20` and no
`G94`, and every absolute coordinate, `G53` move and probe target in it depends on the controller still being
in the mode file one left it in. The coordinate variables are the milder half of the same leak: file two's
first move can have an axis word suppressed because file one ended at that value. `sOutput` is
`force: true` so it is immune; `gPlaneModal` was singled out for reset with a comment explaining exactly this
failure mode, which is the tell that the other three were an oversight rather than a decision.
A related consequence, since the formats are built at load time from `unit`: two files with different output
units would share the first one's decimal places. Marked API-assumption only because whether Fusion reuses
the context is not verifiable from the source here; if it never does, the whole of `resetPostState()` is
unnecessary, and the code is written on the opposite assumption.

### CR-22 — the four coolant "custom file" properties are not in the include pre-flight

**Audience:** Both
**Severity:** Wrong output
**Confidence:** Certain
**Conditions to repeat:** Any `Turn Channel A/B On/Off` set to `Use custom` with a custom-file property
naming a file that is not in the NC output folder.
**Problem:** `validateJob()`'s pre-flight checks `includeStartFile`, `includeStopFile` and — when tool
changes are on — the two tool-change files, and refuses the post before any output when one is missing. The
comment above it states the reason: a missing file otherwise only reaches `error()` inside `loadFile()`, by
which point the header and preamble are already in the stream. `coolantChannelAOnCustom`,
`coolantChannelAOffCustom`, `coolantChannelBOnCustom` and `coolantChannelBOffCustom` are read through the
same `loadFile()` and are absent from the pre-flight list, so exactly that late failure is what they get —
and the coolant-off files fail at `onClose()`, after the whole job has been written. They should be added to
the list under the same condition that makes them reachable (their channel set to `Use custom`).

### CR-23 — a Safe-Z expression of `0` is accepted, making every non-negative Z "safe air"

**Audience:** Hobbyist
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** `Map G1s -> G0 Rapids` on with `Safe Z to Rapid` set to `0` (or `Feed:0`,
`Retract:0`, `Clearance:0` on an operation with no absolute level).
**Problem:** `parseSafeZExpr()`'s CONST regex `/^\d+\.?\d*$/` matches `0`, so `safeZHeightDefault` becomes 0
and `isSafeToRapid()`'s `zr >= safeZHeight` is true for every Z at or above the stock top — including a cut
at exactly Z0, a skim pass, and the whole of a 2D engraving at zero depth. Those moves are then re-emitted as
`G0` at travel speed. `validateJob()`'s Safe-Z warning fires only on the ERROR arm, so `0` posts silently.
`0` is a plausible thing for an operator to type meaning "no restriction", and it produces exactly that with
the sign reversed. The same applies to `probeSafeZ` = `0`, where the post-probe retract becomes a move to the
stock top rather than clear of it. A lower bound on the accepted value, or a warning at zero, would close
it — the parser already rejects negatives.

### CR-24 — the default channel-B coolant code is behind a default-off GRBL build option

**Audience:** Both
**Severity:** Wrong output
**Confidence:** Firmware-assumption
**Conditions to repeat:** `CNC Firmware` = Grbl, `Channel B Mode` set to any coolant a tool in the job
requests, `Turn Channel B On` left at its default `Grbl: M7 (mist)`.
**Problem:** `M7` (mist coolant) is compiled into GRBL 1.1 only when `ENABLE_M7` is uncommented in
`grbl/config.h`, and it ships commented out. On a stock build `M7` returns `error:20` and halts the job, in
the middle of a section, with the tool in the cut. The property's own title advertises it as the GRBL code
and the description says "The default is the Grbl code" — which is true of the dialect and not of the
default build. `M8` and `M9`, the channel-A defaults, are unconditional and fine. Channel B is off by default
(`Channel B Mode` = Off) so the code is not emitted until the operator configures the channel, which is why
this is not more severe — but the operator configuring it is following the dialog's own guidance.

---

## Unwalked code

The post has **103** top-level functions. **100** were walked. The three that were not, and every branch no
story reached, with the reason:

### Functions not walked

| Function | Reason |
|---|---|
| `laserOn` | out of scope by decision — laser / plasma / jet |
| `laserOff` | out of scope by decision |
| `onPower` | out of scope by decision |

### Branches not walked

| Branch | Reason | Residual risk |
|---|---|---|
| `onSection()`'s `TYPE_JET` arm, including the `default:` jetMode fall-through | out of scope | the fall-through is the only jet path with a value-safety argument in its comment; unreviewed |
| `onCommand()`'s `COMMAND_COOLANT_ON` jet arm (`laserCoolant`) | out of scope | none for milling |
| `writeWcsOnStart()`'s jet-tool half of the tool-0 branch | out of scope | the tool-0 half **was** walked — see CR-14 |
| `writeBaseEstablish()` / `writeWCS()` jet-tool guards | out of scope | as above |
| the seven group-9 laser properties | out of scope | untested defaults |
| `describeSafeZ()`'s "no operations to resolve against" arm | **unreachable** — it runs from `writeInformation()`, which runs from `writeFirstSection()`, which runs inside the first section, so `getNumberOfSections()` is never 0 there | none |
| `rapidMovementsXY()` and `rapidMovementsZ()`'s `pendingRadiusCompensation != OFF` error arms | **unreachable** — `onRadiusCompensation()` already called `error()` for any non-off mode, which aborts the post | none; they are defence in depth |
| `writeFixedZReference()`'s "Machine Z ignored on Marlin" warning | **unreachable via the dialog** — `validateJob()` refuses that combination before any output. Kept deliberately, and the comment says so | none |
| `setCoolant()`'s `"unknown"` arm in the no-matching-channel warning | **unreachable** — every value that reaches `setCoolant()` comes from `coolantLevels` or from a channel-mode enum whose ids are the same strings | none |
| `writeComment(eComment.Off, …)` | **never called** — no call site passes `Off` as the *level*. Were one added it would emit at every comment level, `indexOf("Off") <= indexOf("Off")` being true | latent; a trap for a future call site |
| `writeCustomCoolantFile()`'s `on` parameter | **never read** — the function takes it and ignores it | none; dead parameter |
| `limitFeedByXYZComponents()`'s zero-length arm | walked, and shown to produce no emitted feed (A2′) | none — but the arm exists to handle a case that cannot reach the file, so its value is untestable from output |
| `jobCommentLevel` = `Important` | not given a dedicated story. `writeComment()` is a single index comparison, walked at `Off`, `Info` and `Debug`; the intermediate level adds no branch | none |
| `spoilboardBaseReserve` ids `1`–`5` | `6` (C1) and `7` (C2) walked. The ids are parsed with `parseInt` and used numerically, so the intermediate values share one path | none |

### Job shapes not covered

- **Multi-axis and off-axis Setups** are walked only as *rejection* paths (D6), never as motion — correct,
  since the post refuses them.
- **One part machined from two datums, or a flip**, is J3 and **is** walked (C7); the finding there is that
  the dialog forbids it and the code does not.
- **A tool-length-offset workflow (`G43`)** does not exist in this post and was not reviewed; the design
  record states there is no tool-length system at all and the work-Z re-probe is the substitute.

---

## Verification

**Ledger completeness.** All 103 top-level functions are accounted for: 100 in the walks, 3 in *Unwalked
code* with a stated reason. The list was enumerated mechanically from the source rather than by reading, so
nothing is silently absent.

**Branch completeness.** Every enum property's every `id` and both values of every in-scope boolean appear in
at least one story or in the unwalked list. The enum coverage, by id:

| Property | id → story |
|---|---|
| `jobSelectedFirmware` | Grbl A1 · Marlin A4 · RepRap A5 |
| `jobCommentLevel` | Off A3 · Info A1 · Debug A2 · Important — see unwalked |
| `machineHomedAxes` | None A1 · XY B1/A5 · Z B4 · XYZ B2/B3 |
| `machineHomeAtStart` | Off A1/B1 · Home A5/B3/C1 · Pause & Home B2 |
| `machineParkAtEnd` | Off — emits nothing, walked by inspection at `onClose()` · Work A1 · Machine B1/B2/B3 |
| `spoilboardFixedZRef` | None A1 · Spoilboard C1 · Machine Z B2 |
| `spoilboardBaseReserve` | None A1 · 6 C1 · 7 C2 · 1–5 see unwalked |
| `spoilboardBaseEstablish` | Pause & Probe Z C1 · Probe Z — same path with both pause flags false, walked in C1's re-walk |
| `probeOnStart` | Current XY & Probe Z A1 · Current XYZ A3 · Probe Z B1 · Skip C2 · Jog XY & Probe Z A5 · Jog XYZ — `writeWcsOnStart()`'s `Jog XYZ` arm shares the prompt path with `Jog XY & Probe Z` and the origin write with `Current XYZ`, both walked |
| `probeOnChange` | Probe Z B2/C1 · Skip C2 · Jog XY & Probe Z C6 · Jog XYZ C6 |
| `probePause` | No C2 · Before & After A1 · Before — the single expression pair `(pause == "Before" \|\| pause == "Before & After")` / `(pause == "Before & After")`, walked at both endpoints |
| `coolantChannelAMode` / `BMode` | Off A1 · Flood E2 · the remaining ids are string equality against the same expression |
| `coolantChannelAOn`/`AOff`/`BOn`/`BOff` | `M8`/`M9` E2 · `M42 …` E2 · `Use custom` E2 (named and empty) |
| group 9 enums | out of scope |

Booleans: `jobManualSpindlePowerControl` A1/A4 · `jobUseArcs` D7/A3 · `jobSequenceNumbers` A1/A3 ·
`jobSeparateWordsWithSpace` A1/A3 · `feedsEnforceFeedrate` A1/A3 · `feedsScaleFeedrate` A1/A3 ·
`mapRapidsRestoreRapids` A1/A2 · `spoilboardSafeZAcrossWcs` C1/C3 · `probeG382orG28` A1/A4 ·
`toolChangeEnabled` A1/A4 · `toolChangeInsertCode` A4/D4 · `toolChangeDisableZStepper` A1/A4 ·
`toolChangeDoFirstChange` A1/A4 · `toolChangeProbeAfterChange` A1/A4. All fourteen at both values.

**Licence completeness.** All four cells of licence × `Map G1s -> G0` are walked: A1/A3 (Full, off), A2
(Personal, on), A2′ (Personal, off), A2″ (Full, on). Every Direction-1 finding states its licence:
**CR-03** is Full-only, **CR-04** is reached on every section under Personal and on a section opening with a
cut under Full, and no other finding depends on the licence.

**Finding reproducibility.** Each of the 24 findings was re-read against the source independently of the
story that produced it, and each path confirmed reachable from the dialog. Two candidates sighted on the
first read did **not** survive and are dropped:

- `limitFeedByXYZComponents()`'s zero-length arm returning 180 for a long positioning move — the arm is
  reachable but the feed it returns is never emitted (A2′).
- `onClose()`'s `G17` assert being GRBL-only while the built-in footer path does not re-assert after a
  `loadFile()` reset — the built-in footer path never runs a `loadFile()`, the two being the branches of one
  `if`, and the footer emits no arc.

**No duplicate coverage.** No two stories claim the same first-walk. The one overlap worth naming is
**CR-07**, which is reached from A4, C5 and D4; A4 is credited with the first walk and the other two with the
interactions specific to them (Guard A's off-by-one in C5, the relocation-route variant in D4).

**Release read.** Seven findings are `Machine damage` or `Wrong part` on a **default or near-default**
configuration — CR-04, CR-05, CR-06, CR-11, CR-13, CR-15, CR-19 — and CR-18 halts the job on the shipped
default tool-change route. Those are the set a Beta would need to resolve or document. The remainder are
either firmware-specific (CR-01, CR-08, CR-09, CR-10, CR-24), configuration-specific (CR-03, CR-12, CR-14,
CR-16, CR-17, CR-21, CR-22, CR-23), or cosmetic (CR-02, CR-20).
